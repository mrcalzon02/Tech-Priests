"""Reopen all ten sources and prove the wall/tablet/interface geometry unchanged."""
from pathlib import Path
import bpy,json,hashlib
R=Path(__file__).resolve().parents[3];B=R/'art/source-to-3d/filtered-stone-caches/v01';cat=json.loads((B/'catalog.json').read_text())
def geometry():
 bpy.context.view_layer.update();parts={}
 for ob in bpy.context.scene.objects:
  if ob.type!='MESH' or ob.name.startswith('Stock |'):continue
  parts[ob.name]=hashlib.sha256(repr((tuple(tuple(float(x) for x in row) for row in ob.matrix_world),[tuple(float(x) for x in v.co) for v in ob.data.vertices],[tuple(p.vertices) for p in ob.data.polygons],[tuple(float(x) for x in uv.uv) for uv in ob.data.uv_layers.active.data])).encode()).hexdigest()
 return parts
bpy.ops.wm.open_mainfile(filepath=str(R/cat['shared_source']))
for ob in list(bpy.data.collections['CACHE VARIANT | Domed hide cover'].objects):bpy.data.objects.remove(ob,do_unlink=True)
expected=geometry();rows=[]
for row in cat['rows']:
 p=R/row['path'];source=p/(row['stem']+'.blend');bpy.ops.wm.open_mainfile(filepath=str(source));actual=geometry();r=dict(key=row['key'],passed=actual==expected,source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),shared_parts=len(actual));rows.append(r);assert r['passed'],row['key']
(B/'shared-wall-audit.json').write_text(json.dumps(dict(passed=True,expected_parts=expected,rows=rows,scope='Exact source mesh topology, vertices, matrices and active UV unchanged for all shared wall/tablet/emblem/native-contact objects; only stock filling varies.'),indent=2)+'\n');print('TEN_SHARED_WALL_TABLET_GEOMETRY_MATCHES')
