import bpy,json,math,hashlib,numpy as np
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parent;A=R/'interchange-v01';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.fps=48;bpy.ops.import_scene.gltf(filepath=str(A/'miner-v25-physical.glb'))
meshes=[o for o in s.objects if o.type=='MESH'];ref=json.loads((A/'source-pose-reference.json').read_text());errors=[];max_error=0
def bounds(o):
 e=o.evaluated_get(bpy.context.evaluated_depsgraph_get());m=e.to_mesh();vs=[e.matrix_world@v.co for v in m.vertices];e.to_mesh_clear();return[[min(v[i]for v in vs)for i in range(3)],[max(v[i]for v in vs)for i in range(3)]]
for frame,objects in ref['poses'].items():
 s.frame_set(int(frame)-1);bpy.context.view_layer.update()
 for name,b in objects.items():
  o=bpy.data.objects.get(name)
  if not o or o.type!='MESH':errors.append('Missing mesh '+name);continue
  err=float(np.max(np.abs(np.array(bounds(o))-np.array(b))));max_error=max(max_error,err)
  if err>2e-5:errors.append('Pose bounds '+name+' frame '+frame+' error '+str(err))
geometry={'triangles':0,'nonfinite_vertices':0,'zero_area_triangles':0,'nonfinite_uv':0,'zero_area_uv_triangles':0,'missing_uv_meshes':[]}
for o in meshes:
 m=o.data;m.calc_loop_triangles();geometry['triangles']+=len(m.loop_triangles);geometry['nonfinite_vertices']+=sum(not all(math.isfinite(x)for x in v.co)for v in m.vertices)
 uv=m.uv_layers.active
 if not uv:geometry['missing_uv_meshes'].append(o.name);continue
 for t in m.loop_triangles:
  if t.area<1e-14:geometry['zero_area_triangles']+=1
  a,b,c=[uv.data[i].uv for i in t.loops]
  if not all(math.isfinite(x)for v in [a,b,c]for x in v):geometry['nonfinite_uv']+=1
  if abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))<1e-14:geometry['zero_area_uv_triangles']+=1
channels=[];pixel_cache={}
def pixels(im):
 if im.name not in pixel_cache:
  a=np.empty(len(im.pixels),dtype=np.float32);im.pixels.foreach_get(a);pixel_cache[im.name]=a.reshape(-1,4)
 return pixel_cache[im.name]
for m in bpy.data.materials:
 if not m.use_nodes:continue
 nt=m.node_tree;p=next((n for n in nt.nodes if n.type=='BSDF_PRINCIPLED'),None)
 if not p:continue
 def trace(sock,seen=None):
  seen=seen or set();res=[]
  for link in sock.links:
   n=link.from_node
   if n.name in seen:continue
   seen.add(n.name)
   if n.type=='TEX_IMAGE'and n.image:res.append(n.image)
   else:
    for i in n.inputs:res+=trace(i,seen)
  return res
 row={'material':m.name,'channels':{}}
 for label,socket,source,channel in [('base','Base Color','albedo',None),('roughness','Roughness','orm',1),('metallic','Metallic','orm',2),('normal','Normal','normal',None)]:
  ims=trace(p.inputs[socket]);assert ims,(m.name,label)
  orig=bpy.data.images.load(str(A/'textures'/ (source+'.png')),check_existing=True);a=pixels(orig);best=1e10
  for im in ims:
   b=pixels(im)
   if a.shape!=b.shape:continue
   diff=float(np.max(np.abs(a[:,:3]-b[:,:3])))if channel is None else float(np.max(np.abs(a[:,channel]-b[:,channel])))
   best=min(best,diff)
  row['channels'][label]={'max_pixel_error':best,'images':[i.name for i in ims]};assert best<.01,(m.name,label,best)
 channels.append(row)
s.frame_set(0);s.render.engine='CYCLES';s.cycles.samples=16;s.render.resolution_x=512;s.render.resolution_y=512;s.render.resolution_percentage=100;s.render.film_transparent=True;s.use_nodes=False
s.world=bpy.data.worlds.new('Neutral inspection world');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.2,.2,.2,1)
for loc,power,size in [((-2,-3,4),350,4),((2,-1,2),120,3),((0,3,4),250,3)]:
 data=bpy.data.lights.new('Review area','AREA');data.energy=power;data.shape='DISK';data.size=size;o=bpy.data.objects.new('Review area',data);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.3))-o.location).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.objects.new('Actual export review camera',bpy.data.cameras.new('Actual export review camera'));s.collection.objects.link(cam);s.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=1.42
for tag,y in [('front',-2.12132),('rear',2.12132)]:
 cam.location=(0,y,2.41132);cam.rotation_euler=(Vector((0,0,.29))-cam.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(A/('actual-glb-'+tag+'.png'));bpy.ops.render.render(write_still=True)
clay=bpy.data.materials.new('Neutral inspection clay');clay.use_nodes=True;clay.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.4,.4,.4,1);clay.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.7;s.view_layers[0].material_override=clay;cam.location=(1.5,-2,1.6);cam.rotation_euler=(Vector((0,0,.29))-cam.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(A/'actual-glb-clay.png');bpy.ops.render.render(write_still=True)
report={'source_sha256':sha(A/'miner-v25-image-materials.blend'),'runtime_sha256':sha(A/'miner-v25-physical.glb'),'meshes':len(meshes),'nine_source_runtime_pose_checks':True,'max_transformed_bounds_error':max_error,'pose_errors':errors,'geometry':geometry,'actual_export_pbr_pixel_checks':channels,'technical_checks_passed':not errors and not geometry['nonfinite_vertices']and not geometry['nonfinite_uv']and not geometry['missing_uv_meshes'],'scope':'Physical geometry and baked image/TRS interchange. Shader/light/steam animation remains in exact approved original and unchanged native sprites. Zero-area counts are disclosed, not silently treated as clean geometry.'}
(A/'runtime-inspection.json').write_text(json.dumps(report,indent=2));assert report['technical_checks_passed'];print('MINER_ACTUAL_RUNTIME_INSPECTED')
