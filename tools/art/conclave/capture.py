"""Exact four object rotations, native fixed north, separate shadow and icon."""
import bpy,json,math,sys,hashlib
from pathlib import Path
R=Path(__file__).resolve().parents[3];O=Path(sys.argv[sys.argv.index('--asset')+1]).resolve() if '--asset' in sys.argv else R/'art/source-to-3d/conclave-center/v01';C=O/'captures';C.mkdir(exist_ok=True)
sys.path.insert(0,str(R/'tools/fmpl'));from blender_camera_guard import install_canonical_camera,assert_clean
qa=json.loads((O/'inspection.json').read_text());assert qa['passed'],'Actual source/export inspection must pass'
bpy.ops.wm.open_mainfile(filepath=str(O/('conclave-center-v02.blend' if O.name.startswith('v02') else 'conclave-center-v01.blend')));s=bpy.context.scene;root=bpy.data.objects['Conclave Center | ground origin'];profile=json.loads((O/'capture-profile.json').read_text());profile['source_size']=512;install_canonical_camera(s,profile,bpy)
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='OPTIX'
if any(d.use for d in prefs.devices):s.cycles.device='GPU'
s.cycles.samples=32;s.render.film_transparent=True
for i,a in enumerate((0,90,180,270)):
 root.rotation_euler.z=math.radians(a);s.render.filepath=str(C/f'body-d{i}.png');bpy.ops.render.render(write_still=True)
# Actual Cycles shadow catcher plane, same pixel grid and world origin.
for light in [o for o in s.objects if o.type=='LIGHT']:
 light.data.energy=0
s.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=0
sun=bpy.data.lights.new('Single game shadow sun','SUN');sun.energy=2;sun.angle=.035;light=bpy.data.objects.new('Shadow direction',sun);s.collection.objects.link(light);light.rotation_euler=(.15,-.16,-.7)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.001));plane=bpy.context.object;plane.name='Capture only shadow catcher';plane.is_shadow_catcher=True
for o in s.objects:
 if o.type=='MESH' and o!=plane:o.visible_camera=False
for i,a in enumerate((0,90,180,270)):
 root.rotation_euler.z=math.radians(a);s.render.filepath=str(C/f'shadow-d{i}.png');bpy.ops.render.render(write_still=True)
# Dedicated icon frame; one orientation under canonical item policy.
bpy.data.objects.remove(plane,do_unlink=True);bpy.data.objects.remove(light,do_unlink=True)
s.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=1
for o in s.objects:
 if o.type=='MESH':o.visible_camera=True
for o in s.objects:
 if o.type=='LIGHT':o.data.energy={'key':500,'fill':260,'rim':380}[o.name]
root.rotation_euler.z=0
icon=dict(profile);icon.update(capture_kind='item',directions=[0],states={'icon':[1]},source_size=128);install_canonical_camera(s,icon,bpy);s.render.filepath=str(C/'icon.png');bpy.ops.render.render(write_still=True)
(C/'capture.json').write_text(json.dumps(dict(source_sha256=hashlib.sha256((O/('conclave-center-v02.blend' if O.name.startswith('v02') else 'conclave-center-v01.blend')).read_bytes()).hexdigest(),entity_profile=profile,item_profile=icon,native_direction_policy='fixed north; other three views review only',shadow='Actual separate Cycles shadow catcher, canonical camera and root rotation',working_layers='Not applicable: native static container'),indent=2)+'\n')
print('CONCLAVE_REAL_CAPTURE_READY',flush=True)
