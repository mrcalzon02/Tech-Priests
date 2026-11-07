"""V11 fewer sensors, inset armour panels and recessed fastening detail."""
import bpy,math,json,os,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
O=Path('art/source-to-3d/martian-bunker/alternatives/v11').resolve();O.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(O.parent/'v10/six_lobber_refined_v10.blend'))
S=bpy.context.scene;col=bpy.data.collections['SIX_LOBBER_LOOSE_GRENADE_LOADERS'];fin=bpy.data.objects['CENTRAL_FIN'];pivot=bpy.data.objects['LOBBER_ELEVATION'];plane=bpy.data.objects['SYMMETRY_CENTRELINE_X0']
red=bpy.data.materials['FIN | existing oxide red tile'];iron=bpy.data.materials['CAST_IRON | existing dark gunmetal tile'];steel=bpy.data.materials['LOADER | grey steel'];inner=bpy.data.materials['CAST_IRON | dark bore interior']
def signature(o):return hashlib.sha256(repr(([tuple(v.co) for v in o.data.vertices],list(map(tuple,o.matrix_world)),[m.name for m in o.data.materials])).encode()).hexdigest()
removed=[]
for o in list(col.objects):
 if o.name.startswith(('BARREL_INSTRUMENT_','BARREL_OPTIC_','INSTRUMENT_CABLE_')):removed.append(o.name);bpy.data.objects.remove(o,do_unlink=True)
original={o.name:signature(o) for o in col.objects if o.type=='MESH'}
created=[]
helper=(O.parent/'v05/build_loose_loader.py').read_text();exec(helper[helper.index('def own('):helper.index('loaders=[]')])
def small_bevel(o,width=.002):
 for m in list(o.modifiers):
  if m.type=='BEVEL':o.modifiers.remove(m)
 m=o.modifiers.new('Small plate edge bevel','BEVEL');m.width=width;m.segments=3;m.harden_normals=True
 for m in list(o.modifiers):
  if m.type=='WEIGHTED_NORMAL':o.modifiers.remove(m)
 o.modifiers.new('Plate weighted normals','WEIGHTED_NORMAL');return o
def panel(name,C,u,v,width,height):
 C,u,v=Vector(C),Vector(u).normalized(),Vector(v).normalized();n=u.cross(v).normalized();R=Matrix((u,v,n)).transposed()
 def p(x,y,z):return C+u*x+v*y+n*z
 # A dark gasket, raised rim and lower inset face form a true layered recess.
 back=cube(name+'_RECESSED_GASKET',p(0,0,.003),(width,height,.006),inner);back.rotation_euler=R.to_euler();small_bevel(back,.0015)
 vs=[]
 for z in [.004,.014]:
  for w,h in [(width,height),(width-.027,height-.034)]:
   for x,y in [(-w/2,-h/2),(w/2,-h/2),(w/2,h/2),(-w/2,h/2)]:vs.append(tuple(p(x,y,z)))
 fs=[]
 for i in range(4):
  j=(i+1)%4;fs.extend([(i,j,j+8,i+8),(i+4,i+12,j+12,j+4),(i+8,j+8,j+12,i+12),(i+4,j+4,j,i)])
 small_bevel(mesh(name+'_PLATE_RIM',vs,fs,iron),.0018)
 insert=cube(name+'_INSET_OXIDE_FACE',p(0,0,.006),(width-.038,height-.045,.006),red);insert.rotation_euler=R.to_euler();small_bevel(insert,.002)
 for y in [-height*.39,height*.39]:
  # Recessed fastener seat plus restrained hex head.
  cylinder(name+'_FASTENER_RECESS',p(0,y,.010),p(0,y,.013),.012,inner)
  a=p(0,y,.013);b=p(0,y,.017);d=b-a
  bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=.007,depth=d.length,location=(a+b)/2);o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();own(o,name+'_HEX_FASTENER',steel);small_bevel(o,.0008)
# Three inset front plates follow the existing inclined fin segments.
profile=[Vector((0,.08,3.53)),Vector((0,-.12,3.104031)),Vector((0,-.37,2.653721)),Vector((0,-.65,2.191240))]
for i in range(3):
 top,bottom=profile[i],profile[i+1];v=(top-bottom).normalized();u=Vector((1,0,0));n=u.cross(v).normalized()
 panel('FRONT_FIN_ACCESS_PANEL_'+str(i+1),(top+bottom)/2+n*.005,u,v,.17,(top-bottom).length*.73)
# Side armour plates break up the large uninterrupted pillar surfaces.
for side in [-1,1]:
 for i,z in enumerate([2.24,2.84,3.43]):
  panel('PILLAR_SIDE_PANEL_%s_%d'%('L' if side<0 else 'R',i+1),(side*.332,.685,z),(0,side,0),(0,0,1),.235,.39)
# A recessed service panel on the back of the main optical housing.
panel('OPTICAL_HEAD_REAR_SERVICE',(0,.769,4.015),(-1,0,0),(0,0,1),.235,.135)
bpy.context.view_layer.update()
for name,sig in original.items():assert signature(bpy.data.objects[name])==sig,name
assert len(removed)==12,removed
assert not any(o.name.startswith(('BARREL_INSTRUMENT_','BARREL_OPTIC_','INSTRUMENT_CABLE_')) for o in col.objects)
bpy.ops.object.select_all(action='DESELECT')
for o in created:o.select_set(True)
bpy.context.view_layer.objects.active=created[0];bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')
report={'revision':'V11 reduced sensors and inset plating','individual_barrel_sensor_pods_removed':6,'removed_source_objects':removed,'main_optical_cluster_and_two_antennas_retained':True,'front_fin_inset_panels':3,'pillar_side_inset_panels':6,'optical_head_rear_service_panel':1,'recessed_faces_and_fastener_seats':True,'remaining_V10_source_geometry_materials_and_transforms_preserved':True,'cannons_conveyors_hatches_hoppers_preserved':True,'existing_bunker_modified':False}
S.render.resolution_x=S.render.resolution_y=int(os.getenv('LOADER_RENDER_SIZE','1200'));S.render.resolution_percentage=100;S.cycles.samples=int(os.getenv('LOADER_RENDER_SAMPLES','32'));cam=S.camera
views=[('oblique',(-4,-6,4.8),(0,.15,3.02),4.05),('rear',(-4,5,4.5),(0,.28,3.02),4.05),('front',(0,-7,3.6),(0,.2,3.02),4.05),('detail',(-3,-4,4.5),(0,-.2,2.9),1.75),('rear_detail',(-4,3,4.5),(-.18,.70,3.2),1.6)]
for i,(name,pos,target,scale) in enumerate(views):
 cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
 if i==0:bpy.ops.wm.save_as_mainfile(filepath=str(O/'six_lobber_inset_plating_v11.blend'),compress=True)
 S.render.filepath=str(O/('plating_v11_'+name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action='DESELECT')
for o in col.objects:o.select_set(True)
bpy.context.view_layer.objects.active=fin;bpy.ops.export_scene.gltf(filepath=str(O/'six_lobber_inset_plating_v11.glb'),use_selection=True,export_format='GLB',export_apply=True,export_animations=False)
n=sum(o.type=='MESH' for o in col.objects)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(O/'six_lobber_inset_plating_v11.glb'));assert sum(o.type=='MESH' for o in bpy.context.scene.objects)==n
report['GLB_reimported']=True;report['mesh_count']=n;(O/'model_validation.json').write_text(json.dumps(report,indent=2));print('V11_PLATING_AND_EXPORT_PASS')
