"""Measure existing route endpoints against actual named receiving meshes."""
import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/conclave-center/v05-panels-and-buttresses';bpy.ops.wm.open_mainfile(filepath=str(O/'conclave-center-v05.blend'));bpy.context.view_layer.update();rows=[]
for req in json.loads((O/'pipette-requests.json').read_text()):
 for end in ('start','end'):
  socket=req[end+'_socket'];ob=bpy.data.objects.get(socket['parent_mesh']);p=Vector(socket['xyz']);n=Vector(socket['normal']).normalized()
  if not ob:rows.append(dict(route=req['id'],terminal=end,parent=socket['parent_mesh'],missing=True));continue
  bvh=BVHTree.FromPolygons([ob.matrix_world@v.co for v in ob.data.vertices],[list(f.vertices) for f in ob.data.polygons]);co,normal,face,dist=bvh.find_nearest(p)
  rows.append(dict(route=req['id'],terminal=end,parent=ob.name,point=list(p),axis=list(n),nearest_surface=list(co),surface_normal=list(normal),distance_to_named_parent=dist,axis_vs_surface_normal_degrees=math.degrees(math.acos(max(-1,min(1,n.dot(normal))))),diameter=req['size']['outer_diameter'],explicit_receiving_socket=False))
report=dict(source_sha256=hashlib.sha256((O/'conclave-center-v05.blend').read_bytes()).hexdigest(),endpoints=rows,review='Diagnostic of existing nominal endpoints; parent AABB contact was not proof of an aligned receiving receptacle. Dedicated receiving sockets are required in the next revision.')
(O/'endpoint-seat-review.json').write_text(json.dumps(report,indent=2)+'\n');print('EXISTING_ENDPOINT_REVIEW',len(rows));
for row in rows:print(row['route'],row['terminal'],round(row.get('distance_to_named_parent',999),4),round(row.get('axis_vs_surface_normal_degrees',999),1),row['parent'])
