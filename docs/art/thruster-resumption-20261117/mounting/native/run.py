"""Isolated four-drive native Factorio acceptance. No normal profiles or saves."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, socket, subprocess, sys, time, zipfile

SCRIPT = Path(__file__).resolve()
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('mode',choices=['prepare','create','test','server','reload'])
parser.add_argument('--source-root',type=Path)
parser.add_argument('--output-root',type=Path,default=SCRIPT.parent)
parser.add_argument('--factorio',type=Path,default=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'))
args=parser.parse_args()
ROOT = args.output_root.resolve()
ROOT.mkdir(parents=True,exist_ok=True)
candidates=[p for p in SCRIPT.parents]+[SCRIPT.parent.parents[1]/'model-production']
REPO=args.source_root.resolve() if args.source_root else next(p for p in candidates if(p/'tech-priests_src/info.json').exists())
SOURCE=REPO/'tech-priests_src'
EXE = args.factorio.resolve()
MODS = ROOT / 'mods'
USER = ROOT / 'user-data'
mode = args.mode

if mode == 'prepare':
    target = MODS / 'tech-priests'
    if target.exists():
        raise SystemExit('Refusing to overwrite an existing source snapshot')
    inputs = {}
    for p in SOURCE.rglob('*'):
        if not p.is_file():
            continue
        rel = p.relative_to(SOURCE)
        q = target / rel
        q.parent.mkdir(parents=True, exist_ok=True)
        if p.suffix.lower() in {'.png', '.ogg', '.wav', '.jpg'}:
            try:
                os.link(p, q)
            except OSError:
                shutil.copy2(p, q)
        else:
            shutil.copy2(p, q)
        inputs[rel.as_posix()] = hashlib.sha256(q.read_bytes()).hexdigest()
    addon = MODS / 'thruster-resume-proof'
    addon.mkdir(parents=True)
    for name in ('control.lua', 'data.lua'):
        shutil.copy2(SCRIPT.parent / name, addon / name)
    (addon / 'info.json').write_text(json.dumps(dict(name='thruster-resume-proof',version='0.0.1',title='Private four-drive native proof',author='Local test',factorio_version='2.1',dependencies=['base','space-age','tech-priests'])))
    (MODS / 'mod-list.json').write_text(json.dumps(dict(mods=[dict(name=n,enabled=True) for n in ('base','quality','space-age','elevated-rails','tech-priests','thruster-resume-proof')])))
    USER.mkdir(exist_ok=True)
    (ROOT/'config.ini').write_text('[path]\nread-data='+str(EXE.parents[2]/'data')+'\nwrite-data='+str(USER)+'\n[other]\ncheck-updates=false\n')
    (ROOT/'map-gen.json').write_text(json.dumps(dict(seed=17112026,peaceful_mode=True,water=0,autoplace_controls={'enemy-base':dict(frequency='none',size='none',richness='none')})))
    (ROOT/'steam_appid.txt').write_text('427520')
    (ROOT/'source-binding.json').write_text(json.dumps(dict(source=str(SOURCE),files=inputs,scope='Exact working-copy source snapshot; Lua/text copied; immutable image/audio files hardlinked. No source mutation.'),indent=2))
    print('PREPARED',len(inputs),'source files')
    raise SystemExit()

common = [str(EXE),'--config',str(ROOT/'config.ini'),'--mod-directory',str(MODS)]
if mode == 'create':
    tail = ['--create',str(ROOT/'thruster-proof.zip'),'--map-gen-settings',str(ROOT/'map-gen.json')]
elif mode == 'test':
    tail = ['--benchmark',str(ROOT/'thruster-proof.zip'),'--benchmark-ticks','1561','--benchmark-runs','1']
elif mode == 'reload':
    tail = ['--benchmark',str(next((USER/'saves').glob('*thruster-resume-complete*.zip'))),'--benchmark-ticks','61','--benchmark-runs','1']
elif mode == 'server':
    settings=ROOT/'server-settings.json'
    config=json.loads((EXE.parents[2]/'data/server-settings.example.json').read_text())
    config.update(dict(name='Private thruster proof',description='Isolated loopback-only native four-drive acceptance',visibility=dict(public=False,lan=False),require_user_verification=False,auto_pause=False,autosave_interval=1000))
    settings.write_text(json.dumps(config))
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as probe:
        probe.bind(('127.0.0.1',0));port=probe.getsockname()[1]
    tail=['--start-server',str(ROOT/'thruster-proof.zip'),'--server-settings',str(settings),'--bind','127.0.0.1','--port',str(port)]
else:
    raise ValueError(mode)
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
with (ROOT/(mode+'.log')).open('w',encoding='utf-8') as out:
    if mode=='server':
        process=subprocess.Popen(common+tail,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT,startupinfo=startup)
        passed=False
        deadline=time.monotonic()+90
        try:
            while time.monotonic()<deadline and process.poll() is None:
                saves=list((USER/'saves').glob('*thruster-resume-complete*.zip'))
                if saves and 'Saving finished' in (ROOT/'server.log').read_text(errors='replace'):
                    try:
                        with zipfile.ZipFile(saves[0]) as z:passed=z.testzip() is None
                    except (OSError,zipfile.BadZipFile):passed=False
                    if passed:break
                time.sleep(.25)
        finally:
            if process.poll()is None:process.terminate();process.wait(timeout=10)
        rc=0 if passed else 1
    else:
        process = subprocess.run(common+tail,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT,startupinfo=startup,timeout=240)
        rc=process.returncode
print('NATIVE',mode,rc)
if rc:
    print((ROOT/(mode+'.log')).read_text(errors='replace')[-5000:])
raise SystemExit(rc)
