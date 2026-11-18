"""Static ghost-safe body and real source-rendered ambient light contribution."""
import bpy,json,sys,hashlib
from pathlib import Path
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/conclave-center/v08-martian-central-emblem';C=O/'captures';G=O/'glow-frames';G.mkdir(exist_ok=True);sys.path.insert(0,str(R/'tools/fmpl'));from blender_camera_guard import install_canonical_camera
def setup(size):
 bpy.ops.wm.open_mainfile(filepath=str(O/'conclave-center-v08.blend'));s=bpy.context.scene;s.frame_set(1);profile=json.loads((O/'capture-profile.json').read_text());profile['source_size']=size;install_canonical_camera(s,profile,bpy);prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
 for d in prefs.devices:d.use=d.type=='OPTIX'
 s.cycles.device='GPU';s.cycles.samples=16;s.cycles.use_denoising=True
 return s
s=setup(512)
for ob in s.objects:
 if ob.type=='MESH' and ('animated flame' in ob.name or 'light smoke' in ob.name):ob.hide_render=True
 if ob.type=='LIGHT' and ob.name not in ('key','fill','rim'):ob.data.animation_data_clear();ob.data.energy=0
for mat in bpy.data.materials:
 if mat.use_nodes:
  mat.node_tree.animation_data_clear()
  for n in mat.node_tree.nodes:
   if n.type=='BSDF_PRINCIPLED':n.inputs['Emission Strength'].default_value=0
s.render.filepath=str(C/'placement-base.png');bpy.ops.render.render(write_still=True)
s=setup(256)
for ob in list(s.objects):
 if ob.type=='LIGHT' and ob.name in ('key','fill','rim'):bpy.data.objects.remove(ob,do_unlink=True)
 elif ob.type=='MESH' and 'light smoke' in ob.name:ob.hide_render=True
s.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=0
for i,f in enumerate(range(1,289,2)):
 s.frame_set(f);s.render.filepath=str(G/('%03d.png'%i));bpy.ops.render.render(write_still=True)
(G/'capture-source.json').write_text(json.dumps(dict(source_sha256=hashlib.sha256((O/'conclave-center-v08.blend').read_bytes()).hexdigest(),frames=144,render='Actual Cycles emission and local illumination, studio lights/world disabled, smoke excluded from emissive contribution',size=256),indent=2))
print('V08_GHOST_SAFE_BODY_AND_ACTUAL_LIGHT_PASS_READY',flush=True)
