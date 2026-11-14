"""Read actual USD data independently against evaluated native geometry at every exported sample."""
import bpy,pathlib,json,hashlib,numpy as np
from pxr import Usd,UsdGeom,Tf
W=pathlib.Path(__file__).parent;I=W/'a02-gltf-20261114';O=W/'a02-evaluated-usd-20261114';checkpoint=json.loads((O/'CHECKPOINT.json').read_text());assert checkpoint['status']=='FOUR_EVALUATED_USD_STATES_REQUIRE_INDEPENDENT_REIMPORT';reports=[]
def arr(collection,prop,width,dtype=np.float32):
 data=np.empty(len(collection)*width,dtype=dtype);collection.foreach_get(prop,data);return data.reshape(-1,width) if width>1 else data
for mode in ['idle','cycle','entry','settle']:
 bpy.ops.wm.open_mainfile(filepath=str(I/(mode+'-derivative.blend')));s=bpy.context.scene;sample=json.loads((I/(mode+'-sampled-source.json')).read_text());names=set(sample['objects']);objects={n:bpy.data.objects[n] for n in names};stage=Usd.Stage.Open(str(O/(mode+'.usdc')));assert stage and stage.GetTimeCodesPerSecond()==24
 def path(n):
  o=objects[n];parent=o.parent.name if o.parent and o.parent.name in names else None
  return (path(parent) if parent else '/root')+'/'+Tf.MakeValidIdentifier(n)
 mapped={};missing=[]
 for n,o in objects.items():
  prim=stage.GetPrimAtPath(path(n))
  if not prim:missing.append(n);continue
  if o.type=='MESH':
   meshes=[p for p in prim.GetChildren() if p.IsA(UsdGeom.Mesh)];assert len(meshes)==1,(mode,n,[str(p.GetPath()) for p in meshes]);mapped[n]=UsdGeom.Mesh(meshes[0])
 failures=[];max_points=max_normals=max_uv=max_world=0.;topology_failures=0;checks=0;unused_uv_max=0.
 for f in range(sample['frames']):
  s.frame_set(f+1);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();t=Usd.TimeCode(f+1)
  for n,o in objects.items():
   prim=stage.GetPrimAtPath(path(n))
   if not prim:continue
   matrix=np.asarray(UsdGeom.Xformable(prim).ComputeLocalToWorldTransform(t),dtype=float).T;err=float(np.max(np.abs(np.asarray(o.matrix_world)-matrix)));max_world=max(max_world,err)
   if err>2e-5 and len(failures)<30:failures.append({'frame':f,'object':n,'world_matrix_error':err})
   if o.type!='MESH':continue
   ev=o.evaluated_get(dg);m=ev.to_mesh(preserve_all_data_layers=True,depsgraph=dg);usd=mapped[n];points=np.asarray(usd.GetPointsAttr().Get(t));co=arr(m.vertices,'co',3);counts=arr(m.polygons,'loop_total',1,np.int32);indices=arr(m.loops,'vertex_index',1,np.int32)
   same_topology=np.array_equal(counts,np.asarray(usd.GetFaceVertexCountsAttr().Get(t))) and np.array_equal(indices,np.asarray(usd.GetFaceVertexIndicesAttr().Get(t)))
   if not same_topology:topology_failures+=1
   perr=float(np.max(np.abs(points-co))) if points.shape==co.shape else float('inf');max_points=max(max_points,perr)
   normals=np.asarray(usd.GetNormalsAttr().Get(t));expected=arr(m.corner_normals,'vector',3)
   if usd.GetNormalsInterpolation()=='vertex':normals=normals[indices]
   nerr=float(np.max(np.abs(normals-expected))) if normals.shape==expected.shape else float('inf');max_normals=max(max_normals,nerr)
   primvar=UsdGeom.PrimvarsAPI(usd.GetPrim()).GetPrimvar('st');uv=np.asarray(primvar.ComputeFlattened(t)) if primvar else np.empty((0,2));old_uv=arr(m.uv_layers.active.data,'uv',2) if m.uv_layers.active else np.empty((0,2));uerr=float(np.max(np.abs(uv-old_uv))) if uv.shape==old_uv.shape and uv.size else (0. if not old_uv.size else float('inf'))
   uses_uv=any(node.type in ['TEX_IMAGE','TEX_COORD'] for mat in o.data.materials if mat and mat.use_nodes for node in mat.node_tree.nodes)
   if uses_uv:max_uv=max(max_uv,uerr)
   else:unused_uv_max=max(unused_uv_max,uerr)
   if (perr>2e-5 or nerr>2e-5 or not same_topology or (uses_uv and uerr>2e-5)) and len(failures)<30:failures.append({'frame':f,'object':n,'points_error':perr,'normals_error':nerr,'uv_error':uerr,'uv_used':uses_uv,'topology_matches':same_topology})
   ev.to_mesh_clear();checks+=1
  if f%32==0:print('A02_USD_INDEPENDENT_FRAME',mode,f,sample['frames'],flush=True)
 report={'mode':mode,'usd_sha256':hashlib.sha256((O/(mode+'.usdc')).read_bytes()).hexdigest(),'frames':sample['frames'],'mesh_count':len(mapped),'mesh_sample_checks':checks,'missing_objects':missing,'topology_failures':topology_failures,'maximum_position_error':max_points,'maximum_corner_normal_error':max_normals,'maximum_material_used_uv_error':max_uv,'unused_uv_max_error':unused_uv_max,'maximum_world_matrix_error':max_world,'failures':failures,'status':'PASS_EVALUATED_GEOMETRY_NORMALS_UV_TOPOLOGY_AND_TRANSFORMS' if not missing and not failures else 'FAILED_REPAIR_REQUIRED'}
 (O/(mode+'-independent-data-verification.json')).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n');reports.append(report);print(json.dumps({k:v for k,v in report.items() if k!='failures'}),flush=True)
summary={'status':'PASS_ALL_FOUR_EVALUATED_USD_STATES' if all(r['status'].startswith('PASS') for r in reports) else 'FAILED_EVALUATED_USD_STUDY_REQUIRES_REPAIR','modes':reports,'source_sha256':checkpoint['source_sha256'],'scope':'Actual USD point arrays, topology, face-varying normals, material-used UVs and world transforms compared with evaluated native .blend at every sample. Original volume smoke/capture rig and flash lights remain in editable source and sprite passes; not claimed as core geometry interchange.'};(O/'independent-data-summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8',newline='\n')
if not summary['status'].startswith('PASS'):raise RuntimeError('USD study failed, retain checkpoint and repair without promoting')
