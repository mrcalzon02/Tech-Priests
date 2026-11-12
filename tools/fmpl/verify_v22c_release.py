"""Release-blocking, dependency-free condenser V22C graphics validator.

The Blender asset source is immutable. This checks the actual PNGs, manifest,
prototype hookup and all three graphics quality modes without requiring PIL.
It is not a graphical Factorio test; native engine startup remains separate.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import struct
import zipfile
from pathlib import Path

SPRITES = 'graphics/entity/atmospheric-water-condenser-v22c'
APPROVED_SOURCE = '1ccd8093e5b153d80b7ac66cb77b364f05e7ee46a5f236efe189498b71dd052b'
EXPECTED_FACES = {'north': 'north', 'east': 'west_native', 'south': 'south', 'west': 'east_native'}
MOD_SETTING = 'tech-priests-condenser-sprite-quality'
PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'


def fail_if(condition: bool, reason: str):
    if condition:
        raise ValueError(reason)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def png_size(data: bytes) -> tuple[int, int]:
    fail_if(len(data) < 33 or data[:8] != PNG_SIGNATURE, 'Invalid PNG signature/truncated header')
    fail_if(data[12:16] != b'IHDR' or struct.unpack('>I', data[8:12])[0] != 13,
            'Missing standard PNG IHDR')
    width, height, depth, color_type, compression, filtering, interlace = struct.unpack('>IIBBBBB', data[16:29])
    fail_if(width == 0 or height == 0 or depth != 8 or color_type != 6 or compression != 0 or filtering != 0,
            'Invalid RGBA PNG dimensions/encoding')
    fail_if(interlace not in (0, 1), 'Invalid PNG interlace mode')
    fail_if(width > 8192 or height > 8192, 'Texture exceeds Factorio maximum 8192px atlas input')
    return width, height


def file_record(directory: Path, record: dict, dims: tuple[int,int]):
    filename = record['name']
    fail_if(Path(filename).name != filename or filename.count('/') or filename.count('\\'),
            f'Unsafe or incorrect asset filename: {filename}')
    file = directory / filename
    fail_if(not file.is_file(), f'Missing release-blocking atlas: {filename}')
    buf = file.read_bytes()
    fail_if(len(buf) != record['size_bytes'] or sha256(buf) != record['sha256'],
            f'Byte length or source SHA-256 changed: {filename}')
    fail_if(png_size(buf) != dims or (record['width'], record['height']) != dims,
            f'Wrong atlas geometry: {filename}')
    return filename


def quality_contract(lua: str, settings: str, fixes: str, locale: str):
    fail_if(MOD_SETTING not in lua or MOD_SETTING not in settings,
            'Condenser startup quality selector not wired')
    for token in ('"auto", "high", "standard"', 'default_value = "auto"', 'setting_type = "startup"'):
        fail_if(token not in settings, 'Quality setting definition invalid: ' + token)
    for token in ("resolution = quality == 'standard' and 'sd' or 'hr'",
                  "frame_size = resolution == 'sd' and 256 or 512",
                  "world_scale = resolution == 'sd' and 0.4 or 0.2",
                  "allow_forced_downscale=(quality == 'auto')",
                  "frame_path(which,original,resolution,i)",
                  "local FRAMES = 32", "lines_per_file=2", "slice=SLICE_SIZE",
                  "animation_speed=FRAMES / TICKS_PER_CYCLE", "target.graphics_set={",
                  "port.position={0.5,-0.5}"):
        fail_if(token not in lua, 'Condenser graphics contract missing: ' + token)
    fail_if(fixes.count('require("prototypes.generated_graphics.atmospheric-water-condenser-v22c")') != 1,
            'Condenser graphics module not loaded exactly once by final fixes')
    fail_if(f'{MOD_SETTING}=Atmospheric condenser sprite quality' not in locale,
            'Condenser setting locale missing')
    for mode in ('auto', 'high', 'standard'):
        fail_if(f'{MOD_SETTING}-{mode}=' not in locale,
                f'Missing localized graphics mode: {mode}')
    # These compare output pixels, not decoded texture VRAM actually allocated.
    scale = {'auto': (512,.2), 'high': (512,.2), 'standard': (256,.4)}
    assert all(abs(w*s - 102.4) < 1e-8 for w,s in scale.values())
    return scale


def validate(mod_dir: Path, *, verify_code: bool=True) -> dict:
    mod_dir = Path(mod_dir)
    images = mod_dir / SPRITES
    manifest_path = images / 'atlas_manifest.json'
    fail_if(not manifest_path.is_file(), 'Source-locked condenser atlas manifest absent')
    m = json.loads(manifest_path.read_text('utf-8'))
    fail_if(m.get('schema') != 'tech-priests.condenser-v22c-factorio-atlases.v1', 'Wrong atlas schema')
    fail_if(m.get('source_sha256') != APPROVED_SOURCE or m.get('original_source_meshes_changed') is not False,
            'Approved Blender V21 source provenance changed')
    fail_if(m.get('generated_image_art_or_fabricated_pixels') is not False,
            'Atlas no longer certifies real Blender-rendered input')
    fail_if(m.get('source_frame_sequence') != list(range(1,97,3)) or m.get('actual_factorio_animation_frames') != 32,
            'Missing, duplicate, or shuffled native animation samples')
    fail_if(m.get('cycle_seconds') != 12 or not math.isclose(m.get('factorio_animation_speed_frames_per_tick'),32/720),
            'Animation speed no longer equals the approved 12-second cycle')
    fail_if(m.get('blender_to_factorio') != EXPECTED_FACES, 'One or more directional mappings changed')
    fail_if(m.get('nominal_collision_footprint_tiles') != [2,2] or m.get('factorio_output_connection_local') != [.5,-.5]
            or m.get('factorio_output_direction') != 'east', '2x2 water port alignment changed')
    fail_if(m.get('orientation_angles') != [0,90,180,270], 'Missing canonical Factorio directions')
    fail_if((m.get('hr_frame_px'),m.get('sd_frame_px')) != (512,256) or
            not math.isclose(m.get('hr_frame_px')*m.get('hr_factorio_scale'),
                             m.get('sd_frame_px')*m.get('sd_factorio_scale')),
            'HR vs standard graphics world-scale drift')
    fail_if((m.get('chunk_frame_count'),m.get('line_length'),m.get('lines_per_file')) != (8,4,2),
            'Wrong 8-frame sliced 4x2 atlas format')
    seen=set()
    for face in ('north', 'east_native', 'south', 'west_native'):
        for quality,size in (('hr',512),('sd',256)):
            record=m['files'][face][quality]
            fail_if(len(record['activity_slices']) != 4, f'Missing active sheet: {face}/{quality}')
            for idx,r in enumerate(record['activity_slices']):
                expected=f'active-{face}-{quality}-{idx:02d}.png'
                fail_if(r['name'] != expected, f'Out-of-order source frame slice: {expected}')
                seen.add(file_record(images,r,(size*4,size*2)))
            idle=record['idle_repeated_slice']
            fail_if(idle['name'] != f'idle-{face}-{quality}.png', f'Wrong idle slice: {face}/{quality}')
            seen.add(file_record(images,idle,(size*4,size*2)))
    icon=m['icon']
    fail_if(icon['name'] != 'icon-64.png', 'Condenser game icon changed')
    seen.add(file_record(images,icon,(64,64)))
    actual={f.name for f in images.glob('*.png')}
    fail_if(len(seen) != 41 or actual != seen, f'Expected exactly 41 graphics, got {len(seen)} manifest / {len(actual)} disk')
    if verify_code:
        lua=(mod_dir/'prototypes/generated_graphics/atmospheric-water-condenser-v22c.lua').read_text('utf-8')
        settings=(mod_dir/'settings.lua').read_text('utf-8')
        fixes=(mod_dir/'data-final-fixes.lua').read_text('utf-8')
        locale=(mod_dir/'locale/en/base.cfg').read_text('utf-8')
        quality_contract(lua,settings,fixes,locale)
    # Raw uncompressed RGBA pixel estimate only; no promise about actual GPU VRAM.
    frames_per_direction = 32 + 8  # one idle slice (8 unique pixels), 32 active
    mib=1024**2
    estimate={quality:round(4*frames_per_direction*side*side*4/mib,2)
              for quality,side in (('high',512),('standard',256))}
    return {'status':'PASS', 'source_sha256':APPROVED_SOURCE, 'png_assets':len(seen),
            'real_captured_frames':128, 'output_ports':1, 'directions':4,
            'cycle_seconds':12, 'quality_modes':['auto','high','standard'],
            'max_sprite_sheet_px':[2048,1024],
            'estimated_uncompressed_active_plus_idle_MiB':estimate,
            'estimated_standard_texture_reduction_percent':75}


def verify_archive(path: Path, mod_name: str, mod_version: str):
    name=f'{mod_name}_{mod_version}'
    with zipfile.ZipFile(path) as z:
        problems=z.testzip()
        fail_if(problems is not None, 'Corrupt published archive member: '+str(problems))
        files=set(z.namelist())
        fail_if(f'{name}/info.json' not in files, 'Archive has no expected mod root/info.json')
        fail_if(f'{name}/{SPRITES}/atlas_manifest.json' not in files,
                'Packaged Factorio mod is missing source-locked atlas manifest')
        manifest=json.loads(z.read(f'{name}/{SPRITES}/atlas_manifest.json'))
        for quality_files in manifest['files'].values():
            for pack in quality_files.values():
                for meta in [*pack['activity_slices'],pack['idle_repeated_slice']]:
                    full=f'{name}/{SPRITES}/{meta["name"]}'
                    fail_if(full not in files or sha256(z.read(full))!=meta['sha256'],
                            'Packaged asset missing or corrupted: '+full)
        icon=manifest['icon'];path_icon=f'{name}/{SPRITES}/{icon["name"]}'
        fail_if(path_icon not in files or sha256(z.read(path_icon))!=icon['sha256'],
                'Packaged icon missing or corrupted')
    return True


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--mod-dir',type=Path,required=True)
    p.add_argument('--release',type=Path)
    args=p.parse_args()
    result=validate(args.mod_dir)
    if args.release:
        info=json.loads((args.mod_dir/'info.json').read_text())
        verify_archive(args.release,info['name'],info['version'])
        result['release_archive_verified']=True
    print('CONDENSER_V22C_RELEASE_INTEGRATION_PASS',json.dumps(result,sort_keys=True))

if __name__=='__main__':main()
