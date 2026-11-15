"""Preserve the owner-directed open-frame hydroforming construction pilot."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,value):Path(p).write_text(json.dumps(value,indent=2)+'\n')


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--repo',default='.');args=ap.parse_args();repo=Path(args.repo).resolve();src=Path(args.source).resolve()
    out=repo/'art/source-to-3d/metallic-hydrogen-chain/pressure-vessel-fabricator/v01-open-hydroforming-pilot'
    if out.exists():raise FileExistsError('Preserve fabricator checkpoints')
    source=src/'fabricator-v01.blend';glb=src/'fabricator-v01.glb';export=json.loads((src/'export-readback.json').read_text());inspection=json.loads((src/'inspection/hydroforming-readback.json').read_text())
    if not export['passed'] or export['native_sha256']!=sha(source) or export['glb_sha256']!=sha(glb):raise RuntimeError('Actual export gate')
    if not inspection['morph_passed'] or not inspection['recorded_contacts_passed'] or inspection['source_sha256']!=sha(source) or inspection['glb_sha256']!=sha(glb):raise RuntimeError('Morph/contact gate')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    for name in ('fabricator-v01.blend','fabricator-v01.glb','working-front.png','construction-receipt.json','port_manifest.json','part_provenance.json','export-readback.json'):shutil.copy2(src/name,out/name)
    shutil.copytree(src/'inspection',out/'inspection')
    panel=Image.new('RGB',(1920,640),(30,32,35))
    for i,name in enumerate(('plate-welding-open','clamped-expanding','formed-vessel-exposed')):
        with Image.open(src/'inspection'/(name+'.png')) as im:
            im=im.convert('RGBA');panel.paste(im,(i*640,0),im.getchannel('A'))
    panel.save(out/'hydroforming-phases.png')
    registry_path=repo/'art/source-to-3d/shared-parts/metallic-hydrogen/registry.json';registry=json.loads(registry_path.read_text());previous=sha(registry_path);entries=[]
    for instance in json.loads((src/'part_provenance.json').read_text())['instances']:
        part=next(p for p in registry['parts'] if p['part_id']==instance['part_id'] and p['revision']==instance['revision']);master=registry_path.parent/part['source_blend']
        if sha(master)!=instance['source_sha256']:raise RuntimeError('Frozen shared part changed')
        consumer=dict(machine='pressure-vessel-fabricator',machine_revision='V01 open-frame hydroforming construction pilot',instance=instance['instance'],transform=instance['transform'],model_source_sha256=sha(source),runtime_export_sha256=sha(glb),status='Actual unchanged library assembly retained in source and independently imported GLB; final surfaces and native integration pending')
        part['consumers'].append(consumer);entries.append(dict(part_id=part['part_id'],revision=part['revision'],**consumer))
        component=dict(part);component.update(source_blend='part.blend',thumbnail='thumbnail.png',verification='verification.json');write(master.parent/'part.json',component)
    registry['previous_registry_sha256']=previous;registry['instances_by_machine']['pressure-vessel-fabricator']=entries;write(registry_path,registry)
    checkpoint=dict(status='actual_open_hydroforming_source_export_and_morph_pilot; finish_pressure_path_and_native_pending',source_sha256=sha(source),glb_sha256=sha(glb),registry_sha256=sha(registry_path),footprint=[4,4],
        owner_process='Weld steel plates together, clamp the exposed blank in an open frame, and pump high-pressure forming material through a sealed mandrel to expand it.',
        rejected_design='Large solid die blocks from the first private study; not promoted',contacts=len(inspection['contacts']),deformed_vertex_pose_samples=len(inspection['morph_samples']),maximum_deformed_world_vertex_error=inspection['maximum_deformed_world_vertex_error'],
        triangles=export['runtime_stats']['triangles'],cycle_seconds=12,shared_parts=2,owner_approved=False,dedicated_surfaces_complete=False,full_swept_clearance_verified=False,pressure_circuit_verified=False,native_prototype_verified=False,
        next=['Check full open-frame/torch/pressure-blank swept clearances and actual pressure circuit','Finish model-specific surfaces and relevant welding/pump sound','Capture four directions with idle/welding/clamping/forming states','Build actual 4x4 fluid/item prototype and pipe fittings; ordinary chain integration','Build canister assembler, refine three reactors, then remaining sprite-only buildings'])
    write(out/'CHECKPOINT.json',checkpoint)
    (out/'README.md').write_text('# Open-frame hydroforming fabricator V01 pilot\n\nThe owner clarified the process as welded steel plates expanded by high-pressure forming material, then rejected a bulky solid die enclosure. This pilot uses narrow supported edge lands, an open hinged clamping frame and an exposed two-sheet pressure blank. The guided welding torch works along the real plate-edge seam, parks clear, the frame clamps the flanges, and the blank expands while its round pressure neck stays fixed. A grounded tailstock carries the hollow injection mandrel and neck seals. Reservoir/pump hardware, a supported pressure line, plate-loading rollers and the registered cogitator/fluid mouth establish the construction. The first closed-block study remains private and is not promoted.\n\nThe editable Blender source and actual imported GLB pass 113 recorded assembly contacts, 12 phase samples of the deformed blank with zero measured world-vertex error, coherent idle/12-second working clips, finite/UV-bearing geometry and loaded maps. The current 31,296 triangles contain no degenerates. Actual exported welding, clamped expansion and exposed formed-vessel views were inspected; the comparison contains those real renders without concept-board pixels.\n\nThis is a construction pilot, not final art or pressure certification. Packed donor materials are not dedicated finish. Full moving clearance and pressure-route checks, appropriate welding/pump audio, four-direction final captures and a real native fluid/item prototype are still required. Forming-medium gameplay identity and native port cells remain provisional. Ordinary Factorio inserter access is sufficient; the owner explicitly stopped precision hand-to-socket alignment work on the completed forge.\n',encoding='utf-8')
    write(out/'SHA256.json',{p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    path=repo/'docs/art/metallic-hydrogen-chain/PRODUCTION_CONTINUATION.json';d=json.loads(path.read_text());d['current_machine']='pressure-vessel-fabricator';d['current_candidate']=str(out);d['fabricator']=checkpoint;d['library_registry_sha256']=sha(registry_path)
    d['forge'].update(status='preserved; owner directed standard anywhere-on-object inserter logic and move on',graphical_item_handoff_required=False,owner_requested_move_on=True,inserter_owner_instruction="It's standard factorial logic you can put an inserter anywhere on the object and it'll pick it up we don't need to worry about that. We do need to worry about moving on.")
    for row in d['queue']:
        if row['id']=='pelletization-forge':row['status']='native/art checkpoint retained; owner closed precision inserter alignment and requested move on'
        if row['id']=='pressure-vessel-fabricator':row['status']='real open-frame plate hydroforming pilot saved/exported; full clearance, pressure circuit, finish/audio/native next'
    d['next_steps']=checkpoint['next'];write(path,d);print('FABRICATOR_OPEN_PILOT_PACKAGED',out,flush=True)


if __name__=='__main__':main()
