"""Independent GLB crane bearing and guide inspection views."""
import bpy,json,math,hashlib,sys
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/space-cargo-inventories/v01/advanced';bpy.ops.wm.open_mainfile(filepath=str(O/'advanced-space-cargo-v01.blend'));s=bpy.context.scene
for ob in list(s.objects):
 if ob.type in ('MESH','EMPTY'):bpy.data.objects.remove(ob,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(O/'advanced-space-cargo-v01.glb'))
sys.path.insert(0,str(R/'tools/fmpl'));from below_grade_occlusion import add_grade_holdouts
add_grade_holdouts(s,bpy,json.loads((O/'occlusion.json').read_text()))
s.cycles.samples=48;s.render.resolution_x=1100;s.render.resolution_y=1100;s.render.resolution_percentage=100
saved_camera_matrix=s.camera.matrix_world.copy();saved_ortho=s.camera.data.ortho_scale
for name,eye,target,scale in [('crane-bearing-closeup',(5,-5,3.2),(1.35,.12,.95),2.65),('crane-rear-construction',(-5,6,4),(.2,.5,1.15),4.2)]:
 cam=s.camera;cam.location=eye;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale;s.render.filepath=str(O/'inspection'/f'{name}.png');bpy.ops.render.render(write_still=True)
s.camera.matrix_world=saved_camera_matrix;s.camera.data.ortho_scale=saved_ortho
clay=bpy.data.materials.new('QA neutral rough grey');clay.use_nodes=True;bs=clay.node_tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=(.18,.18,.18,1);bs.inputs['Roughness'].default_value=.8
for ob in s.objects:
 if ob.type=='MESH' and not ob.get('fmpl_render_only'):
  ob.data.materials.clear();ob.data.materials.append(clay)
  if ob.get('cargo_glass'):ob.hide_render=True
s.render.filepath=str(O/'inspection/clay-cutaway.png');bpy.ops.render.render(write_still=True)
print('INDEPENDENT_CRANE_CLOSEUPS_RENDERED')
