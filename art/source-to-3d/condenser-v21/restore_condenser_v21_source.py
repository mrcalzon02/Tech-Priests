"""Reconstitute the owner-approved condenser V21 Blender source from Git-tracked parts.

Lossless binary restoration only. Does not invoke Blender or alter source meshes.
Fails closed if a part, byte count, digest, order, or final SHA-256 differs.

Usage:
    python3 art/source-to-3d/condenser-v21/restore_condenser_v21_source.py \
       --out /tmp/tech_priests_water_condenser_v21.blend
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
APPROVED_SHA = '1ccd8093e5b153d80b7ac66cb77b364f05e7ee46a5f236efe189498b71dd052b'
APPROVED_BYTES = 39369602
APPROVED_FILE = 'tech_priests_water_condenser_v21.blend'


class RestoreError(RuntimeError):
    """Fail-safe source recovery error, never silently use guessed geometry."""


def assemble(source_parts: Path, output: Path, *, expected_sha: str = APPROVED_SHA,
             expected_bytes: int = APPROVED_BYTES) -> Path:
    source_parts = Path(source_parts).resolve(strict=True)
    output = Path(output).expanduser().absolute()
    manifest = json.loads((source_parts / 'source_manifest.json').read_text(encoding='utf-8'))
    if (manifest.get('approved_source_sha256') != expected_sha or
            manifest.get('approved_source_size_bytes') != expected_bytes or
            manifest.get('approved_source_filename') != APPROVED_FILE):
        raise RestoreError('Unexpected manifest/source identity; refusing unapproved model')
    parts = manifest.get('parts')
    if not isinstance(parts, list) or not parts or len(parts) != manifest.get('part_count'):
        raise RestoreError('Invalid number of source parts')
    if [p.get('file') for p in parts] != [f'condenser_v21.blend.part{i:02d}' for i in range(len(parts))]:
        raise RestoreError('Part order or part names changed')
    if sum(int(p.get('bytes', 0)) for p in parts) != expected_bytes:
        raise RestoreError('Part lengths disagree with approved source')
    if output.exists() or output.is_symlink():
        raise RestoreError('Refusing to overwrite recovered Blender source: ' + str(output))
    output.parent.mkdir(parents=True, exist_ok=True)
    total = 0
    whole = hashlib.sha256()
    try:
        with output.open('xb') as target:
            for descriptor in parts:
                part = source_parts / descriptor['file']
                if not part.is_file() or part.is_symlink():
                    raise RestoreError('Missing or unsafe part: ' + str(part))
                if part.stat().st_size != descriptor['bytes']:
                    raise RestoreError('Part size incorrect: ' + str(part))
                local_digest = hashlib.sha256()
                with part.open('rb') as stream:
                    while block := stream.read(1024 * 1024):
                        target.write(block)
                        whole.update(block)
                        local_digest.update(block)
                        total += len(block)
                if local_digest.hexdigest() != descriptor['sha256']:
                    raise RestoreError('Part SHA256 incorrect: ' + str(part))
        if total != expected_bytes or whole.hexdigest() != expected_sha:
            raise RestoreError('Final Blender V21 file SHA256 or byte count incorrect')
    except BaseException:
        output.unlink(missing_ok=True)
        raise
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--parts',type=Path,default=HERE/'source-parts')
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    result=assemble(args.parts,args.out)
    print('CONDENSER_V21_EXACT_SOURCE_RESTORED',result,APPROVED_SHA,flush=True)

if __name__ == '__main__':
    main()