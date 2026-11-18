from pathlib import Path
import subprocess,json
R=Path(__file__).resolve().parent;M=R.parent/'tp-sterling-contract-main01/mods';d=M/'power-grid-contract_0.0.1';d.mkdir(exist_ok=True);(d/'info.json').write_text(json.dumps({'name':'power-grid-contract','version':'0.0.1','title':'Actual Emergency Power Grid contract','author':'local','factorio_version':'2.1','dependencies':['base','space-age','tech-priests']}));(d/'control.lua').write_bytes((R/'contract-control.lua').read_bytes());(d/'data-final-fixes.lua').write_bytes((R/'contract-data-final-fixes.lua').read_bytes());p=M/'mod-list.json';m=json.loads(p.read_text());m['mods']=[x for x in m['mods']if x['name']!='power-grid-contract']
for x in m['mods']:
 if x['name']not in('base','space-age','elevated-rails','quality','recycler','tech-priests'):x['enabled']=False
m['mods'].append({'name':'power-grid-contract','enabled':True});p.write_text(json.dumps(m));(R/'config.ini').write_text('[path]\nread-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data\nwrite-data='+str(R/'runtime')+'\n');args=['C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe','--config',str(R/'config.ini'),'--mod-directory',str(M),'--create',str(R/'power-grid-contract.zip')]
with(R/'contract.log').open('w')as f:r=subprocess.run(args,stdout=f,stderr=subprocess.STDOUT,cwd=R)
assert r.returncode==0,(R/'contract.log').read_text(errors='replace')[-2500:];print('POWER_GRID_CONTRACT_NATIVE_CAPTURED')
