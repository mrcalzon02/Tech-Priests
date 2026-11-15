"""Preserve actual tested decay behavior and a safe prototype event adapter."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,d):Path(p).write_text(json.dumps(d,indent=2)+'\n')


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--normal',required=True);ap.add_argument('--reload',required=True);ap.add_argument('--out',required=True);ap.add_argument('--version',default='0.0.1');args=ap.parse_args()
    normal=Path(args.normal);reload=Path(args.reload);out=Path(args.out);src=Path(__file__).with_name('pellet_decay_review')
    if out.exists():raise FileExistsError('Preserve decay revisions')
    reports=[json.loads((p/'native-decay-readback.json').read_text()) for p in (normal,reload)]
    if any(not r['passed'] for r in reports) or not reports[1]['save_reload_exercised']:raise RuntimeError('Native behavior gate')
    # runtime.lua is the safe event adapter; accelerated control.lua is fixture-only.
    for report in reports:
        for name in ('config.lua','data.lua','decay.lua','control.lua'):
            if sha(src/name)!=report['source_hashes'][name]:raise RuntimeError('Changed tested module '+name)
    if reports[0]['behavior']['histories']!=reports[1]['behavior']['histories']:raise RuntimeError('Save/reload behavior differs')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    shutil.copytree(src,out/'source')
    mod=out/('review-mod/tp-mh7-pellet-decay_'+args.version);mod.mkdir(parents=True)
    for name in ('config.lua','data.lua','decay.lua'):shutil.copy2(src/name,mod/name)
    shutil.copy2(src/'runtime.lua',mod/'control.lua')
    write(mod/'info.json',dict(name='tp-mh7-pellet-decay',version=args.version,title='Metallicized pellet instability prototype',author='Tech Priests',factorio_version='2.1',
        dependencies=['base >= 2.1.24','quality >= 2.1.24'],expansion_required=True,quality_required=True,spoiling_required=True))
    for name,path in (('native-continuous.json',normal),('native-save-reload.json',reload)):shutil.copy2(path/'native-decay-readback.json',out/name)
    contract=dict(status='native_behavior_verified; chain_recipe_and_machine_integration_pending',
        owner_requirement='Raw metallicized pellets leave the crucible with a random decay cooldown that reduces both HP and quality and ends as inert pellets; rush them into suitable containment.',
        output_kind='solid item, not a second gameplay fluid box',raw_item='tp-mh7-raw-metallicized-pellet',inert_item='tp-mh7-inert-pellet',
        prototype_tuning=dict(random_step_seconds=[15,30],steps=4,total_uncontained_seconds=[60,120],health=[1,.75,.5,.25,0],quality='One native tier down per decay transition, floor normal; terminal inert is always normal'),
        randomization='Separate native spoil deadline per individual raw pellet; tagged, nonstacking raw units prevent timer refresh through merge/split',
        containment='Requires an actual empty pressure shell. Sealing preserves HP, quality, phase and remaining lifetime. Unsealing resumes that remaining lifetime and returns the same shell condition/quality. No restoration of decayed/inert pellets.',
        verified=['Independent random cooldowns','Actual item health and native quality decrease','Chest-to-chest movement preserves timer/condition','Belt, ground, inserter, character and registered script inventories','Inert terminal, non-fuel, cannot be revived by containment','Shell consumption and state-conserving return','Paused containment and resumed remaining lifetime','Actual save/reload history equals continuous run'],
        normal_adapter='No test scenario creation or world clearing. Registers the provisional native crucible prototype when present and exposes sealing operations for the planned canister assembler.',
        limitations=['Current icons are base-game prototype placeholders; no base-game image bytes redistributed','Normal timing is initial configurable prototype tuning, not owner-approved balancing','Final crucible/forge/canister recipes and full ordinary mod integration remain open'],owner_balance_approved=False)
    write(out/'CONTRACT.json',contract)
    (out/'README.md').write_text('# Raw metallicized pellet instability prototype\n\n'
        'The crucible output is now specified as **raw solid pellets**. Four independent randomized decay steps lower actual item HP from 100% to 75%, 50%, 25%, then inert at 0%. Native Factorio 2.1 quality drops one tier at each transition, with normal as the floor; terminal inert pellets are always normal quality and have no fuel value. Initial configurable tuning is 15–30 seconds per step (60–120 seconds total uncontained). Raw pellets are individual tagged units so logistics cannot refresh their timers by merging or splitting stacks.\n\n'
        'Appropriate containment consumes an empty pressure shell and preserves the current phase, HP, quality and remaining cooldown. It repairs nothing. Opening it resumes the saved remaining time and returns the original shell condition/quality. Inert pellets cannot be sealed back into useful fuel. The sealing API is for the planned canister assembler; its final recipe/model integration is still open.\n\n'
        'Actual Factorio 2.1.24 tests pass separate random deadlines, HP/quality loss, movement without timer refresh, belt/ground/inserter/character/script inventories, inert conversion, containment and unsealing. A real save at tick 200 and resumed run produces the same full recorded history as an uninterrupted run. Accelerated fixture timing is 60–150 ticks per step; gameplay configuration remains 15–30 seconds.\n\n'
        'The included review add-on uses the safe runtime event adapter; it creates no fixtures and clears no world area. The separate source control.lua is an isolated behavior test, not the add-on entry point. Quality/spoilage require the installed expansion features. Placeholder icons reference installed base-game files; final item art and ordinary chain integration remain pending.\n',encoding='utf-8')
    write(out/'SHA256.json',{p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    print('PELLET_DECAY_PACKAGED',out,flush=True)


if __name__=='__main__':main()
