from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import hashlib,json
O=Path(__file__).resolve().parent
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',24);small=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',18)
board=Image.new('RGB',(1500,1130),(32,35,39));d=ImageDraw.Draw(board);d.text((25,16),'MARTIAN BUNKER — ALTERNATE TURRET BLOCKOUTS V01',font=font,fill='white')
for row,(variant,title) in enumerate([('energy_dish','ENERGY DISH'),('grenade_lobber_12','12-TUBE GRENADE LOBBER · 3 × 4')]):
 y=65+row*520;d.text((25,y),title,font=font,fill=(232,187,132))
 for column,(view,label) in enumerate([('mounted','Established bunker base'),('turret','Independent turret'),('front','Front / barrel arrangement')]):
  im=Image.open(O/(variant+'_'+view+'.png')).convert('RGBA');alpha=im.getchannel('A');box=alpha.getbbox();assert box and box[0]>0 and box[1]>0 and box[2]<im.width and box[3]<im.height,(variant,view,box)
  im.thumbnail((480,465));x=column*500+(500-im.width)//2;board.paste(im,(x,y+32),im);d.text((column*500+22,y+494),label,font=small,fill=(210,214,219))
board.save(O/'Turret_Blockouts_V01_Review.png')
for variant in ['energy_dish','grenade_lobber_12']:
 im=Image.open(O/(variant+'_rear.png'));a=im.getchannel('A');assert a.getbbox() and a.getextrema()==(0,255)
files=[p for p in O.rglob('*') if p.is_file() and p.suffix not in ['.blend1','.log'] and p.name!='checksums.json' and '__pycache__' not in str(p)]
(O/'checksums.json').write_text(json.dumps({str(p.relative_to(O)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2))
