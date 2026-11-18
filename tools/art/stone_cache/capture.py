"""Four source directions, genuine shadow catchers and a dedicated item icon."""
import bpy,json,math,sys,hashlib
from pathlib import Path
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/martian-stone-cache/v01';C=O/'captures';C.mkdir(exist_ok=True);assert json.loads((O/'inspection.json').read_text())['passed'];assert json.loads((O/'wall-and-tie-audit.json').read_text())['passed']
for receipt in ('inspection.json','wall-and-tie-audit.json'):
 assert json.loads((O/receipt).read_text())['source_sha256']==hashlib.sha256((O/'martian-stone-cache-v01.blend').read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(O/'martian-stone-cache-v01.blend'));s=bpy.context.scene;root=bpy.data.objects['Martian Stone Cache | ground origin'];sys.path.insert(0,str(R/'tools/fmpl'));from blender_camera_guard import install_canonical_camera
profile=json.loads((O/'capture-profile.json').read_text());profile['source_size']=512;install_canonical_camera(s,profile,bpy);prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='OPTIX'
s.cycles.device='GPU';s.cycles.samples=48;lights={ob.name:ob.data.energy for ob in s.objects if ob.type=='LIGHT'};world_strength=s.world.node_tree.nodes.get('Background').inputs['Strength'].default_value
for i,a in enumerate((0,90,180,270)):
 root.rotation_euler.z=math.radians(a);s.render.filepath=str(C/('body-d%d.png'%i));bpy.ops.render.render(write_still=True)
for ob in s.objects:
 if ob.type=='LIGHT':ob.data.energy=0
s.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=0;data=bpy.data.lights.new('Capture shadow sun','SUN');data.energy=2;data.angle=.035;sun=bpy.data.objects.new('Capture shadow sun',data);s.collection.objects.link(sun);sun.rotation_euler=(.15,-.16,-.7)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.001));plane=bpy.context.object;plane.is_shadow_catcher=True
for ob in s.objects:
 if ob.type=='MESH' and ob!=plane:ob.visible_camera=False
for i,a in enumerate((0,90,180,270)):
 root.rotation_euler.z=math.radians(a);s.render.filepath=str(C/('shadow-d%d.png'%i));bpy.ops.render.render(write_still=True)
bpy.data.objects.remove(plane,do_unlink=True);bpy.data.objects.remove(sun,do_unlink=True)
for ob in s.objects:
 if ob.type=='MESH':ob.visible_camera=True
 if ob.type=='LIGHT':ob.data.energy=lights[ob.name]
s.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=world_strength;root.rotation_euler.z=0;icon=dict(profile);icon.update(capture_kind='item',directions=[0],states={'icon':[1]},source_size=64);icon['camera_override']=dict(profile['camera_override'],ortho_scale=2.3);install_canonical_camera(s,icon,bpy);s.render.filepath=str(C/'icon.png');bpy.ops.render.render(write_still=True)
(C/'capture.json').write_text(json.dumps(dict(source_sha256=hashlib.sha256((O/'martian-stone-cache-v01.blend').read_bytes()).hexdigest(),entity_profile=profile,item_profile=icon,native_facing='Fixed north, preserved. Other facings review only.',working_layers='None: static general container. Existing native circuit connector sprites/LED layers retained untouched.'),indent=2));print('CACHE_CANONICAL_BODY_SHADOW_ICON_CAPTURED')
