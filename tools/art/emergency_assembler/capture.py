"""Capture the exact supplied animation with a fixed FMPL production camera.

Capture-only parenting rotates complete mechanisms. The archived V07 is untouched.
"""
import argparse, bpy, hashlib, json, math, sys, time
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/emergency-assembler/v07'
ap=argparse.ArgumentParser();ap.add_argument('--review',action='store_true');ap.add_argument('--directions',default='0,1,2,3');ap.add_argument('--frames');ap.add_argument('--size',type=int,default=256);ap.add_argument('--samples',type=int,default=16)
a=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
SRC=O/'tech_priests_emergency_assembler_v07_animated.blend'
bpy.ops.wm.open_mainfile(filepath=str(SRC));s=bpy.context.scene
sys.path.insert(0,str(R/'tools/fmpl'));from blender_camera_guard import install_canonical_camera,camera_record
profile=dict(camera_policy='fmpl.factorio45.v1',capture_kind='entity',orientation_policy='rotatable',directions=[0,90,180,270],source_size=a.size,states={'idle':[0],'working':list(range(0,288,2))},camera_override=dict(type='ORTHO',elevation_deg=45,azimuth_deg=0,distance=4,target=[-.01,-.105,.30],ortho_scale=1.50,shift_x=0,shift_y=0))
install_canonical_camera(s,profile,bpy)
s.render.engine='CYCLES';s.cycles.samples=a.samples;s.cycles.use_denoising=True
try:
 prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
 for d in prefs.devices:d.use=d.type=='OPTIX'
 s.cycles.device='GPU'
except Exception:s.cycles.device='CPU'
s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.image_settings.color_depth='8';s.render.resolution_percentage=100
# The original FX are planar sprites. Keep their facing tied to the capture camera.
root=bpy.data.objects.new('V07 capture-only facing',None);s.collection.objects.link(root);root.location=(-.01,-.105,0);bpy.context.view_layer.update()
for obj in list(s.objects):
 if obj!=root and not obj.parent and obj.type not in {'CAMERA','LIGHT'}:
  matrix=obj.matrix_world.copy();obj.parent=root;obj.matrix_parent_inverse=root.matrix_world.inverted();obj.matrix_world=matrix
for obj in s.objects:
 if obj.name.startswith('Cooling steam puff'):
  constraint=obj.constraints.new('COPY_ROTATION');constraint.name='Capture billboard facing';constraint.target=s.camera
# Capture a real moving ground shadow in the same transparent frame.
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,0));catcher=bpy.context.object;catcher.name='V07 capture-only ground shadow';catcher.is_shadow_catcher=True
out=O/('review-final' if a.review else 'captures');out.mkdir(exist_ok=True)
frames=[0,48,84,132,180,240,286] if a.review else list(range(0,288,2))
if a.frames:frames=list(map(int,a.frames.split(',')))
records=[]
for direction in map(int,a.directions.split(',')):
 root.rotation_euler.z=-direction*math.pi/2
 for frame in frames:
  path=out/f'd{direction}-f{frame:03d}.png'
  if path.exists():continue
  s.frame_set(frame);s.render.filepath=str(path);start=time.monotonic();bpy.ops.render.render(write_still=True)
  records.append(dict(direction=direction,frame=frame,file=path.name,seconds=time.monotonic()-start))
  print('V07_FRAME',direction,frame,round(time.monotonic()-start,3),flush=True)
receipt=dict(source_sha256=hashlib.sha256(SRC.read_bytes()).hexdigest(),profile=profile,render_settings=dict(engine=s.render.engine,samples=a.samples,device=s.cycles.device,denoising=s.cycles.use_denoising),camera=camera_record(s),records=records,renderer_only_changes=['Complete-model facing parent around foundation center (-.01,-.105,0)','Steam billboard facing constrained to capture camera','Real per-frame Cycles ground shadow catcher'],source_geometry_changed=False)
(out/('receipt-'+a.directions.replace(',','-')+'.json')).write_text(json.dumps(receipt,indent=2)+'\n')
print('V07_CAPTURE_COMPLETE',len(records))
