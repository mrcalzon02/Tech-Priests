"""Trim transparent margins, retaining the exact FMPL ground-pivot registration."""
from pathlib import Path
import json, math, os, sys
import numpy as np
from PIL import Image
from fmpl_adapter import NAMES,ANGLE_FOR_HEADING,HR_SIZES,profile,registration

def cell_images(sheet,z,moving):
    for i in range(16 if moving else 1):
        x,y=(i%4)*z,(i//4)*z
        yield sheet.crop((x,y,x+z,y+z))

def occupied(sheet,z,moving):
    boxes=[cell.getchannel('A').getbbox() for cell in cell_images(sheet,z,moving)]
    b=[v for v in boxes if v]
    if not b:raise ValueError('A sprite layer is completely empty')
    return min(v[0] for v in b),min(v[1] for v in b),max(v[2] for v in b),max(v[3] for v in b)

def lua(value):
    if isinstance(value,dict):
        return '{'+',\n'.join('["'+k+'"]='+lua(v) for k,v in value.items())+'}'
    if isinstance(value,list):return '{'+','.join(lua(v) for v in value)+'}'
    return str(value)

def trim(root):
    mod=root/'Factorio/mars-reactor-visuals_1.0.0'
    regs={'hr':{},'sd':{}}
    before=after=0
    for t,(name,z) in enumerate(zip(NAMES,HR_SIZES),1):
        n=name.lower();cfg=profile(t)
        for q in regs:regs[q][n]={}
        for d in ANGLE_FOR_HEADING:
            for q in regs:regs[q][n][d]={}
            for role in ['on','off','glow','shadow']:
                moving=role in ['on','glow']
                srcs={q:mod/'graphics'/q/n/(d+'-'+role+'.png') for q in regs}
                sheets={q:Image.open(path).convert('RGBA') for q,path in srcs.items()}
                boxes=[occupied(sheets['hr'],z,moving),tuple(2*v for v in occupied(sheets['sd'],z//2,moving))]
                axes=[min(a[0] for a in boxes),min(a[1] for a in boxes),max(a[2] for a in boxes),max(a[3] for a in boxes)]
                b=[max(0,2*math.floor((axes[j]-4)/2)) if j<2 else min(z,2*math.ceil((axes[j]+4)/2)) for j in range(4)]
                for q,sheet in sheets.items():
                    divisor=1 if q=='hr' else 2
                    k=z//divisor;l,top,r,bot=[v//divisor for v in b]
                    width,height=r-l,bot-top
                    side=4 if moving else 1
                    stored=Image.new('RGBA',(width*side,height*side))
                    for i,cell in enumerate(cell_images(sheet,k,moving)):
                        crop=cell.crop((l,top,r,bot))
                        restored=Image.new('RGBA',(k,k));restored.paste(crop,(l,top))
                        original=np.array(cell);comparison=np.array(restored)
                        assert np.array_equal(original[:,:,3],comparison[:,:,3])
                        nonzero=original[:,:,3]>0
                        assert np.array_equal(original[nonzero],comparison[nonzero])
                        stored.paste(crop,((i%4)*width,(i//4)*height))
                    reg=registration(cfg,k)
                    pixels_per_tile=32/reg['scale']
                    shift=[reg['shift'][0]+(l+width*.5-k*.5)/pixels_per_tile,
                           reg['shift'][1]+(top+height*.5-k*.5)/pixels_per_tile]
                    # Put origin into cropped coordinates, then verify runtime shift recovers it.
                    for a in (0,1):
                        off=(l,top)[a];dim=(width,height)[a]
                        assert abs((dim*.5-shift[a]*pixels_per_tile)-(reg['origin_px'][a]-off))<1e-7
                    regs[q][n][d][role]={'width':width,'height':height,'shift':shift}
                    before+=sheet.width*sheet.height;after+=stored.width*stored.height
                    dst=srcs[q].with_suffix('.trim.png');stored.save(dst,compress_level=6);os.replace(dst,srcs[q])
    (mod/'sprite-regions.lua').write_text('-- Generated per-layer rectangles and ground-anchor shifts.\nreturn '+lua(regs)+'\n')
    info={'source_texels':before,'stored_texels':after,'transparent_area_removed_fraction':1-after/before,
          'validation':'Every nontransparent pixel and complete alpha plane reconstructed exactly. All ground anchors recovered within 1e-7 pixel.','regions':regs}
    (root/'QA').mkdir(exist_ok=True);(root/'QA/atlas-regions.json').write_text(json.dumps(info,indent=2))
    print('Verified all 96 cropped sheets. Transparent area removed:',f'{1-after/before:.1%}')
if __name__=='__main__':trim(Path(sys.argv[1]))
