"""V10 non-destructive bevel and shading refinement of the V09 visual asset."""
import bpy,math,json,os,hashlib
from pathlib import Path
from mathutils import Vector
O=Path('art/source-to-3d/martian-bunker/alternatives/v10').resolve();O.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(O.parent/'v09/six_lobber_sensor_fit_v09.blend'))
S=bpy.context.scene;col=bpy.data.collections['SIX_LOBBER_LOOSE_GRENADE_LOADERS'];fin=bpy.data.objects['CENTRAL_FIN']
def signature(o):
 return hashlib.sha256(repr(([tuple(v.co) for v in o.data.vertices],list(map(tuple,o.matrix_world)),[m.name for m in o.data.materials],[[tuple(t.uv) for t in l.data] for l in o.data.uv_layers])).encode()).hexdigest()
original={o.name:signature(o) for o in col.objects if o.type=='MESH'};changes=[]
for o in list(col.objects):
 if o.type!='MESH' or len(o.data.vertices)<4:continue
 name=o.name
 # Grenade props already have tiny deliberate segment edges; retain them.
 if name.startswith(('PRESENTED_','HATCH_EXIT_PROP_')):continue
 bounds=[max(v.co[i] for v in o.data.vertices)-min(v.co[i] for v in o.data.vertices) for i in range(3)]
 smallest=min(x for x in bounds if x>1e-5)
 if name.startswith('CONTINUOUS_SEGMENTED_RUBBER_TRACK'):
  bevels=[m for m in o.modifiers if m.type=='BEVEL']
  for m in bevels:m.segments=3;m.harden_normals=True
  changes.append({'name':name,'detail':'rubber segment edge smoothing; original width retained'})
  continue
 if name.startswith(('OPTIC_RECESSED_GLASS','BARREL_OPTIC_GLASS','REAR_STATUS_LAMP','HATCH_RECESSED_DARK_BACK','HOPPER_DARK_THROAT')):continue
 if name.startswith('SLOPED_EXIT_CHUTE'):width=.0023
 elif name.startswith('OPEN_MECHANICAL_HOPPER'):width=.0024
 elif name.startswith('HATCH_FRAME'):width=.0032
 elif name=='CENTRAL_FIN':width=.010
 elif name=='CENTRAL_AMMUNITION_ARMOURED_SPINE':width=.012
 elif name.startswith(('ROOF_OPTICAL_HEAD','CENTRAL_ARM_','CENTRAL_FEED_')):width=min(.012,smallest*.12)
 elif name.startswith('BARREL_INSTRUMENT'):width=.007
 elif name.startswith(('CAST_CANNON','ROUNDED_MUZZLE','BOTTOM_FEED','FIN_TO_CANNON')):width=.0025
 elif name.startswith(('ANTENNA','SHORT_ANTENNA','REAR_SENSOR_CABLE','INSTRUMENT_CABLE','CABLE_BRASS_CLIP')):width=min(.0015,smallest*.10)
 else:width=min(.006,smallest*.12)
 bevels=[m for m in o.modifiers if m.type=='BEVEL']
 if not bevels:bevels=[o.modifiers.new('Refined exposed edge bevel','BEVEL')]
 for m in bevels:
  m.width=width;m.segments=4 if width>=.006 else 3;m.limit_method='ANGLE';m.angle_limit=math.radians(35);m.use_clamp_overlap=True;m.harden_normals=True;m.profile=.5
 # Normals must be evaluated after the solidified and bevelled surface.
 for m in list(o.modifiers):
  if m.type=='WEIGHTED_NORMAL':o.modifiers.remove(m)
 normal=o.modifiers.new('Refined area weighted corner normals','WEIGHTED_NORMAL');normal.keep_sharp=True;normal.weight=50
 # Smooth curved castings, ferrules and aerials while retaining planar edges.
 import bmesh
 bm=bmesh.new();bm.from_mesh(o.data)
 for face in bm.faces:face.smooth=True
 for edge in bm.edges:
  if len(edge.link_faces)==2:edge.smooth=edge.calc_face_angle(0)<math.radians(45)
  else:edge.smooth=False
 bm.to_mesh(o.data);bm.free();o.data.update()
 changes.append({'name':name,'bevel_width':width,'segments':bevels[0].segments})
bpy.context.view_layer.update()
# Positions, UVs, source vertices and material assignments are preserved.
for name,sig in original.items():assert signature(bpy.data.objects[name])==sig,name
report={'revision':'V10 bevel and shading refinement','source_vertices_positions_materials_and_UVs_preserved':True,'non_destructive_modifiers':True,'refined_objects':changes,'existing_bunker_modified':False,'cannon_conveyor_and_hatch_layout_preserved':True}
S.render.resolution_x=S.render.resolution_y=int(os.getenv('LOADER_RENDER_SIZE','1200'));S.render.resolution_percentage=100;S.cycles.samples=int(os.getenv('LOADER_RENDER_SAMPLES','40'));S.cycles.use_denoising=True;cam=S.camera
views=[('oblique',(-4,-6,4.8),(0,.15,3.02),4.05),('rear',(-4,5,4.5),(0,.28,3.02),4.05),('front',(0,-7,3.6),(0,.2,3.02),4.05),('detail',(-3,-3,5.5),(-.20,.24,3.35),1.65),('sensor_detail',(-3,-4,5.5),(0,.45,3.98),1.35)]
for i,(name,pos,target,scale) in enumerate(views):
 cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
 if i==0:bpy.ops.wm.save_as_mainfile(filepath=str(O/'six_lobber_refined_v10.blend'),compress=True)
 S.render.filepath=str(O/('refined_v10_'+name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action='DESELECT')
for o in col.objects:o.select_set(True)
bpy.context.view_layer.objects.active=fin;bpy.ops.export_scene.gltf(filepath=str(O/'six_lobber_refined_v10.glb'),use_selection=True,export_format='GLB',export_apply=True,export_animations=False)
n=sum(o.type=='MESH' for o in col.objects)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(O/'six_lobber_refined_v10.glb'));assert sum(o.type=='MESH' for o in bpy.context.scene.objects)==n
report['GLB_reimported']=True;report['mesh_count']=n;(O/'model_validation.json').write_text(json.dumps(report,indent=2));print('V10_REFINEMENT_AND_EXPORT_PASS')
