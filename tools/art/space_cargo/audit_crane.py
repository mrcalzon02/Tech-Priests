"""Closed edited crane castings: independent source/export winding checks."""
import bpy,bmesh,json,hashlib
from pathlib import Path
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/space-cargo-inventories/v01/advanced';names=json.loads((O/'crane-refinement.json').read_text())['modified'];results=[]
for kind in ('source','export'):
 if kind=='source':bpy.ops.wm.open_mainfile(filepath=str(O/'advanced-space-cargo-v01.blend'))
 else:
  bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(O/'advanced-space-cargo-v01.glb'))
 records=[]
 for name in names:
  ob=bpy.data.objects[name];bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7);volume=bm.calc_volume(signed=True);openedges=sum(not e.is_manifold for e in bm.edges);bm.free();records.append(dict(object=name,signed_volume=volume,nonmanifold_edges=openedges,passed=volume>0 and openedges==0))
 results.append(dict(artifact=kind,objects=records,passed=all(r['passed'] for r in records)))
r=dict(source_sha256=hashlib.sha256((O/'advanced-space-cargo-v01.blend').read_bytes()).hexdigest(),results=results,passed=all(x['passed'] for x in results));(O/'crane-solid-audit.json').write_text(json.dumps(r,indent=2)+'\n');print('CRANE_CLOSED_SOLID_WINDING_PASS',r['passed']);assert r['passed']
