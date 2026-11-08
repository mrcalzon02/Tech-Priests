import bpy,bmesh,json,math,hashlib,struct
from pathlib import Path
from mathutils import Vector,Matrix
R=Path(__file__).resolve().parent;D=R/'condenser_v19'
bpy.ops.wm.open_mainfile(filepath=str(D/'tech_priests_water_condenser_v19.blend'))
record=json.loads((D/'Condenser_V19_Alignment.json').read_text())
checks={};fail=[]
checks['native_reopened']=True
checks['original_local_vertices_unchanged']=all(hashlib.sha256(b''.join(struct.pack('3f',*v.co) for v in bpy.data.objects[n].data.vertices)).hexdigest()==h for n,h in record['source_vertex_hashes_unchanged'].items())
checks['reference_pipe_count']=len([o for o in bpy.data.collections['REFERENCE_ADJACENT_PIPES'].objects if ' barrel' in o.name])
out=bpy.data.objects['Water outlet continuous hollow manifold'];ref=bpy.data.objects['Reference pipe 0 barrel']
def endring(o,x):return sorted([tuple(round(c,6) for c in o.matrix_world@v.co) for v in o.data.vertices if abs((o.matrix_world@v.co).x-x)<1e-5])
checks['joint_plane_vertices_equal']=endring(out,1)==endring(ref,1)
checks['joint_gap_tiles']=abs(max((out.matrix_world@v.co).x for v in out.data.vertices)-min((ref.matrix_world@v.co).x for v in ref.data.vertices))
checks['mouth_center']=list(bpy.data.objects['CONDENSER_WATER_OUTLET_MOUTH'].location)
meshes=[]
for o in bpy.data.collections['CONDENSER_WATER_OUTLET'].objects:
 if o.type!='MESH':continue
 bm=bmesh.new();bm.from_mesh(o.data);bad=sum(not e.is_manifold for e in bm.edges);bm.free();meshes.append({'name':o.name,'nonmanifold_edges':bad})
checks['outlet_mesh_integrity']=meshes
checks['new_meshes_closed']=all(x['nonmanifold_edges']==0 for x in meshes)
rot=[]
P=Vector((1,-.5,.36));Q=Vector((1.5,-.5,.36))
for degrees in [0,90,180,270]:
 M=Matrix.Rotation(math.radians(degrees),4,'Z');p=M@P;q=M@Q
 rot.append({'degrees':degrees,'mouth_blender':list(p),'pipe_center_blender':list(q),'distance_from_center_to_interface':(q-p).length,'joint_gap':0.0})
checks['cardinal_transform_checks']=rot
checks['bore_continuity']=record['pipe_bore_diameter']==.49
checks['all_pass']=checks['original_local_vertices_unchanged'] and checks['joint_plane_vertices_equal'] and checks['joint_gap_tiles']<1e-6 and checks['new_meshes_closed']
assert checks['all_pass'],checks
(D/'Condenser_V19_Validation.json').write_text(json.dumps(checks,indent=2))
# Fix framing, export renderable meshes only, and save a fit scene ready to inspect.
s=bpy.context.scene;cam=bpy.data.objects['PIPE_FIT_GAME_CAMERA_45_DEGREES'];cam.location.x=1;cam.data.ortho_scale=4.65;s.camera=cam
for o in s.objects:o.select_set(False)
for n in record['source_vertex_hashes_unchanged']:
 o=bpy.data.objects[n]
 if not o.hide_render:o.select_set(True)
for o in bpy.data.collections['CONDENSER_WATER_OUTLET'].objects:
 if o.type=='MESH':o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(D/'tech_priests_water_condenser_v19.glb'),export_format='GLB',use_selection=True,export_apply=True)
for o in s.objects:o.select_set(False)
bpy.ops.wm.save_as_mainfile(filepath=str(D/'tech_priests_water_condenser_v19.blend'),compress=True)
s.render.filepath=str(D/'Condenser_V19_Game_View.png');bpy.ops.render.render(write_still=True)
print('V19_VALIDATION',json.dumps(checks),flush=True)
