"""Verify real source captures and package labeled cold/working proof."""
import argparse,pathlib,json,hashlib,zipfile,io
import numpy as np
from PIL import Image,ImageDraw,ImageFont
p=argparse.ArgumentParser();p.add_argument('directory',type=pathlib.Path);p.add_argument('--out',type=pathlib.Path,required=True);a=p.parse_args();r=a.directory.resolve();out=a.out.resolve();out.mkdir(parents=True,exist_ok=True);sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
c=json.loads((r/'full-preview-capture.json').read_text(encoding='utf-8'));assert len(c['frames'])==66 and sorted(x['frame'] for x in c['frames'])==list(range(66));assert c['native_sha256']==sha(r/'thetazine-v03-pressure-study.blend')
frames={};bounds=[]
for row in c['frames']:
 path=r/row['file'];assert sha(path)==row['sha256']
 with Image.open(path) as im:im.verify()
 im=Image.open(path).convert('RGBA');assert im.size==(512,1280);bbox=im.getchannel('A').getbbox();assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<512 and bbox[3]<1280,(row['frame'],bbox);frames[row['frame']]=im;bounds.append({'frame':row['frame'],'alpha_bounds':bbox})
unique=len({hashlib.sha256(frames[i].tobytes()).hexdigest() for i in range(1,65)});assert unique==64
diff=np.abs(np.asarray(frames[1]).astype(int)-np.asarray(frames[65]).astype(int));wrap={'rgba_exact':bool(not diff.any()),'max_byte_delta':int(diff.max()),'mean_byte_delta':float(diff.mean()),'note':'Source transforms and morphs have exact wrap; a render mismatch would remain explicitly reported.'}
font=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',20);small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',15);bg=(14,17,21,255)
def tile(frame):
 canvas=Image.new('RGBA',frames[frame].size,bg);canvas.alpha_composite(frames[frame]);return canvas.convert('RGB').crop((0,168,512,1160)).resize((384,744),Image.Resampling.LANCZOS)
cold=tile(0);panels=[]
for frame in range(1,65):
 im=Image.new('RGB',(768,812),bg[:3]);im.paste(cold,(0,42));im.paste(tile(frame),(384,42));d=ImageDraw.Draw(im);d.text((22,9),'COLD / CONTAINED',font=font,fill=(225,231,237));d.text((406,9),'THRUST / RESTRAINED',font=font,fill=(225,231,237));d.text((22,788),'V03 local Blender study - 64 actual poses - not yet installed',font=small,fill=(165,181,196));panels.append(im)
palette=Image.new('RGB',(768*4,812*4))
for i in range(16):palette.paste(panels[i*4],((i%4)*768,(i//4)*812))
palette=palette.quantize(colors=256);gif=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in panels];durations=[round((i+1)*100/30)*10-round(i*100/30)*10 for i in range(64)];gif[0].save(out/'thetazine-v03-containment-loop.gif',save_all=True,append_images=gif[1:],duration=durations,loop=0,optimize=False,disposal=2)
with Image.open(out/'thetazine-v03-containment-loop.gif') as im:assert im.n_frames==64
contact=Image.new('RGB',(768,812*2),bg[:3])
for i,frame in enumerate([1,17,33,49]):
 # Full front poses on a compact temporal sheet, with a persistent cold reference.
 contact.paste(panels[frame-1].resize((384,406),Image.Resampling.LANCZOS),((i%2)*384,(i//2)*406))
contact=contact.crop((0,0,768,812));contact.save(out/'thetazine-v03-keyposes.png')
panels[16].save(out/'thetazine-v03-cold-thrust.png')
archive=r/'source-captures.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for row in c['frames']:
  info=zipfile.ZipInfo(row['file'],(2026,11,8,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;z.writestr(info,(r/row['file']).read_bytes())
 info=zipfile.ZipInfo('full-preview-capture.json',(2026,11,8,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;z.writestr(info,(r/'full-preview-capture.json').read_bytes())
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None and len(z.namelist())==67
 for row in c['frames']:assert hashlib.sha256(z.read(row['file'])).hexdigest()==row['sha256']
result={'status':'PASS_66_ACTUAL_SOURCE_PNGS_64_UNIQUE_WORKING_POSES_AND_ARCHIVE','native_sha256':c['native_sha256'],'source_archive_sha256':sha(archive),'source_pngs':66,'working_unique_rgba':unique,'wrap_image_comparison':wrap,'frames':bounds,'preview_files':[{'file':p.name,'sha256':sha(p)} for p in out.glob('thetazine-v03-*.png')]+[{'file':'thetazine-v03-containment-loop.gif','sha256':sha(out/'thetazine-v03-containment-loop.gif')}],'gif_frame_count':64,'gif_duration_ms':sum(durations),'scope':'Combined body and FX source proof only; no segmented atlas, shadow pass, native visual import or performance/behavior assertion.'}
(r/'preview-validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n');print(json.dumps({k:result[k] for k in ['status','working_unique_rgba','wrap_image_comparison','gif_duration_ms']}))
