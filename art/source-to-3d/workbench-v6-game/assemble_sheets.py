from pathlib import Path
from PIL import Image
import json,hashlib,sys,argparse
p=argparse.ArgumentParser();p.add_argument('--export',required=True);p.add_argument('--asset-dir',required=True);a=p.parse_args();R=Path(a.export).resolve();out=Path(a.asset_dir).resolve();out.mkdir(parents=True,exist_ok=True)
for d in ['north','east','south','west']:
 files=[R/'frames'/d/f'{f:04d}.png' for f in range(1,193,2)];assert len(files)==96 and all(f.exists() for f in files)
 sheet=Image.new('RGBA',(1536,1024));bounds=[]
 for i,f in enumerate(files):
  im=Image.open(f).convert('RGBA');assert im.size==(128,128);assert im.getchannel('A').getextrema()[0]==0,'Opaque background';assert im.getbbox(),'Empty render';strong=im.getchannel('A').point(lambda a:255 if a>150 else 0).getbbox();assert strong and strong[0]>0 and strong[1]>0 and strong[2]<128 and strong[3]<128,('Clipped geometry',d,f,strong);sheet.paste(im,(i%12*128,i//12*128));bounds.append(im.getbbox())
 sheet.save(out/f'working-{d}.png',optimize=True)
 Image.open(files[0]).save(out/f'idle-{d}.png')
 if d=='north':Image.open(files[0]).resize((64,64),Image.Resampling.LANCZOS).save(out/'icon.png')
 print(d, '96 RGBA frames',len(set(Image.open(f).tobytes() for f in files)), 'distinct')
manifest=json.loads((R/'registration.json').read_text()) if (R/'registration.json').exists() else {}; manifest['files']={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(out.glob('*.png'))};(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
