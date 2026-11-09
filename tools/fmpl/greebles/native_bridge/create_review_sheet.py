#!/usr/bin/env python3
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,math,sys
root=Path(sys.argv[1]);items=[]
for rp in sorted(root.glob('parts/*/receipt.json')):
 receipt=json.loads(rp.read_text())
 if (rp.parent/'front.png').is_file() and (rp.parent/'rear.png').is_file():items.append((receipt,rp.parent))
print('with previews',len(items))
cols=2; rows=math.ceil(len(items)/cols);cw=820;ch=465
sheet=Image.new('RGB',(cols*cw,rows*ch),(23,27,32));d=ImageDraw.Draw(sheet)
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',20)
subfont=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',14)
for j,(r,p) in enumerate(items):
 x=(j%cols)*cw;y=(j//cols)*ch
 d.rounded_rectangle((x+7,y+7,x+cw-7,y+ch-7),radius=12,fill=(35,40,45),outline=(78,86,92),width=2)
 d.text((x+20,y+15),f"{r['source_object']}   •   {r['id']}",font=font,fill=(236,238,244))
 for n,nm in enumerate(['front','rear']):
  im=Image.open(p/(nm+'.png')).convert('RGB').resize((390,293),Image.Resampling.LANCZOS)
  sheet.paste(im,(x+15+n*395,y+60))
  d.text((x+22+n*395,y+355),nm,font=subfont,fill=(210,217,222))
 v=r['counts'];d.text((x+20,y+398),f"{v['vertices']:,} vertices  •  {v['polygons']:,} polygons  •  geometry-only",font=subfont,fill=(193,201,209))
 d.text((x+20,y+422),'Candidate — function/design-language review pending',font=subfont,fill=(246,207,157))
path=root/'greebles-review-first-8.png';sheet.save(path,optimize=True)
print('sheet',path,'bytes',path.stat().st_size)
