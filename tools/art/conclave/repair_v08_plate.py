"""Remove zero-area bevel residue from the fitted orbital plate, then re-export."""
import bpy,bmesh,sys,json
from pathlib import Path
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/conclave-center/v08-martian-central-emblem';bpy.ops.wm.open_mainfile(filepath=str(O/'conclave-center-v08.blend'));s=bpy.context.scene;repairs=[]
for ob in s.objects:
 if ob.name.startswith('Mars emblem | fitted'):
  before=len(ob.data.polygons);bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7);bm.to_mesh(ob.data);bm.free();ob.data.update();ob.data.calc_loop_triangles();bad=[t for t in ob.data.loop_triangles if (ob.data.vertices[t.vertices[1]].co-ob.data.vertices[t.vertices[0]].co).cross(ob.data.vertices[t.vertices[2]].co-ob.data.vertices[t.vertices[0]].co).length<1e-12];repairs.append(dict(object=ob.name,faces_before=before,faces_after=len(ob.data.polygons),remaining_degenerate=len(bad)))
  assert not bad,ob.name
(O/'plate-repair.json').write_text(json.dumps(repairs,indent=2));s.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(O/'conclave-center-v08.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for ob in s.objects:
 if ob.type=='MESH':ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'conclave-center-v08.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_cameras=False,export_lights=False)
