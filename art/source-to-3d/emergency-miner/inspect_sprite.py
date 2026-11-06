"""Inspect the canonical Emergency Miner artwork without modifying it."""
from __future__ import annotations
import argparse
import base64
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
CANONICAL = ROOT / "tech-priests_src/graphics/entity/martian-micro/tech-priests-emergency-miner.png"
ICON = ROOT / "tech-priests_src/graphics/icons/martian-micro/tech-priests-emergency-miner.png"


def preview(original: Path, destination: Path, label: str, max_side: int) -> dict:
    raw = original.read_bytes()
    with Image.open(original) as source:
        image = source.convert("RGBA")
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if not bbox:
        raise RuntimeError(f"{label}: completely transparent source")
    background = Image.new("RGBA", image.size, (190, 191, 187, 255))
    background.alpha_composite(image)
    rgb = background.convert("RGB")
    rgb.thumbnail((max_side, max_side), Image.Resampling.LANCZOS)
    destination.parent.mkdir(parents=True, exist_ok=True)
    rgb.save(destination, "JPEG", quality=82, optimize=True, subsampling=0)
    return {
        "file": str(original.relative_to(ROOT)),
        "sha256": hashlib.sha256(raw).hexdigest(),
        "size": list(image.size),
        "mode": "RGBA",
        "alpha_content_bbox_xyxy": list(bbox),
        "alpha_opaque_pixels": sum(1 for v in alpha.getdata() if v == 255),
        "alpha_visible_pixels": sum(1 for v in alpha.getdata() if v != 0),
        "preview_size": list(rgb.size),
        "preview_file": destination.name,
    }


def output_preview(label: str, location: Path) -> None:
    # Useful for source inspection through authenticated GitHub Actions logs,
    # without adding an image generation service to the build.
    print("BEGIN_IMAGE_BASE64_" + label, flush=True)
    data = base64.b64encode(location.read_bytes()).decode("ascii")
    for i in range(0, len(data), 116):
        print(data[i:i+116], flush=True)
    print("END_IMAGE_BASE64_" + label, flush=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--print-preview", action="store_true")
    args = parser.parse_args()
    output = args.out.resolve()
    data = {
        "asset": "tech-priests-emergency-miner",
        "source": preview(CANONICAL, output / "source_reference.jpg", "source", 680),
        "icon": preview(ICON, output / "source_icon.jpg", "icon", 240),
        "source_is_only_accepted_visual_authority": True,
        "mesh_visual_acceptance": "pending",
    }
    (output / "source_measurements.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print("EMERGENCY_MINER_SOURCE_MEASUREMENTS " + json.dumps(data, separators=(",", ":")), flush=True)
    if args.print_preview:
        output_preview("EMERGENCY_MINER", output / "source_reference.jpg")
        output_preview("EMERGENCY_MINER_ICON", output / "source_icon.jpg")


if __name__ == "__main__":
    main()
