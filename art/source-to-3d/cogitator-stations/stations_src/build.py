"""Build or render one of the five station studies in Blender background mode."""
from pathlib import Path
import argparse, os, sys, math, json
import bpy
import numpy as np
from mathutils import Vector, Matrix
HERE=Path(__file__).resolve().parent
FIND=[HERE.parent/'upstream/tools/fmpl',HERE.parent/'fmpl',*[(p/'tools/fmpl') for p in HERE.parents]]
LIB=next((p for p in FIND if (p/'pipette/core.py').is_file()),None)
if LIB is None:raise RuntimeError('Set the build source beside upstream/tools/fmpl, or inside the Tech-Priests checkout.')
sys.path[:0]=[str(HERE),str(LIB),str(LIB.parent)]
from chassis import build_chassis
from tower import build_tower
from fascia import build_fascia
from chains import build_chains
from proportions import fit
from blender_camera_guard import install_canonical_camera, temporary_inspection_camera
from capture_policy import POLICY_ID
LABELS={'junior':'Junior','intermediate':'Intermediate','senior':'Senior','planetary':'Planetary Magos','void':'Void'}
GROUPS=[('Cast chassis and fluid circuits',build_chassis),('Front instruments and insignia',build_fascia),
        ('Electrical gantry',build_tower),('Pinned foot chains',build_chains)]

def project_uv(ob):
    """Box seam projection in station coordinates. Preserve authored display UVs."""
    me=ob.data
    if me.uv_layers or not me.polygons:return
    verts=np.empty(len(me.vertices)*3,np.float32)
    me.vertices.foreach_get('co',verts)
    local=np.asarray(ob.matrix_world)
    v=verts.reshape((-1,3))@local[:3,:3].T+local[:3,3]
    ns=np.empty(len(me.polygons)*3,np.float32)
    me.polygons.foreach_get('normal',ns)
    n=ns.reshape((-1,3))@np.linalg.inv(local[:3,:3])
    axis=np.abs(n).argmax(axis=1)
    count=np.empty(len(me.polygons),np.int32)
    me.polygons.foreach_get('loop_total',count)
    face_axis=np.repeat(axis,count)
    ind=np.empty(len(me.loops),np.int32);me.loops.foreach_get('vertex_index',ind)
    xyz=v[ind]
    uv=np.where((face_axis==0)[:,None],xyz[:,[1,2]],np.where((face_axis==1)[:,None],xyz[:,[0,2]],xyz[:,[0,1]]))
    uv=uv/.77
    layer=me.uv_layers.new(name='Physical finish')
    layer.data.foreach_set('uv',uv.astype(np.float32).ravel())

def build(kind):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    adjustable=[]
    for title,fn in GROUPS:
        before=set(bpy.data.objects)
        fn(kind)
        collection=bpy.data.collections.new(title)
        scene.collection.children.link(collection)
        bpy.context.view_layer.update()
        for ob in sorted(set(bpy.data.objects)-before,key=lambda o:o.name):
            if fn != build_chains:adjustable.append(ob)
            for col in list(ob.users_collection):col.objects.unlink(ob)
            collection.objects.link(ob)
    bpy.context.view_layer.update()
    for ob in adjustable:fit(ob,kind)
    bpy.context.view_layer.update()
    for ob in scene.objects:
        if ob.type=='MESH':project_uv(ob)
    scene['station_rank']=LABELS[kind]
    scene['model_stage']='Editable geometry review'
    scene['fmpl_source']='mrcalzon02/Tech-Priests@707363a27a870839b962fa58a75a4002afe78900'

def studio():
    sc=bpy.context.scene
    col=bpy.data.collections.new('Review studio')
    sc.collection.children.link(col)
    target=Vector((0,0,1.48))
    def add(name,data,pos,look):
        ob=bpy.data.objects.new(name,data);col.objects.link(ob);ob.location=pos
        ob.rotation_euler=(look-ob.location).to_track_quat('-Z','Y').to_euler()
        return ob
    w=bpy.data.worlds.new('Neutral workshop skylight');w.use_nodes=True
    bg=w.node_tree.nodes.get('Background');bg.inputs[0].default_value=(.40,.44,.50,1);bg.inputs[1].default_value=.32
    sc.world=w
    for name,pos,power,wid,high,color in [
        ('Broad warm window',(-3.4,-4.2,6.4),460,3.5,4.5,(1,.86,.68)),
        ('Narrow front softbox',(3.5,-4.9,3.7),220,1.8,4.2,(.79,.88,1.)),
        ('Upper edge strip',(1.3,2.7,5.2),480,3.,2.,(1.,.88,.64)),
        ('Rear shop bounce',(-3.4,2.1,3.0),155,3.,3.,(.73,.85,1.))]:
        d=bpy.data.lights.new(name,'AREA');d.shape='RECTANGLE';d.energy=power;d.size=wid;d.size_y=high;d.color=color
        add(name,d,pos,target)
    cd=bpy.data.cameras.new('Review lens');cd.type='ORTHO'
    cam=add('Inspection camera',cd,(0,-7,3.7),target);sc.camera=cam
    sc.render.engine='CYCLES';sc.cycles.samples=22
    sc.cycles.use_denoising=False;sc.cycles.max_bounces=5
    sc.render.film_transparent=True;sc.render.image_settings.file_format='PNG';sc.render.image_settings.color_mode='RGBA'
    sc.view_settings.view_transform='AgX'
    sc.view_settings.look='AgX - Medium High Contrast'
    return cam

