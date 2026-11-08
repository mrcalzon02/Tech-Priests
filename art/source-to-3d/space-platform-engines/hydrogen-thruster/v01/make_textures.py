import argparse,pathlib,json,hashlib
import numpy as np
from PIL import Image,ImageFilter
parser=argparse.ArgumentParser();parser.add_argument('--out',type=pathlib.Path,required=True);args=parser.parse_args();r=args.out.resolve();r.mkdir(parents=True,exist_ok=False);n=1024
rng=np.random.default_rng(220817)
def field(scale):
 a=rng.random((scale,scale));im=Image.fromarray((a*255).astype('uint8')).resize((n,n),Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(1));return np.asarray(im).astype('float64')/255-.5
coarse=field(32);fine=field(256);y,x=np.mgrid[0:n,0:n]/n
families={'cast':([80,77,65],.82,.68),'tank':([61,68,71],.88,.60),'brass':([126,106,59],.86,.49),'steel':([110,115,110],.92,.48),'bell':([78,70,56],.87,.62),'dark':([34,35,33],.76,.72)}
records=[]
for name,(base,metal,rough) in families.items():
 variation=1+.12*coarse+.045*fine
 color=np.array(base)[None,None,:]*variation[:,:,None]
 if name=='tank':color+=np.sin(x[:,:,None]*np.pi*2*160)*.8
 if name=='bell':
  # U follows circumference, V travels from throat to the rolled hot lip.
  heat=np.exp(-((y-.50)/.08)**2);edge=np.exp(-(np.minimum((x*12)%1,1-(x*12)%1)/.055)**2);color*=1-.22*heat[:,:,None];color+=heat[:,:,None]*np.array([3,-2,7])+edge[:,:,None]*np.array([15,13,9]);color*=1+.10*coarse[:,:,None];roughness=rough+.11*heat-.08*edge+.075*coarse
 else:roughness=rough+.075*coarse+.025*fine
 height=.45*coarse+.08*fine;dx=(np.roll(height,-1,axis=1)-np.roll(height,1,axis=1))*.65;dy=(np.roll(height,-1,axis=0)-np.roll(height,1,axis=0))*.65
 normals=np.stack((-dx,-dy,np.ones_like(dx)),axis=-1);normals/=np.linalg.norm(normals,axis=-1,keepdims=True)
 channels={'basecolor':np.clip(color,0,255).astype('uint8'),'metalrough':np.stack((np.ones((n,n)),np.clip(roughness,0,1),np.full((n,n),metal)),axis=-1),'normal':normals*.5+.5}
 for channel,a in channels.items():
  if channel!='basecolor':a=np.clip(a*255,0,255).astype('uint8')
  p=r/(name+'-'+channel+'.png');Image.fromarray(a,'RGB').save(p);records.append({'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'channel':channel,'region':name,'size':[n,n]})
(r/'manifest.json').write_text(json.dumps({'scope':'Asset-specific cast-metal/tank/brass/steel/bell/dark PBR tiles; UV direction and bell axial heat band follow their named construction regions. Subtle finish only; edges, bands and seams are geometry.','files':records},indent=2)+'\n',encoding='utf-8')
print('TEXTURES',len(records))
