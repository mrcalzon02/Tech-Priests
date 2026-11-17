"""Controlled cargo material studies in the exact emergency-boiler workshop rig."""
from pathlib import Path
import bpy,json,sys,math,hashlib,importlib.util
from mathutils import Vector
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/space-cargo-inventories/v01/basic';D=O/'studies/material-environment';D.mkdir(parents=True,exist_ok=True);env=json.loads((D/'environment-audit.json').read_text())['boiler'];src=O/'basic-space-cargo-v01.blend';h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def module(p,n):
 spec=importlib.util.spec_from_file_location(n,str(p));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
imp=module(R/'art/source-to-3d/shared-parts/industrial-asset-library/import_materials.py','cargo_study_fmpl');sys.path.insert(0,str(R/'tools/fmpl'));from below_grade_occlusion import add_grade_holdouts
catalog=json.loads((R/'art/source-to-3d/shared-parts/industrial-asset-library/catalog.json').read_text());records={r['material_id']:r for r in catalog['materials']};manifest=json.loads((O/'occlusion.json').read_text());rows=[]
def geometry():
 return {o.name:dict(matrix=[list(r) for r in o.matrix_world],vertices=[list(v.co) for v in o.data.vertices],faces=[list(p.vertices) for p in o.data.polygons]) for o in bpy.context.scene.objects if o.type=='MESH' and not o.get('fmpl_render_only')}
def environment(s):
 for ob in list(s.objects):
  if ob.type=='LIGHT':bpy.data.objects.remove(ob,do_unlink=True)
 bg=s.world.node_tree.nodes.get('Background');rec=env['world_nodes'][0]['inputs'];bg.inputs['Color'].default_value=rec['Color'];bg.inputs['Strength'].default_value=rec['Strength']
 for rec in env['lights']:
  data=bpy.data.lights.new(rec['name'],rec['type']);data.energy=rec['energy'];data.color=rec['color'];data.size=rec['size'];data.shape='DISK';ob=bpy.data.objects.new(rec['name'],data);s.collection.objects.link(ob);ob.location=rec['location'];ob.rotation_euler=rec['rotation']
 s.view_settings.view_transform=env['view']['transform'];s.view_settings.look=env['view']['look'];s.view_settings.exposure=env['view']['exposure'];s.view_settings.gamma=env['view']['gamma'];s.cycles.samples=96;s.cycles.use_denoising=True;s.render.resolution_x=s.render.resolution_y=1024;s.render.film_transparent=True
 prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
 for d in prefs.devices:d.use=d.type=='OPTIX'
 s.cycles.device='GPU'
