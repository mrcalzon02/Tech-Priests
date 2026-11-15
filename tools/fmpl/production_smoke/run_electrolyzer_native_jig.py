"""Actual isolated native prototype, 32 connection sites and split-flow proof."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from PIL import Image


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--factorio',required=True)
    ap.add_argument('--asset',required=True);ap.add_argument('--out',required=True)
    ap.add_argument('--capture',help='Explicit native-fitting capture derivative; model source remains independently bound')
    args=ap.parse_args();exe=Path(args.factorio).resolve();asset=Path(args.asset).resolve();out=Path(args.out).resolve()
    capture=Path(args.capture).resolve() if args.capture else asset/'captures'
    if out.exists():raise FileExistsError('Retain isolated native profiles')
    installed=exe.parents[2]/'data';base=json.loads((installed/'base/info.json').read_text())
    if base['version']!='2.1.24':raise RuntimeError('Requires inspected target 2.1.24')
    out.mkdir(parents=True);mods=out/'mods';mods.mkdir();user=out/'user-data';user.mkdir()
    mod=mods/'tp-mh7-electrolyzer-review_0.0.1';mod.mkdir();graphics=mod/'graphics';graphics.mkdir()
    here=Path(__file__).resolve().parent
    for src,dst in (('electrolyzer_native_jig_data.lua','data.lua'),('electrolyzer_native_jig_control.lua','control.lua')):shutil.copy2(here/src,mod/dst)
    (mod/'info.json').write_text(json.dumps(dict(name='tp-mh7-electrolyzer-review',version='0.0.1',title='Electrolyzer art/pipe review',author='Tech Priests',factorio_version='2.1',dependencies=['base >= 2.1.24'])))
    for direction,row in (('north',0),('east',3),('south',2),('west',1)):
        for state in ('idle','working'):
            sheet=Image.new('RGBA',(1024,512))
            for i in range(8):
                path=capture/f'frames/{state}/d{row:02d}/f{0 if state=="idle" else i:03d}.png'
                with Image.open(path) as im:
                    if im.size!=(256,256) or im.mode!='RGBA':raise RuntimeError('Wrong actual source frame')
                    sheet.paste(im,((i%4)*256,(i//4)*256))
            sheet.save(graphics/(state+'-'+direction+'.png'))
    (mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':n,'enabled':n in ('base','tp-mh7-electrolyzer-review')}
        for n in ('base','elevated-rails','quality','recycler','space-age','tp-mh7-electrolyzer-review')]}))
    config=out/'config.ini';config.write_text('[path]\nread-data='+str(installed)+'\nwrite-data='+str(user)+'\n')
    (out/'steam_appid.txt').write_text('427520')
    settings=out/'map-gen-settings.json';settings.write_text(json.dumps(dict(seed=903442,peaceful_mode=True,water=0,autoplace_controls={'enemy-base':dict(frequency='none',size='none',richness='none')})))
    common=[str(exe),'--config',str(config),'--mod-directory',str(mods)];save=out/'electrolyzer-native-jig.zip';commands=[]
    for name,tail in (('create',['--create',str(save),'--map-gen-settings',str(settings)]),('flow',['--benchmark',str(save),'--benchmark-ticks','660','--benchmark-runs','1'])):
        print('ELECTROLYZER_NATIVE_START',name,flush=True)
        with (out/(name+'.log')).open('w') as log:
            result=subprocess.run(common+tail,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        commands.append(dict(stage=name,returncode=result.returncode))
        if result.returncode:raise RuntimeError('Actual native '+name+' failed')
    reports={}
    for name in ('physical-ports','flow'):
        reports[name]=json.loads((user/'script-output/tp-mh7-electrolyzer-review'/(name+'.json')).read_text())
        if not reports[name]['passed']:raise RuntimeError('Actual native evidence failed')
    receipt=dict(passed=True,base_version=base['version'],commands=commands,results=reports,
        model_source_sha256=sha(asset/'electrolyzer-v05.blend'),source_capture_sha256=sha(capture/'capture.json'),
        fixture_hashes={n:sha(mod/n) for n in ('data.lua','control.lua')},
        native_profile=str(out),graphical_seating_verified=False,ordinary_mod_installed=False,production_economy_assigned=False)
    (out/'native-jig-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('ELECTROLYZER_NATIVE_SPLIT_FLOW_PASS',flush=True)


if __name__=='__main__':main()
