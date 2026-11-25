#!/usr/bin/env python3
"""Prepare the nine existing Tech Priests HD mods for separate publication.

Downloads are pinned to the successful original graphics release and checked
against its SHA-256 receipt. Every original ZIP payload except info.json is
copied and verified byte-for-byte. Publication thumbnails and source-art
previews are made only from original sprites; native screenshots remain
separately attributed. No artwork is generated and no network writes occur.
"""
from __future__ import annotations

import argparse
from collections import Counter
import concurrent.futures
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import threading
import time
import urllib.request
import zipfile

from PIL import Image, ImageDraw, ImageFont, ImageOps

SOURCE_COMMIT = "f810fafccef156b4ca863b8bdf98460acf98ebb5"
SOURCE_TAG = "v1.0.0-graphics-" + SOURCE_COMMIT
SOURCE_URL = "https://github.com/mrcalzon02/Tech-Priests"
RELEASE_URL = SOURCE_URL + "/releases/tag/" + SOURCE_TAG
DOWNLOAD_BASE = SOURCE_URL + "/releases/download/" + SOURCE_TAG + "/"
RECEIPT_SHA256 = "23b59e7f20ff79a5f57140e673828eeeec866b91f1ce0d20f341f0817ad6a5b3"
VERSION = "1.0.0"
LIMIT = 262_100_000
ZIP_TIME = (2026, 11, 25, 0, 0, 0)
PRINT_LOCK = threading.Lock()


def log(*args):
    with PRINT_LOCK:
        print(*args, flush=True)


def hashes(path):
    sha1, sha256 = hashlib.sha1(), hashlib.sha256()
    with Path(path).open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            sha1.update(chunk)
            sha256.update(chunk)
    return {"sha1": sha1.hexdigest(), "sha256": sha256.hexdigest()}


def download(url, path, expected_sha256, expected_bytes=None):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and (expected_bytes is None or path.stat().st_size == expected_bytes):
        if hashes(path)["sha256"] == expected_sha256:
            log("SOURCE_CACHED", path.name)
            return path
    part = path.with_name(path.name + ".part")
    for attempt in range(3):
        try:
            log("SOURCE_DOWNLOAD", path.name, "attempt", attempt + 1)
            request = urllib.request.Request(url, headers={"User-Agent": "Tech-Priests-HD-publication/1.0"})
            sha = hashlib.sha256()
            size = 0
            with urllib.request.urlopen(request, timeout=90) as response, part.open("wb") as out:
                while chunk := response.read(1024 * 1024):
                    out.write(chunk)
                    sha.update(chunk)
                    size += len(chunk)
            if expected_bytes is not None and size != expected_bytes:
                raise ValueError(f"Download length differs for {path.name}: {size}")
            if sha.hexdigest() != expected_sha256:
                raise ValueError(f"Source hash differs for {path.name}")
            part.replace(path)
            log("SOURCE_VERIFIED", path.name, size, expected_sha256)
            return path
        except Exception as error:
            log("SOURCE_RETRY", path.name, type(error).__name__, str(error)[:180])
            if attempt == 2:
                raise
            time.sleep(2 ** attempt)
    raise AssertionError("unreachable")


def fixed_info(name, compressed=False):
    result = zipfile.ZipInfo(name, ZIP_TIME)
    result.create_system = 3
    result.external_attr = 0o644 << 16
    result.compress_type = zipfile.ZIP_DEFLATED if compressed else zipfile.ZIP_STORED
    return result


def font(size):
    # Pillow's bundled font keeps hosted and local rendering independent of
    # whatever font packages happen to be installed on a runner.
    return ImageFont.load_default(size=size)


def fit_lines(draw, value, max_width, size, maximum=2):
    value = value.replace("—", "-").replace("–", "-")
    words = value.split()
    lines = []
    for word in words:
        if not lines or draw.textlength(lines[-1] + " " + word, font=font(size)) > max_width:
            lines.append(word)
        else:
            lines[-1] += " " + word
    if len(lines) > maximum:
        return fit_lines(draw, value, max_width, size - 2, maximum)
    return lines, size


