"""Render 3D electric filaments against the actual dish's depth holdout.

No base is loaded. Pilot: eight headings and phases 0/7/15. Full: 64 x 16.
Filaments lie on the concave reflector's front and connect to the emitter.
"""
import bpy
import json
import math
from pathlib import Path
import sys
from mathutils import Vector
args=sys.argv[sys.argv.index('--')+1:]
source=Path(args[0]);output=Path(args[1]);pilot='--pilot' in args
output.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source))
scene=bpy.context.scene
scene.use_nodes=False;scene.render.use_compositing=False;scene.render.use_sequencer=False
scene.render.engine='CYCLES';scene.cycles.samples=4;scene.cycles.use_denoising=False
scene.render.resolution_x=scene.render.resolution_y=256;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.color_mode='RGBA';scene.render.image_settings.file_format='PNG'
scene.render.threads_mode='FIXED';scene.render.threads=4
scene.camera.data.ortho_scale=6.199999809265137
# Prefer OptiX, falling back explicitly to the existing CPU renderer.
backend='CPU'
try:
    preferences=bpy.context.preferences.addons['cycles'].preferences
    preferences.compute_device_type='OPTIX';preferences.get_devices()
    for device in preferences.devices:device.use=device.type=='OPTIX'
    if any(d.type=='OPTIX' for d in preferences.devices):scene.cycles.device='GPU';backend='OPTIX'
except Exception:scene.cycles.device='CPU'
root=bpy.data.objects['TURRET_TRAVERSE']
holdout=bpy.data.materials.new('FX depth occluder');holdout.use_nodes=True
nodes=holdout.node_tree.nodes;nodes.clear();out=nodes.new('ShaderNodeOutputMaterial');shader=nodes.new('ShaderNodeHoldout')
holdout.node_tree.links.new(shader.outputs[0],out.inputs['Surface'])
mesh_count=0
for o in scene.objects:
    if o.type=='MESH':
        mesh_count+=1;o.data.materials.clear();o.data.materials.append(holdout)
assert mesh_count==33,'Dish-only source required; never load the bunker into rotating FX'
def emission(name,color,strength):
    material=bpy.data.materials.new(name);material.use_nodes=True
    nodes=material.node_tree.nodes;nodes.clear();out=nodes.new('ShaderNodeOutputMaterial');shader=nodes.new('ShaderNodeEmission')
    shader.inputs['Color'].default_value=(*color,1);shader.inputs['Strength'].default_value=strength
    material.node_tree.links.new(shader.outputs[0],out.inputs['Surface']);return material
blue=emission('Ionized blue sheath',(.03,.28,1),3)
white=emission('White hot electrical core',(.5,.85,1),7)
fx=[]
def filament(name,points,radius,material):
    data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.bevel_depth=radius;data.bevel_resolution=1;data.resolution_u=1
    spline=data.splines.new('POLY');spline.points.add(len(points)-1)
    for p,v in zip(spline.points,points):p.co=(*v,1)
    o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);data.materials.append(material)
    o.parent=root;o.matrix_parent_inverse=root.matrix_world.inverted();fx.append(o)
def surface(x,z):
    return Vector((x,.18-.52*((z-2.86)/.95)**2-.055,z))
def build(phase):
    # Every phase is authored in the same rest frame. The previous heading
    # must not leak into a new curve's inverse-parent transform.
    root.rotation_euler.z=0;bpy.context.view_layer.update()
    for o in fx:bpy.data.objects.remove(o,do_unlink=True)
    fx.clear()
    strength=1 if phase==0 else phase/15
    count=8 if phase==0 else 1+int(strength*5)
    for branch in range(count):
        side=-1 if branch%2 else 1
        z0=2.1+1.5*((branch*.381+phase*.127)%1)
        start=surface(side*(.65+.18*math.sin(branch+phase)),z0)
        finish=surface(side*.08,2.86+.18*math.sin(phase*.8+branch))
        points=[]
        for step in range(10):
            f=step/9
            x=start.x*(1-f)+finish.x*f+.035*math.sin(step*4.7+phase*1.9+branch)*math.sin(f*math.pi)
            z=start.z*(1-f)+finish.z*f+.05*math.sin(step*3.7+phase+branch)*math.sin(f*math.pi)
            points.append(surface(x,z))
        # Final free-air jump reaches the real central feed / emitter.
        points.extend([Vector((side*.08,-.35,2.86)),Vector((side*.025,-.68,2.9)),Vector((0,-1.105,2.86))])
        filament('Sheath',points,.009 if phase==0 else .004+.003*strength,blue)
        filament('Core',points,.0035 if phase==0 else .0017,white)
        if strength>.5:
            fork=[points[3],points[3]+Vector((side*.11,-.015,.1)),points[3]+Vector((side*.21,0,.16))]
            filament('Branch fork',fork,.003,blue)
    scene['fx_phase']=phase
headings=list(range(0,64,8)) if pilot else list(range(64))
phases=[0,7,15] if pilot else list(range(16))
for phase in phases:
    build(phase)
    for d in headings:
        path=output/f'fx-{d:02}-{phase:02}.png'
        if path.exists():continue
        root.rotation_euler.z=math.radians(180-d*5.625)
        scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        print('DISH_DEPTH_FX',d,phase,backend,flush=True)
scene['fx_contract']='Filaments rendered with all 33 dish meshes as depth occluders; 64 clockwise headings; base excluded.'
bpy.ops.wm.save_as_mainfile(filepath=str(output/('electrical_fx_pilot.blend' if pilot else 'energy_dish_electrical_fx.blend')),compress=True)
(output/'capture.json').write_text(json.dumps({'status':'PILOT_COMPLETE' if pilot else 'COMPLETE',
    'backend':backend,'headings':headings,'phases':phases,'base_included':False,'mesh_occluders':33,
    'source':str(source),'cell':256,'scale':.774999976158,'shift':[0,-1.110906519093]},indent=2)+'\n')
