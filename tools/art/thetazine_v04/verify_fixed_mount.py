"""Owner's fixed-mount contract, measured over actual source poses."""
import bpy,pathlib,sys,json,hashlib
from mathutils import Vector
r=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();src=r/'thetazine-v04-regenerative-study.blend';bpy.ops.wm.open_mainfile(filepath=str(src));s=bpy.context.scene
prefixes=('V04 deep gantry','V04 raised stanchion','V04 upright','V04 triangulated','V04 overhead three-dimensional service bridge','V04 recessed bridge','V04 bridge face','V04 straight structural','V04 tank rear','V04 tank fore','Paired canister','Upper mounting beam','Lower mounting crossmember','Diagonal shoulder','Platform saddle foot','V04 anchored platform','V04 deck anchor','socket_')
names=[o.name for o in s.objects if o.name.startswith(prefixes)];assert len(names)>40
base={};maxerr=0;local={}
for f in range(66):
 s.frame_set(f);bpy.context.view_layer.update()
 for n in names:
  mat=[v for row in bpy.data.objects[n].matrix_world for v in row]
  if f==0:base[n]=mat
  err=max(abs(a-b) for a,b in zip(mat,base[n]));maxerr=max(maxerr,err);assert err<1e-7,(f,n,err)
 for n in ['V04 sliding bell containment carrier','V04 animated pump plunger -1','V04 animated pump plunger 1']:
  if n in bpy.data.objects:local.setdefault(n,[]).append(list(bpy.data.objects[n].matrix_world.translation))
assert local and all(len({tuple(x) for x in pts})>20 for pts in local.values())
o={'status':'PASS_RIGID_MOUNT_LOCAL_MECHANISM_MOTION','native_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'poses':66,'fixed_parts':names,'max_fixed_transform_error':maxerr,'local_motion_bounds':{n:[[min(p[i] for p in pts) for i in range(3)],[max(p[i] for p in pts) for i in range(3)]] for n,pts in local.items()},'scope':'Mount, frame, tanks and fixed interfaces stay rigid. Local pump/auger/carrier/petal/ram animation remains; no whole-sprite wobble.'}
(r/'fixed-mount-validation.json').write_text(json.dumps(o,indent=2)+'\n',encoding='utf-8',newline='\n');print(o['status'],len(names),maxerr)
