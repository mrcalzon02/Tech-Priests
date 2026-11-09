"""Trim only empty canvas, compensate registration, verify every actual cell."""
import pathlib,argparse,json,hashlib,numpy as np
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('study',type=pathlib.Path);a=p.parse_args();R=a.study.resolve();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();c=json.loads((R/'projected-shadow-capture.json').read_text());m=json.loads((R/'source-manifest.json').read_text());assert c['native_sha256']==m['native_sha256'];assert len(c['frames'])==66;images={};bounds=[];rgb_dither_max=0
for row in c['frames']:
 p=R/row['file'];assert sha(p)==row['sha256'];im=Image.open(p).convert('RGBA');assert im.size==(768,1280);v=np.array(im);rgb_dither_max=max(rgb_dither_max,int(v[:,:,:3].max()));assert v[:,:,:3].max()<=1,'Unexpected nonblack shadow material';alpha=v[:,:,3];assert max(alpha[0].max(),alpha[-1].max(),alpha[:,0].max(),alpha[:,-1].max())==0;box=im.getbbox();assert box;bounds.append(box);v[:,:,:3]=0;images[row['frame']]=Image.fromarray(v,'RGBA')
pad=4;x0=min(v[0] for v in bounds)-pad;y0=min(v[1] for v in bounds)-pad;x1=max(v[2] for v in bounds)+pad;y1=max(v[3] for v in bounds)+pad
if (x1-x0)%2:x1+=1
if (y1-y0)%2:y1+=1
crop=[x0,y0,x1,y1];assert x0>0 and y0>0 and x1<768 and y1<1280;w=x1-x0;h=y1-y0;scale=m['draw_registration']['scale'];original=m['draw_registration']['shift'];shift=[original[0]+((x0+x1)/2-384)*scale/32,original[1]+((y0+y1)/2-640)*scale/32];registration=[]
# A common pixel's native point must be identical before/after cropping.
for x,y in [(384,640),(x0,y0),(x1,y1),(214,228),(603,614)]:
 before=[(x-384)*scale/32+original[0],(y-640)*scale/32+original[1]];after=[(x-x0-w/2)*scale/32+shift[0],(y-y0-h/2)*scale/32+shift[1]];assert max(abs(a-b) for a,b in zip(before,after))<1e-12;registration.append({'full_pixel':[x,y],'native_point':before,'cropped_native_point':after})
package=R/'source-package';package.mkdir(exist_ok=True);atlases=[]
for page in range(2):
 sheet=Image.new('RGBA',(w*8,h*4))
 for i in range(32):sheet.paste(images[1+page*32+i].crop(crop),((i%8)*w,(i//8)*h))
 path=package/f'shadow-{page+1}.png';sheet.save(path)
 with Image.open(path) as check:
  for i in range(32):assert np.array_equal(np.asarray(check.crop(((i%8)*w,(i//8)*h,(i%8+1)*w,(i//8+1)*h))),np.asarray(images[1+page*32+i].crop(crop)))
 atlases.append({'file':path.name,'sha256':sha(path),'size':list(sheet.size)})
images[0].crop(crop).save(package/'idle-shadow.png');unique=len({hashlib.sha256(np.asarray(images[f]).tobytes()).hexdigest() for f in range(1,65)});wrap=np.abs(np.asarray(images[1]).astype(np.int16)-np.asarray(images[65]).astype(np.int16));out={'status':'PASS_66_ACTUAL_PROJECTED_SHADOWS_64_EXACT_CELLS_AND_CROP_REGISTRATION','native_sha256':m['native_sha256'],'source_capture_sha256':sha(R/'projected-shadow-capture.json'),'poses':66,'full_cell':[768,1280],'crop':crop,'cell':[w,h],'scale':scale,'shift':shift,'original_body_shift':original,'common_pixel_registration':registration,'atlas':atlases,'idle_shadow_sha256':sha(package/'idle-shadow.png'),'unique_working_rgba':unique,'wrap_max_byte_delta':int(wrap.max()),'scope':'Actual evaluated source geometry clipped at deck and parallel-projected. Source render and exact atlas/registration proof; native shadow phase and appearance still require review. Opaque silhouette, not a physically simulated transparent-glass shadow.'};(R/'projected-shadow-validation.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8',newline='\n');print(json.dumps({k:out[k] for k in ['status','cell','shift','unique_working_rgba','wrap_max_byte_delta']}))
