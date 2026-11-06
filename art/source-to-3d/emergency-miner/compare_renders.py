"""Build honest side-by-side source-versus-REAL-Blender-candidate inspection."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
ORIGINAL = ROOT / "tech-priests_src/graphics/entity/martian-micro/tech-priests-emergency-miner.png"
TARGET_SHA256 = "29442badbd53d2f69880fb625330ed071e6d362119e458952f575d53cc1bf700"
NAMES = [
    ("CANONICAL REFERENCE (ORIGINAL)", None),
    ("SOURCE VIEW (REAL BLENDER MESH)", "01_source_view_real_mesh.png"),
    ("MINER VIEW (AUGER INFERRED)", "02_game_candidate_full_miner.png"),
    ("PHYSICAL INSPECTION", "03_physical_drill_inspection.png"),
]


def to_display(path: Path, size: int) -> Image.Image:
    with Image.open(path) as source:
        copy = source.convert("RGBA")
    copy.thumbnail((size, size), Image.Resampling.LANCZOS)
    solid=Image.new("RGBA",(size,size),(190,191,187,255))
    solid.alpha_composite(copy, ((size-copy.width)//2,(size-copy.height)//2))
    return solid.convert("RGB")


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--out",required=True,type=Path)
    parser.add_argument("--print-preview",action="store_true")
    args=parser.parse_args()
    out=args.out.resolve()
    if hashlib.sha256(ORIGINAL.read_bytes()).hexdigest()!=TARGET_SHA256:
        raise RuntimeError("Canonical source changed: reject incorrect comparison")
    report=json.loads((out/"model_manifest.json").read_text(encoding="utf8"))
    assert not report["appearance_approved"]
    assert not report["underbody_drill_source_observed"]
    assert report["saved_master_sha256"]==hashlib.sha256((out/report["saved_master"]).read_bytes()).hexdigest()
    assert report["physical_glb_sha256"]==hashlib.sha256((out/report["physical_glb_export"]).read_bytes()).hexdigest()
    size=610
    dest=Image.new("RGB",(size*2,size*2+72),(41,43,43))
    draw=ImageDraw.Draw(dest)
    for index,(title,filename) in enumerate(NAMES):
        image=to_display(ORIGINAL if filename is None else out/filename,size)
        xy=((index%2)*size, (index//2)*size+36)
        dest.paste(image,xy)
        draw.rectangle(((index%2)*size,(index//2)*size,
                        (index%2+1)*size,(index//2)*size+35),fill=(36,39,40))
        draw.text(((index%2)*size+15,(index//2)*size+12),title,fill=(235,235,222))
    path=out/"emergency_miner_source_vs_real_3d_contact_sheet.png"
    dest.save(path,"PNG",optimize=True)
    smaller=dest.copy()
    smaller.thumbnail((1000,1050),Image.Resampling.LANCZOS)
    jpg=out/"emergency_miner_comparison_preview.jpg"
    smaller.save(jpg,"JPEG",quality=82,optimize=True)
    if args.print_preview:
        print("BEGIN_IMAGE_BASE64_EMERGENCY_MINER_MODEL_COMPARISON",flush=True)
        data=base64.b64encode(jpg.read_bytes()).decode("ascii")
        for i in range(0,len(data),116):
            print(data[i:i+116],flush=True)
        print("END_IMAGE_BASE64_EMERGENCY_MINER_MODEL_COMPARISON",flush=True)
    print("EMERGENCY_MINER_CONTACT_SHEET_CREATED "+json.dumps({
        "source_sha256":TARGET_SHA256,
        "source_is_real":True,
        "render_is_real_Blender_mesh":True,
        "missing_source_drill_handled_as_inferred_only":True,
        "original_game_sprite_unmodified":True,
        "visual_approval":"PENDING_EXPLICIT_REVIEW"
    }),flush=True)


if __name__=="__main__":
    main()
