from pathlib import Path
import json,hashlib,subprocess,shutil
R=Path(__file__).resolve().parent;A=R/'authored-v03';repo=R.parents[2]/'model-production';M=R.parent/'tp-sterling-contract-main01/mods/tech-priests_0.1.687';base='2e1c08f10446227f0bd4f783cf1c199e78e63658';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();cap=json.loads((A/'capture-manifest.json').read_text());assert cap['runtime_sha256']==sha(A/'laboratorium-v03.glb')
for name,h in cap['files'].items():
 p=A/'sprites'/name;assert sha(p)==h;dst=M/'graphics/entity/emergency-laboratorium-v1'/name;dst.parent.mkdir(exist_ok=True);shutil.copy2(p,dst)
p=M/'prototypes/generated_graphics/emergency-laboratorium-v1.lua';shutil.copy2(A/'emergency-laboratorium-v1.lua',p)
b=subprocess.check_output(['git','-C',str(repo),'show',base+':tech-priests_src/data-final-fixes.lua'])+b'\nrequire("prototypes.generated_graphics.emergency-laboratorium-v1")\n';(M/'data-final-fixes.lua').write_bytes(b);(A/'integrated-data-final-fixes.lua').write_bytes(b)
(A/'integration-candidate.json').write_text(json.dumps({'base_commit':base,'source_sha256':cap['source_sha256'],'runtime_sha256':cap['runtime_sha256'],'sprites':cap['files'],'native_verification_pending':True,'production_repository_integrated':False,'only_visual_prototype_fields_changed':True,'native_lab_inputs_fuel_research_speed_and_circuit_reach_preserved':True,'owner_visual_approved':False},indent=2));print('LABORATORIUM_ART_STAGED')
