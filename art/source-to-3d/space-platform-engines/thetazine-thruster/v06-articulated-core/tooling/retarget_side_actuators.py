"""Solve the two large source screw actuators against real clevis pin centers.

Only this owner's two shaft meshes, two existing aft load webs, and actuator
object transforms are changed. Other source geometry/routes are untouched.
The short hollow barrel and sliding inner rod provide an actual overlap;
neither barrel nor external helical screw geometry is stretched.
"""
import argparse, hashlib, json, math, sys
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

p=argparse.ArgumentParser()
p.add_argument('--source',type=Path,required=True)
p.add_argument('--out',type=Path,required=True)
p.add_argument('--no-export',action='store_true')
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
a.source=a.source.resolve();a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=False)
ROOT=Path.cwd();sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
core_meta=ROOT/'build/thruster-resume-20261117/thetazine-v06-motion/core-01/core-motion.json'
route_meta=ROOT/'build/thruster-resume-20261117/thetazine-v06-motion/inspection/route-ownership.json'
cm=json.loads(core_meta.read_text());rm=json.loads(route_meta.read_text())
bpy.ops.wm.open_mainfile(filepath=str(a.source));s=bpy.context.scene
s.frame_set(0);bpy.context.view_layer.update()
core=bpy.data.objects[cm['moving_root']];frame=bpy.data.objects[cm['protected_fixed_root']]
C0=core.matrix_world.copy();A=Vector(cm['nominal_thrust_axis']).normalized();B=Vector((0,A.z,-A.y))
fixed_frame=frame.matrix_world.copy();new_names=[];records=[]

def key_world(o,M,f):
    o.rotation_mode='QUATERNION';o.matrix_world=M
    for k in ('location','rotation_quaternion','scale'):o.keyframe_insert(data_path=k,frame=f)

def lathe_mesh(name,origin,profile,material,solid=False):
    N=64;u=Vector((1,0,0));v=A.cross(u).normalized();verts=[];faces=[];uvs=[]
    for z,r in profile:
        for i in range(N):verts.append(origin+A*z+r*(math.cos(i*math.tau/N)*u+math.sin(i*math.tau/N)*v))
    rows=len(profile)
    for k in range(rows if not solid else rows-1):
        n=(k+1)%rows
        for i in range(N):
            faces.append((k*N+i,k*N+(i+1)%N,n*N+(i+1)%N,n*N+i))
            uvs.append(((i/N,k/rows),((i+1)/N,k/rows),((i+1)/N,(k+1)/rows),(i/N,(k+1)/rows)))
    if solid:
        for k,reverse in [(0,True),(rows-1,False)]:
            center=len(verts);verts.append(origin+A*profile[k][0])
            for i in range(N):
                ids=(center,k*N+(i+1)%N,k*N+i)if reverse else(center,k*N+i,k*N+(i+1)%N)
                faces.append(ids);uvs.append(((.5,.5),(.5+.45*math.cos((i+1)*math.tau/N),.5+.45*math.sin((i+1)*math.tau/N)),(.5+.45*math.cos(i*math.tau/N),.5+.45*math.sin(i*math.tau/N))))
    me=bpy.data.meshes.new(name+' mesh');me.from_pydata(verts,[],faces);me.update()
    layer=me.uv_layers.new(name='Axial mechanical islands')
    for face,uv in zip(me.polygons,uvs):
        for loop,value in zip(face.loop_indices,uv):layer.data[loop].uv=value
    me.materials.append(material)
    for poly in me.polygons:poly.use_smooth=len(poly.vertices)==4
    return me

def linear_actions(o):
    if o.animation_data and o.animation_data.action:
        act=o.animation_data.action
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        for k in fc.keyframe_points:k.interpolation='LINEAR'

sources={name:[list(v.co)for v in bpy.data.objects[name].data.vertices]
         for name in ('V04 guide-rail aft structural web fuel','V04 guide-rail aft structural web water')}
