"""Measure actual source/GLB joint axes, bores and hub/fork running clearances."""
import bpy,json,hashlib,numpy as np,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/space-cargo-inventories/v01/advanced';contract=json.loads((O/'crane-joint-contract.json').read_text());plane=contract['articulation_plane'];axis=Vector(plane['normal']);u=Vector(plane['horizontal']);v=Vector((0,0,1));points={k:Vector(plane[k]) for k in ('shoulder','elbow','tip')};results=[]
def verts(ob):return [ob.matrix_world@p.co for p in ob.data.vertices]
def tree(names):
 vs=[];fs=[]
 for name in names:
  ob=bpy.data.objects[name];offset=len(vs);vs+=verts(ob);fs += [tuple(offset+i for i in f.vertices) for f in ob.data.polygons]
 return BVHTree.FromPolygons(vs,fs,all_triangles=False)
for artifact in ('source','export'):
 if artifact=='source':bpy.ops.wm.open_mainfile(filepath=str(O/'advanced-space-cargo-v01.blend'))
 else:bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(O/'advanced-space-cargo-v01.glb'))
 bpy.context.view_layer.update();records=[]
 for j in contract['joints']:
  p=Vector(j['center']);shaft=bpy.data.objects[j['shaft']];pv=np.array([list(x) for x in verts(shaft)]);cov=np.cov(pv.T);_,e=np.linalg.eigh(cov);measured=Vector(e[:,-1]);axis_error=math.degrees(math.acos(min(1,abs(measured.dot(axis)))))
  lower=(points['elbow']-points['shoulder']).normalized();upper=(points['tip']-points['elbow']).normalized();perpendicular=max(abs(measured.dot(lower)),abs(measured.dot(upper)))
  hub_points=[x-p for x in verts(bpy.data.objects[j['hub']])];hub_axial=[x.dot(axis) for x in hub_points];hub_radius=[(x-axis*x.dot(axis)).length for x in hub_points];axial_gaps=[]
  for name in j['cheeks']:
   ds=[(x-p).dot(axis) for x in verts(bpy.data.objects[name])];axial_gaps.append(min(abs(x) for x in ds)-max(abs(x) for x in hub_axial))
  radial_gap=min(hub_radius)-max((x-p-axis*(x-p).dot(axis)).length for x in verts(shaft))
  bodies=[j['hub'],*j['cheeks'],'Advanced | large crane lower articulated boom']
  if j['label']=='shoulder':bodies += ['Advanced | large crane slewing journal','Advanced | crane slewing thrust collar 0.49']
  else:bodies += ['Advanced | large crane long overhanging jib','Advanced | crane elbow fixed fork strap -1','Advanced | crane elbow fixed fork strap 1']
  bvh=tree(bodies);hits=[]
  for radius in (0,j['shaft_radius']*.8):
   for k in range(24):
    a=k*math.tau/24;offset=(u*math.cos(a)+v*math.sin(a))*radius;start=p+offset-axis*.32;hit=bvh.ray_cast(start,axis,.64)
    if hit[0] is not None:hits.append(list(hit[0]))
  # Small articulation excursions preserve axial running gaps because every
  # revolute axis is normal to the same plane. Check actual rotated hub vertices.
  excursions=[]
  from mathutils import Matrix
  for angle in (-15,-7.5,0,7.5,15):
   rot=Matrix.Rotation(math.radians(angle),4,axis);ps=[rot@x for x in hub_points];span=max(abs(x.dot(axis)) for x in ps);gap=min(min(abs((x-p).dot(axis)) for x in verts(bpy.data.objects[n])) for n in j['cheeks'])-span;excursions.append(dict(degrees=angle,hub_to_fixed_cheek_axial_gap=gap))
  record=dict(joint=j['label'],measured_axis=list(measured),axis_error_degrees=axis_error,maximum_axis_dot_arm=perpendicular,hub_axial_span=[min(hub_axial),max(hub_axial)],hub_bore_radius=min(hub_radius),pin_radial_clearance=radial_gap,hub_to_cheek_axial_gaps=axial_gaps,through_bore_probes=48,blocked_through_bore_probes=len(hits),probe_hits=hits[:4],hub_excursions=excursions)
  record['passed']=axis_error<.01 and perpendicular<1e-5 and min(axial_gaps)>.01 and radial_gap>.007 and not hits and all(e['hub_to_fixed_cheek_axial_gap']>.01 for e in excursions);records.append(record)
 results.append(dict(artifact=artifact,joints=records,passed=all(r['passed'] for r in records)))
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();d=dict(source_sha256=h(O/'advanced-space-cargo-v01.blend'),export_sha256=h(O/'advanced-space-cargo-v01.glb'),results=results,passed=all(r['passed'] for r in results),scope='Actual transformed source and independently imported GLB geometry. Pin PCA, arm perpendicularity, measured bore/pin radii, axial hub/fork gaps and continuous bore ray probes. Hub-only ±15degree clearance study; not full crane dynamic or structural simulation.');(O/'crane-axis-audit.json').write_text(json.dumps(d,indent=2)+'\n');print('ACTUAL_CRANE_AXES_AND_BEARING_CLEARANCE',d['passed']);assert d['passed']
