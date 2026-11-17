import bpy,json,hashlib,math,struct,sys
import numpy as np
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent;R=next((p for p in O.parents if (p/'tech-priests_src').is_dir()),O.parents[2]);TP=R if (R/'tech-priests_src').is_dir() else R.parent/'model-production'
sys.path.insert(0,str(TP/'tools/fmpl'))
from blender_camera_guard import install_canonical_camera,temporary_inspection_camera
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def snap():
 d={};dg=bpy.context.evaluated_depsgraph_get()
 for o in bpy.context.scene.objects:
  if o.type!='MESH':continue
  ev=o.evaluated_get(dg);m=ev.to_mesh();m.calc_loop_triangles();pts=np.array([tuple(ev.matrix_world@v.co) for v in m.vertices])
  d[o.name]={'min':pts.min(0).tolist(),'max':pts.max(0).tolist(),'finite':bool(np.isfinite(pts).all()),'uv':bool(m.uv_layers),'degenerates':sum(t.area<1e-12 for t in m.loop_triangles),'triangles':len(m.loop_triangles)};ev.to_mesh_clear()
 return d
source=O/'sterling-v03.blend';runtime=O/'sterling-v03.glb';profile=json.loads((O/'capture-profile.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;poses={}
for f in [0,1,25,49,73,97]:s.frame_set(f);poses[f]=snap()
packed=[i.name for i in bpy.data.images if i.users and i.type=='IMAGE' and i.packed_file];unpacked=[i.name for i in bpy.data.images if i.users and i.type=='IMAGE' and not i.packed_file]
b=runtime.read_bytes();length,kind=struct.unpack_from('<II',b,12);assert kind==0x4e4f534a;gltf=json.loads(b[20:20+length]);first=min(gltf['accessors'][x['input']]['min'][0] for a in gltf['animations'] for x in a['samplers'])
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.fps=24;bpy.ops.import_scene.gltf(filepath=str(runtime));actual={};errors={}
for f in poses:
 t=first+f;s.frame_set(math.floor(t),subframe=t-math.floor(t));actual[f]=snap();assert set(actual[f])==set(poses[f]);errors[f]=max(abs(poses[f][n][k][i]-actual[f][n][k][i]) for n in poses[f] for k in ['min','max'] for i in range(3))
deg={n:o['degenerates'] for n,o in actual[1].items() if o['degenerates']};bad=[n for n,o in actual[1].items() if not o['finite'] or not o['uv']]
seam=max(abs(poses[1][n][k][i]-poses[97][n][k][i]) for n in poses[1] for k in ['min','max'] for i in range(3))
report={'technical_checks_passed':max(errors.values())<.001 and not deg and not bad and not unpacked and seam<.0001,'source_sha256':sha(source),'runtime_sha256':sha(runtime),'mesh_count':len(actual[1]),'triangles':sum(x['triangles'] for x in actual[1].values()),'source_runtime_six_pose_bounds_errors':errors,'degenerates':deg,'bad_finite_or_uv':bad,'source_packed_images':len(packed),'source_unpacked_images':unpacked,'runtime_embedded_images':len(gltf.get('images',[])),'runtime_external_images':[i for i in gltf.get('images',[]) if 'uri' in i],'working_loop_seam_error':seam,'full_clearance_audit_pending':True,'native_integration':False,'owner_visual_approved':False}
(O/'runtime-inspection.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print('STERLING_RUNTIME_INSPECTION',json.dumps(report),flush=True);assert report['technical_checks_passed'],report
install_canonical_camera(s,profile,bpy);s.render.engine='CYCLES';s.cycles.samples=32;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
s.world=bpy.data.worlds.new('Sterling actual GLB neutral studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.28,.28,.28,1)
for loc,power,size in [((2,-4,6),900,5),((-4,2,4),600,4)]:
 l=bpy.data.lights.new('Actual GLB review area','AREA');l.energy=power;l.size=size;o=bpy.data.objects.new(l.name,l);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.7))-o.location).to_track_quat('-Z','Y').to_euler()
root=bpy.data.objects['EXPORT | Sterling actual boiler'];projection=bpy.data.objects.new('REVIEW ONLY | square ground projection',None);s.collection.objects.link(projection);projection.scale.y=math.sqrt(2);root.parent=projection;s.frame_set(int(first+25));s.render.resolution_x=s.render.resolution_y=512;s.render.filepath=str(O/'actual-glb-front.png');bpy.ops.render.render(write_still=True)
with temporary_inspection_camera(s,bpy,'Sterling actual GLB alternate review') as camera:
 target=Vector((0,0,.8));camera.data.type='ORTHO';camera.data.ortho_scale=5.1;camera.location=(4,-6,4);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();s.camera=camera;s.render.filepath=str(O/'actual-glb-detail.png');bpy.ops.render.render(write_still=True)
print('STERLING_ACTUAL_EXPORT_PASS',flush=True)
