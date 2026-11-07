"""V13 selected flat corner chamfers on the V12 visual asset."""
import bpy,math,json,os,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
O=Path('art/source-to-3d/martian-bunker/alternatives/v13').resolve();O.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(O.parent/'v12/six_lobber_corrugated_hoses_v12.blend'))
S=bpy.context.scene;col=bpy.data.collections['SIX_LOBBER_LOOSE_GRENADE_LOADERS'];fin=bpy.data.objects['CENTRAL_FIN']
def signature(o):return hashlib.sha256(repr(([tuple(v.co) for v in o.data.vertices],list(map(tuple,o.matrix_world)),[m.name for m in o.data.materials])).encode()).hexdigest()
targets=['ROOF_OPTICAL_HEAD','CENTRAL_AMMUNITION_ARMOURED_SPINE']
original={o.name:signature(o) for o in col.objects if o.type=='MESH' and o.name not in targets and not o.name.startswith('PILLAR_SIDE_PANEL_')}
records=[]
for name in targets:
 o=bpy.data.objects[name];vertices=[o.matrix_world@v.co for v in o.data.vertices];zmin=min(v.z for v in vertices);ymax=max(v.y for v in vertices);xmax=max(abs(v.x) for v in vertices);chosen=[]
 for edge in o.data.edges:
  a,b=[vertices[i] for i in edge.vertices]
  if name=='ROOF_OPTICAL_HEAD':
   select=abs(a.z-zmin)<1e-5 and abs(b.z-zmin)<1e-5 and abs(a.y-b.y)>.1
  else:
   select=abs(a.y-ymax)<1e-5 and abs(b.y-ymax)<1e-5 and abs(a.z-b.z)>1 and abs(abs(a.x)-xmax)<1e-5 and abs(abs(b.x)-xmax)<1e-5
  if select:chosen.append(edge.index)
 assert len(chosen)==2,(name,chosen)
 attr=o.data.attributes.get('bevel_weight_edge') or o.data.attributes.new(name='bevel_weight_edge',type='FLOAT',domain='EDGE')
 for e in o.data.edges:attr.data[e.index].value=1.0 if e.index in chosen else 0.0
 for modifier in o.modifiers:
  if modifier.type=='BEVEL':modifier.width=.003;modifier.segments=3
 m=o.modifiers.new('Selected flat corner chamfers','BEVEL');m.limit_method='WEIGHT';m.width=.032 if name=='ROOF_OPTICAL_HEAD' else .045;m.segments=1;m.use_clamp_overlap=True;m.harden_normals=True
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 for i in range(len(o.modifiers)-1):bpy.ops.object.modifier_move_up(modifier=m.name)
 records.append({'object':name,'selected_edge_indices':chosen,'flat_chamfer_width':m.width,'flat_chamfer_segments':m.segments,'small_edge_finish_width':.003})
# Narrow the side panel assemblies slightly so their rear rims sit ahead of
# the new rear cabinet chamfers. All geometry is retained as editable parts.
fit=Matrix.Translation((0,.685,0))@Matrix.Diagonal((1,.85,1,1))@Matrix.Translation((0,-.685,0))
adjusted=[]
for o in col.objects:
 if o.name.startswith('PILLAR_SIDE_PANEL_'):o.matrix_world=fit@o.matrix_world;adjusted.append(o.name)
bpy.context.view_layer.update()
for name,sig in original.items():assert signature(bpy.data.objects[name])==sig,name
report={'revision':'V13 selected corner chamfers','sensor_box_lower_left_and_right_corners_chamfered':True,'cabinet_rear_left_and_right_vertical_corners_chamfered':True,'corner_records':records,'side_panel_depth_fit_scale':.85,'adjusted_side_panel_parts':len(adjusted),'all_unrelated_geometry_materials_and_transforms_preserved':True,'corrugated_hoses_cannons_conveyors_hatches_preserved':True,'existing_bunker_modified':False}
S.render.resolution_x=S.render.resolution_y=int(os.getenv('LOADER_RENDER_SIZE','1100'));S.render.resolution_percentage=100;S.cycles.samples=int(os.getenv('LOADER_RENDER_SAMPLES','24'));cam=S.camera
views=[('oblique',(-4,-6,4.8),(0,.15,3.02),4.05),('rear',(-4,5,4.5),(0,.28,3.02),4.05),('sensor_detail',(-3,-4,4.7),(0,.63,4.02),.92),('cabinet_detail',(-4,4,3.7),(0,.69,2.96),2.30)]
for i,(name,pos,target,scale) in enumerate(views):
 cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
 if i==0:bpy.ops.wm.save_as_mainfile(filepath=str(O/'six_lobber_corner_chamfers_v13.blend'),compress=True)
 S.render.filepath=str(O/('chamfers_v13_'+name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action='DESELECT')
for o in col.objects:o.select_set(True)
bpy.context.view_layer.objects.active=fin;bpy.ops.export_scene.gltf(filepath=str(O/'six_lobber_corner_chamfers_v13.glb'),use_selection=True,export_format='GLB',export_apply=True,export_animations=False)
n=sum(o.type=='MESH' for o in col.objects)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(O/'six_lobber_corner_chamfers_v13.glb'));assert sum(o.type=='MESH' for o in bpy.context.scene.objects)==n
report['GLB_reimported']=True;report['mesh_count']=n;(O/'model_validation.json').write_text(json.dumps(report,indent=2));print('V13_SELECTED_CHAMFERS_AND_EXPORT_PASS')
