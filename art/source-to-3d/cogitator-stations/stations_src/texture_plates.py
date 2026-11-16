"""Generate seamless color plates for both the Blender materials and glTF."""
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter
from finishes import FINISHES

def make(directory):
    out=Path(directory)
    out.mkdir(parents=True,exist_ok=True)
    for i,(key,(profile,label,rgb,metal,rough)) in enumerate(FINISHES.items()):
        rng=np.random.default_rng(514+i)
        shape=(384,384)
        def field(scale):
            a=gaussian_filter(rng.normal(size=shape),scale,mode='wrap')
            return (a-a.mean())/max(a.std(),.000001)
        macro, grain, speckle=field(12),field(2.4),field(.42)
        is_cast=key in ('iron','steel','gunmetal','dark','bronze','brass','gold','copper','rust','oxide')
        strength=1.0 if is_cast else .27
        pigment=1+strength*(.059*macro+.045*grain+.031*speckle)
        pixels=np.array(rgb)*pigment[...,None]
        if is_cast:
            bloom=np.clip((field(6)+.64*grain-1.1)*.25,0,.55)
            patina=(77,80,62) if key in ('bronze','brass','gold','copper') else (86,57,42)
            pixels=pixels*(1-bloom[...,None])+np.array(patina)*bloom[...,None]
            pits=np.clip((speckle-1.3)*.15,0,.32)
            pixels*=1-pits[...,None]
            # Abrasion follows the direction of machining; masks keep it local.
            lines=field((.46,8))
            scratch=np.clip((lines-2.15)*.45,0,.32)*np.clip((macro+1),0,1)
            pixels=pixels*(1-scratch[...,None])+np.array((194,183,157))*scratch[...,None]
        Image.fromarray(np.uint8(np.clip(pixels,0,255))).save(out/(key+'.png'))
        # glTF's standard channel packing. The red channel is neutral.
        material=np.zeros((*shape,3),dtype=np.uint8)
        material[...,0]=255
        material[...,1]=np.uint8(np.clip(rough+.028*grain+.023*macro+.016*speckle,.08,.96)*255)
        material[...,2]=round(metal*255)
        Image.fromarray(material).resize((192,192),Image.Resampling.BOX).save(out/(key+'-orm.png'))
        if key in ('iron','ceramic','rubber'):
            height=grain*.26+speckle*.085+macro*.9
            factor={'iron':.30,'ceramic':.052,'rubber':.16}[key]
            dhx=(np.roll(height,1,axis=1)-np.roll(height,-1,axis=1))*factor
            dhy=(np.roll(height,-1,axis=0)-np.roll(height,1,axis=0))*factor
            normal=np.stack((dhx,dhy,np.ones(shape)),axis=-1)
            normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
            Image.fromarray(np.uint8((normal*.5+.5)*255)).save(out/(key+'-normal.png'))
if __name__=='__main__':
    import sys
    make(sys.argv[1])
