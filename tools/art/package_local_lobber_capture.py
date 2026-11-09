"""Package a complete A02 capture without letting the legacy assembler delete it.

Run with the same Pillow-enabled Python used by the capture verifier. The original
assembler is retained unchanged; only disposable staging links/copies are deleted.
"""
import argparse,hashlib,json,os,pathlib,shutil,subprocess,sys,zipfile,time

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for flag in ('pipeline','capture','staging','output'):
        p.add_argument('--'+flag,type=pathlib.Path,required=True)
    p.add_argument('--accept-resumed-for-verification',action='store_true',help='Allow the explicit recovered-cache state; full PNG verification still precedes staging.')
    a=p.parse_args();pipeline=a.pipeline.resolve();capture=a.capture.resolve();staging=a.staging.resolve();output=a.output.resolve()
    roots=[pipeline,capture,staging,output]
    for i,left in enumerate(roots):
        for right in roots[i+1:]:
            if left==right or left.is_relative_to(right) or right.is_relative_to(left):
                raise ValueError('Pipeline, capture, staging and output must be separate, non-nested directories')
    if staging.exists() or output.exists():raise FileExistsError('Use new staging/output paths; existing partial packages are preserved')
    state_path=capture/'local-capture-state.json'
    state=json.loads(state_path.read_text())
    accepted={'all_384_chunks_complete'}
    if a.accept_resumed_for_verification:accepted.add('resumed_chunks_ready_for_full_cache_verification')
    if state.get('status')not in accepted or state.get('completed_count')!=384 or state.get('live_jobs'):
        raise RuntimeError('Full 384-chunk capture has not completed; no staging or output created')
    if not shutil.which('ffmpeg'):raise RuntimeError('Install/locate ffmpeg before packaging; no staging or output created')
    sys.path.insert(0,str(pipeline));import recover_export as recovery
    expected=recovery.expected_identity()
    if state['source_identity']!=expected:raise ValueError('Manager/source identity mismatch')
    if hashlib.sha256((pipeline/'lobber_capture.blend').read_bytes()).hexdigest()!=expected['source_sha256']:
        raise ValueError('Native source identity mismatch')
    files={};verification=capture/'full-verification';verification.mkdir(exist_ok=True);progress={'status':'FULL_PNG_DECODE_VERIFICATION_IN_PROGRESS','pid':os.getpid(),'source_identity':expected,'headings':[]}
    for d in range(64):
        identity_path=capture/f'd{d:02}'/'identity.json'
        if json.loads(identity_path.read_text())!=expected:raise ValueError('Heading identity mismatch')
        files[identity_path.relative_to(capture).as_posix()]=hashlib.sha256(identity_path.read_bytes()).hexdigest()
        heading={};saved=verification/f'd{d:02}.json';old=json.loads(saved.read_text()) if saved.exists() else None
        if old and old['source_identity']!=expected:raise ValueError('Prior decode proof belongs to a different source')
        for c in range(6):
            for pas,name in recovery.chunk_paths(d,c):
                if name in files:continue
                data=(capture/name).read_bytes();digest=hashlib.sha256(data).hexdigest()
                if not old or old['files'].get(name)!=digest:
                    if not recovery.valid(data,pas):raise ValueError('Invalid capture: '+name)
                files[name]=digest;heading[name]=digest
        saved.write_text(json.dumps({'status':'PASS_669_FULL_DECODED_RGBA_AND_ALPHA_MARGIN_IMAGES','source_identity':expected,'heading':d,'files':heading},indent=2)+'\n');progress['headings'].append({'direction':d,'images':len(heading),'receipt_sha256':hashlib.sha256(saved.read_bytes()).hexdigest()});(verification/'progress.json').write_text(json.dumps(progress,indent=2)+'\n');print('FULL_PNG_HEADING_VERIFIED',d,len(heading),flush=True)
    if len(files)!=42816+64:raise ValueError('Unexpected complete capture file count')
    progress.update(status='PASS_ALL_42816_SOURCE_PNGS_FULL_DECODE_AND_64_IDENTITIES',images=42816,verified_unix=time.time());(verification/'progress.json').write_text(json.dumps(progress,indent=2)+'\n');state.update(status='all_384_chunks_complete',full_cache_decode_verified=True,verification_receipt=str(verification/'progress.json'),verification_sha256=hashlib.sha256((verification/'progress.json').read_bytes()).hexdigest());temp=capture/'local-capture-state.tmp';temp.write_text(json.dumps(state,indent=2)+'\n');temp.replace(state_path)
    staging.mkdir(parents=True);record=staging/'preserved-input-manifest.json'
    report={'status':'verified_before_packaging','source_identity':expected,'capture':str(capture),'staging':str(staging),'output':str(output),'files':files}
    record.write_text(json.dumps(report,indent=2)+'\n')
    linked=copied=0
    for name in files:
        dest=staging/name;dest.parent.mkdir(parents=True,exist_ok=True)
        try:os.link(capture/name,dest);linked+=1
        except OSError:shutil.copy2(capture/name,dest);copied+=1
    command=[sys.executable,str(pipeline/'assemble_capture.py'),'--input',str(staging),'--output',str(output)]
    with (staging/'assembly.log').open('wb') as log:
        result=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT)
    # Even failed assembly must prove that original inputs survived unchanged.
    changed=[name for name,digest in files.items() if not (capture/name).is_file() or hashlib.sha256((capture/name).read_bytes()).hexdigest()!=digest]
    delivery_valid=False
    if result.returncode==0:
        delivery=json.loads((output/'delivery_manifest.json').read_text())
        assert delivery['status']=='VERIFIED_CAPTURE' and delivery['images']==42816
        for item in delivery['archives']:
            archive=(output/item['filename']).resolve()
            assert archive.is_relative_to(output) and archive.stat().st_size==item['bytes']
            assert hashlib.sha256(archive.read_bytes()).hexdigest()==item['sha256']
            with zipfile.ZipFile(archive) as z:assert z.testzip() is None
        delivery_valid=True
    report.update(status='packaged' if delivery_valid and not changed else 'failed_checkpoint_preserved',assembler_exit_code=result.returncode,hardlinks=linked,copies=copied,changed_original_inputs=changed)
    record.write_text(json.dumps(report,indent=2)+'\n')
    if result.returncode or changed:raise RuntimeError('Assembly failed or input preservation check failed; inspect checkpoint/log')
    print('PACKAGED_WITH_ORIGINAL_42816_PNGS_PRESERVED',flush=True)

if __name__=='__main__':main()
