from pathlib import Path
import subprocess,json,hashlib
R=Path(__file__).resolve().parent;M=R.parent/'tp-sterling-contract-main01/mods';save=R/'runtime/saves/miner-operated.zip';assert save.exists()
state=R/'runtime/script-output/miner-proof/reloaded-state.json'
if state.exists():state.rename(state.with_name('continued-before-actual-reload.json'))
cmd=['C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe','--config',str(R/'config.ini'),'--mod-directory',str(M),'--test-save',str(save),'--test-ticks','600']
with(R/'actual-reload.log').open('w')as log:p=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT)
assert p.returncode==0 and 'MINER_RELOAD_PASS'in(R/'actual-reload.log').read_text(errors='replace')and json.loads(state.read_text())['passed']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(R/'operated-reload-receipt.json').write_text(json.dumps({'passed':True,'actual_operated_save_sha256':sha(save),'actual_reload_ticks':600,'log_sha256':sha(R/'actual-reload.log'),'all_nine_selected_recipes_persist':True,'scope':'Native save loaded in a separate Factorio process. Earlier continued-before-actual-reload.json is ordinary continued simulation, not reload evidence.'},indent=2))
print('MINER_SEPARATE_PROCESS_SAVE_RELOAD_PASS')
