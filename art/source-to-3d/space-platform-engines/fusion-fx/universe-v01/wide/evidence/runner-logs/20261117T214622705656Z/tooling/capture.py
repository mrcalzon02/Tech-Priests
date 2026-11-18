"""Pinned-GLB fixed-north fusion capture derivative; run with Blender --python.

No source model, fixture, GLB, shared FMPL module or prototype is modified.
"""
import argparse, hashlib, json, math, pathlib, struct, sys
import bpy
import numpy as np
from mathutils import Vector

HERE=pathlib.Path(__file__).resolve().parent
REPO=HERE.parents[3]
sys.path.insert(0,str(HERE))
from particle_plume import build_particle_plume, set_particle_plume_phase
from electric_arcs import build_electric_arcs, set_electric_arcs_phase
from emitter_energy import build_emitter_energy
sys.path.insert(0,str(REPO/'tools/fmpl'))
from blender_camera_guard import install_canonical_camera, assert_clean, camera_record

def sha(path):return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()
def dump(path,data):pathlib.Path(path).write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
def glb_json(path):
 raw=pathlib.Path(path).read_bytes();assert raw[:4]==b'glTF';n=struct.unpack_from('<I',raw,12)[0];return json.loads(raw[20:20+n])
def pinned(path,expected):
 p=pathlib.Path(path).resolve();assert p.is_file() and sha(p)==expected,('Pinned input mismatch',str(p));return p
def bound_validation(item,glb_sha):
 p=pinned(item['path'],item['sha256']);j=json.loads(p.read_text());assert str(j.get('status','')).startswith('PASS'),('Validation did not pass',p)
 assert glb_sha in json.dumps(j),('Validation is not bound to this GLB',p)
 return p
def mesh_digest(objects):
 h=hashlib.sha256()
 for o in sorted(objects,key=lambda v:v.name):
  h.update(o.name.encode());h.update(np.asarray(o.matrix_world,dtype='<f8').tobytes())
  v=np.empty(len(o.data.vertices)*3,dtype='<f4');o.data.vertices.foreach_get('co',v);h.update(v.tobytes())
  o.data.calc_loop_triangles();t=np.asarray([p.vertices[:]for p in o.data.loop_triangles],dtype='<i4');h.update(t.tobytes())
 return h.hexdigest()
def black(name):
 m=bpy.data.materials.new(name);m.use_fake_user=True;m.use_nodes=True;n=m.node_tree.nodes;n.clear();e=n.new('ShaderNodeEmission');e.inputs['Color'].default_value=(0,0,0,1);out=n.new('ShaderNodeOutputMaterial');m.node_tree.links.new(e.outputs[0],out.inputs['Surface']);return m
def holdout():
 m=bpy.data.materials.new('CAPTURE_RECIPROCAL_HOLDOUT');m.use_fake_user=True;m.use_nodes=True;nt=m.node_tree;nt.nodes.clear();h=nt.nodes.new('ShaderNodeHoldout');out=nt.nodes.new('ShaderNodeOutputMaterial');nt.links.new(h.outputs[0],out.inputs['Surface']);return m
def make_emission(original,name):
 m=original.copy();m.name=name;m.use_fake_user=True;nt=m.node_tree;bs=next((n for n in nt.nodes if n.type=='BSDF_PRINCIPLED'),None);assert bs is not None,('Unsupported emissive material',original.name)
 strength=float(bs.inputs['Emission Strength'].default_value);color=bs.inputs['Emission Color'];out=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL');e=nt.nodes.new('ShaderNodeEmission');e.name='CAPTURE_STROBE'
 if color.is_linked:nt.links.new(color.links[0].from_socket,e.inputs['Color'])
 else:e.inputs['Color'].default_value=color.default_value
 for link in list(out.inputs['Surface'].links):nt.links.remove(link)
 nt.links.new(e.outputs[0],out.inputs['Surface']);e.inputs['Strength'].default_value=strength
 return m,{'material':m.name,'original':original.name,'base_strength':strength,'constant_strength':strength,'key_frames':[],'key_strengths':[strength,strength],'brightness_owner':'Native actual electrical draw factor/1.5; no independently baked global sine.'}
