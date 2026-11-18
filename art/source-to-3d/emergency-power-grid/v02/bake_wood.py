import bpy,json,sys,hashlib,importlib.util
from pathlib import Path
A=Path(__file__).resolve().parent
REPO=next(c for p in[A,*A.parents]for c in(p,p/'model-production')if(c/'tools/fmpl/FMPL.json').is_file())
src=REPO/'tools/fmpl/surfaces/build_library.py';catalog=REPO/'tools/fmpl/surfaces/catalog.json';spec=importlib.util.spec_from_file_location('fmpl_surface_source',src);lib=importlib.util.module_from_spec(spec);spec.loader.exec_module(lib);d=json.loads(catalog.read_text());rec=next(r for r in d['presets']if r['id']=='cedar-rough');out=A/'textures';out.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=8;s.render.bake.margin=16
mat=lib.shader_material(bpy,rec,d['version']);nodes=mat.node_tree.nodes;links=mat.node_tree.links;bs=nodes['FMPL SURFACE | PBR'];output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL');mapping=nodes['FMPL | Object Mapping'];mapping.inputs['Scale'].default_value=(18,1.2,1.2)
# Plane UV.V is the finished timber's longitudinal coordinate, consistently
# reused on local-Z beams. All timber ends are hidden under real metal boots.
bpy.ops.mesh.primitive_plane_add(size=1);plane=bpy.context.object;plane.name='BAKE ONLY longitudinal cedar material';plane.data.materials.append(mat);bpy.context.view_layer.objects.active=plane
original_output=output.inputs['Surface'].links[0].from_socket
em=nodes.new('ShaderNodeEmission');images={};records={};sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for kind in('albedo','normal','orm'):
 im=bpy.data.images.new('POWER GRID original FMPL cedar '+kind,width=1024,height=1024,alpha=False,float_buffer=False);im.colorspace_settings.name='sRGB'if kind=='albedo'else'Non-Color';tex=nodes.new('ShaderNodeTexImage');tex.image=im;nodes.active=tex
 for link in list(output.inputs['Surface'].links):links.remove(link)
 if kind=='normal':links.new(original_output,output.inputs['Surface']);bpy.ops.object.bake(type='NORMAL')
 else:
  for link in list(em.inputs['Color'].links):links.remove(link)
  if kind=='albedo':links.new(bs.inputs['Base Color'].links[0].from_socket,em.inputs['Color'])
  else:
   combine=nodes.new('ShaderNodeCombineXYZ');combine.inputs['X'].default_value=1;combine.inputs['Z'].default_value=rec['metallic'];links.new(bs.inputs['Roughness'].links[0].from_socket,combine.inputs['Y']);links.new(combine.outputs[0],em.inputs['Color'])
  links.new(em.outputs[0],output.inputs['Surface']);bpy.ops.object.bake(type='EMIT')
 p=out/('grid-cedar-'+kind+'.png');im.filepath_raw=str(p);im.file_format='PNG';im.save();images[kind]=p.name;records[kind]={'file':'textures/'+p.name,'sha256':sha(p),'color_space':im.colorspace_settings.name}
 # A saved actual image, not a retained procedural bump, is the runtime map.
 nodes.remove(tex)
for link in list(output.inputs['Surface'].links):links.remove(link)
links.new(original_output,output.inputs['Surface']);mat.use_fake_user=True;mat['model_specific_grain']='Longitudinal UV.V, 1.8tile full length; endgrain covered by actual metal caps.'
bpy.ops.wm.save_as_mainfile(filepath=str(A/'cedar-bake-editable.blend'),compress=True)
manifest={'material_id':'power-grid-cedar-original-fmpl','source_preset':'cedar-rough','source_catalog':'tools/fmpl/surfaces/catalog.json','source_catalog_sha256':sha(catalog),'source_builder':'tools/fmpl/surfaces/build_library.py','source_builder_sha256':sha(src),'source_repository':'mrcalzon02/Tech-Priests','source_commit':'9c872855ee6b1c0f670ed542a7324605ecbff08e','model_specific_mapping_scale':[18,1.2,1.2],'grain_direction':'UV.V follows local longitudinalZ of every timber. 1.8tile full image height; metal boots cover end grain.','bake_resolution':[1024,1024],'actual_cycles_bake':True,'baked_maps':records,'orm_channels':'R=1 AO;G=baked native roughness;B=original preset metallic0','source_preset_owner_approval_not_claimed':True,'external_files_imported':0,'owner_visual_approved':False};(A/'cedar-bake-manifest.json').write_text(json.dumps(manifest,indent=2));print('POWER_GRID_FMPL_CEDAR_MAPS_BAKED',flush=True)
