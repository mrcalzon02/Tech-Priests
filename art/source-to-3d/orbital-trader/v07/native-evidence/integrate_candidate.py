from pathlib import Path
import subprocess,shutil,json,hashlib
R=Path(__file__).resolve().parent;A=R/'authored-v07';repo=R.parents[2]/'model-production';M=R.parent/'tp-sterling-contract-main01/mods/tech-priests_0.1.687';base='c24c5599976b77a68d6ce4cdfc6f3737e3408127';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();cap=json.loads((A/'capture-manifest.json').read_text());assert cap['authored_replacement_cargo_pod_meshes']==0 and cap['runtime_sha256']==sha(A/'orbital-v07.glb')
for n,row in cap['files'].items():
 p=A/'sprites'/n;assert sha(p)==row['sha256'];d=M/'graphics/entity/orbital-trader-v1'/n;d.parent.mkdir(exist_ok=True);shutil.copy2(p,d)
for src,dst in [('orbital-trader-v1.lua','prototypes/generated_graphics/orbital-trader-v1.lua'),('orbital_trader_visuals.lua','scripts/orbital_trader_visuals.lua')]:
 p=M/dst;p.parent.mkdir(exist_ok=True);shutil.copy2(A/src,p)
for name,append in [('data-final-fixes.lua',b'\nrequire("prototypes.generated_graphics.orbital-trader-v1")\n'),('control.lua',b'\n-- Orbital arrival visuals reuse the existing native cargo pod and canonical dispatcher.\nassert(require("scripts.orbital_trader_visuals").install_main(require("scripts.core.runtime_event_registry")))\n')]:
 b=subprocess.check_output(['git','-C',str(repo),'show',base+':tech-priests_src/'+name]);(M/name).write_bytes(b+append);(A/('integrated-'+name)).write_bytes(b+append)
(A/'integration-candidate.json').write_text(json.dumps({'base_commit':base,'source_sha256':cap['source_sha256'],'runtime_sha256':cap['runtime_sha256'],'isolated_mod':str(M),'original_cargo_pod_assets_and_processions_reused':True,'authored_replacement_cargo_pod':False,'sprites':cap['files'],'native_coupled_verification_pending':True,'production_repository_integrated':False,'owner_visual_approved':False},indent=2));print('ORBITAL_HATCH_AND_NATIVE_POD_STAGED')
