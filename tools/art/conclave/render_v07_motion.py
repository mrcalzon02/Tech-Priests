"""Reopen packed master; render the actual 12-second ambient loop."""
import bpy,json,sys
from pathlib import Path
R=Path(__file__).resolve().parents[3];O=Path(sys.argv[sys.argv.index('--asset')+1]).resolve() if '--asset' in sys.argv else R/'art/source-to-3d/conclave-center/v07-aged-and-ambient';C=O/(sys.argv[sys.argv.index('--frames-dir')+1] if '--frames-dir' in sys.argv else 'motion-frames');C.mkdir(exist_ok=True);STEM='conclave-center-'+O.name.split('-')[0]
bpy.ops.wm.open_mainfile(filepath=str(O/(STEM+'.blend')));s=bpy.context.scene
sys.path.insert(0,str(R/'tools/fmpl'));from blender_camera_guard import install_canonical_camera
profile=json.loads((O/'capture-profile.json').read_text());profile['source_size']=512;install_canonical_camera(s,profile,bpy)
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='OPTIX'
s.cycles.device='GPU';s.cycles.samples=16
for i,f in enumerate(range(1,289,2)):
 s.frame_set(f);s.render.filepath=str(C/('%03d.png'%i));bpy.ops.render.render(write_still=True)
print('V07_REAL_12_SECOND_MOTION_RENDERED',flush=True)
import hashlib
(C/'capture-source.json').write_text(json.dumps(dict(source_sha256=hashlib.sha256((O/(STEM+'.blend')).read_bytes()).hexdigest(),frames=144,source_frame_step=2,source_fps=24,source_start=1),indent=2))
