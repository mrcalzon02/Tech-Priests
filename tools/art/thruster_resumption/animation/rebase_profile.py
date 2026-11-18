"""Stage an honest new underlay/quality capture; retain every original artifact.

This creates a new profile, not relabeled or reused old frame evidence. All
selected frames must actually render against the replacement assembly.
"""
import argparse,hashlib,json,pathlib
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--previous',type=pathlib.Path,required=True);p.add_argument('--underlay',type=pathlib.Path,required=True);p.add_argument('--validation',type=pathlib.Path,required=True);p.add_argument('--samples',type=int,default=64);p.add_argument('--out',type=pathlib.Path,required=True);a=p.parse_args()
previous=a.previous.resolve();old=json.loads(previous.read_text());cfg=json.loads((previous.parent/'profile.json').read_text());under=a.underlay.resolve();validation=a.validation.resolve();proof=json.loads(validation.read_text());assert str(proof.get('status','')).startswith('PASS');assert old['input_glb']['sha256']in json.dumps(proof)and sha(under)in json.dumps(proof),'Replacement underlay is not bound to this unchanged body'
assert sha(pathlib.Path(cfg['glb']))==cfg['glb_sha256']==old['input_glb']['sha256'];assert sha(previous.parent/'capture-master.blend')==old['master_sha256']
cfg['underlay']={'glb':str(under),'sha256':sha(under),'validation':{'path':str(validation),'sha256':sha(validation)}};cfg['camera_lock']=old['camera_profile'];cfg['samples']=a.samples;cfg['denoise_cold']=True
cfg['rebase']={'previous_capture_receipt':str(previous),'previous_capture_receipt_sha256':sha(previous),'previous_master_sha256':old['master_sha256'],'physical_body_unchanged':True,'meaning':'New replacement-underlay/quality derivative. Previous source captures are retained; no old frame is relabeled as a new render. Original canonical camera is locked for direct registration comparison.'}
assert not a.out.exists(),'Refuse to overwrite an existing profile';a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(cfg,indent=2)+'\n');print(a.out.resolve())
