"""Load the normal safe add-on and read its actual default timing prototypes."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--factorio',required=True);ap.add_argument('--mod',required=True);ap.add_argument('--out',required=True);ap.add_argument('--additional-mod',action='append',default=[]);args=ap.parse_args()
    out=Path(args.out).resolve();exe=Path(args.factorio).resolve();source=Path(args.mod).resolve()
    if out.exists():raise FileExistsError('Preserve normal-adapter evidence')
    out.mkdir(parents=True);mods=out/'mods';mods.mkdir();shutil.copytree(source,mods/source.name);user=out/'user-data';user.mkdir()
    enabled={'base','quality','recycler','tp-mh7-pellet-decay'}
    additional=[]
    for path in args.additional_mod:
        extra=Path(path).resolve();info=json.loads((extra/'info.json').read_text());shutil.copytree(extra,mods/extra.name);enabled.add(info['name'])
        if info['name']=='tp-mh7-forge-review':assert not (extra/'control.lua').exists(),'Safe prototype must not contain fixture control'
        additional.append(dict(name=info['name'],has_control_script=(extra/'control.lua').exists()))
    (mods/'mod-list.json').write_text(json.dumps(dict(mods=[dict(name=n,enabled=n in enabled) for n in sorted(enabled|{'space-age','elevated-rails'})])))
    config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n');(out/'steam_appid.txt').write_text('427520')
    common=[str(exe),'--config',str(config),'--mod-directory',str(mods)];save=out/'normal-adapter.zip';results=[]
    for label,tail in (('create',['--create',str(save)]),('runtime',['--benchmark',str(save),'--benchmark-ticks','60','--benchmark-runs','1']),('data',['--dump-data'])):
        with (out/(label+'.log')).open('w') as log:result=subprocess.run(common+tail,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        if result.returncode:raise RuntimeError('Normal add-on '+label+' failed')
        results.append(dict(stage=label,exit_code=result.returncode,log_sha256=sha(out/(label+'.log'))))
    raw=json.loads((user/'script-output/data-raw-dump.json').read_text());items=raw['item-with-tags'];rows=[]
    names=['tp-mh7-raw-metallicized-pellet','tp-mh7-raw-metallicized-pellet-waning','tp-mh7-raw-metallicized-pellet-degraded','tp-mh7-raw-metallicized-pellet-critical']
    names+= [name.replace('raw-','forged-') for name in names[:]]
    for i,name in enumerate(names):
        item=items[name];expected=-128 if i%4==3 else -1
        assert item['spoil_ticks']==1800 and item['spoil_quality_change']==expected and not item['quality_affects_spoil_ticks'],name
        assert item['spoil_result']==('tp-mh7-inert-pellet' if i%4==3 else names[i+1]),name
        rows.append(dict(name=name,spoil_ticks=item['spoil_ticks'],quality_change=item['spoil_quality_change'],result=item['spoil_result'],stack_size=item['stack_size']))
    assert not items['tp-mh7-contained-metallicized-pellet'].get('spoil_ticks')
    assert not raw['item']['tp-mh7-inert-pellet'].get('fuel_value')
    if 'tp-mh7-forge-review' in enabled:
        forge=raw['assembling-machine']['tp-mh7-review-forge'];assert not forge.get('fluid_boxes');assert forge['vector_to_place_result']==[0,-1.1]
        assert forge['working_sound']['sound']['filename'].endswith('/forge-working.ogg')
    report=dict(passed=True,normal_adapter_sha256=sha(source/'control.lua'),stages=rows,contained_spoils=False,inert_is_fuel=False,commands=results,additional_mods=additional,
        scope='Actual normal-timing add-on data load, safe runtime initialization and default prototypes. The separate accelerated native fixture proves the decay and containment behavior; ordinary chain integration remains open.')
    (out/'normal-addon-readback.json').write_text(json.dumps(report,indent=2)+'\n');print('NORMAL_PELLET_ADDON_VERIFIED',flush=True)


if __name__=='__main__':main()
