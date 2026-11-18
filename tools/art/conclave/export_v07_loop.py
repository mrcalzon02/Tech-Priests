"""Re-export one synchronized ambient clip, including the matching loop endpoint."""
import bpy,sys
from pathlib import Path
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/conclave-center/v07-aged-and-ambient'
bpy.ops.wm.open_mainfile(filepath=str(O/'conclave-center-v07.blend'));s=bpy.context.scene;s.frame_end=289;s.frame_set(1)
sys.path.insert(0,str(Path(__file__).parent));from positive_flame_keys import normalize_flame_keys;normalize_flame_keys(s)
bpy.ops.wm.save_as_mainfile(filepath=str(O/'conclave-center-v07.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for ob in s.objects:
 if ob.type=='MESH':ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'conclave-center-v07.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_cameras=False,export_lights=False)
