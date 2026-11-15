"""Freeze the owner-accepted native placement without reworking its geometry."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def write(path,value):Path(path).write_text(json.dumps(value,indent=2)+'\n')


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--repo',required=True);ap.add_argument('--capture',required=True)
    ap.add_argument('--profile',required=True);ap.add_argument('--compressor',required=True)
    args=ap.parse_args();repo=Path(args.repo).resolve();cap=Path(args.capture).resolve();profile=Path(args.profile).resolve()
    out=repo/'art/source-to-3d/metallic-hydrogen-chain/electrolyzer/v06-owner-accepted-native'
    if out.exists():raise FileExistsError('Owner-accepted delivery is immutable')
    for name in ('qa.json','reopen-qa.json','native-fitting-readback.json'):
        if not json.loads((cap/name).read_text())['passed']:raise RuntimeError('Failed fitting/capture gate '+name)
    receipt=json.loads((profile/'native-jig-receipt.json').read_text())
    mod=profile/'mods/tp-mh7-electrolyzer-review_0.0.1'
    if not receipt['passed']:raise RuntimeError('Native pipe/flow fixture failed')
    for name,value in receipt['fixture_hashes'].items():
        if sha(mod/name)!=value:raise RuntimeError('Tested prototype bytes changed')
    raw=profile/'user-data/script-output/tp-mh7-electrolyzer-review'
    pictures={}
    from PIL import Image
    for file in sorted(raw.glob('*.png')):
        with Image.open(file) as im:im.load();pictures[file.name]=dict(sha256=sha(file),size=list(im.size))
    if len(pictures)!=8 or 'Goodbye' not in (profile/'graphics.log').read_text():raise RuntimeError('Incomplete actual graphical run')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    shutil.copytree(cap,out/'captures',ignore=shutil.ignore_patterns('*.log','checkpoint-*.json'))
    shutil.copytree(mod,out/'review-mod/tp-mh7-electrolyzer-review_0.0.1')
    shutil.copy2(profile/'native-jig-receipt.json',out/'native-jig-receipt.json')
    write(out/'native-visual-receipt.json',dict(status='OWNER_ACCEPTED_CURRENT_NATIVE_PLACEMENT',
        profile=str(profile),screenshots=pictures,local_screenshot_root=str(raw),
        user_instruction='Good enough, done',whole_sprite_shift_native_pixels=4,
        body_render_layer='lower-object',native_graphics_exit=0,
        note='Native screenshots containing base-game reference pixels stay local. Owner acceptance is separate from the automated physical receipt, whose graphical flag predates visual review.'))
    acceptance=dict(status='OWNER_ACCEPTED_ELECTROLYZER_MODEL_AND_CURRENT_NATIVE_PLACEMENT',
        owner_instruction='Good enough, done',shape_locked=True,placement_locked=True,
        native_capture_master_sha256=sha(cap/'master.blend'),
        native_source_capture_sha256=sha(cap/'capture.json'),
        original_editable_source='art/source-to-3d/metallic-hydrogen-chain/electrolyzer/v05-finish-and-states/electrolyzer-v05.blend',
        current_editable_native_source='captures/master.blend',
        final_profile=str(profile),whole_sprite_shift_native_pixels=4,body_render_layer='lower-object',
        native_connection_sites=32,orientations_with_real_split_flow=4,
        ordinary_mod_installed=False,full_chain_economy_integrated=False,
        next_shape_action='none; owner called current version done; move on to compressor')
    write(out/'ACCEPTANCE.json',acceptance)
    (out/'README.md').write_text('# Owner-accepted electrolyzer native placement\n\n'
        'The owner accepted the current electrolyzer after native pipe-alignment review: “Good enough, done”. Preserve this geometry and placement. The whole sprite is four native pixels below the initial placement, and the body uses the lower-object depth layer so native pipe graphics can draw at the joint. Earlier overextended/overlapping studies remain rejected local evidence.\n\n'
        'The editable native fitting source is `captures/master.blend`; original engineering source and GLB remain frozen in V05. Four actual directions and idle/working frames, six review atlases and the tested runnable review mod are included. The isolated Factorio 2.1.24 fixture passes all 32 connection/rotation cases and genuine separate hydrogen/oxygen output in all four rotations. Graphical screenshots and their hashes are recorded locally.\n\n'
        'This locks the model and reviewed native placement. It does not claim ordinary mod installation, final chain economy or completed reactors. Next model: hydrogen compressor.\n',encoding='utf-8')
    write(out/'SHA256.json',{p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file()})
    src=Path(args.compressor).resolve();compressor=repo/'art/source-to-3d/metallic-hydrogen-chain/hydrogen-compressor/v01-construction-pilot'
    if compressor.exists():raise FileExistsError('Preserve compressor checkpoint')
    compressor.mkdir(parents=True);(compressor/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    for name in ('compressor-v01.blend','working-front.png','construction-receipt.json','port_manifest.json','part_provenance.json'):shutil.copy2(src/name,compressor/name)
    write(compressor/'CHECKPOINT.json',dict(status='candidate_native; independent QA and finishing pending',
        source_sha256=sha(compressor/'compressor-v01.blend'),provenance='new reconstruction from authorized process packet',
        next=['independent mechanical support/moving clearance audit','actual GLB export/reimport and diagnostic renders','finishing and state capture','native prototype/pipe fitting'],owner_approved=False))
    (compressor/'README.md').write_text('# Compressor construction pilot\n\nDistinct editable 3x4 three-cylinder reciprocating compressor. Twin crank cheeks, interrupted main journals, phased connecting rods/crossheads, bearing-supported guarded flywheel, separate suction/discharge headers and three real donor instances. This is a saved/rendered construction pilot; independent QA, final finishing and integration remain open. Earlier local construction studies are retained.\n',encoding='utf-8')
    write(compressor/'SHA256.json',{p.relative_to(compressor).as_posix():sha(p) for p in sorted(compressor.rglob('*')) if p.is_file()})
    continuation_path=repo/'docs/art/metallic-hydrogen-chain/PRODUCTION_CONTINUATION.json'
    continuation=json.loads(continuation_path.read_text());continuation['current_machine']='hydrogen-compressor';continuation['current_candidate']=str(compressor)
    continuation['electrolyzer'].update(status='owner_accepted_model_and_reviewed_native_placement',owner_approved=True,native_ports_verified=True,
        accepted_delivery=str(out),whole_sprite_shift_native_pixels=4,body_render_layer='lower-object',next_shape_action='none; owner called done')
    continuation['electrolyzer']['next']=['ordinary chain integration later; do not restart accepted model refinement']
    continuation['compressor']=json.loads((compressor/'CHECKPOINT.json').read_text())
    for row in continuation['queue']:
        if row['id']=='electrolyzer':row['status']='owner_accepted_model_and_reviewed_native_placement'
        if row['id']=='hydrogen-compressor':row['status']='candidate_native; independent QA pending'
    continuation['next_steps']=['Refine and verify compressor construction','Continue remaining four precursor machines','Integrate chain prototypes/economy as a whole','Recover and refine three plasma reactors']
    write(continuation_path,continuation)
    print('ACCEPTED_ELECTROLYZER_LOCKED',out,'NEXT_COMPRESSOR',compressor,flush=True)


if __name__=='__main__':main()
