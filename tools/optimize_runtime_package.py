#!/usr/bin/env python3
"""Build a separate, size-capped Factorio distribution candidate.

Never mutate the source tree, publish a release, or guess that dynamically
referenced assets are unused. Preserve dimensions, frame layout and filenames.
Requires Pillow in the existing local Python environment. Palette conversion
is opt-in and must receive native visual acceptance before publication.
"""
from __future__ import annotations
import argparse
import concurrent.futures
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import tempfile
import zipfile

LIMIT = 262_100_000  # conservative interpretation of the portal's 262.1 MB
SKIP_DIRS = {".git", ".github", "__pycache__", ".pytest_cache", ".mypy_cache",
             ".ruff_cache", "node_modules", "build", "dist"}
SKIP_SUFFIXES = {".pyc", ".pyo", ".tmp", ".bak", ".log", ".zip"}
SKIP_FILES = {"MIGRATION_TEST_ONLY.json", ".DS_Store", "Thumbs.db"}
# Documentation only; leave credits, licenses and notices intact.
DEV_ONLY = {"docs/DEVELOPMENT_HISTORY.md", "docs/CURRENT_TESTING_GOALS.md"}

def encode_png(image):
    buf = io.BytesIO()
    image.save(buf, format="PNG", optimize=True, compress_level=9)
    return buf.getvalue()

