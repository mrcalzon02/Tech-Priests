"""Package the measured open-frame mechanism/circuit checkpoint, not final art."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2)+'\n', encoding='utf-8')


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--repo',default='.')
    args=ap.parse_args();repo=Path(args.repo).resolve();src=Path(args.source).resolve()
    out=repo/'art/source-to-3d/metallic-hydrogen-chain/pressure-vessel-fabricator/v02-open-frame-mechanics'
    if out.exists():raise FileExistsError('Preserve published revisions')
    source=src/'fabricator-v02.blend';glb=src/'fabricator-v02.glb';source_sha=sha(source);glb_sha=sha(glb)
    reports={name:json.loads((src/name).read_text()) for name in ('export-readback.json','source-motion.json','runtime-motion.json','flow-readback.json','inspection/hydroforming-readback.json')}
    for name,d in reports.items():
        if d.get('source_sha256',d.get('native_sha256'))!=source_sha:raise RuntimeError(name+' source hash')
        if name!='source-motion.json' and d['glb_sha256']!=glb_sha:raise RuntimeError(name+' export hash')
    if not reports['export-readback.json']['passed'] or not reports['flow-readback.json']['passed']:raise RuntimeError('Export/flow gate')
    for name in ('source-motion.json','runtime-motion.json'):
        if not reports[name]['reviewed_contacts_passed'] or reports[name]['samples']!=1154:raise RuntimeError('Sampled motion gate')
    inspection=reports['inspection/hydroforming-readback.json']
    if not inspection['morph_passed'] or not inspection['recorded_contacts_passed']:raise RuntimeError('Morph/contact gate')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    for name in ('fabricator-v02.blend','fabricator-v02.glb','working-front.png','construction-receipt.json','port_manifest.json','part_provenance.json','export-readback.json','source-motion.json','runtime-motion.json','flow-readback.json'):
        shutil.copy2(src/name,out/name)
    shutil.copytree(src/'inspection',out/'inspection')
    panel=Image.new('RGB',(1920,640),(30,32,35))
    for i,name in enumerate(('plate-welding-open','clamped-expanding','formed-vessel-exposed')):
        with Image.open(out/'inspection'/(name+'.png')) as im:
            im=im.convert('RGBA');panel.paste(im,(i*640,0),im.getchannel('A'))
    panel.save(out/'hydroforming-phases.png')
    registry_path=repo/'art/source-to-3d/shared-parts/metallic-hydrogen/registry.json';registry=json.loads(registry_path.read_text());previous=sha(registry_path);entries=[]
    for instance in json.loads((src/'part_provenance.json').read_text())['instances']:
        part=next(p for p in registry['parts'] if p['part_id']==instance['part_id'] and p['revision']==instance['revision']);master=registry_path.parent/part['source_blend']
        if sha(master)!=instance['source_sha256']:raise RuntimeError('Frozen shared part changed')
        consumer=dict(machine='pressure-vessel-fabricator',machine_revision='V02 measured open-frame mechanism and bored circuit',instance=instance['instance'],transform=instance['transform'],model_source_sha256=source_sha,runtime_export_sha256=glb_sha,status='Unchanged appended shared master; source/runtime bores and sampled motion pass; dedicated finish/native pending')
        part['consumers'].append(consumer);entries.append(dict(part_id=part['part_id'],revision=part['revision'],**consumer))
        component=dict(part);component.update(source_blend='part.blend',thumbnail='thumbnail.png',verification='verification.json');write(master.parent/'part.json',component)
    registry['previous_registry_sha256']=previous;registry['instances_by_machine']['pressure-vessel-fabricator']=entries;write(registry_path,registry)
    checkpoint=dict(status='source_and_actual_export_mechanics_and_bore_checkpoint; dedicated_finish_audio_native_pending',source_sha256=source_sha,glb_sha256=glb_sha,registry_sha256=sha(registry_path),footprint=[4,4],cycle_seconds=12,
        owner_process='Weld steel plates together, clamp the exposed blank in an open frame, and pump high-pressure forming material through a sealed mandrel to expand it.',
        contacts=len(inspection['contacts']),motion_samples_per_artifact=1154,motion_step_frames=.25,unexpected_sampled_intersections=0,source_and_runtime_core_rays=sum(r['rays'] for stage in ('source','runtime') for r in reports['flow-readback.json'][stage]['paths']),
        deformed_vertex_pose_samples=len(inspection['morph_samples']),maximum_deformed_world_vertex_error=inspection['maximum_deformed_world_vertex_error'],triangles=reports['export-readback.json']['runtime_stats']['triangles'],
        sampled_motion_clearance_verified=True,full_continuous_swept_clearance_verified=False,pressure_core_bore_probes_passed=True,hydraulic_simulation_or_seal_certification=False,
        item_visual_transition='Full-size workpiece retained; native crafting owns item removal. No scaling the neck through the mandrel.',owner_approved=False,dedicated_surfaces_complete=False,native_prototype_verified=False,
        next=['Finish dedicated plate/weld/frame/pump/guide surfaces and appropriate welding/pump sound','Capture and inspect four idle/working directions and final hardware closeups','Build native 4x4 fluid/item prototype, real pipe joins and actual animation clock','Build canister assembler, refine three reactors, then remaining sprite-only buildings'])
    write(out/'CHECKPOINT.json',checkpoint)
    write(out/'VISUAL_REVIEW.json',dict(status='mechanism and bore checkpoint; final art gate remains open',source_sha256=source_sha,glb_sha256=glb_sha,owner_approved=False,final_threshold_unchanged=4,
        scores=dict(silhouette=3,construction=3,surfaces=2,states=3,native=0),
        findings=['Exposed blank and narrow open clamps retained. Actual export shows welding, clamped expansion and exposed formed part.',
                  'Rear lift arm, trunnion/clevis, extended torch parking and front-face conductor pads resolve measured clashes.',
                  'Bored reservoir and pump head, matched inlet reducer, constant-radius inlet elbow, low pressure corridor and mandrel glands pass geometry probes.',
                  'Family donor PBR remains provisional. Dedicated finish, closeup/rear/clay review, sound, four-direction final capture and native integration remain open.'],
        render_hashes={r['name']:r['sha256'] for r in inspection['views']}))
    (out/'README.md').write_text('# Open-frame fabricator V02 mechanism checkpoint\n\nThe welded blank stays exposed in narrow edge clamps. The upper frame now clears its rear bearings, the welding torch parks outside its sweep, the lift actuator uses an outboard rear arm and grounded trunnion/clevis, and the sliding conductor contacts approach supported rails from the front. The receiver, matched reducer and constant-radius inlet elbow lead into an actual hollow reservoir. Drilled suction/lid/pump-head bores feed a supported pressure line through a low service corridor into the sealed mandrel.\n\nThe editable source and independently imported GLB pass 1,154 motion samples each at quarter-frame intervals with only explicit guide/seal/piston and welding-tip contacts. Geometry probes traverse the external mouth, inlet, reservoir, suction, pump route and mandrel core; the blind end stops the axial ray. Twelve exported deformed-vertex samples match the source exactly. These are sampled geometric checks, not continuous collision proof or hydraulic certification. Earlier failed mechanical and inlet studies remain private staging.\n\nThe workpiece remains full size. Native crafting owns item output; no shrinking neck crosses the mandrel. The visible blank returns to the fresh-plate state at the cycle boundary.\n\nThis is not final art or owner approval. Dedicated surfaces and original audio, final four-direction captures, rear/closeup/clay inspection, native fluid and item implementation, and real native pipe fittings remain required. Existing accepted machines are unchanged.\n',encoding='utf-8')
    write(out/'SHA256.json',{p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    path=repo/'docs/art/metallic-hydrogen-chain/PRODUCTION_CONTINUATION.json';d=json.loads(path.read_text());d['current_machine']='pressure-vessel-fabricator';d['current_candidate']=str(out);d['fabricator']=checkpoint;d['library_registry_sha256']=sha(registry_path);d['next_steps']=checkpoint['next']
    for row in d['queue']:
        if row['id']=='pressure-vessel-fabricator':row['status']='V02 source/runtime sampled mechanics and core bores pass; dedicated finish/audio/four-angle/native next'
    write(path,d);print('FABRICATOR_V02_CHECKPOINT',out,flush=True)


if __name__=='__main__':main()
