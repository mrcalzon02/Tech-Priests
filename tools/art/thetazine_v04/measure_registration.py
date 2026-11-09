import bpy,pathlib,sys,json,hashlib
from mathutils import Vector,Matrix
from bpy_extras.object_utils import world_to_camera_view
r=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();source=r/'thetazine-v04-regenerative-study.blend';bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;m=json.loads((r/'source-manifest.json').read_text());scale=m['draw_registration']['scale'];shift=m['draw_registration']['shift'];A=Vector((0,-.906307787,-.422618262));records=[]
def project(p):
 v=world_to_camera_view(s,s.camera,p);return [((v.x*512-256)*scale)/32+shift[0],(((1-v.y)*1280-640)*scale)/32+shift[1]]
for frame in range(1,65):
 s.frame_set(frame);bpy.context.view_layer.update();root=bpy.data.objects.get('V04 independently suspended engine core') or bpy.data.objects['V04 engine structural recoil frame'];delta=root.matrix_world@Matrix.Translation(-Vector(root['rest_pivot']));center=bpy.data.objects['V04 native jet effect origin'].matrix_world.translation+delta.to_3x3()@A*.20;ports={}
 for name,target in [('fuel',[-2.5,-1.0625]),('oxidizer',[2.5,-1.0625])]:
  p=project(bpy.data.objects['socket_'+name].matrix_world.translation);assert max(abs(x-y) for x,y in zip(p,target))<1e-5;ports[name]=p
 volumes=[o for o in s.objects if o.get('render_only_volume')]
 if volumes:
  volume=volumes[0];lo=min(v.co.z for v in volume.data.vertices);hi=max(v.co.z for v in volume.data.vertices);join=project(volume.matrix_world@Vector((0,0,lo+(hi-lo)*.84)))
  assert join[1]>project(center)[1]+.75,('Actual volume join is not downstream of mouth',frame,join,project(center))
 else:join=project(center)
 records.append({'frame':frame,'mouth_native_tiles':project(center),'ports':ports,'light_plume_join_native_tiles':join})
mean=[sum(row['mouth_native_tiles'][i] for row in records)/64 for i in range(2)]
out={'native_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'body_registration':m['draw_registration'],'mouth_mean_native_tiles':mean,'light_plume_join_mean_native_tiles':[sum(v['light_plume_join_native_tiles'][i] for v in records)/64 for i in range(2)],'mouth_range_native_tiles':[[min(v['mouth_native_tiles'][i] for v in records),max(v['mouth_native_tiles'][i] for v in records)] for i in range(2)],'frames':records,'scope':'Actual source camera and fixed interface projection. Native shader placement remains a visual pilot and requires inspection.'}
out['light_plume_join_method']='Actual render-volume mesh local axis at84% of axial extent, transformed through carrier/core and source camera; downstream assertion every pose. Legacy V04 light-map plume join empty is unused because its original parenting captured a stale transform.'
(r/'native-jet-registration.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8',newline='\n');print('JET_REGISTRATION',mean,out['light_plume_join_mean_native_tiles'])
