"""Open the preserved V18 condenser, calibrate tile units, and add its water outlet.
Run with Blender --background --python build_condenser_v19.py.
"""
import bpy,bmesh,math,json,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
R=Path(__file__).resolve().parent
D=R/'condenser_v19';D.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(R/'models/Tech priests/tech_priests_water_condenser_v18.blend'))
s=bpy.context.scene
original=[o for o in s.objects if o.type=='MESH']
def sig(o):
 return hashlib.sha256(b''.join(__import__('struct').pack('3f',*v.co) for v in o.data.vertices)).hexdigest()
before={o.name:sig(o) for o in original}
foundation=bpy.data.objects['Condenser shallow tapered foundation']
bb=[foundation.matrix_world@Vector(v) for v in foundation.bound_box]
center=Vector(((min(v.x for v in bb)+max(v.x for v in bb))/2,(min(v.y for v in bb)+max(v.y for v in bb))/2,min(v.z for v in bb)))
scale=1.9/(max(v.y for v in bb)-min(v.y for v in bb))
T=Matrix.Scale(scale,4)@Matrix.Translation(-center)
root=bpy.data.objects.new('CONDENSER_TILE_CALIBRATION',None);s.collection.objects.link(root)
root.empty_display_type='PLAIN_AXES';root.empty_display_size=.2
root['units_per_tile']=1.0;root['footprint_tiles']=[2,2];root['source_uniform_scale']=scale;root['blender_positive_y']='Factorio north / negative map Y'
# Retain every source vertex, material and UV. Only the uniform scene placement changes.
for o in list(s.objects):
 if o==root:continue
 o.matrix_world=T@o.matrix_world
 if o.type=='CAMERA' and o.data.type=='ORTHO':o.data.ortho_scale*=scale
 if o.type=='LIGHT':
  o.data.energy*=scale*scale
  if o.data.type=='AREA':o.data.size*=scale
for o in original:
 mw=o.matrix_world.copy();o.parent=root;o.matrix_world=mw
added=[]
def material(n,color,metal=.8,rough=.42):
 m=bpy.data.materials.new(n);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 return m
steel=bpy.data.materials.get('Emergency shared worn_steel') or material('Outlet aged steel',(.23,.25,.22))
iron=bpy.data.materials.get('Emergency shared iron') or material('Outlet dark iron',(.07,.085,.075))
brass=bpy.data.materials.get('Emergency shared old_gold') or material('Outlet brass gasket',(.28,.19,.065))
refsteel=material('Reference pipe steel',(.31,.35,.32),.83,.3)
gridmat=material('Reference tile seams',(.14,.19,.2),0,.9)
groundmat=material('Reference ground',(.065,.075,.073),0,.95)
asset=bpy.data.collections.new('CONDENSER_WATER_OUTLET');s.collection.children.link(asset)
ref=bpy.data.collections.new('REFERENCE_ADJACENT_PIPES');s.collection.children.link(ref)
grid=bpy.data.collections.new('REFERENCE_TILE_GRID');s.collection.children.link(grid)
def relocate(o,col):
 for c in list(o.users_collection):c.objects.unlink(o)
 col.objects.link(o)
def ring(name,x0,x1,ro,ri,mat,col=asset):
 n=64;vs=[];fs=[]
 for x,r in [(x0,ro),(x1,ro),(x0,ri),(x1,ri)]:
  vs.extend((x,-.5+math.cos(i*math.tau/n)*r,.36+math.sin(i*math.tau/n)*r) for i in range(n))
 for i in range(n):
  j=(i+1)%n;fs.extend([(i,j,n+j,n+i),(2*n+j,2*n+i,3*n+i,3*n+j),(j,i,2*n+i,2*n+j),(n+i,n+j,3*n+j,3*n+i)])
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update()
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free()
 o=bpy.data.objects.new(name,me);col.objects.link(o);me.materials.append(mat)
 for p in me.polygons:p.use_smooth=abs(p.normal.x)<.5
 bevel=o.modifiers.new('Machined edge break','BEVEL');bevel.width=.004;bevel.segments=3
 if col==asset:added.append(o)
 return o
def box(name,loc,dims,mat,col,bevel=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=dims;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat);relocate(o,col)
 if bevel:m=o.modifiers.new('Edge break','BEVEL');m.width=bevel;m.segments=3
 return o
def bolts(label,x,col):
 for i in range(8):
  a=(i+.5)*math.tau/8
  bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=.019,depth=.018,location=(x,-.5+.307*math.cos(a),.36+.307*math.sin(a)),rotation=(0,math.pi/2,0))
  o=bpy.context.object;o.name=label+' bolt %02d'%i;o.data.materials.append(brass);relocate(o,col)
  if col==asset:added.append(o)