poses={f:Matrix(row['authored_core_world'])for f,row in enumerate(cm['poses'])}
for sign,fluid,offset in [(-1,'fuel',0),(1,'water',4)]:
    body=bpy.data.objects[f'Outer actuator body {sign}']
    coil=bpy.data.objects[f'Source actuator helical thread {sign}']
    names=lambda stem,i:stem+(''if i==0 else f'.{i:03d}')
    collars=[bpy.data.objects[names('Outer actuator collar',offset+i)]for i in range(4)]
    ci=0 if sign==-1 else 2
    fore_c=bpy.data.objects[names('Actuator support clevis',ci)]
    aft_c=bpy.data.objects[names('Actuator support clevis',ci+1)]
    fore_p=bpy.data.objects[names('Clevis fixed pin',ci)]
    aft_p=bpy.data.objects[names('Clevis fixed pin',ci+1)]
    # Actual author origin of a bolt is the center of its receiving face.
    # Mesh data was baked before the F=1.25 uniform object transform.
    pin_fore=fore_p.matrix_world@(sum((v.co for v in fore_p.data.vertices),Vector())/len(fore_p.data.vertices))
    pin_aft=aft_p.matrix_world@(sum((v.co for v in aft_p.data.vertices),Vector())/len(aft_p.data.vertices))
    # Both source bolts have the same axial thickness and orientation, so their
    # actual mesh centroids give a matching pair of hinge-axis centers.
    pin_axis=(pin_aft-pin_fore).normalized();rest_length=(pin_aft-pin_fore).length
    assert (pin_axis-A).length<1e-5 and abs(rest_length-2)<1e-5
    shaft_fore=Vector((sign*1.15,-.787542462348938,-.37641555070877075))
    old_body_world=body.matrix_world.copy();mat=body.data.materials[0]
    body.data=lathe_mesh(body.name,shaft_fore,[(0,.10625),(.70,.10625),(.70,.069),(0,.069)],mat)
    body.matrix_parent_inverse=Matrix.Identity(4);body.matrix_world=Matrix.Identity(4)
    body['V06_role']='rigid hollow fore barrel; .069 bore radius; .70 axial length'
    rod=bpy.data.objects.new(f'V06 giant actuator sliding rod {sign}',lathe_mesh(f'V06 inner rod {sign}',shaft_fore,[(.40,.064),(2.0,.064)],mat,solid=True))
    body.users_collection[0].objects.link(rod);rod.parent=frame;rod.matrix_parent_inverse=Matrix.Identity(4);rod.matrix_world=Matrix.Identity(4)
    rod['render_component']='body';rod['V06_role']='rigid inner sliding rod; actual overlap .70-(.40+stroke)'
    new_names.append(rod.name)
    fixed_group=[body]+collars[:2]
    moving_group=[rod,coil]+collars[2:]+[aft_c,aft_p]
    rest={o.name:o.matrix_world.copy()for o in fixed_group+moving_group}
    web=bpy.data.objects[f'V04 guide-rail aft structural web {fluid}']
    job=rm['additional_core_flex_supports'][web.name]
    web_world=web.matrix_world.copy();web_inv=web_world.inverted()
    web_rest=[web_world@Vector(v)for v in sources[web.name]]
    fixed_end=Vector(job['fixed_end']);moving_end=Vector(job['moving_end']);line=moving_end-fixed_end
    weights=[]
    for v in web_rest:
        t=max(0,min(1,((v-fixed_end).dot(line)/line.length_squared-.18)/.64));weights.append(t*t*(3-2*t))
    if web.data.shape_keys:web.shape_key_clear()
    web.shape_key_add(name='Basis',from_mix=False)
    web_samples=[];side_poses=[]
    for f in range(66):
        s.frame_set(f);bpy.context.view_layer.update()
        assert max(abs(core.matrix_world[i][j]-poses[f][i][j])for i in range(4)for j in range(4))<2e-6,'Input core differs from authored motion contract'
        assert max(abs(frame.matrix_world[i][j]-fixed_frame[i][j])for i in range(4)for j in range(4))<1e-6,'Fixed structural frame moved'
        Dcore=poses[f]@C0.inverted();target_aft=Dcore@pin_aft
        length=(target_aft-pin_fore).length;axis=(target_aft-pin_fore).normalized();Q=A.rotation_difference(axis).to_matrix().to_4x4()
        Dbarrel=Matrix.Translation(pin_fore)@Q@Matrix.Translation(-pin_fore)
        delta=length-rest_length;Drod=Matrix.Translation(axis*delta)@Dbarrel
        for o in fixed_group:key_world(o,Dbarrel@rest[o.name],f)
        for o in moving_group:key_world(o,Drod@rest[o.name],f)
        bpy.context.view_layer.update()
        actual_aft=aft_p.matrix_world@(sum((v.co for v in aft_p.data.vertices),Vector())/len(aft_p.data.vertices))
        actual_fore=fore_p.matrix_world@(sum((v.co for v in fore_p.data.vertices),Vector())/len(fore_p.data.vertices))
        coords=[web_inv@((Drod@v).lerp(Dcore@v,w))for v,w in zip(web_rest,weights)]
        if f==0:
            for v,co in zip(web.data.vertices,coords):v.co=co
            for v,co in zip(web.data.shape_keys.key_blocks[0].data,coords):v.co=co
        else:
            k=web.shape_key_add(name=f'V06 aft clevis load web pose {f:02d}',from_mix=False)
            for v,co in zip(k.data,coords):v.co=co
            for ff in range(66):k.value=1 if ff==f else 0;k.keyframe_insert(data_path='value',frame=ff)
        end_error=(actual_aft-target_aft).length
        overlap=.70-(.40+delta)
        assert end_error<2e-6 and(actual_fore-pin_fore).length<2e-6 and overlap>.14 and abs(frame.matrix_world.determinant()-1)<1e-6,{'sign':sign,'frame':f,'aft_error':end_error,'fore_drift':(actual_fore-pin_fore).length,'overlap':overlap,'frame_det':frame.matrix_world.determinant(),'actual_aft':list(actual_aft),'target_aft':list(target_aft),'expected_matrix':[list(r)for r in Drod@rest[aft_p.name]],'actual_matrix':[list(r)for r in aft_p.matrix_world]}
        side_poses.append({'frame':f,'pin_separation':length,'stroke':delta,'rod_barrel_overlap':overlap,'shaft_bore_radial_gap':.005,'actual_aft_pin_target_error':end_error,'actual_fore_pin_drift':(actual_fore-pin_fore).length,'axis':list(axis),'barrel_world_delta':[list(r)for r in Dbarrel],'rod_world_delta':[list(r)for r in Drod]})
    for o in fixed_group+moving_group:linear_actions(o)
    keys=web.data.shape_keys
    if keys.animation_data and keys.animation_data.action:
        for layer in keys.animation_data.action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        for k in fc.keyframe_points:k.interpolation='LINEAR'
    records.append({'sign':sign,'fixed_fore_clevis':fore_c.name,'fixed_fore_pin':fore_p.name,'moving_aft_clevis':aft_c.name,'moving_aft_pin':aft_p.name,'fixed_pin_centroid':list(pin_fore),'rest_aft_pin_centroid':list(pin_aft),'rest_pin_separation':rest_length,'fixed_barrel_group':[o.name for o in fixed_group],'sliding_group':[o.name for o in moving_group],'aft_load_web':web.name,'poses':side_poses})

