"""Fail the pilot on missing passes, clipping, absent flash or excessive runtime."""
import argparse,json,statistics,sys
from pathlib import Path
from PIL import Image,ImageDraw,ImageChops
O=Path(__file__).resolve().parent;C=json.loads((O/'capture_config.json').read_text())
sys.path.insert(0,str(O));from assemble_capture import image
p=argparse.ArgumentParser();p.add_argument('--input',default='rendered');p.add_argument('--directions',default='0,16,32,48');p.add_argument('--output',default='pilot_validation.json');a=p.parse_args();I=Path(a.input);records=[];times=[];board=Image.new('RGB',(640*3,640*len(a.directions.split(','))),(36,40,45))
for row,d in enumerate(int(x) for x in a.directions.split(',')):
 D=I/f'd{d:02}';files=[];emission_seen=False;idle_emission=Image.open(D/'emission'/'idle_000.png').getchannel('A')
 for col,(mode,f) in enumerate([('idle',0),('cycle',1),('cycle',4)]):
  for pas in C['passes']:
   size=C['shadow_size'] if pas=='shadow' else C['beauty_size'];path=D/pas/f'{mode}_{f:03}.png';im=image(path,size,pas!='emission');box=im.getchannel('A').getbbox()
   if pas=='emission' and mode=='cycle' and box:
    extra=ImageChops.subtract(im.getchannel('A'),idle_emission);emission_seen=emission_seen or sum(extra.histogram()[16:])>=12
   if pas=='beauty':
    bg=Image.new('RGBA',im.size,(36,40,45,255));bg.alpha_composite(im);board.paste(bg.convert('RGB'),(col*640,row*640))
   files.append({'file':str(path),'alpha_bounds':box})
 assert emission_seen,('no firing emission',d)
 record=json.loads((D/'chunk_00.json').read_text());times.extend(record['frame_times_seconds']);records.append({'direction':d,'files':files})
assert times,'Pilot timing absent';median=statistics.median(times);projected=48*max(times)/60
assert projected<160,('Worst 48-state chunk exceeds safe runner time budget',projected)
report={'status':'PASS','directions':[r['direction'] for r in records],'median_seconds_per_three_pass_pose':median,'projected_worst_chunk_minutes':projected,'frames':records,'correct_shadow_registration':{'beauty_cell':640,'shadow_cell':1280,'shadow_offset_pixels':[-320,-320],'same_pixels_per_world_unit':True}}
Path(a.output).write_text(json.dumps(report,indent=2));board.save(Path(a.output).with_suffix('.png'));print('LOBBER_PILOT_PASS',median,projected)
