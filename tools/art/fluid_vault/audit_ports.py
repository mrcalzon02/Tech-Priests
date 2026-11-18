"""Actual source/export bore clearance and two supported sprite projections."""
import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from bpy_extras.object_utils import world_to_camera_view
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/pressurized-fluid-vault/v01';meta=json.loads((O/'construction.json').read_text());cfg=json.loads((O/'contract.json').read_text());shift=cfg['registration']['shift'][1]
def audit(label):
 s=bpy.context.scene;bpy.context.view_layer.update();trees={ob.name:BVHTree.FromPolygons([ob.matrix_world@v.co for v in ob.data.vertices],[list(p.vertices) for p in ob.data.polygons]) for ob in s.objects if ob.type=='MESH'};rays=[]
 offsets=[(0,0),(.25,0),(-.25,0),(0,.25),(0,-.25),(.17,.17),(-.17,.17),(.17,-.17),(-.17,-.17)]+[(.279*math.cos(math.tau*j/16),.279*math.sin(math.tau*j/16)) for j in range(16)]
 for dx,dz in offsets:
  p=Vector((dx,-1.7,.44+dz));hits=[]
  for name,tree in trees.items():
   q,n,f,d=tree.ray_cast(p,Vector((0,1,0)),3.4)
   if q is not None:hits.append(dict(mesh=name,distance=d))
  rays.append(dict(offset=[dx,dz],hits=hits,passed=not hits))
 roots=[o for o in s.objects if o.type in ('MESH','EMPTY') and o.parent is None];root=bpy.data.objects.new('TEMP projection pose',None);s.collection.objects.link(root)
 for ob in roots:ob.parent=root
 projection=bpy.data.objects.new('TEMP square ground',None);s.collection.objects.link(projection);projection.scale.y=math.sqrt(2);root.parent=projection;poses=[]
 for direction,yaw in [(0,0),(4,270)]:
  root.rotation_euler.z=math.radians(yaw);bpy.context.view_layer.update()
  for port in meta['ports']:
   p=world_to_camera_view(s,s.camera,root.matrix_world@Vector(port['source_mouth']));actual=[(p.x-.5)*4,(.5-p.y)*4+shift];sign=port['normal'][1];expected=[0,-sign*1.5-.046875] if direction==0 else [sign*1.5,-.046875];err=max(abs(a-b) for a,b in zip(actual,expected));poses.append(dict(direction=direction,port=port['name'],actual=actual,expected=expected,error=err,passed=err<1e-5))
 # Remove only the two temporary projection parents. Never save this scene.
 for ob in roots:ob.parent=None
 bpy.data.objects.remove(root,do_unlink=True);bpy.data.objects.remove(projection,do_unlink=True)
 return dict(label=label,full_bore_rays=rays,native_projections=poses,passed=all(x['passed'] for x in rays+poses))
bpy.ops.wm.open_mainfile(filepath=str(O/'pressurized-fluid-vault-v01.blend'));source=audit('reopened packed source')
for ob in list(bpy.context.scene.objects):
 if ob.type in ('MESH','EMPTY'):bpy.data.objects.remove(ob,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(O/'pressurized-fluid-vault-v01.glb'));export=audit('independent actual GLB');h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();r=dict(passed=source['passed'] and export['passed'],source=source,export=export,source_sha256=h(O/'pressurized-fluid-vault-v01.blend'),export_sha256=h(O/'pressurized-fluid-vault-v01.glb'),limit='Twenty-five axial rays, including sixteen at radius0.279 inside the explicit0.28 bore, check every mesh for obstruction through both ports and the full vessel; geometry inspection also checks the sealed liner construction');(O/'port-audit.json').write_text(json.dumps(r,indent=2)+'\n');print('FLUID_VAULT_BORE_AND_NATIVE_PROJECTION',r['passed']);assert r['passed']
