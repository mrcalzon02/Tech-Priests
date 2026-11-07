"""Fixed registration: 64 clockwise headings, 32 firing frames per heading."""
import bpy,math,json,sys,argparse,shutil,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--directions',default='all');p.add_argument('--frames',default='all');p.add_argument('--out',default='rendered');a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
O=Path(a.out).resolve();O.mkdir(parents=True,exist_ok=True)
S=bpy.context.scene;P=bpy.data.objects['TURRET_TRAVERSE_PIVOT_Z_1_70']
for vl in S.view_layers:vl.use=vl.name=='TURRET_ONLY'
bpy.context.window.view_layer=S.view_layers['TURRET_ONLY']
S.render.use_persistent_data=True;S.render.use_sequencer=False
S.cycles.samples=16;S.cycles.use_denoising=True
S.render.resolution_x=S.render.resolution_y=640;S.render.resolution_percentage=100
S.render.image_settings.file_format='PNG';S.render.image_settings.color_mode='RGBA';S.render.film_transparent=True
assert S.view_layers['TURRET_ONLY'].layer_collection.children['BASE_STATIC'].exclude
assert not any(o.name.startswith(('SYMBOL_BRASS_ROOF_MARS','SYMBOL_BRASS_SERVICE_PLATE_MARS')) for o in S.objects)
assert all(o.parent==P for o in S.objects if o.name.startswith('SHOT_SMOKE_'))
directions=range(64) if a.directions=='all' else [int(x) for x in a.directions.split(',')]
frames=range(1,33) if a.frames=='all' else [int(x) for x in a.frames.split(',')]
source_hash=hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()
identity={'source_sha256':source_hash,'size':640,'samples':16,'mapping':'north0_clockwise','frames':list(frames)}
identity_path=O/'identity.json'
if identity_path.exists():assert json.loads(identity_path.read_text())==identity,'Cache identity mismatch'
else:identity_path.write_text(json.dumps(identity,indent=2))
for d in directions:
 assert 0<=d<64
 D=O/f'd{d:02}';D.mkdir(exist_ok=True)
 for f in frames:
  assert 1<=f<=32
  S.frame_set(f);P.rotation_euler.z=math.radians(180-d*5.625);bpy.context.view_layer.update()
  path=D/f'f{f:02}.png'
  if path.exists():continue
  S.render.filepath=str(path);bpy.ops.render.render(write_still=True,layer='TURRET_ONLY')
  print('CAPTURE_FRAME',d,f,flush=True)
 (D/'heading.json').write_text(json.dumps({'direction':d,'factorio_orientation':d/64,'yaw_degrees':180-d*5.625,'fps':24,'frames':32,'idle_frame':1,'source_sha256':source_hash},indent=2))
print('REQUEST_COMPLETE',list(directions),list(frames),flush=True)
