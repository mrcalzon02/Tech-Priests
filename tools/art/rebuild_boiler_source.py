#!/usr/bin/env python3
"""Rebuild the editable V08 source from the exact approved V07b, locally only."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--blender', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    asset = ROOT/'art/source-to-3d/boiler-v08'
    record = asset/'Boiler_V08_Animation_Record.json'
    expected = json.loads(record.read_text(encoding='utf-8'))
    if hashlib.sha256(args.source.read_bytes()).hexdigest() != expected['source_sha256']:
        raise ValueError('Source does not match approved V07b SHA-256')
    out = args.out.resolve()
    if out.exists():
        raise FileExistsError('Use a fresh output directory; existing work is never overwritten')
    (out/'upload').mkdir(parents=True)
    shutil.copy2(args.source, out/'upload'/expected['source'])

    def blender(script, scene=None, extra=()):
        command = [str(args.blender.resolve()), '--factory-startup', '--background']
        if scene:
            command.append(str(scene))
        command += ['--python-exit-code', '12', '--python', str(script)]
        if extra:
            command += ['--', *map(str, extra)]
        subprocess.run(command, check=True)

    for name in ('animate_boiler_v08.py', 'cleanup_boiler_v08_cameras.py', 'validate_boiler_v08.py'):
        shutil.copy2(asset/name, out/name)
        blender(out/name)
    animated = out/'boiler_v08/tech_priests_emergency_boiler_v08_animated.blend'
    prepared = out/'production-source.blend'
    blender(ROOT/'tools/art/prepare_boiler_source.py', animated, ('--out', prepared))
    blender(ROOT/'tools/art/verify_rebuilt_boiler_source.py', prepared,
            ('--record', record, '--rebuilt-record', out/'boiler_v08/Boiler_V08_Animation_Record.json',
             '--report', out/'source-recovery-validation.json'))
    print('Rebuilt source verified:', prepared)


if __name__ == '__main__':
    main()
