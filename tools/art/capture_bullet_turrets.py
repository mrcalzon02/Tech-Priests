"""Capture separated caps at explicit 30 fps: body, occluded FX, ground shadow.

One Blender process per cap. All source keys remain at 60 fps in the master.
The 48/36 tick loops sample exactly to 24/18 runtime frames, with every shot
on a sample boundary. No bunker geometry is present in any pass.
"""
import bpy, sys, math, json, hashlib
from pathlib import Path
from array import array
source,out=map(Path,sys.argv[sys.argv.index('--')+1:]);out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source));S=bpy.context.scene
variant=S['variant'];ticks=48 if variant=='chicago-piano' else 36
identity={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
          'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'variant':variant,'headings':64,'fps':30,'cycle_ticks':ticks,'frames':ticks//2,'base_included':False}
if (out/'identity.json').exists():assert json.loads((out/'identity.json').read_text())==identity,'Capture identity changed'
else:(out/'identity.json').write_text(json.dumps(identity,indent=2)+'\n')
root=bpy.data.objects['TURRET_TRAVERSE']
FX=[o for o in S.objects if 'MUZZLE_FLASH_' in o.name or 'ROTOR_FLASH_' in o.name]
body=[o for o in S.objects if o.type in ('MESH','CURVE') and o not in FX]
materials={o.name:list(o.data.materials) for o in body}
hold=bpy.data.materials.new('CAPTURE ONLY depth occluder');hold.use_nodes=True
nodes=hold.node_tree.nodes;nodes.clear();p=nodes.new('ShaderNodeHoldout');output=nodes.new('ShaderNodeOutputMaterial');hold.node_tree.links.new(p.outputs[0],output.inputs['Surface'])
S.render.engine='CYCLES';S.cycles.samples=8;S.cycles.use_denoising=True
S.render.threads_mode='FIXED';S.render.threads=4
prefs=bpy.context.preferences.addons['cycles'].preferences
try:
    prefs.compute_device_type='OPTIX';prefs.get_devices()
    for device in prefs.devices:device.use=device.type=='OPTIX'
    if any(d.type=='OPTIX' for d in prefs.devices):S.cycles.device='GPU'
except Exception:S.cycles.device='CPU'
S.render.film_transparent=True;S.render.resolution_percentage=100
S.render.image_settings.file_format='PNG';S.render.image_settings.color_mode='RGBA'
S.view_layers[0].cycles.use_pass_shadow_catcher=True
tree=bpy.data.node_groups.new('Neutral bounded shadow ratio','CompositorNodeTree')
tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
rl=tree.nodes.new('CompositorNodeRLayers');rl.layer=S.view_layers[0].name
dn=tree.nodes.new('CompositorNodeDenoise');tree.links.new(rl.outputs['Shadow Catcher'],dn.inputs['Image'])
gray=tree.nodes.new('CompositorNodeRGBToBW');tree.links.new(dn.outputs['Image'],gray.inputs[0])
inv=tree.nodes.new('ShaderNodeMath');inv.operation='SUBTRACT';inv.inputs[0].default_value=1;inv.use_clamp=True
tree.links.new(gray.outputs[0],inv.inputs[1])
mask=bpy.data.images.new('Registered receiver',width=512,height=512,alpha=True,float_buffer=True);pixels=array('f')
for y in range(512):
    for x in range(512):
        radius=math.sqrt(((x-256)/217.6)**2+((511-y-301.8696899414)/179.2)**2)
        t=max(0,min(1,(radius-.78)/.22));a=1-t*t*(3-2*t);pixels.extend((a,a,a,1))
mask.pixels.foreach_set(pixels);image=tree.nodes.new('CompositorNodeImage');image.image=mask
mul=tree.nodes.new('ShaderNodeMath');mul.operation='MULTIPLY';tree.links.new(inv.outputs[0],mul.inputs[0]);tree.links.new(image.outputs['Image'],mul.inputs[1])
alpha=tree.nodes.new('CompositorNodeSetAlpha');alpha.inputs['Image'].default_value=(0,0,0,1);tree.links.new(mul.outputs[0],alpha.inputs['Alpha'])
output=tree.nodes.new('NodeGroupOutput');tree.links.new(alpha.outputs['Image'],output.inputs['Image'])
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,0));catcher=bpy.context.object
catcher.name='PASS_ONLY_GROUND';catcher.is_shadow_catcher=True;catcher.hide_render=True
def restore():
    for o in body:
        o.data.materials.clear()
        for m in materials[o.name]:o.data.materials.append(m)
        o.visible_camera=True
    for o in FX:o.hide_render=True
    catcher.hide_render=True;S.use_nodes=False;S.render.use_compositing=False
