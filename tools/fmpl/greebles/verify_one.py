#!/usr/bin/env python3
"""Independent Blender native-reopen evidence for an extracted geometry-only donor."""
import json
import sys
from pathlib import Path

import bpy

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from deatlas_core import atomic_json,sha256_file


def main():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    if len(args)!=1:
        raise SystemExit('Usage: blender -b PART.blend --python verify_one.py -- RECEIPT.json')
    receipt_path=Path(args[0]).resolve()
    source=json.loads(receipt_path.read_text(encoding='utf-8'))
    part=Path(bpy.data.filepath).resolve()
    expected_part=receipt_path.parent/(source['id']+'.blend')
    if part!=expected_part or sha256_file(part)!=source['part_sha256']:
        raise RuntimeError('Wrong extracted Blender file or hash')
    obj=bpy.data.objects.get(source['source_object'])
    if obj is None or obj.type!='MESH':
        raise RuntimeError('Missing expected mesh object')
    if len(obj.data.vertices)!=source['evaluated_vertices'] or len(obj.data.polygons)!=source['evaluated_faces']:
        raise RuntimeError('Extracted topology differs from receipt')
    if len(obj.data.materials)!=0:
        raise RuntimeError('Placeholder material slots unexpectedly remain')
    if obj.get('fmpl_part_id')!=source['id'] or obj.get('fmpl_source_object')!=source['source_object']:
        raise RuntimeError('Source identity not embedded correctly')
    if obj.get('fmpl_native_port_verified') is not False:
        raise RuntimeError('Unclassified donor was incorrectly promoted as functional port')
    report={'schema':'fmpl.greebles.native-reopen.v1','part_id':source['id'],
            'part_sha256':source['part_sha256'],
            'blender_version':list(bpy.app.version),
            'native_reopen_verified':True,
            'topology_verified':True,'placeholder_materials_stripped':True,
            'geometry_only_candidate':True,
            'visual_review':'pending'}
    atomic_json(receipt_path.parent/'native_reopen.json',report)
    print('FMPL_GREEBLE_NATIVE_REOPEN_OK',source['id'],flush=True)

if __name__=='__main__':
    main()
