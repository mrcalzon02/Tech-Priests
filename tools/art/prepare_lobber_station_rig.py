"""V15 rig PREPARATION: six independent cannon controls, unchanged rest surfaces.

Run with Blender 5.0.1 --factory-startup -b --python-exit-code 12 --python
this_file.py -- --source V14.blend --out candidate-directory
No firing, reload, hose deformation, prototype changes or visual approval implied.
"""
import argparse, collections, hashlib, json, math, sys
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--source',type=Path,required=True)
ap.add_argument('--out',type=Path,required=True)
ap.add_argument('--size',type=int,default=640)
a=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);a.out.mkdir(parents=True,exist_ok=True)
if bpy.app.version<(5,0,1):raise RuntimeError('Use Blender 5.0.1 or newer; do not downgrade the V14 master')
bpy.ops.wm.open_mainfile(filepath=str(a.source.resolve()))
S=bpy.context.scene;S.frame_set(1);bpy.context.view_layer.update()
C=bpy.data.collections['SIX_LOBBER_LOOSE_GRENADE_LOADERS']
parent=bpy.data.objects['LOBBER_ELEVATION'];plate=bpy.data.objects['ROTARY_ADAPTER']
source_hash=hashlib.sha256(a.source.read_bytes()).hexdigest()

def evaluated(o):
    return bpy.data.meshes.new_from_object(o.evaluated_get(bpy.context.evaluated_depsgraph_get()),preserve_all_data_layers=True,depsgraph=bpy.context.evaluated_depsgraph_get())
def surface(o):
    me=evaluated(o); me.calc_loop_triangles(); result=collections.Counter()
    for tri in me.loop_triangles:
        uv=me.uv_layers.active; poly=me.polygons[tri.polygon_index]
        mat=me.materials[poly.material_index].name if me.materials and me.materials[poly.material_index] else ''
        corners=[]
        for vi,li in zip(tri.vertices,tri.loops):
            p=o.matrix_world@me.vertices[vi].co
            corners.append(tuple(round(v,5) for v in p)+tuple(float(v) for v in uv.data[li].uv) if uv else tuple(round(v,5) for v in p))
        result[(tuple(sorted(corners)),mat)]+=1
    bpy.data.meshes.remove(me);return result
def original_signature(o):
    return hashlib.sha256(repr((list(map(tuple,o.matrix_world)),[(tuple(v.co)) for v in o.data.vertices],[(tuple(p.vertices),p.material_index,p.use_smooth) for p in o.data.polygons],[m.name if m else None for m in o.data.materials])).encode()).hexdigest()

targets=[bpy.data.objects[f'{prefix}_LEFT_{row}'] for row in range(1,4) for prefix in ('CAST_CANNON','ROUNDED_MUZZLE','BOTTOM_FEED_SOCKET')]
untouched={o.name:original_signature(o) for o in C.objects if o.type=='MESH' and o not in targets}
original_surface=collections.Counter()
for o in targets:original_surface.update(surface(o))
controls={}; records=[]
for row,label in enumerate(('TOP','MID','BOT'),1):
    socket=bpy.data.objects[f'BOTTOM_FEED_SOCKET_LEFT_{row}']
    for side,sign in [('L',-1),('R',1)]:
        pos=socket.matrix_world.translation.copy();pos.x=sign*abs(pos.x)
        ctrl=bpy.data.objects.new(f'RECOIL_{label}_{side}',None);C.objects.link(ctrl)
        ctrl.empty_display_type='ARROWS';ctrl.empty_display_size=.15
        ctrl.parent=parent;ctrl.matrix_world=Matrix.Translation(pos)
        ctrl['station_id']=f'{label}_{side}';ctrl['stage']='rest-pose rig preparation only'
        ctrl['recoil_axis_local']=[0,.5,-math.sqrt(.75)]
        controls[(row,side)]=ctrl

for o in targets:
    row=int(o.name.rsplit('_',1)[1]);base=o.name.rsplit('_LEFT_',1)[0]
    # Freeze the evaluated surface before splitting. Re-running the bevel on a
    # reordered half mesh perturbs the generated UVs; preserve those actual UVs.
    # Original editable modifiers remain in the unchanged V14 source.
    me=evaluated(o);me.calc_loop_triangles()
    for side,sign in [('L',-1),('R',1)]:
        polys=[]
        for tri in me.loop_triangles:
            p=me.polygons[tri.polygon_index]
            xs=[(o.matrix_world@me.vertices[v].co).x for v in tri.vertices]
            if min(xs)<-1e-6 and max(xs)>1e-6:raise RuntimeError('Cross-centre face must not be cut: '+o.name)
            if sign*sum(xs)/len(xs)>0:polys.append((tuple(tri.vertices),tuple(tri.loops),p.material_index,p.use_smooth))
        assert polys,'Missing half '+o.name+side
        ids=sorted({v for p in polys for v in p[0]});remap={v:i for i,v in enumerate(ids)}
        nm=bpy.data.meshes.new(f'{base}_{row}_{side}_independent')
        nm.from_pydata([(o.matrix_world@me.vertices[v].co)[:] for v in ids],[],[[remap[v] for v in p[0]] for p in polys]);nm.update()
        for mat in me.materials:nm.materials.append(mat)
        for old,new in zip(polys,nm.polygons):new.material_index=old[2];new.use_smooth=old[3]
        for layer in me.uv_layers:
            uv=nm.uv_layers.new(name=layer.name)
            for old,new in zip(polys,nm.polygons):
                for oldli,newli in zip(old[1],new.loop_indices):uv.data[newli].uv=layer.data[oldli].uv
        normal_matrix=o.matrix_world.to_3x3().inverted().transposed()
        nm.normals_split_custom_set([(normal_matrix@me.corner_normals[li].vector).normalized()[:] for p in polys for li in p[1]])
        new=o.copy();new.data=nm;C.objects.link(new);new.name=f'{base}_{("TOP","MID","BOT")[row-1]}_{side}'
        new.modifiers.clear()
        new.parent=controls[(row,side)];new.matrix_parent_inverse=new.parent.matrix_world.inverted();new.matrix_world=Matrix.Identity(4)
        new['source_object']=o.name;new['station_id']=new.parent['station_id']
        records.append({'source':o.name,'object':new.name,'station':new.parent['station_id'],'evaluated_triangles':len(polys)})
    bpy.data.meshes.remove(me);bpy.data.objects.remove(o,do_unlink=True)
