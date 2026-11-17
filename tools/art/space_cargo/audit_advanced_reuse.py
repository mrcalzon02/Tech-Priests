import bpy,json,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
R=Path(__file__).resolve().parents[3];B=R/'art/source-to-3d/space-cargo-inventories/v01/basic';O=B.parent/'advanced'
def signature(ob):
 return dict(vertices=[list(v.co) for v in ob.data.vertices],polygons=[list(p.vertices) for p in ob.data.polygons],uv=[list(v.uv) for v in ob.data.uv_layers.active.data],materials=[m.name for m in ob.data.materials])
bpy.ops.wm.open_mainfile(filepath=str(B/'basic-space-cargo-v01.blend'));base={o.name:(signature(o),o.matrix_world.copy()) for o in bpy.context.scene.objects if o.type=='MESH' and not o.get('fmpl_render_only')}
bpy.ops.wm.open_mainfile(filepath=str(O/'advanced-space-cargo-v01.blend'));bpy.context.view_layer.update();records=[];transform=Matrix.Translation(Vector((0,-1.468,0)))@Matrix.Diagonal(Vector((.8,.8,.8,1)))
for name,(sig,matrix) in base.items():
 ob=bpy.data.objects.get(name);expected=transform@matrix;err=max(abs(ob.matrix_world[i][j]-expected[i][j]) for i in range(4) for j in range(4)) if ob else 999;records.append(dict(name=name,mesh_uv_materials_unchanged=bool(ob and signature(ob)==sig),uniform_assembly_transform_error=err,passed=bool(ob and signature(ob)==sig and err<1e-5)))
r=dict(passed=all(x['passed'] for x in records),source_sha256=hashlib.sha256((O/'advanced-space-cargo-v01.blend').read_bytes()).hexdigest(),basis_sha256=hashlib.sha256((B/'basic-space-cargo-v01.blend').read_bytes()).hexdigest(),meshes=len(records),records=records,scope='Complete Basic mesh topology, UVs and material bindings unchanged; one uniform0.8 assembly fit andY-1.468 translation within owner-corrected square Advanced5x5 footprint. No window replacement or component stretching.')
(O/'basic-reuse-audit.json').write_text(json.dumps(r,indent=2));assert r['passed'];print('BASIC_MODULE_UNCHANGED_REUSE_PASS',len(records))
