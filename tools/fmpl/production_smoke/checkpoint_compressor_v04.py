"""Preserve the actual finished compressor candidate and bounded QA evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image,ImageDraw


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,value):
    p=Path(p);tmp=p.with_suffix(p.suffix+'.tmp');tmp.write_text(json.dumps(value,indent=2)+'\n');tmp.replace(p)


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--repo',required=True);ap.add_argument('--staging',required=True)
    args=ap.parse_args();repo=Path(args.repo).resolve();src=Path(args.staging).resolve();cap=src/'captures'
    out=repo/'art/source-to-3d/metallic-hydrogen-chain/hydrogen-compressor/v04-finish-and-states'
    if out.exists():raise FileExistsError('Keep published candidate snapshots immutable')
    source=src/'compressor-v01.blend';glb=src/'compressor-v01.glb'
    mechanical=json.loads((src/'mechanics/mechanical-readback.json').read_text());export=json.loads((src/'export-readback.json').read_text())
    for name in ('route-readback.json','export-route-readback.json'):
        r=json.loads((src/name).read_text())
        if not r['passed'] or r['source_sha256']!=sha(source):raise RuntimeError('Failed/stale '+name)
        if r.get('glb_sha256') and r['glb_sha256']!=sha(glb):raise RuntimeError('Wrong exported route artifact')
    if not mechanical['passed'] or mechanical['source_sha256']!=sha(source):raise RuntimeError('Mechanical readback failed')
    if not export['passed'] or export['native_sha256']!=sha(source) or export['glb_sha256']!=sha(glb):raise RuntimeError('Export readback failed')
    for name in ('qa.json','reopen-qa.json'):
        if not json.loads((cap/name).read_text())['passed']:raise RuntimeError('Capture gate '+name)
    capture=json.loads((cap/'capture.json').read_text())
    if capture['source_sha256']!=sha(source) or len(capture['frames'])!=36:raise RuntimeError('Wrong actual capture source/count')
    inspect=json.loads((src/'export-inspection/export-inspection.json').read_text())
    if not inspect['geometry_passed'] or inspect['glb_sha256']!=sha(glb):raise RuntimeError('Wrong inspection')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    shutil.copy2(source,out/'compressor-v04.blend');shutil.copy2(glb,out/'compressor-v04.glb')
    for name in ('working-front.png','construction-receipt.json','port_manifest.json','part_provenance.json','export-readback.json','route-readback.json','export-route-readback.json'):
        shutil.copy2(src/name,out/name)
    shutil.copy2(src/'mechanics/mechanical-readback.json',out/'mechanical-readback.json')
    for name in ('textures','export-inspection','export-details'):shutil.copytree(src/name,out/name)
    shutil.copytree(cap,out/'captures',ignore=shutil.ignore_patterns('*.log','checkpoint-*.json'))
    views=[('North',0),('East',3),('South',2),('West',1)]
    def panel(state,index):
        canvas=Image.new('RGB',(512,552),(33,35,38));draw=ImageDraw.Draw(canvas)
        for slot,(label,direction) in enumerate(views):
            x=(slot%2)*256;y=(slot//2)*276
            with Image.open(cap/f'frames/{state}/d{direction:02d}/f{index:03d}.png') as image:
                rgba=image.convert('RGBA');canvas.paste(rgba,(x,y),rgba.getchannel('A'))
            draw.text((x+12,y+259),label,fill='white')
        return canvas
    panel('idle',0).save(out/'compressor-four-angle-idle.png')
    frames=[panel('working',i) for i in range(8)]
    frames[0].save(out/'compressor-four-angle-working.gif',save_all=True,append_images=frames[1:],duration=500,loop=0,disposal=2)
    frames[0].save(out/'compressor-four-angle-working.webp',save_all=True,append_images=frames[1:],duration=500,loop=0,lossless=True)
    reference=repo/'art/source-to-3d/metallic-hydrogen-chain/water-purifier/v16-owner-accepted/purifier-four-angle-idle.png'
    review=dict(status='VISUALLY_REVIEWED_FINISH_CANDIDATE; OWNER_AND_NATIVE_REVIEW_OPEN',source_sha256=sha(source),export_sha256=sha(glb),
        reference=dict(path=reference.relative_to(repo).as_posix(),sha256=sha(reference)),
        actual_images={p.relative_to(out).as_posix():sha(p) for folder in ('export-inspection','export-details') for p in (out/folder).glob('*.png')},
        scale='0 to 5; final threshold 4 per criterion',
        scores={'silhouette':dict(score=4,reason='Three parallel horizontal cylinders, common phased drive, side motor/flywheel, separate pressure headers and compact emergency-family controls.'),
            'construction':dict(score=4,reason='Supported saddles, guides and shaft seats; clear interrupted journals/twin crank cheeks, grounded drive guard, real manifold gauge and normally closed relief. Pressure tee cuts open only into their branches. Targeted checks do not certify pressure containment.'),
            'surfaces':dict(score=4,reason='Actual GLB front/rear/clay and three oblique renders viewed. Nine packed steel maps follow cylinder axes, real band/head contacts and rear discharge heat region; polished piston rods and retained enamel/glass gauge.'),
            'motion_states':dict(score=4,reason='Actual slider-crank endpoints remain attached with .12 radius/.67 links and 120-degree phases over 17 poses. Coherent exported idle/working clips match all sampled source object poses; four-second loop closes. Actual four-angle review capture included.'),
            'native_integration':dict(score=0,reason='No actual compressor native prototype/pipe-placement test yet. Engineering mouths are provisional and must not be called visually aligned from model-space checks.')},owner_approved=False)
    write(out/'VISUAL_REVIEW.json',review)
    registry_path=repo/'art/source-to-3d/shared-parts/metallic-hydrogen/registry.json';registry=json.loads(registry_path.read_text());previous=sha(registry_path)
    provenance=json.loads((out/'part_provenance.json').read_text());entries=[]
    for instance in provenance['instances']:
        part=next(p for p in registry['parts'] if p['part_id']==instance['part_id'] and p['revision']==instance['revision'])
        master=registry_path.parent/part['source_blend']
        if sha(master)!=instance['source_sha256']:raise RuntimeError('Frozen master changed')
        consumer=dict(machine='hydrogen-compressor',machine_revision='V04 finish/state candidate',instance=instance['instance'],transform=instance['transform'],
            model_source_sha256=sha(source),runtime_export_sha256=sha(glb),status='actual appended, saved/rendered/exported/reimported candidate; native review open')
        part['consumers'].append(consumer);entries.append(dict(part_id=part['part_id'],revision=part['revision'],**consumer))
        component=dict(part);component.update(source_blend='part.blend',thumbnail='thumbnail.png',verification='verification.json');write(master.parent/'part.json',component)
    registry['previous_registry_sha256']=previous;registry['instances_by_machine']['hydrogen-compressor']=entries;write(registry_path,registry)
    checkpoint=dict(status='visual_reviewed_candidate',machine='hydrogen-compressor',planned_footprint=[3,4],source_sha256=sha(source),glb_sha256=sha(glb),registry_sha256=sha(registry_path),
        contacts=len(mechanical['contacts']),motion_poses=len(mechanical['motion']),disjoint_surface_pair_checks=mechanical['disjoint_surface_pair_checks'],
        source_and_export_mouth_rays_each=export['native_bores']['rays'],process_core_rays_each=234,opposite_pressure_wall_checks_each=8,
        capture_frames=36,atlas_count=6,cycle_seconds=4,native_ports_verified=False,owner_approved=False,
        actual_reused_master_parts=2,actual_reused_instances=3,no_new_verified_parts='Machine completion prioritized; existing frozen master console and mouths reused with independent native/export readback.',
        next=['actual native compressor prototype and two fluid assignments','native pipe fitting and idle/working placement review','then metallization crucible'])
    write(out/'CHECKPOINT.json',checkpoint)
    (out/'README.md').write_text('# Compressor V04 finish and state candidate\n\n'
        'Distinct editable 3x4 three-cylinder machine: supported saddles, guided crossheads, 120-degree phased crank assemblies, interrupted main journals, twin crank cheeks, supported guarded flywheel, cast motor, grounded crank guard and independent suction/discharge paths. A real drilled pressure gauge and normally closed relief arrangement are service hardware, not extra gameplay fluid ports.\n\n'
        'V04 repairs the V01 rail/shaft bore obstructions and degenerate Boolean faces. Actual detail review also caught unintended holes through the opposite header walls; the final tee/tap cuts preserve those walls. Source and actual GLB pass the targeted mechanical, route, pressure-wall and state-pose checks. Nine packed model-specific maps follow the barrel axes and actual retaining/head contacts. Actual source/exported views and four idle/working rotations are saved; native engine alignment and owner acceptance remain open.\n\n'
        'Source `compressor-v04.blend`, runtime interchange `compressor-v04.glb`. Receipts retain the original staging filename `compressor-v01.blend`; hashes bind these exact bytes. Source clock 24 fps, four-second cycle; sparse review capture eight uniform poses at 2 fps. Earlier failed studies remain in staging. No ordinary mod installation, native connectivity or full-chain completion is claimed.\n',encoding='utf-8')
    continuation_path=repo/'docs/art/metallic-hydrogen-chain/PRODUCTION_CONTINUATION.json';continuation=json.loads(continuation_path.read_text())
    continuation['current_machine']='hydrogen-compressor';continuation['current_candidate']=str(out);continuation['compressor']=checkpoint
    continuation['library_registry_sha256']=sha(registry_path)
    for row in continuation['queue']:
        if row['id']=='hydrogen-compressor':row['status']='visual_reviewed_candidate; native prototype pending'
    continuation['next_steps']=['Verify compressor actual native prototype and pipe-placement images','Build metallization crucible, pelletization forge, vessel fabricator and canister assembler','Integrate chain prototypes/economy as a whole','Recover and refine three plasma reactors']
    write(continuation_path,continuation)
    write(out/'SHA256.json',{p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    print('COMPRESSOR_V04_CHECKPOINT',out,flush=True)


if __name__=='__main__':main()
