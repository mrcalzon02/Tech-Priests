"""Run actual Factorio pellet decay, transit, containment and reload cases."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--factorio',required=True);ap.add_argument('--out',required=True);ap.add_argument('--reload',action='store_true');args=ap.parse_args()
    out=Path(args.out).resolve();exe=Path(args.factorio).resolve();src=Path(__file__).with_name('pellet_decay_review')
    if out.exists():raise FileExistsError('Preserve native decay receipts')
    out.mkdir(parents=True);mods=out/'mods';mod=mods/'tp-mh7-pellet-decay-review_0.0.1';mod.parent.mkdir();shutil.copytree(src,mod)
    normal_config=sha(mod/'config.lua')
    (mod/'config.lua').write_text((mod/'config.lua').read_text().replace('15*60','60').replace('30*60','150'))
    (mod/'info.json').write_text(json.dumps(dict(name='tp-mh7-pellet-decay-review',version='0.0.1',title='Metallicized pellet decay behavior fixture',author='Tech Priests',factorio_version='2.1',dependencies=['base >= 2.1.24','quality >= 2.1.24'],expansion_required=True,quality_required=True,spoiling_required=True)))
    enabled={'base','quality','recycler','tp-mh7-pellet-decay-review'}
    (mods/'mod-list.json').write_text(json.dumps(dict(mods=[dict(name=n,enabled=n in enabled) for n in ('base','quality','recycler','space-age','elevated-rails','tp-mh7-pellet-decay-review')])))
    user=out/'user-data';user.mkdir();config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n');(out/'steam_appid.txt').write_text('427520')
    settings=out/'map-gen-settings.json';settings.write_text(json.dumps(dict(seed=503421,peaceful_mode=True,water=0,autoplace_controls={'enemy-base':dict(frequency='none',size='none',richness='none')})))
    save=out/'pellet-decay-jig.zip';common=[str(exe),'--config',str(config),'--mod-directory',str(mods)]
    commands=[('create',['--create',str(save),'--map-gen-settings',str(settings)])]
    if args.reload:commands.append(('save-at-200',['--load-game',str(save),'--until-tick','200']))
    commands.append(('runtime',['--benchmark',str(save),'--benchmark-ticks','801' if args.reload else '1001','--benchmark-runs','1']))
    for label,tail in commands:
        with (out/(label+'.log')).open('w') as log:result=subprocess.run(common+tail,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        print('PELLET_DECAY_STAGE',label,result.returncode,flush=True)
        if result.returncode:raise RuntimeError('Inspect '+str(out/(label+'.log')))
    path=user/'script-output/pellet-decay/readback.json';report=json.loads(path.read_text())
    if not report['passed']:raise RuntimeError('Native behavior did not pass')
    receipt=dict(passed=True,save_reload_exercised=args.reload,native_version='2.1.24',behavior=report,
        source_hashes={p.name:sha(p) for p in sorted(src.glob('*.lua'))},normal_config_sha256=normal_config,
        test_config_sha256=sha(mod/'config.lua'),save_sha256=sha(save),log_hashes={label:sha(out/(label+'.log')) for label,_ in commands},
        scope='Accelerated actual native quality/spoilage, item health, separate randomized timers, inventory transfer, belt/ground/inserter/script inventory, reversible containment and terminal inert result. Normal timing is configurable 15-30 seconds per stage; ordinary chain integration remains open.')
    (out/'native-decay-readback.json').write_text(json.dumps(receipt,indent=2)+'\n');print('PELLET_DECAY_VERIFIED',report['checks'],flush=True)


if __name__=='__main__':main()
