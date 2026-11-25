#!/usr/bin/env python3
"""Authoritative per-frame layouts that cannot be resized as whole PNG atlases.

Cropping makes the artillery and reactor frame dimensions indivisible by the
LO divisor. Every frame is padded only at its right and bottom edges before
resampling. The runtime adjusts the sprite's centre by half that padding,
preserving the original artwork's position in world coordinates.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import re
import struct


def png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG: {path}")
    return struct.unpack(">II", header[16:24])


def _plan(root: Path, relative: str, frame_width: int, frame_height: int,
          columns: int, rows: int, frame_count: int, divisor: int,
          layout_source: str, *, original_scale=None, original_shift=None):
    width, height = png_dimensions(root / relative)
    if (width, height) != (frame_width * columns, frame_height * rows):
        raise ValueError(
            f"Atlas metadata mismatch: {relative}: PNG {width}x{height}, "
            f"frames {frame_width}x{frame_height}, grid {columns}x{rows}")
    if frame_count < 1 or frame_count > columns * rows:
        raise ValueError(f"Invalid frame count: {relative}: {frame_count}")
    lo_w = math.ceil(frame_width / divisor)
    lo_h = math.ceil(frame_height / divisor)
    pad_x, pad_y = lo_w * divisor - frame_width, lo_h * divisor - frame_height
    result = {
        "frame_width": frame_width, "frame_height": frame_height,
        "lo_frame_width": lo_w, "lo_frame_height": lo_h,
        "columns": columns, "rows": rows, "frame_count": frame_count,
        "divisor": divisor, "pad_x": pad_x, "pad_y": pad_y,
        "original_width": width, "original_height": height,
        "width": lo_w * columns, "height": lo_h * rows,
        "layout_source": layout_source,
    }
    if original_scale is not None and original_shift is not None:
        # Factorio sprite scale uses 32 pixels per tile. Shift names the
        # centre, so right/bottom padding moves it +padding*scale/(2*32).
        adjusted = [original_shift[0] + pad_x * original_scale / 64,
                    original_shift[1] + pad_y * original_scale / 64]
        before_top_left = [original_shift[0] - frame_width * original_scale / 64,
                           original_shift[1] - frame_height * original_scale / 64]
        after_top_left = [adjusted[0] - lo_w * divisor * original_scale / 64,
                          adjusted[1] - lo_h * divisor * original_scale / 64]
        if any(abs(a-b) > 1e-12 for a, b in zip(before_top_left, after_top_left)):
            raise ValueError(f"Padding changed artwork registration: {relative}")
        result["original_scale"] = original_scale
        result["original_shift"] = original_shift
        result["lo_shift"] = adjusted
    return result


def special_layouts(source: Path, divisor: int = 4) -> dict[str, dict]:
    """Return relative PNG path -> complete per-frame resize plan.

    Artillery's checked authoring receipt supplies each frame's exact crop.
    Reactors use the 4x4 moving / 1x1 static layout declared by
    prototypes/plasma_reactor_family.lua. PNG headers verify that division
    yields integral original frames; this retains each hr/sd selection.
    """
    source = Path(source)
    if not isinstance(divisor, int) or divisor < 1:
        raise ValueError("divisor must be a positive integer")
    result = {}
    artillery_meta = "graphics/entity/bunker-artillery/visuals.json"
    metadata = json.loads((source / artillery_meta).read_text(encoding="utf-8"))
    for heading in metadata["headings"].values():
        for record in heading.values():
            relative = "graphics/entity/bunker-artillery/" + record["file"]
            columns = record["line_length"]
            rows = math.ceil(record["frame_count"] / columns)
            if relative in result:
                raise ValueError(f"Duplicate artillery layout: {relative}")
            result[relative] = _plan(
                source, relative, record["width"], record["height"],
                columns, rows, record["frame_count"], divisor, artillery_meta,
                original_scale=record["scale"], original_shift=record["shift"])

    reactors = source / "graphics/entity/plasma-reactor-family"
    for resolution in ("hr", "sd"):
        for path in sorted((reactors / resolution).rglob("*.png")):
            role = path.stem.rsplit("-", 1)[-1]
            if role not in {"on", "off", "glow", "shadow"}:
                raise ValueError(f"Unknown reactor image role: {path}")
            grid = 4 if role in {"on", "glow"} else 1
            width, height = png_dimensions(path)
            if width % grid or height % grid:
                raise ValueError(f"Non-integral original reactor frame: {path}")
            relative = path.relative_to(source).as_posix()
            result[relative] = _plan(
                source, relative, width // grid, height // grid,
                grid, grid, grid * grid, divisor,
                "prototypes/plasma_reactor_family.lua")
    return result


# Explicit alias makes the intended build-tool API easy to discover.
load_special_layouts = special_layouts


def fixed_layouts(source: Path, divisor: int = 4) -> dict[str, dict]:
    """Return verified fixed-cell layouts for the largest runtime art families.

    Cells come from their production prototype modules, not a guessed atlas
    subdivision. A separate crop/resample for each cell prevents filter taps
    from bleeding adjacent directions or animation frames into each other.
    ``frame_count`` here counts all atlas slots, including padding slots;
    the runtime leaves its original animation/direction counts untouched.
    """
    source = Path(source)
    result = {}
    entity = source / "graphics/entity"

    def add(path: Path, cell_w: int, cell_h: int, authority: str):
        width, height = png_dimensions(path)
        if width % cell_w or height % cell_h:
            raise ValueError(f"Fixed frame grid mismatch: {path}: {width}x{height}, cell {cell_w}x{cell_h}")
        columns, rows = width // cell_w, height // cell_h
        relative = path.relative_to(source).as_posix()
        result[relative] = _plan(source, relative, cell_w, cell_h, columns, rows,
                                 columns * rows, divisor, authority)

    catalog = (source / "shared/character_skin_catalog.lua").read_text(encoding="utf-8")
    if set(re.findall(r'\["size"\]\s*=\s*(\d+)', catalog)) != {"256"}:
        raise ValueError("Gladius donor cell sizes changed; review graphics-pack layouts")
    for path in sorted((entity / "gladius-donors").rglob("*.png")):
        add(path, 256, 256, "shared/character_skin_catalog.lua")

    for group in ("bunker-lobber", "bunker-rocket-salvo", "bunker-twin-cannon",
                  "bunker-chicago-piano", "bunker-twin-minigun", "bunker-autocannon",
                  "bunker-energy-dish"):
        for path in sorted((entity / group).glob("*.png")):
            name = path.name
            if "icon" in name or name == "native-core-board.png":
                continue
            if group == "bunker-lobber":
                size = 512 if name.startswith("shadow-") else 256
                authority = "prototypes/bunker_family.lua"
            elif group == "bunker-rocket-salvo":
                size = 256
                authority = "prototypes/bunker_rocket_salvo.lua"
            elif group == "bunker-twin-cannon":
                size = 512 if name.startswith("shadow-") else 256
                authority = "prototypes/bunker_twin_cannon.lua"
            elif group in {"bunker-chicago-piano", "bunker-twin-minigun"}:
                size = 512 if name.startswith("shadow-") else 256
                authority = "prototypes/bunker_bullet_weapons.lua"
            elif group == "bunker-autocannon":
                size = 512 if name.startswith("base-") else 256
                authority = "prototypes/bunker_autocannon_graphics.lua"
            else:
                size = 512 if name.startswith("shadow-") else 256
                authority = "prototypes/bunker_family.lua"
            add(path, size, size, authority)

    armory = entity / "voidship-armory"
    for folder, size in (("lance-battery", 384), ("macro-cannon", 512)):
        for path in sorted((armory / folder).glob("*.png")):
            add(path, size, size, "prototypes/generated_graphics/voidship_armory.lua")
    effects = {"macro-plume": (72, 320), "plasma-plume": (72, 320),
               "wake-mote": (32, 32), "entry-flash": (128, 128),
               "target-brackets": (256, 256), "target-cell": (128, 128),
               "target-label": (320, 52)}
    for name, (width, height) in effects.items():
        add(armory / "effects" / (name + ".png"), width, height,
            "prototypes/voidship_armory.lua")
    for path in sorted(armory.glob("*.png")):
        if "icon" not in path.name:
            add(path, 384, 384, "prototypes/voidship_armory.lua")

    for group in ("atmospheric-water-condenser-v22c", "atmospheric-water-condenser-v24"):
        for path in sorted((entity / group).glob("*.png")):
            if "icon" in path.name:
                continue
            size = 256 if "-sd" in path.name else 512
            add(path, size, size, "prototypes/generated_graphics/" + group + ".lua")

    for path in sorted((entity / "faction-factories").rglob("*.png")):
        size = 512 if path.name.startswith("smoke-") else 768
        add(path, size, size, "prototypes/faction_factories.lua")

    uniform = {
        "emergency-assembler-v07": 256, "entropic-extractor-v1": 512,
        "orbital-trader-v1": 512, "emergency-laboratorium-v1": 512,
        "emergency-smelter-v1": 512, "citadel-manufactoreo-v1": 512,
        "void-steam-engine-v1": 256, "sterling-steam-catalyzer-v1": 256,
    }
    for group, size in uniform.items():
        for path in sorted((entity / group).glob("*.png")):
            if "icon" not in path.name:
                add(path, size, size, "prototypes/generated_graphics/" + group + ".lua")

    for path in sorted((entity / "conclave-center-v08").glob("*.png")):
        if "icon" not in path.name:
            size = 256 if path.name == "ambient-light.png" else 512
            add(path, size, size, "prototypes/conclave_center_0558.lua")

    for path in sorted((entity / "emergency-miner-v25").glob("*.png")):
        if "icon" not in path.name:
            size = 256 if path.name.endswith("-hr.png") else 128
            add(path, size, size, "prototypes/generated_graphics/emergency-miner-v25.lua")

    for path in sorted(entity.glob("emergency-boiler-v08-*.png")):
        size = 128 if path.name.endswith("-128.png") else 256
        add(path, size, size, "prototypes/generated_graphics/emergency-boiler-v08.lua")

    for path in sorted((entity / "hydrogen-thruster-v01").glob("*.png")):
        cell = (768, 1024) if "shadow" in path.name else (512, 768)
        add(path, *cell, "prototypes/generated_graphics/hydrogen-thruster-v01.lua")

    thrusters = {
        "hydrogen-thruster-v03": ((512, 1536), (398, 186)),
        "thetazine-thruster-v04": ((512, 1280), (398, 394)),
        "thetazine-thruster-v10": ((512, 1280), (470, 282)),
        "thetazine-thruster-v11": ((512, 1280), (470, 282)),
    }
    for group, (body, shadow) in thrusters.items():
        for path in sorted((entity / group).glob("*.png")):
            if "icon" not in path.name:
                add(path, *(shadow if "shadow" in path.name else body),
                    "prototypes/generated_graphics/" + group + ".lua")

    for path in sorted((entity / "void-fusion-thrusters-v01").rglob("*.png")):
        cell = (432, 1120) if path.parent.name == "large-void-fusion-thruster" else (288, 1304)
        add(path, *cell, "prototypes/generated_graphics/void-fusion-thrusters-v01.lua")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path("tech-priests_src"))
    parser.add_argument("--divisor", type=int, default=4)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    layouts = special_layouts(args.source, args.divisor)
    summary = {
        "special_layout_count": len(layouts),
        "padded_frame_count": sum(bool(a["pad_x"] or a["pad_y"]) for a in layouts.values()),
        "original_pixels": sum(a["original_width"] * a["original_height"] for a in layouts.values()),
        "lo_pixels": sum(a["width"] * a["height"] for a in layouts.values()),
        "artillery_registration_pass": True,
    }
    if args.output:
        args.output.write_text(json.dumps({"summary": summary, "layouts": layouts}, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
