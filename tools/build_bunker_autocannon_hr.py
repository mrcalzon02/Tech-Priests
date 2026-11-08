#!/usr/bin/env python3
"""Build resumable HR atlas checkpoints directly from approved captures."""
import argparse, hashlib, io, json, math, zipfile
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'art/production/bunker-autocannon-hr'
SOURCE = ROOT.parent / 'recovered-sources'
P = argparse.ArgumentParser()
P.add_argument('--sheet', type=int, choices=range(16))
A = P.parse_args()
OUT.mkdir(parents=True, exist_ok=True)
REG = json.loads((ROOT/'docs/prototypes/bunker-autocannon-registration.json').read_text())
CELL = 400

def hr(image, ortho, cell):
    # Sample at exactly 64 px/world-unit, padding symmetrically around the
    # recorded camera center. Never recenter individual poses or headings.
    source = image.convert('RGBA')
    ratio = source.width / (ortho * 64)
    offset = source.width / 2 - cell / 2 * ratio
    return source.transform((cell, cell), Image.Transform.AFFINE,
        (ratio, 0, offset, 0, ratio, offset), Image.Resampling.BICUBIC)

def heading(z, d):
    src = Image.open(io.BytesIO(z.read(f'Original_Bunker_Turret/firing_d{d:02}.png'))).convert('RGBA')
    assert src.size == (5120, 2560)
    return [hr(src.crop(((f%8)*640, (f//8)*640, (f%8+1)*640, (f//8+1)*640)),
        REG['orthographic_scale'], CELL) for f in range(32)]

if A.sheet is not None:
    with zipfile.ZipFile(SOURCE/'Original_Bunker_Turret_Full_Rotation_And_Firing.zip') as z:
        atlas = Image.new('RGBA', (CELL*8, CELL*16))
        for local in range(4):
            frames = heading(z, A.sheet*4+local)
            for f, im in enumerate(frames):
                assert im.getchannel('A').getbbox(), (local, f)
                box = im.getchannel('A').getbbox()
                assert box[0]>0 and box[1]>0 and box[2]<CELL and box[3]<CELL, (local,f,box)
                n = local*32+f
                atlas.paste(im, ((n%8)*CELL, (n//8)*CELL))
        path = OUT/f'firing-{A.sheet:02}.png'
        atlas.save(path)
        with Image.open(path) as check:
            check.load()
            assert check.size == (3200,6400)
        record = {'file':path.name, 'directions':list(range(A.sheet*4,A.sheet*4+4)),
            'frames_per_direction':32, 'columns':8, 'rows':16, 'cell':CELL,
            'pixels_per_tile':64, 'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'git_blob_sha':hashlib.sha1(b'blob '+str(path.stat().st_size).encode()+b'\0'+path.read_bytes()).hexdigest(),
            'bytes':path.stat().st_size, 'verified_frames':128}
        (OUT/f'firing-{A.sheet:02}.json').write_text(json.dumps(record,indent=2)+'\n')
        print(json.dumps(record))
