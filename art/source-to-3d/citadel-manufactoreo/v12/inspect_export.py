"""Independent actual GLB inspection; source poses are not accepted as runtime proof."""
import bpy,json,math,struct,hashlib,sys
import numpy as np
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent
def locate_repo():
 for parent in (O,*O.parents):
  for candidate in (parent,parent/'model-production'):
   if (candidate/'tools/fmpl/FMPL.json').is_file():return candidate
 raise FileNotFoundError('Pass a source checkout containing tools/fmpl and canonical material maps.')
sys.path.insert(0,str(locate_repo()/'tools/fmpl'))
from blender_camera_guard import install_canonical_camera,temporary_inspection_camera
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
source=O/'citadel-v12.blend';runtime=O/'citadel-v12.glb'
mesh_stats={};static_snapshots={}
def animated(o):
 while o:
  if o.animation_data and o.animation_data.action:return True
  o=o.parent
 return False

def snap():
 out={};dg=bpy.context.evaluated_depsgraph_get()
 for o in bpy.context.scene.objects:
  if o.type!='MESH':continue
  if not animated(o) and o.name in static_snapshots:
   out[o.name]=static_snapshots[o.name];continue
  ev=o.evaluated_get(dg);m=ev.to_mesh();m.calc_loop_triangles();p=np.array([tuple(ev.matrix_world@v.co) for v in m.vertices]);uv=m.uv_layers.active
  uv_bad=0
  if uv:
   for t in m.loop_triangles:
    q=[np.array(uv.data[i].uv) for i in t.loops];a=q[1]-q[0];b=q[2]-q[0]
    uv_bad+=int(abs(a[0]*b[1]-a[1]*b[0])<1e-12)
  out[o.name]={'min':p.min(0).tolist(),'max':p.max(0).tolist(),'finite':bool(np.isfinite(p).all()),'uv':bool(uv),'degenerate_uv_triangles':uv_bad,'degenerate_triangles':sum(t.area<1e-12 for t in m.loop_triangles),'triangles':len(m.loop_triangles)};ev.to_mesh_clear()
  if not animated(o):static_snapshots[o.name]=out[o.name]
 return out
bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene
# Reconcile the complete skin inventory from saved editable object properties.
# Earlier manifest placement preceded the last two geometry passes.
skin={}
for o in s.objects:
 zone=o.get('citadel_exterior_system')
 if not zone:continue
 rec=skin.setdefault(zone,{'zone':zone,'purpose':o['construction_purpose'],'objects':[],'mesh_count':0})
 rec['objects'].append(o.name);rec['mesh_count']+=o.type=='MESH'
