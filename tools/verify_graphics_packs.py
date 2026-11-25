#!/usr/bin/env python3
"""Verify installable LO/HD ZIP contents against original production artwork.

This is a package-integrity and graphics-layout check. It deliberately does
not label itself a native Factorio launch or graphical atlas test.
"""
from __future__ import annotations

import argparse
from collections import Counter
from contextlib import ExitStack
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import struct
import zipfile

from graphics_pack_layouts import fixed_layouts, special_layouts


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha256_file(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def dimensions(data, label):
    require(len(data) >= 24 and data[:8] == b"\x89PNG\r\n\x1a\n", f"Invalid PNG: {label}")
    return struct.unpack(">II", data[16:24])


def inspect_zip(archive: zipfile.ZipFile, path: Path, limit: int):
    require(path.stat().st_size <= limit, f"Archive exceeds {limit} bytes: {path.name}")
    names = archive.namelist()
    require(len(names) == len(set(names)), f"Duplicate ZIP member: {path.name}")
    require(len(names) == len({n.casefold() for n in names}), f"Case-insensitive path collision: {path.name}")
    require(all(not PurePosixPath(n).is_absolute() and ".." not in PurePosixPath(n).parts
                and "\\" not in n for n in names), f"Unsafe ZIP path: {path.name}")
    infos = [name for name in names if name.count("/") == 1 and name.endswith("/info.json")]
    require(len(infos) == 1, f"Expected one installable mod root: {path.name}")
    root = infos[0][:-len("info.json")]
    require(all(n.startswith(root) for n in names), f"Files outside mod root: {path.name}")
    info = json.loads(archive.read(infos[0]))
    require(root == f'{info["name"]}_{info["version"]}/', f"Mod directory/version mismatch: {path.name}")
    require(path.name == root[:-1] + ".zip", f"Mod ZIP filename mismatch: {path.name}")
    require(archive.testzip() is None, f"CRC failure: {path.name}")
    return info, root, {n[len(root):]: n for n in names if not n.endswith("/")}


def verify(source: Path, output: Path, max_bytes: int = 262_100_000):
    receipt_path = output / "graphics-pack-receipt.json"
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    assets = receipt["assets"]
    require(isinstance(assets, list), "receipt.assets must be a list")
    by_path = {item["path"]: item for item in assets}
    require(len(by_path) == len(assets), "Duplicate asset receipt path")
    source_pngs = {p.relative_to(source).as_posix(): p for p in source.rglob("*.png")}
    known_layouts = fixed_layouts(source) | special_layouts(source)
    all_archives = sorted(output.glob("*.zip"))
    require(all_archives, "No output mod ZIPs")
    counts = Counter()
    archive_reports = []
    with ExitStack() as stack:
        mods = {}
        for path in all_archives:
            archive = stack.enter_context(zipfile.ZipFile(path))
            info, prefix, members = inspect_zip(archive, path, max_bytes)
            require(info["name"] not in mods, f'Duplicate mod: {info["name"]}')
            mods[info["name"]] = (archive, info, prefix, members)
            digest = sha256_file(path)
            archive_reports.append({"name": info["name"], "filename": path.name,
                                    "bytes": path.stat().st_size, "sha256": digest})
        require("tech-priests" in mods, "Missing standalone tech-priests ZIP")
        base, info, prefix, members = mods["tech-priests"]
        version = info["version"]
        for dependency in info.get("dependencies", []):
            if "tech-priests-hd" in dependency:
                require(dependency.lstrip().startswith("?"), f"HD pack required by base: {dependency}")
        base_pngs = {name for name in members if name.lower().endswith(".png")}
        require(base_pngs == set(source_pngs),
                f"Base PNG paths differ: missing={sorted(set(source_pngs)-base_pngs)[:12]}, "
                f"extra={sorted(base_pngs-set(source_pngs))[:12]}")
        require(set(by_path) <= set(source_pngs), "Receipt references nonexistent source images")

        hd_expected = {}
        for index, (relative, path) in enumerate(sorted(source_pngs.items()), 1):
            original = path.read_bytes()
            low = base.read(members[relative])
            old_w, old_h = dimensions(original, relative)
            width, height = dimensions(low, relative)
            counts["source_png_bytes"] += len(original)
            counts["lo_png_bytes"] += len(low)
            counts["source_pixels"] += old_w * old_h
            counts["lo_pixels"] += width * height
            asset = by_path.get(relative)
            if asset is None:
                require(low == original, f"Unrecorded modification: {relative}")
                counts["unchanged_pngs"] += 1
                continue
            require(asset["original_width"] == old_w and asset["original_height"] == old_h,
                    f"Original dimensions do not match receipt: {relative}")
            require(asset["width"] == width and asset["height"] == height,
                    f"LO dimensions do not match receipt: {relative}")
            require(asset["before"] == len(original) and asset["after"] == len(low),
                    f"Byte counts do not match receipt: {relative}")
            require(asset["source_sha256"] == sha256_bytes(original), f"Original hash mismatch: {relative}")
            require(asset["lo_sha256"] == sha256_bytes(low), f"LO hash mismatch: {relative}")
            divisor = asset["divisor"]
            require(isinstance(divisor, int) and divisor >= 1, f"Invalid divisor: {relative}")
            if divisor == 1:
                require((width, height) == (old_w, old_h), f"Unscaled dimensions changed: {relative}")
                counts["unchanged_pngs"] += 1
            else:
                if asset.get("frame_width"):
                    fw, fh = asset["frame_width"], asset["frame_height"]
                    lw, lh = asset["lo_frame_width"], asset["lo_frame_height"]
                    require(old_w % fw == 0 and old_h % fh == 0, f"Original frame grid not integral: {relative}")
                    require(lw == math.ceil(fw/divisor) and lh == math.ceil(fh/divisor),
                            f"LO frame dimensions wrong: {relative}")
                    require((width, height) == (old_w//fw*lw, old_h//fh*lh), f"LO frame grid changed: {relative}")
                    expected = known_layouts.get(relative)
                    if expected:
                        require((fw, fh) == (expected["frame_width"], expected["frame_height"]),
                                f"Production frame metadata mismatch: {relative}")
                    counts["frame_layouts_checked"] += 1
                    if fw % divisor or fh % divisor:
                        counts["padded_layouts_checked"] += 1
                else:
                    require(old_w % divisor == 0 and old_h % divisor == 0, f"Nonintegral image reduction: {relative}")
                    require((width, height) == (old_w//divisor, old_h//divisor), f"Wrong reduced dimensions: {relative}")
                    expected = known_layouts.get(relative)
                    if expected:
                        require(expected["frame_width"] % divisor == 0 and expected["frame_height"] % divisor == 0,
                                f"Cropped atlas needs per-frame padding: {relative}")
                counts["reduced_pngs"] += 1
                require(asset.get("hd_mod") and asset.get("hd_path"), f"Original HD copy unassigned: {relative}")
            if asset.get("hd_mod"):
                modname = asset["hd_mod"]
                require(modname in mods, f"Missing HD package: {modname}")
                hd, hd_info, _, hd_members = mods[modname]
                require(hd_info["version"] == version, f"HD/base version mismatch: {modname}")
                # Resource packs depend on Factorio base. The gameplay mod's
                # optional dependency orders packs first; requiring gameplay
                # from the pack would introduce a dependency cycle.
                require(any(dep.lstrip().startswith("base") for dep in hd_info.get("dependencies", [])),
                        f"HD pack has no Factorio base dependency: {modname}")
                require(any(dep.lstrip().startswith("?") and modname in dep
                            for dep in info.get("dependencies", [])),
                        f"Gameplay mod has no optional dependency on pack: {modname}")
                hd_relative = asset["hd_path"]
                require(hd_relative in hd_members, f"Missing original HD asset: {modname}/{hd_relative}")
                require(hd.read(hd_members[hd_relative]) == original, f"HD artwork changed: {relative}")
                hd_expected.setdefault(modname, set()).add(hd_relative)
                counts["original_hd_pngs_checked"] += 1
            if index % 500 == 0:
                print("GRAPHICS_VERIFY_PROGRESS", index, len(source_pngs), flush=True)

        for name, (archive, _, _, hd_members) in mods.items():
            if name == "tech-priests":
                continue
            actual = {p for p in hd_members if p.lower().endswith(".png") and p != "thumbnail.png"}
            require(actual == hd_expected.get(name, set()), f"HD inventory differs from manifest: {name}")
        for pack in receipt.get("packs", []):
            actual = next((a for a in archive_reports if a["name"] == pack["name"]), None)
            require(actual is not None, f'Missing recorded pack: {pack["name"]}')
            for key in ("filename", "bytes", "sha256"):
                require(pack[key] == actual[key], f'Pack {key} mismatch: {pack["name"]}')
            require(pack["asset_count"] == len(hd_expected.get(pack["name"], set())),
                    f'Pack asset count mismatch: {pack["name"]}')

    require(counts["lo_png_bytes"] * 3 <= counts["source_png_bytes"], "LO graphics exceed one third of original bytes")
    require(counts["reduced_pngs"] > 0 and counts["original_hd_pngs_checked"] > 0, "No LO/HD separation occurred")
    return {"package_verification_pass": True, "native_factorio_launch_checked": False,
            "graphical_atlas_checked": False, "max_archive_bytes": max_bytes,
            "source_png_count": len(source_pngs), **dict(counts),
            "lo_bytes_ratio": counts["lo_png_bytes"] / counts["source_png_bytes"],
            "lo_pixel_ratio": counts["lo_pixels"] / counts["source_pixels"],
            "archives": archive_reports}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path("tech-priests_src"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--max-bytes", type=int, default=262_100_000)
    args = parser.parse_args()
    result = verify(args.source.resolve(), args.output.resolve(), args.max_bytes)
    report = args.output / "graphics-pack-verification.json"
    report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
