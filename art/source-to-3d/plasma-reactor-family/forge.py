"""Mesh construction and packed surface finishes for the three Mars reactor studies."""
from itertools import product
from math import pi, sin, cos, acos, tan, ceil
from pathlib import Path
import struct
import zlib

import bpy
import numpy as np
from mathutils import Vector

# sRGB enamel/metal colors, metallic fraction, perceptual roughness.
FINISHES = {
    'iron': ('514b49', .72, .51), 'steel': ('77797b', .81, .35),
    'edge': ('afb0a9', .83, .31), 'black': ('2e3031', .58, .57),
    'red': ('98483a', .57, .48), 'red_dark': ('68392f', .62, .52),
    'brass': ('c39b5b', .74, .36), 'copper': ('ab704d', .72, .41),
    'ceramic': ('d1c7ac', .24, .39), 'rubber': ('262526', .06, .75),
    'ivory': ('ded4ae', .29, .46), 'amber': ('ffc25c', .24, .32),
    'plasma': ('03aace', .24, .24), 'plasma_hot': ('66e2ff', .06, .23),
    'plasma_dim': ('0a566c', .50, .32)
}
MATERIALS = {}
_ACTIVE = 'Assembly'
_BATCH = {}
PARTS = {}

def group(name):
    global _ACTIVE
    _ACTIVE = name

def srgb(c):
    return c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4

def write_png(path, rgb):
    h,w,k = rgb.shape
    def chunk(kind, data):
        return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    stream = b''.join(b'\0'+line.tobytes() for line in rgb)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(stream,9))+chunk(b'IEND',b''))

def noise_tile(rng, size, cutoff):
    fields = rng.normal(size=(size,size))
    freq = np.fft.fftfreq(size)*size
    xx,yy = np.meshgrid(freq,freq)
    fade = np.exp(-(xx*xx+yy*yy)/(2*cutoff*cutoff))
    noise = np.fft.ifft2(np.fft.fft2(fields)*fade).real
    return (noise-noise.mean()) / max(noise.std(),1e-6)

def build_materials(directory):
    directory = Path(directory)
    directory.mkdir(parents=True,exist_ok=True)
    rng=np.random.default_rng(47300)
    n=384
    cloud=noise_tile(rng,n,3)
    coarse=noise_tile(rng,n,16)
    pitting=noise_tile(rng,n,78)
    grain=rng.normal(size=(n,n))
    # Short directional tool marks and hairline scratches, tiled across object-space UVs.
    scratches=np.zeros((n,n))
    for _ in range(125):
        x,y=rng.integers(n,size=2)
        l=rng.integers(6,63)
        t=rng.choice((-.23,.08,.40,1.95))+rng.normal(0,.06)
        it=np.arange(l)
        dx=(x+np.rint(it*cos(t)).astype(int))%n
        dy=(y+np.rint(it*sin(t)).astype(int))%n
        scratches[dy,dx]=np.sin(pi*(it+.5)/l)*rng.uniform(.18,.86)
    for key,(hexvalue,metal,rough) in FINISHES.items():
        color=np.array(list(bytes.fromhex(hexvalue)))/255.
        linear=tuple(srgb(float(v)) for v in color)
        m=bpy.data.materials.new(key.replace('_',' ').title())
        m.use_nodes=True
        m.diffuse_color=(*linear,1)
        shader=m.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value=(*linear,1)
        shader.inputs['Metallic'].default_value=metal
        shader.inputs['Roughness'].default_value=rough
        emission={'plasma':1.05,'plasma_hot':1.85,'plasma_dim':.24,'amber':1.35}.get(key,0)
        if emission:
            shader.inputs['Emission Color'].default_value=(*linear,1)
            shader.inputs['Emission Strength'].default_value=emission
        else:
            weather=(.050*cloud+.041*coarse+.025*pitting+.017*grain)
            # Oxide is mottled in the recesses with isolated scuffs exposing the alloy.
            patina=np.clip((cloud*.48+coarse*.42+pitting*.27-1.06)*.64,0,.41)
            col=color[None,None,:]*(1+weather[:,:,None])
            col=col*(1-patina[:,:,None])+np.array([.29,.19,.13])*patina[:,:,None]
            strength=.20 if key in ('red','red_dark') else .13
            scar=np.clip(scratches*strength+np.clip(pitting*coarse-4.7,0,1)*strength*.52,0,.35)
            col=col*(1-scar[:,:,None])+np.array([.71,.68,.60])*scar[:,:,None]
            file=directory/(key+'.png')
            write_png(file,np.uint8(np.clip(col*255,0,255)))
            tex=m.node_tree.nodes.new('ShaderNodeTexImage')
            tex.label='Scuffed and oxidized surface'
            tex.image=bpy.data.images.load(str(file.resolve()))
            tex.image.pack()
            tex.location=(-310,220)
            m.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
        MATERIALS[key]=m

