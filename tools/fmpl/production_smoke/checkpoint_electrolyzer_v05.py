"""Package the reviewed V05 candidate, preserving exact evidence bytes."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image,ImageDraw


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def write(path,value):
    path=Path(path);tmp=path.with_suffix(path.suffix+'.tmp')
    tmp.write_text(json.dumps(value,indent=2)+'\n');tmp.replace(path)


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--staging',required=True);ap.add_argument('--capture',required=True)
    ap.add_argument('--out',required=True);ap.add_argument('--repo',required=True)
    args=ap.parse_args();src=Path(args.staging).resolve();cap=Path(args.capture).resolve()
    out=Path(args.out).resolve();repo=Path(args.repo).resolve()
    if out.exists():raise FileExistsError('Immutable evidence checkpoint; choose a new revision')
    source=src/'electrolyzer-v01.blend';glb=src/'electrolyzer-v01.glb'
    for name in ('contact-readback.json','route-readback.json','export-route-readback.json','motion-readback.json'):
        r=json.loads((src/name).read_text())
        if not r['passed'] or r['source_sha256']!=sha(source):raise RuntimeError('Stale/failed '+name)
        if r.get('glb_sha256') and r['glb_sha256']!=sha(glb):raise RuntimeError('Stale export '+name)
    audit=json.loads((src/'independent-readback.json').read_text())
    if audit['errors'] or audit['native_sha256']!=sha(source) or audit['glb_sha256']!=sha(glb):raise RuntimeError('Export audit failure')
    capture=json.loads((cap/'capture.json').read_text())
    for name in ('qa.json','reopen-qa.json'):
        if not json.loads((cap/name).read_text())['passed']:raise RuntimeError('Capture gate '+name)
    if capture['source_sha256']!=sha(source) or len(capture['frames'])!=36:raise RuntimeError('Wrong capture source/count')
    inspect=json.loads((src/'export-inspection/export-inspection.json').read_text())
    if not inspect['geometry_passed'] or inspect['glb_sha256']!=sha(glb):raise RuntimeError('Inspection mismatch')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    shutil.copy2(source,out/'electrolyzer-v05.blend');shutil.copy2(glb,out/'electrolyzer-v05.glb')
    for name in ('construction-receipt.json','port_manifest.json','part_provenance.json','working-front.png','idle-front.png',
                 'independent-readback.json','contact-readback.json','route-readback.json','export-route-readback.json','motion-readback.json'):
        shutil.copy2(src/name,out/name)
    for name in ('textures','export-inspection','export-details'):shutil.copytree(src/name,out/name)
    shutil.copytree(cap,out/'captures',ignore=shutil.ignore_patterns('*.log','checkpoint-*.json'))
    views=[('North',0),('East',3),('South',2),('West',1)]
    def panel(state,index):
        canvas=Image.new('RGB',(512,552),(33,35,38));draw=ImageDraw.Draw(canvas)
        for slot,(label,direction) in enumerate(views):
            x=(slot%2)*256;y=(slot//2)*276
            with Image.open(cap/f'frames/{state}/d{direction:02d}/f{index:03d}.png') as im:
                rgba=im.convert('RGBA');canvas.paste(rgba,(x,y),rgba.getchannel('A'))
            draw.text((x+12,y+259),label,fill='white')
        return canvas
    panel('idle',0).save(out/'electrolyzer-four-angle-idle.png')
    frames=[panel('working',i) for i in range(8)]
    frames[0].save(out/'electrolyzer-four-angle-working.gif',save_all=True,append_images=frames[1:],duration=500,loop=0,disposal=2)
    frames[0].save(out/'electrolyzer-four-angle-working.webp',save_all=True,append_images=frames[1:],duration=500,loop=0,lossless=True)
    review=dict(status='VISUALLY_REVIEWED_FINISH_CANDIDATE; OWNER_REVIEW_AND_NATIVE_PROTOTYPE_OPEN',
        source_sha256=sha(source),export_sha256=sha(glb),
        reference=dict(path='art/source-to-3d/metallic-hydrogen-chain/water-purifier/v16-owner-accepted/purifier-four-angle-idle.png',
            sha256=sha(repo/'art/source-to-3d/metallic-hydrogen-chain/water-purifier/v16-owner-accepted/purifier-four-angle-idle.png')),
        images={str(p.relative_to(out)).replace('\\','/'):sha(p) for d in ('export-inspection','export-details') for p in (out/d).glob('*.png')},
        scale='0 to 5; final threshold 4 per criterion',
        scores={'silhouette':dict(score=4,reason='Distinct twin closed cells, rear rectifier, grounded uprights and isolated side gas lines read at game scale.'),
            'construction':dict(score=4,reason='Actual opened tee/nozzle bores; wider gas returns; bonnet-seated stems; supported wheel spokes, insulated electrical lugs and corrected cell plinths. Targeted contact and sampled bore proof, not manufacturing certification.'),
            'surfaces':dict(score=4,reason='Native and actual GLB front/rear/clay and oblique closeups viewed. Nine packed maps follow cell circumference, band contact levels, front window drip and actual cover retaining heads; no uniform recolor.'),
            'motion_states':dict(score=4,reason='Standby hides gas tracers; working rises with hidden reset. Actual merged glTF idle/working clips match ten sampled native poses, four-second loop closes. Four real capture angles are separately recorded.'),
            'native_integration':dict(score=0,reason='No actual electrolyzer prototype or fluid assignment/graphical pipe jig yet.')},owner_approved=False)
    write(out/'VISUAL_REVIEW.json',review)
    registry_path=repo/'art/source-to-3d/shared-parts/metallic-hydrogen/registry.json'
    registry=json.loads(registry_path.read_text());previous=sha(registry_path)
    provenance=json.loads((out/'part_provenance.json').read_text());entries=[]
    for instance in provenance['instances']:
        part=next(p for p in registry['parts'] if p['part_id']==instance['part_id'] and p['revision']==instance['revision'])
        if sha(registry_path.parent/part['source_blend'])!=instance['source_sha256']:raise RuntimeError('Frozen library source changed')
        entry=dict(machine='electrolyzer',machine_revision='V05 finish and state candidate',instance=instance['instance'],
                   transform=instance['transform'],model_source_sha256=sha(source),runtime_export_sha256=sha(glb),
                   status='actual saved/rendered/reimported candidate; native integration open')
        part['consumers'].append(entry);entries.append(dict(part_id=part['part_id'],revision=part['revision'],**entry))
        component=dict(part);component.update(source_blend='part.blend',thumbnail='thumbnail.png',verification='verification.json')
        write((registry_path.parent/part['source_blend']).parent/'part.json',component)
    registry['previous_registry_sha256']=previous;registry['instances_by_machine']['electrolyzer']=entries;write(registry_path,registry)
    contacts=json.loads((out/'contact-readback.json').read_text());routes=json.loads((out/'route-readback.json').read_text())
    checkpoint=dict(status='visual_reviewed_candidate',machine='electrolyzer',planned_footprint=[3,4],
        source_sha256=sha(source),glb_sha256=sha(glb),registry_sha256=sha(registry_path),
        contacts=contacts['contact_count'],sampled_core_rays=routes['segment_probes'],
        native_bore_rays=audit['native_bores']['rays'],export_bore_rays=audit['runtime_bores']['rays'],
        capture_frames=36,atlas_count=6,cycle_seconds=4,native_ports_verified=False,owner_approved=False,
        no_new_verified_parts='Existing frozen console and mouths retained; machine completion prioritized over speculative harvesting.',
        next=['actual isolated electrolyzer prototype, three native fluid assignments and rotated pipe jig','graphical connected/disconnected cap seating','compressor construction'])
    write(out/'CHECKPOINT.json',checkpoint)
    continuation_path=repo/'docs/art/metallic-hydrogen-chain/PRODUCTION_CONTINUATION.json'
    continuation=json.loads(continuation_path.read_text());continuation['current_candidate']=str(out);continuation['electrolyzer']=checkpoint
    continuation['library_registry_sha256']=sha(registry_path)
    for row in continuation['queue']:
        if row['id']=='electrolyzer':row['status']='visual_reviewed_candidate; native prototype pending'
    continuation['next_steps']=['Verify electrolyzer actual prototype and pipe-fitting jig','Continue remaining five distinct precursor machines','Whole-chain prototype integration','Recover and refine three plasma reactors']
    write(continuation_path,continuation)
    (out/'README.md').write_text('# Electrolyzer V05 finish and state candidate\n\n'
        'Distinct editable 3x4 electrolyzer: opened water tee and inlet bores; clear disjoint gas returns; insulated rectifier-to-cell busbars; supported handwheels and console conduit; grounded cell plinths. Nine packed model-specific PBR maps finish the cell wraps and retained rectifier cover.\n\n'
        'The saved source is `electrolyzer-v05.blend`, actual runtime interchange is `electrolyzer-v05.glb`. Earlier tool receipts retain the staging source filename `electrolyzer-v01.blend`; the SHA-256 binds these exact unchanged bytes. Native and GLB sampled process cores, external bores, targeted contacts and all sampled idle/working poses pass. Actual exported front/rear/clay and oblique closeups were reviewed. The GLB contains coherent `idle` and four-second `working` clips.\n\n'
        'Four actual model rotations, four idle views and eight working frames per angle are included. Source timeline is 24 fps; review captures are eight uniform poses over four seconds, previewed at 2 fps. The first sampling study remains in staging because two 64px west-view cells aliased; this delivery keeps the same clock with a three-source-frame phase offset.\n\n'
        'This is a visually reviewed construction/finish candidate, with no owner approval inferred. Actual native prototype/recipe fluid assignments and graphical pipe seating remain open. No ordinary mod installation or complete-chain delivery is claimed. Frozen V01 and failed repair/export/capture studies remain preserved.\n',encoding='utf-8')
    write(out/'SHA256.json',{str(p.relative_to(out)).replace('\\','/'):sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    print('ELECTROLYZER_V05_CHECKPOINT',out,flush=True)


if __name__=='__main__':main()
