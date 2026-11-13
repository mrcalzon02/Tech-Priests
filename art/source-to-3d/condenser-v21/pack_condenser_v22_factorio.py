"""Pack authentic four-way Cycles condenser V22C frames into Factorio 2.1 atlases.

32 frames sampled from the approved 96 frame / 12s Blender scene for each of
4 directions. Pack eight sequential frames per source file (4x2); keep <8192
pixel sheet dimensions. 512px HR and losslessly downsampled 256px standard
versions have equal world footprint. No generated machine image or AI painting.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ANGLES = (0, 90, 180, 270)
ANGLE_NAMES = {0:'north',90:'east_native',180:'south',270:'west_native'}
FRAMES = tuple(range(1,97,3))
CHUNK_FRAMES=8
COLS=4
ROWS=2
FULL_SIZE=512
STANDARD_SIZE=256
FPS=8/3
CYCLE_SECONDS=12.0
SCALE_HR=.2
SCALE_STANDARD=.4
FOLDER='graphics/entity/atmospheric-water-condenser-v22c'
APPROVED_V21_SHA='1ccd8093e5b153d80b7ac66cb77b364f05e7ee46a5f236efe189498b71dd052b'


def digest(path):
    hash=hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''):
            hash.update(chunk)
    return hash.hexdigest()


def atlas(frames, size=FULL_SIZE):
    if len(frames)!=CHUNK_FRAMES or size not in (FULL_SIZE,STANDARD_SIZE):
        raise ValueError('Atlas expects exactly 8 512/256px frames')
    image=Image.new('RGBA',(COLS*size,ROWS*size),(0,0,0,0))
    for index,frame in enumerate(frames):
        if frame.size!=(FULL_SIZE,FULL_SIZE):
            raise ValueError('Frame must be an original 512px Cycles image')
        scaled=frame if size==FULL_SIZE else frame.resize((size,size),Image.Resampling.LANCZOS)
        image.paste(scaled,(index%COLS*size,index//COLS*size))
    return image


def open_real_frame(root, record):
    path=root/record['path']
    if not path.is_file() or digest(path)!=record['sha256']:
        raise RuntimeError('Missing or corrupted genuine Blender frame '+str(path))
    with Image.open(path) as frame:
        frame.load()
        if frame.size!=(512,512) or frame.mode not in ('RGBA','RGB'):
            raise RuntimeError('Wrong Cycles frame format '+str(path))
        if frame.mode=='RGBA' and frame.getchannel('A').getbbox() is None:
            raise RuntimeError('No machine pixels in native frame '+str(path))
        return frame.convert('RGBA')


def image_write(image,path):
    if path.exists():
        raise RuntimeError('Refusing to overwrite prior atlas: '+str(path))
    image.save(path,format='PNG',optimize=True,compress_level=9)
    with Image.open(path) as check:
        check.verify()
    if path.stat().st_size<1000:
        raise RuntimeError('Atlas PNG unexpectedly empty '+str(path))
    return {'name':path.name,'sha256':digest(path),'size_bytes':path.stat().st_size,
            'width':image.width,'height':image.height}


def build_icon(frame):
    bounds=frame.getchannel('A').getbbox()
    if not bounds:
        raise ValueError('Missing machine pixels for icon')
    x0,y0,x1,y1=bounds
    width=x1-x0;height=y1-y0;side=max(width,height)*1.18
    cx=(x0+x1)*.5;cy=(y0+y1)*.5
    crop=frame.crop((int(cx-side/2),int(cy-side/2),
                     int(cx+side/2),int(cy+side/2)))
    return crop.resize((64,64),Image.Resampling.LANCZOS)


def proof_sheet(idles,actives,output):
    width,height=1240,600
    canvas=Image.new('RGB',(width,height),(28,30,32))
    d=ImageDraw.Draw(canvas)
    d.text((24,20),'Condenser V22C: native Blender four-way integration review',fill=(240,240,232))
    d.text((24,45),'Each direction: genuine idle / intake, not facsimile art',fill=(185,199,202))
    for i,angle in enumerate(ANGLES):
        x=18+(i%2)*620; y=75+(i//2)*255
        d.text((x+10,y),f'Blender {angle} degrees',fill=(220,218,210))
        for j,img in enumerate((idles[angle],actives[angle])):
            resized=img.resize((228,228),Image.Resampling.LANCZOS)
            bg=Image.new('RGBA',resized.size,(29,31,34,255))
            bg.alpha_composite(resized)
            canvas.paste(bg.convert('RGB'),(x+12+j*260,y+22))
    output.parent.mkdir(parents=True,exist_ok=True)
    canvas.save(output)
    return digest(output)


def build(frame_root, out_root):
    frame_root=Path(frame_root).resolve()
    out_root=Path(out_root).resolve()
    receipt=frame_root/'native_frames_manifest.json'
    if not receipt.is_file():
        raise RuntimeError('Missing native Blender frame provenance receipt')
    source=json.loads(receipt.read_text())
    if (source.get('source_sha256')!=APPROVED_V21_SHA or
        source.get('source_hierarchy_and_stationary_ports')!='PASS' or
        source.get('artificial_or_generated_image_frames') is not False or
        source.get('resolution')!=[512,512] or
        source.get('sampled_frames_per_orientation')!=len(FRAMES) or
        set(source['directions'])!={str(a) for a in ANGLES}):
        raise RuntimeError('Native source SHA, hierarchy, orientation or frame count incompatible')
    if out_root.exists() and any(out_root.iterdir()):
        raise RuntimeError('Refusing nonempty graphics output: '+str(out_root))
    folder=out_root/FOLDER
    folder.mkdir(parents=True,exist_ok=True)
    atlas_files={}
    idles={};actives={}
    for angle in ANGLES:
        key=ANGLE_NAMES[angle]
        entries=source['directions'][str(angle)]
        if [x['frame'] for x in entries]!=list(FRAMES):
            raise RuntimeError('Not the correct ordered 32 native source frames: '+key)
        frames=[open_real_frame(frame_root,record) for record in entries]
        idles[angle],actives[angle]=frames[0],frames[2]
        outputs={}
        for res,size in (('hr',FULL_SIZE),('sd',STANDARD_SIZE)):
            chunks=[]
            for idx in range(len(FRAMES)//CHUNK_FRAMES):
                chunk=frames[idx*CHUNK_FRAMES:(idx+1)*CHUNK_FRAMES]
                name=f'active-{key}-{res}-{idx:02d}.png'
                chunks.append(image_write(atlas(chunk,size),folder/name))
            idle_img=atlas([frames[0]]*CHUNK_FRAMES,size)
            idle=image_write(idle_img,folder/f'idle-{key}-{res}.png')
            outputs[res]={'activity_slices':chunks,'idle_repeated_slice':idle}
        atlas_files[key]=outputs
    icon=image_write(build_icon(idles[0]),folder/'icon-64.png')
    proof_path=out_root/'Condenser_V22C_Four_Way_Integration_Proof.png'
    proof_digest=proof_sheet(idles,actives,proof_path)
    result={
        'schema':'tech-priests.condenser-v22c-factorio-atlases.v1',
        'asset':'tech-priests-atmospheric-water-condenser',
        'source_sha256':APPROVED_V21_SHA,
        'native_scene_sha256':source['native_scene_sha256'],
        'orientation_angles':list(ANGLES),
        'orientation_name_map':ANGLE_NAMES,
        'native_frames_provenance_sha256':digest(receipt),
        'full_native_scene_frames':96,
        'actual_factorio_animation_frames':len(FRAMES),
        'source_frame_sequence':list(FRAMES),
        'cycle_seconds':CYCLE_SECONDS,
        'factorio_animation_speed_frames_per_tick':len(FRAMES)/(CYCLE_SECONDS*60),
        'chunk_frame_count':CHUNK_FRAMES,
        'line_length':COLS,
        'lines_per_file':ROWS,
        'hero_world_ortho_scale':3.2,
        'hr_frame_px':FULL_SIZE,
        'sd_frame_px':STANDARD_SIZE,
        'hr_factorio_scale':SCALE_HR,
        'sd_factorio_scale':SCALE_STANDARD,
        'nominal_collision_footprint_tiles':[2,2],
        'native_output_flange_tile_point':[1,-.5],
        'native_output_flange_height':.36,
        'factorio_output_connection_local':[.5,.5],
        'factorio_output_direction':'east',
        'blender_to_factorio':{'north':'north','east':'west_native','south':'south','west':'east_native'},
        'format':'PNG_RGBA_lossless; authored with Blender Cycles frames, PIL only composes sheets and resizes SD',
        'original_source_meshes_changed':False,
        'generated_image_art_or_fabricated_pixels':False,
        'files':atlas_files,'icon':icon,
        'proof':{'file':proof_path.name,'sha256':proof_digest},
    }
    manifest=out_root/'condenser_v22c_factorio_atlas_manifest.json'
    manifest.write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    print('CONDENSER_V22C_FACTORIO_ATLAS_PASS',sum(len(x['activity_slices'])+1 for d in atlas_files.values() for x in d.values())+1,flush=True)
    return result


def main():
    cli=argparse.ArgumentParser()
    cli.add_argument('--frames',type=Path,required=True)
    cli.add_argument('--out',type=Path,required=True)
    args=cli.parse_args()
    build(args.frames,args.out)

if __name__=='__main__':main()
