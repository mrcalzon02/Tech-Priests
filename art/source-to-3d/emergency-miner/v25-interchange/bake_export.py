"""Interchange derivative only. Never overwrite the byte-preserved approved source/sprites."""
import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parent;A=R/'interchange-v01';A.mkdir(exist_ok=True);T=A/'textures';T.mkdir(exist_ok=True)
src=R/'recovered-original/emergency-miner-motion-v21/review/miner_motion_A.blend'
bpy.ops.wm.open_mainfile(filepath=str(src));s=bpy.context.scene;s.frame_set(1)
original_bounds={o.name:[list(o.matrix_world@Vector(c))for c in o.bound_box]for o in s.objects if o.type in {'MESH','CURVE'}and not o.name.startswith('FX ONLY')}
fx=[o for o in s.objects if o.name.startswith('FX ONLY')]
for o in fx:o.hide_render=True;o.hide_set(True)
physical=[o for o in s.objects if o.type in {'MESH','CURVE'}and not o.name.startswith('FX ONLY')and not o.hide_render]
bpy.ops.object.select_all(action='DESELECT')
for o in physical:o.select_set(True)
bpy.context.view_layer.objects.active=physical[0];bpy.ops.object.convert(target='MESH')
physical=[o for o in bpy.context.selected_objects if o.type=='MESH'];materials={m for o in physical for m in o.data.materials if m}
# Keep local generated/object coordinates during all bakes, and the exact rig transforms.
for o in physical:
 if not o.data.uv_layers:o.data.uv_layers.new(name='FMPL_ModelAtlas')
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.003,area_weight=.4,correct_aspect=True,scale_to_bounds=False);bpy.ops.object.mode_set(mode='OBJECT')
s.render.engine='CYCLES';s.cycles.samples=8;s.cycles.bake_type='EMIT';s.render.bake.use_selected_to_active=False;s.render.bake.margin=8;s.render.bake.use_clear=True
images={}
for channel in ['albedo','orm','normal']:
 im=bpy.data.images.new('MinerV25_'+channel,width=2048,height=2048,alpha=True);im.colorspace_settings.name='sRGB'if channel=='albedo'else'Non-Color';images[channel]=im
saved={}
for m in materials:
 nt=m.node_tree;p=next((n for n in nt.nodes if n.type=='BSDF_PRINCIPLED'),None);out=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL'and n.is_active_output)
 assert p,m.name
 saved[m.name]={'p':p,'out':out,'surface':[(l.from_socket,l.to_socket)for l in nt.links if l.to_node==out and l.to_socket.name=='Surface'],'alpha':p.inputs['Alpha'].default_value,'emission':list(p.inputs['Emission Color'].default_value),'emission_strength':p.inputs['Emission Strength'].default_value}
 target=nt.nodes.new('ShaderNodeTexImage');target.name='FMPL_BAKE_TARGET';nt.nodes.active=target
def input_to(nt,src,dst):
 if src.is_linked:nt.links.new(src.links[0].from_socket,dst)
 else:dst.default_value=src.default_value
for channel in ['albedo','orm','normal']:
 for m in materials:
  nt=m.node_tree;v=saved[m.name];p=v['p'];out=v['out'];target=nt.nodes['FMPL_BAKE_TARGET'];target.image=images[channel];nt.nodes.active=target
  for l in list(nt.links):
   if l.to_node==out and l.to_socket.name=='Surface':nt.links.remove(l)
  if channel=='normal':
   for a,b in v['surface']:nt.links.new(a,b)
  else:
   em=nt.nodes.new('ShaderNodeEmission');em.name='FMPL_TEMP_EMIT'
   if channel=='albedo':input_to(nt,p.inputs['Base Color'],em.inputs['Color'])
   else:
    rgb=nt.nodes.new('ShaderNodeCombineColor');rgb.name='FMPL_TEMP_ORM';rgb.inputs['Red'].default_value=1;input_to(nt,p.inputs['Roughness'],rgb.inputs['Green']);input_to(nt,p.inputs['Metallic'],rgb.inputs['Blue']);nt.links.new(rgb.outputs['Color'],em.inputs['Color'])
   nt.links.new(em.outputs[0],out.inputs['Surface'])
 bpy.ops.object.bake(type='NORMAL'if channel=='normal'else'EMIT')
 im=images[channel];im.filepath_raw=str(T/(channel+'.png'));im.file_format='PNG';im.save();im.pack()
 for m in materials:
  nt=m.node_tree
  for n in list(nt.nodes):
   if n.name.startswith('FMPL_TEMP_'):nt.nodes.remove(n)
for m in materials:
 nt=m.node_tree;v=saved[m.name];p=v['p'];out=v['out']
 for a,b in v['surface']:nt.links.new(a,b)
 # Export only baked physical channels; original source retains the complete procedural graphs.
 for l in list(nt.links):
  if l.to_node==p and l.to_socket.name in {'Base Color','Roughness','Metallic','Normal'}:nt.links.remove(l)
 nodes={}
 for channel in images:
  n=nt.nodes.new('ShaderNodeTexImage');n.image=images[channel];n.label='V25 model-specific '+channel;nodes[channel]=n
 nt.links.new(nodes['albedo'].outputs['Color'],p.inputs['Base Color'])
 sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(nodes['orm'].outputs['Color'],sep.inputs[0]);nt.links.new(sep.outputs['Green'],p.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],p.inputs['Metallic'])
 normal=nt.nodes.new('ShaderNodeNormalMap');nt.links.new(nodes['normal'].outputs['Color'],normal.inputs['Color']);nt.links.new(normal.outputs['Normal'],p.inputs['Normal'])
 m.name='MinerV25_'+m.name
s['interchange_scope']='Image-baked physical source and TRS animation derivative. Animated shader/light/steam effects stay in approved editable original and installed sprites. No sprites regenerated.'
report={'original_source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'physical_meshes':len(physical),'materials':len(materials),'texture_size':2048,'uv_layout':'Combined area-weighted smart projection, padded shared model atlas; objects remain separate under original rig','channels':{'albedo':'Original procedural base color baked','orm':'R=constant1 (no AO claim); G=original roughness; B=original metallic','normal':'Actual tangent normal bake including original procedural bump'},'excluded_effects':[o.name for o in fx],'source_geometry_bound_corners':original_bounds,'sprites_changed':False,'blender_warning':'Original5.2.3 opened using5.0; source bytes preserved. Derivative must independently verify poses/bounds.'}
(A/'bake-manifest.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(A/'miner-v25-image-materials.blend'))
bpy.ops.object.select_all(action='DESELECT')
for o in physical:
 o.select_set(True)
 parent=o.parent
 while parent:parent.select_set(True);parent=parent.parent
bpy.context.view_layer.objects.active=physical[0]
bpy.ops.export_scene.gltf(filepath=str(A/'miner-v25-physical.glb'),export_format='GLB',use_selection=True,export_animations=True,export_frame_range=True,export_force_sampling=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
print('MINER_PHYSICAL_IMAGE_DERIVATIVE_EXPORTED')
