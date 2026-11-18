import bpy,json,sys,struct,hashlib,math
import numpy as np
from pathlib import Path
from mathutils import Vector
A=Path(__file__).resolve().parent;repo=next(c for p in[A,*A.parents]for c in(p,p/'model-production')if(c/'tools/fmpl/FMPL.json').is_file());sys.path.insert(0,str(repo/'tools/fmpl'))
from blender_camera_guard import install_canonical_camera,temporary_inspection_camera
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();source=A/'power-grid-v02.blend';runtime=A/'power-grid-v02.glb'
def snap():
 out={};dg=bpy.context.evaluated_depsgraph_get()
 for o in bpy.context.scene.objects:
  if o.type!='MESH':continue
  ev=o.evaluated_get(dg);m=ev.to_mesh();m.calc_loop_triangles();v=np.array([tuple(ev.matrix_world@q.co)for q in m.vertices]);uv=m.uv_layers.active;bad_uv=0
  if uv:
   for tri in m.loop_triangles:
    q=[np.array(uv.data[i].uv)for i in tri.loops];x=q[1]-q[0];y=q[2]-q[0];bad_uv+=int(abs(x[0]*y[1]-x[1]*y[0])<1e-12)
  out[o.name]={'min':v.min(0).tolist(),'max':v.max(0).tolist(),'finite':bool(np.isfinite(v).all()),'uv':bool(uv),'degenerate_uv_triangles':bad_uv,'degenerate_triangles':sum(t.area<1e-12 for t in m.loop_triangles),'triangles':len(m.loop_triangles)};ev.to_mesh_clear()
 return out
bpy.ops.wm.open_mainfile(filepath=str(source));before=snap();unpacked=[im.name for im in bpy.data.images if im.users and im.type=='IMAGE'and not im.packed_file];packed=[im.name for im in bpy.data.images if im.users and im.type=='IMAGE'and im.packed_file];assert not any(o.animation_data and o.animation_data.action for o in bpy.context.scene.objects)
b=runtime.read_bytes();n,k=struct.unpack_from('<II',b,12);g=json.loads(b[20:20+n]);assert not g.get('animations')
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(runtime));s=bpy.context.scene;after=snap();assert set(before)==set(after);error=max(abs(before[n][k][i]-after[n][k][i])for n in before for k in('min','max')for i in range(3));bad={n:r for n,r in after.items()if not r['finite']or not r['uv']or r['degenerate_uv_triangles']or r['degenerate_triangles']};missing=[m['name']for m in g['materials']if not(m.get('normalTexture')and m.get('pbrMetallicRoughness',{}).get('baseColorTexture')and m.get('pbrMetallicRoughness',{}).get('metallicRoughnessTexture'))]
report={'source_sha256':sha(source),'runtime_sha256':sha(runtime),'mesh_count':len(after),'triangles':sum(r['triangles']for r in after.values()),'source_runtime_bounds_error':error,'packed_source_images':len(packed),'unpacked_source_images':unpacked,'runtime_embedded_images':len(g['images']),'runtime_external_images':[im for im in g['images']if'uri'in im],'bad_meshes':bad,'materials_missing_pbr_maps':missing,'native_directions':[0],'animation_clips':0,'passive_fixed_pole_by_actual_native_contract':True,'owner_visual_approved':False};report['technical_checks_passed']=error<.0001 and not bad and not missing and not unpacked and not report['runtime_external_images'];(A/'runtime-inspection.json').write_text(json.dumps(report,indent=2));assert report['technical_checks_passed'],report
profile=json.loads((A/'capture-profile.json').read_text());install_canonical_camera(s,profile,bpy);s.render.engine='CYCLES';s.cycles.samples=32;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.resolution_x=s.render.resolution_y=640
s.world=bpy.data.worlds.new('Actual GLB pole review');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.25,.25,1)
for loc,power,size in[((2,-3,4),240,3),((-3,2,4),180,3)]:
 l=bpy.data.lights.new('Grid review studio','AREA');l.energy=power;l.size=size;o=bpy.data.objects.new(l.name,l);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.6))-o.location).to_track_quat('-Z','Y').to_euler()
root=bpy.data.objects['EXPORT | Emergency Power Grid'];proj=bpy.data.objects.new('UNSAVED square ground',None);s.collection.objects.link(proj);proj.scale.y=math.sqrt(2);root.parent=proj;s.render.filepath=str(A/'actual-glb-front.png');bpy.ops.render.render(write_still=True);proj.scale.y=1
with temporary_inspection_camera(s,bpy,'pole true proportions')as c:
 c.data.type='ORTHO';c.data.ortho_scale=2.1;c.location=(2,-3,2);c.rotation_euler=(Vector((0,0,.75))-c.location).to_track_quat('-Z','Y').to_euler();s.camera=c;s.render.filepath=str(A/'actual-glb-detail.png');bpy.ops.render.render(write_still=True)
 c.location=(-2,3,2);c.rotation_euler=(Vector((0,0,.75))-c.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(A/'actual-glb-rear.png');bpy.ops.render.render(write_still=True)
 clay=bpy.data.materials.new('UNSAVED neutral clay');clay.diffuse_color=(.5,.5,.5,1)
 for o in root.children_recursive:
  if o.type=='MESH':o.data.materials.clear();o.data.materials.append(clay)
 c.location=(2,-3,2);c.rotation_euler=(Vector((0,0,.75))-c.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(A/'actual-glb-clay.png');bpy.ops.render.render(write_still=True)
print('POWER_GRID_STATIC_RUNTIME_INSPECTION_PASS',flush=True)
