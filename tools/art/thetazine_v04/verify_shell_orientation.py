"""Independently measure actual source and reimported physical shell orientation."""
import bpy,bmesh,pathlib,sys,json,hashlib,collections
R=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();records=[]
for kind in ['source','actual_glb']:
 if kind=='source':bpy.ops.wm.open_mainfile(filepath=str(R/'thetazine-v04-regenerative-study.blend'))
 else:bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(R/'thetazine-v04-regenerative-study.glb'))
 bpy.context.scene.frame_set(17);bpy.context.view_layer.update();rows=[]
 for o in bpy.context.scene.objects:
  if o.type!='MESH' or not o.name.startswith(('Nozzle articulated petal','V04 interleaved containment seal')):continue
  ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get());original=ev.to_mesh();me=original;welded=None
  if kind=='actual_glb':
   # glTF splits coincident vertices for UV/material/normal seams. Test the
   # rendered geometric shell, not the deliberate interchange attribute split.
   bm=bmesh.new();bm.from_mesh(me);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6);welded=bpy.data.meshes.new('GLB seam-welded inspection only');bm.to_mesh(welded);bm.free();me=welded
  edges=collections.defaultdict(list)
  for p in me.polygons:
   for i in range(len(p.vertices)):
    a,b=p.vertices[i],p.vertices[(i+1)%len(p.vertices)];edges[tuple(sorted((a,b)))].append((a,b))
  assert all(len(v)==2 and v[0]!=v[1] for v in edges.values()),(kind,o.name,'closed oriented manifold edge failed');bm=bmesh.new();bm.from_mesh(me);volume=bm.calc_volume(signed=True);bm.free();assert volume>0,(kind,o.name,'not outward');assert o.matrix_world.determinant()>0;rows.append({'mesh':o.name,'positive_local_volume':volume,'edge_count':len(edges),'world_transform_determinant':o.matrix_world.determinant(),'import_attribute_seam_weld_tolerance':1e-6 if welded else 0});ev.to_mesh_clear()
  if welded:bpy.data.meshes.remove(welded)
 assert len(rows)==24;records.append({'kind':kind,'shells':rows})
out={'status':'PASS_24_NATIVE_AND_ACTUAL_GLB_OUTWARD_CLOSED_BELL_SHELLS','native_sha256':sha(R/'thetazine-v04-regenerative-study.blend'),'glb_sha256':sha(R/'thetazine-v04-regenerative-study.glb'),'records':records,'scope':'Every edge has two opposing directed uses, positive closed local volume and positive world transform determinant, actual evaluated source and imported GLB at17. Pose66 exact-surface preservation and full route clearance are separate receipts.'};(R/'shell-orientation-validation.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8',newline='\n');print(out['status'])
