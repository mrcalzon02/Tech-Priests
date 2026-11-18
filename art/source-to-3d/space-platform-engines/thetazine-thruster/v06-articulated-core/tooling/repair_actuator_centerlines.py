"""Seat four newly authored shaft meshes on the measured original collar axis."""
import bpy,json,hashlib,pathlib,math
from mathutils import Vector
R=pathlib.Path.cwd();S=R/'build/thruster-resume-20261117/thetazine-v06-motion'
inp=S/'core06-seated-rods';out=S/'core07-collar-aligned';out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
src=inp/'thetazine-v06-seated-rod-motion.blend';assert sha(src)=='f910918254d143c5452077e7f41e3a44359dfccb99a9c1dea5fbc459f2b4b901'
bpy.ops.wm.open_mainfile(filepath=str(src));s=bpy.context.scene;s.frame_set(0);bpy.context.view_layer.update()
A=Vector((0,-math.cos(math.radians(25)),-math.sin(math.radians(25))));delta=Vector((0,A.z,-A.y))*.05
names=[f'Outer actuator body {sign}'for sign in(-1,1)]+[f'V06 giant actuator sliding rod {sign}'for sign in(-1,1)]
for name in names:
    o=bpy.data.objects[name];o.data=o.data.copy()
    for v in o.data.vertices:v.co+=delta
    o.data.update();o['V06_measured_collar_axis_offset']=list(delta)
source=out/'thetazine-v06-collar-aligned-motion.blend';glb=out/'thetazine-v06-collar-aligned-motion.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
for o in s.objects:o.select_set(o.type=='MESH'and not o.get('render_only_volume'))
bpy.ops.export_scene.gltf(filepath=str(glb),use_selection=True,export_format='GLB',export_apply=True,
 export_current_frame=True,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,
 export_frame_range=True,export_force_sampling=True,export_morph=True,export_morph_animation=True,export_extras=True)
report={'status':'FOUR_AUTHORED_SHAFT_MESHES_ALIGNED_TO_ACTUAL_SOURCE_COLLARS_PENDING_INDEPENDENT_CHECK',
 'input':{'path':str(src),'sha256':sha(src)},'native':{'path':str(source),'sha256':sha(source)},'glb':{'path':str(glb),'sha256':sha(glb)},'changed_mesh_coordinates_only':names,
 'local_centerline_offset':list(delta),'script_sha256':sha(pathlib.Path(__file__)),
 'reason':'Independent source rays found actual original8collar axes offset+.05B from original shaft line. Align only four authored shaft surfaces to unchanged collar geometry/actions.'}
for name in('detail-manifest.json','side-actuator-motion.json'):
    j=json.loads((inp/name).read_text());j['native']=report['native'];j['glb']=report['glb'];j['bounded_collar_axis_repair']=report
    (out/name).write_text(json.dumps(j,indent=2),encoding='utf-8')
(out/'collar-axis-repair.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('COLLAR_AXIS_REPAIR_COMPLETE',json.dumps(report),flush=True)
