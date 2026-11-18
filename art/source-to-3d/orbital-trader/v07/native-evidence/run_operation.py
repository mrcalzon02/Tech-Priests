from pathlib import Path
import subprocess,json,time
R=Path(__file__).resolve().parent;M=R.parent/'tp-sterling-contract-main01/mods';d=M/'orbital-v1-proof_0.0.1';d.mkdir(exist_ok=True);(d/'info.json').write_text(json.dumps({'name':'orbital-v1-proof','version':'0.0.1','title':'Actual Orbital Trader operation','author':'local','factorio_version':'2.1','dependencies':['base','space-age','tech-priests']}));(d/'control.lua').write_bytes((R/'orbital-proof-control.lua').read_bytes());(d/'data.lua').write_text('data:extend({{type="electric-energy-interface",name="orbital-proof-power",flags={"not-on-map"},collision_mask={layers={}},energy_source={type="electric",buffer_capacity="1GJ",usage_priority="primary-output",output_flow_limit="50MW"},energy_production="50MW",energy_usage="0W",picture={filename="__core__/graphics/empty.png",width=1,height=1}}})\n');p=M/'mod-list.json';m=json.loads(p.read_text());m['mods']=[x for x in m['mods']if x['name']!='orbital-v1-proof']
for x in m['mods']:
 if x['name']not in('base','space-age','elevated-rails','quality','recycler','tech-priests'):x['enabled']=False
m['mods'].append({'name':'orbital-v1-proof','enabled':True});p.write_text(json.dumps(m));args=['C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe','--config',str(R/'config.ini'),'--mod-directory',str(M)]
for name,extra in [('create-operational',['--create',str(R/'orbital-operation.zip')]),('test-operational',['--test-save',str(R/'orbital-operation.zip'),'--test-ticks','12060'])]:
 with(R/(name+'.log')).open('w')as f:r=subprocess.run(args+extra,stdout=f,stderr=subprocess.STDOUT,cwd=R)
 print(name,r.returncode,flush=True)
 if r.returncode:print((R/(name+'.log')).read_text(errors='replace')[-2200:]);raise SystemExit(r.returncode)
