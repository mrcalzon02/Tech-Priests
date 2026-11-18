from pathlib import Path
import subprocess,json,time
R=Path(__file__).resolve().parent;M=R.parent/'tp-sterling-contract-main01/mods';d=M/'miner-v25-proof_0.0.1';d.mkdir(exist_ok=True)
(d/'info.json').write_text(json.dumps({'name':'miner-v25-proof','version':'0.0.1','title':'Approved miner actual operations','author':'local','factorio_version':'2.1','dependencies':['base','space-age','tech-priests']}))
(d/'control.lua').write_bytes((R/'miner-proof-control.lua').read_bytes())
(d/'data.lua').write_text('data:extend({{type="electric-energy-interface",name="miner-proof-power",flags={"not-on-map"},collision_mask={layers={}},energy_source={type="electric",buffer_capacity="1GJ",usage_priority="primary-output",output_flow_limit="50MW"},energy_production="50MW",energy_usage="0W",picture={filename="__core__/graphics/empty.png",width=1,height=1}}})')
p=M/'mod-list.json';m=json.loads(p.read_text());m['mods']=[x for x in m['mods']if x['name']!='miner-v25-proof']
for x in m['mods']:
 if x['name']not in('base','space-age','elevated-rails','quality','recycler','tech-priests'):x['enabled']=False
m['mods'].append({'name':'miner-v25-proof','enabled':True});p.write_text(json.dumps(m))
exe='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe';base=[exe,'--config',str(R/'config.ini'),'--mod-directory',str(M)]
(R/'runtime/saves').mkdir(exist_ok=True,parents=True)
settings=R/'server-settings.json';cfg=json.loads((R.parent/'tp-emergency-power-grid-main01/server-settings.json').read_text());cfg.update({'name':'Miner private proof','visibility':{'public':False,'lan':False},'require_user_verification':False,'max_players':1,'auto_pause':False,'autosave_interval':0});settings.write_text(json.dumps(cfg))
with(R/'create-proof.log').open('w')as log:
 p=subprocess.run(base+['--create',str(R/'miner-proof.zip')],stdout=log,stderr=subprocess.STDOUT)
assert p.returncode==0,(R/'create-proof.log').read_text(errors='replace')[-2500:]
with(R/'server-proof.log').open('w')as log:
 p=subprocess.Popen(base+['--start-server',str(R/'miner-proof.zip'),'--server-settings',str(settings),'--bind','127.0.0.1','--port','34247'],stdout=log,stderr=subprocess.STDOUT)
 try:
  start=time.monotonic()
  while time.monotonic()-start<240:
   time.sleep(1)
   if p.poll()is not None:raise RuntimeError((R/'server-proof.log').read_text(errors='replace')[-3500:])
   if(R/'runtime/saves/miner-operated.zip').exists():print('ACTUAL_NINE_RECIPES_SAVE_COMPLETE',flush=True);break
  else:raise RuntimeError('bounded native proof deadline; inspect owned log')
 finally:
  if p.poll()is None:p.terminate();p.wait(timeout=20)
