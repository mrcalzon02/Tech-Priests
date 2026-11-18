"""Native full-source proof of presentation-only dormant broker admission."""
from pathlib import Path
import argparse,json,os,shutil,subprocess
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser();p.add_argument('--output-root',type=Path,required=True)
 p.add_argument('--fixture',choices=['broker-gating','raw5-delivery'],default='broker-gating')
 a=p.parse_args()
 out=a.output_root;mod=out/'mods/tech-priests';mod.mkdir(parents=True,exist_ok=True)
 for source in (ROOT/'tech-priests_src').rglob('*'):
  if not source.is_file():continue
  dest=mod/source.relative_to(ROOT/'tech-priests_src');dest.parent.mkdir(parents=True,exist_ok=True)
  if dest.exists():dest.unlink()
  if source.suffix.lower() in ('.png','.ogg','.wav'):
   try:os.link(source,dest)
   except OSError:shutil.copy2(source,dest)
  else:shutil.copy2(source,dest)
 shutil.copy2(ROOT/'tests/scenarios/character-skins'/(a.fixture+'.lua'),mod/(a.fixture+'.lua'))
 (mod/'control.lua').write_text((mod/'control.lua').read_text(encoding='utf-8')+'\nrequire("'+a.fixture+'")\n',encoding='utf-8')
 (out/'mods/mod-list.json').write_text(json.dumps({'mods':[{'name':n,'enabled':True} for n in ('base','space-age','quality','recycler','elevated-rails','tech-priests')]}))
 exe=Path(r'C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe')
 user=out/'user-data';user.mkdir(exist_ok=True);config=out/'config.ini'
 config.write_text('[path]\nread-data='+str(exe.parents[2]/'data').replace('\\','/')+'\nwrite-data='+str(user.resolve()).replace('\\','/')+'\n[other]\ncheck-updates=false\n')
 common=[str(exe),'--config',str(config.resolve()),'--mod-directory',str((out/'mods').resolve())]
 save=out/'proof.zip'
 def run(name,args,marker=None):
  log=out/(name+'.log')
  with log.open('w') as f:r=subprocess.run(common+args,stdout=f,stderr=subprocess.STDOUT,timeout=180)
  text=log.read_text(errors='replace')
  if r.returncode or 'isolated handler failure' in text or marker and marker not in text:
   print(text[-10000:]);raise RuntimeError(name+' failed')
  print('PASS',name,flush=True)
 run('create',['--create',str(save.resolve())])
 marker='[TP-SKIN-BROKER] PASS ' if a.fixture=='broker-gating' else '[TP-RAW5-REGRESSION] PASS '
 run('native',['--test-save',str(save.resolve()),'--test-ticks','90'],marker)
 print((user/'script-output/character-skins'/(a.fixture+'.json')).read_text(),flush=True)
 # --test-save suppresses autosaves. A normal headless benchmark writes none
 # either, so a separate native save/reload proof is covered by the skin runner.
if __name__=='__main__':main()
