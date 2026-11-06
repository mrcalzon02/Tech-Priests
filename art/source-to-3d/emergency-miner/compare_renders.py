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
    ("ISOMETRIC VISIBLE EXTERIOR", "02_game_candidate_full_miner.png"),
    ("VISIBLE ENCLOSURE DETAIL", "03_visible_enclosure_detail.png"),
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
    assert report["render_geometry_policy"]=="GAME_CAMERA_VISIBLE_ONLY"
    assert report["modeled_hidden_internal_components"]==0
    assert report["laser_components_documented_not_modeled"]
    assert report["mechanical_excavation_components"]==0
    assert report["technology_principle"]=="DOWNWARD_FREQUENCY_MODULATED_LASER_ABLATION"
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
    # The current prototype's original 1254px art at 0.034 scale spans
    # ~42.6 game pixels. Approximate the actual 1x1 visual readability,
    # avoiding judgments from a flattering zoomed-in beauty render.
    game_size=43
    magnify=4
    pad=18
    tile=game_size*magnify
    strip=Image.new("RGB", (4*(tile+pad)+pad, tile+108), (39,41,42))
    draw_small=ImageDraw.Draw(strip)
    for index,(label,file) in enumerate(NAMES):
        orig=to_display(ORIGINAL if file is None else out/file, game_size)
        enlarged=orig.resize((tile,tile),Image.Resampling.NEAREST)
        x=pad+index*(tile+pad)
        strip.paste(enlarged,(x,49))
        draw_small.text((x,14),label.split(" (")[0][:22],fill=(237,235,221))
        strip.paste(orig,(x,49+tile+8))
        draw_small.text((x+47,49+tile+19),"43px actual-size swatch",fill=(229,225,215))
    small_path=out/"emergency_miner_43px_display_readability.png"
    strip.save(small_path,"PNG",optimize=True)
    small_jpg=out/"emergency_miner_43px_display_preview.jpg"
    strip.save(small_jpg,"JPEG",quality=84,optimize=True)
    if args.print_preview:
        print("BEGIN_IMAGE_BASE64_EMERGENCY_MINER_GAME_SCALE",flush=True)
        data=base64.b64encode(small_jpg.read_bytes()).decode("ascii")
        for i in range(0,len(data),116):
            print(data[i:i+116],flush=True)
        print("END_IMAGE_BASE64_EMERGENCY_MINER_GAME_SCALE",flush=True)
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
        "hidden_laser_geometry_not_modeled":True,
        "original_game_sprite_unmodified":True,
        "visual_approval":"PENDING_EXPLICIT_REVIEW"
    }),flush=True)


if __name__=="__main__":
    main()