# A full-size visible water manifold enters the existing lower chassis, under the side cable.
# Mouth and flange terminate on x=+1 exactly; adjacent reference starts on the same plane.
ring('Water outlet continuous hollow manifold',.44,1.0,.285,.245,steel)
ring('Water outlet chassis receiver',.56,.70,.335,.245,iron)
ring('Water outlet receiver brass seating band',.685,.705,.316,.284,brass)
ring('Water outlet end flange',.925,1.0,.34,.245,steel)
ring('Water outlet rim inner bevel seat',.985,1.0,.29,.245,iron)
bolts('Water outlet flange',.989,asset)
mouth=bpy.data.objects.new('CONDENSER_WATER_OUTLET_MOUTH',None);asset.objects.link(mouth);mouth.location=(1,-.5,.36);mouth.empty_display_type='ARROWS';mouth.empty_display_size=.18
mouth['fluid']='water';mouth['flow_direction']='output';mouth['factorio_direction']='east';mouth['prototype_position']=[.5,.5];mouth['adjacent_pipe_tile_center']=[1.5,.5];mouth['bore_diameter_tiles']=.49
for k in range(2):
 a=1+k;b=2+k
 ring('Reference pipe %d barrel'%k,a,b,.285,.245,refsteel,ref)
 ring('Reference pipe %d start collar'%k,a,a+.075,.34,.245,steel,ref)
 ring('Reference pipe %d end collar'%k,b-.075,b,.34,.245,steel,ref)
 bolts('Reference pipe %d'%k,a+.015,ref)
 # The source pipe has a recessed inspection window on the top of the barrel.
 box('Reference pipe %d window rim'%k,((a+b)/2,-.5,.637),(.34,.23,.035),iron,ref,.035)
 box('Reference pipe %d inset'%k,((a+b)/2,-.5,.656),(.25,.15,.012),refsteel,ref,.024)
for x in range(-1,4):box('Grid X %d'%x,(x,0,-.013),(.009,3,.008),gridmat,grid)
for y in range(-1,3):box('Grid Y %d'%y,(1,y,-.013),(4,.009,.008),gridmat,grid)
box('Reference ground',(1,0,-.035),(4,3,.03),groundmat,grid)
def camera(name,loc,target,ortho):
 d=bpy.data.cameras.new(name);d.type='ORTHO';d.ortho_scale=ortho
 o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();return o
gamecam=camera('PIPE_FIT_GAME_CAMERA_45_DEGREES',(1,-6,6.15),(1,0,.15),4.65)
oblique=camera('PIPE_FIT_OBLIQUE', (4,-6,4),(.7,-.1,.25),4.6)
top=camera('PIPE_FIT_TOP',(1,0,8),(1,0,0),4.4)
side=camera('PIPE_FIT_FRONT_HEIGHT',(1,-7,.36),(1,0,.36),4.4)
s['asset']='Tech Priests atmospheric water condenser';s['asset_revision']='V19 calibrated 2x2 footprint and east water outlet';s['technology_principle']='Atmospheric water condensation';s['source_sprite_visual_acceptance']='Prior source finish review remains open';s['pipe_fit_status']='Geometrically aligned to reference; game runtime not tested'
s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=24
s.render.resolution_x=1200;s.render.resolution_y=800;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.film_transparent=False
s.camera=gamecam
for o in s.objects:o.select_set(False)
mouth.select_set(True);bpy.context.view_layer.objects.active=mouth
for scr in bpy.data.screens:
 for area in scr.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(D/'tech_priests_water_condenser_v19.blend'),compress=True)
assert all(sig(bpy.data.objects[n])==h for n,h in before.items())
record={'revision':'V19','source':'tech_priests_water_condenser_v18.blend','source_vertex_hashes_unchanged':before,'original_meshes_preserved':len(original),'uniform_scale':scale,'source_ground_and_center':list(center),'units_per_tile':1,'foundation_dimensions_tiles':list(foundation.dimensions),'footprint_tiles':[2,2],'port_world_blender':[1,-.5,.36],'factorio_mouth':[1,.5],'prototype_position':[.5,.5],'adjacent_pipe_center_factorio':[1.5,.5],'pipe_body_diameter':.57,'pipe_flange_diameter':.68,'pipe_bore_diameter':.49,'pipe_height':.36,'reference_basis':'Pipe.png from preserved Boiler V04 package; supplied gameplay image ~80 px tile, ~48 px barrel incl edge shading. Diameter/height are visual calibration estimates, not measured Wube 3D dimensions.','new_asset_meshes':[o.name for o in added],'reference_objects_excluded_from_production_export':True,'runtime_validation':'Not performed; packaged integration patch must align prototype to front/south tile row.','scope':'Condenser only; boiler retained unchanged as reference.'}
(D/'Condenser_V19_Alignment.json').write_text(json.dumps(record,indent=2))
for cam,name in [(gamecam,'Game_View'),(oblique,'Oblique'),(top,'Top'),(side,'Height')]:
 s.camera=cam;s.render.filepath=str(D/('Condenser_V19_'+name+'.png'));bpy.ops.render.render(write_still=True)
# Asset-only GLB. Reference geometry is present only in the editable .blend fit scene.
for o in s.objects:o.select_set(False)
for o in original+added:
 if not o.hide_render:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(D/'tech_priests_water_condenser_v19.glb'),export_format='GLB',use_selection=True,export_apply=True)
print('V19_BUILD_COMPLETE',len(original),len(added),flush=True)
