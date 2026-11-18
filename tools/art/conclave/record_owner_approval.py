"""Record the owner's explicit acceptance of this exact saved Conclave model."""
from pathlib import Path
import json,hashlib
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/conclave-center/v08-martian-central-emblem';h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
r=dict(owner_approved=True,owner_date='2026-11-16',owner_quote='Continue! this is done and we are ready to integrate and test.',scope='Conclave Center V08 authored model and requested visual/ambient refinements; proceed with integration and testing. This does not approve unrelated queue assets or declare unperformed tests passed.',source_sha256=h(O/'conclave-center-v08.blend'),export_sha256=h(O/'conclave-center-v08.glb'),implementation_checkpoint='9d965d214538d4ebbb35101a3b7b5f13c80050f6')
(O/'owner-approval.json').write_text(json.dumps(r,indent=2)+'\n');print('OWNER_ACCEPTANCE_BOUND_TO_SAVED_V08')
