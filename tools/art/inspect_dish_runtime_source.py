"""Independently reopen the editable dish and compare all geometry with V03."""
import bpy
import hashlib
import json
from pathlib import Path
import sys
from mathutils import Vector
prior,finished,out=map(Path,sys.argv[sys.argv.index('--')+1:])
def inspect(path):
    bpy.ops.wm.open_mainfile(filepath=str(path))
    meshes={}
    for o in bpy.context.scene.objects:
        if o.type!='MESH':continue
        meshes[o.name]={
            'vertices':hashlib.sha256(repr([tuple(v.co) for v in o.data.vertices]).encode()).hexdigest(),
            'faces':hashlib.sha256(repr([tuple(p.vertices) for p in o.data.polygons]).encode()).hexdigest(),
            'matrix':[list(row) for row in o.matrix_world],
            'uv':len(o.data.uv_layers)}
    images=[{'name':i.name,'packed':bool(i.packed_file),'size':list(i.size)} for i in bpy.data.images if i.source=='FILE' and i.users]
    return meshes,images
before,_=inspect(prior);after,images=inspect(finished)
assert before.keys()==after.keys(),(before.keys()-after.keys(),after.keys()-before.keys())
for name in before:
    for field in ('vertices','faces','matrix','uv'):assert before[name][field]==after[name][field],(name,field)
assert len(after)==33
assert all(i['packed'] and min(i['size'])>0 for i in images)
assert (bpy.data.objects['TURRET_TRAVERSE'].matrix_world.translation-Vector((0,0,1.7))).length<1e-5
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps({'status':'PASS','source_sha256':hashlib.sha256(prior.read_bytes()).hexdigest(),
    'editable_sha256':hashlib.sha256(finished.read_bytes()).hexdigest(),'meshes':33,
    'geometry_and_uvs_preserved':True,'base_included':False,'images':images,
    'emitter_animation':bool(bpy.data.materials['DISH_V04 | ceramic energized emitter'].node_tree.animation_data)},indent=2)+'\n')
print('DISH_EDITABLE_REOPEN_PASS',flush=True)
