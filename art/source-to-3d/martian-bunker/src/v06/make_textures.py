"""Original, reproducible tileable PBR images for the Factorio-size bunker.

No texture downloads, no Wube assets, no procedural AI raster guessing. Colors
come from build_blockout.COL; the reference image is used only as style guidance.
512^2 albedo (sRGB), ORM (occlusion=255, roughness=G, metalness=B), tangent
normal texture (+Z), per named material. The atlas wraps at both edges.
"""
from pathlib import Path
import hashlib, json, math
import numpy as np
from scipy.ndimage import gaussian_filter
from PIL import Image, ImageDraw
from build_blockout import COL

OUT=Path(__file__).resolve().parent/'textures'
OUT.mkdir(parents=True,exist_ok=True)
N=384

def rand_noise(rng,scale=14):
    a=rng.standard_normal((N,N),dtype=np.float32)
    b=gaussian_filter(a,sigma=scale,mode='wrap')
    return b/(float(np.std(b))+1e-8)

def clamp(v):return np.clip(v,0,1)

meta={}
for key,hx in COL.items():
    seed=int.from_bytes(hashlib.sha256(key.encode()).digest()[:8],'big')
    rng=np.random.default_rng(seed)
    rgb=np.array([int(hx[i:i+2],16)/255 for i in (1,3,5)],dtype=np.float32)
    coarse=rand_noise(rng,22)
    fine=rand_noise(rng,1.0)
    grain=rand_noise(rng,3.1)
    arr=np.broadcast_to(rgb,(N,N,3)).copy()
    rou=np.full((N,N),.56,dtype=np.float32)
    ht=.003*fine+.008*grain
    metal=.1
    family='misc'
    if key.startswith('ferrocrete'):
        family='ferrocrete'; metal=.0
        arr *= (.91+.065*coarse+.036*fine)[...,None]
        tiny=rng.random((N,N))<.009
        arr[tiny]*=.72
        rou=(.82+.06*grain+.035*fine).astype(np.float32)
        ht=.023*grain+.015*fine+.018*coarse
    elif 'red' in key or key in ('oxide_red',):
        family='painted_armor'; metal=.18
        arr*= (.96+.046*coarse+.025*fine)[...,None]
        scratches=rng.random((N,N))<.0023
        # small directional nicks: preserve most of the painted surfaces
        chips=np.zeros((N,N),bool)
        chips|=scratches; chips|=np.roll(scratches,1,axis=1)
        chips|=np.roll(scratches,2,axis=1)
        arr[chips]=np.array([.34,.35,.34],dtype=np.float32)
        rou=(.64+.04*grain+.035*coarse).astype(np.float32)
        rou[chips]=.37
        ht=.008*fine+.007*grain+.005*coarse
    elif key in ('heat_blues','gunmetal_dark','machine_steel','machined_bright','iron'):
        family='machined_steel'; metal=.84
        y=np.linspace(0,2*math.pi,N,endpoint=False,dtype=np.float32)
        machining=(np.sin(y*12)+.3*np.sin(y*40))[None,:]
        arr*=(.965+.045*coarse+.015*machining+.015*fine)[...,None]
        if key=='heat_blues':
            family='heat_tempered_steel'
            arr[:,:,0]*=1+.09*coarse
            arr[:,:,2]*=1+.055*(1-coarse)
        rou=(.39+.045*grain+.03*coarse+.014*machining).astype(np.float32)
        ht=.009*grain+.006*fine+.004*machining
    elif key=='brass':
        family='machined_brass';metal=.92
        arr*= (.97+.045*coarse+.022*fine)[...,None]
        rou=(.36+.032*coarse+.022*grain).astype(np.float32)
        ht=.009*grain+.006*fine
    elif key=='glass':
        family='optical_glass';metal=.1
        arr*=(.97+.012*coarse)[...,None]
        rou=(.15+.012*fine).astype(np.float32);ht=.001*fine
    elif key in ('dark_recess','bore_shadow','grease'):
        family='rubber_and_dark_bores';metal=.05
        arr*=(.98+.02*coarse)[...,None]
        rou=(.82+.04*grain).astype(np.float32);ht=.013*grain
    else:
        family='ceramic_and_fittings';metal=.06
        arr*= (.96+.035*grain+.02*fine)[...,None]
        rou=(.69+.04*grain).astype(np.float32)
        ht=.008*grain
    albedo=np.uint8(np.round(clamp(arr)*255))
    orm=np.empty((N,N,3),dtype=np.uint8)
    orm[:,:,0]=255 # no fake baked AO (physical contact shadows come from render)
    orm[:,:,1]=np.uint8(np.round(clamp(rou)*255))
    orm[:,:,2]=int(round(metal*255))
    hxgrad=np.roll(ht,-1,axis=1)-np.roll(ht,1,axis=1)
    hygrad=np.roll(ht,-1,axis=0)-np.roll(ht,1,axis=0)
    bump=np.stack((-3.2*hxgrad, -3.2*hygrad, np.ones_like(ht)),axis=-1)
    bump/=np.maximum(np.linalg.norm(bump,axis=2,keepdims=True),1e-6)
    norm=np.uint8(np.round(clamp(.5+.5*bump)*255))
    paths={}
    for suffix,data in [('albedo',albedo),('orm',orm),('normal',norm)]:
        fn=f'{key}_{suffix}.png'
        Image.fromarray(data,'RGB').save(OUT/fn,optimize=True)
        paths[suffix]=f'textures/{fn}'
    meta[key]={'family':family,'texture_files':paths,'metallic':metal,'uv_repeat_per_tile_unit':1.25,
              'source_color_hex':hx}
(OUT/'texture_manifest.json').write_text(json.dumps({'generator':'make_textures.py','dimension':[N,N],
 'source':'Original deterministic generated tiles (not third-party source images)',
 'materials':meta},indent=2)+'\n',encoding='utf-8')
print('BUILT_ORIGINAL_TEXTURES',len(meta),'materials',len(list(OUT.glob('*.png'))),'maps')