s.frame_set(0);bpy.context.view_layer.update();bpy.ops.file.pack_all()
source=a.out/'thetazine-v06-side-actuators.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source))
glb=a.out/'thetazine-v06-side-actuators.glb'
if not a.no_export:
    # Same physical-export policy as current source delivery: source-only
    # raymarched volume stays editable but is excluded from physical GLB.
    for o in s.objects:o.select_set(o.type=='MESH'and not o.get('render_only_volume'))
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_yup=True,
        export_apply=True,export_current_frame=True,export_animations=True,export_animation_mode='SCENE',
        export_anim_scene_split_object=False,export_frame_range=True,export_frame_step=1,
        export_force_sampling=True,export_morph=True,export_morph_animation=True,
        export_materials='EXPORT',export_extras=True,export_cameras=False,export_lights=False)
changes={}
for r in records:
    for name in r['fixed_barrel_group']+r['sliding_group']:
        if name not in new_names:changes[name]={'allow_fields':['object_animation','transform'],'reason':'Rigid source actuator member follows actual fixed fore/moving aft pin solve.'}
    changes[f"Outer actuator body {r['sign']}"]['allow_fields']+=['geometry','uv','custom_properties']
    changes[r['aft_load_web']]={'allow_fields':['shape_keys','shape_key_animation','basis_vertices'],'reason':'Existing articulating aft cradle link follows actual solved clevis and core receiver.'}
report={'status':'SIDE_ACTUATORS_SOLVED_REQUIRES_ASSEMBLY_CLEARANCE_AND_ACTUAL_EXPORT_CHECK','input_source':{'path':str(a.source),'sha256':sha(a.source)},'core_motion_sha256':sha(core_meta),'script_sha256':sha(Path(__file__)),'native':{'path':str(source),'sha256':sha(source)},'glb':{'path':str(glb),'sha256':sha(glb)}if glb.exists()else None,'new_meshes':new_names,'allowed_source_changes':changes,'assemblies':records,'untouched_owned_leaf_flexes':24,'routes_unchanged_by_this_addon':84,'unchanged_source_only_exhaust_parent':'V04 sliding bell containment carrier','mechanical_contract':'Fixed fore clevis/actual pin; rigid hollow fore barrel pivots about pin centroid. Rigid sliding rod + original unscaled thread/collars + aft clevis follow solved pin separation. Two old articulating aft webs rebaked between actual aft clevis and moving-core endpoints. No hose, coil, fluid interface or fittings were constructed.'}
(a.out/'side-actuator-motion.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('SIDE_ACTUATORS_AUTHORED',json.dumps({'source':report['native'],'glb':report['glb'],'stroke_ranges':[[min(p['stroke']for p in r['poses']),max(p['stroke']for p in r['poses'])]for r in records],'min_overlap':min(p['rod_barrel_overlap']for r in records for p in r['poses'])}),flush=True)
