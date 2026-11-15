"""Render the editable cannon's real motion, with local native effect artwork.

The native sprite is loaded only for this private review render. It is not
packed into the saved model or GLB. Runtime uses the engine explosion entity.
"""
import bpy,sys,math,json,hashlib
from pathlib import Path
from mathutils import Vector, Quaternion
sys.path.insert(0,str(Path(__file__).resolve().parent))
source,out=map(Path,sys.argv[sys.argv.index('--')+1:]);out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source));S=bpy.context.scene
root=bpy.data.objects['TURRET_TRAVERSE'];original_inverse=root.matrix_world.inverted().copy()
root.rotation_euler.z=math.pi/4;bpy.context.view_layer.update()
S.render.resolution_x=S.render.resolution_y=512;S.render.resolution_percentage=100
S.render.engine='CYCLES';S.cycles.samples=8;S.cycles.use_denoising=True
S.render.threads_mode='FIXED';S.render.threads=4
try:
    prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
    for device in prefs.devices:device.use=device.type=='OPTIX'
    if any(device.type=='OPTIX' for device in prefs.devices):S.cycles.device='GPU'
except Exception:pass
native=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/data/base/graphics/entity/explosion-gunshot/explosion-gunshot.png')
texture=bpy.data.images.load(str(native));texture.alpha_mode='STRAIGHT'
planes=[];uv_layers=[]
for bank in (0,1):
    material=bpy.data.materials.new('REVIEW ONLY native cannon effect '+str(bank));material.use_nodes=True
    nodes=material.node_tree.nodes;nodes.clear();image=nodes.new('ShaderNodeTexImage');image.image=texture;image.interpolation='Linear';image.extension='CLIP'
    emission=nodes.new('ShaderNodeEmission');material.node_tree.links.new(image.outputs['Color'],emission.inputs['Color'])
    transparent=nodes.new('ShaderNodeBsdfTransparent');mix=nodes.new('ShaderNodeMixShader')
    material.node_tree.links.new(image.outputs['Alpha'],mix.inputs[0]);material.node_tree.links.new(transparent.outputs[0],mix.inputs[1]);material.node_tree.links.new(emission.outputs[0],mix.inputs[2])
    output=nodes.new('ShaderNodeOutputMaterial');material.node_tree.links.new(mix.outputs[0],output.inputs[0])
    bpy.ops.mesh.primitive_plane_add(size=1);plane=bpy.context.object;plane.name='REVIEW_ONLY_NATIVE_CANNON_FLASH_'+str(bank)
    plane.dimensions=(34/32,38/32,0);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    plane.rotation_euler=S.camera.rotation_euler.copy();plane.data.materials.append(material)
    plane.visible_diffuse=False;plane.visible_glossy=False;plane.visible_transmission=False;plane.visible_shadow=False
    uv_layers.append(plane.data.uv_layers.active);planes.append(plane)
shots={0:[0,90],1:[45,135]}
flexible=bpy.data.objects.get('FLEXIBLE_RADIO_WHIP_0') is not None
if flexible:root.delta_rotation_euler.z=math.pi/4
ticks=sorted(set(range(0,481,5) if flexible else range(0,226,3))|{shot+delta for values in shots.values() for shot in values for delta in (0,1,2)}|{80,215})
identity={'native_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'native_effect_sha256':hashlib.sha256(native.read_bytes()).hexdigest()}
if (out/'identity.json').exists():assert json.loads((out/'identity.json').read_text())==identity,'Review input changed'
else:(out/'identity.json').write_text(json.dumps(identity,indent=2)+'\n')
for tick in ticks:
    S.frame_set(tick+1);bpy.context.view_layer.update()
    for bank,plane in enumerate(planes):
        recent=[t for t in shots[bank] if t<=tick];age=tick-recent[-1] if recent else 1000
        plane.hide_render=age>=2
        if age<2:
            muzzle=root.matrix_world@(original_inverse@Vector((-.58 if bank==0 else .58,-2.55,2.61)))
            forward=root.matrix_world.to_3x3()@Vector((0,-1,0))
            screen=S.camera.matrix_world.to_quaternion().inverted()@forward
            angle=math.atan2(-screen.x,screen.y)
            plane.rotation_mode='QUATERNION'
            plane.rotation_quaternion=S.camera.matrix_world.to_quaternion()@Quaternion((0,0,1),angle)
            # Match the runtime native flash centre, with the owner's small lead.
            plane.location=muzzle+plane.rotation_quaternion@Vector((0,.16,0))
            frame=min(1,int(age*1.5));u0=frame*34/texture.size[0];u1=(frame+1)*34/texture.size[0]
            for polygon in plane.data.polygons:
                for li in polygon.loop_indices:
                    vertex=plane.data.vertices[plane.data.loops[li].vertex_index].co
                    uv_layers[bank].data[li].uv=(u0 if vertex.x<0 else u1,0 if vertex.y<0 else 1)
            plane.data.update()
    target=out/f'tick-{tick:03}.png'
    if not target.exists():S.render.filepath=str(target);bpy.ops.render.render(write_still=True)
    print('CANNON_MOTION_REVIEW_FRAME',tick,flush=True)
(out/'review.json').write_text(json.dumps({'status':'COMPLETE','identity':identity,'ticks':ticks,'source_fps':60,'render_size':512,
    'native_effect':'Original explosion-gunshot artwork shown at the active muzzle; review rendering only, not an in-game capture.'},indent=2)+'\n')
