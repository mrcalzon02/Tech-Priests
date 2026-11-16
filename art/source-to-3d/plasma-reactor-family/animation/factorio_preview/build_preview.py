"""Package a completed FMPL graphics tree as an installable Factorio 2.1 mod.

Usage: python build_preview.py /path/to/mars-reactor-visuals_1.0.0
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
from zipfile import ZipFile, ZIP_DEFLATED

from PIL import Image

SOURCE = Path(__file__).resolve().parent
CLASSES = {"minoris": 384, "majoris": 512, "maximus": 704}


def check_sheets(target):
    for name, hr_size in CLASSES.items():
        for quality, size in (("hr", hr_size), ("sd", hr_size // 2)):
            for direction in ("north", "east", "south", "west"):
                for role in ("on", "glow", "off", "shadow"):
                    filename = target / "graphics" / quality / name / f"{direction}-{role}.png"
                    with Image.open(filename) as im:
                        n = 4 if role in ("on", "glow") else 1
                        if (im.mode != "RGBA" or im.width % n or im.height % n
                                or im.width > size * n or im.height > size * n):
                            raise ValueError(f"Wrong sprite layout or format in {filename}")
                        im.verify()


def make_icon(target, tier, frames):
    # Icons use one complete on-state frame. Its emitted color, steam and
    # independent cropped runtime layers retain their original registration.
    source = frames / tier / "south" / "01.png"
    folder = target / "graphics" / "icons"
    existing = folder / f"{tier}.png"
    if not source.exists():
        if existing.is_file():
            with Image.open(existing) as im:
                if im.mode == "RGBA" and im.size == (64, 64):
                    return
        raise FileNotFoundError(f"Supply --frames containing {source} to render the item icon")
    with Image.open(source) as im:
        combined = im.convert("RGBA")
    visible = combined.getchannel("A").point(lambda value: 255 if value > 15 else 0)
    bounds = visible.getbbox()
    if not bounds:
        raise ValueError(f"Empty south view in {tier}")
    sprite = combined.crop(bounds)
    sprite.thumbnail((60, 60), Image.Resampling.LANCZOS)
    icon = Image.new("RGBA", (64, 64))
    icon.alpha_composite(sprite, ((64 - sprite.width) // 2, (64 - sprite.height) // 2))
    folder.mkdir(parents=True, exist_ok=True)
    icon.save(folder / f"{tier}.png")


def build(target, frames=None):
    target = target.resolve()
    metadata = json.loads((SOURCE / "info.json").read_text())
    expected = metadata["name"] + "_" + metadata["version"]
    if target.name != expected:
        raise ValueError(f"Expected mod directory {expected}, got {target.name}")
    if not (target / "sprite-regions.lua").is_file():
        raise FileNotFoundError("Missing FMPL cropped sprite registration: sprite-regions.lua")
    check_sheets(target)
    for file in ("info.json", "settings.lua", "data.lua", "README.md"):
        shutil.copy2(SOURCE / file, target / file)
    for directory in ("locale", "scenarios"):
        shutil.copytree(SOURCE / directory, target / directory, dirs_exist_ok=True)
    frames = frames or target.parents[1] / "frames"
    for tier in CLASSES:
        make_icon(target, tier, frames)
    archive = target.with_name(target.name + ".zip")
    temporary = archive.with_name(archive.name + ".partial")
    with ZipFile(temporary, "w", compression=ZIP_DEFLATED, compresslevel=5) as output:
        for file in sorted(target.rglob("*")):
            if file.is_file() and file.suffix in (".json", ".lua", ".md", ".cfg", ".png"):
                output.write(file, f"{target.name}/{file.relative_to(target).as_posix()}")
    with ZipFile(temporary) as output:
        bad = output.testzip()
        if bad:
            raise ValueError(f"Archive CRC failed for {bad}")
        if len([f for f in output.namelist() if f.endswith(".png")]) != 99:
            raise ValueError("The archive must contain 96 directional sheets and three icons")
    temporary.replace(archive)
    return archive


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("mod_directory", type=Path)
    p.add_argument("--frames", type=Path, help="Full uncropped FMPL frame tree for item icons")
    args = p.parse_args()
    archive = build(args.mod_directory, args.frames)
    print(archive, archive.stat().st_size, hashlib.sha256(archive.read_bytes()).hexdigest())
