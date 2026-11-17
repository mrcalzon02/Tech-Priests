"""Baked cutaway sprite and aperture-respecting above-grade shadow."""
import bpy,json,sys,hashlib,math
from pathlib import Path
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/space-cargo-inventories/v01/basic';C=O/'captures';C.mkdir(exist_ok=True)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();audit=json.loads((O/'inspection.json').read_text());assert audit['passed'] and audit['source_sha256']==h(O/'basic-space-cargo-v01.blend')
bpy.ops.wm.open_mainfile(filepath=str(O/'basic-space-cargo-v01.blend'));s=bpy.context.scene;sys.path.insert(0,str(R/'tools/fmpl'));from blender_camera_guard import install_canonical_camera
p=json.loads((O/'capture-profile.json').read_text());p['source_size']=1024;install_canonical_camera(s,p,bpy);s.cycles.samples=48
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='OPTIX'
s.cycles.device='GPU';root=bpy.data.objects['Basic Cargo | grade origin']
for i in range(4):
 root.rotation_euler.z=-i*math.pi/2;s.render.filepath=str(C/('body-d%d.png'%i));bpy.ops.render.render(write_still=True)
root.rotation_euler.z=0
lights={o.name:o.data.energy for o in s.objects if o.type=='LIGHT'};world=s.world.node_tree.nodes.get('Background').inputs['Strength'].default_value
for o in s.objects:
 if o.type=='LIGHT':o.data.energy=0
s.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=0
hold=next(o for o in s.objects if o.get('fmpl_render_only'));hold.is_shadow_catcher=True;hold.data.materials.clear();mat=bpy.data.materials.new('Capture | aperture-cut platform catcher');mat.diffuse_color=(.5,.5,.5,1);hold.data.materials.append(mat)
for o in s.objects:
 if o.type=='MESH' and o!=hold:
  o.visible_camera=False
  if o.get('below_grade_geometry') or o.get('cargo_glass'):o.hide_render=True
data=bpy.data.lights.new('Capture shadow sun','SUN');data.energy=2;data.angle=.035;sun=bpy.data.objects.new(data.name,data);s.collection.objects.link(sun);sun.rotation_euler=(.15,-.16,-.7)
for i in range(4):
 root.rotation_euler.z=-i*math.pi/2;s.render.filepath=str(C/('shadow-d%d.png'%i));bpy.ops.render.render(write_still=True)
bpy.data.objects.remove(sun,do_unlink=True)
# Reload the saved master to avoid carrying shadow-only visibility/materials into icon.
bpy.ops.wm.open_mainfile(filepath=str(O/'basic-space-cargo-v01.blend'));s=bpy.context.scene;s.cycles.samples=64;s.cycles.device='GPU';icon=dict(p);icon.update(capture_kind='item',source_size=64,directions=[0],states={'icon':[1]});icon['camera_override']=dict(p['camera_override'],ortho_scale=6.4);install_canonical_camera(s,icon,bpy);s.render.filepath=str(C/'icon.png');bpy.ops.render.render(write_still=True)
(C/'capture.json').write_text(json.dumps(dict(source_sha256=h(O/'basic-space-cargo-v01.blend'),entity_profile=p,item_profile=icon,native_directions={str(i*4):dict(body='body-d%d.png'%i,shadow='shadow-d%d.png'%i,source_yaw=-90*i) for i in range(4)},shadow='Only above-grade hardware casts onto platform catcher with actual viewport holes; underground geometry excluded from platform shadows',working_layers='None: passive four-direction container'),indent=2)+'\n');print('BASIC_CARGO_BODY_APERTURE_SHADOW_ICON_CAPTURED')
