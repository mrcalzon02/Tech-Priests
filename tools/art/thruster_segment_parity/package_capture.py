"""Decode/hash every source pass, prove exact atlas cells and package a deterministic archive."""
import pathlib,json,hashlib,zipfile,sys
import numpy as np
from PIL import Image,ImageDraw,ImageFont
r=pathlib.Path(sys.argv[1]).resolve();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();receipt=json.loads((r/'capture-receipt.json').read_text(encoding='utf-8'));assert receipt['status']=='COMPLETE_SOURCE_CAPTURE_REQUIRES_REVIEW' and len(receipt['files'])==128
assert sha(r/'thetazine-animation-study.blend')==receipt['source_sha256'];root=r/'captures';package=r/'source-package';package.mkdir(exist_ok=True);lookup={};alphas=[];first=None;upper=None;bounds=[]
for row in receipt['files']:
 p=root/row['file'];assert sha(p)==row['sha256']
 with Image.open(p) as im:im.verify()
 with Image.open(p) as im:im.load();assert im.size==(512,768) and im.mode=='RGBA';pixels=im.copy()
 lookup[row['source_frame'],row['pass']]=pixels
for frame in range(1,65):
 a=np.array(lookup[frame,'beauty'])[:,:,3];b=np.array(lookup[frame,'emission'])[:,:,3];assert np.array_equal(a,b)
 assert not a[0].any() and not a[-1].any() and not a[:,0].any() and not a[:,-1].any()
 if upper is None:upper=a[:256].copy()
 assert np.array_equal(upper,a[:256]),'Fixed fore mount alpha moved'
 alphas.append(hashlib.sha256(a.tobytes()).hexdigest());bounds.append(lookup[frame,'beauty'].getbbox())
assert len(set(alphas))>1,'Mechanical motion must change alpha, not only glow'
atlas=[]
for kind in ['beauty','emission']:
 for page in range(2):
  im=Image.new('RGBA',(4096,3072))
  for local in range(32):im.paste(lookup[page*32+local+1,kind],((local%8)*512,(local//8)*768))
  dest=package/f'body-{kind}-{page+1}.png';im.save(dest)
  with Image.open(dest) as saved:
   saved.load()
   for local in range(32):
    x=local%8*512;y=local//8*768;assert saved.crop((x,y,x+512,y+768)).tobytes()==lookup[page*32+local+1,kind].tobytes()
  atlas.append({'path':dest.name,'sha256':sha(dest),'size':[4096,3072],'frames':list(range(page*32+1,page*32+33)),'pass':kind})
archive=package/'source-captures.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for name in sorted(row['file'] for row in receipt['files']):
  info=zipfile.ZipInfo('captures/'+name,date_time=(1980,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;z.writestr(info,(root/name).read_bytes())
 info=zipfile.ZipInfo('capture-receipt.json',date_time=(1980,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;z.writestr(info,(r/'capture-receipt.json').read_bytes())
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None and len(z.namelist())==129
 for row in receipt['files']:assert hashlib.sha256(z.read('captures/'+row['file'])).hexdigest()==row['sha256']
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',20);frames=[]
for frame in range(1,65):
 image=lookup[frame,'beauty'];board=Image.new('RGB',(720,550),(32,34,36));d=ImageDraw.Draw(board);d.text((12,9),'Blender source: 64-frame mechanical study',font=font,fill='white');small=image.resize((320,480));board.paste(small,(12,54),small);close=image.crop((132,430,380,730)).resize((360,435));board.paste(close,(350,85),close);d.text((350,53),'Nozzle / actuator detail',font=font,fill=(220,220,220));frames.append(board)
palette=frames[0].quantize(colors=256);gif_frames=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in frames];durations=[round((i+1)*100/30)*10-round(i*100/30)*10 for i in range(64)];assert sum(durations)==2130
gif_frames[0].save(r/'mechanical-source-loop.gif',save_all=True,append_images=gif_frames[1:],duration=durations,loop=0,optimize=False,disposal=2)
report={'status':'PASS_128_DECODED_SOURCE_PNGS_AND_EXACT_ATLAS_CELLS_NOT_NATIVE_APPROVAL','native_sha256':receipt['source_sha256'],'renderer_sha256':receipt['renderer_sha256'],'source_png_count':128,'unique_body_alpha_masks':len(set(alphas)),'fixed_fore_mount_alpha_exact_in_all_64':True,'beauty_emission_alpha_match_each_pose':True,'all_body_border_alpha_zero':True,'exact_rgba_atlas_cells_checked':128,'atlas':atlas,'source_archive_sha256':sha(archive),'source_archive_entries':129,'source_gif_sha256':sha(r/'mechanical-source-loop.gif'),'gif_cycle_milliseconds':sum(durations),'pending':['animated projected shadow','idle-state export and native effective frame count','flame and plume anchor review','full conditional native animation integration and working-clock proof','final surface/fidelity acceptance']}
(r/'package-validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n');print('SOURCE_PACKAGE_PASS',128,len(set(alphas)))
