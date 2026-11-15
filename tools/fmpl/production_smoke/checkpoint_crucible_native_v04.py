"""Freeze the restrained crucible native prototype, placement and production proof."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image,ImageChops


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,d):Path(p).write_text(json.dumps(d,indent=2)+'\n')


def main():
    ap=argparse.ArgumentParser()
    for name in ('profile','capture','diagnostic','decay','normal-addon'):ap.add_argument('--'+name,required=True)
    ap.add_argument('--repo',default='.');args=ap.parse_args();repo=Path(args.repo).resolve();profile=Path(args.profile).resolve();cap=Path(args.capture).resolve();diag=Path(args.diagnostic).resolve();decay=Path(args.decay).resolve()
    out=repo/'art/source-to-3d/metallic-hydrogen-chain/metallization-crucible/v04-native-production'
    if out.exists():raise FileExistsError('Preserve native checkpoints')
    receipt=json.loads((profile/'native-jig-receipt.json').read_text());clock=json.loads((diag/'native-clock-readback.json').read_text());spec=json.loads((profile/'spec.json').read_text())
    if not receipt['passed'] or receipt.get('diagnostic_frame_counters') or not clock['native_frames_advance_all_directions']:raise RuntimeError('Native production/animation gate')
    if receipt['fixture_hashes']!=clock['fixture_hashes']:raise RuntimeError('Clock diagnostic uses a different runtime')
    for name in ('qa.json','reopen-qa.json','native-fitting-readback.json'):
        if not json.loads((cap/name).read_text())['passed']:raise RuntimeError('Actual native capture gate '+name)
    mod=profile/'mods/tp-mh7-crucible-review_0.0.1';diagnostic=diag/'mods/tp-mh7-crucible-review_0.0.1'
    # Confirm the only diagnostic image difference is the temporary counter.
    for name in receipt['graphic_hashes']:
        with Image.open(mod/'graphics'/name) as final,Image.open(diagnostic/'graphics'/name) as marked:
            marked=marked.copy()
            for i in range(8):
                x=i%4*256+12;y=i//4*256+12;marked.paste(final.crop((x,y,x+8,y+8)),(x,y))
            difference=ImageChops.difference(final,marked)
            if difference.convert('RGB').getbbox() or difference.getchannel('A').getbbox():raise RuntimeError('Unexpected diagnostic artwork difference '+name)
    shots=profile/'user-data/script-output/tp-mh7-crucible-review'
    if len(list(shots.glob('*.png')))!=44:raise RuntimeError('Missing actual final native views')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    shutil.copytree(mod,out/'review-mod'/mod.name);shutil.copytree(cap,out/'captures',ignore=shutil.ignore_patterns('*.log','checkpoint-*.json'))
    shutil.copy2(profile/'native-jig-receipt.json',out/'native-jig-receipt.json');shutil.copy2(diag/'native-clock-readback.json',out/'native-clock-readback.json');shutil.copy2(profile/'spec.json',out/'spec.json')
    native_views=dict(profile=str(profile),screenshots={p.name:sha(p) for p in sorted(shots.glob('*.png'))},graphics_log_sha256=sha(profile/'graphics.log'),
        review='Four actual inlet joins and item pickup orientations inspected. Native body lowered from +4 to +7 pixels after owner found the first fit mismatched. Source proportions and all coaxial reducer geometry preserved.',
        publication='Base-game reference pixels stay private; only their hashes are published.')
    write(out/'native-view-receipt.json',native_views)
    checkpoint=dict(status='native_production_verified; restrained_animation_accepted',source_delivery='../v03-finish-and-states',source_sha256=receipt['model_source_sha256'],capture_master_sha256=sha(cap/'master.blend'),
        native_input_cases=8,native_fluid_box_count=1,actual_item_pickup_orientations=4,actual_produced_pellet_decay_verified=True,blocked_machine_output_decays=True,
        actual_produced_pellet_containment_verified=True,native_audio_binding_verified=True,whole_sprite_shift_native_pixels=7,body_render_layer='object',
        owner_instruction="We're good Not every every building has to be intricately animated. its okay",owner_accepted_restrained_animation=True,
        next_shape_action='none; preserve restrained fan/readout and current model. Continue forge.',
        native_frames_advance_all_directions=True,uninterrupted_eight_second_loops=[r['direction'] for r in clock['rows'] if r['passed']],
        strict_cadence_all_directions=clock['passed'],clock_note='All four directions advance through real source cells. East/west complete uninterrupted eight-second loops; north/south contain a held sample in the production capture. Strict all-direction cadence diagnostic remains false, not relabeled as a pass.',
        ordinary_chain_integrated=False,gameplay_balanced=False,fixture_quality='Legendary output is clamped solely to exercise native quality loss; this is not an economy recipe.',
        next=['Build/refine pelletization forge with state-preserving processing','Complete pressure-vessel fabricator and canister assembler','Integrate chain and recover/refine reactor sources'])
    write(out/'CHECKPOINT.json',checkpoint)
    (out/'README.md').write_text('# Crucible native production checkpoint\n\n'
        'The owner accepted restrained animation and directed no further intricate motion. Preserve the six seated fan blades, status movement and current engineering model. Actual native input alignment was lowered three additional pixels to +7 overall, with normal object depth and unchanged body proportions/coaxial reducers. The editable native-fitting master, 36 actual state/orientation frames and six atlases are included; engineering source/GLB and original sound remain in V03 and the audio supplement.\n\n'
        'Factorio 2.1.24 passes eight connected/disconnected input/rotation cases. There is exactly one fluid box; a pipe placed at the pellet-transfer edge does not connect. Real inserters collect actual produced solid pellets in all four orientations. Those pellets receive separate random deadlines, lose real HP and quality and become inert; even blocked machine output decays. Actual produced pellets sealed in pressure shells remain stable without healing. Native pressure/cooling sound loads at the intended .65 gain. The fixture deliberately clamps output to legendary to prove quality loss; it is not final balancing.\n\n'
        'Native states now use eight working frames and the source eight-second rate. A private per-cell counter proves visible source-frame advancement in every direction. East/west complete uninterrupted eight-second loops; north/south include a held sample. The strict all-direction cadence report remains false and is preserved honestly. Counter graphics are excluded from this final mod. Base-game graphical views remain private with hashes.\n\n'
        'Use the isolated fresh-world review runner with pellet-decay 0.0.2 and the crucible-audio add-on. This fixture is separate from ordinary mod/economy integration. Continue the forge; do not add ornamental animation or restart the closed model review.\n',encoding='utf-8')
    # Add production evidence to the new decay revision; V01 remains immutable.
    shutil.copy2(args.normal_addon,decay/'normal-addon-readback.json')
    for name in ('production','decay-integration'):shutil.copy2(shots/(name+'.json'),decay/(name+'.json'))
    contract=json.loads((decay/'CONTRACT.json').read_text());contract.update(production_pickup_race_fixed=True,
        production_observation='Registered producer output plus local transport only when completed production changes. Existing native age is subtracted before assigning a random deadline, preventing late discovery from refreshing a pellet.',
        native_crucible_integration='Four actual production/pickup/decay/containment orientations and uncontained blocked output pass',normal_adapter_verified=True)
    write(decay/'CONTRACT.json',contract)
    with (decay/'README.md').open('a',encoding='utf-8') as handle:handle.write('\nProduction pickup revision: an actual native inserter exposed pellets leaving before output polling. Completed production now triggers a local transport check, with existing material age conserved. The crucible fixture passes real production-to-inserter transport, separate randomized cooldowns, HP/quality loss, inert conversion, shell containment and decay in blocked machine output in all four rotations. Normal-timing add-on load also passes.\n')
    for root in (out,decay):write(root/'SHA256.json',{p.relative_to(root).as_posix():sha(p) for p in sorted(root.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    path=repo/'docs/art/metallic-hydrogen-chain/PRODUCTION_CONTINUATION.json';d=json.loads(path.read_text());d['current_machine']='pelletization-forge';d['current_candidate']=None;d['crucible'].update(checkpoint);d['crucible']['native_delivery']=str(out)
    d['pellet_instability'].update(path=decay.relative_to(repo).as_posix(),native_crucible_production_verified=True,production_pickup_race_fixed=True)
    d['machinery_audio']['native_bindings_verified']=4
    for row in d['queue']:
        if row['id']=='metallization-crucible':row['status']='native production/decay/pickup/audio verified; restrained animation accepted; move to forge'
    d['next_steps']=checkpoint['next'];write(path,d);print('CRUCIBLE_NATIVE_CHECKPOINT',out,flush=True)


if __name__=='__main__':main()
