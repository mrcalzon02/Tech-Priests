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
import pathlib
import re
import shutil
import struct
import subprocess
import sys

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
        w, h = png_header(path)
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
    if (report.get("status") != "PASS" or report.get("native") is not True
            or report.get("no_scripted_damage") is not True):
        parser.error("Fixture did not report genuine native combat PASS")
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        parser.error("Evidence output folder must be empty; no replacing historic proof")
    ffmpeg = args.ffmpeg or shutil.which("ffmpeg")
    master = {
        "schema": "tech-priests.native-combat-visual-proof.v1",
        "source_sha": args.source_sha, "native_screenshot_root": str(native),
        "engine_receipt": report,
        "status": "native-frame-verified", "clips": {},
    }
    for clip in CLIPS:
        rows = frame_rows(native, clip, report.get("frames", {}).get(clip))
        paths = [pathlib.Path(row["path"]) for row in rows]
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
        clip_receipt = {
            "source_kind": "original-factorio-client-png-sequence",
            "frames": len(rows), "fps": args.fps,
            "engine_first_tick": rows[0]["tick"],
            "engine_last_tick": rows[-1]["tick"],
            "sources": rows, "gif": None, "mp4": None,
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
