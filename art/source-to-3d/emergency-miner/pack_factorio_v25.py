#!/usr/bin/env python3
"""Pack only verified, user-approved V25 Blender frames into Factorio 2.1 art.

No synthesized 2D machine art. The fixed FMPL camera and 64 rendered frames are
the source. Original sprites remain available in martian-micro as rollback.
"""
from __future__ import annotations
import argparse,hashlib,io,json
from pathlib import Path
import zipfile
from PIL import Image

FRAME_IDS=tuple(1+6*i for i in range(16))
DIRECTIONS=('d00','d01','d02','d03')
DIRMAP={'north':'d00','east':'d03','south':'d02','west':'d01'}
ART=Path('graphics/entity/emergency-miner-v25')

def checksum(blob):
    return hashlib.sha256(blob).hexdigest()

def build(source,mod,manifest,from_zip=False):
    archive=zipfile.ZipFile(source) if from_zip else None
    prefix='emergency-miner-motion-v21/review/four_orientations/A/'
    def get(path):
        return archive.read(prefix+path) if archive else (source/path).read_bytes()
    audit=json.loads(get('four_view_verified_A.json'))
    receipt=json.loads(get('four_orientation_preview_A.json'))
    if (audit.get('verification')!='PASS'
        or audit.get('frames_total')!=64
        or audit.get('same_camera_four_model_rotations') is not True
        or receipt.get('revision')!='V25'
        or receipt.get('source_variant')!='A'
        or receipt.get('model_yaw_degrees')!=[0,90,180,270]
        or receipt.get('production_sprite_exported') is not False):
        raise RuntimeError('Refuse non-V25/non-verified Blender source')
    native=[]
    source_hashes={}
    for dr in DIRECTIONS:
        for fr in FRAME_IDS:
            name=f'{dr}/frame_{fr:03d}.png'
            content=get(name)
            original_hash=checksum(content)
            if receipt['sequences'][dr]['all_frames_sha256'][f'frame_{fr:03d}.png']!=original_hash:
                raise RuntimeError('Native Blender frame checksum mismatch: '+name)
            frame=Image.open(io.BytesIO(content)).convert('RGBA')
            if frame.size!=(256,256) or not frame.getchannel('A').getbbox():
                raise RuntimeError('Invalid native Blender frame: '+name)
            native.append(frame)
            source_hashes[name]=original_hash
    # Sprite atlas layout: four source rotations as rows; 16 frames in each row.
    working=Image.new('RGBA',(4096,1024))
    idle=Image.new('RGBA',(4096,1024))
    for idx,dr in enumerate(DIRECTIONS):
        for fr in range(16):
            working.paste(native[idx*16+fr],(fr*256,idx*256))
            idle.paste(native[idx*16],(fr*256,idx*256))
    dest=mod/ART
    dest.mkdir(parents=True,exist_ok=True)
    files={}
    def export(name,image):
        path=dest/name
        image.save(path,format='PNG',optimize=True,compress_level=9)
        files[name]={'sha256':checksum(path.read_bytes()),
                     'bytes':path.stat().st_size,'dimensions':list(image.size)}
    export('activity-hr.png',working)
    export('idle-hr.png',idle)
    export('activity.png',working.resize((2048,512),Image.Resampling.LANCZOS))
    export('idle.png',idle.resize((2048,512),Image.Resampling.LANCZOS))
    icon=native[0]
    bbox=icon.getchannel('A').point(lambda a:255 if a>=32 else 0).getbbox()
    box=(max(0,bbox[0]-16),max(0,bbox[1]-16),
         min(256,bbox[2]+16),min(256,bbox[3]+16))
    for size in (64,128):
        part=icon.crop(box)
        part.thumbnail((size-4,size-4),Image.Resampling.LANCZOS)
        output=Image.new('RGBA',(size,size))
        output.paste(part,((size-part.width)//2,(size-part.height)//2))
        export(f'icon-{size}.png',output)
    statement={
      'asset':'tech-priests-emergency-miner','approved_revision':'V25',
      'approved_variant':'A','factorio_version':'2.1',
      'camera':'one fixed FMPL orthographic 45 degree camera',
      'source_yaw':[0,90,180,270],
      'factorio_direction_to_source':DIRMAP,
      'native_captured_frames':list(FRAME_IDS),
      'directional_frame_count':16,'source_rate_fps':8,'factorio_animation_speed':8/60,
      'standard_sprite_size':[128,128],'high_resolution_sprite_size':[256,256],
      'standard_scale':0.476,'high_resolution_scale':0.238,
      'sprite_shift_tiles':[0,-.05],
      'source_frame_sha256':source_hashes,
      'emitted':files,'source_original_art_overwritten':False,
      'image_generation_used':False
    }
    manifest.mkdir(parents=True,exist_ok=True)
    (manifest/'emergency-miner-v25-atlas-manifest.json').write_text(
        json.dumps(statement,indent=2)+'\n',encoding='utf8')
    if archive: archive.close()
    print('EMERGENCY_MINER_V25_ATLAS_PASS '+json.dumps({
        'frames':64,'files':files,'mapping':DIRMAP},sort_keys=True))
    return statement

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--source',type=Path,required=True)
    p.add_argument('--mod',type=Path,required=True)
    p.add_argument('--manifest',type=Path,required=True)
    p.add_argument('--zip',action='store_true')
    a=p.parse_args()
    build(a.source,a.mod,a.manifest,a.zip)

if __name__=='__main__':
    main()
