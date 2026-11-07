from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json,zipfile
O=Path(__file__).resolve().parent;r=json.loads((O/'model_validation.json').read_text());assert r['GLB_reimported'] and r['all_other_V13_source_geometry_materials_and_transforms_preserved']
b=Image.new('RGB',(1500,1620),(33,36,40));d=ImageDraw.Draw(b);f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',28);s=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',21)
d.text((25,20),'V14 — BOLTED MOUNT AND INSET GIRDERS',font=f,fill='white')
for i,(v,t) in enumerate([('oblique','Turret mounting plate detailed in place'),('plate_detail','Recessed girder bays and bolted perimeter'),('plate_top','Inset diagonal bracing below the original deck'),('rear','Turret assembly and chamfers preserved')]):
 im=Image.open(O/('mount_v14_'+v+'.png')).convert('RGBA');box=im.getchannel('A').getbbox();assert box
 if v in ['oblique','rear']:assert box[0]>0 and box[1]>0 and box[2]<im.width and box[3]<im.height
 im.thumbnail((730,700));x=i%2*750+(750-im.width)//2;y=75+i//2*770;b.paste(im,(x,y),im);d.text((i%2*750+15,y+710),t,font=s,fill=(226,190,140))
b.save(O/'Inset_Girder_Mount_V14_Review.png')
with zipfile.ZipFile(O/'Inset_Girder_Mount_V14.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in O.iterdir():
  if p.suffix in ['.blend','.glb','.py','.json','.md','.png']:z.write(p,p.name)
print('V14_REVIEW_PACKAGE_PASS')
