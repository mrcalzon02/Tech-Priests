#!/usr/bin/env python3
"""Build the standalone LO mod and byte-exact optional HD graphics packs.

The development tree remains the source of the original artwork. Only the
distribution staging area is resized. No frames, directions, layers or sounds
are removed. Cropped animation frames are padded and resampled individually.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

from graphics_pack_layouts import png_dimensions, special_layouts
from optimize_runtime_package import SKIP_DIRS, SKIP_SUFFIXES, SKIP_FILES, DEV_ONLY

PORTAL_LIMIT = 262_100_000
HD_TARGET = 240_000_000
PREFIX = "__tech-priests__/"
TRANSFORM_VERSION = "lo-frame-lanczos-v1"


def digest(path):
    with Path(path).open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def iter_files(root):
    for file in sorted(root.rglob("*")):
        if not file.is_file():
            continue
        relative = file.relative_to(root)
        if (any(p in SKIP_DIRS for p in relative.parts)
                or file.suffix.lower() in SKIP_SUFFIXES
                or file.name in SKIP_FILES or relative.as_posix() in DEV_ONLY):
            continue
        yield file, relative.as_posix()


def image_plan(root, relative, special, fixed):
    if relative in special:
        return dict(special[relative])
    if relative in fixed:
        return dict(fixed[relative])
    width, height = png_dimensions(root / relative)
    plan = {"original_width": width, "original_height": height,
            "width": width, "height": height, "divisor": 1}
    # No atlas grid is inferred from the PNG's outer dimensions. Uncatalogued
    # images, icons and UI keep their original geometry and readability.
    return plan


def resize_one(task):
    from PIL import Image
    source, target, plan, source_digest = task
    source, target = Path(source), Path(target)
    original_bytes = source.stat().st_size
    signature = hashlib.sha256((TRANSFORM_VERSION + source_digest +
                               json.dumps(plan, sort_keys=True)).encode()).hexdigest()
    cached = target.parent / (signature + ".png")
    if not cached.exists():
        with Image.open(source) as opened:
            if getattr(opened, "n_frames", 1) != 1:
                raise ValueError(f"Animated PNG cannot be treated as a sprite sheet: {source}")
            image = opened.convert("RGBA")
            if image.size != (plan["original_width"], plan["original_height"]):
                raise ValueError(f"Source dimensions changed: {source}")
            if "frame_width" in plan:
                fw, fh = plan["frame_width"], plan["frame_height"]
                lw, lh = plan["lo_frame_width"], plan["lo_frame_height"]
                divisor = plan["divisor"]
                result = Image.new("RGBA", (plan["width"], plan["height"]))
                for row in range(plan["rows"]):
                    for col in range(plan["columns"]):
                        frame = image.crop((col * fw, row * fh, (col + 1) * fw, (row + 1) * fh))
                        if fw != lw * divisor or fh != lh * divisor:
                            padded = Image.new("RGBA", (lw * divisor, lh * divisor))
                            padded.paste(frame, (0, 0))
                            frame = padded
                        frame = frame.resize((lw, lh), Image.Resampling.LANCZOS)
                        result.paste(frame, (col * lw, row * lh))
            else:
                result = image.resize((plan["width"], plan["height"]), Image.Resampling.LANCZOS)
            temporary = cached.with_suffix(".tmp")
            result.save(temporary, format="PNG", compress_level=9, optimize=True)
            with Image.open(temporary) as check:
                check.load()
                if check.size != (plan["width"], plan["height"]):
                    raise ValueError(f"Resized PNG failed dimension verification: {source}")
            temporary.replace(cached)
    return {"cache": str(cached), "before": original_bytes,
            "after": cached.stat().st_size, "lo_sha256": digest(cached)}


def member_info(root, relative, compressed=True):
    info = zipfile.ZipInfo(f"{root}/{relative}", (1980, 1, 1, 0, 0, 0))
    info.external_attr = 0o644 << 16
    info.compress_type = zipfile.ZIP_DEFLATED if compressed else zipfile.ZIP_STORED
    return info


def add_bytes(archive, root, relative, data):
    archive.writestr(member_info(root, relative), data, compresslevel=6)


def add_file(archive, root, relative, path):
    # PNG is already compressed; storing it prevents redundant work and allows
    # the raw-byte HD allocation to guarantee the per-download portal ceiling.
    info = member_info(root, relative, compressed=not relative.lower().endswith(".png"))
    with archive.open(info, "w", force_zip64=True) as out, Path(path).open("rb") as source:
        shutil.copyfileobj(source, out, 1024 * 1024)


def archive_record(path, name):
    with zipfile.ZipFile(path) as archive:
        bad = archive.testzip()
        if bad:
            raise RuntimeError(f"ZIP CRC verification failed: {path}: {bad}")
    return {"name": name, "filename": path.name,
            "bytes": path.stat().st_size, "sha256": digest(path)}


def lua_manifest(assets, packs, version):
    lines = ["-- Generated by tools/build_graphics_packs.py; do not edit.",
             "return {", "  schema_version = 1,", f"  version = {json.dumps(version)},",
             "  packs = {" + ", ".join(json.dumps(p["name"]) for p in packs) + "},", "  assets = {"]
    for entry in assets:
        if entry["divisor"] == 1:
            continue
        values = {k: entry[k] for k in ("divisor", "hd_mod", "hd_path")}
        for key in ("frame_width", "frame_height", "lo_frame_width", "lo_frame_height"):
            if key in entry:
                values[key] = entry[key]
        literal = ", ".join(f"{key} = {json.dumps(value)}" for key, value in values.items())
        lines.append(f"    [{json.dumps(PREFIX + entry['path'])}] = {{{literal}}},")
    lines.extend(["  }", "}", ""])
    return "\n".join(lines).encode()


def build(args):
    root, output = args.source.resolve(), args.output.resolve()
    if output == root or root in output.parents:
        raise ValueError("Output must be outside the original mod source")
    if output.exists() and any(output.iterdir()):
        raise ValueError("Refusing to overwrite a nonempty output directory")
    output.mkdir(parents=True, exist_ok=True)
    cache = output.parent / ".tech-priests-graphics-cache"
    cache.mkdir(exist_ok=True)
    info = json.loads((root / "info.json").read_text(encoding="utf-8"))
    if info.get("name") != "tech-priests":
        raise ValueError("Unexpected mod source")
    version = args.version or info["version"]
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("Factorio requires numeric major.minor.patch")
    files = list(iter_files(root))
    required = {"info.json", "control.lua", "data.lua", "data-final-fixes.lua",
                "prototypes/graphics_pack_quality.lua", "prototypes/graphics_pack_manifest.lua"}
    missing = required - {relative for _, relative in files}
    if missing:
        raise ValueError(f"Required runtime pack support missing: {sorted(missing)}")
    if len({relative.casefold() for _, relative in files}) != len(files):
        raise ValueError("Case-insensitive source path collision")
    special = special_layouts(root)
    try:
        from graphics_pack_layouts import fixed_layouts
        fixed = fixed_layouts(root)
    except ImportError:
        fixed = {}
    assets, tasks, transformed = [], [], []
    for source, relative in files:
        if source.suffix.lower() != ".png":
            continue
        plan = image_plan(root, relative, special, fixed)
        sha = digest(source)
        entry = {"path": relative, **plan, "source_sha256": sha,
                 "before": source.stat().st_size, "after": source.stat().st_size,
                 "lo_sha256": sha}
        assets.append(entry)
        if plan["divisor"] > 1:
            transformed.append(entry)
            tasks.append((str(source), str(cache / "unused.png"), plan, sha))
    print(f"GRAPHICS_PLAN originals={len(assets)} resize={len(tasks)} "
          f"png_bytes={sum(a['before'] for a in assets)} cropped={len(special)}", flush=True)
    staged = {}
    with concurrent.futures.ProcessPoolExecutor(max_workers=args.workers) as pool:
        pending = {pool.submit(resize_one, task): entry for task, entry in zip(tasks, transformed)}
        for count, future in enumerate(concurrent.futures.as_completed(pending), 1):
            entry = pending[future]
            result = future.result()
            staged[entry["path"]] = result.pop("cache")
            entry.update(result)
            if count % 100 == 0 or count == len(tasks):
                print(f"LO_PROGRESS {count}/{len(tasks)}", flush=True)
    source_bytes, lo_bytes = sum(a["before"] for a in assets), sum(a["after"] for a in assets)
    print(f"LO_PNG_BYTES {source_bytes} -> {lo_bytes} ({lo_bytes/source_bytes:.4%})", flush=True)
    if lo_bytes * 3 > source_bytes:
        raise RuntimeError("LO PNG bytes exceed one-third of original PNG bytes")

    # Assign each original exactly once, leaving generous ZIP/metadata overhead.
    packs = []
    for asset in transformed:
        if not packs or packs[-1]["source_bytes"] + asset["before"] > min(HD_TARGET, args.max_bytes - 1_000_000):
            packs.append({"name": f"tech-priests-hd-{len(packs)+1:02d}", "source_bytes": 0, "assets": []})
        pack = packs[-1]
        asset.update(hd_mod=pack["name"], hd_path=asset["path"])
        pack["assets"].append(asset)
        pack["source_bytes"] += asset["before"]
    for pack in packs:
        pack_name = f"{pack['name']}_{version}"
        path = output / f"{pack_name}.zip"
        metadata = {"name": pack["name"], "version": version,
                    "title": f"Tech Priests HD Graphics {pack['name'].rsplit('-',1)[1]}",
                    "author": info.get("author", "christopher vardeman"),
                    "factorio_version": info["factorio_version"],
                    "dependencies": [info["dependencies"][0]],
                    "description": "Optional original-resolution artwork for Tech Priests. Install alongside the standard mod. Available parts are selected automatically; missing parts keep their LO graphics."}
        with zipfile.ZipFile(path, "x", allowZip64=True) as archive:
            add_bytes(archive, pack_name, "info.json", (json.dumps(metadata, indent=2) + "\n").encode())
            add_bytes(archive, pack_name, "README.txt", (
                f"Tech Priests original HD artwork, part {pack['name']}\n"
                f"Use with Tech Priests {version}. Put this ZIP in the Factorio mods folder.\n"
                "The base mod works independently. Other HD parts are optional.\n"
                "Original authorship and licenses are retained from the source mod.\n").encode())
            # Carry all existing source notices with the original artwork.
            for source, relative in files:
                if any(token in source.name.lower() for token in ("license", "licence", "copyright", "credit", "notice")) and source.suffix.lower() != ".png":
                    add_file(archive, pack_name, relative, source)
            for asset in pack["assets"]:
                add_file(archive, pack_name, asset["path"], root / asset["path"])
        pack.update(archive_record(path, pack["name"]))
        pack["asset_count"] = len(pack.pop("assets"))
        if pack["bytes"] > args.max_bytes:
            raise RuntimeError(f"HD part exceeds size cap: {path}")
        print(f"HD_PACK {pack['filename']} {pack['bytes']} bytes", flush=True)

    base_name = f"tech-priests_{version}"
    base_path = output / f"{base_name}.zip"
    packaged_info = {**info, "version": version}
    packaged_info["dependencies"] = [d for d in info["dependencies"] if "tech-priests-hd-" not in d]
    packaged_info["dependencies"].extend("? " + p["name"] for p in packs)
    generated = {
        "info.json": (json.dumps(packaged_info, indent=2) + "\n").encode(),
        "prototypes/graphics_pack_manifest.lua": lua_manifest(assets, packs, version),
    }
    with zipfile.ZipFile(base_path, "x", allowZip64=True) as archive:
        for source, relative in files:
            if relative in generated:
                add_bytes(archive, base_name, relative, generated[relative])
            else:
                add_file(archive, base_name, relative, staged.get(relative, source))
    base = archive_record(base_path, "tech-priests")
    if base["bytes"] > args.max_bytes:
        raise RuntimeError(f"Standard mod exceeds size cap: {base['bytes']} > {args.max_bytes}")
    try:
        commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
        dirty = bool(subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=no"], cwd=root, text=True).strip())
    except (OSError, subprocess.CalledProcessError):
        commit, dirty = None, None
    receipt = {"schema_version": 1, "transform_version": TRANSFORM_VERSION,
               "source_commit": commit, "source_dirty": dirty,
               "source_version": info["version"], "version": version,
               "max_bytes": args.max_bytes, "source_png_bytes": source_bytes,
               "lo_png_bytes": lo_bytes, "lo_fraction": lo_bytes / source_bytes,
               "source_png_count": len(assets), "resized_png_count": len(transformed),
               "source_pixels": sum(a['original_width']*a['original_height'] for a in assets),
               "lo_pixels": sum(a['width']*a['height'] for a in assets),
               "size_cap_pass": True, "one_third_pass": True,
               "archive_crc_pass": True, "native_test_pass": False,
               "base": base, "packs": packs, "assets": assets}
    receipt_path = output / "graphics-pack-receipt.json"
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    checksums = [f"{a['sha256']}  {a['filename']}" for a in [base, *packs]]
    (output / "SHA256SUMS.txt").write_text("\n".join(checksums) + "\n")
    (output / "INSTALL.txt").write_text(
        f"TECH PRIESTS {version}: STANDARD + OPTIONAL HD\n\n"
        f"Install {base['filename']} in the Factorio mods folder.\n"
        "The standard package includes every gameplay sprite at LO resolution and works with no HD packs.\n"
        "To use original-resolution artwork, install the optional tech-priests-hd-*.zip files alongside it.\n"
        "Automatic graphics selection is the default. Missing HD parts use their LO artwork.\n"
        "Choose Standard in the startup graphics setting to use LO even when HD packs are installed.\n"
        "Restart Factorio after changing graphics mods or startup settings.\n\n"
        f"Standard download: {base['bytes']:,} bytes. Original PNGs: {source_bytes:,} bytes.\n"
        f"LO PNGs: {lo_bytes:,} bytes ({lo_bytes/source_bytes:.2%} of originals).\n"
        "All original frame counts, directions, animation timings, shadows and emissions are retained.\n"
        "See graphics-pack-receipt.json and SHA256SUMS.txt for the exact source and package hashes.\n",
        encoding="utf-8")
    print(f"GRAPHICS_PACKS_OK base={base['bytes']} hd_parts={len(packs)} receipt={receipt_path}", flush=True)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path("tech-priests_src"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--version")
    parser.add_argument("--max-bytes", type=int, default=PORTAL_LIMIT)
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()
    if args.max_bytes < 10_000_000 or not 1 <= args.workers <= 8:
        parser.error("Invalid size limit or worker count")
    build(args)


if __name__ == "__main__":
    main()