def _newbuf():
    return [[],[],[],[],[]]

def _put(name, verts, faces, mat, smooth=False):
    if not faces: return
    if mat not in FINISHES: raise ValueError('Unknown finish '+str(mat))
    b=_BATCH.setdefault(_ACTIVE,_newbuf())
    offset=len(b[0])
    b[0].extend(tuple(p) for p in verts)
    b[1].extend(tuple(i+offset for i in f) for f in faces)
    b[2].extend([mat]*len(faces))
    b[3].extend([smooth]*len(faces) if isinstance(smooth,bool) else smooth)
    b[4].append((name,offset,len(verts)))

def mesh(name, verts, faces, mat, smooth=False):
    _put(name,verts,faces,mat,smooth)

def _convex_face(ids, pts, center):
    a,b,c=(Vector(pts[i]) for i in ids[:3])
    return ids if (b-a).cross(c-a).dot(a-center)>0 else ids[::-1]

def box(name, center, size, mat, bevel=0):
    c=Vector(center)
    d=[abs(float(s))*.5 for s in size]
    rad=max(0,min(float(bevel),min(d)*.81))
    signs=list(product([-1,1],repeat=3))
    pts=[]; idx={}
    for s in signs:
        for axis in (range(3) if rad>1e-6 else [0]):
            idx[s,axis]=len(pts)
            pts.append(tuple(c[i]+s[i]*(d[i]-(rad if i!=axis else 0)) for i in range(3)))
    fs=[]
    for ax in range(3):
        others=[i for i in range(3) if i!=ax]
        for sign in (-1,1):
            ids=[]
            for a,b in [(-1,-1),(1,-1),(1,1),(-1,1)]:
                s=[0,0,0];s[ax]=sign;s[others[0]]=a;s[others[1]]=b
                ids.append(idx[tuple(s),ax if rad>1e-6 else 0])
            fs.append(ids)
    if rad>1e-6:
        for ax in range(3):
            j,k=[i for i in range(3) if i!=ax]
            for a,b in product([-1,1],repeat=2):
                p=[-1,-1,-1];p[j]=a;p[k]=b
                q=p.copy();q[ax]=1
                fs.append([idx[tuple(p),j],idx[tuple(q),j],idx[tuple(q),k],idx[tuple(p),k]])
        for s in signs: fs.append([idx[s,0],idx[s,1],idx[s,2]])
    _put(name,pts,[_convex_face(f,pts,c) for f in fs],mat)

def _basis(axis):
    v=Vector((0,0,1)) if abs(axis.z)<.85 else Vector((0,1,0))
    u=v.cross(axis).normalized()
    return u,axis.cross(u).normalized()

def cyl(name,a,b,radius,mat,sides=32,bevel=0):
    a,b=Vector(a),Vector(b)
    length=(b-a).length
    if length<1e-7 or radius<=0: return
    axis=(b-a).normalized();u,v=_basis(axis)
    rad=min(float(bevel),length*.4,radius*.35)
    profile=[(0,radius-rad),(rad,radius),(length-rad,radius),(length,radius-rad)] if rad>1e-7 else [(0,radius),(length,radius)]
    n=int(sides); radials=[u*cos(i*2*pi/n)+v*sin(i*2*pi/n) for i in range(n)]
    pts=[a+axis*d+e*rr for d,rr in profile for e in radials]
    fs=[tuple(reversed(range(n)))]
    for j in range(len(profile)-1):
        for i in range(n):
            k=(i+1)%n;fs.append((j*n+i,j*n+k,(j+1)*n+k,(j+1)*n+i))
    fs.append(tuple(range((len(profile)-1)*n,len(profile)*n)))
    _put(name,pts,fs,mat,[False]+[n>=12]*(len(fs)-2)+[False])

