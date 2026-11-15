"""Capture actual moving ground shadows at the same poses as the reload body.

Blender --python THIS -- SOURCE OUT
Uses the established neutral shadow receiver; omits the separate fixed bunker.
"""
from pathlib import Path
import sys,hashlib,time
helper=Path(__file__).with_name('capture_bullet_turrets.py')
kit=helper.read_text().split('def render(')[0]
start=kit.index('identity={');end=kit.index("root=bpy.data.objects")
kit=kit[:start]+kit[end:]
exec(compile(kit,str(helper),'exec'),globals())
identity={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
 'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
 'helper_sha256':hashlib.sha256(helper.read_bytes()).hexdigest(),'headings':64,'cell':512,
 'frames':95,'source_reload_frames':[52,240],'scale':.774999976158,'shift':[0,-1.110906519093],
 'base_included':False,'receiver':'Established bounded neutral family ground shadow catcher'}
if (out/'identity.json').exists():assert json.loads((out/'identity.json').read_text())==identity,'Shadow inputs changed'
else:(out/'identity.json').write_text(json.dumps(identity,indent=2)+'\n')
root.animation_data_clear();root.delta_rotation_euler=(0,0,0);S.render.use_persistent_data=True
for obj in body:obj.visible_camera=False
rounds=[o for o in S.objects if o.name.startswith('LOADED_ROCKET_')]
catcher.hide_render=False;S.use_nodes=True;S.render.use_compositing=True;S.compositing_node_group=tree
S.camera.data.ortho_scale=12.399999618530274;S.render.resolution_x=S.render.resolution_y=512
def pose(d,f):
    S.frame_set(f);root.rotation_euler.z=math.pi-d*math.tau/64
    for ob in rounds:ob.scale=(0,0,0)
    bpy.context.view_layer.update()
def capture(path):
    if path.exists():return
    S.render.filepath=str(path);bpy.ops.render.render(write_still=True)
began=time.monotonic()
for d in range(64):
    pose(d,1);capture(out/f'd{d:02}-idle.png')
    for f in range(95):
        pose(d,52+f*2);capture(out/f'd{d:02}-reload-{f:02}.png')
        if f%20==0:print('ROCKET_SHADOW_PROGRESS',d,f,round(time.monotonic()-began,1),flush=True)
    print('ROCKET_SHADOW_DIRECTION_DONE',d,flush=True)
(out/'capture.json').write_text(json.dumps({'status':'COMPLETE','identity':identity,'directions':64,
 'elapsed_seconds':time.monotonic()-began,'scope':'Actual structural ground shadows for idle and every reload pose'},indent=2)+'\n')
print('ROCKET_RELOAD_SHADOWS_DONE',flush=True)
