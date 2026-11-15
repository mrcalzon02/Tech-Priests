"""Decode shadow pass, retain camera registration, package bounded atlases with exact cell proof."""
import pathlib,json,hashlib
import numpy as np
from PIL import Image,ImageChops,ImageDraw
W=pathlib.Path(__file__).parent;O=W/'energy-dish-v03-shadow64-sharp/loader-metadata';B=W/'energy-dish-v03';identity=json.loads((O/'shadow-identity.json').read_text());state=json.loads((O/'CHECKPOINT.json').read_text());assert state['status']=='SHADOW64_RENDERED_REQUIRES_DECODE_ATLAS_REVIEW' and len(state['completed'])==64
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();frames=[];records=[];sheets=[];atlasdir=O/'atlases';atlasdir.mkdir(exist_ok=True);authored=O/'authored';authored.mkdir(exist_ok=True)
reference=pathlib.Path('C:/GITS/Tech-Priests/tech-priests_src/graphics/entity/bunker-autocannon/base-north-shadow.png');peak=Image.open(reference).getchannel('A').getextrema()[1];assert peak==177;alpha_table=[round(x*peak/255) for x in range(256)]
old=json.loads((B/'idle64-validation.json').read_text());assert identity['dish_sha256']==old['source_identity']['dish_native_sha256'];assert np.max(abs(np.array(identity['camera_matrix'])-np.array(old['source_identity']['camera_world_matrix'])))<1e-6
for d in range(64):
 p=O/f'shadow-{d:02}.png'
 with Image.open(p) as im:im.verify()
 with Image.open(p) as im:
  im.load();assert im.mode=='RGBA' and im.size==(1280,1280);a=np.array(im);box=im.getchannel('A').getbbox();assert box and box[0]>0 and box[1]>0 and box[2]<1280 and box[3]<1280;alpha=im.getchannel('A').point(alpha_table);frame=Image.new('RGBA',im.size,(0,0,0,0));frame.putalpha(alpha);dest=authored/f'shadow-{d:02}.png';frame.save(dest);frames.append(frame);records.append({'direction':d,'shadow_sha256':sha(p),'authored_shadow_sha256':sha(dest),'raw_alpha_bounds':box,'raw_rgb_maximum':int(a[:,:,:3].max()),'raw_maximum_alpha':int(a[:,:,3].max()),'authored_maximum_alpha':alpha.getextrema()[1]})
 # Existing beauty pixels are read, not regenerated.
 assert sha(B/'idle64'/f'idle-{d:02}.png')==old['records'][d]['raw_sha256']
for cell in [1280,512]:
 for page in range(4):
  sheet=Image.new('RGBA',(cell*4,cell*4))
  for i in range(16):
   frame=frames[page*16+i] if cell==1280 else frames[page*16+i].resize((cell,cell),Image.Resampling.LANCZOS);sheet.paste(frame,((i%4)*cell,(i//4)*cell))
  dest=atlasdir/f'idle-shadow-{cell}-{page+1}.png';sheet.save(dest)
  with Image.open(dest) as check:
   check.load();assert check.size==(cell*4,cell*4)
   for i in range(16):
    want=frames[page*16+i] if cell==1280 else frames[page*16+i].resize((cell,cell),Image.Resampling.LANCZOS);got=check.crop(((i%4)*cell,(i//4)*cell,(i%4+1)*cell,(i//4+1)*cell));assert ImageChops.difference(want,got).getbbox(alpha_only=False) is None
  sheets.append({'file':'atlases/'+dest.name,'sha256':sha(dest),'cell':cell,'page':page+1,'directions':[page*16,page*16+15],'atlas_size':cell*4})
matrix=identity['camera_matrix'];scale=identity['camera_ortho_scale'];delta=[-matrix[j][3] for j in range(3)];local=[sum(matrix[j][i]*delta[j] for j in range(3)) for i in range(3)];origin=[(0.5+local[0]/scale)*1280,(0.5-local[1]/scale)*1280];shift=[(640-p)*scale/1280 for p in origin];assert max(abs(shift[i]-old['factorio_shift'][i]) for i in range(2))<1e-5
board=Image.new('RGB',(1600,850),(175,175,175));draw=ImageDraw.Draw(board)
for i,d in enumerate(range(0,64,8)):
 bg=Image.new('RGBA',(1280,1280),(175,175,175,255));bg.alpha_composite(frames[d]);beauty=Image.open(B/'idle64'/f'idle-{d:02}.png').convert('RGBA');bg.alpha_composite(beauty,(320,320));board.paste(bg.convert('RGB').resize((400,400),Image.Resampling.LANCZOS),((i%4)*400,(i//4)*425));draw.text(((i%4)*400+8,(i//4)*425+403),f'd{d:02}: source beauty + new shadow (not native)',fill='black')
board.save(O/'eight-headings-shadow-composition.png')
out={'status':'PASS_64_SHADOW_DECODE_AND_128_EXACT_ATLAS_CELLS_REQUIRES_FINAL_VISUAL_REVIEW','identity':identity,'source_images':64,'exact_rgba_cells':128,'atlas_cell_basis':'64authoredRGBAframes plus64deterministic Lanczos downsample cells; raw renders preserved separately','alpha_authoring':{'method':'round(raw_alpha*177/255); authored RGB explicitly neutral black (raw display RGB retained in archive)','reference_file':'tech-priests_src/graphics/entity/bunker-autocannon/base-north-shadow.png','reference_sha256':sha(reference),'reference_maximum_alpha':peak},'sheets':sheets,'registration':{'world_origin_pixel_at1280':origin,'factorio_shift':shift,'factorio_scale_at1280':32*scale/1280,'factorio_scale_at512':32*scale/512,'camera_and_shift_equal_existing_beauty':True},'source_beauty_unchanged':'64/64originalPNGhashes match existing receipt','records':records,'scope':'Idle-only source composition; no native-game prototype integration or final owner approval'}
(O/'shadow64-validation.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8',newline='\n');print(json.dumps({k:out[k] for k in ['status','source_images','exact_rgba_cells','registration','source_beauty_unchanged']}))
