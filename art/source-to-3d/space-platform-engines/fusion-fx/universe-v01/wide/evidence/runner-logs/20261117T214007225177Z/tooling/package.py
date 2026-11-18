"""Verify real fusion PNGs and package lossless common-cropped native cells."""
import argparse, hashlib, json, math, pathlib, sys
HERE=pathlib.Path(__file__).resolve().parent;REPO=HERE.parents[3]
try:from PIL import Image, ImageChops, ImageDraw
except ImportError:
 sys.path.insert(0,str(REPO.parent/'local-validation/deps'));from PIL import Image,ImageChops,ImageDraw

def sha(path):return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()
def digest(im):return hashlib.sha256(im.tobytes()).hexdigest()
def dump(path,data):pathlib.Path(path).write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')

p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=pathlib.Path);p.add_argument('--allow-partial',action='store_true');p.add_argument('--no-crop',action='store_true');a=p.parse_args();R=a.directory.resolve();receipt=R/'capture-receipt.json';j=json.loads(receipt.read_text());cfg=json.loads((R/'profile.json').read_text());N=cfg['output_frames'];size=cfg['source_size'];records={(r['layer'],r['index']):r for r in j['frames']};images={};failures=[];bounds=[]
assert sha(j['input_glb']['path'])==j['input_glb']['sha256'];assert sha(R/'capture-master.blend')==j['master_sha256']
for path,expected in j['binding']['scripts'].items():assert sha(REPO/path)==expected,('Capture script changed; fresh derivative required',path)
for key,rec in records.items():
 path=R/rec['file'];assert sha(path)==rec['sha256'],('Changed capture',path)
 with Image.open(path)as im:im.verify()
 with Image.open(path)as im:im.load();im=im.convert('RGBA').copy()
 assert im.size==(size,size),('Wrong source cell',path,im.size)
 alpha=im.getchannel('A');box=alpha.getbbox()
 if box:
  assert box[0]>=4 and box[1]>=4 and box[2]<=size-4 and box[3]<=size-4,('Clipped or unsafe border',key,box)
  bounds.append(box)
 images[key]=im
for key in [('cold_body',0),('cold_light',0),('shadow',0)]:assert key in images,('Missing required static capture',key)
body=images[('cold_body',0)];body_alpha=body.getchannel('A');cold=images[('cold_light',0)]
assert cold.convert('RGB').getbbox()is None,'Cold light contains nonzero RGB'
assert ImageChops.difference(body_alpha,cold.getchannel('A')).getbbox()is None,'Cold light/body alpha differs'
assert images[('shadow',0)].convert('RGB').getbbox()is None,'Projected shadow is not black'
assert images[('shadow',0)].getchannel('A').getbbox(),'Projected shadow is empty'
working=sorted(i for layer,i in images if layer=='working_light'and i<N);common_alpha=True;arc_alpha=[]
for i in working:
 alpha=images[('working_light',i)].getchannel('A');same=ImageChops.difference(body_alpha,alpha).getbbox()is None;common_alpha=common_alpha and same
 if j.get('arcs'):
  assert ImageChops.subtract(body_alpha,alpha).getbbox()is None,('Working energy loses actual physical body coverage',i)
  extra=ImageChops.subtract(alpha,body_alpha);arc_alpha.append({'frame':i,'extra_arc_alpha_bounds':extra.getbbox(),'extra_arc_alpha_pixels':sum(v>0 for v in extra.getdata())})
 else:assert same,('Working light/body alpha differs',i)
complete=working==list(range(N))and('working_light',N)in images
wrap={}
for layer in('working_light','field'):
 if(layer,0)in images and(layer,N)in images:
  assert images[(layer,0)].tobytes()==images[(layer,N)].tobytes(),('Rendered loop wrap differs',layer)
  wrap[layer]=True
light_hashes=[digest(images[('working_light',i)])for i in working]
if len(light_hashes)>1:assert len(set(light_hashes))>1,'Working light is static'
strength_wrap=all(g['key_strengths'][0]==g['key_strengths'][-1]for g in j['emission_groups']);assert strength_wrap
missing=[]
if j['stage']=='FINAL_CAPTURE_CANDIDATE':
 if not j['underlay']:missing.append('source-specific service underlay')
 if not j['field']:missing.append('measured-aperture field candidate')
 if j['underlay']and('underlay',0)not in images:missing.append('service underlay capture')
 if j['field']and not all(('field',i)in images for i in range(N+1)):missing.append('complete field capture/wrap')
