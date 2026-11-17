import bpy,json,sys,tempfile,hashlib,shutil
from pathlib import Path
O=Path(__file__).resolve().parent;tempfile.tempdir=str(O/'export-temp');bpy.ops.wm.open_mainfile(filepath=str(O/'sterling-v10.blend'));s=bpy.context.scene;assert s.frame_start==1 and s.frame_end==97;root=bpy.data.objects['EXPORT | Sterling actual boiler'];bpy.ops.object.select_all(action='DESELECT')
for o in [root,*root.children_recursive]:o.select_set(True)
(O/'studies').mkdir(exist_ok=True);shutil.copy2(O/'sterling-v10.glb',O/'studies/pre-normalized-working-clip.glb')
bpy.ops.export_scene.gltf(filepath=str(O/'sterling-v10.glb'),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_force_sampling=True,export_frame_range=True,export_anim_slide_to_zero=True,export_apply=True)
p=O/'construction.json';d=json.loads(p.read_text());d['runtime_sha256']=hashlib.sha256((O/'sterling-v10.glb').read_bytes()).hexdigest();d['working_loop_source_frames']=[1,97];d['source_idle_frame']=0;d['export_animation_starts_at_zero']=True;p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8');print('STERLING_WORK_LOOP_EXPORT_NORMALIZED',d['runtime_sha256'],flush=True)
