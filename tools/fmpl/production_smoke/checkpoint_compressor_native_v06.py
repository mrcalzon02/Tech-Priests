"""Freeze the owner-approved compressor native depth profile without rewriting V05."""
import hashlib
import json
from pathlib import Path
import shutil
import argparse


def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,d): Path(p).write_text(json.dumps(d,indent=2)+'\n')


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--profile',required=True);ap.add_argument('--repo',default='.');args=ap.parse_args()
    repo=Path(args.repo).resolve();profile=Path(args.profile).resolve()
    prior=repo/'art/source-to-3d/metallic-hydrogen-chain/hydrogen-compressor/v05-slow-and-audio'
    out=prior.parent/'v06-owner-accepted-native'
    if out.exists(): raise FileExistsError('Preserve accepted checkpoints')
    receipt=json.loads((profile/'native-jig-receipt.json').read_text());spec=json.loads((profile/'spec.json').read_text())
    if not receipt['passed'] or spec['body_render_layer']!='object' or spec['rear_collar_layer']: raise RuntimeError('Wrong accepted depth profile')
    shots=profile/'user-data/script-output/tp-mh7-compressor-review'
    if len(list(shots.glob('*.png')))!=44: raise RuntimeError('Native graphical evidence missing')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    shutil.copytree(profile/'mods/tp-mh7-compressor-review_0.0.1',out/'review-mod/tp-mh7-compressor-review_0.0.1')
    shutil.copy2(profile/'native-jig-receipt.json',out/'native-jig-receipt.json');shutil.copy2(profile/'spec.json',out/'spec.json')
    checkpoint=dict(status='owner_accepted_native_pipe_placement',owner_instruction='fixed !',owner_native_placement_approved=True,
        approved_scope='Corrected compressor top-port seam and four-direction native fitting; preserve shape, source, eight-second capture and sound bank.',
        source_delivery='../v05-slow-and-audio',source_sha256=receipt['model_source_sha256'],capture_master_sha256=sha(prior/'native-captures/master.blend'),
        body_render_layer='object',whole_sprite_shift_native_pixels=4,rear_collar_overlay=False,cycle_seconds=8,
        native_physical_and_flow_passed=True,native_ports_verified=True,graphical_seating_verified=True,
        top_port='Owner accepted corrected normal-object-depth placement: fixed !',
        next=['Preserve accepted visual placement; ordinary chain integration, exact native frame clock and owner audio audition remain'],
        native_animation_clock_verified=False,owner_animation_observation='All appeared to animate correctly',
        owner_audio_approved=False,ordinary_chain_integrated=False,
        private_native_evidence=dict(profile=str(profile),screenshots={p.name:sha(p) for p in sorted(shots.glob('*.png'))},log_sha256=sha(profile/'graphics-native.log')))
    write(out/'CHECKPOINT.json',checkpoint)
    (out/'README.md').write_text('# Compressor native placement accepted\n\n'
        'The owner accepted the corrected top-port fitting: **“fixed !”**. The compressor body uses normal `object` depth, allowing the rear pipe to sit behind the receiving neck while the front pipe remains visible. The separate rear-collar overlay is excluded. Preserve this profile; do not restart speculative alignment changes.\n\n'
        'The editable engineering source, eight-second GLB, actual four-direction idle/working capture masters, frames and atlases remain in [V05](../v05-slow-and-audio/README.md). This checkpoint changes native draw depth only. All 16 physical pipe-mask/rotation sites and four actual output-flow orientations pass. Four native views were inspected and their private screenshot hashes bind this checkpoint. Native screenshots containing base-game art are not redistributed.\n\n'
        'Use the included review prototype with the [audio-only extension](../../../shared-audio/hydrogen-machinery/v01/README.md). The owner observed correct-looking animation; exact native frame-clock proof and audio audition remain separate. Ordinary chain/economy integration is still required.\n',encoding='utf-8')
    write(out/'SHA256.json',{p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    cont=repo/'docs/art/metallic-hydrogen-chain/PRODUCTION_CONTINUATION.json';d=json.loads(cont.read_text())
    d['compressor'].update(checkpoint);d['compressor']['accepted_delivery']=str(out);d['current_machine']='metallization-crucible';d['current_candidate']=None
    for row in d['queue']:
        if row['id']=='hydrogen-compressor':row['status']='owner_accepted_native_pipe_placement; eight-second source/captures and audio preserved'
    d['next_steps']=['Build and refine metallization crucible with relevant machine audio','Complete pelletization forge, vessel fabricator and canister assembler','Integrate chain prototypes/economy and exact native clocks','Recover and refine three plasma reactors including sound']
    write(cont,d);print('COMPRESSOR_NATIVE_PLACEMENT_ACCEPTED',out)


if __name__=='__main__':main()
