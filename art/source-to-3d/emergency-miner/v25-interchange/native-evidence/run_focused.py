from pathlib import Path
import subprocess,json
R=Path(__file__).resolve().parent;M=R.parent/'tp-sterling-contract-main01/mods';d=M/'miner-v25-proof_0.0.1';(d/'control.lua').write_bytes((R/'focused-control.lua').read_bytes())
args=['C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe','--config',str(R/'config.ini'),'--mod-directory',str(M)]
with(R/'create-focused.log').open('w')as f:p=subprocess.run(args+['--create',str(R/'miner-focused.zip')],stdout=f,stderr=subprocess.STDOUT)
assert p.returncode==0,(R/'create-focused.log').read_text(errors='replace')[-2000:]
with(R/'run-focused.log').open('w')as f:p=subprocess.run(args+['--test-save',str(R/'miner-focused.zip'),'--test-ticks','3360'],stdout=f,stderr=subprocess.STDOUT)
assert p.returncode==0 and 'MINER_FOCUSED_PASS'in(R/'run-focused.log').read_text(errors='replace'),(R/'run-focused.log').read_text(errors='replace')[-3000:]
print('MINER_BUILD_PLACE_MINE_AND_NATIVE_CIRCUIT_PASS')
