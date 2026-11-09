#!/usr/bin/env python3
"""Blender 5.2 runner stage: convert geometry-only OBJ candidates to separate .blend.

Invoke with Blender 5.2 -b --factory-startup --python native_finalize.py -- --root DIR
--offset N --limit 8. Does not edit the original large source and refuses
existing output until independently reconciled. Does NOT apply source modifiers.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path
import bpy


def read_args():
    args = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    parser=argparse.ArgumentParser()
    parser.add_argument('--root',required=True)
    parser.add_argument('--offset',type=int,default=0)
    parser.add_argument('--limit',type=int,default=8)
    return parser.parse_args(args)


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda:stream.read(8*1024*1024),b''):h.update(chunk)
    return h.hexdigest()


def main():
    a=read_args()
    if not 0<=a.offset or not 1<=a.limit<=32:
        raise ValueError('Bounded offset and limit required')
    root=Path(a.root).resolve()
    receipts=sorted(root.glob('parts/*/receipt.json'))[a.offset:a.offset+a.limit]
    for receipt in receipts:
        info=json.loads(receipt.read_text(encoding='utf-8'))
        if info.get('source_sha256')!='d46d896a146792eadad0a8822a3fc7eb311c6557bd154652ce1dfe7523ebcdc1':
            raise RuntimeError('Unexpected source revision')
        directory=receipt.parent
        obj_file=directory/(info['id']+'.obj')
        blend_file=directory/(info['id']+'.blend')
        if blend_file.exists():
            raise RuntimeError('Native output already exists; validate before retry: '+str(blend_file))
        if sha(obj_file)!=info['obj_sha256']:
            raise RuntimeError('OBJ input hash mismatch: '+str(obj_file))
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.wm.obj_import(filepath=str(obj_file),forward_axis='Y',up_axis='Z')
        meshes=[x for x in bpy.data.objects if x.type=='MESH']
        if len(meshes)!=1:
            raise RuntimeError('Expected exactly one mesh from OBJ '+info['id'])
        obj=meshes[0]
        if len(obj.data.vertices)!=info['counts']['vertices'] or len(obj.data.polygons)!=info['counts']['polygons']:
            raise RuntimeError('Native OBJ import changed original mesh polygon or vertex counts')
        obj.name=info['source_object']
        obj.data.name=info['id']+'_geometry'
        obj.data.materials.clear()
        obj['fmpl_part_id']=info['id']
        obj['fmpl_source_sha256']=info['source_sha256']
        obj['fmpl_state']='unreviewed-geometry-only'
        obj['fmpl_native_port_verified']=False
        obj['fmpl_source_object']=info['source_object']
        bpy.ops.wm.save_as_mainfile(filepath=str(blend_file),compress=True)
        report={'schema':'fmpl.greebles.blend-conversion.v1','part_id':info['id'],
                'blend_sha256':sha(blend_file),'source_obj_sha256':info['obj_sha256'],
                'blender_version':list(bpy.app.version),
                'native_reopen_verified':False,'geometry_only':True}
        (directory/'blend_conversion.json').write_text(json.dumps(report,indent=2)+'\n')
        print('FMPL_NATIVE_CREATED',info['id'],flush=True)
    print('FMPL_NATIVE_BATCH_DONE',len(receipts),flush=True)

if __name__=='__main__':main()
