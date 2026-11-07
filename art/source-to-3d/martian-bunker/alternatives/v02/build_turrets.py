"""Blender 5.0.1. Editable primitive blockouts; source bunker is never overwritten.
Usage: blender -b SOURCE.blend -t 4 --python build_turrets.py -- OUTPUT TEXTURES
"""
import bpy, math, json, sys, hashlib
from pathlib import Path
from mathutils import Vector, Matrix
args=sys.argv[sys.argv.index('--')+1:];O=Path(args[0]).resolve();T=Path(args[1]).resolve();O.mkdir(parents=True,exist_ok=True)
S=bpy.context.scene;S.frame_set(1);bpy.context.view_layer.update()
# Retain exactly the source BASE_ONLY objects, evaluated at rest, independent of shot rig.
base_layer=S.view_layers.get('BASE_ONLY')
assert base_layer is None, 'Use the intact pre-split paving_v6 source, not a split/shot scene with damaged base transforms'
base_names=set(json.loads((O/'source_comparison.json').read_text())['correct_base_signature'])
base_objs=[o for o in S.objects if o.name in base_names]
base_data={o.name: {'matrix':[list(r) for r in o.matrix_world], 'mesh':hashlib.sha256(repr([tuple(v.co) for v in o.data.vertices]).encode()).hexdigest()} for o in base_objs}
for o in base_objs:
 mat=o.matrix_world.copy();o.parent=None;o.matrix_world=mat;o.animation_data_clear()
for o in list(S.objects):
 if o not in base_objs and o.type not in ['LIGHT','CAMERA']:bpy.data.objects.remove(o,do_unlink=True)
for col in list(bpy.data.collections):
 if not col.objects and not col.children:bpy.data.collections.remove(col)
for vl in list(S.view_layers)[1:]:S.view_layers.remove(vl)
S.view_layers[0].name='Review'
def enable(lc):
 lc.exclude=False;lc.hide_viewport=False
 for ch in lc.children:enable(ch)
enable(S.view_layers[0].layer_collection)
for col in bpy.data.collections:col.hide_render=False;col.hide_viewport=False
base_col=bpy.data.collections.new('EXISTING_BUNKER_BASE_UNCHANGED');S.collection.children.link(base_col)
for o in base_objs:
 for c in list(o.users_collection):c.objects.unlink(o)
 base_col.objects.link(o)
# Material source is the committed reference library. New parts use generic tiles,
# not decorated UVs specific to the old cannon.
def material(key,title):
 m=bpy.data.materials.new('V01 | '+title);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF');p.inputs['Roughness'].default_value=.65
 tc=n.new('ShaderNodeTexCoord')
 for suffix,socket in [('', 'Base Color'),('_Roughness','Roughness'),('_Metallic','Metallic')]:
  path=T/(key+'.png') if not suffix else T/key/(key+suffix+'.png')
  if not path.exists():continue
  im=bpy.data.images.load(str(path),check_existing=True);im.pack()
  if suffix:im.colorspace_settings.name='Non-Color'
  tex=n.new('ShaderNodeTexImage');tex.image=im;tex.projection='FLAT';tex.projection_blend=.15;l.new(tc.outputs['UV'],tex.inputs['Vector']);l.new(tex.outputs['Color'],p.inputs[socket])
 return m
red=material('01_oxide_red_paint','committed oxide red');steel=material('03_worn_machined_steel','committed machined steel');dark=material('02_dark_gunmetal','committed gunmetal');brass=material('04_tarnished_brass','committed tarnished brass')
created=[];root=None;parent_links=[]
col=None
def own(o,name,mat,parent=None):
 o.name=name
 for c in list(o.users_collection):c.objects.unlink(o)
 col.objects.link(o)
 if mat:o.data.materials.clear();o.data.materials.append(mat)
 if parent is None:parent=root
 if parent:parent_links.append((o,parent))
 created.append(o);return o