if not complete:missing.append('complete working light capture/wrap')
if missing and not a.allow_partial:raise AssertionError('Capture is incomplete: '+', '.join(missing))
union=[min(b[0]for b in bounds),min(b[1]for b in bounds),max(b[2]for b in bounds),max(b[3]for b in bounds)]
if a.no_crop:crop=[0,0,size,size]
else:crop=[max(0,math.floor((union[0]-8)/8)*8),max(0,math.floor((union[1]-8)/8)*8),min(size,math.ceil((union[2]+8)/8)*8),min(size,math.ceil((union[3]+8)/8)*8)]
w,h=crop[2]-crop[0],crop[3]-crop[1];reg=j['registration'];original=reg.get('original_full_canvas_registration')or{key:reg[key]for key in('cell','scale','shift_tiles','source_deck_pixel','aperture_pixel','field_origin_pixel')if key in reg};scale=original['scale'];shift=[original['shift_tiles'][0]+(crop[0]+w/2-size/2)*scale/32,original['shift_tiles'][1]+(crop[1]+h/2-size/2)*scale/32]
reg.update({'original_full_canvas_registration':original,'cell':[w,h],'shift_tiles':shift,'common_crop_box':crop,'source_deck_pixel':[original['source_deck_pixel'][0]-crop[0],original['source_deck_pixel'][1]-crop[1]],'aperture_pixel':[original['aperture_pixel'][0]-crop[0],original['aperture_pixel'][1]-crop[1]]if original['aperture_pixel']else None})
if original.get('field_origin_pixel'):reg['field_origin_pixel']=[original['field_origin_pixel'][0]-crop[0],original['field_origin_pixel'][1]-crop[1]]
dest=R/'package';dest.mkdir(exist_ok=True);layers={};proof=[]
def static(source,name):
 im=images[(source,0)].crop(crop);path=dest/(name+'.png');im.save(path);layers[name]={'file':path.relative_to(R).as_posix(),'frame_count':1,'scale':scale,'shift':shift,'sha256':sha(path)};proof.append({'layer':name,'source':records[(source,0)]['file'],'crop_rgba_sha256':digest(im),'packaged_rgba_sha256':digest(Image.open(path).convert('RGBA'))})
