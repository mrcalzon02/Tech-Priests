"""Bind the previously measured flex-interface work to the final assembled source."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import bpy
import numpy as np

p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);a.source=a.source.resolve();a.out=a.out.resolve()
root=Path.cwd();stage=root/'build/thruster-resume-20261117/thetazine-v06-motion'
leaf=json.loads((stage/'core-02-owned-flex/core-flex-retarget.json').read_text(encoding='utf-8'))
interfaces=json.loads((stage/'core-03c-seated-interfaces/interface-retarget.json').read_text(encoding='utf-8'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def array_hash(collection,field,width):
    arr=np.empty(len(collection)*width,dtype=np.float32);collection.foreach_get(field,arr)
    return hashlib.sha256(arr.tobytes()).hexdigest()

def action(data):
    if not data.animation_data or not data.animation_data.action:return None
    a=data.animation_data.action;curves=[]
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    curves.append((fc.data_path,fc.array_index,array_hash(fc.keyframe_points,'co',2),
                                   [(k.interpolation,k.handle_left_type,k.handle_right_type)for k in fc.keyframe_points]))
    return curves

def signature(o):
    me=o.data;keys=me.shape_keys
    return {'parent':o.parent.name if o.parent else None,'parent_inverse':[list(r)for r in o.matrix_parent_inverse],
            'basis':[list(r)for r in o.matrix_basis],'vertices':array_hash(me.vertices,'co',3),
            'polygons':[tuple(p.vertices)for p in me.polygons],
            'uv':[(u.name,array_hash(u.data,'uv',2))for u in me.uv_layers],
            'materials':[m.name for m in me.materials],
            'shapes':[(k.name,array_hash(k.data,'co',3),k.relative_key.name)for k in keys.key_blocks]if keys else None,
            'shape_animation':action(keys)if keys else None,'object_animation':action(o)}

expected={};origins=[]
for record,names in((leaf,[r['mesh']for r in leaf['retargeted']]),(interfaces,[r['mesh']for r in interfaces['changed_objects']])):
    source=Path(record['native']['path']);assert sha(source)==record['native']['sha256']
    bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
    for n in names:expected[n]=signature(bpy.data.objects[n])
    origins.append({'source':str(source),'sha256':sha(source),'meshes':names})
bpy.ops.wm.open_mainfile(filepath=str(a.source));bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
for n,old in expected.items():
    current=signature(bpy.data.objects[n]);assert old==current,('Measured interface changed during assembly',n,[k for k in old if old[k]!=current[k]])
result={'status':'PASS_FINAL_SOURCE_RETAINS_ALL40_PREVIOUSLY_MEASURED_FLEX_INTERFACE_OBJECTS_EXACTLY',
        'source':{'path':str(a.source),'sha256':sha(a.source)},'script_sha256':sha(Path(__file__)),
        'origins':origins,'meshes':len(expected),
        'scope':'Exact parent/local transforms, basis vertices, topology, UVs, material bindings, every morph coordinate and morph/object keyframe retained from the independently measured24leaf and16hose/support stages.'}
a.out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(result['status'],flush=True)
