from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json,zipfile
O=Path(__file__).resolve().parent
r=json.loads((O/'model_validation.json').read_text());assert r['GLB_reimported'] and r['all_other_V11_geometry_transforms_and_materials_preserved']
b=Image.new('RGB',(1500,1620),(33,36,40));d=ImageDraw.Draw(b)
f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',28);s=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',21)
d.text((25,20),'V12 — CORRUGATED COMPRESSION HOSES',font=f,fill='white')
for i,(v,t) in enumerate([('oblique','Six corrugated air-feed hoses beneath the cannons'),('rear','Existing plating, sensors and cable runs preserved'),('detail','Continuous bellows profile through the bends'),('side','Original hose routes and end sockets retained')]):
 im=Image.open(O/('hoses_v12_'+v+'.png')).convert('RGBA');box=im.getchannel('A').getbbox();assert box
 if v!='detail':assert box[0]>0 and box[1]>0 and box[2]<im.width and box[3]<im.height
 im.thumbnail((730,700));x=i%2*750+(750-im.width)//2;y=75+i//2*770;b.paste(im,(x,y),im);d.text((i%2*750+15,y+710),t,font=s,fill=(226,190,140))
b.save(O/'Central_Feed_V12_Review.png')
with zipfile.ZipFile(O/'Central_Feed_V12.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in O.iterdir():
  if p.suffix in ['.blend','.glb','.py','.json','.md','.png']:z.write(p,p.name)
print('V12_REVIEW_PACKAGE_PASS')
