"""Canonical retained facings, current geometry shadow and inventory icon."""
import bpy,json,math,sys
from pathlib import Path
R=Path(__file__).resolve().parents[3];O=Path(sys.argv[sys.argv.index('--asset')+1]).resolve() if '--asset' in sys.argv else R/'art/source-to-3d/conclave-center/v07-aged-and-ambient';C=O/'captures';C.mkdir(exist_ok=True);STEM='conclave-center-'+O.name.split('-')[0]
bpy.ops.wm.open_mainfile(filepath=str(O/(STEM+'.blend')));s=bpy.context.scene;s.frame_set(1);root=bpy.data.objects['Conclave Center | ground origin'];sys.path.insert(0,str(R/'tools/fmpl'));from blender_camera_guard import install_canonical_camera
profile=json.loads((O/'capture-profile.json').read_text());profile['source_size']=512;install_canonical_camera(s,profile,bpy)
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='OPTIX'
s.cycles.device='GPU';s.cycles.samples=32;energies={ob.name:ob.data.energy for ob in s.objects if ob.type=='LIGHT'}
for i,a in enumerate((0,90,180,270)):
 root.rotation_euler.z=math.radians(a);s.render.filepath=str(C/('body-d%d.png'%i));bpy.ops.render.render(write_still=True)
for ob in s.objects:
 if ob.type=='LIGHT':ob.data.energy=0
s.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=0
sun=bpy.data.lights.new('Capture only shadow sun','SUN');sun.energy=2;sun.angle=.035;lamp=bpy.data.objects.new('Capture only shadow direction',sun);s.collection.objects.link(lamp);lamp.rotation_euler=(.15,-.16,-.7)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.001));plane=bpy.context.object;plane.is_shadow_catcher=True
for ob in s.objects:
 if ob.type=='MESH' and ob!=plane:ob.visible_camera=False
for i,a in enumerate((0,90,180,270)):
 root.rotation_euler.z=math.radians(a);s.render.filepath=str(C/('shadow-d%d.png'%i));bpy.ops.render.render(write_still=True)
bpy.data.objects.remove(plane,do_unlink=True);bpy.data.objects.remove(lamp,do_unlink=True)
for ob in s.objects:
 if ob.type=='MESH':ob.visible_camera=True
 if ob.type=='LIGHT':ob.data.energy=energies[ob.name]
s.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=1;root.rotation_euler.z=0
icon=dict(profile);icon.update(capture_kind='item',directions=[0],states={'icon':[1]},source_size=128);install_canonical_camera(s,icon,bpy);s.render.filepath=str(C/'icon.png');bpy.ops.render.render(write_still=True)
print('V07_DIRECTIONAL_BODY_SHADOW_ICON_READY',flush=True)
