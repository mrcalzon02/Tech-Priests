"""Verify all actual idle captures, build atlases, prove cell readback and registration."""
from PIL import Image,ImageChops,ImageDraw
import pathlib,json,hashlib,math,argparse
p=argparse.ArgumentParser();p.add_argument('--output',type=pathlib.Path,default=pathlib.Path('work/energy-dish-v03'));p.add_argument('--preview-dir',type=pathlib.Path,default=pathlib.Path('outputs'));a=p.parse_args();O=a.output;a.preview_dir.mkdir(parents=True,exist_ok=True);I=O/'idle64';identity=json.loads((I/'identity.json').read_text());checkpoint=json.loads((I/'capture-checkpoint.json').read_text())
assert checkpoint['status']=='idle64_complete' and len(checkpoint['completed'])==64
atlas640=Image.new('RGBA',(5120,5120));atlas256=Image.new('RGBA',(2048,2048));frames=[];records=[]
board=Image.new('RGB',(1600,850),(36,40,45));draw=ImageDraw.Draw(board)
for d in range(64):
 path=I/f'idle-{d:02}.png'
 with Image.open(path) as probe:probe.verify()
 with Image.open(path) as raw:
  raw.load();assert raw.mode=='RGBA' and raw.size==(640,640)
  box=raw.getchannel('A').getbbox();assert box and min(box)>0 and box[2]<640 and box[3]<640,(d,box)
  small=raw.resize((256,256),Image.Resampling.LANCZOS);atlas640.paste(raw,((d%8)*640,(d//8)*640));atlas256.paste(small,((d%8)*256,(d//8)*256))
  bg=Image.new('RGBA',raw.size,(36,40,45,255));bg.alpha_composite(raw);frames.append(bg.convert('RGB').resize((320,320),Image.Resampling.LANCZOS))
  if d%8==0:
   j=d//8;board.paste(bg.convert('RGB').resize((400,400),Image.Resampling.LANCZOS),((j%4)*400,(j//4)*425));draw.text(((j%4)*400+10,(j//4)*425+403),f'd{d:02} / '+['N','NE','E','SE','S','SW','W','NW'][j],fill='white')
  records.append({'direction':d,'yaw_degrees':180-d*5.625,'raw_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'raw_alpha_bounds':box})
for size,sheet in [(640,atlas640),(256,atlas256)]:
 path=O/f'idle64-{size}.png';sheet.save(path)
 with Image.open(path) as check:
  check.load();assert check.mode=='RGBA' and check.size==(size*8,size*8)
  for d in range(64):
   with Image.open(I/f'idle-{d:02}.png') as raw:expected=raw if size==640 else raw.resize((256,256),Image.Resampling.LANCZOS);cell=check.crop(((d%8)*size,(d//8)*size,(d%8+1)*size,(d//8+1)*size));assert ImageChops.difference(expected,cell).getbbox(alpha_only=False) is None
frames[0].save(O/'idle64-rotation.gif',save_all=True,append_images=frames[1:],duration=80,loop=0,optimize=False);board.save(O/'idle64-eight-headings.png');board.save(a.preview_dir/'energy-dish-v03-eight-headings.png')
frames[0].save(a.preview_dir/'energy-dish-v03-rotation.gif',save_all=True,append_images=frames[1:],duration=80,loop=0,optimize=False)
matrix=identity['camera_world_matrix'];ortho=identity['ortho_scale']
def project(point):
 delta=[point[j]-matrix[j][3] for j in range(3)];local=[sum(matrix[j][i]*delta[j] for j in range(3)) for i in range(3)];return [(0.5+local[0]/ortho)*640,(0.5-local[1]/ortho)*640]
origin=project((0,0,0));mount=project((0,0,1.7));shift=[(320-origin[i])*ortho/640 for i in range(2)]
assert abs(origin[0]-320)<1e-4 and abs(origin[1]-434.6742248535156)<1e-3,(origin,mount)
manifest={'status':'VERIFIED_64_IDLE_BEAUTY_ONLY','source_identity':identity,'direction_count':64,'frames_per_direction':1,'atlas_columns':8,'atlas_rows':8,'source_cell':640,'candidate_game_cell':256,'factorio_scale_at_256':32*ortho/256,'factorio_shift':shift,'entity_origin_pixel_at_640':origin,'mount_pixel_at_640':mount,'atlas_cell_readback':'128 exact RGBA cells verified: 64 raw +64 deterministic Lanczos downsample','no_clipped_raw_frames':True,'planned_imports':{'sprites':'tech-priests_src/graphics/entity/bunker-energy-dish/','graphics_module':'tech-priests_src/prototypes/generated_graphics/bunker-energy-dish-v03.lua'},'integration_status':'not installed; exact native turret/prototype and firing/emission/shadow states remain open','records':records}
(O/'idle64-validation.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps({k:manifest[k] for k in ['status','factorio_scale_at_256','factorio_shift','entity_origin_pixel_at_640','mount_pixel_at_640']}))