def representative_frame(archive, member, entry):
    with Image.open(io.BytesIO(archive.read(member))) as source:
        image = source.convert("RGBA")
    fw, fh = entry.get("frame_width", image.width), entry.get("frame_height", image.height)
    columns, rows = image.width // fw, image.height // fh
    if columns < 1 or rows < 1:
        raise ValueError("Invalid authoritative frame geometry: " + entry["path"])
    # Choose the clearest among the first sixteen existing animation frames.
    # All pixels are copied from the source sheet; no parts are synthesized.
    frames = []
    for index in range(min(columns * rows, 16)):
        col, row = index % columns, index // columns
        frame = image.crop((col * fw, row * fh, (col + 1) * fw, (row + 1) * fh))
        alpha = frame.getchannel("A")
        bbox = alpha.getbbox()
        if bbox:
            frames.append((sum(alpha.histogram()[1:]), index, frame.crop(bbox)))
    if not frames:
        raise ValueError("Selected source frame is empty: " + entry["path"])
    _, index, result = max(frames, key=lambda value: (value[0], -value[1]))
    return result, index


def make_art_preview(source_zip, entries, item, thumbnail_path, preview_path):
    by_path = {entry["path"]: entry for entry in entries}
    selected = []
    for selector in item["artwork"]:
        matches = [entry for path, entry in by_path.items() if re.search(selector["pattern"], path)]
        if not matches:
            raise ValueError(f"No source sprite matches {item['name']}: {selector['pattern']}")
        selected.append((sorted(matches, key=lambda entry: entry["path"])[0], selector["label"]))
    preview = Image.new("RGB", (1600, 1100), "#0d1117")
    draw = ImageDraw.Draw(preview)
    number = item["name"].rsplit("-", 1)[1]
    draw.text((52, 35), "TECH PRIESTS", fill="#f4ecd9", font=font(44))
    draw.text((52, 95), "HD " + number + " / 09  ·  " + item["label"], fill="#d8ae61", font=font(34))
    draw.text((52, 151), "Original game artwork · source sprite preview", fill="#aab3c2", font=font(25))
    provenance = []
    frames = []
    with zipfile.ZipFile(source_zip) as archive:
        root = f"{item['name']}_{VERSION}/"
        for index, (entry, label) in enumerate(selected):
            frame, frame_index = representative_frame(archive, root + entry["path"], entry)
            frames.append(frame)
            col, row = index % 3, index // 3
            left, top = 40 + col * 520, 212 + row * 390
            draw.rounded_rectangle((left, top, left + 500, top + 366), radius=18,
                                   fill="#171e28", outline="#303c4b", width=2)
            fitted = ImageOps.contain(frame, (448, 288), Image.Resampling.NEAREST)
            preview.paste(fitted, (left + (500 - fitted.width) // 2,
                                  top + 16 + (288 - fitted.height) // 2), fitted)
            lines, text_size = fit_lines(draw, label, 460, 25)
            for line_index, line in enumerate(lines):
                draw.text((left + 20, top + 310 + 27 * line_index), line,
                          fill="#e2e6ec", font=font(text_size))
            provenance.append({"path": entry["path"], "source_sha256": entry["source_sha256"],
                               "frame": frame_index, "label": label,
                               "frame_width": entry.get("frame_width"),
                               "frame_height": entry.get("frame_height")})
    draw.text((52, 1035), "Part of the nine-pack HD collection · Requires Tech Priests",
              fill="#aab3c2", font=font(24))
    preview_path.parent.mkdir(parents=True, exist_ok=True)
    preview.save(preview_path, format="PNG", optimize=False, compress_level=9)

    thumbnail = Image.new("RGB", (512, 512), "#0d1117")
    td = ImageDraw.Draw(thumbnail)
    td.text((24, 20), "TECH PRIESTS", fill="#f4ecd9", font=font(34))
    td.text((24, 66), "HD " + number, fill="#d8ae61", font=font(48))
    featured = ImageOps.contain(frames[0], (400, 290), Image.Resampling.NEAREST)
    thumbnail.paste(featured, ((512 - featured.width) // 2, 132 + (290 - featured.height) // 2), featured)
    lines, text_size = fit_lines(td, item["label"], 464, 26)
    for index, line in enumerate(lines):
        td.text((24, 436 + index * 29), line, fill="#e2e6ec", font=font(text_size))
    thumbnail.save(thumbnail_path, format="PNG", optimize=False, compress_level=9)
    return provenance


def page_text(item, caption, artwork_is_primary):
    text = (
        "# " + item["title"] + "\n\n"
        + item["coverage"] + "\n\n"
        "This is part **" + item["name"].rsplit("-", 1)[1] + " of 9** in the optional Tech Priests HD collection. "
        "Install it alongside [Tech Priests](https://mods.factorio.com/mod/tech-priests). "
        "Install all nine HD packs for the complete original-resolution artwork upgrade. "
        "Some animations and viewing directions span several packs; missing packs retain the standard artwork.\n\n"
        "![" + caption + "]({{SCREENSHOT_URL}})\n\n"
        + caption + "\n\n"
    )
    if not artwork_is_primary:
        text += (
            "## Artwork in this pack\n\n"
            "![Original sprites included in this HD pack]({{ARTWORK_URL}})\n\n"
            "Preview assembled from original sprites included in this download.\n\n"
        )
    text += (
        "## Installation\n\n"
        "Enable Tech Priests and the desired HD packs in Factorio, then restart. "
        "The automatic graphics setting selects available HD artwork. "
        "The complete collection is listed below.\n\n"
        + " · ".join(f"[HD {index:02d}](https://mods.factorio.com/mod/tech-priests-hd-{index:02d})"
                     for index in range(1, 10)) + "\n\n"
        "Original artwork credits and notices are included in the download.\n"
    )
    return text


def prepare_pack(pack, assets, catalog, cache, output):
    name = pack["name"]
    item = catalog[name]
    source_zip = cache / pack["filename"]
    target_zip = output / pack["filename"]
    root = f"{name}_{VERSION}/"
    media = output / "media"
    pages = output / "pages"
    media.mkdir(parents=True, exist_ok=True)
    pages.mkdir(parents=True, exist_ok=True)
    thumbnail = media / f"{name}-thumbnail.png"
    artwork = media / f"{name}-artwork.png"
    provenance = make_art_preview(source_zip, assets, item, thumbnail, artwork)
    preview = media / f"{name}-preview.png"
    screenshot = item.get("screenshot")
    if screenshot:
        original = download(screenshot["url"], cache / "media" / screenshot["file"],
                            screenshot["sha256"], screenshot.get("bytes"))
        if screenshot.get("crop"):
            with Image.open(original) as opened:
                crop = screenshot["crop"]
                if not (0 <= crop[0] < crop[2] <= opened.width and 0 <= crop[1] < crop[3] <= opened.height):
                    raise ValueError("Screenshot crop is outside original capture")
                opened.crop(tuple(crop)).save(preview, format="PNG", optimize=False, compress_level=9)
        else:
            shutil.copyfile(original, preview)
        caption = screenshot["caption"]
        image_kind = "native-factorio-screenshot"
    else:
        shutil.copyfile(artwork, preview)
        caption = "Original Tech Priests game artwork included in HD " + name.rsplit("-", 1)[1] + ". Source sprite preview."
        image_kind = "original-sprite-preview"
    description = pages / f"{name}.md"
    description.write_text(page_text(item, caption, screenshot is None), encoding="utf-8")
    original_hashes = {}
    with zipfile.ZipFile(source_zip) as source, zipfile.ZipFile(target_zip, "w", allowZip64=True,
                                                              compression=zipfile.ZIP_DEFLATED,
                                                              compresslevel=6) as target:
        names = source.namelist()
        if len(names) != len(set(names)) or any(not member.startswith(root) for member in names):
            raise ValueError("Source ZIP has inconsistent mod root: " + name)
        old_info = json.loads(source.read(root + "info.json"))
        if old_info["name"] != name or old_info["version"] != VERSION:
            raise ValueError("Source metadata identity differs: " + name)
        info = dict(old_info, title=item["title"], description=item["summary"])
        if info["dependencies"] != old_info["dependencies"]:
            raise AssertionError("Dependency preservation failed")
        if any("tech-priests" in dependency for dependency in info["dependencies"]):
            raise ValueError("HD-to-gameplay dependency would create a cycle")
        for member in source.infolist():
            if member.is_dir():
                continue
            relative = member.filename[len(root):]
            if relative == "info.json":
                target.writestr(fixed_info(member.filename, True),
                                (json.dumps(info, indent=2, ensure_ascii=False) + "\n").encode("utf-8"),
                                compresslevel=6)
                continue
            if relative == "thumbnail.png":
                raise ValueError("Unexpected pre-existing thumbnail requires explicit handling")
            digest = hashlib.sha256()
            with source.open(member) as inp, target.open(fixed_info(member.filename,
                                                       member.compress_type != zipfile.ZIP_STORED), "w",
                                                       force_zip64=True) as out:
                while chunk := inp.read(1024 * 1024):
                    digest.update(chunk)
                    out.write(chunk)
            original_hashes[relative] = digest.hexdigest()
        target.writestr(fixed_info(root + "thumbnail.png"), thumbnail.read_bytes())
    if target_zip.stat().st_size > LIMIT:
        raise ValueError("Prepared ZIP exceeds portal ceiling: " + name)
    verified = 0
    with zipfile.ZipFile(target_zip) as archive:
        expected_names = {root + name for name in original_hashes} | {root + "info.json", root + "thumbnail.png"}
        if set(archive.namelist()) != expected_names:
            raise ValueError("Prepared ZIP inventory differs: " + name)
        for relative, expected in original_hashes.items():
            digest = hashlib.sha256()
            with archive.open(root + relative) as member:
                while chunk := member.read(1024 * 1024):
                    digest.update(chunk)
            if digest.hexdigest() != expected:
                raise ValueError("Original payload changed: " + name + "/" + relative)
            verified += 1
        packaged = json.loads(archive.read(root + "info.json"))
        if packaged != info:
            raise ValueError("Prepared metadata differs: " + name)
        if archive.read(root + "thumbnail.png") != thumbnail.read_bytes():
            raise ValueError("Packaged thumbnail differs: " + name)
        with Image.open(io.BytesIO(archive.read(root + "thumbnail.png"))) as image:
            image.load()
            if image.size != (512, 512):
                raise ValueError("Thumbnail geometry differs: " + name)
    payload_pngs = {path: digest for path, digest in original_hashes.items() if path.endswith(".png")}
    expected_pngs = {asset["path"]: asset["source_sha256"] for asset in assets}
    if payload_pngs != expected_pngs:
        raise ValueError("Receipt artwork inventory/hash differs: " + name)
    record = {
        "name": name, "version": VERSION, "title": info["title"], "summary": info["description"],
        "file_name": target_zip.name, "bytes": target_zip.stat().st_size, **hashes(target_zip),
        "factorio_version": info["factorio_version"], "dependencies": info["dependencies"],
        "category": "tweaks", "description_file": description.relative_to(output).as_posix(),
        "image_file": preview.relative_to(output).as_posix(), "image_caption": caption,
        "image_kind": image_kind, "image_sha256": hashes(preview)["sha256"],
        "thumbnail_file": thumbnail.relative_to(output).as_posix(),
        "thumbnail_sha256": hashes(thumbnail)["sha256"],
        "artwork_file": artwork.relative_to(output).as_posix(), "artwork_sha256": hashes(artwork)["sha256"],
        "image_source": screenshot, "artwork_source_frames": provenance,
        "source_asset_sha256": pack["sha256"], "source_asset_bytes": pack["bytes"],
        "source_asset_url": DOWNLOAD_BASE + pack["filename"], "source_commit": SOURCE_COMMIT,
        "preserved_payload_files": verified, "preserved_artwork_files": len(payload_pngs),
        "all_original_payloads_preserved": True, "size_cap_pass": True, "archive_crc_pass": True,
    }
    log("HD_PUBLICATION_READY", name, record["bytes"], record["sha256"], "preserved", verified)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--version", default=VERSION)
    parser.add_argument("--catalog", type=Path, default=Path(__file__).with_name("hd_publication_catalog.json"))
    parser.add_argument("--download-workers", type=int, default=3)
    args = parser.parse_args()
    if args.version != VERSION:
        parser.error("This source-bound preparation preserves version " + VERSION)
    if not 1 <= args.download_workers <= 4:
        parser.error("Download workers must be between one and four")
    cache, output = args.cache.resolve(), args.output.resolve()
    if cache == output or cache in output.parents or output in cache.parents:
        parser.error("Cache and publication output must be separate directories")
    cache.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    receipt_path = download(DOWNLOAD_BASE + "graphics-pack-receipt.json",
                            cache / "graphics-pack-receipt.json", RECEIPT_SHA256)
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    if receipt["source_commit"] != SOURCE_COMMIT or receipt["version"] != VERSION or len(receipt["packs"]) != 9:
        raise ValueError("Unexpected original graphics release receipt")
    catalog_data = json.loads(args.catalog.read_text(encoding="utf-8"))
    catalog = {item["name"]: item for item in catalog_data["packs"]}
    if set(catalog) != {pack["name"] for pack in receipt["packs"]}:
        raise ValueError("Publication catalog must match all nine original packs")
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.download_workers) as pool:
        futures = [pool.submit(download, DOWNLOAD_BASE + pack["filename"], cache / pack["filename"],
                               pack["sha256"], pack["bytes"]) for pack in receipt["packs"]]
        for future in concurrent.futures.as_completed(futures):
            future.result()
    result = []
    for pack in receipt["packs"]:
        entries = [asset for asset in receipt["assets"] if asset.get("hd_mod") == pack["name"]]
        result.append(prepare_pack(pack, entries, catalog, cache, output))
    manifest = {
        "schema": "tech-priests.hd-publication.v1", "version": VERSION,
        "source_commit": SOURCE_COMMIT, "source_release_url": RELEASE_URL,
        "source_receipt_sha256": RECEIPT_SHA256, "source_url": SOURCE_URL,
        "base_mod_url": "https://mods.factorio.com/mod/tech-priests", "max_bytes": LIMIT,
        "pack_count": len(result), "packs": result,
        "all_original_payloads_preserved": True,
        "all_packages_under_portal_limit": all(pack["bytes"] <= LIMIT for pack in result),
        "native_engine_launch_performed": False,
    }
    (output / "publication-manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (output / "SHA256SUMS").write_text("".join(f"{pack['sha256']}  {pack['file_name']}\n" for pack in result), encoding="utf-8")
    (output / "SHA1SUMS").write_text("".join(f"{pack['sha1']}  {pack['file_name']}\n" for pack in result), encoding="utf-8")
    index = Image.new("RGB", (1536, 1536), "#0d1117")
    for position, pack in enumerate(result):
        with Image.open(output / pack["thumbnail_file"]) as thumbnail:
            index.paste(thumbnail.convert("RGB"), ((position % 3) * 512, (position // 3) * 512))
    index.save(output / "hd-preview-index.png", format="PNG", optimize=False, compress_level=9)
    log("ALL_NINE_HD_MODS_PREPARED", output / "publication-manifest.json")


if __name__ == "__main__":
    main()
