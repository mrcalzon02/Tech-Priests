"""Capture articulated artillery ground shadows, independently of the bunker."""
from pathlib import Path
import sys,json,hashlib,time,shutil
from mathutils import Vector
helper=Path(__file__).with_name('capture_bullet_turrets.py')
kit=helper.read_text().split('def render(')[0]
start=kit.index("variant=S['variant']");end=kit.index("root=bpy.data.objects")
kit=kit[:start]+kit[end:]
kit=kit.replace("sys.argv[sys.argv.index('--')+1:]","sys.argv[sys.argv.index('--')+1:sys.argv.index('--')+3]")
exec(compile(kit,str(helper),'exec'),globals())
capture=Path(sys.argv[sys.argv.index('--')+3]);main=json.loads((capture/'identity.json').read_text());ticks=main['ticks']
arguments=sys.argv[sys.argv.index('--')+1:];cache=Path(arguments[3])if len(arguments)>3 else None
reuse=json.loads((capture/'reuse.json').read_text())if cache else None
rendered={};reused=0
assert hashlib.sha256(source.read_bytes()).hexdigest()==main['source_sha256']
identity={**main,'cell':384,'scale':1.6,'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
 'helper_sha256':hashlib.sha256(helper.read_bytes()).hexdigest(),'scope':'Actual moving ground shadow, no bunker or ammunition'}
(out/'identity.json').write_text(json.dumps(identity,indent=2)+'\n')
target=Vector((0,0,3.5));S.camera.location=target+Vector((0,-10,10));S.camera.rotation_euler=(target-S.camera.location).to_track_quat('-Z','Y').to_euler()
S.camera.data.ortho_scale=19.2;S.render.resolution_x=S.render.resolution_y=384
mask.scale(384,384);pixels=array('f')
for y in range(384):
 for x in range(384):
  radius=math.sqrt(((x-192)/176)**2+((383-y-(192+main['shift'][1]*-20))/155)**2)
  t=max(0,min(1,(radius-.85)/.15));a=1-t*t*(3-2*t);pixels.extend((a,a,a,1))
mask.pixels.foreach_set(pixels)
root.animation_data_clear();root.delta_rotation_euler=(0,0,0);S.render.use_persistent_data=True
for obj in body:obj.visible_camera=False
rounds=[bpy.data.objects['LOADED_ARTILLERY_SHELL_'+str(i)] for i in range(3)]
catcher.hide_render=False;S.use_nodes=True;S.render.use_compositing=True;S.compositing_node_group=tree
completed=[];began=time.monotonic()
for d in [0,16,32,48]+[d for d in range(64)if d not in (0,16,32,48)]:
 for i,tick in enumerate(ticks):
  path=out/f'd{d:02}-shadow-{i:03}.png'
  if not path.exists():
   alias=reuse and reuse['aliases']['body'].get(str(tick));key=(d,alias if alias is not None else ('new',tick));inherited=None
   if alias is not None:
    old_index=reuse['cache_identity']['ticks'].index(alias);candidate=cache/f'd{d:02}-shadow-{old_index:03}.png'
    if candidate.exists():inherited=candidate
   if inherited is None:inherited=rendered.get(key)
   if inherited:shutil.copy2(inherited,path);reused+=1
   else:
    S.frame_set(tick+1);root.rotation_euler.z=math.pi-d*math.tau/64
    for round in rounds:round.scale=(0,0,0)
    bpy.context.view_layer.update();S.render.filepath=str(path);bpy.ops.render.render(write_still=True)
   rendered[key]=path
 completed.append(d)
 temp=out/'capture.next.json';temp.write_text(json.dumps({'status':'COMPLETE'if len(completed)==64 else 'RUNNING',
  'identity':identity,'completed_headings':completed,'elapsed_seconds':time.monotonic()-began},indent=2)+'\n');temp.replace(out/'capture.json')
 print('ARTILLERY_MOVING_SHADOW_DIRECTION',d,flush=True)
