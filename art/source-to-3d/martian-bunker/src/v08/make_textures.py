"""Reproducible, original, weathered PBR atlas for the Martian bunker v0.8.

The three supplied tabletop-model images are HARD visual finish references only.
No source image pixels, original textures or proprietary decals are copied.
Generates 23 material sets (512px tileable albedo / packed ORM / tangent normal).
Depth variation is represented by true roughness/metalness and normal mapping,
not just bright painted grain. All random sources are deterministic and wrap.
"""
from pathlib import Path
import hashlib, json, math
import numpy as np
from scipy.ndimage import gaussian_filter, binary_dilation
from PIL import Image, ImageDraw
from build_blockout import COL

OUT=Path(__file__).resolve().parent/'textures'
OUT.mkdir(parents=True,exist_ok=True)
N=512

def noise(rng,sigma):
    n=rng.standard_normal((N,N)).astype(np.float32)
    a=gaussian_filter(n,sigma=sigma,mode='wrap')
    return a/(np.std(a)+1e-8)

def scratches(rng,count,maxlen=22):
    # Repeated at seams so no one-sided scratch stops at a tile boundary.
    im=Image.new('L',(N,N),0);dr=ImageDraw.Draw(im)
    for _ in range(count):
        x=int(rng.integers(0,N));y=int(rng.integers(0,N))
        l=int(rng.integers(2,maxlen));deg=float(rng.choice([0,10,80,90,100,170]))
        ang=math.radians(deg+float(rng.normal(0,5)))
        dx=int(round(math.cos(ang)*l));dy=int(round(math.sin(ang)*l))
        width=int(rng.choice([1,1,1,2]))
        for ox in (-N,0,N):
            for oy in (-N,0,N):
                dr.line([(x+ox,y+oy),(x+dx+ox,y+dy+oy)],fill=255,width=width)
    return np.asarray(im,dtype=np.float32)/255.0

def clamp(a):return np.clip(a,0.0,1.0)

