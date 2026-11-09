"""Read actual native body/light clocks and make compact visual evidence."""
import argparse,pathlib,json,hashlib
import numpy as np
from PIL import Image,ImageDraw
p=argparse.ArgumentParser();p.add_argument('--study',type=pathlib.Path,required=True);p.add_argument('--profile',type=pathlib.Path,required=True);p.add_argument('--out',type=pathlib.Path,required=True);a=p.parse_args();src=a.profile/'userdata/script-output/thetazine-v04-native';a.out.mkdir(exist_ok=True,parents=True);sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();m=json.loads((a.study/'source-manifest.json').read_text());prep=json.loads((a.profile/'v04-preparation-receipt.json').read_text());assert prep['native_sha256']==m['native_sha256']
rows=[];frames=[]
for f in sorted((src/'body-loop').glob('*.png'),key=lambda p:int(p.stem.split('-')[-1])):
 im=Image.open(f).convert('RGB');v=np.asarray(im);clocks=[];levels=[]
 for start in [197,773]:
  bits=[float(v[244:249,start+6*b-1:start+6*b+2,:].mean()) for b in range(6)];levels.append(bits);clocks.append(sum((1<<b) for b,l in enumerate(bits) if l>128))
 rows.append({'file':f.name,'sha256':sha(f),'body':clocks[0],'light':clocks[1],'bit_levels':levels});frames.append(im.crop((130,160,870,1660)).resize((444,900),Image.Resampling.LANCZOS))
assert len(rows)==64
same=all(r['body']==r['light'] for r in rows);bodyunique=len({r['body'] for r in rows});lightunique=len({r['light'] for r in rows});assert same and bodyunique==lightunique==64,(same,bodyunique,lightunique)
frames[0].save(a.out/'thetazine-v04-fixed-mount-native-loop.gif',save_all=True,append_images=frames[1:],duration=[30,30,40]*21+[30],loop=0,optimize=False)
pan=Image.new('RGB',(1000,450),(15,18,21));d=ImageDraw.Draw(pan)
for i,label in enumerate(['balanced','fuel-heavy','water-heavy','night']):
 f=sorted((src/label).glob('*.png'))[0];im=Image.open(f).convert('RGB');im.thumbnail((250,860));pan.paste(im,(i*250,30));d.text((i*250+8,8),label,fill='white')
pan.save(a.out/'thetazine-v04-native-fuel-light.png')
sh=Image.open(src/'body-loop/frame-180.png').convert('RGB');sh.crop((280,710,720,1260)).save(a.out/'thetazine-v04-native-bell-mouth.png')
receipt=json.loads((src/'receipt.json').read_text());assert receipt['source_native_sha256']==m['native_sha256'];assert len(receipt['ports'])==2 and all(p['connected']=='pipe' for p in receipt['ports'])
mod=a.profile/'mods/model-visual-review_0.1.0'
assert sha(mod/'data-final-fixes.lua')==prep['data_sha256'] and sha(mod/'scenarios/model-placement/control.lua')==prep['control_sha256']
for row in prep['graphics_files']:assert sha(mod/'graphics/thetazine-v04'/row['file'])==row['sha256']
result={'status':'PASS_NATIVE_64_BODY_AND_LIGHT_CLOCKS_CONNECTED_PORTS_VISUAL_REVIEW_REQUIRED','native_sha256':m['native_sha256'],'preparation_sha256':sha(a.profile/'v04-preparation-receipt.json'),'clock_frames':rows,'body_unique':bodyunique,'light_unique':lightunique,'all_clocks_equal':same,'native_receipt':receipt,'external_flame_y_adjust':prep['flame_y_adjust'],'scope':'Actual isolated graphical client capture and independently decoded body/light clocks. Visual flame join, occlusion and finish require actual image review; no gameplay/performance assertions.'}
(a.study/'native-visual-validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n');print(result['status'],bodyunique,lightunique)
