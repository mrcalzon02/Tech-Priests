#!/usr/bin/env python3
"""Read *stored* mesh geometry from this specific Blender 5.0 scene without bpy.

This is a read-only compatibility bridge for index/GLB candidates when Blender is
unavailable. It is not Blender's depsgraph evaluation, a native .blend exporter, or
a general reader for arbitrary .blend versions. It requires exact known source
header and performs topology/pointer validation before output.
"""
from __future__ import annotations
import bisect
import hashlib
import mmap
import struct
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

import numpy as np

HEADER = b'BLENDER17-01v0500'
SOURCE_SHA256 = 'd46d896a146792eadad0a8822a3fc7eb311c6557bd154652ce1dfe7523ebcdc1'  # update after readback
# The compressed original is pinned separately; the uncompressed working copy must
# be matched to its content-derived digest, not falsely compared byte-for-byte.

@dataclass(frozen=True)
class Block:
    code: str
    ptr: int
    start: int
    size: int
    count: int
    sdna: int

class BlenderScene:
    def __init__(self,path):
        self.path=Path(path).resolve()
        self.file=self.path.open('rb')
        self.mm=mmap.mmap(self.file.fileno(),0,access=mmap.ACCESS_READ)
        if self.mm[:17]!=HEADER:
            raise ValueError('This validated reader only supports the exact Blender 5.0 extended header')
        self.blocks=[]
        pos=17
        while pos+32<=len(self.mm):
            code,sdna,ptr,length,count=struct.unpack_from('<4siQqq',self.mm,pos)
            if length<0 or pos+32+length>len(self.mm):
                raise ValueError('Invalid native block length')
            name=code.rstrip(b'\0').decode('latin1')
            self.blocks.append(Block(name,ptr,pos+32,length,count,sdna))
            pos+=32+length
            if name=='ENDB':break
        if pos!=len(self.mm) or self.blocks[-1].code!='ENDB':
            raise ValueError('Incomplete Blender source blocks')
        self.objects={}
        self.meshes={}
        for i,b in enumerate(self.blocks):
            if b.code=='OB':
                name=self._str(b.start+42,256)
                if struct.unpack_from('<h',self.mm,b.start+424)[0]==1:
                    self.objects[name] = {
                        'name':name,
                        'mesh_ptr':self.u64(b.start+560),
                        'location':self.floats(b.start+744,3),
                        'scale':self.floats(b.start+768,3),
                        'rotation_euler':self.floats(b.start+804,3),
                        'rotation_mode':struct.unpack_from('<h',self.mm,b.start+1048)[0],
                        'parent_ptr':self.u64(b.start+504),
                        'block':b,
                    }
            if b.code=='ME':
                self.meshes[b.ptr]=(i,b)
        if not self.objects or not self.meshes:
            raise ValueError('Source lacks mesh datablocks')

    def close(self):
        self.mm.close();self.file.close()

    def _str(self,start,n):return self.mm[start:start+n].split(b'\0',1)[0].decode('utf8','replace')
    def u64(self,start):return struct.unpack_from('<Q',self.mm,start)[0]
    def floats(self,start,count):return list(struct.unpack_from('<'+'f'*count,self.mm,start))

    def _group(self,idx):
        j=idx+1
        while j<len(self.blocks) and self.blocks[j].code=='DATA':j+=1
        blocks=self.blocks[idx:j]
        mapping={b.ptr:b for b in blocks if b.ptr}
        def read(ptr, length=None):
            b=mapping.get(ptr)
            if not b:return None
            if length is not None and length>b.size:return None
            return memoryview(self.mm)[b.start:b.start+(b.size if length is None else length)]
        return read

    def load_mesh(self,name):
        ob=self.objects.get(name)
        if not ob:raise KeyError(name)
        entry=self.meshes.get(ob['mesh_ptr'])
        if not entry:raise ValueError(f'Object {name} has unresolved mesh reference')
        idx,b=entry; read=self._group(idx); mesh=self.mm
        nvert,nedge,nface,ncorner=struct.unpack_from('<4i',mesh,b.start+432)
        if not (0<nvert<=20_000_000 and 0<=nface<=20_000_000 and 0<=ncorner<=100_000_000):
            raise ValueError(f'Invalid mesh cardinalities for {name}')
        attrptr=self.u64(b.start+456)
        num=struct.unpack_from('<i',mesh,b.start+464)[0]
        if not 0<num<128:raise ValueError(f'Invalid mesh attribute count for {name}')
        attrs=read(attrptr, num*24)
        if attrs is None:raise ValueError(f'Unresolvable native attributes for {name}')
        out={}
        attrs_meta=[]
        for x in range(num):
            a=attrs[x*24:(x+1)*24]
            name_ptr=struct.unpack_from('<Q',a,0)[0]
            typ,domain,storage=struct.unpack_from('<hbb',a,8)
            data_ptr=struct.unpack_from('<Q',a,16)[0]
            nm=read(name_ptr)
            if nm is None:raise ValueError('Missing attribute name')
            key=bytes(nm).split(b'\0',1)[0].decode('utf8','replace')
            attrs_meta.append({'name':key,'type':typ,'domain':domain,'storage':storage})
            if key not in {'position','.corner_vert','UVMap'}:
                continue
            if storage!=0:raise ValueError(f'Unsupported attribute storage {key}')
            db=read(data_ptr,24)
            if db is None:raise ValueError(f'Unresolvable {key} data descriptor')
            rawptr=struct.unpack_from('<Q',db,0)[0]
            num_elems=struct.unpack_from('<I',db,16)[0]
            if key=='position':
                expected=nvert;size=12;dt='<f4';width=3
            elif key=='.corner_vert':
                expected=ncorner;size=4;dt='<i4';width=1
            else:
                expected=ncorner;size=8;dt='<f4';width=2
            if num_elems!=expected:raise ValueError(f'{name}.{key} count mismatch: {num_elems} != {expected}')
            raw=read(rawptr,expected*size)
            if raw is None:raise ValueError(f'Missing {key} raw array')
            out[key]=np.frombuffer(raw,dtype=dt,count=expected*width).reshape((-1,width)).copy()
        if not {'position','.corner_vert'}<=out.keys():
            raise ValueError(f'{name}: essential mesh geometry missing')
        verts=out['position']
        corners=out['.corner_vert'].reshape(-1)
        if not np.isfinite(verts).all() or not ((corners>=0)&(corners<nvert)).all():
            raise ValueError(f'{name}: invalid vertex or corner data')
        offptr=self.u64(b.start+448)
        offraw=read(offptr,4*(nface+1))
        if offraw is None:raise ValueError(f'Missing polygon offsets for {name}')
        offsets=np.frombuffer(offraw,dtype='<i4',count=nface+1).copy()
        if offsets[0]!=0 or offsets[-1]!=ncorner or (np.diff(offsets)<3).any():
            raise ValueError(f'Invalid polygon offsets for {name}')
        # Preserve n-gons as source evidence. Fan triangulation is a staging
        # interchange only; native Blender later reopens for exact mesh proof.
        triangles=[]
        for face in range(nface):
            loop=corners[offsets[face]:offsets[face+1]]
            for k in range(1,len(loop)-1):triangles.append((int(loop[0]),int(loop[k]),int(loop[k+1])))
        faces=np.asarray(triangles,dtype=np.int32).reshape((-1,3))
        if not len(faces) or not ((faces>=0)&(faces<nvert)).all():
            raise ValueError(f'{name}: invalid triangulation')
        return {
            'vertices':verts,'faces':faces, 'corner_uv':out.get('UVMap'),
            'source_face_offsets':offsets,'source_corner_indices':corners,
            'mesh_name':self._str(b.start+42,256),
            'attribute_metadata':attrs_meta,
            'object':{k:v for k,v in ob.items() if k!='block'},
            'counts':{'vertices':nvert,'edges':nedge,'polygons':nface,'corners':ncorner,'triangles':len(faces)},
            'bounds':{'min':verts.min(axis=0).tolist(),'max':verts.max(axis=0).tolist()},
        }
