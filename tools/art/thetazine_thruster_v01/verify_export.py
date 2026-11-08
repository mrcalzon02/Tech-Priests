"""Compare actual native/exported triangles, avoiding float-sensitive unique-vertex counts."""
import bpy, hashlib, json, pathlib, sys
from mathutils import Vector, kdtree
r=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot():
 s=bpy.context.scene;bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();parts={}
 for o in s.objects:
  if o.type!='MESH':continue
  e=o.evaluated_get(dg);m=e.to_mesh();m.calc_loop_triangles();uv=m.uv_layers.active;assert uv is not None,o.name
  points=[o.matrix_world@v.co for v in m.vertices];triangles=[];area=0
  for t in m.loop_triangles:
   rows=[tuple(points[m.loops[li].vertex_index])+tuple(uv.data[li].uv) for li in t.loops]
   triangles.append({'corners':rows,'material':m.materials[t.material_index].name})
   a,b,c=[Vector(row[:3]) for row in rows];area+=(b-a).cross(c-a).length/2
  parts[o.name]={'triangles':triangles,'area':area,'bounds':[[min(p[i] for p in points) for i in range(3)],[max(p[i] for p in points) for i in range(3)]]};e.to_mesh_clear()
 sockets={name:{'position':list(bpy.data.objects['socket_'+name].matrix_world.translation),'outward':list((bpy.data.objects['socket_'+name].matrix_world.to_3x3()@Vector((0,0,1))).normalized())} for name in ['fuel','oxidizer']}
 images=[{'name':i.name,'size':list(i.size),'packed':bool(i.packed_file)} for i in bpy.data.images if i.source=='FILE']
 assert len(images)==18 and all(i['packed'] and min(i['size'])>0 for i in images)
 return parts,sockets,images
bpy.ops.wm.open_mainfile(filepath=str(r/'thetazine-thruster-v01.blend'));native,sockets,images=snapshot()
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(r/'thetazine-thruster-v01.glb'));export,imported_sockets,imported_images=snapshot()
assert native.keys()==export.keys()
max_pos=max_uv=max_area=0;records=[]
def center(tri):return sum((Vector(row[:3]) for row in tri['corners']),Vector())/3
for name,part in native.items():
 other=export[name];a=part['triangles'];b=other['triangles'];assert len(a)==len(b),name
 tree=kdtree.KDTree(len(b))
 for i,tri in enumerate(b):tree.insert(center(tri),i)
 tree.balance();choices=[];errors={}
 for si,tri in enumerate(a):
  candidates=[]
  for _,bi,dist in tree.find_range(center(tri),1e-5):
   target=b[bi]
   if tri['material']!=target['material']:continue
   options=[]
   for rotation in range(3):
    delta=[[abs(tri['corners'][k][j]-target['corners'][(k+rotation)%3][j]) for j in range(5)] for k in range(3)]
    options.append((max(max(row[:3]) for row in delta),max(max(row[3:]) for row in delta)))
   good=[v for v in options if max(v)<1e-5]
   if good:
    error=min(good,key=max);errors[si,bi]=error;candidates.append((max(error),bi))
  choices.append([bi for _,bi in sorted(candidates)])
 owner={}
 def assign(si,seen):
  for bi in choices[si]:
   if bi in seen:continue
   seen.add(bi)
   if bi not in owner or assign(owner[bi],seen):owner[bi]=si;return True
  return False
 for si in range(len(a)):assert assign(si,set()),(name,'triangle position/UV/material/winding mismatch',si)
 assert len(owner)==len(b)
 for bi,si in owner.items():
  pos,uv=errors[si,bi];max_pos=max(max_pos,pos);max_uv=max(max_uv,uv)
 area=abs(part['area']-other['area']);assert area<1e-5,(name,area);max_area=max(max_area,area)
 records.append({'name':name,'triangles_matched':len(a),'native_bounds':part['bounds'],'imported_bounds':other['bounds'],'area_delta':area})
for name,v in sockets.items():
 for field in ['position','outward']:assert max(abs(a-b) for a,b in zip(v[field],imported_sockets[name][field]))<1e-6
report={'status':'PASS_ACTUAL_NATIVE_GLB_TRIANGLE_UV_MATERIAL_WINDING_AND_SOCKET_REIMPORT','native_sha256':sha(r/'thetazine-thruster-v01.blend'),'glb_sha256':sha(r/'thetazine-thruster-v01.glb'),'method':'One-to-one oriented triangle correspondence, including all three world positions, UVs and material. Bipartite matching resolves coincident triangles without trusting vertex deduplication or raw float uniqueness. Threshold 1e-5, area threshold 1e-5.','mesh_count':len(records),'triangle_count_each':sum(v['triangles_matched'] for v in records),'max_world_position_delta':max_pos,'max_uv_delta':max_uv,'max_part_area_delta':max_area,'native_sockets':sockets,'imported_sockets':imported_sockets,'packed_native_images':images,'imported_images':imported_images,'parts':records,'scope':'Static warm-idle interchange and named sockets only; no native game acceptance or GLB animation claim.'}
(r/'roundtrip-validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print('REIMPORT_PASS',len(records),report['triangle_count_each'],max_pos,max_uv,max_area)
