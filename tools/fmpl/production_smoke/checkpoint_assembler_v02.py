"""Package the measured assembler cadence, clearances and complete bore review."""
import argparse
import json
from pathlib import Path
import shutil
from PIL import Image
from run_compressor_native_jig import sha
from checkpoint_assembler_v01 import write


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--repo',default='.')
    args=ap.parse_args();repo=Path(args.repo).resolve();src=Path(args.source).resolve()
    out=repo/'art/source-to-3d/metallic-hydrogen-chain/canister-assembler/v02-clearance-and-cadence'
    if out.exists():raise FileExistsError('Preserve prior checkpoints')
    source=src/'assembler-v02.blend';glb=src/'assembler-v02.glb';source_hash=sha(source);glb_hash=sha(glb)
    names=['export-readback.json','source-motion.json','runtime-motion.json','feed-readback.json','inspection/assembler-readback.json']
    reports={n:json.loads((src/n).read_text()) for n in names}
    for name,r in reports.items():
        if r.get('source_sha256',r.get('native_sha256'))!=source_hash:raise RuntimeError('Stale source '+name)
        if name!='source-motion.json' and r['glb_sha256']!=glb_hash:raise RuntimeError('Stale export '+name)
    export=reports['export-readback.json'];inspection=reports['inspection/assembler-readback.json']
    if not export['passed'] or not reports['feed-readback.json']['passed']:raise RuntimeError('Export/feed gate')
    if not inspection['recorded_contacts_passed'] or not inspection['work_loop_passed'] or inspection['centerline_obstructions']:raise RuntimeError('Contact/loop gate')
    for name in ['source-motion.json','runtime-motion.json']:
        r=reports[name]
        if not r['reviewed_contacts_passed'] or r['unexpected_pairs'] or r['samples']!=1538:raise RuntimeError('Motion gate '+name)
    for row in inspection['views']:
        if sha(src/'inspection'/(row['view']+'.png'))!=row['sha256']:raise RuntimeError('Changed render')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    for name in ['assembler-v02.blend','assembler-v02.glb','working-front.png','construction-receipt.json','port_manifest.json','part_provenance.json']+names[:-1]:shutil.copy2(src/name,out/name)
    shutil.copytree(src/'inspection',out/'inspection')
    panel=Image.new('RGB',(1920,640),(30,32,35))
    for index,row in enumerate(inspection['views']):
        with Image.open(src/'inspection'/(row['view']+'.png')) as im:
            im=im.convert('RGBA');panel.paste(im,(640*index,0),im.getchannel('A'))
    panel.save(out/'indexed-stations.png')
    registry_path=repo/'art/source-to-3d/shared-parts/metallic-hydrogen/registry.json';registry=json.loads(registry_path.read_text());previous=sha(registry_path);entries=[]
    for instance in json.loads((src/'part_provenance.json').read_text())['instances']:
        part=next(p for p in registry['parts'] if p['part_id']==instance['part_id'] and p['revision']==instance['revision']);master=registry_path.parent/part['source_blend']
        if sha(master)!=instance['source_sha256']:raise RuntimeError('Frozen shared master changed')
        consumer=dict(machine='canister-assembler',machine_revision='V02 measured clearances and sixteen-second cadence',instance=instance['instance'],transform=instance['transform'],model_source_sha256=source_hash,runtime_export_sha256=glb_hash,status='Unchanged appended console; source/export sampled mechanics pass. Dedicated finish and native remain open.')
        part['consumers'].append(consumer);entries.append(dict(part_id=part['part_id'],revision=part['revision'],**consumer))
        component=dict(part);component.update(source_blend='part.blend',thumbnail='thumbnail.png',verification='verification.json');write(master.parent/'part.json',component)
    if sha(registry_path)!=previous:raise RuntimeError('Concurrent registry update')
    registry['previous_registry_sha256']=previous;registry['instances_by_machine']['canister-assembler']=entries;write(registry_path,registry)
    next_steps=['Author assembler-specific vessel, gantry, guide, valve and sealing-tool surfaces and appropriate sound','Capture four idle/working directions and reopen packed source','Implement live pellet/shell assembly with existing seal operation, retaining HP, quality, phase and remaining decay time','Refine three reactors, remaining sprite-only buildings and ordinary chain/UI/economy integration']
    checkpoint=dict(status='sampled_source_and_export_mechanics_and_complete_bore_review_pass; finish_audio_capture_native_pending',source_sha256=source_hash,glb_sha256=glb_hash,library_registry_sha256=sha(registry_path),footprint=[4,4],primary_canisters=3,
        recorded_contacts=len(inspection['contacts']),recorded_contacts_passed=True,work_cycle_seconds=16,station_seconds=4,station_start_seconds=[0,5,10],between_station_index_seconds=1,return_seconds=2,source_loop_matrix_error=inspection['work_loop_matrix_error'],triangles=export['runtime_stats']['triangles'],
        motion_samples_per_artifact=1538,sample_interval_frames=.25,unexpected_sampled_pairs=0,maximum_head_index_speed_tiles_per_second=reports['source-motion.json']['maximum_head_index_speed_tiles_per_second'],previous_v01_maximum_speed_tiles_per_second=6.078426361083984,
        complete_authored_bore_ray_review=True,source_and_export_open_core_rays=1512,closed_gate_lids_and_bottoms_verified=True,landed_punch_verified=True,continuous_swept_clearance_verified=False,granular_dynamics_simulated=False,
        actual_glb_phase_views=3,dedicated_surfaces_complete=False,audio_implemented=False,native_verified=False,owner_approved=False,
        native_contract='Use live pellet/shell seal operation. Preserve HP, quality, decay phase, remaining lifetime and original shell condition.',next=next_steps)
    write(out/'CHECKPOINT.json',checkpoint)
    write(out/'VISUAL_REVIEW.json',dict(status='mechanics checkpoint; below final surface/native gate',source_sha256=source_hash,glb_sha256=glb_hash,owner_approved=False,final_threshold_unchanged=4,scores=dict(silhouette=3,construction=4,surfaces=2,states=4,native=0),
        findings=['Three indexed hollow vessels, exposed necks, supported lid rails and rear gantry retain distinct three-station construction.', 'Outboard metering bearings and separate crank/pivot planes clear adjacent tools. Real slots receive lids/jaws/shutter. A bored slotted valve body connects hopper and bend without blocking its moving blade.', 'Nozzle and annular punch clear cap hardware; landed punch meets the closed cap. Raised true-radius feed clears the tool flange and passes all authored core segments.', 'Three actual GLB phase renders inspected; donor finish remains provisional. Full four-angle capture, dedicated sound/surfaces and live-state native assembly are still required.'],render_hashes={r['view']:r['sha256'] for r in inspection['views']}))
    (out/'README.md').write_text('# Assembler V02 clearance and cadence checkpoint\n\nThe three-station assembler now uses a sixteen-second cycle: three four-second operations, one second for each station index, and a two-second return. Maximum sampled head speed falls from 6.078 to 1.499 tiles/second. Real slide channels clear cap carriers, lift jaws and the metering shutter. The eccentric linkage uses separate pivot planes and outboard bearing supports. A slotted bored valve body connects the hopper throat to the raised true-radius feed. The sealing punch lands on the cap without penetrating it.\n\nBoth source and independently imported GLB pass 1,538 quarter-frame motion samples with no undeclared triangle intersection pairs. All 201 recorded static attachments and the closed object-matrix loop pass. At each of three stations, 252 center/offset rays traverse the complete authored hopper, gate, curved feed, guide, nozzle and vessel path in each artifact. Closed lids, closed gate, actual vessel bottoms and landed punch are separately checked. These are bounded geometric samples, not continuous mathematical collision proof, granular dynamics or pressure certification.\n\nEditable source, runtime export, three actual exported phase renders and hash-bound readbacks are included. Dedicated assembler surfaces, sound, full four-direction captures and state-preserving native sealing remain open. No owner approval is inferred. The earlier V01 pilot and private failed clearance studies remain preserved. Native sealing must use actual live pellet/shell stacks without healing, quality gain or decay reset, retaining the shell condition for unsealing.\n',encoding='utf-8')
    write(out/'SHA256.json',{p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    path=repo/'docs/art/metallic-hydrogen-chain/PRODUCTION_CONTINUATION.json';d=json.loads(path.read_text());d.update(current_machine='canister-assembler',current_candidate=str(out),assembler=checkpoint,library_registry_sha256=sha(registry_path),next_steps=next_steps)
    for row in d['queue']:
        if row['id']=='canister-assembler':row['status']='V02 source/export cadence, sampled mechanics and complete authored bore review pass; finish/audio/four-angle/native next'
    write(path,d);print('ASSEMBLER_V02_CHECKPOINT',out,flush=True)


if __name__=='__main__':main()
