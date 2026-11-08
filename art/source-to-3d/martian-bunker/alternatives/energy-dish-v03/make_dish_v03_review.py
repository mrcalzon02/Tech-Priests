from PIL import Image,ImageDraw,ImageFont,ImageChops,ImageStat
import pathlib,json,hashlib,argparse
p=argparse.ArgumentParser();p.add_argument('--output',type=pathlib.Path,default=pathlib.Path('work/energy-dish-v03'));p.add_argument('--preview-dir',type=pathlib.Path,default=pathlib.Path('outputs'));a=p.parse_args();O=a.output;a.preview_dir.mkdir(parents=True,exist_ok=True);W=400;H=434;board=Image.new('RGB',(4*W,2*H+44),(36,40,45));draw=ImageDraw.Draw(board)
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18);draw.text((12,10),'Energy dish V03 — actual local source / native / imported GLB review',font=font,fill='white')
items=[('source-front','V02 source / front'),('native-front','V03 native / front'),('glb-front','V03 reimported GLB / front'),('glb-clay','GLB diagnostic clay'),('source-rear','V02 source / rear'),('native-rear','V03 native / rear'),('glb-rear','V03 reimported GLB / rear'),('native-256-review','V03 256px review (not game capture)')]
for j,(name,label) in enumerate(items):
 with Image.open(O/(name+'.png')) as im:
  im.load();assert im.mode=='RGBA';alpha=im.getchannel('A').getbbox();assert alpha and alpha[0]>0 and alpha[1]>0 and alpha[2]<im.width and alpha[3]<im.height
  bg=Image.new('RGBA',im.size,(36,40,45,255));bg.alpha_composite(im)
  if name=='native-256-review':tile=Image.new('RGB',(W,W),(36,40,45));tile.paste(bg.convert('RGB'),((W-256)//2,(W-256)//2))
  else:tile=bg.convert('RGB').resize((W,W),Image.Resampling.LANCZOS)
 board.paste(tile,((j%4)*W,44+(j//4)*H));draw.text(((j%4)*W+10,44+(j//4)*H+402),label,font=font,fill='white')
board.save(O/'local-proof.png');board.save(a.preview_dir/'energy-dish-v03-local-proof.png')
comparisons=[]
for view in ('front','rear'):
 with Image.open(O/('native-'+view+'.png')) as native,Image.open(O/('glb-'+view+'.png')) as glb:
  diff=ImageChops.difference(native,glb);extrema=diff.getextrema();comparisons.append({'view':view,'maximum_rgba_delta':[v[1] for v in extrema],'mean_rgba_delta':ImageStat.Stat(diff).mean,'alpha_identical':ImageChops.difference(native.getchannel('A'),glb.getchannel('A')).getbbox() is None})
(O/'render-comparison.json').write_text(json.dumps(comparisons,indent=2)+'\n');print(json.dumps(comparisons))