def tube(name,points,radius,mat,sides=12,bend=0):
    pts=[]
    for p in map(Vector, points):
        if not pts or (p-pts[-1]).length>1e-6: pts.append(p)
    if len(pts)<2: return
    path=[pts[0]]
    for a,p,b in zip(pts,pts[1:],pts[2:]):
        da=(p-a).normalized(); db=(b-p).normalized()
        phi=acos(max(-1,min(1,da.dot(db))))
        if bend>0 and 1e-4<phi<pi-1e-4:
            trim=min(bend*tan(phi/2),(p-a).length*.47,(b-p).length*.47)
            start=p-da*trim; end=p+db*trim
            turn=da.cross(db).normalized()
            ctr=start+turn.cross(da)*(trim/tan(phi/2))
            radial=start-ctr
            for j in range(max(3,ceil(phi*6))+1):
                t=phi*j/max(3,ceil(phi*6))
                path.append(ctr+radial*cos(t)+turn.cross(radial)*sin(t))
        else: path.append(p)
    path.append(pts[-1])
    n=int(sides); vs=[]; fs=[]; last=None
    for i,p in enumerate(path):
        prev=(p-path[i-1]).normalized() if i else (path[1]-p).normalized()
        nxt=(path[i+1]-p).normalized() if i+1<len(path) else prev
        axis=(prev+nxt).normalized()
        u=_basis(axis)[0] if last is None else (last-axis*last.dot(axis)).normalized()
        if u.length<.1: u=_basis(axis)[0]
        v=axis.cross(u);last=u
        vs.extend(p+radius*(cos(j*2*pi/n)*u+sin(j*2*pi/n)*v) for j in range(n))
    fs=[tuple(reversed(range(n)))]
    for i in range(len(path)-1):
        for j in range(n):
            k=(j+1)%n;fs.append((i*n+j,i*n+k,(i+1)*n+k,(i+1)*n+j))
    fs.append(tuple(range(len(vs)-n,len(vs))))
    _put(name,vs,fs,mat,[False]+[True]*(len(fs)-2)+[False])

def commit_model(model_name):
    """Make named service assemblies. UVs have a fixed world-space texel density."""
    collection=bpy.data.collections.new(model_name)
    bpy.context.scene.collection.children.link(collection)
    for label,(verts,faces,materials,smooth,parts) in _BATCH.items():
        me=bpy.data.meshes.new(label)
        me.from_pydata(verts,[],faces)
        obj=bpy.data.objects.new(label,me)
        collection.objects.link(obj)
        keys=list(dict.fromkeys(materials))
        for key in keys: me.materials.append(MATERIALS[key])
        lookup={k:i for i,k in enumerate(keys)}
        me.polygons.foreach_set('material_index',np.asarray([lookup[k] for k in materials],dtype=np.int32))
        me.polygons.foreach_set('use_smooth',np.array(smooth,dtype=np.bool_))
        me.update()
        # Dominant-axis box projection per face avoids distorted caps and supports freeform castings.
        normals=np.empty(len(faces)*3,dtype=np.float32)
        me.polygons.foreach_get('normal',normals)
        axis=np.argmax(np.abs(normals.reshape((-1,3))),axis=1)
        totals=np.empty(len(faces),dtype=np.int32);me.polygons.foreach_get('loop_total',totals)
        major=np.repeat(axis,totals)
        inds=np.empty(len(me.loops),dtype=np.int32);me.loops.foreach_get('vertex_index',inds)
        vv=np.asarray(verts,dtype=np.float32)[inds]
        uv=np.empty((len(inds),2),dtype=np.float32)
        for ax,(j,k) in enumerate([(1,2),(0,2),(0,1)]):
            mask=major==ax
            uv[mask,0]=vv[mask,j]/1.45
            uv[mask,1]=vv[mask,k]/1.45
        me.uv_layers.new(name='Foundry Surface').data.foreach_set('uv',uv.ravel())
        obj['assembly']=label
        # Source component names persist as selectable vertex groups in the native file.
        for part,offset,length in parts:
            vg=obj.vertex_groups.get(part) or obj.vertex_groups.new(name=part)
            vg.add(list(range(offset,offset+length)),1.0,'REPLACE')
        obj['component_count']=len(parts)
    _BATCH.clear()
    return collection
