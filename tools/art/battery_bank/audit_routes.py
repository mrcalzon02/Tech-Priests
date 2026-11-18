"""Independent actual-source/GLB cable clearance and native socket projection."""
import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/primitive-battery-bank/v01';meta=json.loads((O/'construction.json').read_text())
def tree(ob):return BVHTree.FromPolygons([ob.matrix_world@v.co for v in ob.data.vertices],[list(p.vertices) for p in ob.data.polygons])
def audit(label):
 bpy.context.view_layer.update();trees={ob.name:tree(ob) for ob in bpy.context.scene.objects if ob.type=='MESH'};terminals=[];routes=[]
 for rec in meta['terminals']:
  p=Vector(rec['mouth']);q,n,f,d=trees[rec['object']].find_nearest(p);screen=[p.x,-(p.y+p.z)/math.sqrt(2)+.20];err=max(abs(a-b) for a,b in zip(screen,rec['native']));terminals.append(dict(wire=rec['wire'],projection_error=err,surface_distance=d,passed=err<1e-6 and d<1e-5))
 for route in meta['routes']:
  points=[Vector(p) for p in route['request']['path']['points']];excluded=set(route['objects']+[route['start_parent'],route['end_parent']]);near=[];minimum=100;seats=[]
  for kind,i,parent in [('start',0,route['start_parent']),('end',-1,route['end_parent'])]:
   q,n,f,d=trees[parent].find_nearest(points[i]);seats.append(dict(endpoint=kind,distance=d,passed=d<.009))
  for i,p in enumerate(points):
   if (p-points[0]).length<.07 or (p-points[-1]).length<.07:continue
   for name,t in trees.items():
    if name in excluded:continue
    q,n,f,d=t.find_nearest(p);minimum=min(minimum,d)
    if d<.0115:near.append(dict(sample=i,mesh=name,distance=d))
  radii=[]
  for a,b,c in zip(points,points[1:],points[2:]):
   ab=(b-a).length;bc=(c-b).length;ac=(c-a).length;cross=(b-a).cross(c-a).length
   if cross>1e-10:radii.append(ab*bc*ac/(2*cross))
  routes.append(dict(id=route['request']['id'],seats=seats,minimum_other_surface_distance=minimum,collisions=near,minimum_bend_radius=min(radii),passed=not near and all(s['passed'] for s in seats) and min(radii)>.04))
 return dict(label=label,terminals=terminals,routes=routes,passed=all(x['passed'] for x in terminals+routes))
bpy.ops.wm.open_mainfile(filepath=str(O/'primitive-battery-bank-v01.blend'));source=audit('reopened source')
for ob in list(bpy.context.scene.objects):
 if ob.type in ('MESH','EMPTY'):bpy.data.objects.remove(ob,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(O/'primitive-battery-bank-v01.glb'));export=audit('actual GLB import');h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();d=dict(passed=source['passed'] and export['passed'],source=source,export=export,source_sha256=h(O/'primitive-battery-bank-v01.blend'),export_sha256=h(O/'primitive-battery-bank-v01.glb'),limit='Cable centerline clearance sampled against every other mesh; endpoint fitting overlaps are intentional within 0.07 units');(O/'route-audit.json').write_text(json.dumps(d,indent=2)+'\n');print('BATTERY_ROUTES_AND_NATIVE_POINTS',d['passed']);assert d['passed']