def cold_material(original):
 m=original.copy();m.name='CAPTURE_COLD | '+original.name
 for n in m.node_tree.nodes:
  if n.type=='BSDF_PRINCIPLED':
   for link in list(n.inputs['Emission Strength'].links):m.node_tree.links.remove(link)
   n.inputs['Emission Strength'].default_value=0
 return m
def clip(poly,normal,offset):
 out=[]
 for a,b in zip(poly,poly[1:]+poly[:1]):
  da=normal.dot(a)-offset;db=normal.dot(b)-offset;ain=da>=-1e-10;bin=db>=-1e-10
  if ain:out.append(a)
  if ain!=bin:out.append(a+(b-a)*(da/(da-db)))
 return out
def receiver_clip(poly,receiver):
 # Convex receiver polygons are CCW in source XY; clip independently to union.
 result=[]
 for ring in receiver:
  cut=poly
  for a,b in zip(ring,ring[1:]+ring[:1]):
   n=Vector((-(b[1]-a[1]),b[0]-a[0],0));cut=clip(cut,n,n.x*a[0]+n.y*a[1]) if cut else []
  if len(cut)>=3:result.append(cut)
 return result
def projected_shadow(objects,cfg):
 direction=Vector((4,6,-8));vertices=[];faces=[];clipped=0
 receiver=cfg.get('deck_receiver_polygons')
 for o in objects:
  o.data.calc_loop_triangles();world=[o.matrix_world@v.co for v in o.data.vertices]
  for tri in o.data.loop_triangles:
   poly=clip([world[i]for i in tri.vertices],Vector((0,0,1)),0)
   if len(poly)<3:continue
   projected=[v+direction*(-v.z/direction.z)for v in poly]
   regions=receiver_clip(projected,receiver)if receiver else [clip(projected,Vector((0,1,0)),0)]
   for pts in regions:
    if len(pts)<3:continue
    area=sum(a.x*b.y-b.x*a.y for a,b in zip(pts,pts[1:]+pts[:1]))
    if abs(area)<1e-10:continue
    start=len(vertices);vertices.extend(pts);faces.append(list(range(start,start+len(pts))));clipped+=1
 me=bpy.data.meshes.new('CAPTURE_PROJECTED_DECK_SHADOW');me.from_pydata(vertices,[],faces);me.update();o=bpy.data.objects.new(me.name,me);bpy.context.scene.collection.objects.link(o);o.data.materials.append(black('CAPTURE_PROJECTED_BLACK'));o.hide_render=True
 assert len(faces)>0,'No actual triangles project onto the declared deck receiver'
 return o,{'triangles_clipped_and_projected':clipped,'light_travel_direction':[4,6,-8],'deck_plane_z':0,'receiver_polygons':receiver,'receiver_status':'SOURCE_SPECIFIC'if receiver else'PILOT_FORE_HALFPLANE_ONLY'}
def make_effects(cfg,body):
 violent=cfg.get('effects_style')=='TORTURED_UNIVERSE_V1'
 ap=cfg['aperture'];plume=build_particle_plume(family=cfg['prototype'],origin=ap.get('effect_origin',ap['center']),axis=ap['axis'],aperture_radius=ap['radius'],seed=731,length=cfg.get('field_length',2.0),particles=cfg.get('particle_count',24),wisps=cfg.get('wisp_count',12),violent=violent)
 arcs=build_electric_arcs(body,family=cfg['prototype'],seed=6143,samples=64,strength=.24,violent=violent)
 for name in arcs['materials']:
  bpy.data.materials[name].node_tree.nodes['ELECTRIC_ARC_NORMALIZED_RADIANCE'].inputs['Strength'].default_value=cfg.get('arc_capture_strength',8)
 arcs['capture_exposure_compensation']=cfg.get('arc_capture_strength',8)
 return plume,arcs
