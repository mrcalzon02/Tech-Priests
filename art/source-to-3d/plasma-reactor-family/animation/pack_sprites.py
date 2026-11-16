"""Denoise registered native renders and separate Factorio color, glow and shadow."""
from argparse import ArgumentParser
from pathlib import Path
import json, os, shutil, subprocess, sys, tempfile, time
from math import pi
import numpy as np
from scipy.ndimage import gaussian_filter, maximum_filter, map_coordinates
from PIL import Image, ImageDraw, ImageFilter
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import fmpl_adapter as fmpl
from thermal_rig import heat_zones

def pfm_write(path,arr):
    with path.open('wb') as stream:
        stream.write(f'PF\n{arr.shape[1]} {arr.shape[0]}\n-1.0\n'.encode())
        np.flipud(arr).astype('<f4').tofile(stream)

def pfm_read(path):
    with path.open('rb') as stream:
        if stream.readline().strip()!=b'PF':raise ValueError('Expected an RGB PFM')
        w,h=map(int,stream.readline().split())
        endian='<' if float(stream.readline())<0 else '>'
        return np.flipud(np.fromfile(stream,endian+'f4').reshape(h,w,3))

def rgba(path):
    return np.asarray(Image.open(path).convert('RGBA'),np.float32)/255.

def u8(arr):
    return np.uint8(np.clip(arr*255.+.5,0,255))

def image(arr):
    return Image.fromarray(u8(arr))