manifest=json.loads((O/'greeble-skin-manifest.json').read_text());manifest.update(zones=list(skin.values()),total_added_meshes=sum(r['mesh_count']for r in skin.values()),inventory_reconciled_from_reopened_source=True)
(O/'greeble-skin-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
poses={}
for f in (1,17,33,65,97,129,161,193):s.frame_set(f);poses[f]=snap()
packed=[im.name for im in bpy.data.images if im.users and im.type=='IMAGE' and im.packed_file]
unpacked=[im.name for im in bpy.data.images if im.users and im.type=='IMAGE' and not im.packed_file]
b=runtime.read_bytes();size,kind=struct.unpack_from('<II',b,12);assert kind==0x4e4f534a;g=json.loads(b[20:20+size])
first=min(g['accessors'][x['input']]['min'][0] for a in g['animations'] for x in a['samplers']);last=max(g['accessors'][x['input']]['max'][0] for a in g['animations'] for x in a['samplers'])
static_snapshots.clear();bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.fps=48;bpy.ops.import_scene.gltf(filepath=str(runtime));errors={};actual={}
for f in poses:
 t=(first+(f-1)/48)*48;s.frame_set(math.floor(t),subframe=t%1);actual[f]=snap();assert set(actual[f])==set(poses[f])
 errors[f]=max(abs(poses[f][n][k][i]-actual[f][n][k][i]) for n in poses[f] for k in ('min','max') for i in range(3))
bad={n:r for n,r in actual[1].items() if not r['finite'] or not r['uv'] or r['degenerate_triangles'] or r['degenerate_uv_triangles']}
seam=max(abs(poses[1][n][k][i]-poses[193][n][k][i]) for n in poses[1] for k in ('min','max') for i in range(3))
missing_maps=[m.get('name') for m in g.get('materials',[]) if not all([m.get('normalTexture'),m.get('pbrMetallicRoughness',{}).get('baseColorTexture'),m.get('pbrMetallicRoughness',{}).get('metallicRoughnessTexture')])]
report={'source_sha256':sha(source),'runtime_sha256':sha(runtime),'mesh_count':len(actual[1]),'triangles':sum(r['triangles'] for r in actual[1].values()),'source_runtime_eight_pose_bounds_errors':errors,'working_loop_seam_error':seam,'packed_source_images':len(packed),'unpacked_source_images':unpacked,'runtime_embedded_images':len(g.get('images',[])),'runtime_external_images':[im for im in g.get('images',[]) if 'uri' in im],'bad_meshes':bad,'materials_missing_pbr_maps':missing_maps,'runtime_clip_seconds':last-first,'working_only_clip':True,'native_directions':[0],'full_clearance_adjudication_pending':True,'native_integration':False,'owner_visual_approved':False}
report['technical_checks_passed']=max(errors.values())<.0001 and seam<.0001 and not bad and not unpacked and not missing_maps and abs(last-first-4)<1e-6 and not report['runtime_external_images']
(O/'runtime-inspection.json').write_text(json.dumps(report,indent=2)+'\n');print('CITADEL_RUNTIME_INSPECTION',json.dumps(report),flush=True);assert report['technical_checks_passed']
profile=json.loads((O/'capture-profile.json').read_text());install_canonical_camera(s,profile,bpy);s.render.engine='CYCLES';s.cycles.samples=24;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.resolution_x=s.render.resolution_y=640
s.world=bpy.data.worlds.new('Void actual GLB review');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.28,.28,.28,1)
for loc,power,size in [((4,-7,9),1800,7),((-6,3,6),1400,6)]:
 l=bpy.data.lights.new('GLB review studio','AREA');l.energy=power;l.size=size;o=bpy.data.objects.new(l.name,l);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,1.7))-o.location).to_track_quat('-Z','Y').to_euler()
root=bpy.data.objects['EXPORT | Citadel Manufactureo'];projection=bpy.data.objects.new('UNSAVED runtime projection',None);s.collection.objects.link(projection);projection.scale.y=math.sqrt(2);root.parent=projection;s.frame_set(24)
s.render.filepath=str(O/'actual-glb-front.png');bpy.ops.render.render(write_still=True)
projection.scale.y=1.0  # Oblique inspection must show undistorted world proportions.
with temporary_inspection_camera(s,bpy,'Void actual GLB joints') as camera:
 target=Vector((0,0,2));camera.data.type='ORTHO';camera.data.ortho_scale=8.6;camera.location=(6,-8,6);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();s.camera=camera;s.render.filepath=str(O/'actual-glb-detail.png');bpy.ops.render.render(write_still=True)
 camera.location=(-6,8,6);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(O/'actual-glb-rear.png');bpy.ops.render.render(write_still=True)
 clay=bpy.data.materials.new('UNSAVED neutral clay');clay.use_nodes=True;clay.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.35,.35,.35,1)
 for o in s.objects:
  if o.type=='MESH':o.data.materials.clear();o.data.materials.append(clay)
 camera.location=(6,-8,6);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(O/'actual-glb-clay.png');bpy.ops.render.render(write_still=True)
print('CITADEL_ACTUAL_EXPORT_PASS',flush=True)
