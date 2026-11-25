"""Exercise production Data Spike prototypes and runtime in isolated Factorio."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--full', action='store_true', help='Load all production prototypes, runtime modules, and required dependencies')
    parser.add_argument('--factorio', type=Path, default=Path(r'C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'))
    args = parser.parse_args()
    out = ROOT / ('build/data-spike-native-full' if args.full else 'build/data-spike-native')
    mod = out / 'mods/tech-priests'
    source = ROOT / 'tech-priests_src'
    mod.mkdir(parents=True, exist_ok=True)
    for relative in ['scripts/core/conclave_center_0558.lua', 'scripts/core/runtime_event_registry.lua',
                     'graphics/icons/data-spike.png', 'locale/en/base.cfg', 'prototypes/compatibility/native_recipe_schema_1274.lua']:
        target = mod / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / relative, target)
    (mod / 'info.json').write_text(json.dumps(dict(name='tech-priests', version='0.0.1', title='Data Spike native fixture', author='Test', factorio_version='2.1', dependencies=['base >= 2.1.0'])))
    item = (source / 'prototypes/item.lua').read_text('utf-8')
    start = item.rfind('table.insert(items, {', 0, item.index('name = "tech-priests-data-spike"'))
    item = item[start:item.index('\n})', start) + 3]
    recipe = (source / 'prototypes/recipe.lua').read_text('utf-8')
    start = recipe.rfind('table.insert(recipes, {', 0, recipe.index('name = "tech-priests-data-spike"'))
    recipe = recipe[start:recipe.index('\n})', start) + 3]
    entity = (source / 'prototypes/entity.lua').read_text('utf-8')
    start = entity.index('local function make_tech_priests_data_spike_projectile_0590()')
    entity = entity[start:entity.index('\nend', start) + 4]
    technology = (source / 'prototypes/technology.lua').read_text('utf-8')
    start = technology.rfind('  {', 0, technology.index('name = "tech-priests-data-spike-reclamation-1"'))
    stop = technology.index('\n  {', technology.index('order = "c-k-e-z"', start))
    technology = technology[start:stop]
    (mod / 'data.lua').write_text('''local items,recipes={},{}
data:extend{{type="item-subgroup",name="tech-priest-cogitators",group="logistics",order="z"}}
local salt=table.deepcopy(data.raw.item["coal"]);salt.name="ritual-salt";data:extend{salt}
local station=table.deepcopy(data.raw.container["steel-chest"]);station.name="senior-cogitator-station";data:extend{station}
local prerequisite=table.deepcopy(data.raw.technology.automation);prerequisite.name="planetary-magos-cogitator-stations";prerequisite.effects={};data:extend{prerequisite}
local function red_green_blue_science(count,time) return {count=count,time=time,ingredients={{"automation-science-pack",1},{"logistic-science-pack",1},{"chemical-science-pack",1}}} end
''' + item + '\n' + recipe + '\n' + entity + '\ndata:extend(items);data:extend(recipes);data:extend{make_tech_priests_data_spike_projectile_0590()}\ndata:extend{\n' + technology + '\n}\n')
    shutil.copy2(ROOT / 'tests/scenarios/data-spike/fixture.lua', mod / 'fixture.lua')
    (mod / 'control.lua').write_text('TechPriestsRuntimeEventRegistry=require("scripts.core.runtime_event_registry")\nrequire("scripts.core.conclave_center_0558").install()\nrequire("fixture")\n')
    (mod / 'data-final-fixes.lua').write_text('require("prototypes.compatibility.native_recipe_schema_1274")(data.raw.recipe, mods.base)\n')
    enabled = ['base', 'tech-priests']
    if args.full:
        for path in source.rglob('*'):
            if not path.is_file():
                continue
            target = mod / path.relative_to(source)
            target.parent.mkdir(parents=True, exist_ok=True)
            if path.suffix.lower() in ('.png', '.ogg', '.wav'):
                if not target.exists():
                    try:
                        os.link(path, target)
                    except OSError:
                        shutil.copy2(path, target)
            else:
                shutil.copy2(path, target)
        (mod / 'control.lua').write_text((source / 'control.lua').read_text('utf-8') + '\nDATA_SPIKE_FULL_TEST=true\nrequire("fixture")\n', encoding='utf-8')
        dependency_dir = Path(os.environ['APPDATA']) / 'Factorio/mods'
        for dependency in ['aai-programmable-vehicles', 'aai-signals', 'informatron']:
            candidates = list(dependency_dir.glob(dependency + '_*.zip'))
            if len(candidates) != 1:
                raise RuntimeError(f'Expected one installed {dependency} dependency, found {len(candidates)}')
            shutil.copy2(candidates[0], out / 'mods' / candidates[0].name)
            enabled.append(dependency)
    (out / 'mods/mod-list.json').write_text(json.dumps({'mods': [{'name': name, 'enabled': True} for name in enabled] + [{'name': name, 'enabled': args.full} for name in ('space-age', 'quality', 'elevated-rails', 'recycler')]}))
    user = out / 'user-data'
    user.mkdir(exist_ok=True)
    config = out / 'config.ini'
    config.write_text('[path]\nread-data=' + (args.factorio.parents[2] / 'data').as_posix() + '\nwrite-data=' + user.as_posix() + '\n[other]\ncheck-updates=false\n')
    common = [str(args.factorio), '--config', str(config), '--mod-directory', str(out / 'mods')]
    initial = out / 'initial.zip'
    pending = user / 'saves/_autosave-data-spike-pending.zip'
    for label, command in [('create', ['--create', str(initial)]),
                           ('impact', ['--test-save', str(initial), '--test-ticks', '5700']),
                           ('reload', ['--test-save', str(pending), '--test-ticks', '5700'])]:
        if label == 'reload':
            # --test-save suppresses autosaves; a separate hidden client
            # writes the real pending-claim save used by the reload test.
            pending.unlink(missing_ok=True)
            startup = subprocess.STARTUPINFO()
            startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startup.wShowWindow = 0
            environment = os.environ.copy()
            environment.update(SteamAppId='427520', SteamGameId='427520')
            graphical_log = out / 'save-pending.log'
            with graphical_log.open('w') as handle:
                process = subprocess.Popen(common + ['--load-game', str(initial), '--disable-audio'], stdout=handle, stderr=subprocess.STDOUT, startupinfo=startup, env=environment)
                try:
                    deadline = time.monotonic() + 150
                    while process.poll() is None and time.monotonic() < deadline:
                        if 'isolated handler failure' in graphical_log.read_text(errors='replace'):
                            break
                        if pending.exists():
                            time.sleep(2)
                            break
                        time.sleep(.5)
                finally:
                    if process.poll() is None:
                        process.terminate()
                        process.wait(timeout=15)
            if not pending.exists() or 'isolated handler failure' in graphical_log.read_text(errors='replace'):
                print(graphical_log.read_text(errors='replace')[-9000:]); return 1
            print('Saved native pending claims for separate-process reload', flush=True)
        log = out / (label + '.log')
        with log.open('w') as handle:
            result = subprocess.run(common + command, stdout=handle, stderr=subprocess.STDOUT, timeout=180)
        output = log.read_text(errors='replace')
        print(label, result.returncode, log, flush=True)
        if result.returncode or 'isolated handler failure' in output:
            print(output[-9000:]); return 1
        if label == 'impact' and '[TP-SPIKE] PENDING' not in output:
            print(output[-9000:]); return 1
        if label == 'impact' and '[TP-SPIKE] PASS' not in output:
            print(output[-9000:]); return 1
        if label == 'reload' and '[TP-SPIKE] PASS' not in output:
            print(output[-9000:]); return 1
    print('PASS native projectile attribution, research gate, timers, reload, pair and machine capture, removal and replacement')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