static('cold_body','cold_body');static('cold_light','cold_light');static('shadow','deck_shadow')
if('underlay',0)in images:static('underlay','service_underlay')
for source,name in[('working_light','working_light'),('field','field_candidate')]:
 if not all((source,i)in images for i in range(N)):continue
 pages=[]
 for page,start in enumerate(range(0,N,32)):
  count=min(32,N-start);rows=math.ceil(count/8);atlas=Image.new('RGBA',(w*8,h*rows))
  for k,index in enumerate(range(start,start+count)):atlas.paste(images[(source,index)].crop(crop),((k%8)*w,(k//8)*h))
  path=dest/f'{name}-{page+1}.png';atlas.save(path)
  with Image.open(path)as actual:
   actual=actual.convert('RGBA');actual.load()
   for k,index in enumerate(range(start,start+count)):
    cell=actual.crop(((k%8)*w,(k//8)*h,(k%8+1)*w,(k//8+1)*h));src=images[(source,index)].crop(crop);assert cell.tobytes()==src.tobytes(),('Atlas cell mismatch',source,index)
    proof.append({'layer':name,'index':index,'source':records[(source,index)]['file'],'source_crop_rgba_sha256':digest(src),'atlas_cell_rgba_sha256':digest(cell)})
  pages.append(path.relative_to(R).as_posix())
 layers[name]={'files':pages,'frame_count':N,'line_length':8,'lines_per_file':4,'animation_speed':N/2/60,'scale':scale,'shift':shift,'file_sha256':{f:sha(R/f)for f in pages}}
 if name=='field_candidate':layers[name]['kind']='advected_particle_ejecta_and_turbulent_wisps'
 # Pure source preview, never relabeled a native-engine capture.
 frames=[images[(source,i)].crop(crop)for i in range(N)];frames[0].save(dest/(name+'-source-loop.gif'),save_all=True,append_images=frames[1:],duration=2000/N,loop=0,disposal=2)
for name,spec in layers.items():
 for file in spec.get('files')or[spec['file']]:
  with Image.open(R/file)as im:im.verify()
preview=[]
def composite(index=None):
 bg=Image.new('RGBA',(w,h),(42,45,49,255));bg=Image.alpha_composite(bg,images[('shadow',0)].crop(crop))
 if('underlay',0)in images:bg=Image.alpha_composite(bg,images[('underlay',0)].crop(crop))
 bg=Image.alpha_composite(bg,body.crop(crop));rgb=bg.convert('RGB')
 if index is not None:
  for lane in('working_light','field'):
   if(lane,index)in images:
    im=images[(lane,index)].crop(crop);weighted=ImageChops.multiply(im.convert('RGB'),im.getchannel('A').convert('RGB'));rgb=ImageChops.add(rgb,weighted)
 return rgb
if working:
 preview=[composite(i)for i in working]
 preview[0].save(dest/'source-assembly-loop.gif',save_all=True,append_images=preview[1:],duration=2000/max(1,len(working)),loop=0)
 chosen=[working[min(len(working)-1,int(len(working)*q))]for q in(0,.25,.5,.75)]if len(working)>=4 else working;panels=[('Cold assembly',composite())]+[(f'Peak FX {i}/{N}',composite(i))for i in chosen]
 board=Image.new('RGB',(w*len(panels),h+46),(32,35,39));draw=ImageDraw.Draw(board)
 for k,(label,im)in enumerate(panels):board.paste(im,(k*w,28));draw.text((k*w+6,8),label,fill=(235,238,240))
 draw.text((6,h+30),'18MW normalized source; final native art fit pending',fill=(215,220,225));board.save(dest/'source-assembly-board.png')
status='PASS_FINAL_SOURCE_LAYERS_REQUIRES_NATIVE_FIT'if complete and not missing and j['stage']=='FINAL_CAPTURE_CANDIDATE'else'PASS_TOOLING_PILOT_WITH_EXPLICIT_BLOCKERS'if complete else'PARTIAL_CAPTURE_REQUIRES_COMPLETION'
result={'status':status,'input_glb_sha256':j['input_glb']['sha256'],'master_sha256':j['master_sha256'],'packager_sha256':sha(__file__),'source_cell':[size,size],'common_crop_box':crop,'native_cell':[w,h],'common_body_light_alpha':common_alpha,'physical_coverage_witness_exact':True,'working_energy_preserves_body_coverage':True,'added_arc_coverage':arc_alpha,'cold_light_rgb_zero':True,'shadow_rgb_black':True,'clear_source_border_pixels':4,'exact_strength_wrap':strength_wrap,'rendered_wrap':wrap,'distinct_working_light_images':len(set(light_hashes)),'missing':missing,'service_underlay_status':j['underlay_status'],'field_status':j['field_status'],'registration':reg,'layers':layers,'exact_cells':proof,'scope':'Actual reimport-derived PNGs and lossless cropped atlas cells; not native state/clock, owner approval, animated GLB, or real background-refraction proof.'}
j['render_color_management']={'cold_exposure_stops':0,'emission_capture_exposure_stops':cfg.get('light_exposure',-3),'view_transform':'Standard','meaning':'Capture exposure preserves imported emissive texture/color/strength, while reducing eight-bit green clipping. Source GLB/materials remain unchanged.'}
j['timeline']['native_power_sync']=False;j['timeline']['native_power_sync_status']='REQUIRES_ACTUAL_NATIVE_DRAW_VALIDATION'
j['source_assembly_preview']={'board':'package/source-assembly-board.png','loop':'package/source-assembly-loop.gif','scope':'Source-derived layer assembly on a neutral background; approximate additive color, quantized GIF timing, not native graphics proof.'}
j['registration']=reg;j['layers']=layers;j['status']=status;dump(receipt,j);dump(R/'package-validation.json',result);print(status,'cell',w,h,'unique light',len(set(light_hashes)),'wrap',wrap,'blockers',j['underlay_status'],j['field_status'])
