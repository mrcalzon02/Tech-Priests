"""Animate approved V4 workbench. Blender -b --python animate_workbench.py -- [--render]."""
import bpy, math, pathlib, random, sys, json
from mathutils import Vector, Quaternion
R=pathlib.Path(__file__).resolve().parent
source=R/'rough_timber_workbench_v4.blend'
if not source.exists(): source=R.parent/'github_render/rough_timber_workbench_v4.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
sc=bpy.context.scene;sc.frame_start=1;sc.frame_end=192;sc.render.fps=24
hammer=[bpy.data.objects['Hammer wooden handle'],bpy.data.objects['Single forged hammer head']]
rig=bpy.data.objects.new('Hammer grip - animated swing',None);sc.collection.objects.link(rig);rig.location=(.29,-.16,.85)
bpy.context.view_layer.update()
for o in hammer:
 m=o.matrix_world.copy();o.parent=rig;o.matrix_world=m
def curves(action):
 if hasattr(action,'fcurves'): return action.fcurves
 return action.layers[0].strips[0].channelbag(action.slots[0]).fcurves
rest=rig.location.copy();axis=Vector((math.sin(math.radians(24)),math.cos(math.radians(24)),0))
rig.rotation_mode='QUATERNION'
def pose(frame,angle,working=True,lift=0):
 rig.location=rest+(Vector((.22,-.07,lift)) if working else Vector((0,0,lift)))
 rig.rotation_quaternion=Quaternion(axis,math.radians(angle));rig.keyframe_insert('location',frame=frame);rig.keyframe_insert('rotation_quaternion',frame=frame)
pose(1,0,False);pose(8,0,False);pose(18,25,True,.08);pose(25,64)
hits=[32,48,64,80,96,112]
for f in hits:
 pose(f-7,64);pose(f-2,28);pose(f,0);pose(f+2,13)
pose(122,48);pose(131,22,True,.13);pose(143,0,False);pose(192,0,False)
# Clamped interpolation prevents the head overshooting through the sheet.
for fc in curves(rig.animation_data.action):
 for kp in fc.keyframe_points:kp.interpolation='BEZIER';kp.handle_left_type='AUTO_CLAMPED';kp.handle_right_type='AUTO_CLAMPED'
# The same continuous metal sheet heats locally under the strike point.
sheet=next(o for o in bpy.data.objects if o.name.startswith('ONE continuous'))
mat=sheet.data.materials[0].copy();mat.name='Hammered sheet - animated central heat';sheet.data.materials[0]=mat
n=mat.node_tree.nodes;l=mat.node_tree.links;bs=n.get('Principled BSDF')
geo=n.new('ShaderNodeNewGeometry');flat=n.new('ShaderNodeVectorMath');flat.operation='MULTIPLY';flat.inputs[1].default_value=(1,1,0);l.new(geo.outputs['Position'],flat.inputs[0]);dist=n.new('ShaderNodeVectorMath');dist.operation='LENGTH';l.new(flat.outputs[0],dist.inputs[0]);fall=n.new('ShaderNodeMapRange');fall.clamp=True;fall.inputs['From Min'].default_value=.025;fall.inputs['From Max'].default_value=.38;fall.inputs['To Min'].default_value=1;fall.inputs['To Max'].default_value=0;l.new(dist.outputs['Value'],fall.inputs['Value'])
heat=n.new('ShaderNodeValue');heat.name='Heat build and cooling envelope';mul=n.new('ShaderNodeMath');mul.operation='MULTIPLY';l.new(fall.outputs['Result'],mul.inputs[0]);l.new(heat.outputs[0],mul.inputs[1]);l.new(mul.outputs[0],bs.inputs['Emission Strength']);bs.inputs['Emission Color'].default_value=(1,.065,.004,1)
# A warm tint persists as emission recedes, then returns exactly to the cold metal.
base=bs.inputs['Base Color'].links[0].from_socket;mix=n.new('ShaderNodeMixRGB');mix.blend_type='MIX';mix.inputs[2].default_value=(.32,.055,.014,1);l.new(base,mix.inputs[1]);tint=n.new('ShaderNodeMath');tint.operation='MULTIPLY';tint.inputs[1].default_value=.24;l.new(mul.outputs[0],tint.inputs[0]);l.new(tint.outputs[0],mix.inputs[0]);l.new(mix.outputs[0],bs.inputs['Base Color'])
for f,v in [(1,0),(31,0),(40,.12),(56,.3),(72,.55),(88,.85),(104,1.15),(120,1.4),(143,.9),(158,.4),(176,.1),(192,0)]:heat.outputs[0].default_value=v;heat.outputs[0].keyframe_insert('default_value',frame=f)
# Small emissive tapered shards follow baked ballistic arcs; no simulation cache needed.
random.seed(19)
sm=bpy.data.materials.new('Hot flying sparks');sm.use_nodes=True;sn=sm.node_tree.nodes;sn.clear();em=sn.new('ShaderNodeEmission');em.inputs[0].default_value=(1,.29,.025,1);em.inputs[1].default_value=7;out=sn.new('ShaderNodeOutputMaterial');sm.node_tree.links.new(em.outputs[0],out.inputs[0])
for strike in hits:
 for i in range(14):
  me=bpy.data.meshes.new('Tapered spark');me.from_pydata([(0,0,-.5),(.12,0,0),(0,.12,0),(-.12,0,0),(0,-.12,0),(0,0,.5)],[],[(0,1,2),(0,2,3),(0,3,4),(0,4,1),(5,2,1),(5,3,2),(5,4,3),(5,1,4)]);me.materials.append(sm)
  o=bpy.data.objects.new(f'Spark strike {strike} shard {i}',me);sc.collection.objects.link(o)
  angle=random.uniform(0,math.tau);speed=random.uniform(.6,1.3);vel=Vector((math.cos(angle)*speed,math.sin(angle)*speed,random.uniform(.6,1.6)));start=Vector((random.uniform(-.035,.035),random.uniform(-.035,.035),.807));life=random.randint(7,11)
  for f in [1,strike-1]:o.scale=(0,0,0);o.keyframe_insert('scale',frame=f)
  for age in range(life+1):
   f=strike+age;t=age/24;position=start+vel*t+Vector((0,0,-3*t*t));velocity=vel+Vector((0,0,-6*t));o.location=position;o.rotation_euler=velocity.to_track_quat('Z','Y').to_euler();fade=max(0,1-age/life);o.scale=(.018*fade,.018*fade,.065*fade) if position.z>.802 else (0,0,0)
   o.keyframe_insert('location',frame=f);o.keyframe_insert('rotation_euler',frame=f);o.keyframe_insert('scale',frame=f)
  o.scale=(0,0,0);o.keyframe_insert('scale',frame=192)
  for fc in curves(o.animation_data.action):
   for kp in fc.keyframe_points:kp.interpolation='LINEAR'
