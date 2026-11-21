#!/usr/bin/env python3
"""Encode ONLY real Factorio GUI screenshots from a completed combat batch.

No simulated frames, interpolation, invented shots, or fabricated battle results.
Native source frames are retained unchanged. Real MP4 requires ffmpeg; GIF can
use Pillow if ffmpeg is unavailable. Missing output is marked BLOCKED.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import shutil
import struct
import subprocess
import sys
import zlib

CLIPS = ("01-massed-units", "02-bunker-lines", "03-enemy-flank")
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"


def digest(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def png_header(path: pathlib.Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        header = stream.read(24)
    if not header.startswith(PNG_MAGIC) or len(header) < 24:
        raise ValueError(f"Not a real Factorio PNG: {path}")
    w, h = struct.unpack(">II", header[16:24])
    if not 160 <= w <= 4096 or not 90 <= h <= 2160:
        raise ValueError(f"Impossible native screenshot dimensions: {path}")
    return w, h


def verified_png(path: pathlib.Path) -> tuple[int, int]:
    """Validate the complete native PNG chunk stream, not just its signature."""
    dims = png_header(path)
    with path.open("rb") as stream:
        if stream.read(8) != PNG_MAGIC:
            raise ValueError("Bad native PNG magic")
        saw_ihdr, saw_idat, saw_iend = False, False, False
        while True:
            length_bytes = stream.read(4)
            if len(length_bytes) != 4:
                break
            size = struct.unpack(">I", length_bytes)[0]
            if size > 512 * 1024 * 1024:
                raise ValueError("Unbounded PNG chunk")
            kind = stream.read(4)
            payload = stream.read(size)
            check = stream.read(4)
            if len(kind) != 4 or len(payload) != size or len(check) != 4:
                raise ValueError("Truncated native PNG data")
            crc = zlib.crc32(payload, zlib.crc32(kind)) & 0xFFFFFFFF
            if struct.unpack(">I", check)[0] != crc:
                raise ValueError("Native PNG checksum mismatch")
            if kind == b"IHDR":
                saw_ihdr = True
            elif kind == b"IDAT":
                saw_idat = True
            elif kind == b"IEND":
                saw_iend = True
                break
        if not (saw_ihdr and saw_idat and saw_iend):
            raise ValueError("Incomplete native PNG stream")
        if stream.read(1):
            raise ValueError("Native PNG has unexpected trailing bytes")
    return dims


def frame_rows(root: pathlib.Path, clip: str, expected: list) -> list[dict]:
    if not re.fullmatch(r"[a-z0-9-]{3,40}", clip):
        raise ValueError("Unsafe clip identifier")
    rows = []
    if not isinstance(expected, list) or len(expected) < 16 or len(expected) > 72:
        raise ValueError(f"Native clip has insufficient/excess frame receipts: {clip}")
    for i, item in enumerate(expected):
        if type(item) is not dict or item.get("frame") != i or type(item.get("tick")) is not int:
            raise ValueError(f"Missing native sequential frame/tick receipt: {clip}/{i}")
        path = root / clip / f"frame-{i:04d}.png"
        if not path.is_file() or path.stat().st_size < 4096:
            raise ValueError(f"Missing or empty actual Factorio screenshot: {path}")
        w, h = verified_png(path)
        rows.append({
            "path": str(path),
            "tick": item["tick"],
            "frame": i,
            "resolution": [w, h],
            "bytes": path.stat().st_size,
            "sha256": digest(path),
        })
        if i and rows[-1]["tick"] <= rows[-2]["tick"]:
            raise ValueError(f"Non-monotonic engine screenshot receipt: {clip}")
    if len(set(tuple(x["resolution"]) for x in rows)) != 1:
        raise ValueError(f"Native source screenshot resolutions changed: {clip}")
    if len(set(x["sha256"] for x in rows)) < 3:
        raise ValueError(f"Native footage is static; no motion proof: {clip}")
    return rows


def run_encode(argv: list[str], target: pathlib.Path, log: pathlib.Path) -> bool:
    with log.open("w", encoding="utf-8") as output:
        code = subprocess.run(argv, stdout=output, stderr=subprocess.STDOUT,
                              timeout=300).returncode
    return code == 0 and target.is_file() and target.stat().st_size > 4096


def gif_pillow(paths: list[pathlib.Path], target: pathlib.Path, fps: int) -> bool:
    try:
        from PIL import Image
    except ImportError:
        return False
    images = []
    try:
        for path in paths:
            with Image.open(path) as img:
                # Downsample to a GIF-friendly proof size without modifying
                # the underlying native screenshot. No inter-frame blending.
                frame = img.convert("RGB")
                frame.thumbnail((640, 360), Image.Resampling.LANCZOS)
                images.append(frame.quantize(colors=128))
        if not images:
            return False
        images[0].save(target, save_all=True, append_images=images[1:],
                       duration=int(1000 / fps), loop=0, optimize=False)
        return target.is_file() and target.stat().st_size > 4096
    finally:
        for img in images:
            img.close()



PINNED_FFMPEG_WHEEL = "imageio_ffmpeg-0.8.1-py3-none-win_amd64.whl"
PINNED_FFMPEG_SHA256 = "f27ca4cb85e2d4946deedbce1a81245dfd942a2bcf94b53676fb3956aa95bf1b"


def pinned_local_ffmpeg() -> str | None:
    """One-time checksum-pinned portable FFmpeg; leave runner installations alone.

    The approved Windows runner's Blender Python has neither ffmpeg on PATH
    nor Pillow. Store the vetted binary in the user's persistent local cache,
    never in a per-run report or the immutable Factorio graphics cache.
    """
    if os.name != "nt" or sys.maxsize <= 2**32:
        return None
    import tempfile
    import urllib.parse
    import urllib.request
    import zipfile

    cache = pathlib.Path(os.environ.get("LOCALAPPDATA") or
                         pathlib.Path.home() / ".cache") / "tech-priests" / "native-ffmpeg"
    exe = cache / "ffmpeg-imageio-0.8.1-win_amd64.exe"
    manifest = cache / "encoder-pin.json"
    try:
        if exe.is_file() and manifest.is_file():
            pin = json.loads(manifest.read_text(encoding="utf-8"))
            if (pin.get("wheel_sha256") == PINNED_FFMPEG_SHA256
                    and pin.get("executable_sha256") == digest(exe)
                    and exe.stat().st_size > 1024 * 1024):
                print("NATIVE_PROOF_ENCODER_CACHE_HIT source=pinned-imageio-ffmpeg-0.8.1",
                      flush=True)
                return str(exe)
        cache.mkdir(parents=True, exist_ok=True)
        metadata_url = "https://pypi.org/pypi/imageio-ffmpeg/0.8.1/json"
        with urllib.request.urlopen(metadata_url, timeout=25) as response:
            metadata = json.load(response)
        matches = [r for r in metadata.get("urls", [])
                   if r.get("filename") == PINNED_FFMPEG_WHEEL
                   and r.get("digests", {}).get("sha256") == PINNED_FFMPEG_SHA256]
        if len(matches) != 1:
            raise ValueError("Official PyPI wheel/digest pin not found")
        wheel_url = matches[0]["url"]
        location = urllib.parse.urlsplit(wheel_url)
        if (location.scheme != "https" or
                location.hostname != "files.pythonhosted.org"):
            raise ValueError("Unexpected pinned wheel download origin")
        wheel_tmp = None
        exe_tmp = None
        manifest_tmp = None
        try:
            with tempfile.NamedTemporaryFile(dir=cache, suffix=".whl",
                                             delete=False) as temporary:
                wheel_tmp = pathlib.Path(temporary.name)
                size = 0
                with urllib.request.urlopen(wheel_url, timeout=90) as response:
                    if urllib.parse.urlsplit(response.geturl()).hostname != "files.pythonhosted.org":
                        raise ValueError("Wheel download redirected to unapproved origin")
                    while True:
                        chunk = response.read(1024 * 1024)
                        if not chunk:
                            break
                        size += len(chunk)
                        if size > 96 * 1024 * 1024:
                            raise ValueError("Pinned wheel exceeds size limit")
                        temporary.write(chunk)
            if digest(wheel_tmp) != PINNED_FFMPEG_SHA256:
                raise ValueError("Pinned wheel SHA256 mismatch; refusing executable")
            with zipfile.ZipFile(wheel_tmp) as archive:
                binaries = [item for item in archive.infolist()
                            if item.filename.startswith("imageio_ffmpeg/binaries/ffmpeg-")
                            and item.filename.endswith(".exe")
                            and 1024 * 1024 < item.file_size < 160 * 1024 * 1024]
                if len(binaries) != 1:
                    raise ValueError("Pinned wheel contains no unique Windows FFmpeg executable")
                with tempfile.NamedTemporaryFile(dir=cache, suffix=".exe",
                                                 delete=False) as temporary:
                    exe_tmp = pathlib.Path(temporary.name)
                    with archive.open(binaries[0]) as source:
                        shutil.copyfileobj(source, temporary, 1024 * 1024)
            exe_digest = digest(exe_tmp)
            # Atomic publish: no partially downloaded or extracted codec is reusable.
            os.replace(exe_tmp, exe)
            exe_tmp = None
            with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8",
                                             dir=cache, suffix=".json",
                                             delete=False) as temporary:
                manifest_tmp = pathlib.Path(temporary.name)
                json.dump({"wheel_sha256": PINNED_FFMPEG_SHA256,
                           "executable_sha256": exe_digest}, temporary)
            os.replace(manifest_tmp, manifest)
            manifest_tmp = None
            print("NATIVE_PROOF_ENCODER_PINNED_CACHED wheel_sha256=" +
                  PINNED_FFMPEG_SHA256 + " executable_sha256=" + exe_digest, flush=True)
            return str(exe)
        finally:
            for temp in (wheel_tmp, exe_tmp, manifest_tmp):
                if temp is not None:
                    temp.unlink(missing_ok=True)
    except (OSError, ValueError, KeyError, json.JSONDecodeError,
            zipfile.BadZipFile) as error:
        print("NATIVE_PROOF_ENCODER_PROVISION_BLOCKED " +
              type(error).__name__ + ": " + str(error)[:350], flush=True)
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native-root", type=pathlib.Path, required=True)
    parser.add_argument("--output-dir", type=pathlib.Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--fps", type=int, choices=(6, 8, 10, 12), default=8)
    parser.add_argument("--ffmpeg", default=None)
    args = parser.parse_args()
    if not re.fullmatch("[0-9a-f]{40}", args.source_sha):
        parser.error("Exact immutable source SHA required")
    native = args.native_root.resolve()
    report_file = native / "manifest.json"
    if not report_file.is_file():
        parser.error("No original Factorio GUI screenshot manifest; refusing fabricated proof")
    report = json.loads(report_file.read_text(encoding="utf-8-sig"))
    if (report.get("status") not in ("PASS", "FAIL") or report.get("native") is not True
            or report.get("no_scripted_damage") is not True):
        parser.error("No authentic Factorio combat PASS or FAIL receipt")
    # Report the engine verdict even if the host has no media codecs.
    # Never mistake a successful 48-frame screenshot sequence for gameplay PASS.
    print("NATIVE_COMBAT_ENGINE_VERDICT " + json.dumps({
        "status": report["status"],
        "blockers": report.get("blockers", []),
        "samples": report.get("samples", 0),
        "damage": report.get("damage", {}),
        "hits": report.get("hits", {}),
    }), flush=True)
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        parser.error("Evidence output folder must be empty; no replacing historic proof")
    ffmpeg = args.ffmpeg or shutil.which("ffmpeg")
    if not ffmpeg:
        # The Windows homebrew runner may have FFmpeg installed but omitted
        # from PATH. Read only known local executable locations; never install.
        candidates = (
            os.environ.get("FFMPEG_EXE"),
            r"C:\ProgramData\chocolatey\bin\ffmpeg.exe",
            r"C:\ffmpeg\bin\ffmpeg.exe",
            r"D:\ffmpeg\bin\ffmpeg.exe",
            r"C:\tools\ffmpeg\bin\ffmpeg.exe",
        )
        ffmpeg = next((str(pathlib.Path(p)) for p in candidates
                       if p and pathlib.Path(p).is_file()), None)
    if not ffmpeg:
        ffmpeg = pinned_local_ffmpeg()
    try:
        import PIL
        pillow_version = getattr(PIL, "__version__", "present")
    except ImportError:
        pillow_version = None
    print("NATIVE_PROOF_ENCODER_CAPABILITIES " + json.dumps({
        "ffmpeg": ffmpeg, "pillow": pillow_version, "python": sys.executable,
    }), flush=True)
    master = {
        "schema": "tech-priests.native-combat-visual-proof.v1",
        "source_sha": args.source_sha, "native_screenshot_root": str(native),
        "engine_receipt": report,
        "gameplay_accepted": report["status"] == "PASS",
        "status": "native-frame-verified", "clips": {},
    }
    for clip in CLIPS:
        rows = frame_rows(native, clip, report.get("frames", {}).get(clip))
        paths = [pathlib.Path(row["path"]) for row in rows]
        # Exact untouched native screenshot, useful as an inline visual check
        # alongside the derived frame-accurate GIF and MP4.
        poster = output / (clip + "-native-frame.png")
        shutil.copy2(paths[len(paths) // 2], poster)
        gif = output / (clip + ".gif")
        mp4 = output / (clip + ".mp4")
        gitlog = output / (clip + "-gif-encoder.log")
        videolog = output / (clip + "-video-encoder.log")
        gif_ok = False
        mp4_ok = False
        if ffmpeg:
            source = str(native / clip / "frame-%04d.png")
            gif_ok = run_encode(
                [ffmpeg, "-hide_banner", "-nostdin", "-loglevel", "warning",
                 "-y", "-framerate", str(args.fps), "-i", source,
                 "-filter_complex",
                 "scale=640:-2:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse",
                 "-frames:v", str(len(rows)), str(gif)],
                gif, gitlog)
            mp4_ok = run_encode(
                [ffmpeg, "-hide_banner", "-nostdin", "-loglevel", "warning",
                 "-y", "-framerate", str(args.fps), "-i", source,
                 "-frames:v", str(len(rows)), "-vf", "scale=960:-2:flags=lanczos",
                 "-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p",
                 "-movflags", "+faststart", str(mp4)], mp4, videolog)
        if not gif_ok:
            gif_ok = gif_pillow(paths, gif, args.fps)
        if not gif_ok and gitlog.exists():
            print("NATIVE_PROOF_GIF_ENCODER_ERROR " + clip + " " +
                  repr(gitlog.read_text(encoding="utf-8", errors="replace")[-1400:]),
                  flush=True)
        if not mp4_ok and videolog.exists():
            print("NATIVE_PROOF_MP4_ENCODER_ERROR " + clip + " " +
                  repr(videolog.read_text(encoding="utf-8", errors="replace")[-1400:]),
                  flush=True)
        clip_receipt = {
            "source_kind": "original-factorio-client-png-sequence",
            "frames": len(rows), "fps": args.fps,
            "engine_first_tick": rows[0]["tick"],
            "engine_last_tick": rows[-1]["tick"],
            "simulation_speedup_equivalent": round(
                args.fps * (rows[-1]["tick"] - rows[0]["tick"])
                / max(1, len(rows) - 1) / 60, 3),
            "sources": rows, "gif": None, "mp4": None,
            "native_frame": {"path": str(poster), "sha256": digest(poster),
                             "bytes": poster.stat().st_size,
                             "source_tick": rows[len(rows) // 2]["tick"]},
        }
        if gif_ok:
            clip_receipt["gif"] = {"path": str(gif), "sha256": digest(gif),
                                     "bytes": gif.stat().st_size}
        if mp4_ok:
            clip_receipt["mp4"] = {"path": str(mp4), "sha256": digest(mp4),
                                     "bytes": mp4.stat().st_size}
        master["clips"][clip] = clip_receipt
        print("NATIVE_COMBAT_PROOF " + json.dumps({
            "clip": clip, "frames": len(rows), "gif": gif_ok,
            "mp4": mp4_ok, "source_sha": args.source_sha,
        }), flush=True)
    master["status"] = "all-gif-and-mp4-encoded" if all(
        info["gif"] and info["mp4"] for info in master["clips"].values()) \
        else "partial-media-encoding-blocked"
    result = output / "proof-manifest.json"
    result.write_text(json.dumps(master, indent=2) + "\n", encoding="utf-8")
    print("NATIVE_COMBAT_PROOF_RECEIPT " + json.dumps({
        "status": master["status"], "source_sha": args.source_sha,
        "manifest": str(result), "clips": list(master["clips"]),
    }), flush=True)
    if master["status"] != "all-gif-and-mp4-encoded":
        raise SystemExit("Missing actual GIF/MP4; do not call visual proof delivered")


if __name__ == "__main__":
    main()