def empty(name,loc,parent=None):
 o=bpy.data.objects.new(name,None);col.objects.link(o);o.location=loc;o.empty_display_type='PLAIN_AXES';o.empty_display_size=.25
 if parent:parent_links.append((o,parent))
 created.append(o);return o

def cube(name,loc,scale,mat,parent=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.dimensions=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 own(o,name,mat,parent);b=o.modifiers.new('Small edge chamfer','BEVEL');b.width=.015;b.segments=2;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');return o

def cyl(name,a,b,r,mat,parent=None):
 a,b=Vector(a),Vector(b);d=b-a;bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=d.length,location=(a+b)/2);o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return own(o,name,mat,parent)

def mesh(name,vs,fs,mat,parent=None):
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(name,me);col.objects.link(o);own(o,name,mat,parent);return o

def tube(name,a,b,r,wall,mat,parent=None):
 a,b=Vector(a),Vector(b);axis=(b-a).normalized();u=axis.cross(Vector((1,0,0))).normalized();v=axis.cross(u);vs=[];N=32
 for center,rad in [(a,r),(b,r),(b,r-wall),(a,r-wall)]:
  for j in range(N):vs.append(tuple(center+rad*(u*math.cos(j*2*math.pi/N)+v*math.sin(j*2*math.pi/N))))
 fs=[]
 for ring,next_ring in [(0,1),(1,2),(2,3),(3,0)]:
  for j in range(N):fs.append((ring*N+j,ring*N+(j+1)%N,next_ring*N+(j+1)%N,next_ring*N+j))
 return mesh(name,vs,fs,mat,parent)

def platform():
 # Both alternate tops use the existing bearing's z=1.70 interface.
 cyl('ROTARY_ADAPTER',(0,0,1.70),(0,0,1.82),.78,dark)
 cube('PEDESTAL_FOOT',(0,0,1.87),(1.36,.98,.12),red)
 for sign in [-1,1]:
  cube('YOKE_'+str(sign),(sign*.70,0,2.16),(.16,.62,.52),red)
  cyl('TRUNNION_'+str(sign),(sign*.60,0,2.34),(sign*.83,0,2.34),.16,steel)

def camera(pos,target,scale):
 S.camera.location=pos;S.camera.rotation_euler=(Vector(target)-S.camera.location).to_track_quat('-Z','Y').to_euler();S.camera.data.type='ORTHO';S.camera.data.ortho_scale=scale
# Replace shot compositor, use direct normal render, preserve recovered light rig.
S.use_nodes=False;S.render.use_compositing=False;S.render.use_sequencer=False;S.view_layers[0].use=True;S.render.engine='CYCLES';S.cycles.device='CPU';S.cycles.samples=24;S.cycles.use_denoising=True
S.render.resolution_x=1000;S.render.resolution_y=1000;S.render.resolution_percentage=100;S.render.film_transparent=True;S.render.image_settings.file_format='PNG';S.render.image_settings.color_mode='RGBA'
for obj in S.objects:
 if obj.type=='LIGHT':obj.hide_render=False
if not S.camera:
 d=bpy.data.cameras.new('Review camera');c=bpy.data.objects.new(d.name,d);S.collection.objects.link(c);S.camera=c
