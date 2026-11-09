#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
import hashlib,json,sys
from extract_native_geometry import hash_file,part_id,SOURCE_SHA256,COMPRESSED_ORIGINAL_SHA256

def main(root):
 root=Path(root)
 index=json.loads((root/'source_geometry_index.json').read_text())
 found={}
 failures=[]
 total_bytes=0
 for x in index['objects']:
  ident=x['id']; d=root/'parts'/ident
  receipt=d/'receipt.json';obj=d/(ident+'.obj');glb=d/(ident+'.glb')
  if not receipt.is_file() or not obj.is_file() or not glb.is_file():
   failures.append(f'missing {ident}');continue
  r=json.loads(receipt.read_text())
  if r['id'] != ident or r['counts']!=x['counts'] or r['source_sha256']!=SOURCE_SHA256:
   failures.append(f'metadata {ident}')
  if r['glb_sha256']!=hash_file(glb) or r['obj_sha256']!=hash_file(obj):
   failures.append(f'checksum {ident}')
  total_bytes+=obj.stat().st_size+glb.stat().st_size
  found[ident]=r
 all_recs=list(root.glob('parts/*/receipt.json'))
 if len(all_recs)!=len(index['objects']):failures.append('receipts-count')
 if len(set(found))!=len(found):failures.append('duplicate ids')
 result={'schema':'fmpl.greebles.extraction-audit.v1',
  'source_original_sha256':COMPRESSED_ORIGINAL_SHA256,'source_decompressed_sha256':SOURCE_SHA256,
  'expected_objects':len(index['objects']),'found_objects':len(found),
  'validation':'Independent file hash reread for every GLB/OBJ, manifest crosscheck, and no extra receipts',
  'geometry_totals':index['counts'],
  'individual_obj_glb_payload_bytes':total_bytes,
  'errors':failures,'status':'passed-interchange-only' if not failures else 'failed',
  'native_blend_files':'not generated; Blender required',
  'placeholder_materials':'excluded from each interchange',
  'asset_promotion':'candidates only; visual/fit/native Blender checks pending'}
 (root/'extraction_audit.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps(result,indent=2))
 if failures:raise SystemExit(1)
if __name__=='__main__':main(sys.argv[1])
