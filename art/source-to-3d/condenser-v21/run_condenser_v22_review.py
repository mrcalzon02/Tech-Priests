"""Cross-platform, source-locked one-command native Blender condenser V22 review.

This is a LOCAL RUNNER, not a GitHub Actions workflow or Factorio art install.
It locates the *exact* accepted V21 .blend, including inside an owner-provided
ZIP, and refuses a wrong source, a stale/dirty output directory or a failed
Blender/readback/visual check. It never modifies production sprites.

Windows example:
  py art/source-to-3d/condenser-v21/run_condenser_v22_review.py ^
    --source "D:\\AI-Relocation\\condenser-V21-approved-source-V22-animation-starter.zip" ^
    --blender "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" ^
    --out "D:\\AI-Relocation\\condenser-V22-review-01"

Linux example:
  python3 art/source-to-3d/condenser-v21/run_condenser_v22_review.py \\
    --source /mnt/assets/tech_priests_water_condenser_v21.blend \\
    --blender blender --out /tmp/condenser-V22-review-01

With --search-root, search is limited to one explicitly named root and a
bounded directory depth. No network, private credentials, or new workflow.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
APPROVED_SHA = '1ccd8093e5b153d80b7ac66cb77b364f05e7ee46a5f236efe189498b71dd052b'
APPROVED_NAME = 'tech_priests_water_condenser_v21.blend'
MAX_SOURCE_SIZE = 250 * 1024 * 1024
MAX_DEPTH = 6
MAX_VISITED = 50000


class SourceBlocked(RuntimeError):
    pass


def sha_stream(stream) -> str:
    digest = hashlib.sha256()
    while block := stream.read(1024 * 1024):
        digest.update(block)
    return digest.hexdigest()


def file_hash(path: Path) -> str:
    with path.open('rb') as source:
        return sha_stream(source)


def approved_zip_member(archive: Path) -> str:
    """Inspect approved source streams in-place; never extract unknown content."""
    with zipfile.ZipFile(archive) as zf:
        members = sorted((m for m in zf.infolist()
                          if not m.is_dir() and Path(m.filename).name.lower() == APPROVED_NAME.lower()),
                         key=lambda m: m.filename)
        for member in members:
            if not (1 <= member.file_size <= MAX_SOURCE_SIZE):
                continue
            if member.compress_size > MAX_SOURCE_SIZE:
                continue
            with zf.open(member, 'r') as content:
                if sha_stream(content) == APPROVED_SHA:
                    return member.filename
    raise SourceBlocked('No SHA-matching approved V21 Blender source found inside ' + str(archive))


def resolve_source(path: Path, out: Path) -> Path:
    """Hash-gated direct source or ZIP; extraction occurs AFTER exact hash proof."""
    path = path.expanduser().resolve()
    if not path.is_file():
        raise SourceBlocked('Condenser source path not found: ' + str(path))
    if path.suffix.lower() == '.blend':
        if path.stat().st_size > MAX_SOURCE_SIZE or file_hash(path) != APPROVED_SHA:
            raise SourceBlocked('V21 Blender source SHA-256 mismatch: ' + str(path))
        return path
    if path.suffix.lower() != '.zip':
        raise SourceBlocked('Expected the approved .blend or containing ZIP: ' + str(path))
    member = approved_zip_member(path)
    dest = out / APPROVED_NAME
    # The caller has already ensured the output does not contain previous work.
    out.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path) as zf, zf.open(member, 'r') as src, dest.open('xb') as target:
        shutil.copyfileobj(src, target, length=1024 * 1024)
    if file_hash(dest) != APPROVED_SHA:
        dest.unlink(missing_ok=True)
        raise SourceBlocked('Extracted ZIP entry unexpectedly failed accepted-source SHA')
    return dest


def candidates(root: Path):
    """Walk a SPECIFIED source directory, not the host filesystem in general."""
    root = root.expanduser().resolve()
    if not root.is_dir():
        raise SourceBlocked('Source search root does not exist: ' + str(root))
    visited = 0
    for directory, subdirs, files in os.walk(root, followlinks=False):
        level = len(Path(directory).relative_to(root).parts)
        subdirs.sort()
        if level >= MAX_DEPTH:
            subdirs.clear()
        for name in sorted(files):
            visited += 1
            if visited > MAX_VISITED:
                raise SourceBlocked('Source search exceeded bounded file count')
            lower = name.lower()
            if lower == APPROVED_NAME or (lower.endswith('.zip') and 'condenser' in lower and 'v21' in lower):
                yield Path(directory) / name


def find_approved(root: Path) -> Path:
    errors = []
    for candidate in candidates(root):
        try:
            if candidate.suffix.lower() == '.blend':
                if candidate.stat().st_size <= MAX_SOURCE_SIZE and file_hash(candidate) == APPROVED_SHA:
                    return candidate
            else:
                approved_zip_member(candidate)
                return candidate
        except (OSError, zipfile.BadZipFile, SourceBlocked) as error:
            errors.append(f'{candidate.name}: {error}')
    raise SourceBlocked('No exact SHA-verified V21 model found under %s (scanned candidate archives; first failures: %s)' %
                        (root, '; '.join(errors[:3])))


def blender_binary(value: str | None) -> str:
    if value:
        location = shutil.which(value)
        if location:
            return location
        if Path(value).expanduser().is_file():
            return str(Path(value).expanduser().resolve())
        raise RuntimeError('Blender executable missing: ' + value)
    auto = shutil.which('blender')
    if auto:
        return auto
    if os.name == 'nt':
        location = Path('C:/Program Files/Blender Foundation/Blender 5.2/blender.exe')
        if location.is_file():
            return str(location)
    raise RuntimeError('No local Blender binary found; pass --blender explicitly')


def invoke(command: list[str], cwd: Path, log: Path) -> None:
    """Stream the true Blender result and preserve the complete log."""
    with log.open('x', encoding='utf8') as output:
        print('RUN', ' '.join(map(str, command)), flush=True)
        process = subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True, errors='replace')
        assert process.stdout is not None
        for line in process.stdout:
            print(line, end='', flush=True)
            output.write(line)
            output.flush()
        status = process.wait()
    if status:
        raise RuntimeError('Blender failed with exit %d. Review log: %s' % (status, log))


def review(source: Path, out: Path, blender: str) -> dict:
    """Run complete real Blender build, independent reopen and pixel inspection."""
    if not (REPO / 'tools/fmpl/blender_camera_guard.py').is_file():
        raise RuntimeError('A real Tech-Priests checkout containing FMPL is required')
    if out.exists() and any(out.iterdir()):
        raise RuntimeError('Refusing to overwrite existing V22 candidate/preview: ' + str(out))
    if importlib.util.find_spec('PIL') is None:
        raise RuntimeError('Pillow required for native pixel QA; use python -m pip install Pillow')
    source_path = resolve_source(source, out)
    if file_hash(source_path) != APPROVED_SHA:
        raise RuntimeError('Source changed during preflight')
    out.mkdir(parents=True, exist_ok=True)
    invoke([blender, '--version'], REPO, out / '00_blender_version.log')
    subprocess.run([sys.executable, '-m', 'unittest', 'discover', '-s', str(HERE),
                    '-p', 'test_condenser_v22_*.py'], cwd=REPO, check=True)
    invoke([blender, '-b', '--factory-startup', '--threads', '4',
            '--python-exit-code', '12', '--python', str(HERE / 'animate_condenser_v22.py'),
            '--', '--source-blend', str(source_path), '--out', str(out)],
           REPO, out / '01_native_blender.log')
    blend = out / 'condenser_v22_motion_review.blend'
    if not blend.is_file() or blend.stat().st_size < 10000:
        raise RuntimeError('Blender did not create a genuine editable V22 derivative')
    invoke([blender, '-b', str(blend), '--threads', '4',
            '--python-exit-code', '13', '--python', str(HERE / 'verify_condenser_v22.py'),
            '--', '--out', str(out)], REPO, out / '02_native_readback.log')
    invoke([sys.executable, str(HERE / 'condenser_v22_visual_qa.py'), '--out', str(out)],
           REPO, out / '03_pixel_qa.log')
    proofs = [out / name for name in (
        'Condenser_V22_Real_Blender_4_Directions_Proof.png',
        'Condenser_V22_Real_Blender_Effect_Isolation.png',
        'Condenser_V22_Real_Blender_Sequential_Intake.gif',
    )]
    if any(not file.is_file() or file.stat().st_size <= 1000 for file in proofs):
        raise RuntimeError('Missing genuine Cycles proof; do not claim animation review success')
    pixel_qa = json.loads((out / 'condenser_v22_visual_qa.json').read_text())
    if pixel_qa.get('independent_effect_visibility_gates') != 'PASS':
        raise RuntimeError('Native vapor/piston isolation pixel quality not verified')
    receipt = {
        'result': 'NATIVE_REVIEW_RENDERED_NOT_OWNER_APPROVED',
        'source_sha256': APPROVED_SHA,
        'output_blend': blend.name,
        'real_native_proofs': [file.name for file in proofs],
        'files': {file.name: file_hash(file) for file in [blend, *proofs]},
        'native_validation': json.loads((out / 'condenser_v22_native_readback.json').read_text()),
        'visual_effect_isolation': pixel_qa['independent_effect_visibility_gates'],
        'human_approval': False,
        'factorio_mod_modified': False,
        'next_step': 'Show true Cycles GIF/contact sheet/A-B effect isolation in chat before Factorio sprite packing',
    }
    receipt_path = out / 'V22_REVIEW_RECEIPT.json'
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
    # One portable native proof archive for inspection/handoff: bundle files
    # that were ACTUALLY rendered, not a speculative preview or output link.
    bundle = out / 'Condenser_V22_Native_Review_Bundle.zip'
    source_files = [blend, *proofs, receipt_path,
                    out / 'condenser_v22_native_readback.json',
                    out / 'condenser_v22_visual_qa.json',
                    out / 'condenser_v22_motion_manifest.json',
                    *sorted(out.glob('frame_*.png')),
                    *sorted(out.glob('direction_*.png')),
                    *sorted(out.glob('game_scale_*.png'))]
    with zipfile.ZipFile(bundle, mode='x', compression=zipfile.ZIP_DEFLATED,
                         compresslevel=6, allowZip64=True) as zf:
        for file in source_files:
            if not file.is_file() or file.stat().st_size < 1:
                raise RuntimeError('Refusing review bundle without source file: ' + str(file))
            zf.write(file, arcname=file.name)
    with zipfile.ZipFile(bundle) as zf:
        bad_member = zf.testzip()
        if bad_member is not None or len(zf.namelist()) != len(source_files):
            raise RuntimeError('Native review archive integrity failed: ' + str(bad_member))
    (out / 'Condenser_V22_Native_Review_Bundle.sha256').write_text(
        f'{file_hash(bundle)}  {bundle.name}\n')
    print('CONDENSER_V22_REAL_BLENDER_REVIEW_PASS', out,
          'bundle_sha256', file_hash(bundle), flush=True)
    return receipt


def parse():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--source', type=Path, help='Exact approved V21 .blend or starter ZIP')
    group.add_argument('--search-root', type=Path, help='Bounded search root containing approved .blend or ZIP')
    parser.add_argument('--out', type=Path, required=True, help='NEW empty output directory (never overwritten)')
    parser.add_argument('--blender', help='Blender 5.2 executable; defaults to PATH or known Windows install')
    return parser.parse_args()


def main():
    args = parse()
    src = args.source if args.source else find_approved(args.search_root)
    binary = blender_binary(args.blender)
    review(src.resolve(), args.out.expanduser().resolve(), binary)


if __name__ == '__main__':
    main()
