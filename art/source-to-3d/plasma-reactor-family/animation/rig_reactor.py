"""Build one portable FMPL-rigged reactor derivative from the approved family scene."""
import sys
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import fmpl_adapter as fmpl
import energy_rig
import thermal_rig

def make(tier,out):
    scene=bpy.context.scene
    name=fmpl.NAMES[tier-1]
    collection=bpy.data.collections[name]
    for other_name in fmpl.NAMES:
        if other_name==name: continue
        other=bpy.data.collections[other_name]
        for obj in list(other.objects): bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.collections.remove(other)
    floor=bpy.data.objects.get('Ground • photographic stage')
    if floor:bpy.data.objects.remove(floor,do_unlink=True)
    root=next(o for o in collection.objects if o.type=='EMPTY' and 'ground pivot' in o.name)
    scene.name=name+' | FMPL operating rig'
    cfg=fmpl.install(scene,tier)
    fmpl.select_direction(root,0)
    scene['reactor_power']=1.
    scene.id_properties_ui('reactor_power').update(min=0,max=1,description='0 = cold and stationary, 1 = illuminated and operating')
    scene.frame_start=1;scene.frame_end=96
    scene.render.fps=48;scene.render.fps_base=1
    energy_rig.apply(scene,collection,tier,fmpl.RADII[tier-1],root,period=96)
    thermal_rig.apply(scene,collection,tier,fmpl.RADII[tier-1],root,period=96)
    scene.frame_set(1)
    scene.render.engine='CYCLES'
    scene.cycles.samples=32;scene.cycles.use_denoising=False
    scene.cycles.film_transparent_glass=True
    scene.cycles.film_transparent_roughness=.16
    scene.cycles.transparent_max_bounces=12
    for screen in bpy.data.screens:
        for a in screen.areas:
            if a.type=='VIEW_3D':
                sp=a.spaces.active
                sp.region_3d.view_perspective='CAMERA'
                sp.region_3d.view_distance=cfg['camera_override']['ortho_scale']
                sp.region_3d.view_location=Vector(cfg['camera_override']['target'])
                sp.region_3d.view_rotation=scene.camera.rotation_euler.to_quaternion()
                sp.shading.type='MATERIAL';sp.shading.use_scene_lights=True;sp.shading.use_scene_world=True
                sp.overlay.show_overlays=False
    fmpl.audit(scene,cfg)
    bpy.data.orphans_purge(do_recursive=True)
    out.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(out/(name+'_FMPL.blend')),compress=True)
    print('RIGGED',name,flush=True)

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:]
    make(int(args[0]),Path(args[1]).resolve())
