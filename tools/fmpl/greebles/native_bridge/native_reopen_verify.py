#!/usr/bin/env python3
"""Independently reopen one native-converted Blender part and validate identity."""
import json,sys
from pathlib import Path
import bpy

def main():
    if '--' not in sys.argv or len(sys.argv[sys.argv.index('--')+1:])!=1:
        raise SystemExit('Usage: blender -b PART.blend --python native_reopen_verify.py -- RECEIPT.json')
    receipt=Path(sys.argv[sys.argv.index('--')+1:][0]).resolve()
    r=json.loads(receipt.read_text())
    part=Path(bpy.data.filepath).resolve()
    if part!=receipt.parent/(r['id']+'.blend'):
        raise RuntimeError('Opened a different Blend scene')
    mesh=bpy.data.objects.get(r['source_object'])
    if mesh is None or mesh.type!='MESH' or len(mesh.data.vertices)!=r['counts']['vertices'] or len(mesh.data.polygons)!=r['counts']['polygons']:
        raise RuntimeError('Blender native mesh geometry mismatch')
    if mesh.get('fmpl_part_id')!=r['id'] or mesh.get('fmpl_native_port_verified') is not False or len(mesh.data.materials)!=0:
        raise RuntimeError('Source, material or mechanical interface contract mismatch')
    result={'schema':'fmpl.greebles.blend-native-reopen.v1','id':r['id'],'verified':True,
            'blender_version':list(bpy.app.version),'vertex_count':len(mesh.data.vertices),
            'polygon_count':len(mesh.data.polygons)}
    (receipt.parent/'native_reopen.json').write_text(json.dumps(result,indent=2)+'\n')
    print('FMPL_NATIVE_REOPEN_OK',r['id'])

if __name__=='__main__':main()
