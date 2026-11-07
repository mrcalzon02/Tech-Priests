from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json,zipfile,hashlib
O=Path(__file__).resolve().parent
r=json.loads((O/"model_validation.json").read_text())
assert r["total_cannons"]==6 and r["loaders_after_mirroring"]==6 and r["GLB_reimported"]
assert r["cannon_shapes_and_UVs_unchanged"] and r["cannon_XY_and_aim_angles_unchanged"]
f=ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",27)
small=ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",21)
b=Image.new("RGB",(1600,1680),(33,36,40));d=ImageDraw.Draw(b)
d.text((24,15),"LOOSE PINEAPPLE GRENADE LOADERS — SIX CANNONS",font=f,fill="white")
views=[("oblique","Cannon forms and pneumatic pipes retained"),("pineapple_detail","Loose pineapple bodies, spoon levers and rings"),("front","Six side-loading hoods and open guide troughs"),("loader_rear","Open cradles and separate ammunition paths")]
for i,(view,label) in enumerate(views):
 im=Image.open(O/("loader_v05_"+view+".png")).convert("RGBA")
 box=im.getchannel("A").getbbox()
 assert box,(view,box)
 if view!="pineapple_detail":assert box[0]>0 and box[1]>0 and box[2]<im.width and box[3]<im.height,(view,box)
 im.thumbnail((790,740));x=(i%2)*800+(800-im.width)//2;y=75+(i//2)*800
 b.paste(im,(x,y),im);d.text(((i%2)*800+20,y+745),label,font=small,fill=(226,190,140))
b.save(O/"Loose_Pineapple_Loader_V05_Review.png")
files=[p for p in O.rglob("*") if p.is_file() and p.suffix not in [".zip",".blend1",".pyc",".log"] and p.name!="checksums.json" and "__pycache__" not in str(p)]
(O/"checksums.json").write_text(json.dumps({str(p.relative_to(O)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2))
with zipfile.ZipFile(O/"Loose_Pineapple_Loader_V05.zip","w",zipfile.ZIP_DEFLATED) as z:
 for p in files+[O/"checksums.json"]:z.write(p,str(p.relative_to(O)))
print("V05_REVIEW_AND_PACKAGE_PASS")
