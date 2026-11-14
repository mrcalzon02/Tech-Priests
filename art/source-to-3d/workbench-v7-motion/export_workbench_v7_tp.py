"""Local Tech-Priests candidate: recovered V7 motion, existing V6 ground-shadow/registration contract."""
import bpy,pathlib,json,hashlib,struct,math
W=pathlib.Path(__file__).resolve().parent; recovered=W/'workbench-v7-recovered-20261109'; source=recovered/'source/rough_timber_workbench_v4.blend'; candidate=W/'workbench-v7-local-proof/workbench_v7.blend'; O=W/'workbench-v7-tp-candidate';O.mkdir(exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def mesh_record(obj):
 m=obj.data;h=hashlib.sha256()
 for v in m.vertices:h.update(struct.pack('<3f',*v.co))
 for p in m.polygons:h.update(struct.pack('<I',len(p.vertices)));h.update(struct.pack('<'+'I'*len(p.vertices),*p.vertices));h.update(struct.pack('<I',p.material_index))
 for uv in m.uv_layers:
  for item in uv.data:h.update(struct.pack('<2f',*item.uv))
 return {'local_geometry_sha256':h.hexdigest(),'vertices':len(m.vertices),'polygons':len(m.polygons),'world_matrix':[list(r) for r in obj.matrix_world]}
bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.scene.frame_set(1);baseline={o.name:mesh_record(o) for o in bpy.context.scene.objects if o.type=='MESH'}
bpy.ops.wm.open_mainfile(filepath=str(candidate));s=bpy.context.scene;s.frame_set(1);root=bpy.data.objects['EXPORT_CARDINAL_ORIENTATION'];root.rotation_euler.z=0;bpy.context.view_layer.update();actual={o.name:mesh_record(o) for o in s.objects if o.type=='MESH'}
for name,old in baseline.items():
 assert actual[name]['local_geometry_sha256']==old['local_geometry_sha256'],name
 assert max(abs(actual[name]['world_matrix'][i][j]-old['world_matrix'][i][j]) for i in range(4) for j in range(4))<1e-6,(name,'rest transform')
ground=bpy.data.objects['Preview ground - excluded from asset'];ground.hide_render=False;ground.is_shadow_catcher=True
s.render.resolution_x=s.render.resolution_y=128;s.render.resolution_percentage=100;s.cycles.samples=16;s.cycles.use_denoising=False;s.render.threads_mode='FIXED';s.render.threads=4
assert s.camera.data.ortho_scale==2.0 and s.render.fps==24
report={'status':'PASS_ALL_ORIGINAL_V4_MESH_GEOMETRY_UV_AND_REST_TRANSFORMS','source_sha256':sha(source),'v7_local_source_sha256':sha(candidate),'original_meshes':len(baseline),'source_meshes':baseline,'scope':'Explicit geometry/UV/rest-transform comparison. Sheet heat material and hammer motion intentionally changed. Added sparks retained. Not an animated GLB proof.','render_contract':{'width':128,'height':128,'scale':.5,'shift':[0,-.63/math.sqrt(2)],'fps':12,'frames':96,'timeline_frames':list(range(2,193,2)),'columns':12,'rows':8,'shadow':'Existing Tech-Priests V6 transparent Cycles shadow catcher retained; differs from recovered runner no-ground frames.'}}
(O/'source-preservation.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(O/'workbench_v7_tp.blend'))
for d,name in enumerate(['north','east','south','west']):
 root.rotation_euler.z=-d*math.pi/2
 folder=O/'frames'/name;folder.mkdir(parents=True,exist_ok=True)
 for frame in range(2,193,2):
  p=folder/f'{frame:04d}.png'
  if p.exists():continue
  s.frame_set(frame);s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
 print('TP_V7_DIRECTION_COMPLETE',name,flush=True)
print('TP_V7_FULL_CAPTURE_READY',flush=True)
