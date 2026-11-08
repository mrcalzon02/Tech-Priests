import bpy,hashlib,json,pathlib,sys,math
from mathutils import Vector,kdtree
out=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve()
def capture():
 s=bpy.context.scene;bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();parts={}
 for o in s.objects:
  if o.type!='MESH':continue
  ev=o.evaluated_get(dg);m=ev.to_mesh();m.calc_loop_triangles();uv=m.uv_layers.active;rows={};area=0;coords=[]
  assert uv is not None,o.name
  for v in m.vertices:coords.append(o.matrix_world@v.co)
  for t in m.loop_triangles:
   a,b,c=(coords[v] for v in t.vertices);area+=(b-a).cross(c-a).length/2
   for li in t.loops:
    p=coords[m.loops[li].vertex_index];u=uv.data[li].uv;mat=m.materials[t.material_index].name
    rows[(tuple(p)+tuple(u),mat)]=None
  parts[o.name]={'rows':list(rows),'triangles':len(m.loop_triangles),'area':area,'bounds':[[min(v[i] for v in coords) for i in range(3)],[max(v[i] for v in coords) for i in range(3)]]};ev.to_mesh_clear()
 sockets={}
 for name in ['water','steam','circuit_mount']:
  o=bpy.data.objects['socket_'+name];sockets[name]={'position':list(o.matrix_world.translation),'outward':list((o.matrix_world.to_3x3()@Vector((0,0,1))).normalized())}
 return parts,sockets
bpy.ops.wm.open_mainfile(filepath=str(out/'boiler-v08-cold-interchange.blend'));native,sockets=capture()
packed=[{'name':i.name,'packed':bool(i.packed_file),'size':list(i.size)} for i in bpy.data.images if i.source=='FILE'];assert all(i['packed'] and min(i['size'])>0 for i in packed)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(out/'boiler-v08-cold.glb'));export,imported_sockets=capture()
assert native.keys()==export.keys();delta_pos=delta_uv=delta_area=0;parts=[]
for name,part in native.items():
 other=export[name];assert part['triangles']==other['triangles'],name
 assert len(part['rows'])==len(other['rows']),(name,'unique corner count')
 values=other['rows'];tree=kdtree.KDTree(len(values))
 for i,(row,mat) in enumerate(values):tree.insert(row[:3],i)
 tree.balance();used=set()
 for row,mat in part['rows']:
  candidates=tree.find_range(row[:3],1e-5);found=None
  for _,idx,dist in candidates:
   target,tmat=values[idx]
   if idx not in used and mat==tmat and max(abs(row[k]-target[k]) for k in range(5))<1e-5:found=idx;break
  assert found is not None,(name,'position/UV/material mismatch',row,mat)
  used.add(found);target=values[found][0];delta_pos=max(delta_pos,max(abs(row[k]-target[k]) for k in range(3)));delta_uv=max(delta_uv,max(abs(row[k]-target[k]) for k in (3,4)))
 error=abs(part['area']-other['area']);delta_area=max(delta_area,error);assert error<1e-5,(name,error)
 parts.append({'name':name,'triangles':part['triangles'],'unique_position_uv_material_corners':len(part['rows']),'native_bounds':part['bounds'],'imported_bounds':other['bounds'],'surface_area_delta':error})
for name,point in sockets.items():
 for field in ['position','outward']:assert max(abs(a-b) for a,b in zip(point[field],imported_sockets[name][field]))<1e-6,(name,field)
images=[{'name':i.name,'size':list(i.size),'packed':bool(i.packed_file)} for i in bpy.data.images if i.source=='FILE'];assert images and all(min(i['size'])>0 and i['packed'] for i in images)
result={'status':'PASS_STATIC_COLD_MODEL_INDEPENDENT_REIMPORT','source_scope':'Static interchange branch; not a GLB animation acceptance or production sprite replacement.','native_sha256':hashlib.sha256((out/'boiler-v08-cold-interchange.blend').read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256((out/'boiler-v08-cold.glb').read_bytes()).hexdigest(),'parts':parts,'mesh_count':len(parts),'triangle_count_each':sum(p['triangles'] for p in parts),'max_world_position_delta':delta_pos,'max_uv_delta':delta_uv,'max_part_surface_area_delta':delta_area,'native_sockets':sockets,'imported_sockets':imported_sockets,'packed_native_images':packed,'imported_images':images}
(out/'roundtrip-validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print('REIMPORT_PASS',len(parts),result['triangle_count_each'],delta_pos,delta_uv,delta_area)
