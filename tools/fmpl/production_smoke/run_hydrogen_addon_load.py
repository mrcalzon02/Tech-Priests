"""Load the production addon on a normal map, optionally alongside Tech Priests."""
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
    ap.add_argument('--main-mod');args=ap.parse_args();exe=Path(args.factorio).resolve();addon=Path(args.addon).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve normal load results')
    out.mkdir(parents=True);mods=out/'mods';mods.mkdir();enabled={'base','quality','recycler'}
    for source in addon.iterdir():
        if source.is_dir() and (source/'info.json').exists():shutil.copytree(source,mods/source.name);enabled.add(json.loads((source/'info.json').read_text())['name'])
    if args.main_mod:
        source=Path(args.main_mod).resolve();shutil.copytree(source,mods/'tech-priests');enabled.update({'tech-priests','space-age','elevated-rails'})
    (mods/'mod-list.json').write_text(json.dumps(dict(mods=[dict(name=n,enabled=n in enabled) for n in sorted(enabled|{'space-age','elevated-rails'})])))
    user=out/'user-data';user.mkdir();config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n');(out/'steam_appid.txt').write_text('427520')
    commands=[]
    for label,tail in [('create',['--create',str(out/'normal-map.zip')]),('data',['--dump-data'])]:
        with (out/(label+'.log')).open('w') as log:r=subprocess.run([str(exe),'--config',str(config),'--mod-directory',str(mods),*tail],cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=240)
        if r.returncode:raise RuntimeError('Inspect '+str(out/(label+'.log')))
        commands.append(dict(stage=label,exit_code=r.returncode,log_sha256=sha(out/(label+'.log'))))
    raw=json.loads((user/'script-output/data-raw-dump.json').read_text());specs=json.loads((addon/'BUILD_RECEIPT.json').read_text())['specs'];rows=[]
    assets=verify_references(raw,mods/'tp-hydrogen-production_0.1.0')
    for spec in specs:
        e=raw['assembling-machine'][spec['entity']];recipe=raw['recipe'][spec['recipe']]
        if e['energy_source']['type']!='electric' or recipe['energy_required']!=spec['cycle_seconds']:raise RuntimeError('Electricity/cycle contract '+spec['key'])
        if not raw['recipe']['tp-hydrogen-build-'+spec['key']]['enabled']==False:raise RuntimeError('Construction recipe bypasses research')
        rows.append(dict(key=spec['key'],entity=spec['entity'],tile_width=e['tile_width'],tile_height=e['tile_height'],energy_usage=e['energy_usage'],recipe_seconds=recipe['energy_required'],sound=e['working_sound'],fluid_boxes=len(e.get('fluid_boxes',[]))))
    report=dict(passed=True,main_mod_loaded=bool(args.main_mod),commands=commands,machines=rows,verified_native_asset_uris=assets,technology=raw['technology']['tp-metallicized-hydrogen-production'],build_receipt_sha256=sha(addon/'BUILD_RECEIPT.json'),source_mod_hashes={p.relative_to(mods).as_posix():sha(p) for p in mods.rglob('*.lua')},scope='Normal map creation and native prototype audit only. Full-chain production, power interruption, blocked output, save/reload and graphical interfaces remain separate tests.')
    (out/'load-readback.json').write_text(json.dumps(report,indent=2)+'\n');print('HYDROGEN_NORMAL_ADDON_LOAD_PASS',len(rows),'MACHINES',flush=True)


if __name__=='__main__':main()