def render(s,p):s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
for key in ('a-current-workshop','b-fmpl-steel','c-fmpl-painted'):
 P=D/key;P.mkdir(exist_ok=True);bpy.ops.wm.open_mainfile(filepath=str(src));s=bpy.context.scene;before=geometry();environment(s);root=bpy.data.objects['Basic Cargo | grade origin'];materials={};uv_scale=.65
 if key!='a-current-workshop':
  imported=imp.import_materials(R,['machine_steel','gunmetal_dark','iron','brass','dark_recess','martian_red','red_dark','machined_bright','glass'],pack=True)
  for role,ident in [('deck-steel','machine_steel'),('structure','gunmetal_dark'),('cargo-green','iron'),('aged-brass','brass'),('well-liner','dark_recess'),('barrel-red','martian_red'),('tool-steel','machined_bright')]:
   if key=='c-fmpl-painted' and role=='deck-steel':ident='red_dark'
   mat=imported[ident].copy();mat.name='Cargo study | '+key+' | '+role;mat['cargo_role']=role;materials[role]=mat
  # Green optical glass is an explicit derivative of the canonical optics maps.
  mat=imported['glass'].copy();mat.name='Cargo study | green viewing glass';bs=mat.node_tree.nodes.get('Principled BSDF');n=mat.node_tree.nodes.get('TP_LIBRARY_ALBEDO');im=n.image.copy();im.name=key+' | green optical albedo';import numpy as np
  a=np.array(im.pixels[:],dtype=np.float32).reshape(-1,4);lum=a[:,:3].mean(axis=1);a[:,:3]=lum[:,None]*np.array([.52,1.0,.48]);im.pixels[:]=a.reshape(-1);im.pack();n.image=im;bs.inputs['Alpha'].default_value=.12;bs.inputs['Transmission Weight'].default_value=.95;bs.inputs['IOR'].default_value=1.45;bs.inputs['Specular IOR Level'].default_value=.25;mat.surface_render_method='DITHERED';materials['glass']=mat
  # Real FMPL cedar shader; bake its color/normal to the existing authored plank UVs.
  surf=module(R/'tools/fmpl/surfaces/build_library.py','cargo_wood');cat=json.loads((R/'tools/fmpl/surfaces/catalog.json').read_text());cedar=next(r for r in cat['presets'] if r['id']=='cedar-rough');wood=surf.shader_material(bpy,cedar,cat['version'])
  bpy.ops.mesh.primitive_plane_add(size=2,location=(0,0,20));plane=bpy.context.object;plane.data.materials.append(wood);bpy.context.view_layer.objects.active=plane
  wood_maps={}
  for kind,typ in [('albedo','DIFFUSE'),('normal','NORMAL')]:
   image=bpy.data.images.new(key+' | baked FMPL cedar '+kind,width=1024,height=1024);image.colorspace_settings.name='sRGB' if kind=='albedo' else 'Non-Color';node=wood.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;wood.node_tree.nodes.active=node;s.render.bake.use_pass_direct=False;s.render.bake.use_pass_indirect=False;s.render.bake.use_pass_color=True;bpy.ops.object.bake(type=typ);image.filepath_raw=str(P/('cedar-'+kind+'.png'));image.file_format='PNG';image.save();image.pack();wood_maps[kind]=image
  bpy.data.objects.remove(plane,do_unlink=True);mat=bpy.data.materials.new('Cargo study | packed directional FMPL cedar');mat.use_nodes=True;nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=cedar['roughness']
  for kind,im in wood_maps.items():
   n=nt.nodes.new('ShaderNodeTexImage');n.image=im
   if kind=='albedo':nt.links.new(n.outputs['Color'],bs.inputs['Base Color'])
   else:
    normal=nt.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.30;nt.links.new(n.outputs['Color'],normal.inputs['Color']);nt.links.new(normal.outputs[0],bs.inputs['Normal'])
  materials['timber']=mat
  for ob in s.objects:
   if ob.type!='MESH' or ob.get('fmpl_render_only') or ob.name.startswith('Cache centered emblem |'):continue
   old=ob.data.materials[0].name;role=old.split('Basic Cargo | ')[-1]
   if role not in materials:continue
   use='structure' if role=='deck-steel' and any(t in ob.name for t in ('truss','hoop','locking housing')) else role;ob.data.materials.clear();ob.data.materials.append(materials[use])
   # Canonical metal scale, preserving topology, transforms and receiving frames.
   for uv in ob.data.uv_layers.active.data:uv.uv=(uv.uv-Vector((.5,.5)))*(1.25/.65)+Vector((.5,.5))
   if role=='timber':
    # Grain runs along each plank/handle's long axis, not across its width.
    dims=ob.dimensions;axis=max(range(3),key=lambda k:dims[k]);other=1 if axis==0 else 0
    for poly in ob.data.polygons:
     for li in poly.loop_indices:
      v=ob.data.vertices[ob.data.loops[li].vertex_index].co;ob.data.uv_layers.active.data[li].uv=(v[axis]/2+.5,v[other]/2+.5)
 assert before==geometry(),'Material study changed geometry or attachment frames'
 bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(P/'study.blend'),compress=True);render(s,P/'source-front.png');root.rotation_euler.z=-math.pi/2;render(s,P/'source-east.png');root.rotation_euler.z=0
 bpy.ops.object.select_all(action='DESELECT')
 for ob in s.objects:
  if ob.type=='MESH' and not ob.get('fmpl_render_only'):ob.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(P/'study.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_lights=False,export_cameras=False,export_extras=True)
 # Render actual GLB in the same measured rig, reconstructing only grade mask.
 for ob in list(s.objects):
  if ob.type in ('MESH','EMPTY'):bpy.data.objects.remove(ob,do_unlink=True)
 bpy.ops.import_scene.gltf(filepath=str(P/'study.glb'));add_grade_holdouts(s,bpy,manifest);render(s,P/'export-front.png')
 packed=all(im.packed_file for im in bpy.data.images if im.users and im.type=='IMAGE');row=dict(key=key,geometry_and_frames_unchanged=True,source_sha256=h(P/'study.blend'),export_sha256=h(P/'study.glb'),render_sha256={p.name:h(p) for p in P.glob('*.png')},scope='Material/environment study only; source and production sprites untouched. All studies use exact Boiler V08 workshop light transforms/powers/world and Standard color transform.',uv='Canonical1.25 repeat/tile metal; cedar grain along physical plank/handle length' if key!='a-current-workshop' else 'Baseline UVs unchanged',references=dict(fmpl_catalog_sha256=h(R/'art/source-to-3d/shared-parts/industrial-asset-library/catalog.json'),environment_source_sha256=h(R/env['source'])),packed_images=packed);(P/'study.json').write_text(json.dumps(row,indent=2));rows.append(row)
(D/'studies.json').write_text(json.dumps(dict(rows=rows,production_unchanged=h(src),environment=env,owner_approval='Pending study review; no material candidate promoted'),indent=2));print('CARGO_MATERIAL_STUDIES_SAVED')