def source_world_points(objects):return [o.matrix_world@Vector(c)for o in objects for c in o.bound_box]
def project(point,scene):
 from bpy_extras.object_utils import world_to_camera_view
 p=world_to_camera_view(scene,scene.camera,Vector(point));s=scene.render.resolution_x;return [p.x*s,(1-p.y)*s]

p=argparse.ArgumentParser(description=__doc__);p.add_argument('mode',choices=['prepare','capture']);p.add_argument('--profile',type=pathlib.Path,required=True);p.add_argument('--out',type=pathlib.Path,required=True);p.add_argument('--frames',default='all');p.add_argument('--layers',default='cold_body,cold_light,shadow,underlay,working_light,field');a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);cfg=json.loads(a.profile.read_text());R=a.out.resolve();R.mkdir(parents=True,exist_ok=True)
assert cfg['prototype']in('void-fusion-thruster','large-void-fusion-thruster');assert cfg['stage']in('PILOT_TOOLING','FINAL_CAPTURE_CANDIDATE');assert cfg['output_frames']in(16,64)
glb=pinned(cfg['glb'],cfg['glb_sha256']);validation=bound_validation(cfg['validation'],cfg['glb_sha256']);gj=glb_json(glb);assert not gj.get('animations'),'Rigid body lane refuses an animated physical GLB'
if cfg['stage']=='FINAL_CAPTURE_CANDIDATE':
 assert cfg.get('deck_receiver_polygons'),'Final deck shadow requires actual receiver polygons'
 assert cfg.get('underlay'),'Final service-underlay handoff is missing'
assert cfg['native_cut_y']==(.5 if cfg['prototype']=='void-fusion-thruster'else 1)
for name in ('underlay',):
 if cfg.get(name):
  pinned(cfg[name]['glb'],cfg[name]['sha256'])
  if cfg[name].get('validation'):bound_validation(cfg[name]['validation'],cfg['glb_sha256'])
if cfg.get('aperture'):
 bound_validation(cfg['aperture']['validation'],cfg['glb_sha256'])
 assert len(cfg['aperture']['center'])==len(cfg['aperture']['axis'])==3 and cfg['aperture']['radius']>0
 assert all(math.isfinite(v)for v in cfg['aperture']['center']+cfg['aperture']['axis'])and Vector(cfg['aperture']['axis']).length>.99
for ring in cfg.get('deck_receiver_polygons',[]):
 assert len(ring)>=3 and all(len(v)==2 and all(math.isfinite(x)for x in v)and v[1]>=0 for v in ring)
 assert sum(x[0]*y[1]-y[0]*x[1]for x,y in zip(ring,ring[1:]+ring[:1]))>0,'Receiver polygons must be convex and counterclockwise'
