"""Package actual source sequence previews; retain every source frame/hash."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT.parent/"local-validation/deps"))
from PIL import Image,ImageDraw

p=argparse.ArgumentParser();p.add_argument("directory",type=Path);p.add_argument("--views",default="whole,mechanism");a=p.parse_args()
root=a.directory.resolve();j=json.loads((root/"motion-capture.json").read_text(encoding="utf-8"));sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
outputs=[]
for view in a.views.split(","):
    rows=sorted([r for r in j["frames"]if r["view"]==view],key=lambda x:x["frame"])
    assert [r["frame"]for r in rows]==list(range(66))
    images={}
    for row in rows:
        path=root/row["file"];assert sha(path)==row["sha256"]
        with Image.open(path)as im:
            im.load();im=im.convert("RGBA")
            bg=Image.new("RGBA",im.size,(18,21,24,255));images[row["frame"]]=Image.alpha_composite(bg,im).convert("RGB")
    frames=[images[i]for i in range(1,65)]
    dims=(320,800)if view=="whole"else(480,576)
    frames=[im.resize(dims,Image.Resampling.LANCZOS)for im in frames]
    path=root/("thetazine-v06-"+view+"-cycle.gif")
    frames[0].save(path,save_all=True,append_images=frames[1:],duration=[33,33,34]*21+[33],loop=0)
    outputs.append({"view":view,"file":path.name,"sha256":sha(path),"actual_source_frames":64,"duration_seconds":64/30})
    board=Image.new("RGB",(dims[0]*4,dims[1]+26),(18,21,24));d=ImageDraw.Draw(board)
    for k,f in enumerate([1,17,33,49]):
        board.paste(images[f].resize(dims,Image.Resampling.LANCZOS),(k*dims[0],26));d.text((k*dims[0]+6,8),"Pose "+str(f),fill="white")
    board.save(root/("thetazine-v06-"+view+"-poses.png"))
result={"status":"PACKAGED_ACTUAL_SOURCE_MECHANICAL_MOTION_REQUIRES_VISUAL_REVIEW","capture_receipt_sha256":sha(root/"motion-capture.json"),
        "source_sha256":j["binding"]["source_sha256"],"outputs":outputs,"scope":"Source previews, actual64poses at30fps. GIF quantization is not native clock proof; runtime integration stays separate."}
(root/"motion-preview-package.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
print(result["status"])