bpy.context.view_layer.update()
after=collections.Counter()
for rec in records:after.update(surface(bpy.data.objects[rec['object']]))
if original_surface!=after:
    (a.out/'rejected-surface-diagnostic.json').write_text(json.dumps({'removed':[(str(k),v) for k,v in (original_surface-after).items()][:8],'added':[(str(k),v) for k,v in (after-original_surface).items()][:8],'before_triangles':sum(original_surface.values()),'after_triangles':sum(after.values())},indent=2))
def by_geometry(counter):
    result=collections.defaultdict(list)
    for (corners,mat),count in counter.items():
        for _ in range(count):result[(tuple(c[:3] for c in corners),mat)].append(tuple(v for c in corners for v in c[3:]))
    return result
before_g,after_g=by_geometry(original_surface),by_geometry(after)
assert before_g.keys()==after_g.keys(),'World triangle/material keys changed'
max_uv_delta=0.
for key,values in before_g.items():
    assert len(values)==len(after_g[key]),'Triangle multiplicity changed'
    for old,new in zip(sorted(values),sorted(after_g[key])):
        max_uv_delta=max(max_uv_delta,max((abs(x-y) for x,y in zip(old,new)),default=0))
# Generated modifier UVs use float32 interpolation. Compare numerical values,
# not rounded decimal bins (which can put 1e-8 drift in adjacent 1e-5 bins).
assert max_uv_delta<=1e-6,f'UV numerical drift exceeds 1e-6: {max_uv_delta}'
assert all(original_signature(bpy.data.objects[name])==sig for name,sig in untouched.items())
assert len(controls)==6 and len(records)==18
assert not any(m.type=='MIRROR' for rec in records for m in bpy.data.objects[rec['object']].modifiers)
# Check actual transform independence, then restore the exact rest pose.
before={rec['object']:bpy.data.objects[rec['object']].matrix_world.copy() for rec in records}
ctrl=controls[(1,'R')];rest=ctrl.matrix_world.copy();ctrl.location.y+=.02;bpy.context.view_layer.update()
moved=[rec['station'] for rec in records if (bpy.data.objects[rec['object']].matrix_world.translation-before[rec['object']].translation).length>1e-5]
assert moved==['TOP_R']*3,moved
ctrl.matrix_world=rest;bpy.context.view_layer.update()
assert all(max(abs(bpy.data.objects[n].matrix_world[i][j]-m[i][j]) for i in range(4) for j in range(4))<1e-6 for n,m in before.items())
S['model_completion_stage']='V15 independent recoil rig preparation; animation and loader rig incomplete'
S.render.engine='CYCLES';S.cycles.samples=12;S.cycles.use_denoising=True;S.cycles.device='CPU';S.render.threads_mode='FIXED';S.render.threads=6
S.render.resolution_x=S.render.resolution_y=a.size;S.render.resolution_percentage=100
native=a.out/'six_lobber_independent_recoil_v15.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(native.resolve()),compress=True)
cam=S.camera;source_cam=cam.matrix_world.copy();source_ortho=cam.data.ortho_scale
for name,pos,target,scale in [('front',(0,-7,3.2),(0,0,2.8),4.0),('rear',(-4,5,4.5),(0,.2,2.8),4.0),('game',(0,-7,9),(0,0,2.75),4.2)]:
    cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
    S.render.filepath=str((a.out/f'{name}.png').resolve());bpy.ops.render.render(write_still=True)
cam.matrix_world=source_cam;cam.data.ortho_scale=source_ortho
report={'stage':'rig_preparation_only','source_sha256':source_hash,'blender_version':bpy.app.version_string,
 'six_independent_controls':True,'recoil_parts':records,'unchanged_other_meshes':len(untouched),
 'rest_triangles_uv_material_multiset_preserved':True,'max_uv_float_delta':max_uv_delta,'uv_numeric_tolerance':1e-6,'world_position_precision_tiles':1e-5,'protected_triangle_count':sum(original_surface.values()),
 'top_right_transform_independence_proven':True,'animation_authored':False,'loader_hatch_belt_hose_deformation_authored':False,
 'runtime_integrated':False,'visual_acceptance':'pending actual render inspection','source_camera_retained_in_native':True,
 'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest()}
(a.out/'rig-validation.json').write_text(json.dumps(report,indent=2)+'\n')
print('V15_REST_RIG_PREPARATION_PASS',flush=True)
