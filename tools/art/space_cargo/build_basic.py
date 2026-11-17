"""Reproduce the accepted packed Basic cargo delivery; legacy pilot is archived."""
from pathlib import Path
import json,hashlib,shutil
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/space-cargo-inventories/v01/basic';approval=json.loads((O/'owner-approval.json').read_text());P=R/approval['accepted_study'];h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert approval['model_visual_approved'] and h(P/'study.blend')==approval['source_sha256'] and h(P/'study.glb')==approval['export_sha256'],'Accepted source changed; resolve source recovery before rebuild'
for a,b in [('study.blend','basic-space-cargo-v01.blend'),('study.glb','basic-space-cargo-v01.glb'),('source-front.png','source-front.png')]:shutil.copy2(P/a,O/b)
print('ACCEPTED_BASIC_PACKED_SOURCE_AND_ACTUAL_GLB_REPRODUCED')
