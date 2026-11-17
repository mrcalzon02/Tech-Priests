"""Independent axial bore probes on real source and imported GLB pump service ports."""
import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/space-cargo-inventories/v01/advanced';routes=json.loads((O/'dense-detail-manifest.json').read_text())['hydraulic_routes'];results=[]
for kind in ('source','export'):
 if kind=='source':bpy.ops.wm.open_mainfile(filepath=str(O/'advanced-space-cargo-v01.blend'))
 else:bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(O/'advanced-space-cargo-v01.glb'))
 bpy.context.view_layer.update();verts=[];faces=[]
 for ob in bpy.context.scene.objects:
  if ob.type!='MESH' or ob.get('fmpl_render_only'):continue
  me=ob.data;me.calc_loop_triangles();offset=len(verts);verts.extend(ob.matrix_world@v.co for v in me.vertices);faces.extend(tuple(offset+j for j in t.vertices) for t in me.loop_triangles)
 tree=BVHTree.FromPolygons(verts,faces,all_triangles=True);tests=[]
 for route in routes:
  for terminal in ('start','end'):
   p=Vector(route['request'][terminal+'_socket']['xyz']);probes=[(0,0)]+[(r*math.cos(k*math.tau/n),r*math.sin(k*math.tau/n)) for r,n in ((.006,8),(.0135,16)) for k in range(n)]
   hits=[]
   for dy,dz in probes:
    start=Vector((p.x+.001,p.y+dy,p.z+dz));end=Vector((1.80,p.y+dy,p.z+dz));hit=tree.ray_cast(start,Vector((-1,0,0)),(end-start).length-.002)
    if hit[0] is not None:hits.append(dict(offset=[dy,dz],location=list(hit[0])))
   tests.append(dict(route=route['request']['id'],terminal=terminal,rays=len(probes),clear_radius=.0135,blocked=hits,passed=not hits))
 results.append(dict(kind=kind,tests=tests,passed=all(t['passed'] for t in tests)))
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();r=dict(passed=all(x['passed'] for x in results),source_sha256=h(O/'advanced-space-cargo-v01.blend'),export_sha256=h(O/'advanced-space-cargo-v01.glb'),results=results,scope='25axial rays at each of8real receiver entries, through all scene physical meshes into the reservoir/pump cavity, source and actual GLB. Visible route centerlines are true hollow Pipette meshes; not a pressure/flow simulation.')
(O/'pump-bore-audit.json').write_text(json.dumps(r,indent=2)+'\n');print('PUMP_SOURCE_AND_EXPORT_BORE_PASS',r['passed']);assert r['passed']
