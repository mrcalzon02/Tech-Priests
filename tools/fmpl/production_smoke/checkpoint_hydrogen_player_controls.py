"""Package tested normal-game prototypes separately from destructive fixtures."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--repo',default='.');args=ap.parse_args();repo=Path(args.repo).resolve();build=repo/'build'
    candidate=build/'model-completion/metallic-hydrogen-chain/production-addon-v16-player-controls';validation=build/'hydrogen-player-controls-validation-01.json';report=json.loads(validation.read_text())
    if not report['passed'] or not report['native_ui_continuous_and_main_reload_identical'] or not all(report['native_ui_checks'].values()):raise RuntimeError('Actual player-control gates required')
    if report['build_receipt_sha256']!=sha(candidate/'BUILD_RECEIPT.json'):raise RuntimeError('Stale candidate')
    receipt=json.loads((candidate/'BUILD_RECEIPT.json').read_text())
    for folder,key in [('tp-hydrogen-production_0.1.0','production_addon_hashes'),('tp-mh7-pellet-decay_0.0.5','dependency_addon_hashes')]:
        for path,digest in receipt[key].items():
            if sha(candidate/folder/path)!=digest:raise RuntimeError('Changed tested runtime '+path)
    out=repo/'art/source-to-3d/metallic-hydrogen-chain/ordinary-integration/v01-player-controls'
    if out.exists():raise FileExistsError('Preserve deliveries')
    out.mkdir(parents=True);mods=out/'prototype-mods';mods.mkdir()
    for source in candidate.iterdir():
        if source.is_dir() and (source/'info.json').exists():shutil.copytree(source,mods/source.name)
    for p in mods.rglob('*.lua'):
        if 'storage.ui_review' in p.read_text(encoding='utf-8') or 'tp-hydrogen-player-review/' in p.read_text(encoding='utf-8'):raise RuntimeError('Fixture leaked into production')
    shutil.copy2(candidate/'BUILD_RECEIPT.json',out/'BUILD_RECEIPT.json')
    inspection=out/'inspection';inspection.mkdir()
    for source,name in [(validation,validation.name),(build/'hui-07/controls-receipt.json','continuous-player-controls.json'),(build/'hui-rm-08/controls-receipt.json','main-reloaded-player-controls.json'),(build/'hui-chain-02/chain-receipt.json','main-connected-chain.json')]:shutil.copy2(source,inspection/name)
    fixtures=out/'fixtures';fixtures.mkdir()
    for source in [build/'hui-rm-08/mods/tp-hydrogen-player-review_0.0.1',build/'hui-chain-02/mods/tp-hydrogen-chain-review_0.0.1']:shutil.copytree(source,fixtures/source.name)
    (out/'README.md').write_text('''# Seven-machine production prototype with player controls

Copy the two directories inside `prototype-mods` into the Factorio mods directory to use this isolated production prototype alongside Tech Priests. Research **Metallicized hydrogen production** to unlock the seven machines. This delivery is not installed automatically into the real mod. `fixtures` contains destructive fresh-world tests and is separate from production; do not enable it in a valued save.

The normal prototype uses real electricity, water, steel, pipes and ordinary anywhere-on-building inserter access. It purifies, electrolyzes, compresses and metallizes hydrogen, forms the unstable pellets, hydroforms pressure shells from welded/clamped plates, and seals formed pellets into those shells. Uncontained raw and formed pellets lose integrity and quality until inert. Containment preserves the exact remaining lifetime and original shell condition.

Open the forge or assembler for material controls. Click your inventory to pick up a real stack, then an empty input slot to load it. Click waiting material or output to collect it; Shift-click collects into your inventory. Active press material and reserved shell stacks remain clamped until their operation finishes. Tooltips show quality, integrity and decay time. The native internal clock/filter/presentation recipes are not shown in these windows.

Fifteen actual native checks cover opening the real entity GUI, exact material round trips, wrong-material rejection, unrelated-window and reach guards, automatic out-of-reach closure, active forge/assembler locks, full inventories, repeated collection, contained metadata preservation, native decay while open, and exact original lifetime/shell recovery. A real active-job/UI save at tick 600 reloads with results identical to continuous execution, including alongside the published main mod. Click handlers receive actual Lua GUI elements and real player/cursor inventories; separate physical mouse automation and two simultaneously connected players are not claimed. Native GUI images were inspected privately and only their hashes are included.

The complete seven-machine line still collects six contained pellets from only water, steel and electricity. All 105 art/audio/spec files and all seven native visual prototype definitions are unchanged from the preceding exact-clock checkpoint. No building geometry, pipe fitting, capture camera or animation cadence was revised for these controls. The purifier is closed by the owner; preserve it.

Power, construction costs and research values are documented starting prototype tuning. Working graphics and sound use the engine's per-entity phase offsets with the verified source cycle lengths; exact per-instance press/seal/audio phase alignment is not asserted. Final game economy balancing is a separate tuning task, not a claim of this art/prototype checkpoint.

`BUILD_RECEIPT.json` records bytes at generation time. `inspection` records the subsequent actual validation. Rebuild and test with the corresponding tools under `tools/fmpl/production_smoke`. The reactor source/refinement and remaining sprite-only building work remain in the full goal.
''',encoding='utf-8')
    (out/'DELIVERY.json').write_text(json.dumps(dict(status='tested production prototype; full model goal remains active',validation_sha256=sha(validation),fixture_controls_in_normal_addons=False,owner_approved=False,files={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file()}),indent=2)+'\n')
    print('HYDROGEN_PLAYER_CONTROLS_CHECKPOINT',out)


if __name__=='__main__':main()
