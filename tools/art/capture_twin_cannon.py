"""Directional native-cap capture with shot-driven cold/overlap/settle states.

Blender --python THIS -- SOURCE OUTPUT [comma-separated headings]
No foundation, muzzle flames or traverse-study animation is baked into sprites.
"""
import bpy,sys,math,json,hashlib,time
from pathlib import Path
from mathutils import Vector

args=sys.argv[sys.argv.index('--')+1:];source,out=map(Path,args[:2]);out.mkdir(parents=True,exist_ok=True)
directions=list(map(int,args[2].split(','))) if len(args)>2 else list(range(64))
bpy.ops.wm.open_mainfile(filepath=str(source));S=bpy.context.scene
root=bpy.data.objects['TURRET_TRAVERSE'];root.animation_data_clear();root.rotation_euler=(0,0,0)
root.delta_rotation_euler=(0,0,0)
S.render.engine='CYCLES';S.cycles.samples=8;S.cycles.use_denoising=True
S.render.use_persistent_data=True;S.render.threads_mode='FIXED';S.render.threads=4
prefs=bpy.context.preferences.addons['cycles'].preferences
try:
    prefs.compute_device_type='OPTIX';prefs.get_devices()
    for device in prefs.devices:device.use=device.type=='OPTIX'
    if any(device.type=='OPTIX' for device in prefs.devices):S.cycles.device='GPU'
except Exception:S.cycles.device='CPU'
S.render.film_transparent=True;S.render.resolution_percentage=100
S.render.resolution_x=S.render.resolution_y=256;S.camera.data.ortho_scale=6.199999809265137
S.render.image_settings.file_format='PNG';S.render.image_settings.color_mode='RGBA'
S.use_nodes=False;S.render.use_compositing=False
identity={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
          'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'headings':64,'cell':256,'fps':30,'base_included':False,
          'modes':{'idle':1,'single0':40,'single1':40,'overlap0':18,'overlap1':18},
          'aerial_tip_offsets':[-.09,-.045,0,.045,.09]}
if (out/'identity.json').exists():assert json.loads((out/'identity.json').read_text())==identity,'Capture input changed'
else:(out/'identity.json').write_text(json.dumps(identity,indent=2)+'\n')
whips=[bpy.data.objects['FLEXIBLE_RADIO_WHIP_'+str(i)] for i in (0,1)]
caps=[bpy.data.objects['Flexible whip protective tip'+('' if i==0 else '.001')] for i in (0,1)]
aerials=whips+caps;meshes=[o for o in S.objects if o.type in ('MESH','CURVE')]
body=[o for o in meshes if o not in aerials]
materials={o.name:list(o.data.materials) for o in meshes}
hold=bpy.data.materials.new('CAPTURE ONLY aerial depth holdout');hold.use_nodes=True
nodes=hold.node_tree.nodes;nodes.clear();p=nodes.new('ShaderNodeHoldout');n=nodes.new('ShaderNodeOutputMaterial');hold.node_tree.links.new(p.outputs[0],n.inputs[0])
bank_parts=[]
for bank in (0,1):
    bank_parts.append([o for o in S.objects if o.name in ('INDEPENDENT_RECOIL_'+str(bank),'INDEPENDENT_MANTLET_'+str(bank),'LOADING_RAM_'+str(bank))
                       or o.name.startswith('ENCLOSED_FEED_ROUND_'+str(bank)+'_')])
S.frame_set(226);bpy.context.view_layer.update()
rest=[{o.name:o.matrix_basis.copy() for o in parts} for parts in bank_parts]
actions={o.name:o.animation_data.action for parts in bank_parts for o in parts if o.animation_data}
# Rest shape/cap positions must come from a settled frame, not shot zero.
cap_rest=[o.location.copy() for o in caps]
for obj in whips:
    obj.data.shape_keys.animation_data_clear()
    for key in list(obj.data.shape_keys.key_blocks)[1:]:key.value=0
for obj in caps:obj.animation_data_clear()

def pose(direction,mode,frame):
    for parts in bank_parts:
        for obj in parts:
            if obj.name in actions:obj.animation_data.action=actions[obj.name]
    bank=int(mode[-1]) if mode!='idle' else 0
    tick=225 if mode=='idle' else ((0 if bank==0 else 135) if mode.startswith('single') else (90 if bank==0 else 135))+frame*2
    S.frame_set(tick+1)
    if mode.startswith('single'):
        for obj in bank_parts[1-bank]:
            if obj.animation_data:obj.animation_data.action=None
            obj.matrix_basis=rest[1-bank][obj.name]
    root.rotation_euler.z=math.pi-direction*math.tau/64
    for obj in whips:
        for key in list(obj.data.shape_keys.key_blocks)[1:]:key.value=0
    for obj,location in zip(caps,cap_rest):obj.location=location
    bpy.context.view_layer.update()

def capture(path):
    if path.exists():return
    S.render.filepath=str(path);bpy.ops.render.render(write_still=True)

started=time.monotonic()
for obj in aerials:obj.hide_render=False
for d in directions:
    pose(d,'idle',0);capture(out/f'd{d:02}-preview.png')
print('CANNON_NATIVE_PREVIEWS_READY',directions,flush=True)
for obj in aerials:obj.hide_render=True
for d in directions:
    for mode,count in identity['modes'].items():
        for frame in range(count):
            pose(d,mode,frame);capture(out/f'd{d:02}-{mode}-{frame:02}.png')
    print('CANNON_BODY_DIRECTION',d,'seconds',round(time.monotonic()-started,1),flush=True)

# Whips are depth-tested against the actual stationary casting and feed cages.
for obj in body:obj.data.materials.clear();obj.data.materials.append(hold)
for d in directions:
    for bank in (0,1):
        pose(d,'idle',0)
        for obj in aerials:obj.hide_render=obj not in (whips[bank],caps[bank])
        for ix,x in enumerate(identity['aerial_tip_offsets']):
            for iy,y in enumerate(identity['aerial_tip_offsets']):
                whip=whips[bank];whip.data.shape_keys.key_blocks[1].value=x/.24;whip.data.shape_keys.key_blocks[2].value=y/.24
                caps[bank].location=cap_rest[bank]+Vector((x,y,0))
                bpy.context.view_layer.update();capture(out/f'd{d:02}-aerial{bank}-{ix*5+iy:02}.png')
    print('CANNON_AERIAL_DIRECTION',d,'seconds',round(time.monotonic()-started,1),flush=True)

for obj in meshes:
    obj.data.materials.clear()
    for material in materials[obj.name]:obj.data.materials.append(material)
    obj.hide_render=False
# Native UI preview is the complete neutral model, including both guns/aerials.
for d in directions:
    pose(d,'idle',0);capture(out/f'd{d:02}-preview.png')
record={'status':'COMPLETE' if len(directions)==64 else 'PILOT_COMPLETE','identity':identity,
        'directions':directions,'elapsed_seconds':time.monotonic()-started,
        'shadow':'To be captured as a separate static cap shadow pass',
        'scale':.774999976158,'shift':[0,-1.110906519093]}
(out/('capture.json' if len(directions)==64 else 'pilot.json')).write_text(json.dumps(record,indent=2)+'\n')
print('CANNON_CAPTURE_COMPLETE',json.dumps(record),flush=True)