S.camera.animation_data_clear();S.camera.data.animation_data_clear()
S.world.use_nodes=True;bg=S.world.node_tree.nodes.get('Background');bg.inputs['Color'].default_value=(.16,.18,.22,1);bg.inputs['Strength'].default_value=.4
# Source render uses Factorio production lights; retain positions and energies.
report={'stage':'primitive blockout v01','base_mesh_count':len(base_objs),'source_base_signature':base_data,'interface_z':1.70,'assumptions':{'dish':'rectangular concave trough reflector inferred from drawn curved left edge and straight cross-width edges','lobber':'12 tubes arranged as 3 rows of 4; sketch supplies 3 rows, hidden depth inferred','firing_pose':'dish fixed concept pose, lobber 45-degree elevation; gameplay not installed'},'variants':{}}
base_ref=[(o,o.matrix_world.copy(),o.data.copy()) for o in base_objs]
for variant in ['energy_dish','grenade_lobber_12']:
 created=[];parent_links=[];col=bpy.data.collections.new(variant.upper());S.collection.children.link(col);root=None;root=empty('TURRET_TRAVERSE',(0,0,1.70));platform()
 pivot=empty('WEAPON_ELEVATION',(0,0,2.34),root)
 if variant=='energy_dish':
  # Rectangular reflector 1.84 wide, 1.90 high, 0.52 deep.
  # Curvature is vertical; open mouth faces -Y, matching the drawn side profile.
  vs=[];N=24
  for j in range(N+1):
   z=-.95+1.90*j/N;y=.18-.52*(z/.95)**2
   vs.extend([(-.92,y,2.86+z),(.92,y,2.86+z)])
  fs=[(2*j,2*j+1,2*j+3,2*j+2) for j in range(N)]
  dish=mesh('CURVED_REFLECTOR',vs,fs,steel,pivot)
  sol=dish.modifiers.new('Reflector wall thickness','SOLIDIFY');sol.thickness=.065
  # A separate red backing follows the same curve without occupying the front face.
  back=mesh('RED_REFLECTOR_BACKING',[(x,y+.072,z) for x,y,z in vs],fs,red,pivot);sol=back.modifiers.new('Backing plate thickness','SOLIDIFY');sol.thickness=.035
  for side in [-1,1]:
   for j in range(N):
    cyl('CURVED_SIDE_RIM_'+str(side)+'_'+str(j),(side*.94,vs[2*j][1],vs[2*j][2]),(side*.94,vs[2*(j+1)][1],vs[2*(j+1)][2]),.037,dark,pivot)
   cube('REFLECTOR_PIVOT_CHEEK_'+str(side),(side*.64,.12,2.48),(.16,.27,.50),red,pivot)
  for z,y in [(1.91,-.34),(3.81,-.34)]:cyl('STRAIGHT_RIM',(-.94,y,z),(.94,y,z),.045,dark,pivot)
  # Visible central emitter and triangulated focus supports; no hidden mechanisms.
  cyl('CENTRAL_FEED',(0,.16,2.86),(0,-1.03,2.86),.065,brass,pivot)
  cyl('EMITTER_TIP',(0,-1.03,2.86),(0,-1.16,2.86),.10,steel,pivot)
  for x in [-.77,.77]:
   for z in [2.23,3.49]:
    y=.18-.52*((z-2.86)/.95)**2
    cyl('FOCUS_SUPPORT',(x,y-.02,z),(0,-.92,2.86),.027,dark,pivot)
  for side in [-1,1]:
   for z in [2.07,2.86,3.65]:
    y=.18-.52*((z-2.86)/.95)**2
    cyl('RIM_NODE',(side*.94,y-.035,z),(side*.94,y-.10,z),.075,brass,pivot)
  # Structural spine connects reflector back to elevation pivot.
  cube('REAR_SPINE',(0,.28,2.63),(.34,.20,.82),red,pivot)
 else:
  # Hollow single tubes; three rows in an elevating four-wide rack.
  axis=Vector((0,-math.sqrt(.5),math.sqrt(.5)));up=Vector((0,math.sqrt(.5),math.sqrt(.5)));C=Vector((0,0,2.55))
  for row in range(3):
   for column in range(4):
    center=C+Vector(((column-1.5)*.36,0,0))+up*((row-1)*.36)
    a=center-axis*.47;b=center+axis*.47
    o=tube('GRENADE_TUBE_R%d_C%d'%(row+1,column+1),a,b,.148,.034,dark,pivot);o['row']=row+1;o['column']=column+1
    tube('MUZZLE_COLLAR_R%d_C%d'%(row+1,column+1),b-axis*.075,b+axis*.015,.17,.056,steel,pivot)
    cyl('BREECH_CAP_R%d_C%d'%(row+1,column+1),a-axis*.035,a,.151,red,pivot)
  # Side plates and cross rails connect all rows to the trunnions.
  for side in [-1,1]:
   o=cube('RACK_SIDE_PLATE_'+str(side),(side*.76,0,2.55),(.14,.92,1.14),red,pivot);o.rotation_euler[0]=math.radians(-45)
  for row in range(3):
   c=C+up*((row-1)*.36)-axis*.30
   cyl('ROW_SUPPORT_'+str(row),c+Vector((-.77,0,0)),c+Vector((.77,0,0)),.09,brass,pivot)
 bpy.context.view_layer.update()
 for obj,par in parent_links:
  mw=obj.matrix_world.copy();obj.parent=par;obj.matrix_parent_inverse=par.matrix_world.inverted();obj.matrix_world=mw;bpy.context.view_layer.update()
 # All new meshes have real UVs so native and GLB share the same mapped materials.
 bpy.ops.object.select_all(action='DESELECT')
 for obj in created:
  if obj.type=='MESH':obj.select_set(True)
 bpy.context.view_layer.objects.active=next(obj for obj in created if obj.type=='MESH')
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')
 # Pack maps, strip all unused old cannon data and save a self-contained native scene.
 S['variant']=variant;S['stage']='primitive blockout for silhouette review';S['mount_interface_z']=1.70
 bpy.context.view_layer.update()
 for o,mw,_ in base_ref:assert all(abs(o.matrix_world[i][j]-mw[i][j])<1e-6 for i in range(4) for j in range(4)),o.name
 tubes=[o for o in created if o.name.startswith('GRENADE_TUBE')]
 if variant=='grenade_lobber_12':assert len(tubes)==12
 # Full mounted review and two isolated views use the same orthographic angles.
 base_col.hide_render=False
 camera((5,-7,5.5),(0,0,1.85),5.5)
 for i in range(3):
  bpy.ops.outliner.orphans_purge(do_recursive=True)
 bpy.ops.wm.save_as_mainfile(filepath=str(O/(variant+'_v02.blend')),compress=True)
 for view,pos,target,scale,base in [('mounted',(5,-7,5.5),(0,0,1.85),5.5,True),('turret',(5,-7,5.5),(0,0,2.65),3.5,False),('front',(0,-8,3.5),(0,0,2.65),3.3,False),('rear',(-5,7,5.5),(0,0,2.65),3.5,False)]:
  base_col.hide_render=not base;camera(pos,target,scale);S.render.filepath=str(O/(variant+'_'+view+'.png'));bpy.ops.render.render(write_still=True)
 # Export independent turret entity with textures and hierarchy, not a second bunker.
 bpy.ops.object.select_all(action='DESELECT')
 for o in created:o.select_set(True)
 bpy.context.view_layer.objects.active=root
 bpy.ops.export_scene.gltf(filepath=str(O/(variant+'_v01.glb')),use_selection=True,export_format='GLB',export_animations=False)
 report['variants'][variant]={'turret_objects':len(created),'mesh_count':sum(o.type=='MESH' for o in created),'grenade_tube_count':len(tubes),'elevation_pivot':[0,0,2.34],'bounds':{}}
 pts=[o.matrix_world@Vector(c) for o in created if o.type=='MESH' for c in o.bound_box]
 report['variants'][variant]['bounds']={'min':[min(p[i] for p in pts) for i in range(3)],'max':[max(p[i] for p in pts) for i in range(3)]}
 base_col.hide_render=False
 for o in list(created):bpy.data.objects.remove(o,do_unlink=True)
 bpy.data.collections.remove(col)
 root=None
(O/'build_validation.json').write_text(json.dumps(report,indent=2))
print('BLOCKOUT_BUILD_PASS',flush=True)
