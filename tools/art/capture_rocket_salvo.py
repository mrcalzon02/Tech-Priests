"""Capture shot-independent launch tubes, the checked reload, and nose overlays.

Blender --python THIS -- SOURCE OUT [heading-list]
No fixed foundation or synthetic/native muzzle artwork is baked into the cap.
"""
import bpy,sys,json,math,hashlib,time
from pathlib import Path
args=sys.argv[sys.argv.index('--')+1:];source,out=map(Path,args[:2]);out.mkdir(parents=True,exist_ok=True)
directions=list(map(int,args[2].split(','))) if len(args)>2 else list(range(64))
identity={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
 'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'headings':64,'cell':256,
 'reload_frames':95,'source_reload_frames':[52,240],'nose_holdout_poses':[1,94,140,196,237],
 'scale':.774999976158,'shift':[0,-1.110906519093],'base_included':False}
if (out/'identity.json').exists():assert json.loads((out/'identity.json').read_text())==identity,'Capture inputs changed'
else:(out/'identity.json').write_text(json.dumps(identity,indent=2)+'\n')
bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;root=bpy.data.objects['TURRET_TRAVERSE']
root.animation_data_clear();root.rotation_euler=(0,0,0)
s.render.engine='CYCLES';s.cycles.samples=8;s.cycles.use_denoising=True
s.render.use_persistent_data=True;s.render.threads_mode='FIXED';s.render.threads=4
prefs=bpy.context.preferences.addons['cycles'].preferences
try:
    prefs.compute_device_type='OPTIX';prefs.get_devices()
    for device in prefs.devices:device.use=device.type=='OPTIX'
    if any(d.type=='OPTIX' for d in prefs.devices):s.cycles.device='GPU'
except Exception:s.cycles.device='CPU'
s.render.film_transparent=True;s.render.resolution_x=s.render.resolution_y=256;s.render.resolution_percentage=100
s.camera.data.ortho_scale=6.199999809265137;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
s.use_nodes=False;s.render.use_compositing=False;s.render.use_sequencer=False
rounds=[bpy.data.objects['LOADED_ROCKET_%d_%d'%(b,c)] for b,c in ((0,0),(1,0),(0,1),(1,1),(0,2),(1,2))]
def descendant(o,parent):
    while o.parent:
        if o.parent==parent:return True
        o=o.parent
    return False
meshes=[o for o in s.objects if o.type in ('MESH','CURVE')]
body=[o for o in meshes if not any(descendant(o,r) for r in rounds)]
hold=bpy.data.materials.new('ROCKET_CAPTURE_ONLY_DEPTH_HOLDOUT');hold.use_nodes=True
nodes=hold.node_tree.nodes;nodes.clear();h=nodes.new('ShaderNodeHoldout');o=nodes.new('ShaderNodeOutputMaterial');hold.node_tree.links.new(h.outputs[0],o.inputs['Surface'])
def pose(d,f,cell=None):
    s.frame_set(f);root.rotation_euler.z=math.pi-d*math.tau/64
    for i,r in enumerate(rounds):r.scale=(1,1,1) if i==cell else (0,0,0)
    bpy.context.view_layer.update()
def capture(path):
    if path.exists():return
    s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
start=time.monotonic()
for d in directions:
    pose(d,1);capture(out/f'd{d:02}-idle.png')
    for frame in range(95):
        pose(d,52+frame*2);capture(out/f'd{d:02}-reload-{frame:02}.png')
        if frame%20==0:print('ROCKET_BODY_PROGRESS',d,frame,round(time.monotonic()-start,1),flush=True)
    print('ROCKET_BODY_DIRECTION_DONE',d,flush=True)
for obj in body:obj.data.materials.clear();obj.data.materials.append(hold)
for d in directions:
    for cell in range(6):
        for f in identity['nose_holdout_poses']:
            pose(d,f,cell);capture(out/f'd{d:02}-nose{cell}-p{f:03}.png')
    print('ROCKET_NOSE_DIRECTION_DONE',d,flush=True)
report={'status':'COMPLETE' if len(directions)==64 else 'PILOT_COMPLETE','directions':directions,
 'identity':identity,'elapsed_seconds':time.monotonic()-start,
 'remaining':'Pack and inspect exact atlas cells; weapon shadows and native graphical pilot are separate gates'}
(out/('capture.json' if len(directions)==64 else 'pilot.json')).write_text(json.dumps(report,indent=2)+'\n')
print('ROCKET_CAPTURE_DONE',report['status'],flush=True)
