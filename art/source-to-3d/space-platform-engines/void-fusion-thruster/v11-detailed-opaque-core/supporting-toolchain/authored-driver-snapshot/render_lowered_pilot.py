"""Early actual-export housing/bay images, explicitly not full acceptance."""
import bpy,json,pathlib,sys,hashlib
from mathutils import Vector
O=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();c=json.loads((O/'source-contract.json').read_text());bpy.ops.wm.open_mainfile(filepath=str(O/'void-fusion-v09-stage.blend'));s=bpy.context.scene
for o in list(s.objects):
    if o.type in ('MESH','EMPTY'):bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(O/'void-fusion-v09-stage.glb'))
deckmat=bpy.data.materials.new('Review only actual U bay platform');deckmat.diffuse_color=(.10,.13,.15,1)
for name,lo,hi in [('west',(-1.3,0,-.2),(-.5,4.8,0)),('east',(.5,0,-.2),(1.3,4.8,0)),('fore',(-.5,4.2,-.2),(.5,4.8,0))]:
    bpy.ops.mesh.primitive_cube_add(size=1,location=[(a+b)/2 for a,b in zip(lo,hi)]);o=bpy.context.object;o.name='REVIEW_U_BAY_'+name;o.dimensions=[b-a for a,b in zip(lo,hi)];bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(deckmat)
s.render.threads_mode='FIXED';s.render.threads=2;s.cycles.samples=20;yc=c['housing_pilot']['center_y'];receipt=[]
for name,loc,target,scale,landscape in [('lowered-bay-overview',(5,-8,11),(0,0,0),10.7,False),('housing-two-stone-detail',(1.8,yc-1.2,1.35),(0,yc,.08),1.50,False),('lowered-bay-side',(7,-.3,.45),(0,0,0),10.0,True),('lowered-bay-underside',(5,-2,-3.0),(0,.2,-.05),10.0,True)]:
    s.camera.location=loc;s.camera.rotation_euler=(Vector(target)-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=scale;s.render.resolution_x=1100 if landscape else 760;s.render.resolution_y=640 if landscape else 1100;s.render.filepath=str(O/(name+'.png'));bpy.ops.render.render(write_still=True);p=O/(name+'.png');receipt.append({'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'scope':'Actual GLB import with review-only U-shaped deck; intermediate construction view, formal source/export and endpoint checks pending.'})
(O/'early-view-receipt.json').write_text(json.dumps({'glb_sha256':c['glb_sha256'],'renders':receipt},indent=2)+'\n')