def pose(sc,view,draft):
    cam=sc.camera; target=Vector((0,-.05,1.59))
    width,height=620,795
    az,el,scale=(2,14,4.06) if view=='front' else (138,22,4.13)
    if view=='threequarter':az,el,scale=30,18,4.10
    if view=='chain':
        az,el,scale=24,13,1.28
        target=Vector((.857,-.837,.640));width,height=670,790
    if view=='desk':
        az,el,scale=4,13,3.19
        target=Vector((0,-.44,1.04));width,height=940,570
    cam.data.ortho_scale=scale
    a,e=math.radians(az),math.radians(el)
    cam.location=target+Vector((math.sin(a)*math.cos(e),-math.cos(a)*math.cos(e),math.sin(e)))*8
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    sc.render.resolution_x=width;sc.render.resolution_y=height
    sc.render.resolution_percentage=52 if draft else 100
    sc.cycles.samples=16 if draft else 80
    for scr in bpy.data.screens:
        for area in scr.areas:
            if area.type=='VIEW_3D':
                sp=area.spaces.active
                sp.region_3d.view_distance=6.6
                sp.region_3d.view_location=target
                sp.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
                sp.region_3d.view_perspective='ORTHO'
                sp.shading.color_type='MATERIAL';sp.shading.light='STUDIO'
                sp.overlay.show_overlays=False

def canonical(sc):
    zs=[];ys=[]
    for ob in sc.objects:
        if ob.type=='MESH':
            for corner in ob.bound_box:
                pt=ob.matrix_world@Vector(corner)
                zs.append(pt.z);ys.append(pt.y)
    center_z=(max(zs)+min(zs))/2
    center_y=(max(ys)+min(ys))/2
    cfg={'camera_policy':POLICY_ID,'capture_kind':'entity','orientation_policy':'rotatable',
         'directions':[0,90,180,270],'states':{'idle':[1]},'source_size':640,
         'camera_override':{'type':'ORTHO','elevation_deg':45,'azimuth_deg':0,
         'distance':8,'target':[0,center_y,center_z],'ortho_scale':4.25,'shift_x':0,'shift_y':0}}
    install_canonical_camera(sc,cfg,bpy)
    sc['source_camera_profile']=json.dumps(cfg)

def export_glb(stem):
    # Preserve each mechanical assembly and each chain link as a selectable node.
    bpy.ops.object.select_all(action='DESELECT')
    for ob in bpy.context.scene.objects:
        if ob.type=='MESH':ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(stem.with_suffix('.glb')),use_selection=True,
           export_format='GLB',export_apply=True,export_extras=True,
           export_animations=False,export_lights=False,export_cameras=False)
    bpy.ops.object.select_all(action='DESELECT')

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('kind',choices=LABELS)
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--stage',choices=['draft','final','render'],default='final')
    ap.add_argument('--views',nargs='*',choices=['front','threequarter','back','chain','desk'],
                    default=['front','back'], help='Inspection views. An empty list writes models only.')
    ap.add_argument('--samples',type=int,help='Override samples per pixel for review renders.')
    ap.add_argument('--denoise',action='store_true',help='Use the Cycles denoiser when supported.')
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:])
    folder=args.out.resolve();folder.mkdir(parents=True,exist_ok=True)
    stem=folder/('planetary-magos' if args.kind=='planetary' else args.kind)
    if args.stage=='render': bpy.ops.wm.open_mainfile(filepath=str(stem.with_suffix('.blend')))
    else:
        build(args.kind)
        studio()
    sc=bpy.context.scene
    pose(sc,'front',False)
    if args.stage=='final':
        canonical(sc)
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(stem.with_suffix('.blend')),compress=True)
        export_glb(stem)
    with temporary_inspection_camera(sc,bpy,'station review') as diagnostic:
        sc.camera=diagnostic
        diagnostic.data.type='ORTHO'
        for view in args.views:
            pose(sc,view,args.stage=='draft')
            if args.samples is not None:
                sc.cycles.samples=max(1,args.samples)
            sc.cycles.use_denoising=args.denoise
            sc.render.filepath=str(folder/(stem.name+'-'+view+'.png'))
            bpy.ops.render.render(write_still=True)

if __name__=='__main__':main()
