"""Actual static cap shadow per heading, using the family shadow receiver."""
from pathlib import Path
import hashlib
helper=Path(__file__).with_name('capture_bullet_turrets.py')
kit=helper.read_text().split('def render(')[0]
kit=kit.replace("'script_sha256':", "'capture_helpers_sha256':hashlib.sha256(helper.read_bytes()).hexdigest(),'script_sha256':")
exec(compile(kit,str(helper),'exec'),globals())
root.animation_data_clear();root.delta_rotation_euler=(0,0,0)
S.render.use_persistent_data=True
for obj in body:obj.visible_camera=False
catcher.hide_render=False;S.use_nodes=True;S.render.use_compositing=True;S.compositing_node_group=tree
S.camera.data.ortho_scale=12.399999618530274;S.render.resolution_x=S.render.resolution_y=512
S.frame_set(226)
for d in range(64):
    root.rotation_euler.z=math.pi-d*math.tau/64;bpy.context.view_layer.update()
    path=out/f'shadow-{d:02}.png'
    if not path.exists():S.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    print('CANNON_SHADOW_DIRECTION',d,flush=True)
(out/'capture.json').write_text(json.dumps({'status':'COMPLETE','pass':'static-cap-shadow','source_sha256':identity['source_sha256'],
    'directions':64,'cell':512,'scale':.774999976158,'shift':[0,-1.110906519093],
    'shadow_mode':'Actual Cycles shadow catcher with established bounded family receiver'},indent=2)+'\n')
