"""V09 exterior sensor and antenna fit on preserved V08 game asset."""
import bpy,math,json,os,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
O=Path('art/source-to-3d/martian-bunker/alternatives/v09').resolve();O.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(O.parent/'v08/six_lobber_central_feed_v08.blend'))
S=bpy.context.scene;col=bpy.data.collections['SIX_LOBBER_LOOSE_GRENADE_LOADERS'];pivot=bpy.data.objects['LOBBER_ELEVATION'];plane=bpy.data.objects['SYMMETRY_CENTRELINE_X0'];fin=bpy.data.objects['CENTRAL_FIN']
red=bpy.data.materials['FIN | existing oxide red tile'];iron=bpy.data.materials['CAST_IRON | existing dark gunmetal tile'];steel=bpy.data.materials['LOADER | grey steel'];inner=bpy.data.materials['CAST_IRON | dark bore interior']
def signature(o):return hashlib.sha256(repr(([tuple(v.co) for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons],list(map(tuple,o.matrix_world)),[m.name for m in o.data.materials])).encode()).hexdigest()
original={o.name:signature(o) for o in col.objects if o.type=='MESH'}
created=[]
helper=(O.parent/'v05/build_loose_loader.py').read_text();exec(helper[helper.index('def own('):helper.index('loaders=[]')])
brass=matte('SENSORS | aged brass ferrules',(.29,.19,.065),.68,.65)
cable=matte('SENSORS | rubber cable sheath',(.015,.019,.016),.93)
lens=matte('SENSORS | dark teal optical glass',(.018,.105,.095),.24,.35)
p=lens.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=(.02,.18,.13,1);p.inputs['Emission Strength'].default_value=.25
amber=matte('SENSORS | amber indicator',(.27,.09,.008),.35,.15)
p=amber.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=(.5,.12,.006,1);p.inputs['Emission Strength'].default_value=.4
# Roof sensor head: compact armoured optical cluster.
cylinder('ROOF_SENSOR_PEDESTAL',(0,.685,3.80),(0,.685,3.93),.082,iron)
cube('ROOF_OPTICAL_HEAD',(0,.65,4.015),(.31,.23,.18),red)
cube('OPTICAL_HEAD_BROW',(0,.60,4.12),(.37,.33,.045),iron)
for x,r in [(-.082,.050),(.074,.034)]:
 cylinder('OPTIC_BRASS_BEZEL',(x,.530,4.025),(x,.507,4.025),r,brass)
 cylinder('OPTIC_RECESSED_GLASS',(x,.504,4.025),(x,.499,4.025),r*.77,lens)
# Compact individual barrel instruments on the forward exterior, away from guides.
for row in range(3):
 C=Vector((-.27,.04-.26*row,3.10-.38*row+{0:.28,1:.14,2:0}[row]))
 small_cube('BARREL_INSTRUMENT_RED_HOUSING_LEFT_'+str(row+1),(-.27,C.y-.166,C.z+.035),(.115,.075,.12),red)
 mirrored(cylinder('BARREL_OPTIC_BRASS_LEFT_'+str(row+1),(-.27,C.y-.205,C.z+.05),(-.27,C.y-.220,C.z+.05),.033,brass))
 mirrored(cylinder('BARREL_OPTIC_GLASS_LEFT_'+str(row+1),(-.27,C.y-.221,C.z+.05),(-.27,C.y-.224,C.z+.05),.024,lens))
 # Short attached cable into the cast barrel instrument socket.
 mirrored(cylinder('INSTRUMENT_CABLE_LEFT_'+str(row+1),(-.315,C.y-.17,C.z),(-.335,C.y-.10,C.z-.08),.009,cable))
# Two short aerials with visible insulated mounts. No extreme whips.
for i,(x,y,length) in enumerate([(-.235,.72,.55),(.235,.75,.38)]):
 cylinder('ANTENNA_BRASS_BASE_'+str(i),(x,y,3.80),(x,y,3.86),.041,brass)
 cylinder('ANTENNA_INSULATOR_'+str(i),(x,y,3.86),(x,y,3.96),.026,inner)
 cylinder('SHORT_ANTENNA_'+str(i),(x,y,3.96),(x,y,3.96+length),.008,steel)
 cylinder('ANTENNA_RUBBER_TIP_'+str(i),(x,y,3.95+length),(x,y,3.98+length),.012,cable)
