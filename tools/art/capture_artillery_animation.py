"""Capture real barrage poses and per-chamber, depth-occluded shell overlays.

All 64 headings are rendered; cardinal headings finish first for engine review.
The separate bunker is never baked into the moving cap.
"""
import bpy,sys,json,math,hashlib,time,shutil
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

arguments=sys.argv[sys.argv.index('--')+1:];source,out=(Path(p).resolve() for p in arguments[:2]);out.mkdir(parents=True,exist_ok=True)
cache=Path(arguments[2])if len(arguments)>2 else None
reuse=json.loads((out/'reuse.json').read_text())if cache else None
if reuse:assert reuse['source_sha256']==hashlib.sha256(source.read_bytes()).hexdigest()
ticks={0,89,90,179,180,249,250,300,314,315,360,440,499,500,545,549,550,600}
for shot in (0,90,180):
    ticks.update(shot+t for t in list(range(13))+list(range(16,61,4))+[62])
for shot in (0,90):ticks.update(shot+t for t in list(range(64,83,3))+[82,83,88])
for lo,hi in ((250,300),(315,360),(360,440),(500,545),(550,600)):ticks.update(range(lo,hi+1,5))
ticks=sorted(ticks)
ticks=sorted(set(ticks)|set(range(450,496)))
bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(1)
root=bpy.data.objects['TURRET_TRAVERSE'];root.animation_data_clear();root.rotation_euler=(0,0,0)
s.render.engine='CYCLES';s.cycles.samples=8;s.cycles.use_denoising=True;s.render.use_persistent_data=True
s.render.threads_mode='FIXED';s.render.threads=4
try:
    prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
    for device in prefs.devices:device.use=device.type=='OPTIX'
    if any(d.type=='OPTIX' for d in prefs.devices):s.cycles.device='GPU'
except Exception:s.cycles.device='CPU'
target=Vector((0,0,3.5));s.camera.location=target+Vector((0,-10,10))
s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler()
s.camera.data.type='ORTHO';s.camera.data.ortho_scale=9.6
s.render.resolution_x=s.render.resolution_y=384;s.render.resolution_percentage=100
s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
s.use_nodes=False;s.render.use_compositing=False;s.render.use_sequencer=False
bpy.context.view_layer.update();origin=world_to_camera_view(s,s.camera,Vector((0,0,0)))
identity={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
 'cell':384,'scale':.8,'shift':[(.5-origin.x)*9.6,(origin.y-.5)*9.6],'ticks':ticks,'headings':64,'base_included':False,
 'source_fps':60,'muzzle_source':list(bpy.data.objects['MUZZLE_ARTILLERY'].matrix_world.translation),
 'scope':'Full structural source poses plus three independently occluded shell layers. No baked firing effects. Shadows captured separately.'}
if (out/'identity.json').exists():assert json.loads((out/'identity.json').read_text())==identity,'Animation inputs changed; retain the old cache'
else:(out/'identity.json').write_text(json.dumps(identity,indent=2)+'\n')
rounds=[bpy.data.objects['LOADED_ARTILLERY_SHELL_'+str(i)] for i in range(3)]
def child(obj,parent):
    while obj.parent:
        obj=obj.parent
        if obj==parent:return True
    return False
objects=[o for o in s.objects if o.type in ('MESH','CURVE')]
body=[o for o in objects if not any(child(o,r) for r in rounds)]
materials={o.name:list(o.data.materials) for o in body}
hold=bpy.data.materials.new('ANIMATION_CAPTURE_ONLY_BODY_DEPTH');hold.use_nodes=True
nodes=hold.node_tree.nodes;nodes.clear();h=nodes.new('ShaderNodeHoldout');output=nodes.new('ShaderNodeOutputMaterial');hold.node_tree.links.new(h.outputs[0],output.inputs['Surface'])
def pose(d,tick,cell=None):
    s.frame_set(tick+1);root.rotation_euler.z=math.pi-d*math.tau/64
    for i,r in enumerate(rounds):r.scale=(1,1,1) if i==cell else (0,0,0)
    bpy.context.view_layer.update()
rendered={};reused=0
def render(path,d,layer,tick):
    global reused
    if path.exists():return
    alias=reuse and reuse['aliases'][layer].get(str(tick))
    key=(d,layer,alias if alias is not None else ('new',tick))
    inherited=None
    if alias is not None:
        old_index=reuse['cache_identity']['ticks'].index(alias)
        candidate=cache/f'd{d:02}-{layer}-{old_index:03}.png'
        if candidate.exists():inherited=candidate
    if inherited is None:inherited=rendered.get(key)
    if inherited:
        shutil.copy2(inherited,path);reused+=1
    else:s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    rendered[key]=path
def restore():
    for obj in body:
        obj.data.materials.clear()
        for material in materials[obj.name]:obj.data.materials.append(material)
    s.render.use_border=False
def border(cell):
    points=[world_to_camera_view(s,s.camera,o.matrix_world@Vector(p)) for o in objects if child(o,rounds[cell]) for p in o.bound_box]
    pad=5/384
    s.render.use_border=True;s.render.use_crop_to_border=False
    s.render.border_min_x=max(0,min(p.x for p in points)-pad);s.render.border_max_x=min(1,max(p.x for p in points)+pad)
    s.render.border_min_y=max(0,min(p.y for p in points)-pad);s.render.border_max_y=min(1,max(p.y for p in points)+pad)
directions=[0,16,32,48]+[d for d in range(64) if d not in (0,16,32,48)]
completed=[];began=time.monotonic()
def receipt(status):
    data={'status':status,'identity':identity,'completed_headings':completed,'elapsed_seconds':time.monotonic()-began}
    temp=out/'capture.next.json';temp.write_text(json.dumps(data,indent=2)+'\n');temp.replace(out/'capture.json')
receipt('RUNNING')
for d in directions:
    restore()
    for i,tick in enumerate(ticks):
        pose(d,tick);render(out/f'd{d:02}-body-{i:03}.png',d,'body',tick)
        if i%20==0:print('ARTILLERY_ANIMATION_BODY',d,i,len(ticks),round(time.monotonic()-began,1),flush=True)
    for obj in body:obj.data.materials.clear();obj.data.materials.append(hold)
    for cell in range(3):
        for i,tick in enumerate(ticks):
            pose(d,tick,cell);border(cell)
            path=out/f'd{d:02}-shell{cell}-{i:03}.png'
            # Unoccupied chambers are hidden by the native inventory owner.
            visible=tick<=cell*90 or tick>=450+15*cell
            if not visible:
                if not path.exists():
                    empty_path=out/'empty-chamber.png'
                    if not empty_path.exists():
                        empty=bpy.data.images.new('EMPTY_UNOCCUPIED_CHAMBER',width=384,height=384,alpha=True)
                        empty.generated_color=(0,0,0,0);empty.file_format='PNG'
                        empty.filepath_raw=str(empty_path);empty.save()
                    shutil.copy2(empty_path,path)
            else:render(path,d,'shell'+str(cell),tick)
            if i%40==0:print('ARTILLERY_ANIMATION_SHELL',d,cell,i,len(ticks),flush=True)
    completed.append(d);receipt('PILOT_READY' if len(completed)>=4 else 'RUNNING')
    print('ARTILLERY_ANIMATION_DIRECTION_COMPLETE',d,round(time.monotonic()-began,1),flush=True)
receipt('COMPLETE')
print('ARTILLERY_ANIMATION_ALL_64_COMPLETE',flush=True)
print('ARTILLERY_IDENTICAL_POSES_REUSED',reused,flush=True)