ld=bpy.data.lights.new('Impact flicker','POINT');lo=bpy.data.objects.new('Impact flicker',ld);sc.collection.objects.link(lo);lo.location=(0,0,.86);ld.color=(1,.23,.04);ld.shadow_soft_size=.08
for f in [1,192]:ld.energy=0;ld.keyframe_insert('energy',frame=f)
for f in hits:
 for offset,power in [(-1,0),(0,12),(2,0)]:ld.energy=power;ld.keyframe_insert('energy',frame=f+offset)
for fc in curves(ld.animation_data.action):
 for kp in fc.keyframe_points:kp.interpolation='LINEAR'
# Wider fixed frame accommodates the raised hammer and spark arcs.
cam=sc.camera;cam.data.ortho_scale=2.05;target=Vector((0,0,.63));ang=math.radians(-55);cam.location=(3*math.cos(ang),3*math.sin(ang),3.63);cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
sc.render.resolution_x=480;sc.render.resolution_y=480;sc.render.resolution_percentage=100
sc.render.engine='CYCLES';sc.cycles.samples=8;sc.cycles.use_denoising=False
# Compositor adds a restrained glow to the bright spark cores.
if bpy.app.version >= (5,0,0):
 tree=bpy.data.node_groups.new('Workbench restrained spark glow','CompositorNodeTree');sc.compositing_node_group=tree;tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor');output_type='NodeGroupOutput'
else:
 sc.use_nodes=True;tree=sc.node_tree;output_type='CompositorNodeComposite'
cn=tree.nodes;cn.clear();rl=cn.new('CompositorNodeRLayers');gl=cn.new('CompositorNodeGlare')
if hasattr(gl,'glare_type'): gl.glare_type='FOG_GLOW';gl.quality='MEDIUM'
else: gl.inputs['Type'].default_value='Fog Glow'
if hasattr(gl,'threshold'): gl.threshold=1.3
elif 'Threshold' in gl.inputs: gl.inputs['Threshold'].default_value=1.3
if hasattr(gl,'size'): gl.size=6
comp=cn.new(output_type);tree.links.new(rl.outputs['Image'],gl.inputs['Image']);tree.links.new(gl.outputs['Image'],comp.inputs['Image'])
# Verify impacts contact the sheet at its center, with a clean rest-to-rest loop.
for f in hits:
 sc.frame_set(f);center=hammer[1].matrix_world.translation;assert abs(center.x)<.001 and abs(center.y)<.001,(f,center);assert abs(center.z-.885)<.001
sc.frame_set(1);startmat=rig.matrix_world.copy();sc.frame_set(192);assert all(abs(startmat[i][j]-rig.matrix_world[i][j])<1e-6 for i in range(4) for j in range(4));assert heat.outputs[0].default_value==0
sc.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(R/'rough_timber_workbench_v5_animated.blend'))
(R/'animation_manifest.json').write_text(json.dumps({'fps':24,'frames':192,'seconds':8,'impact_frames':hits,'hammer_restored_frame':143,'fully_cold_frame':192,'preview_step':2,'description':'Pickup, six central hammer strikes with impact sparks and accumulating heat, lay down, cooling, seamless cold rest.'},indent=2))
if '--render' in sys.argv:
 (R/'frames').mkdir(exist_ok=True)
 for f in range(1,193,2):
  sc.frame_set(f);sc.render.filepath=str(R/'frames'/f'frame_{f:04d}.png');bpy.ops.render.render(write_still=True)
print('VERIFIED: six central strikes; one rigid hammer; rest pose and cold sheet restored at cycle end')
