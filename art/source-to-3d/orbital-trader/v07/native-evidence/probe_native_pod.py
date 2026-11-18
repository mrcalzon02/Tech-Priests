from pathlib import Path
import subprocess,json
R=Path(__file__).resolve().parent;M=R.parent/'tp-sterling-contract-main01/mods';d=M/'orbital-pod-reuse_0.0.1';d.mkdir(exist_ok=True);(d/'info.json').write_text(json.dumps({'name':'orbital-pod-reuse','version':'0.0.1','title':'Existing native cargo pod reuse','author':'local','factorio_version':'2.1','dependencies':['base','space-age','tech-priests']}));(d/'control.lua').write_bytes((R/'pod-reuse-control.lua').read_bytes());(d/'data-final-fixes.lua').write_text('local p=table.deepcopy(assert(data.raw["cargo-pod"]["cargo-pod"]))\np.name="tp-orbital-native-cargo-pod";p.impact_trigger=nil;p.hidden_in_factoriopedia=true\ndata:extend({p})\n');p=M/'mod-list.json';m=json.loads(p.read_text());m['mods']=[x for x in m['mods']if x['name']!='orbital-pod-reuse']
for x in m['mods']:
 if x['name']not in('base','space-age','elevated-rails','quality','recycler','tech-priests'):x['enabled']=False
m['mods'].append({'name':'orbital-pod-reuse','enabled':True});p.write_text(json.dumps(m));args=['C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe','--config',str(R/'config.ini'),'--mod-directory',str(M)]
for name,extra in [('pod-reuse-create',['--create',str(R/'native-pod-reuse.zip')]),('pod-reuse-test',['--test-save',str(R/'native-pod-reuse.zip'),'--test-ticks','1200'])]:
 with(R/(name+'.log')).open('w')as f:r=subprocess.run(args+extra,stdout=f,stderr=subprocess.STDOUT,cwd=R)
 print(name,r.returncode,flush=True)
 if r.returncode:print((R/(name+'.log')).read_text(errors='replace')[-1800:]);raise SystemExit(r.returncode)