# Rear control sensor package and exposed cable trunk.
cube('REAR_CONTROL_SENSOR_BOX',(0,.905,2.86),(.22,.09,.30),red)
for i in range(3):
 cylinder('REAR_STATUS_BRASS_'+str(i),(-.055+i*.055,.955,2.93),(-.055+i*.055,.968,2.93),.018,brass)
 cylinder('REAR_STATUS_LAMP_'+str(i),(-.055+i*.055,.969,2.93),(-.055+i*.055,.974,2.93),.012,amber)
for i,x in enumerate([-.087,.087]):
 pts=smooth([(x,.73,3.94),(x,.88,3.85),(x,.91,3.65),(x,.92,3.19),(x,.95,3.02)],12)
 cu=bpy.data.curves.new('REAR_SENSOR_CABLE','CURVE');cu.dimensions='3D';cu.bevel_depth=.013;cu.bevel_resolution=3;sp=cu.splines.new('POLY');sp.points.add(len(pts)-1)
 for point,co in zip(sp.points,pts):point.co=(*co,1)
 ob=bpy.data.objects.new('REAR_SENSOR_CABLE_'+str(i),cu);col.objects.link(ob);bpy.context.view_layer.objects.active=ob;ob.select_set(True);bpy.ops.object.convert(target='MESH');own(bpy.context.object,'REAR_SENSOR_CABLE_'+str(i),cable)
 for z in [3.26,3.52,3.73]:cube('CABLE_BRASS_CLIP',(x,.925,z),(.045,.035,.025),brass)
# Rear aerial puck and compact auxiliary sensor.
cylinder('ROOF_REAR_SENSOR_PUCK',(0,.77,4.12),(0,.77,4.19),.065,iron)
cylinder('ROOF_REAR_SENSOR_CAP',(0,.77,4.19),(0,.77,4.21),.070,red)
bpy.context.view_layer.update()
for name,sig in original.items():assert signature(bpy.data.objects[name])==sig,name
bpy.ops.object.select_all(action='DESELECT')
for ob in created:ob.select_set(True)
bpy.context.view_layer.objects.active=created[0];bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')
report={'revision':'V09 sensor and antenna fit','all_V08_existing_meshes_materials_and_transforms_preserved':True,'short_antenna_count':2,'barrel_sensor_pairs':3,'roof_optical_cluster':True,'rear_control_box_and_cable_runs':True,'conveyor_hatches_and_hoppers_unchanged':True,'existing_bunker_modified':False}
S.render.resolution_x=S.render.resolution_y=int(os.getenv('LOADER_RENDER_SIZE','1000'));S.render.resolution_percentage=100;S.cycles.samples=int(os.getenv('LOADER_RENDER_SAMPLES','24'));cam=S.camera
views=[('oblique',(-4,-6,4.8),(0,.15,3.02),4.05),('rear',(-4,5,4.5),(0,.28,3.02),4.05),('front',(0,-7,3.6),(0,.2,3.02),4.05),('detail',(-3,-4,5.5),(0,.45,3.98),1.35)]
for i,(name,pos,target,scale) in enumerate(views):
 cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
 if i==0:bpy.ops.wm.save_as_mainfile(filepath=str(O/'six_lobber_sensor_fit_v09.blend'),compress=True)
 S.render.filepath=str(O/('sensor_fit_v09_'+name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action='DESELECT')
for ob in col.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=fin;bpy.ops.export_scene.gltf(filepath=str(O/'six_lobber_sensor_fit_v09.glb'),use_selection=True,export_format='GLB',export_apply=True,export_animations=False)
n=sum(ob.type=='MESH' for ob in col.objects)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(O/'six_lobber_sensor_fit_v09.glb'));assert sum(ob.type=='MESH' for ob in bpy.context.scene.objects)==n
report['GLB_reimported']=True;report['mesh_count']=n;(O/'model_validation.json').write_text(json.dumps(report,indent=2));print('V09_PRESERVATION_AND_EXPORT_PASS')
