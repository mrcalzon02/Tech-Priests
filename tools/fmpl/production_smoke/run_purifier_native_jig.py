"""Run an isolated Factorio 2.1 prototype/physical pipe jig, no GUI or mod install."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--factorio',required=True)
    ap.add_argument('--sprites',required=True); ap.add_argument('--out',required=True)
    args=ap.parse_args(); exe=Path(args.factorio).resolve(); sprites=Path(args.sprites).resolve(); out=Path(args.out).resolve()
    if out.exists(): raise FileExistsError('Use a new isolated native profile')
    installed=exe.parents[2]/'data'
    base=json.loads((installed/'base/info.json').read_text())
    if base['version']!='2.1.24': raise RuntimeError('Fixture requires inspected native 2.1.24 data')
    from PIL import Image
    out.mkdir(parents=True); mods=out/'mods'; mods.mkdir(); user=out/'user-data'; user.mkdir()
    mod=mods/'tp-mh7-purifier-review_0.0.1'; mod.mkdir(); graphics=mod/'graphics'; graphics.mkdir()
    here=Path(__file__).resolve().parent
    for src,dst in (('purifier_native_jig_data.lua','data.lua'),('purifier_native_jig_control.lua','control.lua')):
        shutil.copy2(here/src,mod/dst)
    (mod/'info.json').write_text(json.dumps(dict(name='tp-mh7-purifier-review',version='0.0.1',
        title='Isolated purifier art and pipe jig',author='Tech Priests',factorio_version='2.1',dependencies=['base >= 2.1.24'])))
    with Image.open(sprites/'idle-256.png') as im:
        if im.size!=(256,256) or im.mode!='RGBA': raise ValueError('Actual idle source dimensions')
        sheet=Image.new('RGBA',(1024,512))
        for i in range(8): sheet.paste(im,((i%4)*256,(i//4)*256))
        sheet.save(graphics/'idle.png')
    shutil.copy2(sprites/'working-256.png',graphics/'working.png')
    (mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':n,'enabled':n in ('base','tp-mh7-purifier-review')}
        for n in ('base','elevated-rails','quality','recycler','space-age','tp-mh7-purifier-review')]}))
    config=out/'config.ini'; config.write_text('[path]\nread-data='+str(installed)+'\nwrite-data='+str(user)+'\n')
    (out/'steam_appid.txt').write_text('427520')
    settings=out/'map-gen-settings.json'; settings.write_text(json.dumps(dict(seed=903441,peaceful_mode=True,water=0,
        autoplace_controls={'enemy-base':dict(frequency='none',size='none',richness='none')})))
    common=[str(exe),'--config',str(config),'--mod-directory',str(mods)]
    save=out/'purifier-native-jig.zip'; commands=[]
    for name,tail in (('create',['--create',str(save),'--map-gen-settings',str(settings)]),
                      ('flow',['--benchmark',str(save),'--benchmark-ticks','660','--benchmark-runs','1'])):
        command=common+tail; print('NATIVE_JIG_START',name,flush=True)
        with (out/(name+'.log')).open('w') as log:
            result=subprocess.run(command,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        commands.append(dict(stage=name,returncode=result.returncode))
        if result.returncode: raise RuntimeError('Native '+name+' failed; inspect '+str(out/(name+'.log')))
    reports={}
    for name in ('physical-ports','flow'):
        p=user/'script-output/tp-mh7-purifier-review'/(name+'.json')
        reports[name]=json.loads(p.read_text())
        if not reports[name]['passed']: raise RuntimeError('Actual native evidence failed')
    (out/'native-jig-receipt.json').write_text(json.dumps(dict(passed=True,base_version=base['version'],
        isolated_profile=str(out),commands=commands,results=reports,
        source_graphic_hashes={n:sha(sprites/n) for n in ('idle-256.png','working-256.png')},
        fixture_hashes={n:sha(mod/n) for n in ('data.lua','control.lua')},
        graphical_pipe_seating_verified=False,ordinary_mod_installed=False,gameplay_acceptance=False),indent=2)+'\n')
    print('NATIVE_PURIFIER_PHYSICAL_JIG_PASS',out,flush=True)

if __name__=='__main__': main()
