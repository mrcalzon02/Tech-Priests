"""Diagnose actual evaluated seal topology and uncertain point containment."""
import bpy,bmesh,pathlib,json,math,collections,numpy as np,hashlib
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=pathlib.Path(__file__).parent/'pilot-32';B=R.parent/'pilot-31';src=R/'thetazine-v04-regenerative-study.blend';bpy.ops.wm.open_mainfile(filepath=str(src));records=[]
for f in range(66):
 report=json.loads((B/f'leaf-cooling-clearance-frame-{f:02}.json').read_text())
 for a in report['ambiguous_closed_solid_samples']:
  bpy.context.scene.frame_set(f);bpy.context.view_layer.update();o=bpy.data.objects[a['obstacle']];ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh();pts=[ev.matrix_world@v.co for v in me.vertices];edges=collections.defaultdict(list)
  for face in me.polygons:
   for i in range(len(face.vertices)):
    u,v=face.vertices[i],face.vertices[(i+1)%len(face.vertices)];edges[tuple(sorted((u,v)))].append((u,v))
  inconsistent=[e for e,uses in edges.items() if len(uses)==2 and uses[0]==uses[1]];bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));tmp=bpy.data.meshes.new('containment diagnostic normals');bm.to_mesh(tmp);bm.free();tmp.calc_loop_triangles();p=np.asarray(a['point'],dtype=np.float64)
  def winding(mesh):
   mesh.calc_loop_triangles();t=np.asarray([[pts[i] for i in x.vertices] for x in mesh.loop_triangles],dtype=np.float64)-p;a0,b,c=t[:,0],t[:,1],t[:,2];la=np.linalg.norm(a0,axis=1);lb=np.linalg.norm(b,axis=1);lc=np.linalg.norm(c,axis=1);num=np.einsum('ij,ij->i',a0,np.cross(b,c));den=la*lb*lc+np.einsum('ij,ij->i',a0,b)*lc+np.einsum('ij,ij->i',b,c)*la+np.einsum('ij,ij->i',c,a0)*lb;return float(np.sum(2*np.arctan2(num,den))/(4*math.pi))
  tree=BVHTree.FromPolygons(pts,[list(x.vertices) for x in me.polygons]);nearest=tree.find_nearest(Vector(a['point']));votes=[]
  for seed in range(31):
   d=Vector((math.sin(seed*2.39+.3),math.cos(seed*1.87+.7),math.sin(seed*1.19+1.1))).normalized();origin=Vector(a['point'])+d*1e-6;count=0
   for _ in range(128):
    hit=tree.ray_cast(origin,d,100)
    if hit[0] is None:break
    count+=1;origin=hit[0]+d*1e-5
   votes.append(count%2)
  records.append({'frame':f,**a,'nearest_surface_distance':nearest[3],'vertices':len(pts),'faces':len(me.polygons),'non_two_use_edges':sum(len(v)!=2 for v in edges.values()),'inconsistently_wound_edges':len(inconsistent),'original_winding':winding(me),'consistent_orientation_winding':winding(tmp),'parity_31_rays':votes});ev.to_mesh_clear();bpy.data.meshes.remove(tmp)
out={'status':'DIAGNOSED_NOT_ACCEPTANCE','native_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'records':records};(R/'seal-containment-diagnosis.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8',newline='\n');print(json.dumps(records,indent=2))
