"""Export unchanged final source with physical hierarchy and all66 authored poses."""
import bpy,json,pathlib,hashlib,shutil,struct
R=pathlib.Path.cwd();S=R/'build/thruster-resume-20261117/thetazine-v06-motion';inp=S/'core09-physical-hierarchy';out=S/'core10-complete-pose-range';out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();pin='35c4f470ad92015b70d056086b7f6e53573f4ccabbecab6af346ab382734871e'
src=inp/'thetazine-v06-physical-hierarchy.blend';assert sha(src)==pin
source=out/'thetazine-v06-complete-motion.blend';shutil.copy2(src,source);bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene
old_range=[s.frame_start,s.frame_end];s.frame_start=0;s.frame_end=65;s.frame_set(0);bpy.context.view_layer.update()
excluded=[]
for o in s.objects:
    o.select_set(o.type in{'MESH','EMPTY'}and not o.get('render_only_volume'))
    if o.get('render_only_volume'):excluded.append(o.name)
glb=out/'thetazine-v06-complete-motion.glb'
bpy.ops.export_scene.gltf(filepath=str(glb),use_selection=True,export_format='GLB',export_apply=True,
 export_current_frame=True,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,
 export_frame_range=True,export_force_sampling=True,export_anim_slide_to_zero=False,
 export_morph=True,export_morph_animation=True,export_extras=True)
raw=glb.read_bytes();length,_=struct.unpack_from('<II',raw,12);doc=json.loads(raw[20:20+length]);names={n.get('name'):i for i,n in enumerate(doc['nodes'])}
core=names['V04 independently suspended engine core'];assert 'V04 engine structural recoil frame'in names
timing=[]
for anim in doc['animations']:
    for ch in anim['channels']:
        if ch['target']['node']==core:
            acc=doc['accessors'][anim['samplers'][ch['sampler']]['input']];assert acc['count']==66 and abs(acc['min'][0])<1e-9 and abs(acc['max'][0]-65/30)<1e-6
            timing.append({'path':ch['target']['path'],'sample_count':acc['count'],'time_min':acc['min'][0],'time_max':acc['max'][0]})
assert timing and sha(source)==pin and sha(src)==pin
report={'status':'ALL66_POSES_AND_PHYSICAL_HIERARCHY_EXPORTED_PENDING_ACTUAL66_CHECK','input_source':{'path':str(src),'sha256':pin},'native':{'path':str(source),'sha256':pin},'glb':{'path':str(glb),'sha256':sha(glb)},'script_sha256':sha(pathlib.Path(__file__)),'source_is_byte_exact_copy':True,'source_saved_scene_range':old_range,'temporary_export_range':[0,65],'fps':30,'cold_frame':0,'working_frames':[1,64],'wrap_frame':65,'actual_core_timing':timing,'physical_policy':'MESH+EMPTY; tagged render_only_volume excluded; explicit full pose range0..65 without saving source.','excluded_source_only':excluded,'actual_meshes':len(doc['meshes']),'actual_nodes':len(doc['nodes']),'actual_empty_nodes':sum('mesh'not in n for n in doc['nodes']),'animation_channels':sum(len(x['channels'])for x in doc['animations'])}
for name in('detail-manifest.json','side-actuator-motion.json'):
    j=json.loads((inp/name).read_text());j['native']=report['native'];j['glb']=report['glb'];j['complete_pose_range_export']=report;(out/name).write_text(json.dumps(j,indent=2),encoding='utf-8')
(out/'complete-pose-range-export.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print('COMPLETE_POSE_RANGE_EXPORTED',json.dumps(report),flush=True)
