"""Verify real separated body/glow captures and exact bounded atlas cells."""
import argparse,pathlib,json,hashlib,zipfile,io,shutil
import numpy as np
from PIL import Image,ImageDraw,ImageFont
p=argparse.ArgumentParser();p.add_argument('directory',type=pathlib.Path);p.add_argument('--out',type=pathlib.Path,required=True);a=p.parse_args();r=a.directory.resolve();out=a.out.resolve();out.mkdir(exist_ok=True,parents=True);sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
c=json.loads((r/'separated-body-heat-capture.json').read_text(encoding='utf-8'));assert c['native_sha256']==sha(r/'thetazine-v04-regenerative-study.blend') and len(c['files'])==132
paths={};stats=[]
for row in c['files']:
 path=r/row['file'];assert sha(path)==row['sha256'] and row['body_thermal_materials_unanimated'];im=Image.open(path);im.verify();im=Image.open(path).convert('RGBA');assert im.size==(512,1280);paths[row['frame'],row['pass']]=path
 if row['pass']=='heat-glow':
  v=np.asarray(im)[:,:,:3];nonzero=np.max(v,axis=2)>2;ys,xs=np.where(nonzero)
  if row['frame']==0:assert not nonzero.any(),'Cold pose heat must be black'
  else:assert nonzero.any() and ys.min()>550 and ys.max()<1232,'Full bell/plume light map leaked onto head or canvas edge'
  stats.append({'frame':row['frame'],'heat_rgb_nonzero_pixels':int(nonzero.sum()),'heat_peak_byte':int(v.max()),'heat_mean_byte':float(v.mean()),'rgb_bounds':None if not len(xs) else [int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)]})
assert set(paths)=={(frame,kind) for frame in range(66) for kind in ['body','heat-glow']}
body=np.asarray(Image.open(paths[17,'body']).convert('RGBA'));heat=np.asarray(Image.open(paths[17,'heat-glow']).convert('RGBA'));mask=heat[:,:,0]>100
body_at_hotspot=float(np.max(body[:,:,:3],axis=2)[mask].mean());heat_at_hotspot=float(np.max(heat[:,:,:3],axis=2)[mask].mean());assert body_at_hotspot<heat_at_hotspot*.75,(body_at_hotspot,heat_at_hotspot,'heat baked into body')
package=r/'source-package';package.mkdir(exist_ok=True);atlases=[]
for kind in ['body','heat-glow']:
 for sheet in range(2):
  frames=list(range(1+sheet*32,33+sheet*32));atlas=Image.new('RGBA',(4096,5120))
  for i,frame in enumerate(frames):
   with Image.open(paths[frame,kind]) as im:atlas.paste(im,(i%8*512,i//8*1280))
  # Installed vanilla light maps use opaque RGB for emitted blue regions.
  # Preserve rendered emission RGB and avoid a second volume-alpha attenuation.
  if kind=='heat-glow':atlas.putalpha(255)
  dest=package/f'{kind}-{sheet+1}.png';atlas.save(dest)
  with Image.open(dest) as actual:
   actual.load()
   for i,frame in enumerate(frames):
    with Image.open(paths[frame,kind]) as im:
     expected=im.convert('RGBA')
     if kind=='heat-glow':expected.putalpha(255)
     assert actual.crop((i%8*512,i//8*1280,i%8*512+512,i//8*1280+1280)).tobytes()==expected.tobytes()
  atlases.append({'path':dest.name,'pass':kind,'frames':frames,'size':[4096,5120],'cell':[512,1280],'exact_cells_verified':32,'sha256':sha(dest)})
 for frame in [0]:
  im=Image.open(paths[frame,kind]).convert('RGBA')
  if kind=='heat-glow':im.putalpha(255)
  im.save(package/f'idle-{kind}.png')
archive=package/'separated-body-heat-captures.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for row in c['files']:
  info=zipfile.ZipInfo(row['file'],(2026,11,8,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;z.writestr(info,(r/row['file']).read_bytes())
 info=zipfile.ZipInfo('separated-body-heat-capture.json',(2026,11,8,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;z.writestr(info,(r/'separated-body-heat-capture.json').read_bytes())
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None and len(z.namelist())==133
 for row in c['files']:assert hashlib.sha256(z.read(row['file'])).hexdigest()==row['sha256']
font=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',19);bg=(14,17,21,255);panel=Image.new('RGB',(1152,804),bg[:3])
for i,(label,path) in enumerate([('BODY / NO HEAT',paths[17,'body']),('SEPARATE HEAT GLOW',paths[17,'heat-glow']),('SOURCE / JET SEPARATE',r/'full-preview-frames/17.png')]):
 im=Image.open(path).convert('RGBA');base=im.convert('RGB');tile=base.crop((0,168,512,1160)).resize((384,744),Image.Resampling.LANCZOS);panel.paste(tile,(i*384,42));ImageDraw.Draw(panel).text((i*384+15,10),label,font=font,fill=(225,231,237))
panel.save(out/'thetazine-v04-separate-heat-glow.png')
for kind in ['body','heat-glow']:shutil.copy2(paths[17,kind],out/f'thetazine-v04-{kind}-frame17.png')
result={'status':'PASS_SEPARATE_NOHEAT_BODY_AND_HEAT_ONLY_132_PNGS_128_EXACT_ATLAS_CELLS','native_sha256':c['native_sha256'],'capture_renderer_sha256':c['renderer_sha256'],'source_pngs':132,'working_cells':128,'atlas':atlases,'source_archive_sha256':sha(archive),'source_archive_bytes':archive.stat().st_size,'cold_heat_rgb_zero':True,'body_hotspot_mean_max_rgb_byte':body_at_hotspot,'heat_hotspot_mean_max_rgb_byte':heat_at_hotspot,'heat_effectively_absent_from_body':True,'heat_mask_scope':'Only mapped bell/refractory heat; no fuel, chamber head or exhaust cone','heat_statistics':stats,'preview_sha256':sha(out/'thetazine-v04-separate-heat-glow.png'),'registration':json.loads((r/'source-manifest.json').read_text())['draw_registration'],'native_layer_contract':{'same_64_source_poses':True,'body_bell_emission_strength':0,'heat_blend_mode':'additive','heat_draw_as_glow':True,'scale':.46875,'shift':json.loads((r/'source-manifest.json').read_text())['draw_registration']['shift'],'cold_heat':'idle-heat-glow.png contains zero RGB; do not draw a hot working frame on idle'},'scope':'Actual local Blender source export and atlas/registration checks only. Native working clock, day/night balance and additive occlusion remain untested for V04.'}
result['atlas_pixel_contract']='64body RGBA cells exact;64heat RGB cells exact with alpha255 for native additive emission. Original132RGBA source captures retained in archive. Black additive pixels contribute zero.';result['heat_mask_scope']='Mapped bell/refractory plus full-throated render-only volume; no fuel-window glow or chamber-head emission.'
(r/'body-heat-validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n');print(json.dumps({k:result[k] for k in ['status','source_pngs','working_cells','source_archive_bytes','body_hotspot_mean_max_rgb_byte','heat_hotspot_mean_max_rgb_byte']}))
