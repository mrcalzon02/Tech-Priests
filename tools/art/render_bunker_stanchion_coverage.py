"""Recover actual four-corner stanchion coverage from the original source."""
import bpy,sys,math,json,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
source,out=map(Path,sys.argv[sys.argv.index('--')+1:]);out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source));S=bpy.context.scene
base=bpy.data.collections['RT-P | STATIONARY FERROCRETE + SERVICES']
base_objects=set(base.all_objects)
selected=[o for o in base.all_objects if o.name.startswith('06_corner_armor_buttress_')]
assert len(selected)==4,[o.name for o in selected]
white=bpy.data.materials.new('MASK ONLY stanchion coverage');white.use_nodes=True
n=white.node_tree.nodes;n.clear();e=n.new('ShaderNodeEmission');e.inputs[0].default_value=(1,1,1,1)
o=n.new('ShaderNodeOutputMaterial');white.node_tree.links.new(e.outputs[0],o.inputs[0])
hold=bpy.data.materials.new('MASK ONLY geometry occlusion');hold.use_nodes=True
n=hold.node_tree.nodes;n.clear();e=n.new('ShaderNodeHoldout');o=n.new('ShaderNodeOutputMaterial');hold.node_tree.links.new(e.outputs[0],o.inputs[0])
objects=[o for o in S.objects if o.type in ('MESH','CURVE')]
for obj in objects:
    obj.hide_render=obj not in base_objects
    if obj in base_objects:obj.data.materials.clear();obj.data.materials.append(white if obj in selected else hold)
root=bpy.data.objects.new('MASK_ONLY_BASE_YAW',None);S.collection.objects.link(root)
for obj in base.all_objects:
    if obj.parent is None:
        mw=obj.matrix_world.copy();obj.parent=root;obj.matrix_world=mw
S.camera.location=(0,-8,9.571059226989746);S.camera.rotation_euler=(math.pi/4,0,0)
S.camera.data.type='ORTHO';S.camera.data.ortho_scale=5.047421455383301
S.render.engine='CYCLES';S.cycles.samples=8;S.cycles.use_denoising=False
S.render.threads_mode='FIXED';S.render.threads=4;S.render.use_persistent_data=True
S.render.resolution_x=S.render.resolution_y=512;S.render.resolution_percentage=100
S.render.film_transparent=True;S.use_nodes=False;S.render.use_compositing=False
S.render.image_settings.file_format='PNG';S.render.image_settings.color_mode='RGBA'
for direction,yaw in [('north',180),('east',90),('south',0),('west',270)]:
    root.rotation_euler.z=math.radians(yaw);bpy.context.view_layer.update()
    S.render.filepath=str(out/f'coverage-{direction}.png');bpy.ops.render.render(write_still=True)
(out/'selection.json').write_text(json.dumps({'status':'COVERAGE_RENDERED','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
    'objects':[o.name for o in selected],'mask_scope':'Four corner stanchions only; concrete feet and red armour excluded',
    'camera_ortho':S.camera.data.ortho_scale,'camera_elevation':45},indent=2)+'\n')