def optimize_one(task):
    from PIL import Image, ImageChops, ImageStat, features
    source, target, palette, error_limit = task
    original = Path(source).read_bytes()
    best = original
    method = "original"
    error = 0.0
    with Image.open(io.BytesIO(original)) as image:
        # Animated/multi-frame PNG and unusual formats remain untouched.
        if getattr(image, "n_frames", 1) != 1 or image.mode not in {"RGBA", "RGB", "P", "L", "LA"}:
            Path(target).write_bytes(original)
            return len(original), len(original), method, error
        reference = image.convert("RGBA")
        # Keep profile-bearing assets unchanged unless lossless encoding preserves
        # their rendered pixel values and metadata; conservative skip for now.
        if not any(k in image.info for k in ("icc_profile", "gamma", "chromaticity", "srgb", "exif")):
            lossless = encode_png(image)
            with Image.open(io.BytesIO(lossless)) as check:
                if check.size == image.size and not any(ImageChops.difference(reference, check.convert("RGBA")).getextrema()[i][1] for i in range(4)):
                    if len(lossless) < len(best):
                        best, method = lossless, "lossless"
            if palette and image.mode != "P":
                quantizer = (Image.Quantize.LIBIMAGEQUANT if features.check_feature("libimagequant")
                             else Image.Quantize.FASTOCTREE)
                for colors in (256, 128, 64):
                    indexed = reference.quantize(colors=colors, method=quantizer, dither=Image.Dither.NONE)
                    candidate = encode_png(indexed)
                    if len(candidate) >= len(best):
                        continue
                    with Image.open(io.BytesIO(candidate)) as check:
                        rgba = check.convert("RGBA")
                        if rgba.size != reference.size:
                            continue
                        # Reject introduced visible pixels in previously fully
                        # transparent areas. Also bound alpha and composited RGB
                        # mean error, with both dark and light backgrounds.
                        old_a, new_a = reference.getchannel("A"), rgba.getchannel("A")
                        zero_mask = old_a.point([255] + [0] * 255)
                        if ImageChops.multiply(zero_mask, new_a).getextrema()[1]:
                            continue
                        errors = ImageStat.Stat(ImageChops.difference(old_a, new_a)).mean
                        for background in ((0,0,0,255), (255,255,255,255)):
                            bg = Image.new("RGBA", reference.size, background)
                            a = Image.alpha_composite(bg, reference).convert("RGB")
                            b = Image.alpha_composite(bg, rgba).convert("RGB")
                            errors.extend(ImageStat.Stat(ImageChops.difference(a,b)).mean)
                        worst = max(errors)
                        if worst <= error_limit:
                            best, method, error = candidate, "palette-" + str(colors), worst
    Path(target).write_bytes(best)
    return len(original), len(best), method, error

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source", type=Path, default=Path("tech-priests_src"))
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--version", help="Candidate metadata version; source stays unchanged")
    p.add_argument("--max-bytes", type=int, default=LIMIT)
    p.add_argument("--palette", action="store_true", help="Allow bounded lossy color quantization")
    p.add_argument("--mean-error", type=float, default=2.0)
    p.add_argument("--workers", type=int, default=2)
    args = p.parse_args()
    from PIL import Image  # fail before any work if dependency unavailable
    root, output = args.source.resolve(), args.output.resolve()
    if output == root or root in output.parents:
        p.error("output must be outside the runtime source tree")
    if args.max_bytes <= 0 or not 0 <= args.mean_error <= 8 or not 1 <= args.workers <= 8:
        p.error("invalid limit, error bound or worker count")
    if output.exists():
        p.error("refusing to overwrite an existing candidate")
    output.mkdir(parents=True)
    info = json.loads((root / "info.json").read_text(encoding="utf-8"))
    if args.version:
        if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", args.version):
            p.error("version must be numeric major.minor.patch")
        info["version"] = args.version
    if info["name"] != "tech-priests":
        p.error("unexpected mod name")
    name = f'{info["name"]}_{info["version"]}'
    files = []
    omitted = []
    for f in sorted(root.rglob("*")):
        if not f.is_file():
            continue
        rel = f.relative_to(root).as_posix()
        if (any(part in SKIP_DIRS for part in f.relative_to(root).parts)
                or f.suffix.lower() in SKIP_SUFFIXES or f.name in SKIP_FILES or rel in DEV_ONLY):
            omitted.append(rel)
        else:
            files.append((f, rel))
    required = {"info.json","control.lua","data.lua","data-updates.lua","data-final-fixes.lua",
                "thumbnail.png","changelog.txt"}
    if not required <= {rel for _, rel in files}:
        raise RuntimeError("missing required mod files")
    if len({rel.casefold() for _,rel in files}) != len(files):
        raise RuntimeError("case-insensitive path collision")
    receipt = {"limit_bytes": args.max_bytes, "source_version": json.loads((root/"info.json").read_text())["version"],
               "candidate_version": info["version"], "omitted": omitted, "native_test_pass": False,
               "visual_acceptance_pass": False, "published": False, "files": []}
    with tempfile.TemporaryDirectory(prefix="tp-opt-", dir=output) as tmp:
        staging = Path(tmp)
        pngs = [(f, rel) for f,rel in files if f.suffix.lower()==".png" and rel!="thumbnail.png"]
        tasks = [(str(f), str(staging/str(i)), args.palette, args.mean_error) for i,(f,rel) in enumerate(pngs)]
        by_rel = {}
        with concurrent.futures.ProcessPoolExecutor(max_workers=args.workers) as pool:
            for i, result in enumerate(pool.map(optimize_one, tasks)):
                by_rel[pngs[i][1]] = (staging/str(i), result)
                if (i+1)%100==0:
                    print("PNG_PROGRESS", i+1, len(tasks), flush=True)
        archive = output / (name+".candidate.zip")
        with zipfile.ZipFile(archive,"x",compression=zipfile.ZIP_DEFLATED,compresslevel=6,allowZip64=True) as z:
            for f, rel in files:
                if rel in by_rel:
                    candidate, (before,after,method,error) = by_rel[rel]
                    data = candidate.read_bytes()
                elif rel=="info.json" and args.version:
                    data = (json.dumps(info,indent=2,ensure_ascii=False)+"\n").encode("utf-8")
                    before,after,method,error = f.stat().st_size,len(data),"metadata",0
                else:
                    data = f.read_bytes()
                    before,after,method,error = len(data),len(data),"original",0
                member = zipfile.ZipInfo(name+"/"+rel,date_time=(1980,1,1,0,0,0))
                member.external_attr=0o644<<16
                z.writestr(member,data,compress_type=zipfile.ZIP_DEFLATED,compresslevel=6)
                receipt["files"].append({"path":rel,"before":before,"after":after,"method":method,"mean_error":error})
        with zipfile.ZipFile(archive) as z:
            if z.testzip() is not None or len(z.namelist()) != len(files):
                raise RuntimeError("candidate archive failed integrity check")
        size=archive.stat().st_size
        receipt.update(archive_bytes=size, size_cap_pass=size<=args.max_bytes,
                       archive_crc_pass=True, sha256=hashlib.file_digest(archive.open("rb"),"sha256").hexdigest())
        if size <= args.max_bytes:
            archive.rename(output/(name+".zip"))
        else:
            archive.rename(output/(name+".oversize.zip"))
        (output/"optimization-receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
        print("SIZE_CAP",size,args.max_bytes,"PASS" if size<=args.max_bytes else "FAIL",flush=True)
        return 0 if size<=args.max_bytes else 2

if __name__ == "__main__":
    raise SystemExit(main())
