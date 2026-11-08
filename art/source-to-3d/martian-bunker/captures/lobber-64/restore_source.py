"""Reconstruct the native source with per-part and complete SHA-256 checks."""
import json,hashlib
from pathlib import Path
O=Path(__file__).resolve().parent;M=json.loads((O/'source_manifest.json').read_text());P=O/M['filename']
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
if not (P.exists() and P.stat().st_size==M['size_bytes'] and digest(P)==M['sha256']):
 temp=P.with_suffix('.partial')
 with temp.open('wb') as out:
  for part in M['parts']:
   data=(O/part['path']).read_bytes();assert len(data)==part['size_bytes'] and hashlib.sha256(data).hexdigest()==part['sha256'];out.write(data)
 assert temp.stat().st_size==M['size_bytes'] and digest(temp)==M['sha256'];temp.replace(P)
print('LOBBER_SOURCE_VERIFIED',M['sha256'])
