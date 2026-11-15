"""Freeze real forge behavior/clock proof while retaining graphical-fit limits."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image,ImageChops


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,data):Path(p).write_text(json.dumps(data,indent=2)+'\n')


def main():
    ap=argparse.ArgumentParser()
    for name in ('profile','reload','diagnostic','decay','normal-addon','crucible-regression'):ap.add_argument('--'+name,required=True)
    ap.add_argument('--repo',default='.');args=ap.parse_args();repo=Path(args.repo).resolve();profile=Path(args.profile).resolve();reload=Path(args.reload).resolve();diag=Path(args.diagnostic).resolve();decay=Path(args.decay).resolve()
    out=repo/'art/source-to-3d/metallic-hydrogen-chain/pelletization-forge/v04-native-preservation'
    if out.exists():raise FileExistsError('Preserve native checkpoints')
    normal=json.loads((profile/'native-jig-receipt.json').read_text());resumed=json.loads((reload/'native-jig-receipt.json').read_text());clock=json.loads((diag/'native-clock-readback.json').read_text())
    if not normal['passed'] or not resumed['passed'] or not resumed['save_reload_exercised'] or normal['results']!=resumed['results']:raise RuntimeError('Native/reload behavior gate')
    if normal['diagnostic_frame_counters'] or not clock['passed'] or normal['fixture_hashes']!=clock['fixture_hashes']:raise RuntimeError('Clean/clock runtime differs')
    mod=profile/'mods/tp-mh7-forge-review_0.0.1';marked=diag/'mods/tp-mh7-forge-review_0.0.1'
    for name in normal['graphic_hashes']:
        with Image.open(mod/'graphics'/name) as final,Image.open(marked/'graphics'/name) as counter:
            counter=counter.copy()
            if final.size==(1024,512):
                for i in range(8):
                    x=i%4*256+12;y=i//4*256+12;counter.paste(final.crop((x,y,x+8,y+8)),(x,y))
            difference=ImageChops.difference(final,counter)
            if difference.convert('RGB').getbbox() or difference.getchannel('A').getbbox():raise RuntimeError('Unexpected counter artwork difference '+name)
    shots=profile/'user-data/script-output/tp-mh7-forge-review';requested=json.loads((shots/'screenshots.json').read_text())['requested']
    if len(requested)!=72 or len(list(shots.glob('*.png')))!=72:raise RuntimeError('Missing actual final native views')
    for row in requested:
        with Image.open(profile/'user-data/script-output'/row['path']) as im:
            if im.size!=(900,900):raise RuntimeError('Wrong actual native view')
    baseline=json.loads(Path(args.crucible_regression).read_text());safe=json.loads(Path(args.normal_addon).read_text())
    if not baseline['passed'] or not safe['passed']:raise RuntimeError('Crucible/normal safe-adapter regression')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    shutil.copytree(mod,out/'isolated-review-mod'/mod.name)
    shutil.copytree(mod,out/'prototype-mod'/mod.name,ignore=shutil.ignore_patterns('control.lua'))
    for name in ('spec.json','native-jig-receipt.json'):shutil.copy2(profile/name,out/name)
    shutil.copy2(reload/'native-jig-receipt.json',out/'native-save-reload.json');shutil.copy2(diag/'native-clock-readback.json',out/'native-clock-readback.json')
    shutil.copy2(args.crucible_regression,decay/'crucible-regression.json');shutil.copy2(args.normal_addon,decay/'normal-addon-readback.json')
    views=dict(screenshots={p.name:sha(p) for p in sorted(shots.glob('*.png'))},requested=requested,graphics_log_sha256=sha(profile/'graphics.log'),
        inspection='Actual clean idle/working screenshots exist in four genuinely retained native entity orientations. Source proportions and sprite scale are unchanged. High hopper versus ground-level native inserter handoff still needs graphical interface refinement; this is not owner acceptance.',
        publication='Native images contain base-game pixels and remain private; only hashes are published.')
    write(out/'native-view-receipt.json',views)
    checkpoint=dict(status='native_processing_decay_clock_audio_verified; graphical_item_handoff_and_ordinary_chain_pending',engineering_delivery='../v03-finish-and-states',source_sha256=normal['model_source_sha256'],
        native_sites=24,orientations=4,gameplay_fluid_boxes=0,processing_cases=['state-conserving fresh formation','real decay during processing','inert during processing','blocked decaying output','formed containment/unseal','four sequential mixed-quality inputs per direction'],
        native_cycle_ticks=480,dispatch_overhead_ticks=1,save_reload_identical=True,damaged_stock_never_heals=True,normal_build_event_registration_verified=True,live_stock_released_on_destroy=True,
        native_eight_cells_all_directions=True,native_source_frame_period_ticks=60,native_full_loop_boundary_observed=False,native_audio_binding_verified=True,
        owner_approved=False,ordinary_chain_integrated=False,graphical_item_handoff_verified=False,
        next=['Refine native item handoff: tall hopper receiving point versus standard inserter hand position; preserve source proportions and real process path','Complete player-facing chain/UI/economy integration without exposing clock/filter recipes','Build vessel fabricator and canister assembler; recover/refine three reactors'])
    write(out/'CHECKPOINT.json',checkpoint)
    (out/'README.md').write_text('# Forge native state-preservation checkpoint\n\nActual Factorio 2.1.24 tests pass 24 sites across four real entity orientations. Real inserters feed and collect current-state forged pellets. The native eight-second driver consumes only a private non-pellet token; live stock remains in a registered inventory and keeps decaying. Disabled dispatch recipes configure the output inventory for its current phase/quality, then the exact current HP, quality, tags and native deadline are copied. Expired work leaves inert. Four sequential mixed-quality units per direction are processed without refresh, healing, duplication or jams. The default native orientation was initially discarded for an item-only machine; a true forward item-egress vector now retains all four directions, with zero gameplay fluid boxes.\n\nThe due-only instability scheduler uses real LuaItem references across logistics and calls native spoilage at its exact deadline, retaining damage ceilings/custom tags that native result replacement would otherwise discard. Damaged chest/belt/ground/inserter/character/work-unit histories and full forge results are identical after an actual save at tick 200 and reload. Formed output decays while blocked; sealing/unsealing preserves remaining lifetime and shell condition. Destroying a working forge releases its live original stock. The safe normal adapter and unchanged accepted crucible both pass regression runs.\n\n72 clean native snapshots were inspected privately. Separate temporary per-cell counters prove all eight cells at one cell per second in each of the four directions. Source/GLB separately prove loop closure; the stopped single native craft does not prove a continuous native loop boundary. Counter pixels are excluded. Actual authored sound binding loads at .70 gain; owner audition is not inferred.\n\nGraphical item handoff remains open: the tall hopper receiving point and standard ground-level inserter hand position need refinement. Native physics, source proportions and clock success do not certify that visual interface. Ordinary chain/economy and player-facing UI remain open; hidden clock/filter/dispatch recipes are internal prototype machinery.\n\nInstall the **prototype-mod** with pellet-decay 0.0.3 and the forge-audio add-on for safe manual placement; this version has no control.lua and creates no scenario or test items. The separate **isolated-review-mod** contains the destructive fresh-world test fixture and must only be used in the isolated runner. Native images contain base-game pixels and remain private with published hashes.\n',encoding='utf-8')
    contract=json.loads((decay/'CONTRACT.json').read_text());contract.update(normal_adapter_verified=True,native_crucible_regression_verified=True,actual_native_forge_orientations_verified=True,production_pickup_race_fixed=True);write(decay/'CONTRACT.json',contract)
    for root in (out,decay):write(root/'SHA256.json',{p.relative_to(root).as_posix():sha(p) for p in sorted(root.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    path=repo/'docs/art/metallic-hydrogen-chain/PRODUCTION_CONTINUATION.json';d=json.loads(path.read_text());d['current_machine']='pelletization-forge';d['current_candidate']=str(out);d['forge'].update(checkpoint);d['forge']['native_delivery']=str(out)
    d['pellet_instability'].update(path=decay.relative_to(repo).as_posix(),forge_native_processing_verified=True,damaged_stock_never_heals=True,native_quality_decay_preserved=True)
    d['machinery_audio']['native_bindings_verified']=5
    for row in d['queue']:
        if row['id']=='pelletization-forge':row['status']='source/art/native state preservation and sound verified; graphical item handoff plus ordinary integration open'
    d['next_steps']=checkpoint['next'];write(path,d);print('FORGE_NATIVE_CHECKPOINT',out,flush=True)


if __name__=='__main__':main()
