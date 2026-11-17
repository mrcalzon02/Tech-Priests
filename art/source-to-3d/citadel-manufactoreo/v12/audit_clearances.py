"""Inventory real triangle intersections; retain every pair for manual joint adjudication.

All fixed mesh pairs are checked once. Every mesh with an animated ancestor is
checked against the complete assembly at each authored frame, with AABB pruning.
No name-based collision exclusions are applied to the raw report.
"""
import bpy,json,sys,time,struct,hashlib,math
from pathlib import Path
from mathutils.bvhtree import BVHTree
P=Path(sys.argv[sys.argv.index('--')+1]);runtime='--runtime' in sys.argv
artifact=P/('citadel-v12.glb' if runtime else 'citadel-v12.blend')
if runtime:
 blob=artifact.read_bytes();length,kind=struct.unpack_from('<II',blob,12);gltf=json.loads(blob[20:20+length]);first=min(gltf['accessors'][s['input']]['min'][0] for a in gltf['animations'] for s in a['samplers'])
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=48;bpy.ops.import_scene.gltf(filepath=str(artifact))
else:bpy.ops.wm.open_mainfile(filepath=str(artifact))
scene=bpy.context.scene
def frame(f):
 t=(first+(f-1)/48)*48 if runtime else f
 scene.frame_set(math.floor(t),subframe=t-math.floor(t));bpy.context.view_layer.update()
frame(1)
objects=[o for o in scene.objects if o.type=='MESH']
def animated(o):
 while o:
  if o.animation_data and o.animation_data.action:return True
  o=o.parent
 return False
moving={o.name for o in objects if animated(o)}
def owner(o):
 while o:
  if o.animation_data and o.animation_data.action:return o.name
  o=o.parent
 return None
owners={o.name:owner(o) for o in objects}
def geo(o):
 ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get());m=ev.to_mesh();m.calc_loop_triangles()
 points=[ev.matrix_world@v.co for v in m.vertices];tri=[tuple(t.vertices) for t in m.loop_triangles]
 lo=[min(p[a] for p in points) for a in range(3)];hi=[max(p[a] for p in points) for a in range(3)]
 tree=BVHTree.FromPolygons(points,tri,all_triangles=True,epsilon=0);ev.to_mesh_clear()
 return lo,hi,tree
fixed={o.name:geo(o) for o in objects if o.name not in moving}
pairs={};start=time.time()
def check(a,b,ga,gb,frame):
 if any(min(ga[1][k],gb[1][k])-max(ga[0][k],gb[0][k])<1e-5 for k in range(3)):return
 hits=ga[2].overlap(gb[2])
 if not hits:return
 key=' <> '.join(sorted((a,b)))
 if key not in pairs:pairs[key]={'first_frame':frame,'last_frame':frame,'frames':0,'maximum_triangle_intersections':0,'moving':a in moving or b in moving}
 r=pairs[key];r['last_frame']=frame;r['frames']+=1;r['maximum_triangle_intersections']=max(r['maximum_triangle_intersections'],len(hits))
names=list(fixed)
for i,a in enumerate(names):
 for b in names[i+1:]:check(a,b,fixed[a],fixed[b],1)
for f in ((1+i/2 for i in range(385)) if runtime else (i/2 for i in range(387))):
 frame(f);dynamic={o.name:geo(o) for o in objects if o.name in moving};names=list(dynamic)
 for a,ga in dynamic.items():
  for b,gb in fixed.items():check(a,b,ga,gb,f)
 for i,a in enumerate(names):
  for b in names[i+1:]:check(a,b,dynamic[a],dynamic[b],f)
 if f%24==1:print('CLEARANCE_FRAME',f,'pairs',len(pairs),'seconds',round(time.time()-start),flush=True)
report={'artifact':str(artifact),'sha256':hashlib.sha256(artifact.read_bytes()).hexdigest(),'sampled_poses':385 if runtime else 387,'authored_frames':193 if runtime else 194,'includes_half_frames':True,'moving_meshes':sorted(moving),'motion_owners':owners,'fixed_mesh_count':len(fixed),'pairs':pairs,'note':'Raw triangle contacts include intentional fitted joints, tooth engagement and fasteners. Every pair requires adjudication; this inventory is not a clearance pass.'}
(P/('clearance-runtime-raw.json' if runtime else 'clearance-raw.json')).write_text(json.dumps(report,indent=2)+'\n')
print('CLEARANCE_INVENTORY_COMPLETE',len(pairs),flush=True)
