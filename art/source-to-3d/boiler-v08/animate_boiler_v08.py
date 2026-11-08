"""Looping boiler operation, preserving the user's V07b meshes and nozzle."""
import bpy,math,json,hashlib,struct
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parent;D=R/'boiler_v08';D.mkdir(exist_ok=True)
SOURCE=R/'upload/tech_priests_emergency_boiler_v07b.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));s=bpy.context.scene
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
source=[o for o in s.objects if o.type=='MESH']
def sig(o):return hashlib.sha256(b''.join(struct.pack('3f',*v.co) for v in o.data.vertices)).hexdigest()
before={o.name:sig(o) for o in source};world={o.name:o.matrix_world.copy() for o in source}
s.frame_start=1;s.frame_end=96;s.render.fps=24;s.render.fps_base=1.0
for c in bpy.data.collections:
 if 'REFERENCE_ADJACENT' in c.name:c.hide_render=True
def phase(f):return (f-1)/96
emission=[]
for o in source:
 if o.hide_render:continue
 button=o.name.startswith('Console square button') and o.name.endswith('inset face')
 for index,old in enumerate(list(o.data.materials)):
  if not old or not old.use_nodes:continue
  candidates=[n for n in old.node_tree.nodes if n.type=='EMISSION' and n.inputs['Strength'].default_value>0 or n.type=='BSDF_PRINCIPLED' and n.inputs.get('Emission Strength') and n.inputs['Emission Strength'].default_value>0]
  if not candidates and not button:continue
  mat=old.copy();mat.name='V08 animated '+o.name;o.data.materials[index]=mat
  node=next((n for n in mat.node_tree.nodes if n.type=='EMISSION'),None)
  if node:socket=node.inputs['Strength']
  else:
   node=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');socket=node.inputs['Emission Strength']
   if socket.default_value<=0:
    node.inputs['Emission Color'].default_value=(.035,.039,.034,1) if 'button 0' in o.name else (.018,.020,.018,1)
  base=max(float(socket.default_value),.35 if button else .1);seed=len(emission)+1
  for f in range(1,98):
   t=phase(f)
   if button:value=base*(.30+1.65*(.5-.5*math.cos(math.tau*(3*t+seed*.14))))
   else:value=base*(1+.21*math.sin(math.tau*(17*t+seed*.21))+.12*math.sin(math.tau*(31*t+seed*.37))+.07*math.sin(math.tau*(7*t+seed*.11)))
   socket.default_value=max(.02,value);socket.keyframe_insert('default_value',frame=f)
  emission.append({'object':o.name,'material':mat.name,'mode':'pulse' if button else 'flicker','base_strength':base})
# Rattle three pressure/canister assemblies. Their fixed mounting feet stay put.
def choose(group):
 out=[]
 for o in source:
  n=o.name
  if n.endswith('.001'):continue
  if group=='central':match=(n.startswith(('Central head ','Central crown perimeter','V02 crown ','V02 central head ')) and not any(x in n for x in ['lower mounting foot','deck support pedestal','bottom vessel flange']))
  elif group=='right':match=n.startswith(('Right pressure ','Right crown rim ','Right chamber top ','V02 right cap ','V02 right chamber casing')) or n in ['Right sight chamber pressure body','Right sight chamber upper flange','Right sight chamber crown plate']
  else:match=n.startswith(('Front small horizontal','Small chamber ','V02 small chamber arched','V02 small chamber recessed','V02 small visor','V02 small chamber feed coupling'))
  if match:out.append(o)
 return out
rigs=[]
for i,(label,pivot,freq,amp) in enumerate([('central',(.038,.23,.49),13,.007),('right',(.44,.24,.45),17,.006),('small',(-.08,-.16,.43),19,.006)]):
 members=choose(label);rig=bpy.data.objects.new('V08 RATTLE '+label,None);s.collection.objects.link(rig);rig.location=pivot;rig.empty_display_type='PLAIN_AXES';rig.empty_display_size=.08
 bpy.context.view_layer.update()
 for o in members:
  mw=o.matrix_world.copy();o.parent=rig;o.matrix_parent_inverse=rig.matrix_world.inverted();o.matrix_world=mw
 for f in range(1,98):
  t=phase(f);rig.location=Vector(pivot)+Vector((amp*math.sin(math.tau*freq*t),amp*.35*math.sin(math.tau*(freq+4)*t),amp*.18*math.sin(math.tau*(freq*2)*t)))
  rig.rotation_euler=(.006*math.sin(math.tau*(freq-2)*t),.004*math.sin(math.tau*(freq+1)*t),.010*math.sin(math.tau*freq*t))
  rig.keyframe_insert('location',frame=f);rig.keyframe_insert('rotation_euler',frame=f)
 rigs.append({'rig':rig.name,'objects':[o.name for o in members],'translation_amplitude_tiles':amp,'frequency_hz':freq/4})
