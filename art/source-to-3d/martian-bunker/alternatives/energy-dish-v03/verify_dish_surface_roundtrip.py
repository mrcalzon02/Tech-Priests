import bpy,json,pathlib,sys,math,itertools
from mathutils import Vector
O=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve()
def surfaces():
 result={};dg=bpy.context.evaluated_depsgraph_get()
 for o in bpy.context.scene.objects:
  if o.type!='MESH':continue
  ev=o.evaluated_get(dg);m=ev.to_mesh();m.calc_loop_triangles();uv=m.uv_layers.active.data;rows={};area=0
  for t in m.loop_triangles:
   corners=[]
   for li in t.loops:
    p=o.matrix_world@m.vertices[m.loops[li].vertex_index].co;corners.append(tuple(p)+tuple(uv[li].uv))
   area+=(Vector(corners[1][:3])-Vector(corners[0][:3])).cross(Vector(corners[2][:3])-Vector(corners[0][:3])).length/2
   for corner in corners:
    key=(corner,o.data.materials[t.material_index].name);rows[key]=corner
  result[o.name]={'corners':rows,'area':area,'triangles':len(m.loop_triangles)};ev.to_mesh_clear()
 return result
bpy.ops.wm.open_mainfile(filepath=str(O/'energy_dish_v03.blend'));native=surfaces()
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(O/'energy_dish_v03.glb'));export=surfaces()
assert native.keys()==export.keys();delta_pos=delta_uv=area_delta=0;triangles=corners=0
for name,part in native.items():
 other=export[name];rows=part['corners'];assert len(rows)==len(other['corners']),(name,'unique corner count')
 assert part['triangles']==other['triangles'],name
 area_delta=max(area_delta,abs(part['area']-other['area']));assert abs(part['area']-other['area'])<1e-5,name
 buckets={};values=list(other['corners'])
 for index,(v,mat) in enumerate(values):buckets.setdefault((tuple(math.floor(x/1e-5) for x in v[:3]),mat),[]).append(index)
 used=set()
 for (v,mat) in rows:
  cell=tuple(math.floor(x/1e-5) for x in v[:3]);found=None
  for offset in itertools.product((-1,0,1),repeat=3):
   for index in buckets.get((tuple(cell[i]+offset[i] for i in range(3)),mat),[]):
    w=values[index][0]
    if index not in used and max(abs(v[i]-w[i]) for i in range(5))<1e-5:found=index;break
   if found is not None:break
  assert found is not None,(name,'position/UV/material coverage',v)
  used.add(found);w=values[found][0];delta_pos=max(delta_pos,max(abs(v[i]-w[i]) for i in range(3)));delta_uv=max(delta_uv,max(abs(v[i]-w[i]) for i in (3,4)))
 triangles+=part['triangles'];corners+=len(rows)
assert delta_pos<1e-5 and delta_uv<1e-5,(delta_pos,delta_uv)
report={'status':'PASS','mesh_count':len(native),'triangle_count_each':triangles,'unique_position_uv_material_corners_matched':corners,'max_world_position_delta':delta_pos,'max_uv_delta':delta_uv,'max_part_surface_area_delta':area_delta,'material_assignments_match':True,'scope':'Evaluated native unique position/UV/material coverage, per-part triangle counts and surface area versus actual imported GLB. N-gon cap triangulation may choose different diagonals; triangle topology and render pixels are not claimed identical.'}
(O/'surface-roundtrip-validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
