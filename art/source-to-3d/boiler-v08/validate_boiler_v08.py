import bpy,json,math,hashlib,struct
from pathlib import Path
R=Path(__file__).resolve().parent;D=R/'boiler_v08'
bpy.ops.wm.open_mainfile(filepath=str(D/'tech_priests_emergency_boiler_v08_animated.blend'));s=bpy.context.scene;j=json.loads((D/'Boiler_V08_Animation_Record.json').read_text())
camera_count=len([o for o in bpy.data.objects if o.type=='CAMERA']);assert camera_count==1,camera_count
def sig(o):return hashlib.sha256(b''.join(struct.pack('3f',*v.co) for v in o.data.vertices)).hexdigest()
assert all(sig(bpy.data.objects[n])==v for n,v in j['source_mesh_vertex_hashes'].items())
def sample(f):
 s.frame_set(f);bpy.context.view_layer.update();glow=[]
 for x in j['emissive_animations']:
  mat=bpy.data.materials[x['material']];n=next((n for n in mat.node_tree.nodes if n.type=='EMISSION'),None);glow.append(float(n.inputs['Strength'].default_value if n else next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Emission Strength'].default_value))
 return {'rigs':{x['rig']:[list(r) for r in bpy.data.objects[x['rig']].matrix_world] for x in j['rattle_rigs']},'glow':glow,'puffs':{x['object']:{'position':list(bpy.data.objects[x['object']].location),'scale':list(bpy.data.objects[x['object']].scale),'density':float(bpy.data.objects[x['object']].data.materials[0].node_tree.nodes['Animated steam density'].outputs[0].default_value)} for x in j['steam_puffs']}}
a=sample(1);b=sample(97)
def flat(x):
 if isinstance(x,dict):return [v for k in x for v in flat(x[k])]
 if isinstance(x,list):return [v for a in x for v in flat(a)]
 return [float(x)]
loop_error=max(abs(x-y) for x,y in zip(flat(a),flat(b)));assert loop_error<1e-5,loop_error
samples=[sample(f) for f in [1,13,25,37,49,61,73,85]]
glow_ranges=[max(x['glow'][i] for x in samples)-min(x['glow'][i] for x in samples) for i in range(len(j['emissive_animations']))];assert all(x>.01 for x in glow_ranges)
rig_ranges={x['rig']:max(abs(y['rigs'][x['rig']][i][3]-a['rigs'][x['rig']][i][3]) for y in samples for i in range(3)) for x in j['rattle_rigs']};assert all(v>.001 for v in rig_ranges.values())
peak=sample(25);assert any(v['scale'][0]>.03 for v in peak['puffs'].values())
out={'native_reopened':True,'camera_count':camera_count,'all_source_mesh_vertices_preserved':True,'loop_endpoint_error':loop_error,'emissive_target_count':len(glow_ranges),'emission_strength_sample_ranges':glow_ranges,'rattle_rig_translation_sample_ranges':rig_ranges,'steam_puffs':len(j['steam_puffs']),'nozzle_object':j['steam_nozzle_object'],'nozzle_exit':j['steam_exit_world'],'pass':True}
(D/'Boiler_V08_Validation.json').write_text(json.dumps(out,indent=2));print('ANIMATION_VALIDATION',out)
