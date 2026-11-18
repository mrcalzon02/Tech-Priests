"""Pack actual rendered source frames; no generated or painted motion substitute."""
from pathlib import Path
from PIL import Image
import json,hashlib,shutil,sys
R=Path(__file__).resolve().parents[3];O=Path(sys.argv[sys.argv.index('--asset')+1]).resolve() if '--asset' in sys.argv else R/'art/source-to-3d/conclave-center/v07-aged-and-ambient';STEM='conclave-center-'+O.name.split('-')[0];F=O/(sys.argv[sys.argv.index('--frames-dir')+1] if '--frames-dir' in sys.argv else 'motion-frames');frames=sorted(F.glob('*.png'));assert len(frames)==144
images=[Image.open(p).convert('RGBA') for p in frames];atlas=Image.new('RGBA',(6144,6144))
for i,im in enumerate(images):assert im.size==(512,512);atlas.paste(im,((i%12)*512,(i//12)*512))
C=O/'captures';C.mkdir(exist_ok=True);atlas.save(C/'ambient-north.png')
preview=[]
for im in images:
 bg=Image.new('RGB',im.size,(23,25,26));bg.paste(im,mask=im.getchannel('A'));preview.append(bg.quantize(colors=240))
preview[0].save(O/'ambient-preview.gif',save_all=True,append_images=preview[1:],duration=[80,80,90]*48,loop=0,disposal=2)
(O/'sprite-animation.json').write_text(json.dumps(dict(source_frames=144,frame_size=[512,512],line_length=12,animation_speed=.2,seconds=12,source_step=2,source_fps=24,runtime_fps=12,facings='Native fixed north container; four source review/body/shadow directions retained.',source_sha256=hashlib.sha256((O/(STEM+'.blend')).read_bytes()).hexdigest()),indent=2))
print('V07_REAL_MOTION_ATLAS_AND_GIF_READY')
