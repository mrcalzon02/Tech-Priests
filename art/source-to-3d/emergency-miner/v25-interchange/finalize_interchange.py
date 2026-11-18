import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parent;A=R/'interchange-v01';bpy.ops.wm.open_mainfile(filepath=str(A/'miner-v25-image-materials.blend'));s=bpy.context.scene
# Six original rig frames correspond to each approved8fps sprite sample.
# 48fps gives the physical interchange the same2second cycle without editing keys.
s.render.fps=48;s.frame_end=97;s.frame_set(1)
physical=[o for o in s.objects if o.type=='MESH'and not o.hide_render and not o.name.startswith('FX ONLY')]
def bounds(o):
 dg=bpy.context.evaluated_depsgraph_get();e=o.evaluated_get(dg);m=e.to_mesh();vs=[e.matrix_world@v.co for v in m.vertices];e.to_mesh_clear();return[[min(v[i]for v in vs)for i in range(3)],[max(v[i]for v in vs)for i in range(3)]]
poses={}
for f in [1,13,25,37,49,61,73,85,97]:
 s.frame_set(f);bpy.context.view_layer.update();poses[str(f)]={o.name:bounds(o)for o in physical}
s.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(A/'miner-v25-image-materials.blend'));bpy.ops.object.select_all(action='DESELECT')
for o in physical:
 o.select_set(True);p=o.parent
 while p:p.select_set(True);p=p.parent
bpy.context.view_layer.objects.active=physical[0]
bpy.ops.export_scene.gltf(filepath=str(A/'miner-v25-physical.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_anim_slide_to_zero=True,export_frame_range=True,export_force_sampling=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
(A/'source-pose-reference.json').write_text(json.dumps({'fps':48,'source_frames_per_sprite':6,'approved_sprite_fps':8,'cycle_seconds':2,'poses':poses},indent=2));print('MINER_MATCHING_TWO_SECOND_SCENE_CLIP_EXPORTED')
