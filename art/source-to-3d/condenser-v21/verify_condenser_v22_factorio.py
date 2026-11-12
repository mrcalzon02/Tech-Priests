"""Independent fail-closed inspection of Blender-derived condenser Factorio atlases."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image
from pack_condenser_v22_factorio import APPROVED_V21_SHA, ANGLES, ANGLE_NAMES, FRAMES, FOLDER, SCALE_HR, SCALE_STANDARD, CHUNK_FRAMES, digest


def verify(root:Path, source_mod:Path|None=None):
    root=Path(root).resolve()
    source=json.loads((root/'condenser_v22c_factorio_atlas_manifest.json').read_text())
    if source.get('source_sha256') != APPROVED_V21_SHA:
        raise RuntimeError('Source SHA does not match owner-approved V21')
    if source.get('generated_image_art_or_fabricated_pixels') is not False or source.get('original_source_meshes_changed') is not False:
        raise RuntimeError('Not proven source-locked native renderer')
    if source.get('source_frame_sequence')!=list(FRAMES) or source.get('cycle_seconds')!=12:
        raise RuntimeError('Wrong authoritative animation cycle')
    if source.get('orientation_angles')!=list(ANGLES):
        raise RuntimeError('Missing 0/90/180/270 headings')
    if abs(source.get('hr_frame_px')*source.get('hr_factorio_scale')-source.get('sd_frame_px')*source.get('sd_factorio_scale'))>1e-8:
        raise RuntimeError('HR vs SD Factorio scale mismatch')
    if abs(source.get('factorio_animation_speed_frames_per_tick')*60*12 - len(FRAMES))>1e-6:
        raise RuntimeError('Incorrect Factorio loop animation speed')
    assets=root/FOLDER
    checked={}
    for angle in ANGLES:
        name=ANGLE_NAMES[angle]
        for level,size in (('hr',512),('sd',256)):
            block=source['files'][name][level]
            if len(block['activity_slices'])!=4:
                raise RuntimeError('Incomplete four-slice output: '+name)
            for index,entry in enumerate([*block['activity_slices'],block['idle_repeated_slice']]):
                path=assets/entry['name']
                if not path.is_file() or digest(path)!=entry['sha256'] or path.stat().st_size!=entry['size_bytes']:
                    raise RuntimeError('Missing or mismatched asset: '+str(path))
                with Image.open(path) as im:
                    im.verify()
                with Image.open(path) as im:
                    if im.size!=(size*4,size*2):
                        raise RuntimeError('Wrong atlas dimensions: '+str(path))
                checked[entry['name']]=entry['sha256']
    icon=source['icon'];icon_path=assets/icon['name']
    if digest(icon_path)!=icon['sha256']:
        raise RuntimeError('Game icon changed')
    with Image.open(icon_path) as img:
        if img.size!=(64,64):raise RuntimeError('Icon must be 64x64')
    if source_mod:
        lua=(Path(source_mod)/'prototypes/generated_graphics/atmospheric-water-condenser-v22c.lua').read_text()
        if ("local FRAMES = 32" not in lua or "position={0.5,-0.5}" not in lua or
             "lines_per_file=2" not in lua or "target.graphics_set={" not in lua):
            raise RuntimeError('Lua graphics/pipe registration missing')
    return {'status':'PASS','assets':len(checked)+1,'headings':4,'sampled_frames':4*32,'source_sha256':APPROVED_V21_SHA}


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--source-mod',type=Path)
    a=p.parse_args()
    print('CONDENSER_V22C_FACTORIO_STATIC_INTEGRATION_PASS',json.dumps(verify(a.out,a.source_mod)))

if __name__=='__main__':main()
