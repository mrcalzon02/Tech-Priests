"""Model-specific axial heat, lip char and fuel/exhaust textures for V03."""
import argparse,pathlib,json,hashlib,math
import numpy as np
from PIL import Image,ImageFilter,ImageDraw,ImageFont
p=argparse.ArgumentParser();p.add_argument('--out',type=pathlib.Path,required=True);a=p.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);n=1024;rng=np.random.default_rng(90317);y,x=np.mgrid[0:n,0:n]/(n-1)
def noise(k):return np.asarray(Image.fromarray((rng.random((k,k))*255).astype('uint8')).resize((n,n),Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(1))).astype(float)/255
coarse=noise(48);fine=noise(384);records=[]
def write(name,array):
 path=out/(name+'.png');Image.fromarray(np.clip(array*255,0,255).astype('uint8')).save(path);records.append({'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
# V=0 throat, V=1 hot lip; U follows the actual twelve manufactured petals.
v=1-y;seam=np.exp(-(np.minimum((x*12)%1,1-(x*12)%1)/.065)**2)
char=np.clip((v-.77)*5+(coarse-.5)*.75,0,1);temper=np.exp(-((v-.69)/.16)**2)
base=np.zeros((n,n,3))+np.array([.25,.23,.19]);base*=.90+.20*coarse[:,:,None];base+=temper[:,:,None]*np.array([.09,-.01,.12]);base*=1-.77*char[:,:,None];base+=seam[:,:,None]*np.array([.09,.07,.04])*(1-.7*char[:,:,None]);base+=((fine-.5)*.025)[:,:,None]
rough=.47+.31*char+.12*(coarse-.5)-.08*seam
height=.035*coarse+.009*fine+.025*seam;dx=np.roll(height,-1,1)-np.roll(height,1,1);dy=np.roll(height,-1,0)-np.roll(height,1,0);normal=np.stack((-dx*5,-dy*5,np.ones_like(dx)),axis=-1);normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
heat=np.clip((v-.52)/.48,0,1)**2*(.65+.35*coarse);emit=heat[:,:,None]*np.array([1,.23,.028])
for family,bc,metal,rr,em in [('petal',base,.9,rough,emit),('refractory',base*np.array([.55,.45,.40]),.18,np.clip(rough+.15,0,1),emit*1.8)]:
 write(family+'-basecolor',bc);write(family+'-metalrough',np.stack((np.ones_like(x),rr,np.full_like(x,metal)),axis=-1));write(family+'-normal',normal*.5+.5);write(family+'-emission',em)
# Authored spatial exhaust texture: near-nozzle density, trailing falloff and
# circumferential variation. Animation is geometry/rig driven, not a fake GIF.
t=1-y;grain=.7+.3*coarse;fade=(1-t)**1.3*np.clip(t/.045,0,1);bands=.77+.23*np.cos(t*math.tau*4+x*math.tau*2)
rgba=np.empty((n,n,4));rgba[:,:,:3]=np.array([.62,.15,1.0])*(.72+.28*bands[:,:,None]);rgba[:,:,3]=.78*fade*grain;write('exhaust-envelope',rgba)
rgba[:,:,:3]=np.array([.58,.81,1.0]);rgba[:,:,3]=.88*(1-t)**.65*np.clip(t/.025,0,1);write('exhaust-core',rgba)
im=Image.new('RGB',(512,512),(196,187,155));d=ImageDraw.Draw(im);font=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',42);small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',24)
for tick in range(41):
 angle=math.radians(150+tick*6);r0=191 if tick%5==0 else 201;r1=223;color=(145,29,21) if tick>31 else (40,42,38);d.line((256+math.cos(angle)*r0,256+math.sin(angle)*r0,256+math.cos(angle)*r1,256+math.sin(angle)*r1),fill=color,width=5 if tick%5==0 else 3)
d.text((215,275),'HP',font=font,fill=(38,39,33));d.text((140,333),'CONTAINMENT',font=small,fill=(48,48,40));path=out/'pressure-gauge.png';im.save(path);records.append({'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(out/'manifest.json').write_text(json.dumps({'status':'AUTHORED_V03_REGION_MAPS','uv_contract':'Petal/refractory U circumferential, V axial throat0/lip1. Temper at V~.69, char from V~.77, heat emission toward lip; glass fuel color derives from native Thetazine fluid.','files':records},indent=2)+'\n',encoding='utf-8',newline='\n');print('V03_TEXTURES',len(records))
