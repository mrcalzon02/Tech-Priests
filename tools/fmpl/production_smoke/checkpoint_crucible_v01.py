"""Preserve the real crucible pilot and corrected process transitions."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,d):Path(p).write_text(json.dumps(d,indent=2)+'\n')


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--repo',default='.');args=ap.parse_args()
    repo=Path(args.repo).resolve();src=Path(args.source).resolve();source=src/'crucible-v01.blend';glb=src/'crucible-v01.glb'
    out=repo/'art/source-to-3d/metallic-hydrogen-chain/metallization-crucible/v01-construction-pilot'
    if out.exists():raise FileExistsError('Preserve real candidate snapshots')
    export=json.loads((src/'export-readback.json').read_text())
    if not export['passed'] or export['native_sha256']!=sha(source) or export['glb_sha256']!=sha(glb):raise RuntimeError('Export gate')
    reports={}
    for folder in ('mechanics','export-mechanics'):
        row=json.loads((src/folder/'mechanical-readback.json').read_text())
        if not row['passed'] or row['source_sha256']!=sha(source):raise RuntimeError('Mechanical gate '+folder)
        reports[folder]=row
    if reports['export-mechanics']['artifact_sha256']!=sha(glb):raise RuntimeError('Wrong actual runtime artifact')
    views=json.loads((src/'export-details/inspection.json').read_text())
    if views['native_sha256']!=sha(source) or views['glb_sha256']!=sha(glb):raise RuntimeError('Wrong actual inspected artifact')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    for name in ('crucible-v01.blend','crucible-v01.glb','working-front.png','port_manifest.json','part_provenance.json','construction-receipt.json','export-readback.json'):shutil.copy2(src/name,out/name)
    for name in ('mechanics','export-mechanics','export-details'):shutil.copytree(src/name,out/name)
    registry_path=repo/'art/source-to-3d/shared-parts/metallic-hydrogen/registry.json';registry=json.loads(registry_path.read_text());prior_hash=sha(registry_path)
    provenance=json.loads((src/'part_provenance.json').read_text());entries=[]
    for instance in provenance['instances']:
        part=next(p for p in registry['parts'] if p['part_id']==instance['part_id'] and p['revision']==instance['revision'])
        master=registry_path.parent/part['source_blend']
        if sha(master)!=instance['source_sha256']:raise RuntimeError('Frozen library master changed')
        consumer=dict(machine='metallization-crucible',machine_revision='V01 construction pilot',instance=instance['instance'],transform=instance['transform'],
            model_source_sha256=sha(source),runtime_export_sha256=sha(glb),status='actual appended saved and independently reimported construction candidate; native fitting provisional')
        part['consumers'].append(consumer);entries.append(dict(part_id=part['part_id'],revision=part['revision'],**consumer))
        component=dict(part);component.update(source_blend='part.blend',thumbnail='thumbnail.png',verification='verification.json');write(master.parent/'part.json',component)
    registry['previous_registry_sha256']=prior_hash;registry['instances_by_machine']['metallization-crucible']=entries;write(registry_path,registry)
    checkpoint=dict(status='technically_verified_construction_candidate; finish_and_native_pending',source_sha256=sha(source),glb_sha256=sha(glb),planned_footprint=[5,5],
        registry_sha256=sha(registry_path),generator_sha256=sha(repo/'tools/fmpl/production_smoke/build_crucible_v01.py'),
        provenance='new_reconstruction_from_reference; historical native v0.2 bytes unrecovered',assembly_contacts=len(reports['mechanics']['contacts']),
        source_and_runtime_core_rays_each=reports['mechanics']['core_rays'],fan_surface_pair_checks_each=reports['mechanics']['fan_surface_pair_checks'],
        exported_triangles=export['runtime_stats']['triangles'],maximum_sampled_world_pose_error=export['maximum_sampled_world_pose_error'],cycle_seconds=8,
        owner_approved=False,native_pipe_verified=False,model_specific_surface_finish_complete=False,audio_implemented=False,
        owner_correction='Twisting at mechanical-to-pipe inlet/outlet transitions looked wrong. Both rebuilt as straight coaxial reducers with separate .20-radius circular elbows.',
        render_review='Actual GLB injector, transfer and rear-services views inspected. Smooth separate transitions replace the earlier skewed reducer; this does not approve final finish.',
        actual_reused_parts=2,actual_reused_instances=3,no_new_verified_parts='Machine construction and owner-requested transition correction prioritized; no speculative parts harvested.',
        next=['Model-specific pressure-shell, crown, casting and cover surfaces','Relevant closed pressure/thermal audio and meaningful states','Four actual idle/working rotations','Actual native 5x5 prototype and pipe fitting'])
    write(out/'CHECKPOINT.json',checkpoint)
    (out/'README.md').write_text('# Metallization crucible V01 construction candidate\n\n'
        'Distinct 5x5 closed pressure vessel: thick wall and graded crown, three seated pressure bands, four grounded tapered red haunches and steel back braces, real hinged/latching maintenance hatch, separately supported injector and protected product-transfer housing, rear thermal/power cabinet with guarded fan, small process witnesses, clear front grated maintenance corridor and registered cogitator controls. This is a new reconstruction from the approved process packet; unseen historical v0.2 meshes were not edited.\n\n'
        'The owner rejected the twisted mechanical-to-pipe transitions. Both are now straight coaxial hollow reducers followed by separate constant-diameter .20-radius circular elbows. Offset clamps retain the straight risers without entering the flow core. Actual source and GLB pass 77 recorded contacts, 290 core rays each into the drilled vessel, 204 fan/guard pairs each over 17 poses, external mouth clearance and mesh/image/UV checks. The GLB has 44k-class triangles with zero degenerate/nonfinite geometry; exact count and hashes are in the readbacks. Actual exported inlet, outlet and rear-service closeups were inspected. Earlier skewed and obstructed studies stay private in staging.\n\n'
        'This remains a construction candidate. Model-specific surfacing, protective-cover finishing, relevant pressure/thermal sound, four-direction idle/working captures, native 5x5 prototype fitting and ordinary-chain economy are still required. Current socket numbers are model-space proposals with native declarations null. No native alignment or owner finish acceptance is claimed. The compressor native placement is separately accepted and frozen in V06.\n',encoding='utf-8')
    cont=repo/'docs/art/metallic-hydrogen-chain/PRODUCTION_CONTINUATION.json';d=json.loads(cont.read_text())
    d['current_machine']='metallization-crucible';d['current_candidate']=str(out);d['crucible']=checkpoint;d['library_registry_sha256']=sha(registry_path)
    for row in d['queue']:
        if row['id']=='metallization-crucible':row['status']='real construction pilot; source/export verified; finishing/audio/native pending'
    write(cont,d)
    write(out/'SHA256.json',{p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    print('CRUCIBLE_CONSTRUCTION_CHECKPOINT',out)


if __name__=='__main__':main()
