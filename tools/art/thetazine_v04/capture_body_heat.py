"""Separate nonheated body and actual heat-only material renders, same poses/camera.

The glow includes the bell-occluded interior combustion flame, as requested.
External exhaust remains native engine FX. Nonemitting geometry is a black
occluder; fuel-window luminescence is excluded from this light-only pass.
"""
import bpy,pathlib,sys,hashlib,json,os
r=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();source=r/'thetazine-v04-regenerative-study.blend';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.render.engine='BLENDER_EEVEE'
if hasattr(s.eevee,'taa_render_samples'):s.eevee.taa_render_samples=24
s.render.resolution_percentage=100;s.render.film_transparent=True;dest=r/'separated-body-heat';dest.mkdir(exist_ok=True);receipt=r/'separated-body-heat-capture.json'
state={'status':'CAPTURING','pid':os.getpid(),'native_sha256':sha(source),'renderer_sha256':sha(pathlib.Path(__file__)),'renderer':'Blender5.0.1 Eevee','target_pngs':132,'working_frames':64,'cell':[512,1280],'frame_contract':'cold0, working1..64, wrap65,30fps','passes':{'body':'Original PBR materials with both bell heat emission strengths forced to0; exhaust and underlay excluded.','heat-glow':'Actual authored bell emission maps and pose-specific source strengths on emission-only shaders; all other surfaces black occluders, no FX/fuel emission. Black nonemitting regions, body-coverage alpha; intended additive light layer.'},'files':[]}
if receipt.exists():
 old=json.loads(receipt.read_text(encoding='utf-8'));assert old['native_sha256']==state['native_sha256'] and old['renderer_sha256']==state['renderer_sha256'];state['files']=old['files']
def checkpoint():receipt.write_text(json.dumps(state,indent=2)+'\n',encoding='utf-8',newline='\n')
black=bpy.data.materials.new('HEAT_PASS black geometric occluder');black.use_nodes=True;nt=black.node_tree;nt.nodes.clear();out=nt.nodes.new('ShaderNodeOutputMaterial');em=nt.nodes.new('ShaderNodeEmission');em.inputs['Color'].default_value=(0,0,0,1);nt.links.new(em.outputs[0],out.inputs['Surface'])
thermal={};body_thermal={};strength_nodes={}
for m in list(bpy.data.materials):
 if m.name not in ['V04 axial temper and charred bell petals','V04 charred inner refractory heat','V04 interior combustion light map']:continue
 bm=m.copy();assert bm.node_tree!=m.node_tree;bm.name='BODY_PASS no heat '+m.name;bm.animation_data_clear();bm.node_tree.animation_data_clear();bm.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=0;body_thermal[m.name]=bm
 gm=m.copy();gm.name='HEAT_PASS '+m.name;gm.animation_data_clear();gm.node_tree.animation_data_clear();nt=gm.node_tree;out=nt.nodes.get('Material Output');source_bs=nt.nodes.get('Principled BSDF');em=nt.nodes.new('ShaderNodeEmission');color_link=next((l.from_socket for l in nt.links if l.to_socket==source_bs.inputs['Emission Color']),None)
 if color_link:nt.links.new(color_link,em.inputs['Color'])
 else:em.inputs['Color'].default_value=source_bs.inputs['Emission Color'].default_value
 nt.links.new(em.outputs[0],out.inputs['Surface']);thermal[m.name]=gm;strength_nodes[m.name]=em
 if m.name=='V04 interior combustion light map':
  gm.surface_render_method='BLENDED';tr=nt.nodes.new('ShaderNodeBsdfTransparent');mix=nt.nodes.new('ShaderNodeMixShader');alpha_link=next(l.from_socket for l in nt.links if l.to_socket==source_bs.inputs['Alpha']);nt.links.new(alpha_link,mix.inputs[0]);nt.links.new(tr.outputs[0],mix.inputs[1]);nt.links.new(em.outputs[0],mix.inputs[2]);nt.links.new(mix.outputs[0],out.inputs['Surface'])
assert len(thermal)==(2 if any(o.get('render_only_volume') for o in s.objects) else 3)
original={}
for o in s.objects:
 if o.type!='MESH':continue
 o.hide_render=o.get('render_component') in ['exhaust','underlay'] or o.name.startswith('Underlay');original[o.name]=list(o.data.materials)
checkpoint()
for frame in range(66):
 s.frame_set(frame);values={name:bpy.data.materials[name].node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value for name in thermal}
 for kind in ['body','heat-glow']:
  path=dest/f'{frame:02}-{kind}.png';prior=next((x for x in state['files'] if x['frame']==frame and x['pass']==kind),None)
  if prior:assert sha(path)==prior['sha256'];continue
  for o in s.objects:
   if o.type!='MESH':continue
   if o.get('light_map_only'):o.hide_render=kind=='body' or frame==0
   if o.get('render_only_volume'):continue
   for i,m in enumerate(original[o.name]):o.data.materials[i]=body_thermal.get(m.name,m) if kind=='body' else thermal.get(m.name,black)
  if kind=='body':
   for name in thermal:assert body_thermal[name].node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value==0 and not body_thermal[name].node_tree.animation_data
  else:
   for name in thermal:strength_nodes[name].inputs['Strength'].default_value=values[name]
   if 'V04 interior combustion light map' in thermal:thermal['V04 interior combustion light map'].node_tree.nodes.get('Mapping').inputs['Location'].default_value=bpy.data.materials['V04 interior combustion light map'].node_tree.nodes.get('Mapping').inputs['Location'].default_value
  s.render.filepath=str(path);bpy.ops.render.render(write_still=True);state['files'].append({'frame':frame,'pass':kind,'file':'separated-body-heat/'+path.name,'sha256':sha(path),'source_heat_strengths':values,'body_thermal_materials_unanimated':True});checkpoint();print('V04_LAYER_CAPTURE',frame,kind,flush=True)
 # Restore animated source slots and values before the next source frame.
 for o in s.objects:
  if o.type=='MESH':
   for i,m in enumerate(original[o.name]):o.data.materials[i]=m
 for name in thermal:bpy.data.materials[name].node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=values[name]
state['status']='COMPLETE_132_LAYER_PNGS_REQUIRES_PACKAGING_REVIEW';checkpoint();print('V04_BODY_HEAT_COMPLETE',len(state['files']))