binding={'profile_sha256':sha(a.profile),'glb_sha256':sha(glb),'validation_sha256':sha(validation),'scripts':{str(x.relative_to(REPO)):sha(x)for x in [pathlib.Path(__file__),HERE/'particle_plume.py',HERE/'electric_arcs.py',HERE/'emitter_energy.py',REPO/'tools/fmpl/blender_camera_guard.py',REPO/'tools/fmpl/capture_policy.py']}}
receipt=R/'capture-receipt.json';master=R/'capture-master.blend'
if a.mode=='prepare':
 if receipt.exists():
  old=json.loads(receipt.read_text());assert old['binding']==binding and sha(master)==old['master_sha256'];print('REUSED_MATCHING_CAPTURE_MASTER');raise SystemExit()
 assert not master.exists(),'Refusing unbound existing capture master'
 bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;bpy.ops.import_scene.gltf(filepath=str(glb));physical=[o for o in s.objects if o.type=='MESH'];original_digest=mesh_digest(physical)
 excluded=set(cfg.get('body_exclude',[]));assert excluded.issubset({o.name for o in physical}),('Unknown underlay exclusions',excluded-{o.name for o in physical})
 body=[o for o in physical if o.name not in excluded];underlay=[]
 if cfg.get('underlay'):
  uj=glb_json(cfg['underlay']['glb']);same={n.get('name')for n in uj['nodes']if'mesh'in n}&{o.name for o in physical};assert same.issubset(excluded),('Underlay repeats visible body parts without explicit exclusions',same-excluded)
  before=set(s.objects);bpy.ops.import_scene.gltf(filepath=str(pathlib.Path(cfg['underlay']['glb']).resolve()));underlay=[o for o in s.objects if o not in before and o.type=='MESH']
  assert underlay
  for o in underlay:assert 'foundation slab'not in o.name.lower(),'Whole foundation art is not a service underlay'
  for o in underlay:o.name='CAPTURE_SERVICE | '+o.name
 emit_names={m['name']for m in gj['materials']if any(m.get('emissiveFactor',[0,0,0]))or m.get('emissiveTexture')};cold_cache={};slots=[];groups=[];matte=black('CAPTURE_OPAQUE_BLACK_OCCLUDER');holdout()
 for o in body+underlay:
  o.data=o.data.copy();row={'object':o.name,'cold':[],'light':[]}
  for i,original in enumerate(list(o.data.materials)):
   if original.name not in cold_cache:cold_cache[original.name]=cold_material(original)
   cold=cold_cache[original.name];row['cold'].append(cold.name)
   if original.name in emit_names and o in body:
    light,record=make_emission(original,'CAPTURE_GLOW | '+o.name+' | '+str(i));groups.append(record)
   else:light=matte
   row['light'].append(light.name);o.data.materials[i]=cold
  slots.append(row)
 for o in physical:
  if o.name in excluded:o.hide_render=True
 rim_materials,rim_proof=build_emitter_energy(body,family=cfg['prototype'],axis=cfg['aperture']['axis'])if cfg.get('aperture')else({},{'status':'NO_APERTURE_HANDOFF'})
 for row in slots:
  if row['object']in rim_materials:row['light']=[rim_materials[row['object']]]*len(row['cold'])
 assert groups,'GLB has no actual emissive material slots'
 shadow,shadow_info=projected_shadow(body+underlay,cfg)
 aperture_measurement=None
 if cfg.get('aperture'):
  from mathutils.bvhtree import BVHTree
  ap=cfg['aperture'];obj=next((o for o in body if o.name==ap['mesh']),None);assert obj is not None,('Measured aperture mesh is not in actual imported body',ap['mesh'])
  obj.data.calc_loop_triangles();tree=BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[t.vertices[:]for t in obj.data.loop_triangles],all_triangles=True);near=tree.find_nearest(Vector(ap['center']));assert near[0]is not None and near[3]<=ap['radius']*2+.02,('Aperture datum does not reach its named actual surface',near[3])
  aperture_measurement={'mesh':obj.name,'source_center':ap['center'],'nearest_actual_surface':list(near[0]),'surface_distance':near[3],'declared_inner_radius':ap['radius'],'effect_origin':ap.get('effect_origin',ap['center']),'meaning':'Physical aperture plane and separate downstream FX origin remain distinct; exact aperture geometry measurement belongs to pinned source handoff.'}
 plume,arcs=make_effects(cfg,body)if cfg.get('aperture')else(None,None)
 field=[bpy.data.objects[v['object']]for v in plume['objects']]if plume else[]
 arc_objects=[bpy.data.objects[n]for n in arcs['objects']]if arcs else[]
 for o in field+arc_objects:o.hide_render=True
 bpy.context.view_layer.update();points=source_world_points(body+underlay+[shadow])
 if field:
  first=set_particle_plume_phase(plume,0);wrap=set_particle_plume_phase(plume,1);assert first==wrap,'Advecting plume lifecycle wrap differs'
  for f in range(cfg['output_frames']):
   set_particle_plume_phase(plume,f/cfg['output_frames']);set_electric_arcs_phase(arcs,f/cfg['output_frames']);bpy.context.view_layer.update();points.extend(source_world_points(field+arc_objects))
  set_particle_plume_phase(plume,0);set_electric_arcs_phase(arcs,0)
  for o in field+arc_objects:o.hide_render=True
 bounds=[[min(v[i]for v in points)for i in range(3)],[max(v[i]for v in points)for i in range(3)]];target=[(bounds[0][i]+bounds[1][i])/2 for i in range(3)]
 extent=max(max(abs(v.x-target[0]),abs(((v.y-target[1])+(v.z-target[2]))/math.sqrt(2)))for v in points);ortho=max(cfg.get('minimum_ortho_scale',8),extent*2*1.12)
 profile={'camera_policy':'fmpl.factorio45.v1','capture_kind':'entity','orientation_policy':'fixed','directions':[0],'states':{'idle':[1],'working':list(range(cfg['output_frames']))},'source_size':cfg['source_size'],'camera_override':{'type':'ORTHO','elevation_deg':45,'azimuth_deg':0,'distance':20,'ortho_scale':ortho,'target':target,'shift_x':0,'shift_y':0}}
 if cfg.get('camera_lock'):
  profile=cfg['camera_lock'];assert profile['source_size']==cfg['source_size'],'Locked camera/source cell mismatch'
  ortho=profile['camera_override']['ortho_scale'];target=profile['camera_override']['target']
 camera_cleanup=install_canonical_camera(s,profile,bpy)
 s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=cfg.get('samples',16);s.cycles.use_denoising=False;s.render.threads_mode='FIXED';s.render.threads=cfg.get('render_threads',2);s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.use_compositing=False;s.render.fps=48;s.frame_start=1;s.frame_end=97;s.view_settings.view_transform='Standard';s.view_settings.look='None';s.render.dither_intensity=0
 world=bpy.data.worlds.new('CAPTURE_WORLD');s.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.14,.17,1);world.node_tree.nodes['Background'].inputs[1].default_value=.25
 for name,loc,power,size in [('key',(-4,-2,7),1300,5),('fill',(4,2,5),700,4),('rim',(0,5,5),800,3)]:
  d=bpy.data.lights.new('CAPTURE_'+name,'AREA');d.energy=power;d.size=size;o=bpy.data.objects.new(d.name,d);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
 for o in underlay:o.hide_render=True
 s.frame_set(1);bpy.context.view_layer.update();assert_clean(s,profile,bpy);deck_px=project((0,0,0),s);size=cfg['source_size'];scale=cfg.get('native_pixels_per_source_unit',32)*ortho/size;shift=[-(deck_px[0]-size/2)*scale/32,cfg['native_cut_y']-(deck_px[1]-size/2)*scale/32]
 aperture=cfg.get('aperture');ap_px=project(aperture['center'],s)if aperture else None
 fx_source=aperture.get('effect_origin',aperture['center'])if aperture else None;fx_px=project(fx_source,s)if fx_source else None
 registration={'cell':[size,size],'native_pixels_per_source_unit':cfg.get('native_pixels_per_source_unit',32),'scale':scale,'shift_tiles':shift,'source_deck_origin':[0,0,0],'source_deck_pixel':deck_px,'native_cut_y':cfg['native_cut_y'],'aperture_source':aperture['center']if aperture else None,'aperture_pixel':ap_px,'aperture_native_tiles':[shift[i]+(ap_px[i]-size/2)*scale/32 for i in range(2)]if aperture else None,'field_origin_source':fx_source,'field_origin_pixel':fx_px,'field_origin_native_tiles':[shift[i]+(fx_px[i]-size/2)*scale/32 for i in range(2)]if fx_px else None,'status':'CANDIDATE_REQUIRES_NATIVE_FIT'}
 assert mesh_digest(physical)==original_digest,'Capture preparation changed physical mesh geometry or transforms'
 bpy.ops.wm.save_as_mainfile(filepath=str(master),compress=True)
 state={'schema':'fusion_capture_v1','prototype':cfg['prototype'],'stage':cfg['stage'],'status':'PREPARED_CAPTURE_DERIVATIVE','binding':binding,'input_glb':{'path':str(glb),'sha256':sha(glb)},'master_sha256':sha(master),'camera':camera_record(s),'camera_profile':profile,'camera_cleanup':camera_cleanup,'registration':registration,'timeline':{'authored_keys':16,'source_frames':[1+6*i for i in range(17)],'source_fps':48,'duration_seconds':2,'output_frames':cfg['output_frames'],'output_source_frames':[1+96*i/cfg['output_frames']for i in range(cfg['output_frames'])],'wrap_source_frame':97,'native_animation_speed':cfg['output_frames']/2/60,'physical_glb_animations':0,'native_power_sync':False},'body': [o.name for o in body],'underlay':[o.name for o in underlay],'underlay_status':'SOURCE_SPECIFIC_IMPORTED'if underlay else'BLOCKED_SOURCE_SPECIFIC_SERVICE_UNDERLAY_NOT_DELIVERED','excluded_body_parts':sorted(excluded),'physical_objects':[o.name for o in physical],'physical_digest':original_digest,'slots':slots,'emission_groups':groups,'shadow':shadow.name,'shadow_proof':shadow_info,'field':[o.name for o in field],'field_status':'STYLIZED_FIELD_LINES_NOT_BACKGROUND_REFRACTION'if field else'BLOCKED_FINAL_APERTURE_MEASUREMENT_NOT_DELIVERED','aperture_measurement':aperture_measurement,'frames':[],'layers':{}}
 state['plume']=plume;state['arcs']=arcs;state['field_status']='ADVECTING_PARTICLES_AND_TURBULENT_WISPS_NO_BACKGROUND_REFRACTION'if plume else state['field_status']
 state['effects_style']=cfg.get('effects_style','ADVECTING_PARTICLES_AND_POWER_LINKED_CRACKLE')
 state['emitter_energy']=rim_proof
 state['timeline'].update({'authored_keys':0,'source_frames':None,'motion_model':'Deterministic seeded advecting lifecycles and fast surface crackles, sampled at64 phases; constant imported emissive base.','native_power_sync':'REQUIRES_ACTUAL_NATIVE_DRAW_VALIDATION'})
 state['brightness_contract']={'asset_normalization_power_watts':18000000,'native_multiplier':'L = actual record.operation.factor /1.5; unpowered L=0','native_premultiplied_color':'{r=L,g=L,b=L,a=L}','plume_gate':'Powered AND native entity working AND platform on_the_path AND not paused','global_baked_brightness_sine':False,'scope':'Runtime helper integration and native observations required before claiming synchronization.'}
 dump(receipt,state);dump(R/'profile.json',cfg);print('CAPTURE_MASTER_PREPARED',len(body),'body meshes',len(groups),'emissive groups')
