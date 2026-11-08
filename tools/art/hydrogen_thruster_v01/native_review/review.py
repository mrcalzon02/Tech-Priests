import argparse,hashlib,json,pathlib
from PIL import Image,ImageDraw,ImageFont
import numpy as np
ap=argparse.ArgumentParser();ap.add_argument('review_root',type=pathlib.Path);ap.add_argument('model_root',type=pathlib.Path);a=ap.parse_args();root=a.review_root.resolve();model=a.model_root.resolve();shots=root/'userdata/script-output/hydrogen-model-review';binding=json.loads((root/'candidate-binding.json').read_text(encoding='utf-8'))
lines=[l for l in (root/'userdata/factorio-current.log').read_text(encoding='utf-8').splitlines() if 'HYDROGEN_NATIVE_JSON ' in l];assert len(lines)==1;graphics=json.loads(lines[0].split('HYDROGEN_NATIVE_JSON ',1)[1]);assert graphics['nonvisual_fields_preserved'] and graphics['native_cap_visualisations_preserved'];assert graphics['drawing_box']==[[-2.65,-2.95],[2.65,5.25]]
assert graphics['footprint']==[4,4] and graphics['collision_box']==[[-1.85,-1.85],[1.85,1.85]]
package=model/'package';assert binding['module_sha256']==hashlib.sha256((package/'hydrogen-thruster-v01.lua').read_bytes()).hexdigest()
for name,digest in binding['images'].items():assert hashlib.sha256((package/name).read_bytes()).hexdigest()==digest
receipts={s:json.loads((shots/(s+'-receipt.json')).read_text(encoding='utf-8')) for s in ['connected','disconnected']}
for state,receipt in receipts.items():
 assert len(receipt['entities'])==3
 for e in receipt['entities']:
  assert len(e['ports'])==2
  for port,sign in zip(e['ports'],[-1,1]):
   expected=[e['position']['x']+sign*1.5,-.5];assert [port['position']['x'],port['position']['y']]==expected
   target=[e['position']['x']+sign*2.5,-.5];assert [port['target_position']['x'],port['target_position']['y']]==target
   assert port.get('connected_name')==('pipe' if state=='connected' else None)
images={}
for p in shots.glob('*.png'):
 with Image.open(p) as im:im.verify()
 with Image.open(p) as im:im.load();assert im.size==(800,1000)
 images[p.name]=hashlib.sha256(p.read_bytes()).hexdigest()
assert len(images)==21
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',20);board=Image.new('RGB',(1200,1090),(29,33,38));draw=ImageDraw.Draw(board);draw.text((10,8),'Hydrogen V01: actual native graphics review / fixed physical pipe positions',font=font,fill='white')
for row,state in enumerate(['connected','disconnected']):
 for col,(name,label) in enumerate([('legacy','Previous sprite'),('candidate-idle','Authored idle / actual target'),('candidate-run','Authored run / forced display')]):
  with Image.open(shots/(name+'-'+state+'.png')) as im:board.paste(im.convert('RGB').resize((400,500),Image.Resampling.LANCZOS),(col*400,40+row*525))
  draw.text((col*400+6,540+row*525),label+' / '+state,font=font,fill='white')
board.save('outputs/hydrogen-v01-native-review.png');board.save(model/'native-review-board.png')
frames=[];roi_hashes=[];blue_means=[];pose_board=Image.new('RGB',(1820,220),(29,33,38));pose_draw=ImageDraw.Draw(pose_board)
assert len(graphics['pose_graphics'])==7
for i,pose in enumerate(graphics['pose_graphics']):
 assert pose['source_index']==i
 assert pose['body']['north']['layers'][0]['x']==i*512 and pose['body']['north']['layers'][0]['frame_count']==1
 thermal=next(v for v in pose['visuals'] if v.get('name')=='hydrogen-v01-thermal-glow');assert thermal['animation']['x']==i*512 and thermal['animation']['frame_count']==1
 with Image.open(shots/('frozen-source-pose-'+str(i)+'.png')) as im:
  arr=np.asarray(im.convert('RGB'));roi=arr[730:830,270:530].astype('int16');blue=np.maximum(roi[:,:,2]-np.maximum(roi[:,:,0],roi[:,:,1]),0).astype('uint8');roi_hashes.append(hashlib.sha256(blue.tobytes()).hexdigest());blue_means.append(float(blue.mean()));frames.append(im.convert('RGB').resize((400,500),Image.Resampling.LANCZOS))
  pose_board.paste(im.convert('RGB').crop((270,700,530,850)),(i*260,35));pose_draw.text((i*260+8,190),'Source pose '+str(i),font=font,fill='white')
assert max(blue_means)-min(blue_means)>.1,blue_means
pose_draw.text((8,6),'Native frozen source poses / real working-clock progression not tested',font=font,fill='white');pose_board.save('outputs/hydrogen-v01-native-frozen-poses.png');pose_board.save(model/'native-frozen-poses.png')
source_frames=[]
for i in range(7):
 with Image.open(model/'captures'/('run-'+str(i).zfill(2)+'-beauty.png')) as im:
  bg=Image.new('RGBA',im.size,(29,33,38,255));bg.alpha_composite(im);source_frames.append(bg.convert('RGB').resize((384,576),Image.Resampling.LANCZOS))
source_frames[0].save('outputs/hydrogen-v01-working-source-loop.gif',save_all=True,append_images=source_frames[1:],duration=[100,83,100,83,100,83,101],loop=0,optimize=False)
report={'status':'NATIVE_GRAPHICS_LOAD_CAP_JOIN_FROZEN_SOURCE_POSE_REVIEW_PASS','scope':'Actual target idle plus forced working-display clone and seven fixed source-frame variants; exact same native nonvisual prototype fields, no propellant/thrust/behavior tests. Sequential cold-thruster screenshot differences are not accepted as proof of working-clock progression.','binding':binding,'graphics':graphics,'receipts':receipts,'native_png_sha256':images,'native_frozen_blue_liner_roi':[270,730,530,830],'native_frozen_source_pose_count':7,'native_frozen_blue_roi_means':blue_means,'native_working_clock_cycle_proven':False,'source_working_clip_preview':'Seven actual Blender source captures; source indices 0 and 6 intentionally match. The GIF is labeled as a source render, not an engine propulsion cycle.','viewed_preview_board':'native-review-board.png','manual_visual_review':'Pending viewing final board, frozen-pose board and night image.'}
(model/'native-review-validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print('NATIVE_GRAPHICS_PASS',len(images),'PNGS',len(set(roi_hashes)),'BLUE_ROI_POSES')