def render(direction,frame,idle=False):
    prefix=f'd{direction:02}-'+('idle' if idle else f'f{frame:02}')
    paths={p:out/(prefix+'-'+p+'.png') for p in ('body','fx','shadow')}
    if all(p.exists() for p in paths.values()):return
    S.frame_set(1 if idle else frame*2+1)
    root.rotation_euler.z=math.radians(180-direction*5.625)
    restore();S.camera.data.ortho_scale=6.199999809265137
    S.render.resolution_x=S.render.resolution_y=256
    if not paths['body'].exists():
        S.render.filepath=str(paths['body']);bpy.ops.render.render(write_still=True)
    if not paths['fx'].exists():
        for o in body:o.data.materials.clear();o.data.materials.append(hold)
        for o in FX:o.hide_render=idle
        S.cycles.use_denoising=False
        S.render.filepath=str(paths['fx']);bpy.ops.render.render(write_still=True)
        S.cycles.use_denoising=True
    restore()
    if not paths['shadow'].exists():
        for o in body:o.visible_camera=False
        catcher.hide_render=False;S.use_nodes=True;S.render.use_compositing=True;S.compositing_node_group=tree
        S.camera.data.ortho_scale=12.399999618530274;S.render.resolution_x=S.render.resolution_y=512
        S.render.filepath=str(paths['shadow']);bpy.ops.render.render(write_still=True)
    print('BULLET_CAP_CAPTURE',variant,direction,frame,'idle' if idle else 'firing',flush=True)
def pose(d,frame,idle=False):
    S.frame_set(1 if idle else frame*2+1)
    root.rotation_euler.z=math.radians(180-d*5.625)
# Batch material/pass changes. Recompiling the full textured scene between
# every body/holdout/catcher frame is much slower than pose evaluation.
for pas in ('body','fx','shadow'):
    restore();S.render.resolution_x=S.render.resolution_y=256
    S.camera.data.ortho_scale=6.199999809265137
    if pas=='fx':
        for o in body:o.data.materials.clear();o.data.materials.append(hold)
        S.cycles.use_denoising=False
    elif pas=='shadow':
        for o in body:o.visible_camera=False
        catcher.hide_render=False;S.use_nodes=True;S.render.use_compositing=True;S.compositing_node_group=tree
        S.camera.data.ortho_scale=12.399999618530274;S.render.resolution_x=S.render.resolution_y=512
        S.cycles.use_denoising=True
    for d in range(64):
        poses=[('idle',0,True)]
        if pas!='shadow':poses += [(f'f{f:02}',f,False) for f in range(ticks//2)]
        for label,frame,idle in poses:
            path=out/f'd{d:02}-{label}-{pas}.png'
            if path.exists():continue
            pose(d,frame,idle)
            if pas=='fx':
                for o in FX:o.hide_render=idle
            S.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        print('BULLET_CAP_PASS',variant,pas,d,flush=True)
(out/'capture.json').write_text(json.dumps({'status':'COMPLETE','identity':identity,
    'cell':256,'shadow_cell':512,'shadow_mode':'static cap shadow per aim heading',
    'scale':.774999976158,'shift':[0,-1.110906519093]},indent=2)+'\n')
