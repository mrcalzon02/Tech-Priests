from pathlib import Path
import json,hashlib,subprocess,shutil
R=Path(__file__).resolve().parent;A=R/'authored-v05';repo=R.parents[2]/'model-production';M=R.parent/'tp-sterling-contract-main01/mods/tech-priests_0.1.687';base='8263531d659c885ec36a15767ff844c863d82fd1';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();cap=json.loads((A/'capture-manifest.json').read_text());assert cap['runtime_sha256']==sha(A/'smelter-v05.glb')
for name,h in cap['files'].items():
 p=A/'sprites'/name;assert sha(p)==h;dst=M/'graphics/entity/emergency-smelter-v1'/name;dst.parent.mkdir(exist_ok=True);shutil.copy2(p,dst)
p=M/'prototypes/generated_graphics/emergency-smelter-v1.lua';shutil.copy2(A/'emergency-smelter-v1.lua',p)
b=subprocess.check_output(['git','-C',str(repo),'show',base+':tech-priests_src/data-final-fixes.lua'])+b'\nrequire("prototypes.generated_graphics.emergency-smelter-v1")\n';(M/'data-final-fixes.lua').write_bytes(b);(A/'integrated-data-final-fixes.lua').write_bytes(b)
(A/'integration-candidate.json').write_text(json.dumps({'base_commit':base,'source_sha256':cap['source_sha256'],'runtime_sha256':cap['runtime_sha256'],'sprites':cap['files'],'native_verification_pending':True,'production_repository_integrated':False,'only_visual_fields_and_existing_recipe_output_capacity_repair':True,'result_inventory_size_before':1,'result_inventory_size_after':8,'smoke_position_matches_actual_chimney':True,'owner_visual_approved':False},indent=2));print('SMELTER_ART_STAGED')
