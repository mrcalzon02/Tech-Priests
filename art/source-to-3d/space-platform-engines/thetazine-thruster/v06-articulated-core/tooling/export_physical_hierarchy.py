"""Export final08 byte-exact source with canonical physical EMPTY hierarchy."""
import bpy,json,pathlib,hashlib,shutil,struct
R=pathlib.Path.cwd();S=R/'build/thruster-resume-20261117/thetazine-v06-motion';inp=S/'core08-matched-collar-facets';out=S/'core09-physical-hierarchy';out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
src=inp/'thetazine-v06-matched-collar-motion.blend';pin='35c4f470ad92015b70d056086b7f6e53573f4ccabbecab6af346ab382734871e';assert sha(src)==pin
source=out/'thetazine-v06-physical-hierarchy.blend';shutil.copy2(src,source);assert sha(source)==pin
bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(0);bpy.context.view_layer.update()
excluded=[]
for o in s.objects:
    include=o.type in{'MESH','EMPTY'}and not o.get('render_only_volume')
    o.select_set(include)
    if o.get('render_only_volume'):excluded.append(o.name)
glb=out/'thetazine-v06-physical-hierarchy.glb'
bpy.ops.export_scene.gltf(filepath=str(glb),use_selection=True,export_format='GLB',export_apply=True,
 export_current_frame=True,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,
 export_frame_range=True,export_force_sampling=True,export_morph=True,export_morph_animation=True,export_extras=True)
raw=glb.read_bytes();length,kind=struct.unpack_from('<II',raw,12);doc=json.loads(raw[20:20+length]);names={n.get('name'):i for i,n in enumerate(doc['nodes'])}
for n in('V04 independently suspended engine core','V04 engine structural recoil frame'):assert n in names
assert sha(source)==pin and sha(src)==pin
report={'status':'CANONICAL_PHYSICAL_HIERARCHY_EXPORTED_PENDING_ACTUAL66_CHECK','input_source':{'path':str(src),'sha256':pin},'native':{'path':str(source),'sha256':pin},'glb':{'path':str(glb),'sha256':sha(glb)},'script_sha256':sha(pathlib.Path(__file__)),'source_is_byte_exact_copy':True,'physical_policy':'MESH+EMPTY selected, only tagged render_only_volume excluded; canonicalV05 policy','excluded_source_only':excluded,'actual_meshes':len(doc['meshes']),'actual_nodes':len(doc['nodes']),'actual_empty_nodes':sum('mesh'not in n for n in doc['nodes']),'animation_channels':sum(len(a['channels'])for a in doc.get('animations',[])),'core_node':names['V04 independently suspended engine core'],'fixed_frame_node':names['V04 engine structural recoil frame']}
for name in('detail-manifest.json','side-actuator-motion.json'):
    j=json.loads((inp/name).read_text());j['native']=report['native'];j['glb']=report['glb'];j['physical_hierarchy_export']=report;(out/name).write_text(json.dumps(j,indent=2),encoding='utf-8')
(out/'physical-hierarchy-export.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print('PHYSICAL_HIERARCHY_EXPORTED',json.dumps(report),flush=True)
