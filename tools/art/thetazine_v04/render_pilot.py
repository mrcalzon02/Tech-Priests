import bpy,pathlib,sys,json,hashlib
from mathutils import Vector
r=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();source=r/'thetazine-v04-regenerative-study.blend';bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.render.engine='BLENDER_EEVEE'
if hasattr(s.eevee,'taa_render_samples'):s.eevee.taa_render_samples=32
basecam=(s.camera.location.copy(),s.camera.rotation_euler.copy(),s.camera.data.ortho_scale);records=[]
for name,frame,target,location,ortho in [('thrust-front',17,None,None,None),('cold-front',0,None,None,None),('screw-pumps',17,(0,.15,.9),(5,-5,6),5.8),('curved-bell-rams',17,(0,-4.4,-1.9),(5,-9,2.8),5.8)]:
 s.frame_set(frame)
 if target:s.render.resolution_x=s.render.resolution_y=800;s.camera.location=location;s.camera.rotation_euler=(Vector(target)-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=ortho
 else:s.render.resolution_x=512;s.render.resolution_y=1280;s.camera.location=basecam[0];s.camera.rotation_euler=basecam[1];s.camera.data.ortho_scale=basecam[2]
 for obj in s.objects:
  if obj.get('render_component')=='exhaust':obj.hide_render=bool(target)
 path=r/(name+'.png');s.render.filepath=str(path);bpy.ops.render.render(write_still=True);records.append({'file':path.name,'frame':frame,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(r/'pilot-render-receipt.json').write_text(json.dumps({'native_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'files':records},indent=2)+'\n',encoding='utf-8',newline='\n');print('V04_PILOTS_RENDERED',len(records))
