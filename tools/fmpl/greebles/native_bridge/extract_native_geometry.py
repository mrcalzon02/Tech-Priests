#!/usr/bin/env python3
"""Stage-1 read-only extraction for the pinned Blender 5.0 Greebles source.

Produces independent, editable OBJ source polygons + triangulated GLB donor geometry,
source receipts and two-angle diagnostic renders. Native .blend split and modifier
application must still be performed in Blender; no native claims here.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import os
import zipfile
from pathlib import Path

import numpy as np
import trimesh
from PIL import Image, ImageDraw, ImageFont

from blend5_geometry_reader import BlenderScene, SOURCE_SHA256

COMPRESSED_ORIGINAL_SHA256 = 'b7938b171edc0bf1e3daeb410029b0f5978a65df34b466fdd0fe209a71848123'

def hash_file(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for chunk in iter(lambda:f.read(8*1024*1024),b''):h.update(chunk)
    return h.hexdigest()

def part_id(name):
    import re, unicodedata
    slug=unicodedata.normalize('NFKD',name).encode('ascii','ignore').decode().lower()
    slug=re.sub(r'[^a-z0-9]+','-',slug).strip('-')[:40] or 'unnamed'
    short=hashlib.sha256((COMPRESSED_ORIGINAL_SHA256+'\0'+name).encode()).hexdigest()[:10]
    return 'gb-'+slug+'-'+short

def save_json_atomic(path,document):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    staged=path.with_suffix(path.suffix+'.tmp')
    with staged.open('x',encoding='utf-8') as f:
        json.dump(document,f,indent=2,ensure_ascii=False)
        f.write('\n');f.flush();os.fsync(f.fileno())
    os.replace(staged,path)

def geometry_report(scene, name, loaded):
    v=loaded['vertices'];b=loaded['bounds']
    extent=np.array(b['max'])-b['min']
    mn=float(min(extent));mx=float(max(extent))
    return {
        'id':part_id(name), 'source_object':name,'mesh_name':loaded['mesh_name'],
        'counts':loaded['counts'],'bounds_source_local':loaded['bounds'],
        'aspect_ascending':sorted([round(float(x),4) for x in extent]),
        'extent_local':[round(float(x),5) for x in extent],
        'source_object_transform':loaded['object'],
        'attribute_names':[x['name'] for x in loaded['attribute_metadata']],
        'geometry_status':'binary-parsed-validated-candidate',
        'source_materials':'placeholder-only; not transferred',
        'semantic_label':None,'native_blender_reopen_verified':False,
        'functional_interfaces_verified':False,'visual_review':'pending',
        'native_depsgraph_or_modifiers_evaluated':False,
    }

def save_obj(path,vertices,loaded):
    # Keep original n-gon topology instead of substituting a triangulated-only export.
    offsets=loaded['source_face_offsets']; corners=loaded['source_corner_indices']
    with Path(path).open('x',encoding='ascii') as f:
        f.write('# FMPL Greebles candidate, original source mesh faces, no source materials\n')
        for xyz in vertices:
            f.write(f'v {xyz[0]:.7f} {xyz[1]:.7f} {xyz[2]:.7f}\n')
        for i in range(len(offsets)-1):
            f.write('f '+' '.join(str(int(v)+1) for v in corners[offsets[i]:offsets[i+1]])+'\n')

def save_glb(path,vertices,faces):
    obj=trimesh.Trimesh(vertices=vertices,faces=faces,process=False,validate=False)
    blob=obj.export(file_type='glb')
    p=Path(path)
    with p.open('xb') as f:f.write(blob)
    # Independent glTF readback: topology may reorder but must not shrink or grow.
    back=trimesh.load(p,force='mesh',process=False)
    if len(back.vertices)!=len(vertices) or len(back.faces)!=len(faces) or not np.isfinite(back.vertices).all():
        raise RuntimeError('GLB readback mismatch')
    return len(blob)

def preview(path, vertices,faces, azimuth=45, elev=38, w=512,h=384):
    import cv2
    v=np.asarray(vertices,dtype=np.float64)
    rad1=math.radians(azimuth);rad2=math.radians(elev)
    c=np.array([math.cos(rad2)*math.cos(rad1),math.cos(rad2)*math.sin(rad1),math.sin(rad2)],dtype=float)
    r=np.cross(np.array([0,0,1.],dtype=float),c);r/=np.linalg.norm(r)
    up=np.cross(c,r);up/=np.linalg.norm(up)
    p=np.stack([v@r,v@up],axis=-1)
    span=np.ptp(p,axis=0); scale=min((w-65)/max(span[0],1e-8),(h-52)/max(span[1],1e-8))
    screen=(p-p.mean(axis=0))*scale+np.array([w/2,h/2]);screen[:,1]=h-screen[:,1]
    scr=np.round(screen).astype(np.int32)
    depth=v@c
    tri=faces
    tri_depth=depth[tri].mean(axis=1)
    a=v[tri[:,1]]-v[tri[:,0]]; b=v[tri[:,2]]-v[tri[:,0]]
    normal=np.cross(a,b)
    length=np.linalg.norm(normal,axis=1)
    normal/=np.maximum(length[:,None],1e-10)
    light=np.array([0.25,-0.4,0.9]);light=light/np.linalg.norm(light)
    shades=0.24+0.70*np.clip(np.abs(normal@light),0,1)
    # Deterministic shaded clay render for shape proof only; no source materials.
    canvas=np.full((h,w,3),(33,37,42),dtype=np.uint8)
    # Very cheap depth-sorted painter's algorithm; no guarantee of perfect occlusion.
    # For 100k+ faces this still makes a useful silhouette diagnostic.
    for fid in np.argsort(tri_depth):
        points=scr[tri[fid]]
        if abs(cv2.contourArea(points))<0.20:continue
        s=float(shades[fid]);col=(int(130*s+35),int(155*s+36),int(167*s+39))
        cv2.fillConvexPoly(canvas,points,col)
    cv2.imwrite(str(path),canvas)

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--source',required=True)
    p.add_argument('--out',required=True)
    p.add_argument('--offset',type=int,default=0)
    p.add_argument('--limit',type=int,default=8)
    p.add_argument('--index-all',action='store_true')
    p.add_argument('--previews',action='store_true')
    p.add_argument('--resume',action='store_true')
    a=p.parse_args()
    if a.offset<0 or a.limit<1 or a.limit>32:p.error('Bounded limit 1..32')
    source=Path(a.source).resolve();out=Path(a.out).resolve()
    if source==out or out in source.parents or source in out.parents:
        raise ValueError('Output must be separate from original Blender source')
    if hash_file(source)!=SOURCE_SHA256:
        raise RuntimeError('Uncompressed source hash mismatch; refusing extraction')
    withsource=BlenderScene(source)
    try:
        names=sorted(withsource.objects, key=lambda x:(x.casefold(),x))
        index=[]
        if a.index_all:
            for j,name in enumerate(names):
                loaded=withsource.load_mesh(name)
                index.append(geometry_report(withsource,name,loaded))
                if (j+1)%40==0:print('INDEXED',j+1,'of',len(names),flush=True)
            counts={'objects':len(index),'vertices':sum(x['counts']['vertices'] for x in index),
                'polygons':sum(x['counts']['polygons'] for x in index),
                'triangles':sum(x['counts']['triangles'] for x in index)}
            out.mkdir(parents=True,exist_ok=True)
            save_json_atomic(out/'source_geometry_index.json',{
                'schema':'fmpl.greebles.native-geometry-index.v1','source_sha256':SOURCE_SHA256,
                'original_drive_sha256':COMPRESSED_ORIGINAL_SHA256,
                'counts':counts,'objects':index,
                'audit':'All geometry retrieved from Blender 5 native polygon and position arrays; not depsgraph evaluated.'})
            print('GEOMETRY_INDEX_COMPLETE',counts,flush=True)
        selected=names[a.offset:a.offset+a.limit]
        for name in selected:
            pid=part_id(name)
            folder=out/'parts'/pid
            receipt=folder/'receipt.json'
            glb=folder/(pid+'.glb')
            obj=folder/(pid+'.obj')
            if receipt.exists():
                if not a.resume:raise RuntimeError('Existing receipt; rerun with --resume after review: '+str(receipt))
                previous=json.loads(receipt.read_text())
                if previous['source_sha256']!=SOURCE_SHA256 or not glb.is_file() or hash_file(glb)!=previous['glb_sha256']:
                    raise RuntimeError('Checkpoint mismatch for '+pid)
                print('RESUME_VERIFIED',pid,flush=True)
                continue
            if folder.exists():
                raise RuntimeError('Orphaned part directory; inspect before retry '+str(folder))
            loaded=withsource.load_mesh(name)
            v=loaded['vertices'].astype(np.float64)
            # Centre into a reusable local pivot, without altering stored topology.
            center=(v.min(axis=0)+v.max(axis=0))/2
            local=v-center
            folder.mkdir(parents=True,exist_ok=False)
            save_obj(obj,local,loaded)
            glb_bytes=save_glb(glb,local,loaded['faces'])
            result=geometry_report(withsource,name,loaded)
            result.update({'schema':'fmpl.greebles.external-candidate.v1','source_sha256':SOURCE_SHA256,
                           'original_drive_sha256':COMPRESSED_ORIGINAL_SHA256,
                           'geometry_normalization':'subtract-local-AABB-center',
                           'geometry_center_source_local':center.tolist(),
                           'glb_sha256':hash_file(glb),'glb_bytes':glb_bytes,
                           'obj_sha256':hash_file(obj),'obj_bytes':obj.stat().st_size,
                           'glb_readback_verified':True,'source_file_unchanged':True,
                           'state':'external-geometry-candidate; native-blend-split-pending'})
            if a.previews:
                for angle,label in [(45,'front'),(225,'rear')]:
                    preview(folder/(label+'.png'),local,loaded['faces'],azimuth=angle)
                result['preview_files']=['front.png','rear.png']
            save_json_atomic(receipt,result)
            print('PART_OK',pid,'vertices',len(v),'faces',len(loaded['faces']),'glb_bytes',glb_bytes,flush=True)
        print('BATCH_DONE',len(selected),flush=True)
    finally:withsource.close()

if __name__=='__main__':main()
