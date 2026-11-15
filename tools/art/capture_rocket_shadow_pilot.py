"""Actual settled cap shadows for the four-direction runtime pilot.

Moving reload shadows remain a separate production gate; this is not the final
all-direction animation delivery. Reuse the calibrated family shadow receiver.
"""
from pathlib import Path
import sys,hashlib
helper=Path(__file__).with_name('capture_bullet_turrets.py')
kit=helper.read_text().split('def render(')[0]
kit=kit.replace("ticks=48 if variant=='chicago-piano' else 36",'ticks=240')
kit=kit.replace("'script_sha256':", "'capture_helpers_sha256':hashlib.sha256(helper.read_bytes()).hexdigest(),'script_sha256':")
exec(compile(kit,str(helper),'exec'),globals())
root.animation_data_clear();root.delta_rotation_euler=(0,0,0);S.render.use_persistent_data=True
for obj in body:obj.visible_camera=False
catcher.hide_render=False;S.use_nodes=True;S.render.use_compositing=True;S.compositing_node_group=tree
S.camera.data.ortho_scale=12.399999618530274;S.render.resolution_x=S.render.resolution_y=512
S.frame_set(241)
for d in (0,16,32,48):
    root.rotation_euler.z=math.pi-d*math.tau/64;bpy.context.view_layer.update()
    path=out/f'shadow-{d:02}.png'
    if not path.exists():S.render.filepath=str(path);bpy.ops.render.render(write_still=True)
(out/'capture.json').write_text(json.dumps({'status':'PILOT_STATIC_SHADOWS','directions':[0,16,32,48],
 'source_sha256':identity['source_sha256'],'cell':512,'remaining':'Animated reload shadows and all 64 headings'},indent=2)+'\n')
print('ROCKET_SHADOW_PILOT_DONE',flush=True)
