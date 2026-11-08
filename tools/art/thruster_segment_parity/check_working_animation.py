import argparse,pathlib,json,hashlib,re,shutil
import numpy as np
from PIL import Image,ImageDraw,ImageFont
p=argparse.ArgumentParser();p.add_argument('--study',type=pathlib.Path,required=True);p.add_argument('--review-root',type=pathlib.Path,required=True);p.add_argument('--deliverables',type=pathlib.Path);a=p.parse_args()
w=pathlib.Path(__file__).resolve().parent;profile=a.review_root.resolve();r=profile/'userdata/script-output/thetazine-v02-native-working-loop';study=a.study.resolve();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();rows=[];frames=[]
for path in sorted(r.glob('frame-*.png')):
 with Image.open(path) as im:im.verify()
 with Image.open(path) as im:im.load();assert im.size==(900,1100);rgb=im.convert('RGB')
 samples=[rgb.getpixel((166+6*bit,204))[0] for bit in range(6)];assert all(v<40 or v>200 for v in samples),(path.name,samples)
 value=sum((1<<bit) if v>160 else 0 for bit,v in enumerate(samples));rows.append({'file':path.name,'sha256':sha(path),'body_atlas_index':value,'blender_source_frame':value+1,'frame_counter_samples':samples});frames.append(rgb)
assert len(rows)==64 and len({v['body_atlas_index'] for v in rows})==64
assert all(rows[i+1]['body_atlas_index']==(rows[i]['body_atlas_index']+1)%64 for i in range(63))
receipt=json.loads((r/'receipt.json').read_text(encoding='utf-8'));assert len(receipt['ports'])==2
for p in receipt['ports']:assert p['connected']=='pipe' and p['connected_position']==p['target_position']
log=(profile/'userdata/factorio-current.log').read_text(encoding='utf-8');assert re.search(r'Graphics options: \[Graphics quality: high\]',log)
graph=json.loads(next(line.split('THETAZINE_V02_NATIVE_JSON ',1)[1] for line in log.splitlines() if 'THETAZINE_V02_NATIVE_JSON ' in line));layers=graph['graphics']['animation']['north']['layers'];assert layers[0]['frame_count']==layers[1]['frame_count']==64 and layers[0]['animation_speed']==layers[1]['animation_speed']==.5
for frame in graph['graphics']['working_visualisations']:
 if frame.get('name')=='v02-preview-thermal-glow':assert frame['animation']['frame_count']==64 and frame['animation']['animation_speed']==.5
gif=[im.resize((450,550)) for im in frames];palette=gif[0].quantize(colors=256);gif=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in gif];durations=[round((i+1)*100/30)*10-round(i*100/30)*10 for i in range(64)];gif[0].save(study/'native-working-loop.gif',save_all=True,append_images=gif[1:],duration=durations,loop=0,optimize=False,disposal=2)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18);board=Image.new('RGB',(1440,930),(32,34,36));d=ImageDraw.Draw(board)
for index,source_index in enumerate([0,8,16,24,32,40,48,56]):
 native=next(i for i,row in enumerate(rows) if row['body_atlas_index']==source_index);im=frames[native].resize((360,440));x=index%4*360;y=index//4*465;board.paste(im,(x,y+25));d.text((x+8,y+3),f'Native body frame {source_index:02}',font=font,fill='white')
board.save(study/'native-working-keyposes.png')
result={'status':'PASS_ACTUAL_NATIVE_THRUSTER_WORKING_BODY_CLOCK_ALL_64_FRAMES','source_model_sha256':sha(study/'thetazine-animation-study.blend'),'source_glb_sha256':sha(study/'thetazine-animation-study.glb'),'body_clock_proven':True,'decoded_unique_body_indices':64,'sequential_modulo_64':True,'body_and_counter_same_animation_layer_timing':True,'native_pngs':rows,'source_atlas_sha256':{p.name:sha(p) for p in (study/'source-package').glob('*.png')},'native_prototype_graph':graph,'native_ports':receipt['ports'],'native_working_gif_sha256':sha(study/'native-working-loop.gif'),'native_keyposes_sha256':sha(study/'native-working-keyposes.png'),'native_glow_phase_independently_decoded':False,'source_shadow_or_flame_parity_accepted':False,'scope':'Review-only actual thruster prototype. Propellant and disposable route selected only to view active graphics; no consumption/thrust/behavior assertions. New model remains a refinement candidate, not installed into the normal profile or promoted to final game art. Temporary six-bit frame-counter layer is review-only.'}
(study/'native-working-validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
if a.deliverables:
 out=a.deliverables.resolve();out.mkdir(parents=True,exist_ok=True);shutil.copyfile(study/'native-working-loop.gif',out/'thetazine-v02-native-working-loop.gif');shutil.copyfile(study/'native-working-keyposes.png',out/'thetazine-v02-native-working-keyposes.png')
print('NATIVE_WORKING_BODY_64_FRAMES_PASS',rows[0]['body_atlas_index'],rows[-1]['body_atlas_index'])
