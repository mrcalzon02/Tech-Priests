"""Audit locally supplied Wube reference; publish numerical metadata only."""
import argparse,hashlib,io,json,pathlib,re,zipfile
import numpy as np
from PIL import Image,ImageDraw,ImageFont
p=argparse.ArgumentParser();p.add_argument('--zip',type=pathlib.Path,required=True);p.add_argument('--out',type=pathlib.Path,required=True);a=p.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=True);private=out/'private-reference';private.mkdir(exist_ok=True)
sha=lambda b:hashlib.sha256(b).hexdigest()
with zipfile.ZipFile(a.zip) as z:
 assert z.testzip() is None
 records=[];png={};descriptors={}
 for e in z.infolist():
  if e.is_dir():continue
  raw=z.read(e.filename);row={'name':e.filename,'bytes':len(raw),'sha256':sha(raw),'zip_crc32':f'{e.CRC:08x}'}
  if e.filename.endswith('.png'):
   with Image.open(io.BytesIO(raw)) as image:image.verify()
   image=Image.open(io.BytesIO(raw));image.load();png[pathlib.PurePosixPath(e.filename).name]=image.convert('RGBA');row.update({'size':list(image.size),'mode':image.mode})
  elif e.filename.endswith('.lua'):descriptors[pathlib.PurePosixPath(e.filename).name]=raw.decode('utf-8')
  records.append(row)
 body=[];light=[]
 for key,frames,cell in [('thruster',body,(264,542)),('thruster-light',light,(384,832))]:
  for page in [1,2]:
   image=png[f'{key}-{page}.png'];assert image.size==(cell[0]*8,cell[1]*4)
   for frame in range(32):x=frame%8*cell[0];y=frame//8*cell[1];frames.append(image.crop((x,y,x+cell[0],y+cell[1])))
 curves=[]
 for index,image in enumerate(body):
  alpha=np.asarray(image)[:,:,3];mask=alpha>128;region=mask[410:542];ys,xs=np.where(region)
  base=np.asarray(body[0])[:,:,3];diff=np.abs(alpha.astype(int)-base.astype(int))>10
  curves.append({'frame':index,'lower_lip_alpha_bounds':[int(xs.min()),int(ys.min()+410),int(xs.max()+1),int(ys.max()+411)],'lower_lip_width_px':int(xs.max()-xs.min()+1),'alpha_changes_from_frame0':int(diff.sum()),'upper_fixed_region_alpha_changes':int(diff[0:340].sum()),'lower_lip_alpha_changes':int(diff[410:542].sum()),'source_cell_rgba_sha256':sha(image.tobytes()),'light_cell_rgba_sha256':sha(light[index].tobytes())})
 font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18);board=Image.new('RGB',(1056,1140),(36,38,41));d=ImageDraw.Draw(board)
 for n,index in enumerate([0,16,24,25,26,40,52,63]):
  im=body[index];x=n%4*264;y=n//4*570;board.paste(im,(x,y+25),im);d.text((x+8,y+2),f'Vanilla body {index:02}',font=font,fill='white')
 board.save(private/'body-cues-PRIVATE.png');png['thruster-bckg.png'].save(private/'underlay-PRIVATE.png')
 frames=[]
 for index in range(64):
  im=Image.new('RGB',(264,542),(36,38,41));im.paste(body[index],(0,0),body[index]);frames.append(im)
 frames[0].save(private/'body-64-frame-PRIVATE.gif',save_all=True,append_images=frames[1:],duration=[33 if i%3 else 34 for i in range(64)],loop=0,optimize=False)
 report={'status':'ALL_SUPPLIED_ENTRIES_CRC_AND_IMAGE_DECODE_VERIFIED','zip_sha256':sha(a.zip.read_bytes()),'source_zip_bytes':a.zip.stat().st_size,'entries':records,'descriptors':descriptors,'body':{'frames':64,'cell':[264,542],'pages':2,'frames_per_page':32,'grid':[8,4],'descriptor_shift_px':[1.5,-39],'native_scale':.5,'native_base_shift_tiles':[0,3],'effective_shift_tiles':[.046875,1.78125],'animation_speed':.5},'light':{'frames':64,'cell':[384,832],'pages':2,'frames_per_page':32,'descriptor_shift_px':[0,0],'native_scale':.5,'native_base_shift_tiles':[0,3],'additive':True,'fadeout':True,'draw_as_glow':True},'integration_patch':{'cell':[302,452],'descriptor_shift_px':[2,-72.5],'native_scale':.5,'native_base_shift_tiles':[0,3],'effective_shift_tiles':[.0625,.734375],'render_layer':'floor','alpha_center':list(png['thruster-bckg.png'].getpixel((151,200))),'meaning':'Transparent U-shaped machinery underlay; not an opaque painted hole and not a tile-deletion script.'},'pipe_visuals':{'count':4,'cell':[384,832],'native_scale':.5,'named_conditional':['pipe-1','pipe-2','pipe-3','pipe-4'],'native_y_shift_pixels':[95,96,96,95]},'flame':{'cell':[384,832],'type':'separate EffectTexture, not baked into body'},'plumes':{'sheets':['thruster-smoke.png','thruster-smoke-glow.png'],'frames_each':60,'native_visualisations':3,'independent_of_body_clock':True},'body_motion':curves,'remnants':{'included':True,'separate_lifecycle':True},'copyright':'Wube reference pixels and derived contact sheets/loops stay local/private, not committed as mod-owned source or re-uploaded to GitHub. Native __space-age__ paths may be referenced without copying.'}
 (out/'package-audit.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n');print(json.dumps({'zip_sha256':report['zip_sha256'],'files':len(records),'body_frames':len(body),'light_frames':len(light),'body_lip_width_range':[min(v['lower_lip_width_px'] for v in curves),max(v['lower_lip_width_px'] for v in curves)]}))
