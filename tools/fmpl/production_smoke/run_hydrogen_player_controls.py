"""Exercise real player/cursor/GUI stock transfers in isolated Factorio maps."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import time
from run_compressor_native_jig import sha


def main():
    ap=argparse.ArgumentParser()
    for key in ('factorio','addon','out'):ap.add_argument('--'+key,required=True)
    ap.add_argument('--reload',action='store_true');ap.add_argument('--main-mod');args=ap.parse_args()
    exe=Path(args.factorio).resolve();addon=Path(args.addon).resolve();out=Path(args.out).resolve();here=Path(__file__).resolve().parent
    if out.exists():raise FileExistsError('Preserve actual GUI review evidence')
    out.mkdir(parents=True);mods=out/'mods';mods.mkdir();enabled={'base','quality','recycler'}
    for source in addon.iterdir():
        if source.is_dir() and (source/'info.json').exists():shutil.copytree(source,mods/source.name);enabled.add(json.loads((source/'info.json').read_text())['name'])
    if args.main_mod:
        shutil.copytree(Path(args.main_mod).resolve(),mods/'tech-priests');enabled.update({'tech-priests','space-age','elevated-rails'})
    fixture=mods/'tp-hydrogen-player-review_0.0.1';fixture.mkdir();enabled.add('tp-hydrogen-player-review')
    shutil.copy2(here/'hydrogen_player_controls_fixture.lua',fixture/'control.lua')
    (fixture/'info.json').write_text(json.dumps(dict(name='tp-hydrogen-player-review',version='0.0.1',title='Isolated hydrogen player controls review',author='Tech Priests',factorio_version='2.1',dependencies=['tp-hydrogen-production >= 0.1.0'])))
    (mods/'mod-list.json').write_text(json.dumps(dict(mods=[dict(name=n,enabled=n in enabled) for n in sorted(enabled|{'space-age','elevated-rails'})])))
    user=out/'user-data';user.mkdir();config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n');(out/'steam_appid.txt').write_text('427520')
    settings=out/'map-gen-settings.json';settings.write_text(json.dumps(dict(seed=903801,peaceful_mode=True,water=0,autoplace_controls={'enemy-base':dict(frequency='none',size='none',richness='none')})))
    save=out/'player-controls.zip';common=[str(exe),'--config',str(config),'--mod-directory',str(mods)];commands=[];stages=[('create',['--create',str(save),'--map-gen-settings',str(settings)])]
    autosave=user/'saves/_autosave-hydrogen-player-600.zip'
    if args.reload:stages.append(('save-at-600',['--benchmark-graphics',str(save),'--benchmark-ticks','651','--benchmark-runs','1']))
    stages.append(('controls',['--benchmark-graphics',str(autosave if args.reload else save),'--benchmark-ticks','1501' if args.reload else '2001','--benchmark-runs','1']))
    for label,tail in stages:
        print('HYDROGEN_PLAYER_START',label,flush=True)
        log_path=out/(label+'.log')
        with log_path.open('w') as log:
            process=subprocess.Popen(common+tail,cwd=out,stdout=log,stderr=subprocess.STDOUT);deadline=time.monotonic()+180
            while process.poll() is None:
                content=log_path.read_text(encoding='utf-8',errors='replace')
                if 'Exception at tick' in content or 'Error while running event' in content or time.monotonic()>deadline:
                    process.terminate();process.wait(timeout=10);raise RuntimeError('Inspect '+str(log_path))
                time.sleep(.25)
        if process.returncode:raise RuntimeError('Inspect '+str(log_path))
        commands.append(dict(stage=label,exit_code=process.returncode,log_sha256=sha(log_path)))
    results=json.loads((user/'script-output/tp-hydrogen-player-review/results.json').read_text())
    if not results['passed'] or not all(results['checks'].values()):raise RuntimeError('Actual player controls gate')
    report=dict(passed=True,save_reload_exercised=args.reload,main_mod_loaded=bool(args.main_mod),results=results,commands=commands,build_receipt_sha256=sha(addon/'BUILD_RECEIPT.json'),fixture_sha256=sha(fixture/'control.lua'),graphics_reviewed=False,actual_native_gui_open_events=True,click_handler_invoked_with_real_gui_elements=True,physical_mouse_clicks_simulated=False,multiple_connected_players_tested=False)
    (out/'controls-receipt.json').write_text(json.dumps(report,indent=2)+'\n');print('HYDROGEN_PLAYER_CONTROLS_PASS',len(results['checks']),'CHECKS',flush=True)


if __name__=='__main__':main()
