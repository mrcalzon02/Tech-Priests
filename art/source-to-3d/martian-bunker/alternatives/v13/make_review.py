from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json,zipfile
O=Path(__file__).resolve().parent;r=json.loads((O/'model_validation.json').read_text());assert r['GLB_reimported'] and r['all_unrelated_geometry_materials_and_transforms_preserved']
b=Image.new('RGB',(1500,1620),(33,36,40));d=ImageDraw.Draw(b);f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',28);s=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',21)
d.text((25,20),'V13 — SELECTED CORNER CHAMFERS',font=f,fill='white')
views=[('oblique','Original silhouette with selected flat corner cuts'),('sensor_detail','Sensor box: chamfered lower left and right corners'),('cabinet_detail','Rear cabinet: two upright corner chamfers'),('rear','Side panels fitted clear of the rear chamfers')]
for i,(v,t) in enumerate(views):
 im=Image.open(O/('chamfers_v13_'+v+'.png')).convert('RGBA');box=im.getchannel('A').getbbox();assert box
 if v in ['oblique','rear']:assert box[0]>0 and box[1]>0 and box[2]<im.width and box[3]<im.height
 im.thumbnail((730,700));x=i%2*750+(750-im.width)//2;y=75+i//2*770;b.paste(im,(x,y),im);d.text((i%2*750+15,y+710),t,font=s,fill=(226,190,140))
b.save(O/'Corner_Chamfers_V13_Review.png')
with zipfile.ZipFile(O/'Corner_Chamfers_V13.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in O.iterdir():
  if p.suffix in ['.blend','.glb','.py','.json','.md','.png']:z.write(p,p.name)
print('V13_REVIEW_PACKAGE_PASS')
