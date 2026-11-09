"""Measure both ends of all actual exterior routes against their moving hosts."""
import bpy,pathlib,sys,json,hashlib
from mathutils import Vector
from mathutils.bvhtree import BVHTree
r=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();src=r/'thetazine-v04-regenerative-study.blend';m=json.loads((r/'source-manifest.json').read_text());bpy.ops.wm.open_mainfile(filepath=str(src));s=bpy.context.scene;s.frame_set(1);bpy.context.view_layer.update();joints=m['mechanical_refinement']['seated_pipe_end_joints'];inverses={j['host']:bpy.data.objects[j['host']].matrix_world.inverted() for j in joints};assert len({j['pipe'] for j in joints})==46
worst=0;bad=[];motion=[]
for f in range(66):
 s.frame_set(f);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();trees={};core=bpy.data.objects['V04 independently suspended engine core'];motion.append({'frame':f,'location':list(core.location),'rotation':list(core.rotation_quaternion)})
 for j in joints:
  name=j['pipe']
  if name not in trees:
   o=bpy.data.objects[name];ev=o.evaluated_get(dg);mesh=ev.to_mesh();trees[name]=BVHTree.FromPolygons([o.matrix_world@v.co for v in mesh.vertices],[list(p.vertices) for p in mesh.polygons]);ev.to_mesh_clear()
  expected=bpy.data.objects[j['host']].matrix_world@inverses[j['host']]@Vector(j['pipe_endpoint_inside_union']);hit=trees[name].find_nearest(expected);err=hit[3];worst=max(worst,err)
  if err>3e-5:bad.append({'frame':f,'pipe':name,'side':j['side'],'distance':err})
assert not bad,bad[:12]
assert motion[1]==dict(motion[65],frame=1),'Core wrap differs'
assert len({tuple(x['location'])+tuple(x['rotation']) for x in motion})>10
out={'status':'PASS_46_DISTINCT_PIPE_ROUTES_92_ENDS_ALL66_CORE_POSES','native_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'pose_count':66,'end_checks':66*92,'max_pipe_cap_to_host_following_union_error':worst,'core_motion':motion,'scope':'Actual evaluated pipe cap surfaces remain at the host-following captive union centers during occasional core jerks. Distinct duplicated pump/gauge route identities repaired before audit; no missing twin route inherited.'};(r/'core-seat-validation.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8',newline='\n');print(out['status'],worst)