def denoise(raw,oidn,tmp):
    # Filter a neutral matte in sRGB, then return to straight RGBA. The matte
    # is never written into the Factorio sprite. Preserve fine material detail.
    color=raw[:,:,:3];alpha=raw[:,:,3]
    matte=.24
    flat=color*alpha[:,:,None]+matte*(1-alpha[:,:,None])
    if oidn:
        infile,outfile=tmp/'frame.pfm',tmp/'clean.pfm'
        pfm_write(infile,flat)
        subprocess.run([oidn,'-d','CPU','--ldr',str(infile),'--srgb','--threads','2',
                        '-q','balanced','-v','0','-o',str(outfile)],check=True,
                       stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        filtered=pfm_read(outfile)
        flat=filtered*.91+flat*.09
    else:
        # A bounded local edge-preserving filter for systems without OIDN.
        from scipy.ndimage import median_filter
        median=median_filter(flat,size=(3,3,1))
        weight=np.exp(-np.max(np.abs(median-flat),axis=2,keepdims=True)**2/.035)
        flat+=.55*weight*(median-flat)
    a_blur=gaussian_filter(alpha,.65)
    # Denoise stochastic vapor coverage while retaining the hard surface silhouette.
    border=(alpha<.98) & (a_blur>.003)
    a=np.where(border,.58*a_blur+.42*alpha,alpha)
    out=np.empty_like(raw);out[:,:,3]=a
    out[:,:,:3]=np.clip((flat-matte*(1-a[:,:,None]))/np.maximum(a[:,:,None],.018),0,1)
    out[a<.005]=0
    return out

def coil_distortion(beauty,emit,cfg,tier,angle,phase):
    # Sprite-space optical displacement is attached to the actual projected hot
    # volumes and gated by their visible emission. It refracts captured hardware
    # and its alpha silhouette, including at a nominal 32 px/tile game zoom.
    h,w=beauty.shape[:2];ys,xs=np.mgrid[:h,:w].astype(np.float32)
    dx=np.zeros((h,w),np.float32);dy=dx.copy()
    factor=h/cfg['camera_override']['ortho_scale']
    for zone in heat_zones(tier,fmpl.RADII[tier-1]):
        x,y=fmpl.project(cfg,zone['center'],angle)
        rx,ry,rz=zone['radii']
        if angle in (90,270):rx,ry=ry,rx
        rx=rx*factor;ry=np.hypot(ry,rz)*fmpl.S*factor
        ex=int(rx*1.2+5);ey=int(ry*1.2+5)
        x0=max(0,int(x)-ex);x1=min(w,int(x)+ex+1)
        y0=max(0,int(y)-ey);y1=min(h,int(y)+ey+1)
        if x1<=x0 or y1<=y0:continue
        si=np.s_[y0:y1,x0:x1]
        xx=xs[si]-x;yy=ys[si]-y
        ellipse=(xx/(rx+1))**2+(yy/(ry+1))**2
        envelope=np.clip((1.43-ellipse)/.72,0,1)
        em=emit[si]
        lit=np.clip((em[:,:,1]+em[:,:,2]-2*em[:,:,0]-.055)*1.9,0,1)*envelope
        if np.max(lit)<.12:continue
        near=gaussian_filter(maximum_filter(lit,size=7),1.4)
        envelope*=near
        theta=2*pi*(phase+zone['seed'])
        amplitude=.66*envelope
        dx[si]+=amplitude*(.68*np.sin(yy*.21+xx*.045+theta)+.32*np.sin(yy*.11-xx*.085+2*theta))
        dy[si]+=.43*amplitude*np.cos(xx*.20+yy*.065-theta)
    if not np.any(dx):return beauty,emit
    coords=[ys+dy,xs+dx]
    def warp(arr):
        return np.stack([map_coordinates(arr[:,:,i],coords,order=1,mode='constant',prefilter=False) for i in range(arr.shape[2])],axis=2)
    pm=beauty.copy();pm[:,:,:3]*=pm[:,:,3:4]
    tmp=warp(pm);tmp[:,:,:3]/=np.maximum(tmp[:,:,3:4],1.e-5)
    return np.clip(tmp,0,1),warp(emit)

def save(path,img):
    path.parent.mkdir(exist_ok=True,parents=True)
    temp=path.with_suffix('.partial.png');img.save(temp,compress_level=6);os.replace(temp,path)

def shadow(geometry,cfg,angle,dst):
    with np.load(geometry) as data:
        verts=data['verts'];faces=data['tris']
    x,y,z=verts.T
    xx,yy=((x,y),(-y,x),(-x,-y),(y,-x))[angle//90]
    kx,ky=fmpl.SHADOW_OFFSET_PER_Z
    xx=xx+kx*z;yy=yy+ky*z
    size=cfg['source_size'];scale=2*size/cfg['camera_override']['ortho_scale']
    cx,cy,cz=cfg['camera_override']['target']
    pixels=np.rint(np.column_stack([size+(xx-cx)*scale,size-((yy-cy)-cz)*fmpl.S*scale])).astype(np.int32)
    mask=Image.new('L',(2*size,2*size))
    draw=ImageDraw.Draw(mask)
    for tri in pixels[faces].reshape(-1,6).tolist():
        draw.polygon(tri,fill=105)
    mask=mask.filter(ImageFilter.GaussianBlur(1.8)).resize((size,size),Image.Resampling.LANCZOS)
    sh=Image.new('RGBA',(size,size),(18,18,20,0));sh.putalpha(mask);save(dst,sh)

def export_frame(rawpath,emitfile,folder,cfg,tier,angle,index,oidn,tmp):
    beauty=denoise(rgba(rawpath),oidn,tmp)
    stem='off' if index==0 else f'{index:02d}'
    if index:
        em=np.array(Image.open(emitfile).convert('RGB'),np.float32)/255.
        em=np.maximum(0,em-.012)
        beauty,em=coil_distortion(beauty,em,cfg,tier,angle,(index-1)/16.)
        # Separate emitted color from the combined daylight plate; base+additive
        # matches the proof by construction, and the glow remains luminous at night.
        a=beauty[:,:,3:4]
        glow=np.minimum(em*.91,beauty[:,:,:3]*.90)
        glow*=np.minimum(em.max(axis=2,keepdims=True)*13,1)
        base=beauty.copy();base[:,:,:3]=np.maximum(0,base[:,:,:3]-glow)
        g=np.empty_like(beauty);peak=np.max(glow,axis=2,keepdims=True)
        g[:,:,:3]=glow/np.maximum(peak,1.e-6);g[:,:,3:4]=peak*a
        save(folder/'layers'/(stem+'-on.png'),image(base));save(folder/'layers'/(stem+'-glow.png'),image(g))
    save(folder/(stem+'.png'),image(beauty))

def assemble(folder,mod,tier,heading):
    name=fmpl.NAMES[tier-1].lower()
    for res,z in [('hr',fmpl.HR_SIZES[tier-1]),('sd',fmpl.SD_SIZES[tier-1])]:
        target=mod/'graphics'/res/name;target.mkdir(parents=True,exist_ok=True)
        def scaled(path):
            with Image.open(path) as im:
                v=im.convert('RGBA')
                # Pillow uses premultiplied alpha for RGBA resize.
                return v if v.size==(z,z) else v.resize((z,z),Image.Resampling.LANCZOS)
        for state in ['off','shadow']:
            save(target/(heading+'-'+state+'.png'),scaled(folder/(state+'.png')))
        for state in ['on','glow']:
            atlas=Image.new('RGBA',(4*z,4*z))
            for i in range(16):
                f=folder/'layers'/(f'{i+1:02d}-{state}.png')
                atlas.paste(scaled(f),((i%4)*z,(i//4)*z))
            save(target/(heading+'-'+state+'.png'),atlas)

def main(o):
    raw=Path(o.raw).resolve();cold=Path(o.cold).resolve();dest=Path(o.output).resolve()
    mod=dest/'Factorio'/'mars-reactor-visuals_1.0.0';oidn=os.environ.get('OIDN_DENOISE') or shutil.which('oidnDenoise')
    jobs=[(name.lower(),k,h,fmpl.ANGLE_FOR_HEADING[h],j) for h in ['south','east','north','west'] for k,name in enumerate(fmpl.NAMES,1) for j in range(17)]
    done=set();sheets=set()
    with tempfile.TemporaryDirectory() as t:
        while len(done)<len(jobs):
            progress=False
            for name,k,h,angle,j in jobs:
                key=(name,h,j)
                if key in done:continue
                stem='off' if j==0 else f'{j:02d}'
                source=(cold if j==0 else raw)/name/h
                if not (source/(stem+'.ok')).is_file():continue
                folder=dest/'frames'/name/h;folder.mkdir(parents=True,exist_ok=True)
                cfg=fmpl.profile(k);outframe=folder/(stem+'.png')
                if not outframe.is_file() or o.force:
                    emit=next(source.glob(f'emit-{stem}-*.png'))
                    export_frame(source/(stem+'.png'),emit,folder,cfg,k,angle,j,oidn,Path(t))
                geo=raw/name/'shadow-geometry.npz'
                if not (folder/'shadow.png').is_file() and geo.exists():shadow(geo,cfg,angle,folder/'shadow.png')
                done.add(key);progress=True
                if all((name,h,n) in done for n in range(17)):
                    assemble(folder,mod,k,h);sheets.add((name,h))
                    print('PACKED',name,h,flush=True)
            if not progress and len(done)<len(jobs):
                if not o.watch: raise RuntimeError(f'Missing Blender renders ({len(done)}/{len(jobs)})')
                time.sleep(2)
    if len(sheets)!=12:raise RuntimeError('Missing a direction')
    print('Completed 12 directions, 192 unique active frames, 12 idle plates.',flush=True)

if __name__=='__main__':
    ap=ArgumentParser();ap.add_argument('raw');ap.add_argument('cold');ap.add_argument('output')
    ap.add_argument('--watch',action='store_true');ap.add_argument('--force',action='store_true')
    main(ap.parse_args())