meta={}
for key,hx in COL.items():
    seed=int.from_bytes(hashlib.sha256(('v08|'+key).encode()).digest()[:8],'big')
    rng=np.random.default_rng(seed)
    rgb=np.array([int(hx[k:k+2],16)/255 for k in (1,3,5)],dtype=np.float32)
    coarse=noise(rng,26)
    medium=noise(rng,7)
    grain=noise(rng,1.3)
    fine=noise(rng,.55)
    patina=noise(rng,(22,2.1)) # long streaks of oil, ash and industrial dust
    arr=np.broadcast_to(rgb,(N,N,3)).copy()
    rou=np.full((N,N),.56,dtype=np.float32)
    metal=np.full((N,N),.06,dtype=np.float32)
    height=.005*medium+.003*fine
    family='ceramic_and_fittings'
    worn=0
    if key.startswith('ferrocrete'):
        family='weathered_ferrocrete'
        dust=clamp((coarse+.6*medium+.4)/3.7)
        arr*= (.94+.045*coarse+.040*grain)[...,None]
        arr=arr*(1-.30*dust[...,None])+np.array([.44,.26,.19])[None,None,:]*(.30*dust[...,None])
        tiny=(grain>1.75)&(medium<.75)
        arr[tiny]*=.70
        rou=clamp(.83+.055*grain+.020*medium).astype(np.float32)
        height=.022*grain+.012*fine+.015*medium-.020*tiny.astype(np.float32)
    elif key in ('martian_red','red_highlight','red_dark','oxide_red'):
        family='battleworn_martian_red_paint'
        sc=scratches(rng,430,21)
        # Correlated chips in islands, rather than evenly scattered noise.
        islands=(grain>1.56)&(medium>.28)&(coarse>-.55)
        fragments=(fine>1.95)&(medium>.25)
        chips=islands|fragments|(sc>.25)
        chip_edges=binary_dilation(chips,iterations=1)
        exposed=chips&((fine>.0)|(sc>.25))
        dust=clamp(.11+.12*coarse+.095*patina+.07*medium)
        grime=clamp(.15+.19*patina+.12*medium)
        arr *= (.92+.05*coarse+.024*fine)[...,None]
        arr=arr*(1-.42*dust[...,None])+np.array([.50,.27,.16])[None,None,:]*(.42*dust[...,None])
        arr=arr*(1-.14*grime[...,None])
        # Bright exposed steel is rare; most paint chips show dark blackened primer.
        arr[chip_edges&~chips]=arr[chip_edges&~chips]*.70
        arr[chips]=np.array([.115,.115,.115])
        arr[exposed]=np.array([.36,.365,.345])*(.83+.16*rng.random((int(exposed.sum()),1)))
        rou=clamp(.64+.048*medium+.042*grain+.035*patina)
        metal[:]=.11
        rou[chips]=.35;metal[chips]=.79
        height=.006*fine+.007*medium+.0025*coarse-.017*chips.astype(np.float32)
        worn=float(chips.mean())
    elif key in ('gunmetal_dark','machine_steel','machined_bright','iron','heat_blues'):
        family='turned_gunmetal_steel'
        sc=scratches(rng,140,20)
        rows=np.linspace(0,2*math.pi,N,endpoint=False,dtype=np.float32)
        # Fine longitudinal tool marks and circumferential machining on the
        # circular jacket via explicit cylindrical unwrap in setup_blender.py.
        mill=(.60*np.sin(rows*28)+.24*np.sin(rows*82))[None,:]
        dust=clamp((coarse+.42*patina-.1)/3.0)
        arr*= (.95+.055*coarse+.026*grain+.015*mill-.10*sc)[...,None]
        arr=arr*(1-.15*dust[...,None])+np.array([.30,.23,.17])[None,None,:]*(.15*dust[...,None])
        if key=='heat_blues':
            family='heat_tempered_crown_steel'
            bands=(np.sin(rows*3.1+medium*.25)+1)/2
            bands=np.broadcast_to(bands,(N,N))
            arr[:,:,2]=clamp(arr[:,:,2]+.10*bands)
            arr[:,:,0]=clamp(arr[:,:,0]+.055*(1-bands))
        rou=clamp(.39+.040*grain+.033*coarse+.045*sc)
        metal[:]=.86
        height=.0048*grain+.0035*mill-.005*sc
        worn=float(sc.mean())
    elif key=='brass':
        family='oiled_machined_brass'
        sc=scratches(rng,160,18)
        arr*=(.96+.046*coarse+.017*fine-.11*sc)[...,None]
        rou=clamp(.38+.032*medium+.018*grain)
        metal[:]=.88
        height=.006*grain+.003*medium-.004*sc
    elif key=='glass':
        family='coated_sensor_optics'
        arr*=(.95+.011*coarse)[...,None]
        rou=clamp(.13+.013*fine)
        metal[:]=.03
        height=.0007*fine
    elif key in ('dark_recess','bore_shadow','grease'):
        family='oiled_dark_recess'
        arr*=(.94+.038*coarse+.017*fine)[...,None]
        rou=clamp(.78+.04*grain)
        height=.005*grain
    else:
        arr*=(.95+.040*coarse+.022*fine)[...,None]
        rou=clamp(.67+.044*grain)
        height=.006*grain+.004*medium
    albedo=np.uint8(np.rint(clamp(arr)*255))
    orm=np.empty((N,N,3),dtype=np.uint8)
    orm[:,:,0]=255 # no pre-baked AO: Blender gives truthful shadowing
    orm[:,:,1]=np.uint8(np.rint(clamp(rou)*255))
    orm[:,:,2]=np.uint8(np.rint(clamp(metal)*255))
    gx=np.roll(height,-1,axis=1)-np.roll(height,1,axis=1)
    gy=np.roll(height,-1,axis=0)-np.roll(height,1,axis=0)
    normal=np.stack((-3.1*gx,-3.1*gy,np.ones_like(gx)),axis=-1)
    normal/=np.maximum(np.linalg.norm(normal,axis=2,keepdims=True),1e-8)
    norm=np.uint8(np.rint(clamp(.5+.5*normal)*255))
    paths={}
    for suffix,data in (('albedo',albedo),('orm',orm),('normal',norm)):
        fn=f'{key}_{suffix}.png'
        Image.fromarray(data,'RGB').save(OUT/fn,compress_level=1)
        paths[suffix]=f'textures/{fn}'
    print('FINISHED_MATERIAL',key,flush=True)
    meta[key]={'family':family,'texture_files':paths,
               'uv_repeat_per_tile_unit':1.25,'source_color_hex':hx,
               'chipped_area_fraction':round(worn,4)}
(OUT/'texture_manifest.json').write_text(json.dumps({
    'generator':'make_textures.py','version':'v0.8 owner-targeted edge chipping, oxide dust and dark metal',
    'dimension':[N,N],'source':'Original deterministic synthetic weathering; no photo or AI-generated texture pixels',
    'materials':meta},indent=2)+'\n',encoding='utf-8')
print('BUILT_ORIGINAL_V08_TEXTURES',len(meta),'material types,',len(list(OUT.glob('*.png'))),'maps')
