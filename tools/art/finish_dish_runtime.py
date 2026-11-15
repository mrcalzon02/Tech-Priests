"""Add an authored emitter pulse and calibrated emission/shadow captures.

Run in Blender with the restored A02 camera source loaded. Geometry, UVs,
mount frame and existing packed maps are preserved from the V03 dish.
"""
import bpy
import hashlib
import json
import math
from pathlib import Path
import sys
from mathutils import Vector

dish, output = map(Path, sys.argv[sys.argv.index('--')+1:])
output.mkdir(parents=True, exist_ok=True)
scene=bpy.context.scene
camera=scene.camera
keep={o for o in scene.objects if o.type in ('CAMERA','LIGHT') and not o.name.startswith('FLASH_LIGHT_')}
for o in keep:
    world=o.matrix_world.copy();o.parent=None;o.matrix_world=world
    o.animation_data_clear();o.data.animation_data_clear()
for o in list(scene.objects):
    if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
with bpy.data.libraries.load(str(dish),link=False) as (source, loaded):
    loaded.objects=[n for n in source.objects if n not in {o.name for o in keep}]
for o in loaded.objects:
    if o and o.type in ('MESH','EMPTY'):scene.collection.objects.link(o)
for collection in bpy.data.collections:collection.hide_render=False
def enable(lc):
    lc.exclude=False;lc.hide_viewport=False
    for child in lc.children:enable(child)
for layer in list(scene.view_layers)[1:]:scene.view_layers.remove(layer)
enable(scene.view_layers[0].layer_collection)
scene.use_nodes=False;scene.render.use_compositing=False;scene.render.use_sequencer=False
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=4
scene.cycles.use_denoising=True;scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.render.resolution_percentage=100
root=bpy.data.objects['TURRET_TRAVERSE']
emitter=bpy.data.objects['EMITTER_TIP']
material=bpy.data.materials.new('DISH_V04 | ceramic energized emitter')
material.use_nodes=True
bsdf=material.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Base Color'].default_value=(.06,.2,.24,1)
bsdf.inputs['Metallic'].default_value=.15;bsdf.inputs['Roughness'].default_value=.27
bsdf.inputs['Emission Color'].default_value=(.12,.75,1,1)
for frame,power in [(1,0),(6,8),(11,5),(21,2),(31,.3),(41,0)]:
    bsdf.inputs['Emission Strength'].default_value=power
    bsdf.inputs['Emission Strength'].keyframe_insert('default_value',frame=frame)
emitter.data.materials.clear();emitter.data.materials.append(material)
scene.render.fps=60;scene.frame_start=1;scene.frame_end=40;scene.frame_set(1)
scene['surface_plan']='Existing oxide-red armor, machined reflector and gunmetal supports retained; dedicated cyan ceramic emitter with forty-tick energized pulse.'
scene['runtime_contract']='3x3 shared fixed base; 64 clockwise headings; unchanged bearing at Z=1.70; native electric beam and energy-gated glow.'
for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file:im.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(output/'energy_dish_v04.blend'),compress=True)
# Source artifact saved before pass-only holdouts and catcher are installed.
holdout=bpy.data.materials.new('PASS_ONLY_OCCLUSION');holdout.use_nodes=True
nodes=holdout.node_tree.nodes;nodes.clear()
out=nodes.new('ShaderNodeOutputMaterial');hold=nodes.new('ShaderNodeHoldout')
holdout.node_tree.links.new(hold.outputs[0],out.inputs['Surface'])
original={o.name:list(o.data.materials) for o in scene.objects if o.type=='MESH'}
for o in scene.objects:
    if o.type=='MESH' and o!=emitter:
        o.data.materials.clear();o.data.materials.append(holdout)
scene.frame_set(6)
camera.data.ortho_scale=6.199999809265137
scene.render.resolution_x=scene.render.resolution_y=256
for d in range(64):
    path=output/f'emission-{d:02}.png'
    if path.exists():continue
    root.rotation_euler.z=math.radians(180-d*5.625)
    scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    print('DISH_EMISSION',d,flush=True)
for name,materials in original.items():
    o=bpy.data.objects[name];o.data.materials.clear()
    for m in materials:o.data.materials.append(m)
scene.frame_set(1)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,0))
catcher=bpy.context.object;catcher.name='PASS_ONLY_GROUND';catcher.is_shadow_catcher=True
scene.cycles.samples=16
scene.view_layers[0].cycles.use_pass_shadow_catcher=True
tree=bpy.data.node_groups.new('DISH shadow ratio denoised before alpha','CompositorNodeTree')
tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
rl=tree.nodes.new('CompositorNodeRLayers');rl.layer=scene.view_layers[0].name
denoise=tree.nodes.new('CompositorNodeDenoise');tree.links.new(rl.outputs['Shadow Catcher'],denoise.inputs['Image'])
luma=tree.nodes.new('CompositorNodeRGBToBW');tree.links.new(denoise.outputs['Image'],luma.inputs[0])
inverse=tree.nodes.new('ShaderNodeMath');inverse.operation='SUBTRACT';inverse.inputs[0].default_value=1;inverse.use_clamp=True
tree.links.new(luma.outputs[0],inverse.inputs[1])
# Use the same finite receiver as the established A02 shadow pipeline.
from array import array
mask=bpy.data.images.new('DISH registered receiver',width=512,height=512,alpha=True,float_buffer=True)
pixels=array('f')
for y in range(512):
    for x in range(512):
        radius=math.sqrt(((x-256)/217.6)**2+((511-y-301.86968994140625)/179.2)**2)
        t=max(0,min(1,(radius-.78)/.22));value=1-t*t*(3-2*t)
        pixels.extend((value,value,value,1))
mask.pixels.foreach_set(pixels)
mi=tree.nodes.new('CompositorNodeImage');mi.image=mask
mul=tree.nodes.new('ShaderNodeMath');mul.operation='MULTIPLY'
tree.links.new(inverse.outputs[0],mul.inputs[0]);tree.links.new(mi.outputs['Image'],mul.inputs[1])
alpha=tree.nodes.new('CompositorNodeSetAlpha');alpha.inputs['Image'].default_value=(0,0,0,1)
tree.links.new(mul.outputs[0],alpha.inputs['Alpha'])
outnode=tree.nodes.new('NodeGroupOutput');tree.links.new(alpha.outputs['Image'],outnode.inputs['Image'])
scene.use_nodes=True;scene.render.use_compositing=True;scene.compositing_node_group=tree
camera.data.ortho_scale=12.399999618530274
scene.render.resolution_x=scene.render.resolution_y=512
for d in range(64):
    path=output/f'shadow-clean-{d:02}.png'
    if path.exists():continue
    root.rotation_euler.z=math.radians(180-d*5.625)
    # Camera rays see only the catcher; the actual dish casts its own shadow.
    for name in original:bpy.data.objects[name].visible_camera=False
    scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    print('DISH_SHADOW',d,flush=True)
(output/'capture.json').write_text(json.dumps({'status':'CAPTURE_COMPLETE','source_sha256':hashlib.sha256(dish.read_bytes()).hexdigest(),
    'directions':64,'mapping':'N0 E16 S32 W48','source_geometry_preserved':True,
    'emission_cell':256,'shadow_cell':512,'samples':16,'shadow_revision':'denoised ratio and registered bounded receiver','emitter_cycle_ticks':40},indent=2)+'\n')
