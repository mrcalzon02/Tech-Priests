"""Independent real GLTF import, every discrete frame and STEP midpoint, one-belt pilot."""
import bpy,pathlib,json,hashlib,numpy as np,math
W=pathlib.Path(__file__).parent;O=W/'a02-belt-flipbook-pilot-20261114';state=json.loads((O/'CHECKPOINT.json').read_text());assert state['status']=='ONE_BELT_DISCRETE_GLTF_REQUIRES_INDEPENDENT_IMPORT';p=O/'belt-discrete-24fps.glb';assert hashlib.sha256(p.read_bytes()).hexdigest()==state['glb_sha256']
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.fps=24;bpy.ops.import_scene.gltf(filepath=str(p));objects=sorted([o for o in s.objects if o.type=='MESH'],key=lambda o:o.name);assert len(objects)==193,len(objects)
starts=[o.animation_data.action.frame_range[0] for o in objects if o.animation_data and o.animation_data.action];assert starts and len(set(starts))==1,starts;start=starts[0]
def sorted_triangles(corners,normals):
 # First canonicalize each triangle's corner order, then compare complete triangle records.
 order=np.lexsort((corners[:,:,2],corners[:,:,1],corners[:,:,0]),axis=1);rows=np.concatenate([np.take_along_axis(corners,order[:,:,None],axis=1),np.take_along_axis(normals,order[:,:,None],axis=1)],axis=2).reshape(-1,18)
 positions=rows[:,[0,1,2,6,7,8,12,13,14]];sort=np.lexsort(tuple(np.round(positions,5)[:,i] for i in reversed(range(9))));return rows[sort]
failures=[];maxpos=maxnorm=0.;records=[]
for frame in range(1,194):
 s.frame_set(int(start+frame-1));bpy.context.view_layer.update();active=[o for o in objects if abs(o.scale.x)>0.5];assert len(active)==1,(frame,[o.name for o in active]);o=active[0];assert o.name==f'A02_BELT_SAMPLE_{frame:03}',(frame,o.name)
 m=o.data;m.calc_loop_triangles();co=np.asarray([o.matrix_world@v.co for v in m.vertices]);indices=np.asarray([t.vertices[:] for t in m.loop_triangles]);loops=np.asarray([t.loops[:] for t in m.loop_triangles]);nm=o.matrix_world.to_3x3().inverted().transposed();normals=np.asarray([(nm@n.vector).normalized() for n in m.corner_normals]);reference=np.load(O/f'source-{frame:03}.npz');expected=sorted_triangles(reference['corners'],reference['normals']);actual=sorted_triangles(co[indices],normals[loops]);same=actual.shape==expected.shape
 pos=float(np.max(np.abs(actual[:,:9]-expected[:,:9]))) if same else float('inf');normal=float(np.max(np.abs(actual[:,9:]-expected[:,9:]))) if same else float('inf')
 # Layout is [xyz,nxyz] per corner: gather proper coordinate columns for final metrics.
 pc=[0,1,2,6,7,8,12,13,14];nc=[3,4,5,9,10,11,15,16,17]
 pos=float(np.max(np.abs(actual[:,pc]-expected[:,pc]))) if same else float('inf');normal=float(np.max(np.abs(actual[:,nc]-expected[:,nc]))) if same else float('inf');maxpos=max(maxpos,pos);maxnorm=max(maxnorm,normal)
 if not same or pos>2e-5 or normal>2e-5:failures.append({'frame':frame,'triangles_match':same,'position_error':pos,'normal_error':normal})
 if frame<193:
  s.frame_set(int(start+frame-1),subframe=.5);bpy.context.view_layer.update();visible=[x.name for x in objects if abs(x.scale.x)>0.5];assert visible==[o.name],(frame,'STEP midpoint failed',visible)
 records.append({'frame':frame,'triangles':len(m.loop_triangles),'position_error':pos,'normal_error':normal})
 if frame%24==0:print('IMPORTED_GLTF_VERIFIED',frame,flush=True)
summary={'status':'PASS_ONE_BELT_DISCRETE_GLTF_PILOT' if not failures else 'FAILED_PILOT_REQUIRES_REPAIR','glb_sha256':state['glb_sha256'],'source_sha256':state['original_source_sha256'],'source_target':state['target'],'discrete_frames_checked':193,'step_midpoints_checked':192,'imported_pose_meshes':193,'clip_start_frame':start,'max_position_error':maxpos,'max_normal_error':maxnorm,'failures':failures,'samples':records,'scope':'One topology-changing belt only. Whole-cap GLTF, signed antenna adapter, full FX, clean geometry and native integration remain open. No arbitrary continuous subframe fidelity claim.'}
(O/'independent-import-verification.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8',newline='\n');print(json.dumps({k:v for k,v in summary.items() if k!='samples'}),flush=True)
if failures:raise RuntimeError('Retain failed pilot; no promotion')
