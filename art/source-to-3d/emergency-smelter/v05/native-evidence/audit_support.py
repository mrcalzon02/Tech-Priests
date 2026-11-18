"""Measure physical support paths in the reopened editable assembly.
A shared collection/parent is not evidence of attachment. Edges require real
triangle contact/intersection, <=0.1mm surface seating, or contained solid volume.
The moving hub's bearing is reviewed separately from rigid welded attachments.
"""
import bpy,json,math,hashlib,sys,time
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
A=Path(sys.argv[sys.argv.index('--')+1]);runtime='--runtime'in sys.argv;source=next(A.glob('smelter-v*.glb'if runtime else'smelter-v*.blend'));
if runtime:bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(source));bpy.context.scene.frame_set(0)
else:bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.scene.frame_set(1)
dg=bpy.context.evaluated_depsgraph_get();tol=.0001
objs=[o for o in bpy.context.scene.objects if o.type=='MESH'];data={}
for o in objs:
 ev=o.evaluated_get(dg);m=ev.to_mesh();m.calc_loop_triangles();v=[ev.matrix_world@p.co for p in m.vertices];t=[tuple(q.vertices)for q in m.loop_triangles];lo=tuple(min(p[i]for p in v)for i in range(3));hi=tuple(max(p[i]for p in v)for i in range(3));data[o.name]=(v,lo,hi,BVHTree.FromPolygons(v,t,all_triangles=True,epsilon=0));ev.to_mesh_clear()
def aabb(a,b,pad=tol):return all(min(a[2][i],b[2][i])+pad>=max(a[1][i],b[1][i])for i in range(3))
def inside(p,d):
 if any(p[i]<=d[1][i]+1e-7 or p[i]>=d[2][i]-1e-7 for i in range(3)):return False
 ray=Vector((.371,.529,.763)).normalized();start=p+ray*1e-7;n=0
 for _ in range(100):
  hit,normal,index,distance=d[3].ray_cast(start,ray)
  if hit is None:return n%2==1
  n+=1;start=hit+ray*1e-6
 return False
def gap(a,b):
 best=1e9
 for p in a[0]:
  q,normal,index,dist=b[3].find_nearest(p)
  if q is not None:best=min(best,dist)
 for p in b[0]:
  q,normal,index,dist=a[3].find_nearest(p)
  if q is not None:best=min(best,dist)
 return best
edges=[];names=list(data);adj={n:set()for n in names};start=time.time()
for i,a in enumerate(names):
 da=data[a]
 for b in names[i+1:]:
  db=data[b]
  if not aabb(da,db):continue
  reason=None;dist=None
  if da[3].overlap(db[3]):reason='actual triangle intersection/contact'
  else:
   dist=gap(da,db)
   if dist<=tol:reason='measured near-surface fitted seat'
   elif inside(da[0][0],db)or inside(db[0][0],da):reason='contained solid volume contact'
  if reason:adj[a].add(b);adj[b].add(a);edges.append({'a':a,'b':b,'basis':reason,'surface_distance':dist})
 if i%250==0:print('SUPPORT_GRAPH',i,len(names),'edges',len(edges),'seconds',round(time.time()-start),flush=True)
roots=[n for n,d in data.items()if d[1][2]<=1e-4 and d[2][2]>0];connected=set(roots);todo=list(roots)
while todo:
 for n in adj[todo.pop()]-connected:connected.add(n);todo.append(n)
remaining=set(names)-connected;groups=[]
while remaining:
 n=remaining.pop();group={n};todo=[n]
 while todo:
  more=adj[todo.pop()]&remaining;remaining-=more;group|=more;todo.extend(more)
 nearest=[]
 for n in group:
  dn=data[n];best=(1e9,None)
  for target in connected:
   dt=data[target]
   if not aabb(dn,dt,.20):continue
   dist=gap(dn,dt)
   if dist<best[0]:best=(dist,target)
  nearest.append({'object':n,'nearest_founded_object':best[1],'gap':best[0]})
 groups.append({'objects':sorted(group),'nearest_founded_seats':sorted(nearest,key=lambda x:x['gap'])[:12]})
r={'artifact':source.name,'artifact_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'tolerance_tiles':tol,'root_foundation_meshes':roots,'mesh_count':len(names),'physically_connected_to_foundation':len(connected),'unattached_components':groups,'measured_edges':edges,'passed_without_manual_exclusions':not groups,'note':'Raw support graph. Volume contacts still require intended-interface review; a contact is not proof that two unrelated components should intersect. Bearings need clearance and explicit support design.'};(A/('attachment-support-runtime-raw.json'if runtime else'attachment-support-raw.json')).write_text(json.dumps(r,indent=2));print('SUPPORT_RESULT',len(names),len(connected),'UNATTACHED',len(groups),flush=True)

