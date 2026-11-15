"""Reconcile this detached production checkout without resetting other worktrees.

Inspect first. Preserve differing local files before applying remote versions;
leave unrelated untracked files alone and retain sparse, absent art as absent.
"""
import argparse,hashlib,json,subprocess,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/turret-reconciliation';OUT.mkdir(exist_ok=True)
def git(*args,input=None):
    return subprocess.check_output(['git',*args],cwd=ROOT,input=input)
def tree(ref):
    result={}
    for row in git('ls-tree','-rz',ref).split(b'\0'):
        if not row:continue
        meta,name=row.split(b'\t',1);mode,kind,sha=meta.decode().split()
        if kind=='blob':result[name.decode()]={'sha':sha,'mode':mode}
    return result
def blob(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
def main():
    p=argparse.ArgumentParser();p.add_argument('--target',required=True);p.add_argument('--apply',action='store_true')
    p.add_argument('--resolve-remote',action='append',default=[]);a=p.parse_args()
    head=git('rev-parse','HEAD').decode().strip();old=tree(head);new=tree(a.target)
    assert not git('branch','--show-current').strip(),'This tool only advances a detached checkout'
    updates=[];conflicts=[];already=[];removed=[]
    text_roots=('tech-priests_src/','docs/','tools/','tests/','.github/')
    for name in sorted(set(old)|set(new)):
        if old.get(name)==new.get(name):continue
        path=ROOT/name
        local=None
        if path.is_file():
            local=blob(path.read_bytes())
            expected={x['sha'] for x in (old.get(name),new.get(name)) if x}
            if local not in expected:
                local=git('hash-object','--path='+name,str(path)).decode().strip()
        if name in new and local==new[name]['sha']:already.append(name);continue
        if local is not None and (name not in old or local!=old[name]['sha']):
            conflicts.append(name);continue
        if name not in new:
            if path.is_file():removed.append(name)
        elif path.exists() or name.startswith(text_roots):updates.append(name)
    plan={'old_head':head,'target':a.target,'updates':updates,'already_published':already,'conflicts':conflicts,'remote_removed':removed}
    (OUT/'plan.json').write_text(json.dumps(plan,indent=2)+'\n')
    print('RECONCILIATION_PLAN',len(updates),'updates',len(already),'already published',len(conflicts),'conflicts',len(removed),'removed')
    if not a.apply:return
    assert set(conflicts)==set(a.resolve_remote),'Resolve conflicting files explicitly before applying'
    assert not removed,'Resolve remote removals explicitly before applying'
    # Capture all modified tracked files before metadata or worktree changes.
    dirty=git('diff','--name-only','-z').decode().strip('\0').split('\0')
    with zipfile.ZipFile(OUT/'pre-reconcile-local.zip','w',zipfile.ZIP_DEFLATED) as archive:
        for name in sorted(set(dirty+conflicts)):
            if name and (ROOT/name).is_file():archive.write(ROOT/name,name)
        archive.writestr('reconciliation-plan.json',json.dumps(plan,indent=2))
    git('update-ref','refs/checkpoints/turret-pre-reconciliation',head)
    # Fetch/write only the selected files, never touching local-only assets.
    for name in updates+conflicts:
        path=ROOT/name;path.parent.mkdir(parents=True,exist_ok=True)
        path.write_bytes(git('cat-file','blob',new[name]['sha']))
    git('read-tree',a.target)
    indexed=git('ls-files','-z').decode().strip('\0').split('\0')
    absent=[name for name in indexed if not (ROOT/name).exists()]
    if absent:git('update-index','--skip-worktree','-z','--stdin',input='\0'.join(absent).encode()+b'\0')
    git('update-ref','--no-deref','HEAD',a.target,head)
    status=git('status','--porcelain','-uno').decode()
    plan.update(status='RECONCILED',tracked_status=status,absent_sparse_files=len(absent),resolved_remote=conflicts)
    (OUT/'receipt.json').write_text(json.dumps(plan,indent=2)+'\n')
    print('RECONCILED_HEAD',a.target,'tracked changes:',repr(status))
if __name__=='__main__':main()
