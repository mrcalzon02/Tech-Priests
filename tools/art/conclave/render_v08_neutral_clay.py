"""Actual export geometry, neutral material and white studio lights only."""
import bpy
from pathlib import Path
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/conclave-center/v08-martian-central-emblem';bpy.ops.wm.open_mainfile(filepath=str(O/'conclave-center-v08.blend'));s=bpy.context.scene
for ob in list(s.objects):
 if ob.type in ('MESH','EMPTY'):bpy.data.objects.remove(ob,do_unlink=True)
 elif ob.type=='LIGHT' and ob.name not in ('key','fill','rim'):bpy.data.objects.remove(ob,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(O/'conclave-center-v08.glb'));mat=bpy.data.materials.new('Actual neutral clay');mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.24,.24,.24,1);bs.inputs['Roughness'].default_value=.85;s.view_layers[0].material_override=mat
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='OPTIX'
s.cycles.device='GPU';s.cycles.samples=24;s.render.filepath=str(O/'inspection/export-clay.png');bpy.ops.render.render(write_still=True)
