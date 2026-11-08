"""Compose actual base and dish sprites using their recorded native draw shifts."""
from PIL import Image,ImageDraw,ImageFont
import pathlib,json,hashlib,argparse
p=argparse.ArgumentParser();p.add_argument('--output',type=pathlib.Path,default=pathlib.Path('work/energy-dish-v03'));p.add_argument('--base',type=pathlib.Path,default=pathlib.Path('C:/GITS/Tech-Priests/tech-priests_src/graphics/entity/bunker-autocannon'));p.add_argument('--preview-dir',type=pathlib.Path,default=pathlib.Path('outputs'));a=p.parse_args();O=a.output;base=a.base;a.preview_dir.mkdir(parents=True,exist_ok=True);m=json.loads((O/'idle64-validation.json').read_text());g={'base_scale':.315463840961,'base_shift':[0,-1.110906552544]};pixels=64
board=Image.new('RGB',(1600,450),(36,40,45));draw=ImageDraw.Draw(board);font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18);draw.text((12,8),'Dish V03 — actual sprite composition at recorded scale/shift (not an in-game screenshot)',font=font,fill='white');sources=[]
with Image.open(O/'idle64-256.png') as atlas:
 atlas.load()
 for j,(direction,label) in enumerate([(0,'north'),(16,'east'),(32,'south'),(48,'west')]):
  tile=Image.new('RGBA',(400,400),(36,40,45,255));origin=(200,300)
  def paste(im,scale,shift):
   width=round(im.width*scale*pixels/32);height=round(im.height*scale*pixels/32);image=im.resize((width,height),Image.Resampling.LANCZOS);x=round(origin[0]+shift[0]*pixels-width/2);y=round(origin[1]+shift[1]*pixels-height/2);tile.alpha_composite(image,(x,y))
  for suffix in ['-shadow','','-glow']:
   path=base/f'base-north{suffix}.png'
   with Image.open(path) as im:im.load();paste(im,g['base_scale'],g['base_shift'])
   sources.append({'path':path.as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
  d=direction;dish=atlas.crop(((d%8)*256,(d//8)*256,(d%8+1)*256,(d//8+1)*256));paste(dish,m['factorio_scale_at_256'],m['factorio_shift']);board.paste(tile.convert('RGB'),(j*400,36));draw.text((j*400+12,426),f'cap d{direction:02} / fixed north base',font=font,fill='white')
board.save(O/'mounted-sprite-composition.png');board.save(a.preview_dir/'energy-dish-v03-mounted-sprites.png');(O/'mounted-sprite-composition.json').write_text(json.dumps({'status':'COMPOSITED_PREVIEW','scope':'Actual installed base PNGs and candidate dish PNGs at recorded graphic scales/shifts; proves sprite registration preview only, not native game placement, 3D mount clearance, final shadow or prototype installation','base_draw':g,'dish_draw':{'scale':m['factorio_scale_at_256'],'shift':m['factorio_shift']},'preview_pixels_per_tile':pixels,'base_sources':sources,'dish_atlas_sha256':hashlib.sha256((O/'idle64-256.png').read_bytes()).hexdigest()},indent=2)+'\n');print('MOUNTED_SPRITE_COMPOSITION_WRITTEN')
