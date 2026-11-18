"""Full-color video of the actual working poses, avoiding GIF palette dithering."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

repo=Path(__file__).resolve().parents[3];sys.path.insert(0,str(repo.parent/'local-validation/deps'))
from PIL import Image

p=argparse.ArgumentParser();p.add_argument('directory',type=Path);a=p.parse_args();root=a.directory.resolve()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
capture=json.loads((root/'motion-capture.json').read_text(encoding='utf-8'))
rows={r['frame']:r for r in capture['frames']if r['view']=='mechanism'}
assert set(rows)==set(range(66))
frames=[];size=None
for f in range(1,65):
    path=root/rows[f]['file'];assert sha(path)==rows[f]['sha256']
    with Image.open(path)as im:
        rgba=im.convert('RGBA');size=rgba.size
        bg=Image.new('RGBA',size,(18,21,24,255))
        frames.append(Image.alpha_composite(bg,rgba).convert('RGB').tobytes())
exe=shutil.which('ffmpeg');assert exe,'Installed FFmpeg required'
dst=root/'thetazine-v06-mechanism-cycle.mp4'
command=[exe,'-hide_banner','-loglevel','error','-y','-f','rawvideo','-pixel_format','rgb24',
         '-video_size',f'{size[0]}x{size[1]}','-framerate','30','-i','pipe:0','-an',
         '-c:v','libx264','-preset','medium','-crf','17','-pix_fmt','yuv420p','-threads','4',
         '-movflags','+faststart',str(dst)]
process=subprocess.Popen(command,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
for _ in range(3):
    for frame in frames:process.stdin.write(frame)
process.stdin.close();process.wait();errors=process.stderr.read().decode('utf-8',errors='replace')
assert process.returncode==0,errors
version=subprocess.check_output([exe,'-version']).decode('utf-8').splitlines()[0]
report={'status':'ENCODED_ACTUAL_SOURCE_FULL_COLOR_MOTION_VIDEO','file':dst.name,'sha256':sha(dst),
        'source_sha256':capture['binding']['source_sha256'],'capture_receipt_sha256':sha(root/'motion-capture.json'),
        'script_sha256':sha(Path(__file__)),'encoder':version,'size':list(size),'fps':30,'video_frames':192,
        'duration_seconds':6.4,'working_loop_frames':64,'loop_repetitions':3,
        'scope':'Three repeats of the same64 actual source working poses, composited on a dark background and encoded without GIF palette reduction. Source preview, not native gameplay timing.'}
(root/'motion-video-preview.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(report['status'],str(dst),dst.stat().st_size)
