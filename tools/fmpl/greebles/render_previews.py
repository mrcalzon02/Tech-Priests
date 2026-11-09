#!/usr/bin/env python3
"""Blender 5.x SINGLE canonical 45-degree item preview of geometry-only candidates.

Not production sprites; no source materials or donor files are modified.
Run with blender --background --factory-startup --python render_previews.py -- --root PRIVATE_PARTS --limit 8
"""
from __future__ import annotations
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
FMPL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(FMPL))
from blender_camera_guard import install_canonical_camera, assert_clean


def args_from_blender():
    return sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []


def set_engine(scene):
    for engine in ('BLENDER_EEVEE_NEXT','BLENDER_EEVEE','CYCLES'):
        try:
            scene.render.engine=engine
            if engine=='CYCLES':scene.cycles.samples=16
            return engine
        except TypeError:
            continue
    raise RuntimeError('No supported render engine')


def setup_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    scene=bpy.context.scene
    engine=set_engine(scene)
    scene.render.resolution_x=256
    scene.render.resolution_y=256
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGBA'
    scene.render.film_transparent=True
    scene.world.color=(0.35,0.35,0.35)
    material=bpy.data.materials.new('FMPL_diagnostic_clay')
    material.diffuse_color=(0.58,0.62,0.63,1)
    material.use_nodes=True
    bsdf=material.node_tree.nodes.get('Principled BSDF')
    if bsdf:
        bsdf.inputs['Base Color'].default_value=(0.52,0.56,0.58,1)
        bsdf.inputs['Metallic'].default_value=0.18
        bsdf.inputs['Roughness'].default_value=0.63
    # Exactly one production-view icon camera; never write closeup/rear rigs.
    capture = {
        'capture_kind':'item', 'camera_policy':'fmpl.factorio45.v1',
        'directions':[0], 'states':{'icon':[0]}, 'source_size':256,
        'camera_override':{'type':'ORTHO','elevation_deg':45,'azimuth_deg':0,
                           'distance':7.0,'target':[0,0,0],'ortho_scale':2.5}
    }
    install_canonical_camera(scene, capture, bpy)
    assert_clean(scene, capture, bpy)
    for name,location,energy,size in [
        ('key',(1.0,-3.0,4.0),600,3.0),
        ('fill',(-3.0,2.0,3.0),350,4.0)]:
        light_data=bpy.data.lights.new(name,'AREA')
        light=bpy.data.objects.new(name,light_data)
        scene.collection.objects.link(light)
        light.location=location
        light.data.energy=energy
        light.data.shape='DISK'
        light.data.size=size
    return scene,material,engine


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--root',required=True)
    p.add_argument('--offset',type=int,default=0)
    p.add_argument('--limit',type=int,default=8)
    p.add_argument('--overwrite',action='store_true')
    a=p.parse_args(args_from_blender())
    if a.offset<0 or not 1<=a.limit<=32:
        p.error('Bounded preview batches only')
    root=Path(a.root).resolve()
    receipts=sorted(root.glob('parts/*/receipt.json'),key=lambda p:p.parent.name)
    chosen=receipts[a.offset:a.offset+a.limit]
    scene,clay,engine=setup_scene()
    previews=root/'previews'
    previews.mkdir(parents=True,exist_ok=True)
    for receipt_path in chosen:
        data=json.loads(receipt_path.read_text(encoding='utf-8'))
        if data.get('status')!='extracted-candidate':continue
        blend=receipt_path.parent/(data['id']+'.blend')
        with bpy.data.libraries.load(str(blend),link=False) as (source,dest):
            if data['source_object'] not in source.objects:
                raise RuntimeError('Preview source does not contain indexed object')
            dest.objects=[data['source_object']]
        obj=dest.objects[0]
        if obj is None or obj.type!='MESH':
            raise RuntimeError('Unrecognized extracted mesh')
        scene.collection.objects.link(obj)
        # Diagnostic viewport normalization only; source .blend stays unchanged.
        obj.data=obj.data.copy()
        obj.data.materials.clear()
        obj.data.materials.append(clay)
        obj.matrix_world.identity()
        corners=[Vector(p) for p in obj.bound_box]
        mins=[min(x[i] for x in corners) for i in range(3)]
        maxs=[max(x[i] for x in corners) for i in range(3)]
        size=max(maxs[i]-mins[i] for i in range(3))
        if size<=1e-8:
            bpy.data.objects.remove(obj,do_unlink=True)
            continue
        obj.scale=(1.5/size,)*3
        mid=[(mins[i]+maxs[i])*0.5 for i in range(3)]
        obj.location=tuple(-mid[i]*obj.scale[i] for i in range(3))
        obj.rotation_mode='XYZ'
        png=previews/(data['id']+'_icon.png')
        if not png.exists() or a.overwrite:
            obj.rotation_euler[2]=0.0
            assert_clean(scene, capture, bpy)
            scene.render.filepath=str(png)
            bpy.ops.render.render(write_still=True)
            print('FMPL_GREEBLE_SINGLE_ICON_PREVIEW',str(png),flush=True)
        bpy.data.objects.remove(obj,do_unlink=True)
    print('FMPL_PREVIEW_BATCH_COMPLETE',json.dumps({'parts':len(chosen),'engine':engine}),flush=True)

if __name__=='__main__':main()
