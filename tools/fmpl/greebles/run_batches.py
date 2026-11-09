#!/usr/bin/env python3
"""Bounded local-runner Blender extraction orchestrator; no GitHub Actions workflow.

Default: ONE 8-object batch; --batches 40 covers the initial 320-candidate index.
Runs synchronously with durable per-batch logs; failures halt without deleting parts.
"""
from __future__ import annotations
import argparse
import csv
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from deatlas_core import atomic_json,sha256_file,verified_checkpoint


def run(argv):
    p=argparse.ArgumentParser()
    p.add_argument('--blender',required=True,help='Blender 5.x executable path')
    p.add_argument('--source',default=os.getenv('FMPL_GREEBLES_BLEND'))
    p.add_argument('--out',required=True,help='Private runner-side parts directory')
    p.add_argument('--offset',type=int,default=0)
    p.add_argument('--batch-size',type=int,default=8)
    p.add_argument('--batches',type=int,default=1)
    p.add_argument('--retries',type=int,default=1)
    p.add_argument('--timeout',type=int,default=2400)
    p.add_argument('--dry-run',action='store_true')
    a=p.parse_args(argv)
    if not a.source:p.error('Source path or FMPL_GREEBLES_BLEND required')
    if a.offset<0 or a.batches<1 or not (1<=a.batch_size<=32) or a.retries<0 or a.retries>3 or a.timeout<60:
        p.error('Invalid bounded batch parameters')
    source=Path(a.source).expanduser().resolve()
    out=Path(a.out).expanduser().resolve()
    if not source.is_file():raise FileNotFoundError(str(source))
    meta=json.loads((HERE/'source.json').read_text(encoding='utf-8'))
    if source.stat().st_size!=meta['payload_bytes'] or sha256_file(source)!=meta['sha256']:
        raise ValueError('Wrong Drive source, refusing extraction')
    if out==source.parent or out==source or out in source.parents or source in out.parents:
        raise ValueError('Source and output directory must be separate')
    blender=str(Path(a.blender).expanduser().resolve())
    if not Path(blender).is_file():raise FileNotFoundError(blender)
    if shutil.disk_usage(out.parent if out.parent.exists() else source.parent).free<1024*1024*1024:
        raise RuntimeError('Refusing extraction with under 1 GiB free')
    out.mkdir(parents=True,exist_ok=True)
    logs=out/'logs'
    logs.mkdir(exist_ok=True)
    for iteration in range(a.batches):
        offset=a.offset+iteration*a.batch_size
        if offset>=320:
            break
        limit=min(a.batch_size,320-offset)
        command=[blender,'--background',str(source),'--python',str(HERE/'deatlas.py'),'--',
                 '--out',str(out),'--offset',str(offset),'--limit',str(limit),'--resume']
        if a.dry_run:command.append('--dry-run')
        for attempt in range(1,a.retries+2):
            log=logs/f'batch_{offset:03d}_attempt{attempt}.log'
            try:
                with log.open('w',encoding='utf-8',errors='replace') as f:
                    result=subprocess.run(command,stdout=f,stderr=subprocess.STDOUT,
                                          timeout=a.timeout,check=False)
                code=result.returncode
            except subprocess.TimeoutExpired:
                code=124
            if code==0:
                print('FMPL_BATCH_OK',offset,limit,str(log),flush=True)
                break
            print('FMPL_BATCH_FAILED',offset,code,'log',str(log),flush=True)
            if attempt>a.retries:
                raise RuntimeError('Extraction failed, preserved checkpoints and logs; inspect before retry')
            time.sleep(min(10*attempt,30))
    return 0

if __name__=='__main__':
    raise SystemExit(run(sys.argv[1:]))
