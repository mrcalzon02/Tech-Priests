"""Preserve a real exported pilot and record its actual registered-part reuse."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def write(path,value):
    path=Path(path);tmp=path.with_suffix(path.suffix+'.tmp');tmp.write_text(json.dumps(value,indent=2)+'\n');tmp.replace(path)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--staging',required=True);ap.add_argument('--out',required=True)
    ap.add_argument('--registry',required=True);ap.add_argument('--resume',action='store_true');args=ap.parse_args()
    staging=Path(args.staging).resolve();out=Path(args.out).resolve();registry_path=Path(args.registry).resolve()
    if out.exists() and not args.resume:raise FileExistsError('Preserve previous pilot; explicit resume validates existing bytes')
    audit=json.loads((staging/'independent-readback.json').read_text())
    provenance=json.loads((staging/'part_provenance.json').read_text())
    if audit['errors']:raise RuntimeError('Pilot technical failures remain')
    out.mkdir(parents=True,exist_ok=args.resume)
    if not (out/'.gitattributes').exists():(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    def copy_exact(source,target):
        if target.exists():
            if sha(source)!=sha(target):raise RuntimeError('Resume would overwrite changed artifact: '+str(target))
        else:
            target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    for name in ('electrolyzer-v01.blend','electrolyzer-v01.glb','working-front.png','construction-receipt.json',
                 'independent-readback.json','port_manifest.json','part_provenance.json'):
        copy_exact(staging/name,out/name)
    for file in (staging/'export-inspection-ports').rglob('*'):
        if file.is_file():copy_exact(file,out/'export-inspection'/file.relative_to(staging/'export-inspection-ports'))
    registry=json.loads(registry_path.read_text());prior_sha=sha(registry_path)
    entries=[]
    for instance in provenance['instances']:
        entry=next(x for x in registry['parts'] if x['part_id']==instance['part_id'] and x['revision']==instance['revision'])
        master=registry_path.parent/entry['source_blend']
        if sha(master)!=instance['source_sha256']:raise RuntimeError('Frozen part master changed')
        entry['parameters']={'uniform_scale':dict(default=1.0,safe_range=[1.0,1.0]),'placement':'rigid transform only'}
        consumer=dict(machine='electrolyzer',machine_revision='V01 pilot',instance=instance['instance'],transform=instance['transform'],
            model_source_sha256=sha(out/'electrolyzer-v01.blend'),runtime_export_sha256=sha(out/'electrolyzer-v01.glb'),
            status='actual saved/rendered/reimported candidate; final machine review open')
        entry['consumers'].append(consumer);entries.append(dict(part_id=entry['part_id'],revision=entry['revision'],**consumer))
        component=dict(entry);component.update(source_blend='part.blend',thumbnail='thumbnail.png',verification='verification.json')
        write(master.parent/'part.json',component)
    registry['instances_by_machine']['electrolyzer']=entries
    registry['previous_registry_sha256']=prior_sha;write(registry_path,registry)
    review=dict(status='VISUALLY_REVIEWED_CONSTRUCTION_PILOT; NOT_FINAL',
        source_sha256=sha(out/'electrolyzer-v01.blend'),export_sha256=sha(out/'electrolyzer-v01.glb'),
        images={str(p.relative_to(out)):sha(p) for p in out.rglob('*.png')},
        scale='0 to 5; final threshold 4 per criterion',
        scores={'silhouette':dict(score=4,reason='Two closed cell stacks, rear rectifier and separate gas paths read clearly.'),
                'construction':dict(score=3,reason='Frames, caps, cell windows, busbars and donor mouths exist; full contact/line audit remains.'),
                'surfaces':dict(score=3,reason='Loaded packed PBR and coherent material roles; individual wear, finishing and closeups remain.'),
                'motion_states':dict(score=2,reason='Real keyed gas nucleation and donor green bars; no final state/loop capture yet.'),
                'native_integration':dict(score=0,reason='Actual target, native fluid IDs and prototype interfaces remain unassigned. Model-space bores alone are not game connectivity.')},
        owner_approved=False)
    write(out/'VISUAL_REVIEW.json',review)
    checkpoint=dict(status='candidate_exported',machine='electrolyzer',planned_footprint=[3,4],
        provenance='new reconstruction from approved style/process packet; not edited unseen v0.2 geometry',
        actual_reused_master_parts=2,actual_reused_instances=4,
        source_sha256=sha(out/'electrolyzer-v01.blend'),glb_sha256=sha(out/'electrolyzer-v01.glb'),
        registry_sha256=sha(registry_path),native_bore_rays=audit['native_bores']['rays'],
        export_bore_rays=audit['runtime_bores']['rays'],native_ports_verified=False,
        no_new_verified_parts='construction pilot only; do not delay next work with speculative harvesting',
        next=['support/contact and process route audit','model-specific finishing and closeup inspection','animation states and direction captures','actual prototype and pipe fitting jig'])
    write(out/'CHECKPOINT.json',checkpoint)
    (out/'README.md').write_text('# Electrolyzer V01 construction pilot\n\n'
        'A real distinct 3x4 saved Blender model, GLB and actual native/reimported front/rear/clay views. '
        'It reuses the accepted purifier console and three verified full-size pipe-mouth instances, with frozen source hashes and transforms. '
        'The first import/reducer studies remain in ignored staging; this version clears 111 rays at the three mouths in both native and exported geometry.\n\n'
        'This is a new reconstruction from the seven-machine process packet, not a claim to have edited unrecovered historical v0.2 meshes. '
        'Final finishing, complete contact QA, state captures and native prototype/recipe interfaces remain open. No owner acceptance is implied.\n',encoding='utf-8')
    write(out/'SHA256.json',{str(p.relative_to(out)).replace('\\','/'):sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    print('ELECTROLYZER_CHECKPOINT',out,'registered instances',len(entries))

if __name__=='__main__':main()
