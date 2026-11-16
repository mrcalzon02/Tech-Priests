"""Run with Blender 4.3+: blender -b -P build_family.py -- /path/to/output"""
import sys
import math
from pathlib import Path
import bpy
from mathutils import Vector
import numpy as np

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import core, plumbing, structure, services, forge
NAMES=('Minoris','Majoris','Maximus')
RADII=(1.65,2.30,3.05)
VIEW=Vector((.53,-1,.415)).normalized()
EAST=Vector((-VIEW.y,VIEW.x,0)).normalized()

def area(studio,name,loc,target,power,color,size,size_y=None):
    lamp=bpy.data.lights.new(name,'AREA')
    lamp.energy=power; lamp.color=color
    lamp.shape='DISK' if size_y is None else 'RECTANGLE'
    lamp.size=size
    if size_y: lamp.size_y=size_y
    obj=bpy.data.objects.new(name,lamp)
    studio.objects.link(obj)
    obj.location=loc
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
    return obj

def studio_scene():
    s=bpy.context.scene
    c=bpy.data.collections.new('Studio • cameras, lights and floor')
    s.collection.children.link(c)
    world=bpy.data.worlds.new('Foundry photographic stage')
    world.use_nodes=True
    bg=world.node_tree.nodes.get('Background')
    world_path=bpy.utils.system_resource('DATAFILES',path='studiolights/world/studio.exr')
    if world_path and Path(world_path).exists():
        env=world.node_tree.nodes.new('ShaderNodeTexEnvironment')
        env.image=bpy.data.images.load(world_path)
        env.image.pack()
        world.node_tree.links.new(env.outputs['Color'],bg.inputs['Color'])
        bg.inputs['Strength'].default_value=.36
    else:
        bg.inputs['Color'].default_value=(.37,.39,.43,1);bg.inputs['Strength'].default_value=.65
    s.world=world
    # Wide softboxes act as long highlights on the continuous annulus and on pipe elbows.
    area(c,'Warm overhead softbox',(-7,-12,18),(0,0,1),6100,(1.0,.86,.72),12,8)
    area(c,'Cold right softbox',(12,-5,11),(0,0,2),4650,(.74,.84,1.0),10,9)
    area(c,'Rear strip on pipe gallery',(-3,10,14),(0,0,3),8500,(1.0,.81,.65),14,5)
    area(c,'Broad frontal reflector',(-1,-13,5),(0,0,2.5),1050,(.85,.90,1),10,8)
    mat=bpy.data.materials.new('Studio | Basalt')
    mat.diffuse_color=(.068,.074,.08,1);mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(.044,.047,.053,1);bs.inputs['Roughness'].default_value=.87
    me=bpy.data.meshes.new('Seamless studio floor')
    me.from_pydata([(-200,-200,0),(200,-200,0),(200,200,0),(-200,200,0)],[],[(0,1,2,3)])
    floor=bpy.data.objects.new('Ground • photographic stage',me)
    c.objects.link(floor);me.materials.append(mat)
    camdata=bpy.data.cameras.new('Family portrait')
    camdata.type='ORTHO';camdata.clip_end=700
    cam=bpy.data.objects.new('Camera • all three reactors',camdata);c.objects.link(cam)
    s.camera=cam
    s.render.engine='CYCLES';s.cycles.samples=32
    s.cycles.use_denoising=False
    s.cycles.max_bounces=4;s.cycles.diffuse_bounces=2;s.cycles.glossy_bounces=2
    s.cycles.sample_clamp_indirect=2.5
    s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGB'
    s.render.resolution_percentage=100
    s.display.shading.light='STUDIO';s.display.shading.color_type='MATERIAL'
    s.view_settings.view_transform='AgX'
    s.view_settings.look='AgX - Medium High Contrast'
    s.view_settings.exposure=-.18
    s.render.film_transparent=False
    return c

def bounds(objs):
    v=[]
    for obj in objs:
        if obj.type!='MESH': continue
        points=np.empty(len(obj.data.vertices)*3,dtype=np.float32)
        obj.data.vertices.foreach_get('co',points)
        # Model roots only translate. Use a full transform to retain generality for inspection.
        matrix=np.asarray(obj.matrix_world,dtype=np.float32)
        v.append(points.reshape((-1,3))@matrix[:3,:3].T+matrix[:3,3])
    return np.concatenate(v)

