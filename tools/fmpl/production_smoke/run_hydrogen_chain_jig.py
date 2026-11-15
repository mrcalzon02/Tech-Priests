"""Exercise the seven-machine electric production line without injected intermediates."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
from run_compressor_native_jig import sha
from hydrogen_native_assets import verify_references


def main():
    ap=argparse.ArgumentParser()
    for k in ('factorio','addon','out'):ap.add_argument('--'+k,required=True)
    ap.add_argument('--reload',action='store_true');ap.add_argument('--main-mod');args=ap.parse_args();exe=Path(args.factorio).resolve();addon=Path(args.addon).resolve();out=Path(args.out).resolve();here=Path(__file__).resolve().parent
    if out.exists():raise FileExistsError('Preserve chain test profiles')
    out.mkdir(parents=True);mods=out/'mods';mods.mkdir();enabled={'base','quality','recycler'}
    for source in addon.iterdir():
        if source.is_dir() and (source/'info.json').exists():shutil.copytree(source,mods/source.name);enabled.add(json.loads((source/'info.json').read_text())['name'])
    if args.main_mod:
        source=Path(args.main_mod).resolve();shutil.copytree(source,mods/'tech-priests');enabled.update({'tech-priests','space-age','elevated-rails'})
    fixture=mods/'tp-hydrogen-chain-review_0.0.1';fixture.mkdir();enabled.add('tp-hydrogen-chain-review')
    for source,target in [('hydrogen_chain_fixture_data.lua','data.lua'),('hydrogen_chain_fixture.lua','control.lua')]:shutil.copy2(here/source,fixture/target)
    (fixture/'info.json').write_text(json.dumps(dict(name='tp-hydrogen-chain-review',version='0.0.1',title='Isolated connected hydrogen chain review',author='Tech Priests',factorio_version='2.1',dependencies=['tp-hydrogen-production >= 0.1.0'])))
    (mods/'mod-list.json').write_text(json.dumps(dict(mods=[dict(name=n,enabled=n in enabled) for n in sorted(enabled|{'space-age','elevated-rails'})])))
    user=out/'user-data';user.mkdir();config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n');(out/'steam_appid.txt').write_text('427520')
    settings=out/'map-gen-settings.json';settings.write_text(json.dumps(dict(seed=903801,peaceful_mode=True,water=0,autoplace_controls={'enemy-base':dict(frequency='none',size='none',richness='none')})))
    save=out/'connected-chain.zip';common=[str(exe),'--config',str(config),'--mod-directory',str(mods)];commands=[];stages=[('create',['--create',str(save),'--map-gen-settings',str(settings)])]
    if args.reload:stages.append(('save-at-3500',['--load-game',str(save),'--until-tick','3500']))
    stages.extend([('production',['--benchmark',str(save),'--benchmark-ticks','6501' if args.reload else '10001','--benchmark-runs','1']),('data',['--dump-data'])])
    for label,tail in stages:
        print('HYDROGEN_CHAIN_START',label,flush=True)
        with (out/(label+'.log')).open('w') as log:r=subprocess.run(common+tail,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=240)
        if r.returncode:raise RuntimeError('Inspect '+str(out/(label+'.log')))
        commands.append(dict(stage=label,exit_code=r.returncode,log_sha256=sha(out/(label+'.log'))))
    production=json.loads((user/'script-output/tp-hydrogen-chain-review/production.json').read_text())
    if not production['passed']:raise RuntimeError('Actual chain production failed')
    raw=json.loads((user/'script-output/data-raw-dump.json').read_text());assets=verify_references(raw,mods/'tp-hydrogen-production_0.1.0')
    report=dict(passed=True,save_reload_exercised=args.reload,main_mod_loaded=bool(args.main_mod),commands=commands,results=production,verified_native_asset_uris=assets,build_receipt_sha256=sha(addon/'BUILD_RECEIPT.json'),fixture_hashes={p.name:sha(p) for p in fixture.glob('*.lua')},graphics_reviewed=False,owner_approved=False,economy_tuning_final=False)
    (out/'chain-receipt.json').write_text(json.dumps(report,indent=2)+'\n');print('HYDROGEN_CONNECTED_CHAIN_PASS',production['contained_output_before_unseal'],'CONTAINED',flush=True)


if __name__=='__main__':main()
