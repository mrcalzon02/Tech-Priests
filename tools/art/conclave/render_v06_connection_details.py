"""High-resolution actual-export views under the unchanged canonical camera."""
import bpy,json,math,sys
from pathlib import Path
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/conclave-center/v06-receiving-bulkheads';bpy.ops.wm.open_mainfile(filepath=str(O/'conclave-center-v06.blend'));s=bpy.context.scene
for ob in list(s.objects):
 if ob.type in ('MESH','EMPTY'):bpy.data.objects.remove(ob,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(O/'conclave-center-v06.glb'));roots=[ob for ob in s.objects if ob.type in ('MESH','EMPTY') and ob.parent is None];root=bpy.data.objects.new('Actual GLB connection review turntable',None);s.collection.objects.link(root)
for ob in roots:ob.parent=root
sys.path.insert(0,str(R/'tools/fmpl'));from blender_camera_guard import install_canonical_camera
profile=json.loads((O/'capture-profile.json').read_text());profile['source_size']=1536;install_canonical_camera(s,profile,bpy)
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='OPTIX'
if any(d.use for d in prefs.devices):s.cycles.device='GPU'
s.cycles.samples=48
for name,angle in [('front',0),('side',math.pi/2)]:
 root.rotation_euler.z=angle;s.render.filepath=str(O/'inspection'/('connection-review-'+name+'.png'));bpy.ops.render.render(write_still=True)
print('V06_ACTUAL_EXPORT_CONNECTION_REVIEW_RENDERED',flush=True)
