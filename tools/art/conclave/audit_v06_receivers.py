"""Measure mating axes, seating and bores on actual reopened source and GLB."""
import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/conclave-center/v06-receiving-bulkheads';data=json.loads((O/'receiving-interfaces.json').read_text())
def vertices(ob):
 unique={tuple(round(c,7) for c in ob.matrix_world@v.co) for v in ob.data.vertices};return [Vector(p) for p in unique]
def tree(ob):return BVHTree.FromPolygons([ob.matrix_world@v.co for v in ob.data.vertices],[list(f.vertices) for f in ob.data.polygons])
def axis_measure(name,q,n):
 points=vertices(bpy.data.objects[name]);t=[(p-q).dot(n) for p in points];lo,hi=min(t),max(t);ends=[]
 for value in (lo,hi):
  ring=[p for p,s in zip(points,t) if abs(s-value)<3e-6];center=sum(ring,Vector((0,0,0)))/len(ring);ends.append((center,len(ring)))
 axis=(ends[1][0]-ends[0][0]).normalized();radial=[((p-q)-n*((p-q).dot(n))).length for p in points]
 return dict(t_min=lo,t_max=hi,axis_error_radians=axis.angle(n),maximum_axis_center_error=max(((c-q)-n*((c-q).dot(n))).length for c,count in ends),end_plane_vertex_counts=[count for c,count in ends],inner_radius=min(radial),outer_radius=max(radial))
def run(stage):
 bpy.context.view_layer.update();results=[];endpoints=[];cache={}
 for rec in data['receivers']:
  q,n=Vector(rec['q']),Vector(rec['normal']);u=n.orthogonal().normalized();v=n.cross(u).normalized();flange=axis_measure(rec['flange'],q,n);neck=axis_measure(rec['neck'],q,n);nose=axis_measure(rec['nose'],q,n);parent=bpy.data.objects[rec['host']];bvh=cache.setdefault(parent.name,tree(parent));samples=[]
  for angle in (0,math.pi/2,math.pi,math.pi*1.5):
   r=(rec['receiving_inner_radius']+rec['flange_radius'])/2;p=q+(u*math.cos(angle)+v*math.sin(angle))*r;co,normal,face,dist=bvh.find_nearest(p);samples.append(dict(distance=dist,normal_alignment=normal.dot(n)))
  bore=[]
  for angle in (0,math.pi/2,math.pi,math.pi*1.5):
   offset=(u*math.cos(angle)+v*math.sin(angle))*rec['receiving_inner_radius']*.5;start=q+offset+n*(rec['receiver_neck_end']+.002);length=rec['receiver_neck_end']+.009
   for obname in (rec['host'],rec['neck']):
    surface=cache.setdefault(obname,tree(bpy.data.objects[obname]));co,normal,face,dist=surface.ray_cast(start,-n,length);bore.append(dict(mesh=obname,clear=co is None))
  clearance=neck['inner_radius']-nose['outer_radius'];overlap=min(neck['t_max'],nose['t_max'])-max(neck['t_min'],nose['t_min']);axis_ok=all(m['axis_error_radians']<1e-3 and m['maximum_axis_center_error']<2e-5 and min(m['end_plane_vertex_counts'])>=8 for m in (flange,neck,nose));seat_ok=abs(flange['t_min'])<2e-5 and all(p['distance']<.001 and p['normal_alignment']>.999 for p in samples);passed=axis_ok and seat_ok and clearance>.001 and overlap>=rec['diameter']*.35 and all(p['clear'] for p in bore)
  results.append(dict(socket=rec['index'],host=rec['host'],flange=flange,receiving_neck=neck,male_nose=nose,actual_radial_clearance=clearance,actual_axial_insertion=overlap,seat_samples=samples,bore_rays=bore,passed=passed))
 for end in data['endpoints']:
  p,n,D=Vector(end['point']),Vector(end['outward_axis']),end['route_diameter'];points=[]
  for name in end['body_parts']:
   for vertex in vertices(bpy.data.objects[name]):
    delta=vertex-p
    if abs(delta.dot(n))<3e-6 and delta.length<D*.9:points.append(vertex)
  unique={tuple(round(c,6) for c in point) for point in points};points=[Vector(point) for point in unique];center=sum(points,Vector((0,0,0)))/len(points) if points else Vector((1000,1000,1000));err=(center-p).length;endpoints.append(dict(route=end['route'],terminal=end['terminal'],socket=end['socket'],actual_end_plane_vertices=len(points),measured_center_error=err,passed=len(points)>=8 and err<2e-5))
 return dict(stage=stage,receivers=results,endpoints=endpoints,passed=all(r['passed'] for r in results+endpoints))
bpy.ops.wm.open_mainfile(filepath=str(O/'conclave-center-v06.blend'));source=run('independently reopened source')
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(O/'conclave-center-v06.glb'));export=run('actual independently imported GLB')
report=dict(passed=source['passed'] and export['passed'],source=source,export=export,source_sha256=hashlib.sha256((O/'conclave-center-v06.blend').read_bytes()).hexdigest(),export_sha256=hashlib.sha256((O/'conclave-center-v06.glb').read_bytes()).hexdigest(),scope='Actual flange back planes, parent face seating, coaxial receiving/male geometry, measured radial clearance/axial insertion, open receiver/host bore rays and every carried route end-plane centre. Blind receiving cavities are internal signal/service receptacles, not invented external Factorio interfaces.')
(O/'receiving-seat-and-axis-audit.json').write_text(json.dumps(report,indent=2)+'\n');print('CONCLAVE_ACTUAL_RECEIVING_AUDIT',report['passed'],flush=True)
if not report['passed']:
 for r in source['receivers']:
  if not r['passed']:print('FAILED_RECEIVER',r['socket'],r['host'],'seat',r['seat_samples'],'bore',sum(not p['clear'] for p in r['bore_rays']),flush=True)
 print('FAILED_SOURCE_ENDPOINTS',[r for r in source['endpoints'] if not r['passed']],flush=True);raise RuntimeError('Inspect actual receiving-interface audit')
