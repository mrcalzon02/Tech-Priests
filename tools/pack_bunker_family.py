"""Build runtime sprites from preserved captures; retain every A02 time sample.

Source archives remain unchanged. Runtime cells are explicitly 256px beauty /
emission and 512px shadow, matching the existing cannon's world pixel density.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import zipfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--lobber', type=Path, required=True)
    p.add_argument('--dish', type=Path, required=True)
    a = p.parse_args()
    manifest = json.loads((a.lobber/'capture_manifest.json').read_text())
    assert manifest['direction_count'] == 64
    assert manifest['cycle_frames_per_heading'] == 192
    archives = [zipfile.ZipFile(f) for f in sorted(a.lobber.glob('Lobber_*.zip'))
                if any(k in f.name for k in ('beauty', 'emission', 'shadow'))]
    index = {n: z for z in archives for n in z.namelist()}
    outputs = []

    def read(name):
        with index[name].open(name) as stream:
            im = Image.open(stream).convert('RGBA')
        return im

    out = ROOT/'tech-priests_src/graphics/entity/bunker-lobber'
    out.mkdir(parents=True, exist_ok=True)
    for d in manifest['directions']:
        direction = d['direction']
        for pas, rec in d['passes'].items():
            srcsize = rec['cell_size'][0]
            size = 512 if pas == 'shadow' else 256
            for mode, count in [('cycle', 192), ('entry', 15), ('settle', 15), ('idle', 1)]:
                target = out/f'{pas}-{mode}-{direction:02}.png'
                cols = 16 if mode == 'cycle' else count
                rows = (count+cols-1)//cols
                expected = (cols*size, rows*size)
                # Each output is self-contained and safely resumable.
                if target.exists():
                    with Image.open(target) as prior:
                        prior.load()
                        if prior.size != expected:
                            # Re-layout an earlier 8-column runtime atlas to
                            # fit Factorio's 8192px spritesheet limit. No
                            # resampling or frame deletion in this repair.
                            assert mode == 'cycle' and prior.size == (8*size,24*size)
                            repaired=Image.new('RGBA',expected)
                            for f in range(count):
                                cell=prior.crop((f%8*size,f//8*size,(f%8+1)*size,(f//8+1)*size))
                                repaired.paste(cell,(f%16*size,f//16*size))
                            repaired.save(target)
                    continue
                sheet = Image.new('RGBA', expected)
                names = rec['cycle'] if mode == 'cycle' else [rec.get(mode, rec['idle_sheet'])]
                sources = [read(n) for n in names]
                for frame in range(count):
                    if mode == 'idle':
                        col, row = rec['idle_cell']; source = sources[0]
                    else:
                        page, local = divmod(frame, rec['sheet_capacity'])
                        col, row = local % rec['columns'], local // rec['columns']
                        source = sources[page]
                    cell = source.crop((col*srcsize, row*srcsize, (col+1)*srcsize, (row+1)*srcsize))
                    cell = cell.resize((size, size), Image.Resampling.LANCZOS)
                    sheet.paste(cell, ((frame % cols)*size, (frame//cols)*size))
                sheet.save(target)
                for im in sources: im.close()
        print('LOBber_PACKED', direction, flush=True)
    for z in archives: z.close()
    dish = ROOT/'tech-priests_src/graphics/entity/bunker-energy-dish'
    dish.mkdir(parents=True, exist_ok=True)
    with Image.open(a.dish/'idle64-256.png') as im:
        assert im.size == (2048, 2048)
        for direction in range(64):
            x, y = direction % 8*256, direction//8*256
            im.crop((x, y, x+256, y+256)).save(dish/f'idle-{direction:02}.png')
    for folder in (out, dish):
        for f in sorted(folder.glob('*.png')):
            with Image.open(f) as im:
                outputs.append({'path': str(f.relative_to(ROOT)), 'size': list(im.size),
                                'sha256': hashlib.sha256(f.read_bytes()).hexdigest()})
    record = {'status': 'RUNTIME_SPRITES_PACKED', 'directions': 64,
              'lobber_frames': {'cycle': 192, 'entry': 15, 'settle': 15, 'idle': 1},
              'source_identity': manifest['source_identity'], 'fps': 24,
              'explicit_runtime_resampling': {'beauty': [640, 256], 'emission': [640, 256], 'shadow': [1280, 512]},
              'geometry_or_camera_changes': False, 'files': outputs}
    (ROOT/'docs/prototypes/bunker-family-assets.json').write_text(json.dumps(record, indent=2)+'\n')


if __name__ == '__main__': main()