def frame(objs, direction, width, height, margin=1.1):
    s=bpy.context.scene
    direction=Vector(direction).normalized()
    q=(-direction).to_track_quat('-Z','Y')
    xright=q @ Vector((1,0,0)); yup=q @ Vector((0,1,0))
    pts=bounds(objs)
    x=pts@np.asarray(xright);y=pts@np.asarray(yup);z=pts@np.asarray(direction)
    center=xright*float((x.max()+x.min())*.5)+yup*float((y.max()+y.min())*.5)+direction*float((z.max()+z.min())*.5)
    scale=max(float(x.max()-x.min()),float(y.max()-y.min())*width/height)*margin
    cam=s.camera;cam.rotation_euler=q.to_euler()
    cam.location=center+direction*60
    cam.data.ortho_scale=scale
    s.render.resolution_x=width;s.render.resolution_y=height
    return q,center,scale

def setup_view(objs):
    q,center,scale=frame(objs,VIEW,2360,1000,1.065)
    for screen in bpy.data.screens:
        for a in screen.areas:
            if a.type=='VIEW_3D':
                sp=a.spaces.active; sp.region_3d.view_rotation=q;sp.region_3d.view_distance=scale*.90;sp.region_3d.view_location=center
                sp.region_3d.view_perspective='ORTHO';sp.clip_end=1000
                sp.overlay.show_overlays=False;sp.shading.color_type='MATERIAL';sp.shading.light='STUDIO';sp.shading.show_shadows=True;sp.shading.show_cavity=True;sp.shading.cavity_type='WORLD'
                sp.shading.cavity_ridge_factor=1.1;sp.shading.cavity_valley_factor=1.1

def create(out):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s=bpy.context.scene;s.name='Forge of Mars • Plasma Reactors'
    s.unit_settings.system='METRIC'
    forge.build_materials(out/'work'/'surface_maps')
    roots=[];subs=[]
    (out/'GLB').mkdir(parents=True,exist_ok=True)
    for tier,(name,r) in enumerate(zip(NAMES,RADII),1):
        core.build(tier,r);structure.build(tier,r);plumbing.build(tier,r);services.build(tier,r)
        collection=forge.commit_model(name)
        meshes=list(collection.objects)
        root=bpy.data.objects.new(name+' • ground pivot',None)
        root.empty_display_type='PLAIN_AXES';root.empty_display_size=r*.2
        collection.objects.link(root)
        for ob in meshes: ob.parent=root
        root['class']=name;root['vessel_diameter']=2*r
        bpy.context.view_layer.update()
        bpy.ops.object.select_all(action='DESELECT')
        for ob in [root]+meshes: ob.select_set(True)
        bpy.context.view_layer.objects.active=root
        bpy.ops.export_scene.gltf(filepath=str(out/'GLB'/(name+'.glb')),export_format='GLB',
            use_selection=True,export_yup=True,export_animations=False,export_cameras=False,
            export_lights=False,export_extras=True,export_materials='EXPORT')
        print('EXPORTED',name,len(meshes),sum(len(o.data.polygons) for o in meshes),flush=True)
        roots.append(root);subs.append(meshes)
    # Arrange at one physical scale. Compute horizontal extent from actual mesh silhouettes.
    offset=0.0
    for root,meshes in zip(roots,subs):
        screen_x=bounds(meshes)@np.asarray(EAST)
        root.location=EAST*(offset-screen_x.min())
        offset+=screen_x.max()-screen_x.min()+.72
    mid=(offset-.72)/2
    for root in roots: root.location-=EAST*mid
    bpy.context.view_layer.update()
    studio_scene()
    allmodels=[v for m in subs for v in m]
    setup_view(allmodels)
    for ob in bpy.context.selected_objects: ob.select_set(False)
    bpy.context.view_layer.objects.active=None
    (out/'Blender').mkdir(exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'Blender'/'Mars_Reactor_Family.blend'),compress=True)

def main():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    out=Path(args[0]).resolve() if args else HERE/'output'
    out.mkdir(exist_ok=True,parents=True)
    create(out)

if __name__=='__main__':
    main()
