"""Freeze native fabricator production, fitted captures and actual clock proof."""
import argparse
import json
from pathlib import Path
import shutil
from PIL import Image,ImageChops
from run_compressor_native_jig import sha


def write(path,value):Path(path).write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')


def main():
    ap=argparse.ArgumentParser()
    for key in ('profile','reload','diagnostic','capture'):ap.add_argument('--'+key,required=True)
    ap.add_argument('--repo',default='.');args=ap.parse_args();repo=Path(args.repo).resolve();profile=Path(args.profile).resolve();resumed=Path(args.reload).resolve();diag=Path(args.diagnostic).resolve();capture=Path(args.capture).resolve()
    out=repo/'art/source-to-3d/metallic-hydrogen-chain/pressure-vessel-fabricator/v04-native-review'
    if out.exists():raise FileExistsError('Preserve native checkpoints')
    normal=json.loads((profile/'native-jig-receipt.json').read_text());reload=json.loads((resumed/'native-jig-receipt.json').read_text());clock=json.loads((diag/'native-clock-readback.json').read_text());cap=json.loads((capture/'capture.json').read_text());fitting=json.loads((capture/'native-fitting-readback.json').read_text())
    if not normal['passed'] or not reload['passed'] or not reload['save_reload_exercised'] or normal['results']!=reload['results'] or normal['fixture_hashes']!=reload['fixture_hashes']:raise RuntimeError('Native production/reload gate')
    if not clock['passed'] or not clock['full_loop_boundary_observed'] or normal['fixture_hashes']!=clock['fixture_hashes']:raise RuntimeError('Actual twelve-second clock gate')
    if normal['diagnostic_frame_counters'] or not fitting['passed'] or fitting['master_sha256']!=sha(capture/'master.blend') or fitting['source_sha256']!=normal['model_source_sha256']:raise RuntimeError('Clean/fitting gate')
    if normal['capture_sha256']!=sha(capture/'capture.json') or cap['source_sha256']!=normal['model_source_sha256']:raise RuntimeError('Source/capture mismatch')
    for name in ('qa.json','reopen-qa.json'):
        if not json.loads((capture/name).read_text())['passed']:raise RuntimeError('Capture gate '+name)
    mod=profile/'mods/tp-mh7-fabricator-review_0.0.1';marked=diag/'mods/tp-mh7-fabricator-review_0.0.1'
    for name in normal['graphic_hashes']:
        if sha(mod/'graphics'/name)!=normal['graphic_hashes'][name]:raise RuntimeError('Native graphic changed')
        with Image.open(mod/'graphics'/name) as final,Image.open(marked/'graphics'/name) as counter:
            counter=counter.copy()
            if final.size==(1024,768):
                for index in range(12):
                    x=index%4*256+12;y=index//4*256+12;counter.paste(final.crop((x,y,x+8,y+8)),(x,y))
            delta=ImageChops.difference(final,counter)
            if delta.convert('RGB').getbbox() or delta.getchannel('A').getbbox():raise RuntimeError('Unexpected counter graphic delta')
    for direction,row in (('north',0),('east',3),('south',2),('west',1)):
        for state in ('idle','working'):
            with Image.open(mod/'graphics'/(state+'-'+direction+'.png')) as sheet:
                for index in range(12):
                    with Image.open(capture/f'frames/{state}/d{row:02d}/f{0 if state=="idle" else index:03d}.png') as frame:
                        tile=sheet.crop((index%4*256,index//4*256,index%4*256+256,index//4*256+256))
                        if tile.tobytes()!=frame.tobytes():raise RuntimeError('Source/native cell mismatch')
    shots=profile/'user-data/script-output';requested=json.loads((shots/'tp-mh7-fabricator-review/screenshots.json').read_text())['requested']
    if len(requested)!=228:raise RuntimeError('Missing native screenshot requests')
    for row in requested:
        with Image.open(shots/row['path']) as image:
            if image.size!=(900,900):raise RuntimeError('Missing/wrong native screenshot')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    shutil.copytree(mod,out/'isolated-review-mod'/mod.name)
    shutil.copytree(mod,out/'prototype-mod'/mod.name,ignore=shutil.ignore_patterns('control.lua'))
    shutil.copytree(capture,out/'captures',ignore=shutil.ignore_patterns('*.log','checkpoint-*.json'))
    for name in ('native-jig-receipt.json','spec.json'):shutil.copy2(profile/name,out/name)
    shutil.copy2(resumed/'native-jig-receipt.json',out/'native-save-reload.json');shutil.copy2(diag/'native-clock-readback.json',out/'native-clock-readback.json')
    write(out/'native-view-receipt.json',dict(requested=requested,screenshots={row['path']:sha(shots/row['path']) for row in requested},graphics_log_sha256=sha(profile/'graphics.log'),
        inspection='Actual clean four-direction connected/disconnected and working views inspected; rigid mouth/reducer, straight axial receiving extension, correct off-center native row, normal object layer and +4px body shift. No pipe gap or hidden attached pipe remains in the reviewed views.',
        publication='Native screenshot bytes contain base-game pixels and remain private. Only own captures/prototype art and native screenshot hashes are published.'))
    port=dict(id='forming_fluid_intake',fluid='water',fluid_identity_final=False,production_type='input',native_position=[-1.5,-.5],native_direction='west',native_target=[-2.5,-.5],effective_plane=[-2,-.5],engineering_model_mouth_center=[-2,.5,.36],model_outward_normal=[-1,0,0],native_axis_note='Model +Y projects toward native screen north; off-center native row is -0.5.',native_physical_connection_verified=True,agent_native_graphical_review=True,owner_approved=False)
    write(out/'port_manifest.json',dict(machine='pressure-vessel-fabricator',footprint=[4,4],ports=[port],native_target='tp-mh7-review-fabricator'))
    checkpoint=dict(status='native_production_quality_reload_pipe_review_clock_and_sound_binding_pass; ordinary_chain_pending',engineering_delivery='../v03-finish-and-states',source_sha256=normal['model_source_sha256'],
        native_sites=20,orientations=4,footprint=[4,4],fluid_boxes=1,water_as_review_forming_medium=True,fluid_identity_and_economy_final=False,
        real_plate_inserter_input=True,real_shell_inserter_output=True,normal_and_rare_quality_verified=True,missing_input_cases_verified=True,mid_cycle_reload_identical=True,
        native_cycle_ticks=720,native_source_cell_period_ticks=60,all_twelve_cells_verified_each_direction=True,actual_two_loop_wraps_each_direction=True,
        native_audio_binding_verified=True,native_audio_phase_synchronization_verified=False,agent_graphical_pipe_seating_review=True,owner_approved=False,ordinary_chain_integrated=False,
        fitting_method='Rigid original ten-mesh mouth and unchanged 64-section reducer; straight axial receiving neck or intact laterally shifted reducer with constant-radius small feed. Original camera/body proportions remain fixed.',
        next=['Build canister assembler with state-preserving pellet/shell sealing','Refine three reactors and remaining sprite-only buildings','Integrate ordinary chain recipes/UI/economy and final fluid identity without exposing review internals'])
    write(out/'CHECKPOINT.json',checkpoint)
    (out/'README.md').write_text('# Fabricator V04 native review\n\nThe actual 4x4 prototype consumes two steel plates and review forming water over twelve seconds and produces one empty pressure shell. Twenty native sites cover four rotations, real inserter plate input and shell pickup, normal/rare quality and missing connection/plate/water cases. Actual mid-cycle tick-1200 save/reload yields identical histories. The original working/idle/start/stop sounds bind at their intended gains. Recipe balance and final forming medium remain provisional.\n\nThe native capture derivative retains the unchanged camera, body and 64-section reducer. A rigid mouth, straight full-bore axial extension or intact lateral intake with constant-radius small feed closes the projection gap. The off-center native row is -0.5 because model +Y projects toward native screen north. The left hinge plate and seated anchors move .12 to clear the lateral receiver. Independent four-pose rim/barrel/bore checks pass; actual connected/disconnected screenshots were inspected at normal object depth with +4px placement. This is agent review, not owner acceptance.\n\nThe initial fractional 1/60 animation drifts in engine playback. A binary-exact .25 speed and 180-entry frame sequence repeats each of the twelve source cells fifteen times, yielding sixty ticks per source cell and 720 ticks per cycle. Private half-second counter images verify all twelve cells, exact sixty-tick steps and two real wraps in every direction. Native sound phase synchronization is not claimed. Counters are excluded from delivered art.\n\nThe prototype-mod has no control.lua or fixture clearing. The separately named isolated-review-mod builds and clears only its fresh review world. Its scripts must never be installed as ordinary production control. Native screenshots stay private because they contain base-game pixels; their hashes are included. Own editable capture master, source frames, sheets and safe prototype graphics are public. Ordinary chain recipes/UI/economy and final fluid identity remain open. Continue the canister assembler, reactors and remaining buildings.\n',encoding='utf-8')
    write(out/'SHA256.json',{p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    path=repo/'docs/art/metallic-hydrogen-chain/PRODUCTION_CONTINUATION.json';d=json.loads(path.read_text());d['current_machine']='canister-assembler';d['current_candidate']=str(out);d['fabricator_native']=checkpoint;d['next_steps']=checkpoint['next']
    for row in d['queue']:
        if row['id']=='pressure-vessel-fabricator':row['status']='V03 art/V04 actual native candidate saved; ordinary chain/economy and owner feedback remain open'
        if row['id']=='canister-assembler':row['status']='next: three indexed stations with state-preserving sealing'
    write(path,d);print('FABRICATOR_NATIVE_V04_CHECKPOINT',out,flush=True)


if __name__=='__main__':main()
