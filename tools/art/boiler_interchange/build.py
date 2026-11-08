"""Build a static cold-pose interchange branch; never overwrite sprite authority."""
import argparse,bpy,hashlib,json,math,pathlib,sys
from mathutils import Vector
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('directory',type=pathlib.Path);parser.add_argument('--source',type=pathlib.Path,required=True);args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
out=args.directory.resolve();out.mkdir(parents=True,exist_ok=False)
source=args.source.resolve();digest=hashlib.sha256(source.read_bytes()).hexdigest()
assert digest=='eb6aad420f04d7ca3b13933fb0323228252d569233690bac5b2c87bb3751a93d'
bpy.ops.wm.open_mainfile(filepath=str(source))
s=bpy.context.scene;s.frame_set(0);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
parts=[];excluded=[];snapshots=[];hidden=[]
for o in list(s.objects):
 if o.type!='MESH':continue
 if o.hide_render or any(c.hide_render for c in o.users_collection):
  excluded.append(o.name);hidden.append(o);continue
 ev=o.evaluated_get(dg);m=ev.to_mesh(preserve_all_data_layers=True,depsgraph=dg).copy();ev.to_mesh_clear()
 snapshots.append((o,m,o.matrix_world.copy()))
for o in hidden:bpy.data.objects.remove(o,do_unlink=True)
for o,m,world in snapshots:
 m.calc_loop_triangles()
 world=o.matrix_world.copy();verts=[v.co.copy() for v in m.vertices];uv=m.uv_layers.active
 normals=[n.vector.copy() for n in m.corner_normals];triangles=[];removed=0;old_area=0
 for t in m.loop_triangles:
  p=[world@verts[v] for v in t.vertices];area=(p[1]-p[0]).cross(p[2]-p[0]).length/2
  if area<1e-10 or min((p[i]-p[(i+1)%3]).length for i in range(3))<1e-6:removed+=1;continue
  old_area+=area
  triangles.append((tuple(t.vertices),t.material_index,t.use_smooth,[tuple(uv.data[l].uv) for l in t.loops] if uv else None,[tuple(normals[l]) for l in t.loops]))
 mesh=bpy.data.meshes.new(o.name+' evaluated interchange');mesh.from_pydata(verts,[],[t[0] for t in triangles]);mesh.update()
 for mat in m.materials:mesh.materials.append(mat)
 layer=mesh.uv_layers.new(name=uv.name if uv else 'Axial pipe fitting unwrap')
 # Existing UVs remain exact. New fittings unwrap around X; end faces use planar YZ.
 coords=[world@v for v in verts];center_y=(min(p.y for p in coords)+max(p.y for p in coords))/2;center_z=(min(p.z for p in coords)+max(p.z for p in coords))/2
 span_x=max(p.x for p in coords)-min(p.x for p in coords);min_x=min(p.x for p in coords)
 uv_repaired=0
 for poly,t in zip(mesh.polygons,triangles):
  poly.material_index=t[1];poly.use_smooth=t[2]
  if t[3]:values=t[3]
  else:
   points=[coords[v] for v in t[0]];normal=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
   if abs(normal.x)>.85:values=[(.5+(p.y-center_y)/1.6,.5+(p.z-center_z)/1.6) for p in points]
   else:
    angles=[math.atan2(p.z-center_z,p.y-center_y)/(2*math.pi)+.5 for p in points]
    if max(angles)-min(angles)>.5:angles=[u+1 if u<.5 else u for u in angles]
    values=[((p.x-min_x)/max(span_x,.001),u) for p,u in zip(points,angles)]
  a=[float(values[1][i])-float(values[0][i]) for i in range(2)];b=[float(values[2][i])-float(values[0][i]) for i in range(2)]
  uv_short=min(math.dist(values[i],values[(i+1)%3]) for i in range(3))
  if abs(a[0]*b[1]-a[1]*b[0])/2<=1e-10 or uv_short<1e-6:
   # Rebuild collapsed UV faces at a fixed 0.5-model-unit repeat scale.
   points=[coords[v] for v in t[0]];n=(points[1]-points[0]).cross(points[2]-points[0]).normalized();axis=max(range(3),key=lambda i:abs(n[i]));axes=[i for i in range(3) if i!=axis]
   values=[(p[axes[0]]*2+.5,p[axes[1]]*2+.5) for p in points];uv_repaired+=1
  for li,value in zip(poly.loop_indices,values):layer.data[li].uv=value
 mesh.normals_split_custom_set([n for t in triangles for n in t[4]])
 new_uv=uv is None
 o.parent=None;o.matrix_world=world;o.modifiers.clear();o.constraints.clear();o.animation_data_clear();o.data=mesh
 parts.append({'name':o.name,'triangles':len(triangles),'collapsed_or_numerical_sliver_triangles_removed':removed,'surviving_surface_area':old_area,'new_axial_uv':new_uv,'collapsed_uv_triangles_reprojected':uv_repaired})
 bpy.data.meshes.remove(m)
# Clear inherited material emission F-curves at the frozen cold pose.
for m in bpy.data.materials:
 if m.node_tree:m.node_tree.animation_data_clear()
root=bpy.data.objects.new('Boiler model frame',None);s.collection.objects.link(root)
root['source_sha256']=digest;root['pose']='cold frame 0; static interchange only'
for o in list(s.objects):
 if o.type=='MESH':world=o.matrix_world.copy();o.parent=root;o.matrix_world=world
sockets={'water':((-1,.5,.36),(-1,0,0)),'steam':((1,.5,.36),(1,0,0)),'circuit_mount':((.6671270728111267,.9216609597206116,.8431828022003174),(0,0,1))}
for name,(pos,normal) in sockets.items():
 o=bpy.data.objects.new('socket_'+name,None);s.collection.objects.link(o);o.parent=root;o.location=pos;o.rotation_euler=Vector(normal).to_track_quat('Z','Y').to_euler();o['identity']=name;o['coordinate_frame']='Blender model units; X right, Y rear, Z up; fixed model attachment, not Factorio fluidbox declaration'
for o in s.objects:o.select_set(o.type=='MESH' or o==root or o.name.startswith('socket_'))
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(out/'boiler-v08-cold.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_extras=True,export_yup=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'boiler-v08-cold-interchange.blend'),compress=True)
report={'status':'CANDIDATE_EXPORTED_REQUIRES_INDEPENDENT_INSPECTION','source_sha256':digest,'builder_sha256':hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),'scope':'Static cold-pose interchange branch, not replacement sprite/animation authority. Existing animation/render source stays untouched.','parts':parts,'excluded_hidden_reference_and_effect_objects':excluded,'sockets':{k:{'position':p,'outward':n} for k,(p,n) in sockets.items()},'native_sha256':hashlib.sha256((out/'boiler-v08-cold-interchange.blend').read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256((out/'boiler-v08-cold.glb').read_bytes()).hexdigest()}
(out/'build-receipt.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('EXPORTED',len(parts),'MESHES',sum(p['triangles'] for p in parts),'TRIANGLES','REMOVED',sum(p['collapsed_or_numerical_sliver_triangles_removed'] for p in parts),'NEW_UV',sum(p['new_axial_uv'] for p in parts),'UV_REPAIRED',sum(p['collapsed_uv_triangles_reprojected'] for p in parts),flush=True)