else:
 state=json.loads(receipt.read_text());assert state['binding']==binding and sha(master)==state['master_sha256'];bpy.ops.wm.open_mainfile(filepath=str(master));s=bpy.context.scene;body=[bpy.data.objects[n]for n in state['body']];underlay=[bpy.data.objects[n]for n in state['underlay']];physical=[bpy.data.objects[n]for n in state['physical_objects']];shadow=bpy.data.objects[state['shadow']];field=[bpy.data.objects[n]for n in state['field']];lights=[o for o in s.objects if o.type=='LIGHT'];matte=bpy.data.materials['CAPTURE_OPAQUE_BLACK_OCCLUDER'];mask=bpy.data.materials['CAPTURE_RECIPROCAL_HOLDOUT'];layers=a.layers.split(',');indices=list(range(cfg['output_frames']))+[cfg['output_frames']]if a.frames=='all'else[int(x)for x in a.frames.split(',')]
 plume=state.get('plume');arcs=state.get('arcs');arc_objects=[bpy.data.objects[n]for n in arcs['objects']]if arcs else[]
 assert all(0<=i<=cfg['output_frames']for i in indices)
 for layer in layers:
  if layer=='underlay'and not underlay:continue
  if layer=='field'and not field:continue
  assert layer in('cold_body','cold_light','shadow','underlay','working_light','field')
  frames=indices if layer in('working_light','field')else[0]
  for index in frames:
   file=f'frames/{layer}/{index:03}.png';path=R/file;path.parent.mkdir(parents=True,exist_ok=True);old=next((f for f in state['frames']if f['layer']==layer and f['index']==index),None)
   if old:assert path.is_file()and sha(path)==old['sha256'];continue
   source_frame=1+96*index/cfg['output_frames'];s.frame_set(int(source_frame),subframe=source_frame%1)
   s.render.engine=cfg.get('field_engine','CYCLES')if layer=='field'else'CYCLES';eevee_settings={}
   if s.render.engine=='BLENDER_EEVEE':
    # All FX phases are explicit helper inputs. Keep renderer evaluation at
    # frame1 so stochastic temporal sampling cannot create a false loop seam.
    s.frame_set(1)
    for key,value in {'taa_render_samples':64,'volumetric_samples':128,'volumetric_tile_size':'2','volumetric_start':10.0,'volumetric_end':30.0,'volumetric_sample_distribution':0.0,'use_volumetric_shadows':False}.items():
     if hasattr(s.eevee,key):
      try:setattr(s.eevee,key,value);eevee_settings[key]=getattr(s.eevee,key)
      except(TypeError,ValueError):eevee_settings[key]='UNSUPPORTED_REQUEST'
   for o in body+underlay+field+arc_objects+[shadow]:o.hide_render=True
   for o in lights:o.hide_render=layer!='cold_body'and layer!='underlay'
   for row in state['slots']:
    o=bpy.data.objects[row['object']];names=row['cold']if layer in('cold_body','underlay')else row['light']if layer=='working_light'else[matte.name]*len(row['cold'])
    for i,name in enumerate(names):o.data.materials[i]=bpy.data.materials[name]
   if layer in('cold_body','cold_light','working_light','field'):
    for o in body:o.hide_render=False
    for o in underlay:
     o.hide_render=False
     for i in range(len(o.data.materials)):o.data.materials[i]=matte if layer=='field'else mask
   if layer=='underlay':
    for o in underlay:o.hide_render=False
    for o in body:
     o.hide_render=False
     for i in range(len(o.data.materials)):o.data.materials[i]=mask
   if layer=='shadow':shadow.hide_render=False
   plume_state=set_particle_plume_phase(plume,index/cfg['output_frames'])if plume else[]
   arc_state=set_electric_arcs_phase(arcs,index/cfg['output_frames'])if arcs else None
   if layer!='working_light':
    for o in arc_objects:o.hide_render=True
   if layer=='field':
    for o in field:o.hide_render=False
   s.world.node_tree.nodes['Background'].inputs[1].default_value=.25 if layer in('cold_body','underlay')else 0
   s.cycles.use_denoising=cfg.get('denoise_cold',True)and layer in('cold_body','underlay')
   # Preserve imported HDR emissive strength while avoiding an all-clipped
   # eight-bit green map. This is capture exposure, not a source material edit.
   s.view_settings.exposure=cfg.get('field_exposure',cfg.get('light_exposure',-3))if layer=='field'else cfg.get('light_exposure',-3)if layer=='working_light'else 0
   bpy.context.view_layer.update();assert_clean(s,state['camera_profile'],bpy);digest=mesh_digest(physical);assert digest==state['physical_digest'],'Physical body moved during a shader-only capture'
   s.cycles.seed=731;s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
   strengths={g['material']:bpy.data.materials[g['material']].node_tree.nodes['CAPTURE_STROBE'].inputs['Strength'].default_value for g in state['emission_groups']}
   state['frames'].append({'layer':layer,'index':index,'source_frame':source_frame,'scene_evaluation_frame':s.frame_current_final,'renderer':s.render.engine,'eevee_settings':eevee_settings,'file':file,'sha256':sha(path),'physical_digest':digest,'emission_strengths':strengths,'camera':camera_record(s),'arc_state':arc_state,'plume_state':plume_state if layer=='field'else None})
   state['status']='CAPTURING_SOURCE_CANDIDATE';dump(receipt,state);print('CAPTURED',layer,index,flush=True)
 state['status']='CAPTURED_REQUIRES_EXACT_IMAGE_PACKAGING_AND_NATIVE_FIT';dump(receipt,state)
assert sha(glb)==cfg['glb_sha256'],'Original GLB changed during capture'
