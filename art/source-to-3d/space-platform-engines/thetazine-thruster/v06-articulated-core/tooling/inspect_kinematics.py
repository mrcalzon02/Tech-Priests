"""Read-only mechanical anchors for the owner-authorized V06 motion change."""
import bpy,json,pathlib,hashlib,math
import numpy as np
from mathutils import Vector
ROOT=pathlib.Path.cwd()
OUT=ROOT/'build/thruster-resume-20261117/thetazine-v06-motion/inspection'
OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'build/thruster-resume-20261117/thetazine-v05-detail/candidate-06b-animation-without-guides/thetazine-v05-mechanical-detail.blend'
PIN=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
assert PIN=='f02f30ad740636d6fa7906a01c6b86af45d90cf1eb940a7c7fc627ed065a2f34'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));scene=bpy.context.scene
scene.frame_set(0);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
def simple(value):
    if isinstance(value,(str,int,float,bool)) or value is None:return value
    try:return [simple(v) for v in value]
    except TypeError:return str(value)
names=[o.name for o in scene.objects if o.name in ['V04 independently suspended engine core','V04 engine structural recoil frame'] or o.name.startswith(('Outer actuator','Source actuator helical','Actuator support clevis','Clevis fixed pin','V04 structural sliding hinge carrier rail','V04 guide-rail aft structural web','V04 guide-rail fore structural web'))]
records={}
for name in names:
    ob=bpy.data.objects[name];chain=[];p=ob.parent
    while p:chain.append(p.name);p=p.parent
    row={'type':ob.type,'parent':ob.parent.name if ob.parent else None,'parent_chain':chain,
      'rotation_mode':ob.rotation_mode,'matrix_world':[list(v) for v in ob.matrix_world],
      'matrix_parent_inverse':[list(v) for v in ob.matrix_parent_inverse],
      'location':list(ob.location),'rotation_quaternion':list(ob.rotation_quaternion),
      'rotation_euler':list(ob.rotation_euler),'scale':list(ob.scale),
      'custom_properties':{k:simple(v) for k,v in ob.items() if k!='_RNA_UI'},
      'children':[o.name for o in ob.children],
      'constraints':[{'type':c.type,'target':getattr(getattr(c,'target',None),'name',None)} for c in ob.constraints]}
    if ob.type=='MESH':
        ev=ob.evaluated_get(dg);me=ev.to_mesh();local=np.asarray([v.co[:] for v in me.vertices]);world=np.asarray([tuple(ev.matrix_world@v.co) for v in me.vertices]);center=world.mean(axis=0);_,vectors=np.linalg.eigh(np.cov((world-center).T));axis=vectors[:,-1];axis*=1 if axis@np.array([0,-math.cos(math.radians(25)),-math.sin(math.radians(25))])>=0 else -1;projection=(world-center)@axis
        row.update(local_bounds=[local.min(axis=0).tolist(),local.max(axis=0).tolist()],world_bounds=[world.min(axis=0).tolist(),world.max(axis=0).tolist()],vertex_count=len(world),principal_axis_world=axis.tolist(),principal_axis_center=center.tolist(),axial_range=[float(projection.min()),float(projection.max())],axis_extreme_points=[(center+axis*projection.min()).tolist(),(center+axis*projection.max()).tolist()])
        ev.to_mesh_clear()
    records[name]=row
result={'status':'READ_ONLY_REST_AND_SIDE_ASSEMBLY_ANCHORS','source':str(SOURCE),'source_sha256':PIN,'frame':0,'source_axis_A':[0,-math.cos(math.radians(25)),-math.sin(math.radians(25))],'objects':records}
(OUT/'rest-and-side-anchors.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==PIN
print('REST_AND_SIDE_ANCHORS_READY',len(records),flush=True)
for name in ['V04 independently suspended engine core','V04 engine structural recoil frame','Outer actuator body -1','Outer actuator body 1','Source actuator helical thread -1','Source actuator helical thread 1']:
    row=records[name];print(name,json.dumps(row),flush=True)
