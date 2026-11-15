"""Match sparse metadata to preserved local art without deleting any file.

The prior manual skip bits disagreed with broad cone rules. Rebase expanded
those rules and reported absent archives as deletions. Keep active code roots
and every currently materialized tracked file, excluding absent large archives.
"""
import subprocess,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def git(*args,input=None):return subprocess.check_output(['git',*args],cwd=ROOT,input=input)
assert git('config','--get','extensions.worktreeConfig').strip()==b'true'
out=ROOT/'build/turret-reconciliation';out.mkdir(exist_ok=True)
names=git('ls-files','-z').decode().strip('\0').split('\0')
roots=('.github','tech-priests_src','tests','tools','docs/art','docs/prototypes',
       'art/bunker-rocket-salvo','art/bunker-twin-cannon')
present=[n for n in names if (ROOT/n).exists()]
missing=[n for n in names if not (ROOT/n).exists()]
assert not any(n.startswith(('tech-priests_src/','tests/','tools/','.github/')) for n in missing),'Materialize active code before changing policy'
patterns=['/*','!/*/']+['/'+r+'/' for r in roots]
patterns+=['/'+n for n in present if '/' in n and not any(n.startswith(r+'/') for r in roots)]
file=Path(git('rev-parse','--git-path','info/sparse-checkout').decode().strip())
(out/'sparse-before.txt').write_bytes(file.read_bytes())
file.write_text('\n'.join(patterns)+'\n',encoding='utf-8')
git('config','--worktree','core.sparseCheckout','true')
git('config','--worktree','core.sparseCheckoutCone','false')
git('config','--worktree','index.sparse','false')
git('read-tree','HEAD')
if missing:git('update-index','--skip-worktree','-z','--stdin',input='\0'.join(missing).encode()+b'\0')
assert all((ROOT/n).exists() for n in present),'No local file may be removed'
status=git('status','--porcelain','-uno').decode()
(out/'sparse-repair.json').write_text(json.dumps({'status':'PRESERVED_AND_RECONCILED','present_files':len(present),
 'excluded_absent_files':len(missing),'tracked_status':status,'mode':'explicit non-cone; no filesystem deletion'},indent=2)+'\n')
assert not status,status
print('SPARSE_METADATA_REPAIRED',len(present),'preserved files',len(missing),'excluded absences')
