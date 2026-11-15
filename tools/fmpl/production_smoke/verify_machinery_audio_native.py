"""Load all three real review prototypes with the audio-only extension."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--factorio',required=True);ap.add_argument('--purifier',required=True)
    ap.add_argument('--electrolyzer',required=True);ap.add_argument('--compressor',required=True);ap.add_argument('--audio',required=True);ap.add_argument('--out',required=True)
    args=ap.parse_args();out=Path(args.out).resolve();exe=Path(args.factorio).resolve()
    if out.exists():raise FileExistsError('Retain native audio validation evidence')
    out.mkdir(parents=True);mods=out/'mods';mods.mkdir();user=out/'user-data';user.mkdir();enabled={'base'}
    for source in (args.purifier,args.electrolyzer,args.compressor,args.audio):
        source=Path(source).resolve();shutil.copytree(source,mods/source.name)
        enabled.add(json.loads((source/'info.json').read_text())['name'])
    names=sorted(enabled|{'elevated-rails','space-age','quality','recycler'})
    (mods/'mod-list.json').write_text(json.dumps({'mods':[dict(name=n,enabled=n in enabled) for n in names]}))
    config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n')
    (out/'steam_appid.txt').write_text('427520')
    with (out/'native-audio-data.log').open('w') as log:
        result=subprocess.run([str(exe),'--config',str(config),'--mod-directory',str(mods),'--dump-data'],cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=180)
    if result.returncode:raise RuntimeError('Native sound/prototype data load failed')
    raw=json.loads((user/'script-output/data-raw-dump.json').read_text());records=[]
    for name,gain in (('tp-mh7-review-purifier',.46),('tp-mh7-review-electrolyzer',.40),('tp-mh7-review-compressor',1.15)):
        sound=raw['assembling-machine'][name]['working_sound'];working=sound['sound']
        if not math.isclose(working['volume'],gain,rel_tol=1e-9) or not working['filename'].startswith('__tp-mh7-machinery-audio__/sound/'):raise RuntimeError('Native audio binding differs '+name)
        records.append(dict(entity=name,working_sound=sound))
    report=dict(passed=True,native_data_stage_exit=result.returncode,bindings=records,
        native_dump_sha256=sha(user/'script-output/data-raw-dump.json'),log_sha256=sha(out/'native-audio-data.log'),
        scope='Actual Factorio data-stage sound prototypes with all three real machine review mods. Codec/sample checks are in authored audio receipt; owner audition and ordinary chain installation remain separate.')
    (out/'native-audio-readback.json').write_text(json.dumps(report,indent=2)+'\n');print('NATIVE_MACHINE_AUDIO_BOUND',len(records),flush=True)


if __name__=='__main__':main()
