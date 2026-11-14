"""Add real recessed intake bores to the recovered V22C animated review scene.

Review derivative only. Cuts the rack and matching seat, adds lined recesses,
and retargets the existing mist into their mouths. Preserves cap timing,
materials, camera, foundation and output flange.
"""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

def bounds(o):
    p = [o.matrix_world @ Vector(v) for v in o.bound_box]
    return Vector([min(v[i] for v in p) for i in range(3)]), Vector([max(v[i] for v in p) for i in range(3)])

def mesh_object(name, vertices, faces, collection):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    collection.objects.link(o)
    return o

def cylinder(name, x, y, radius, low, high, collection):
    n = 64
    vs = [(x+radius*math.cos(i*math.tau/n), y+radius*math.sin(i*math.tau/n), z) for z in (low,high) for i in range(n)]
    fs = [tuple(reversed(range(n))), tuple(range(n,2*n))]
    fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh_object(name,vs,fs,collection)

def cut(o, cutter):
    bpy.context.view_layer.objects.active = o
    mod = o.modifiers.new('V23 real intake aperture','BOOLEAN')
    mod.operation='DIFFERENCE'
    mod.solver='EXACT'
    mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name)

def run(source, output):
    expected='5e28d62eb5b4250d78a7b4888d4bf031d5437b9e0a0ed52d4ff7e26d4792d247'
    if hashlib.sha256(source.read_bytes()).hexdigest()!=expected:
        raise RuntimeError('Expected recovered V22C source SHA '+expected)
    bpy.ops.wm.open_mainfile(filepath=str(source))
    s=bpy.context.scene
    s.frame_set(1)
    bpy.context.view_layer.update()
    rack=bpy.data.objects['Condenser eight-seat rack body']
    caps=[o for o in s.objects if o.name.startswith('Condenser capped canister ')]
    if len(caps)!=8: raise RuntimeError('Expected eight original caps')
    untouched={o.name:(o.matrix_world.copy(),len(o.data.vertices)) for o in s.objects if o.type=='MESH' and not o.name.startswith(('Condenser dark canister seat ','FX ONLY | inward mist ')) and o is not rack}
    collection=bpy.data.collections.new('CONDENSER V23 | REAL INLET RECESSES')
    s.collection.children.link(collection)
    dark=bpy.data.materials.new('V23 dark bore interior')
    dark.diffuse_color=(.012,.009,.006,1)
    dark.use_nodes=True
    dark.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.012,.009,.006,1)
    dark.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.88
    receipt=[]
    for cap in caps:
        suffix=cap.name.removeprefix('Condenser capped canister ')
        seat=bpy.data.objects['Condenser dark canister seat '+suffix]
        a,b=bounds(cap)
        x,y=(a.x+b.x)/2,(a.y+b.y)/2
        top=bounds(seat)[1].z
        radius=min(b.x-a.x,b.y-a.y)*.37
        low=top-.058
        cutter=cylinder('V23 temporary bore cutter',x,y,radius,low-.01,top+.04,collection)
        cut(seat,cutter)
        cut(rack,cutter)
        bpy.data.objects.remove(cutter,do_unlink=True)
        # A real cylindrical wall and annular lip, with an open centre.
        n=64
        rings=[(radius,low),(radius,top+.001),(radius+.009,top+.001),(radius+.009,top-.005)]
        vs=[(x+r*math.cos(i*math.tau/n),y+r*math.sin(i*math.tau/n),z) for r,z in rings for i in range(n)]
        fs=[(k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i) for k in range(3) for i in range(n)]
        liner=mesh_object('V23 recessed inlet liner '+suffix,vs,fs,collection)
        liner.data.materials.append(seat.data.materials[0])
        floor=cylinder('V23 recessed inlet floor '+suffix,x,y,radius,low-.003,low,collection)
        floor.data.materials.append(dark)
        # Follow the existing rack vibration without inheriting cap lift.
        for obj in (liner,floor):
            obj.parent=rack
            obj.matrix_parent_inverse=rack.matrix_world.inverted()
        receipt.append({'cap':cap.name,'center':[x,y],'radius':radius,'mouth_z':top,'floor_z':low,'seat':seat.name})
    order=json.loads(s['piston_order'])
    sys.path.insert(0,str(Path(__file__).parent))
    from condenser_v22_mist_particles import pose
    for head,name in enumerate(order):
        rec=next(r for r in receipt if r['cap']==name)
        x,y=rec['center']
        for cloud in [o for o in s.objects if o.name.startswith('FX ONLY | inward mist %02d.'%head)]:
            origin=Vector(cloud['fx_origin'])
            radial=Vector((origin.x-x,origin.y-y,0)).normalized()
            cloud['fx_destination']=[x+radial.x*rec['radius']*.30,y+radial.y*rec['radius']*.30,rec['mouth_z']-.008]
            for frame in range(1,98):
                cloud.location,cloud.scale=pose(frame,head,cloud,96)
                cloud.keyframe_insert(data_path='location',frame=frame)
                cloud.keyframe_insert(data_path='scale',frame=frame)
    s.frame_set(1)
    bpy.context.view_layer.update()
    for name,(world,count) in untouched.items():
        obj=bpy.data.objects[name]
        if len(obj.data.vertices)!=count or max(abs(obj.matrix_world[r][c]-world[r][c]) for r in range(4) for c in range(4))>1e-5:
            raise RuntimeError('Unrelated hardware changed: '+name)
    # Cast down the open centre; the first surface must be the deep floor,
    # not a painted disk or an uncut seat/rack face.
    deps=bpy.context.evaluated_depsgraph_get()
    for rec in receipt:
        x,y=rec['center']
        for name in (rec['seat'],rack.name):
            obj=bpy.data.objects[name].evaluated_get(deps)
            inv=obj.matrix_world.inverted()
            hit,loc,normal,index=obj.ray_cast(inv@Vector((x,y,rec['mouth_z']+.002)),inv.to_3x3()@Vector((0,0,-1)))
            if hit: raise RuntimeError('Inlet centre remains blocked by '+name)
    s['animation_review_revision']='V23 real inlet bore repair; artistic review pending'
    s['v23_inlets']=json.dumps(receipt)
    s['v23_source_sha256']=hashlib.sha256(source.read_bytes()).hexdigest()
    s['v23_machine_geometry_changes']='eight seat bores, rack perforations, recessed liners and floors'
    s['model_source_revision']='V23 inlet repair derived from approved V21 / recovered V22C'
    s['new_machine_geometry_count']=16
    s['source_mesh_geometry_modified_for_v23']=True
    s['owner_visual_approved']=False
    output.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output))
    output.with_suffix('.json').write_text(json.dumps({'source_sha256':s['v23_source_sha256'],'inlets':receipt,'unrelated_hardware_transform_and_vertex_count_guard':'PASS','eight_open_centres_ray_test':'PASS','production_assets_modified':False},indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--source',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
    run(a.source.resolve(),a.out.resolve())
