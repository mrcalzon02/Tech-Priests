"""Pin existing mod-owned Noctilith references; make a private inspection board.

The crops are references, never texture projection or newly authored asset art.
Their lighting is baked into the sprites and cannot be used as PBR albedo.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[3])
    args = parser.parse_args()
    repo = args.repo.resolve()
    output = repo / "docs/art/thruster-resumption-20261117/animation-capture"
    output.mkdir(parents=True, exist_ok=True)
    root = repo / "tech-priests_src/graphics"
    specs = [
        ("icons/blackstone.png", None, "Blackstone mineral identity"),
        ("icons/blackstone-fragment.png", None, "Broken mineral faces"),
        ("entity/void-fusion-thruster/void-fusion-thruster-wide-idle.png", (147, 134, 217, 175), "Wide cold rock, upper window"),
        ("entity/void-fusion-thruster/void-fusion-thruster-wide-idle.png", (146, 190, 216, 232), "Wide cold rock, middle window"),
        ("entity/void-fusion-thruster/void-fusion-thruster-wide-run.png", (147, 134, 217, 175), "Wide working rock, upper window"),
        ("entity/void-fusion-thruster/void-fusion-thruster-wide-run.png", (146, 190, 216, 232), "Wide working rock, middle window"),
    ]
    board = Image.new("RGB", (960, 680), (28, 30, 32))
    draw = ImageDraw.Draw(board)
    rows = []
    for index, (rel, crop, label) in enumerate(specs):
        path = root / rel
        source = Image.open(path).convert("RGBA")
        sample = source.crop(crop) if crop else source
        rgb = [pixel[:3] for pixel in sample.getdata() if pixel[3] > 128]
        channels = [sorted(channel) for channel in zip(*rgb)]
        quantiles = [[channel[round((len(channel) - 1) * q)] for channel in channels]
                     for q in (.1, .5, .9)]
        x, y = (index % 3) * 320, (index // 3) * 340
        draw.text((x + 12, y + 12), label, fill="white")
        preview = sample.copy()
        preview.thumbnail((280, 230), Image.Resampling.NEAREST)
        if preview.width < 180:
            ratio = min(280 / sample.width, 230 / sample.height)
            preview = sample.resize((round(sample.width * ratio), round(sample.height * ratio)), Image.Resampling.NEAREST)
        board.paste(preview, (x + (320 - preview.width) // 2, y + 50), preview)
        draw.text((x + 12, y + 294), "Reference crop; nearest-neighbor inspection", fill=(175, 180, 180))
        rows.append({"path": str(path.relative_to(repo)).replace("\\", "/"),
                     "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                     "source_size": list(source.size), "crop_xyxy": crop,
                     "opaque_srgb_byte_quantiles_10_50_90": quantiles,
                     "scope": label})
    dest = output / "noctilith-reference-board.png"
    board.save(dest)
    report = {
        "status": "EXISTING_SPRITE_AND_ICON_REFERENCE_PINNED_REQUIRES_MODEL_COMPARISON",
        "references": rows,
        "board_sha256": hashlib.sha256(dest.read_bytes()).hexdigest(),
        "interpretation": [
            "Dark olive/charcoal irregular mineral faces with broad tonal variation, fractured grain, pale/ochre seams and chipped edge planes.",
            "The mineral is dielectric; pale mineral seams must not turn every rock into metal.",
            "Cold stone remains legible independently of green energized recesses and contacts.",
            "Sprite lighting and sprite metal restraints contaminate simple color statistics; quantiles are descriptive, not PBR albedo targets.",
            "Do not project sprite crops onto the model: author model-specific surface masks, useful UVs and real exported base/normal/roughness maps.",
            "The gray asteroid-chunk icon is a different visual treatment and is excluded from the chosen Noctilith family reference.",
        ],
        "acceptance": [
            "Rock-only material revision preserves current mesh geometry, bounds, receiving surfaces, sockets, cage geometry and mounting datum.",
            "Inspect cold and working actual-GLB renders at the fixed production camera and an inspection detail.",
            "At game scale, stone reads as fractured mineral instead of featureless black or shiny metal; green light does not erase the mineral faces.",
            "Reopen packed Blender source and independently import GLB; verify decoded exported maps and material bindings.",
        ],
    }
    (output / "noctilith-reference.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": report["status"], "references": len(rows), "board": str(dest)}))


if __name__ == "__main__":
    main()
