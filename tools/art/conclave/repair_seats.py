"""Repair first construction's measured support seats, preserving cast source."""
import bpy,json,math,sys
from pathlib import Path
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/conclave-center/v01'
bpy.ops.wm.open_mainfile(filepath=str(O/'conclave-center-v01.blend'))
# Retain first study for comparison before revising.
P=O/'first-study';P.mkdir(exist_ok=True)
import shutil
for name in ['conclave-center-v01.blend','conclave-center-v01.glb','source-front.png','contacts.json']:
 if (O/name).exists() and not (P/name).exists():shutil.copy2(O/name,P/name)
for o in bpy.context.scene.objects:
 if o.name=='Back shrine structural casting':o.location.z=.865;o.scale.z=1.52/1.47
 if 'service lid retained hinge' in o.name:
  yaw=o.rotation_euler.z;o.location.x-=math.sin(yaw)*.019;o.location.y+=math.cos(yaw)*.019
 if 'seated keyboard key' in o.name:
  row=int(o.name.split('key ')[1].split()[0]);o.location.z=.789+row*.0056;o.rotation_euler.x=.12
 if o.name.startswith('Retained anatomical skull casting'):
  i=int(o.name.rsplit(' ',1)[1]);o.location.y=.39 if i else .355
rows=json.loads((O/'contacts.json').read_text())
for x in rows:
 if x['a'].startswith('Crown cog tooth'):x['b']='Crown cog continuous rim';x['why']='tooth root seated into continuous cast rim'
(O/'contacts.json').write_text(json.dumps(rows,indent=2))
try:
 prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
 for d in prefs.devices:d.use=d.type=='OPTIX'
 if any(d.use for d in prefs.devices):bpy.context.scene.cycles.device='GPU'
except Exception:pass
bpy.ops.wm.save_as_mainfile(filepath=str(O/'conclave-center-v01.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:
 if o.type=='MESH':o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'conclave-center-v01.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
bpy.context.scene.render.filepath=str(O/'source-front.png');bpy.ops.render.render(write_still=True)
print('CONCLAVE_SEATS_REPAIRED',flush=True)