# The user's added rear nozzle is the outlet authority.
nozzle=bpy.data.objects['V02 crown recessed inner plate.001'];bb=[nozzle.matrix_world@Vector(v) for v in nozzle.bound_box]
exit=Vector(((min(v.x for v in bb)+max(v.x for v in bb))/2,(min(v.y for v in bb)+max(v.y for v in bb))/2,max(v.z for v in bb)+.002))
fx=bpy.data.collections.new('V08 ANIMATED STEAM');s.collection.children.link(fx)
def steam_material(i):
 m=bpy.data.materials.new('V08 steam volume %02d'%i);m.use_nodes=True;n=m.node_tree.nodes;n.clear();l=m.node_tree.links
 out=n.new('ShaderNodeOutputMaterial');volume=n.new('ShaderNodeVolumePrincipled');volume.inputs['Color'].default_value=(.88,.93,.96,1);volume.inputs['Anisotropy'].default_value=.12;l.new(volume.outputs['Volume'],out.inputs['Volume'])
 tex=n.new('ShaderNodeTexCoord');subtract=n.new('ShaderNodeVectorMath');subtract.operation='SUBTRACT';subtract.inputs[1].default_value=(.5,.5,.5);l.new(tex.outputs['Generated'],subtract.inputs[0])
 length=n.new('ShaderNodeVectorMath');length.operation='LENGTH';l.new(subtract.outputs['Vector'],length.inputs[0]);fall=n.new('ShaderNodeMapRange');fall.clamp=True;fall.inputs['From Min'].default_value=.12;fall.inputs['From Max'].default_value=.5;fall.inputs['To Min'].default_value=1;fall.inputs['To Max'].default_value=0;l.new(length.outputs['Value'],fall.inputs['Value'])
 noise=n.new('ShaderNodeTexNoise');noise.noise_dimensions='4D';noise.inputs['Scale'].default_value=5;noise.inputs['Detail'].default_value=2;noise.inputs['W'].default_value=i*1.731;l.new(tex.outputs['Generated'],noise.inputs['Vector'])
 mult=n.new('ShaderNodeMath');mult.operation='MULTIPLY';l.new(fall.outputs['Result'],mult.inputs[0]);l.new(noise.outputs['Fac'],mult.inputs[1])
 value=n.new('ShaderNodeValue');value.name='Animated steam density';density=n.new('ShaderNodeMath');density.operation='MULTIPLY';l.new(mult.outputs[0],density.inputs[0]);l.new(value.outputs[0],density.inputs[1]);l.new(density.outputs[0],volume.inputs['Density'])
 return m,value.outputs[0]
puffs=[]
births=list(range(8,30,3))+list(range(56,78,3))
for i,birth in enumerate(births):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1);o=bpy.context.object;o.name='V08 nozzle steam puff %02d'%i
 for c in list(o.users_collection):c.objects.unlink(o)
 fx.objects.link(o);mat,density=steam_material(i);o.data.materials.append(mat)
 for f in range(1,98):
  age=((f-1-birth)%96);active=age<30;u=age/30 if active else 0
  if active:
   o.location=exit+Vector((.035*u*math.sin(i*2.1+u*4),.025*u*math.cos(i*1.3+u*3),.025+.94*u));radius=.024+.135*u**.8;o.scale=(radius,radius,.065+.12*u)
   density.default_value=11*(1-u)**.75*min(1,u*8)
  else:o.location=exit;o.scale=(.001,.001,.001);density.default_value=0
  o.keyframe_insert('location',frame=f);o.keyframe_insert('scale',frame=f);density.keyframe_insert('default_value',frame=f)
 puffs.append({'object':o.name,'birth_frame':birth+1,'lifetime_frames':30})
cam=bpy.data.objects['BOILER_FACTORIO_EXPORT_45'];cam.location=(0,-6,6.85);cam.rotation_euler=(Vector((0,0,.85))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.35;s.camera=cam
for old_camera in list(bpy.data.objects):
 if old_camera.type=='CAMERA' and old_camera!=cam:bpy.data.objects.remove(old_camera,do_unlink=True)
for camera_data in list(bpy.data.cameras):
 if camera_data.users==0:bpy.data.cameras.remove(camera_data)
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type!='VIEW_3D':continue
  space=area.spaces.active;space.shading.use_scene_world=True;space.shading.use_scene_lights=True
  if hasattr(space.shading,'use_scene_world_render'):space.shading.use_scene_world_render=True
  if hasattr(space.shading,'use_scene_lights_render'):space.shading.use_scene_lights_render=True
  if screen.name in ['Layout','Animation','Shading']:space.shading.type='RENDERED';space.region_3d.view_perspective='CAMERA'
if bpy.context.window and bpy.data.workspaces.get('Layout'):bpy.context.window.workspace=bpy.data.workspaces['Layout']
s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=24;s.render.resolution_x=720;s.render.resolution_y=720;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.film_transparent=False
s.frame_set(1);bpy.context.view_layer.update()
assert all(sig(bpy.data.objects[n])==h for n,h in before.items())
max_rest_error=max(abs(bpy.data.objects[n].matrix_world[i][j]-mw[i][j]) for n,mw in world.items() for i in range(4) for j in range(4));assert max_rest_error<1e-5,max_rest_error
s['asset_revision']='V08 animation based on user V07b';s['animation_loop_seconds']=4.;s['steam_outlet_object']=nozzle.name;s['source_geometry_preserved']=True
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(D/'tech_priests_emergency_boiler_v08_animated.blend'),compress=True)
record={'revision':'V08','source':SOURCE.name,'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'source_mesh_count':len(source),'source_mesh_vertex_hashes':before,'source_mesh_geometry_preserved':True,'frame_1_world_transform_max_error':max_rest_error,'fps':24,'frame_range':[1,96],'loop_endpoint_keyframe':97,'loop_seconds':4,'emissive_animations':emission,'rattle_rigs':rigs,'steam_nozzle_object':nozzle.name,'steam_exit_world':list(exit),'steam_direction_world':[0,0,1],'steam_bursts_frames':[[9,30],[57,78]],'steam_puffs':puffs,'camera':'45-degree orthographic, fixed 3.35-tile canvas with steam headroom','runtime_integration':'Not performed; editable native animation and preview only'}
(D/'Boiler_V08_Animation_Record.json').write_text(json.dumps(record,indent=2))
print('V08_ANIMATION_SAVED',len(emission),len(rigs),len(puffs),max_rest_error,flush=True)
