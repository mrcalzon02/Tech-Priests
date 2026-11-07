import hashlib,json
from pathlib import Path
O=Path(__file__).resolve().parent
m=json.loads((O/'source_manifest.json').read_text())
target=O/m['filename']
with target.open('wb') as f:
 for part in m['parts']:
  data=(O/part['path']).read_bytes()
  assert hashlib.sha256(data).hexdigest()==part['sha256'],part['path']
  f.write(data)
assert target.stat().st_size==m['size_bytes']
assert hashlib.sha256(target.read_bytes()).hexdigest()==m['sha256']
print('RESTORED_VERIFIED_SOURCE',target)
