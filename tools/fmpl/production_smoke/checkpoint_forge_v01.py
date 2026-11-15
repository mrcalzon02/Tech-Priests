"""Save the distinct forge pilot with bounded mechanical/export evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,d):Path(p).write_text(json.dumps(d,indent=2)+'\n')


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--repo',default='.');args=ap.parse_args();repo=Path(args.repo).resolve();src=Path(args.source).resolve()
    out=repo/'art/source-to-3d/metallic-hydrogen-chain/pelletization-forge/v01-construction-pilot';source=src/'forge-v01.blend';glb=src/'forge-v01.glb'
    if out.exists():raise FileExistsError('Preserve forge source candidates')
    export=json.loads((src/'export-readback.json').read_text());mechanical=json.loads((src/'mechanics/mechanical-readback.json').read_text());inspection=json.loads((src/'export-inspection/export-inspection.json').read_text())
    if not export['passed'] or export['native_sha256']!=sha(source) or export['glb_sha256']!=sha(glb):raise RuntimeError('Export gate')
    if not mechanical['passed'] or mechanical['source_sha256']!=sha(source):raise RuntimeError('Mechanical gate')
    if not inspection['geometry_passed'] or inspection['glb_sha256']!=sha(glb):raise RuntimeError('Inspected artifact gate')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    for name in ('forge-v01.blend','forge-v01.glb','working-front.png','construction-receipt.json','port_manifest.json','part_provenance.json','export-readback.json'):shutil.copy2(src/name,out/name)
    for name in ('mechanics','export-inspection'):shutil.copytree(src/name,out/name)
    path=repo/'art/source-to-3d/shared-parts/metallic-hydrogen/registry.json';registry=json.loads(path.read_text());previous=sha(path);entries=[]
    for instance in json.loads((src/'part_provenance.json').read_text())['instances']:
        part=next(p for p in registry['parts'] if p['part_id']==instance['part_id'] and p['revision']==instance['revision']);master=path.parent/part['source_blend']
        if sha(master)!=instance['source_sha256']:raise RuntimeError('Frozen library master changed')
        consumer=dict(machine='pelletization-forge',machine_revision='V01 construction pilot',instance=instance['instance'],transform=instance['transform'],model_source_sha256=sha(source),runtime_export_sha256=sha(glb),status='actual appended console in saved and independently reimported pilot; finish/native pending')
        part['consumers'].append(consumer);entries.append(dict(part_id=part['part_id'],revision=part['revision'],**consumer))
        component=dict(part);component.update(source_blend='part.blend',thumbnail='thumbnail.png',verification='verification.json');write(master.parent/'part.json',component)
    registry['previous_registry_sha256']=previous;registry['instances_by_machine']['pelletization-forge']=entries;write(path,registry)
    checkpoint=dict(status='actual_source_export_and_guided_ram_pilot; finish_material_path_and_native_pending',source_sha256=sha(source),glb_sha256=sha(glb),footprint=[3,3],
        registry_sha256=sha(path),contacts=len(mechanical['contacts']),motion_poses=len(mechanical['sampled_motion']),guided_ram_static_pair_checks=mechanical['moving_fixed_pair_checks'],
        triangles=export['runtime_stats']['triangles'],maximum_sampled_world_pose_error=export['maximum_sampled_world_pose_error'],cycle_seconds=8,
        actual_library_parts=1,actual_library_instances=1,no_new_verified_parts='New actuator/auger assemblies remain machine-local pending complete material-path and finishing proof.',
        owner_approved=False,full_material_path_verified=False,model_specific_finish_complete=False,audio_implemented=False,native_item_interfaces_verified=False,
        next=['Audit hopper-auger-feed-shoe and pellet compression/ejection support through the whole cycle','Finish cast frame, hopper, ram/die surfaces and authored working sound','Capture four idle/working rotations and create actual native item-handling fixture','Preserve pellet remaining lifetime, HP and quality through processing; no recipe refresh'])
    write(out/'CHECKPOINT.json',checkpoint)
    (out/'README.md').write_text('# Pelletization forge V01 construction pilot\n\n'
        'Distinct 3x3 editable machine: true open tapered hopper, supported short auger/motor, grounded red I-section press frame, a drilled crossbeam with seated actuator, two real guides and bored crosshead bearings, an on-axis punch and narrowing open die, open rear feed shoe, inclined extraction chute and accessible front pickup tray. One actual registered cogitator console is appended locally; no fluid mouths are invented for this item-processing machine.\n\n'
        'The saved source passes 57 recorded contacts, 1,428 guided-ram/static surface pairs over 17 actual poses, on-axis punch/telescoping piston endpoint checks and loop closure. The actual GLB reimport has 17,400 triangles, no degenerate/nonfinite geometry or missing UV/maps, and a maximum sampled world-pose difference of 2.4e-7. Exported front/rear/clay views were inspected. These are bounded construction checks; the complete material feed/compression/ejection path is still a separate open gate.\n\n'
        'Current packed donor surfaces establish the family palette, not final model-specific finish. Machine-specific maps, sound, four-angle states, actual native item access and state-preserving pellet processing remain required. Processing must not reset unstable pellet lifetime or restore HP/quality. The crucible is preserved at its restrained native checkpoint; do not restart ornamental animation there.\n',encoding='utf-8')
    write(out/'SHA256.json',{p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    path=repo/'docs/art/metallic-hydrogen-chain/PRODUCTION_CONTINUATION.json';d=json.loads(path.read_text());d['current_machine']='pelletization-forge';d['current_candidate']=str(out);d['forge']=checkpoint;d['library_registry_sha256']=sha(repo/'art/source-to-3d/shared-parts/metallic-hydrogen/registry.json')
    for row in d['queue']:
        if row['id']=='pelletization-forge':row['status']='real 3x3 guided-press pilot saved/exported; finishing/audio/material path/native pending'
    d['next_steps']=checkpoint['next']+['Build vessel fabricator and canister assembler, integrate full chain, recover/refine three reactor sources'];write(path,d);print('FORGE_PILOT_PACKAGED',out,flush=True)


if __name__=='__main__':main()
