"""Refine the sketch-derived dish without changing its bearing or elevation frame."""
import bpy,math,json,pathlib,hashlib,sys
from mathutils import Vector,Matrix
O=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();O.mkdir(parents=True,exist_ok=True)
S=bpy.context.scene;root=bpy.data.objects['TURRET_TRAVERSE'];pivot=bpy.data.objects['WEAPON_ELEVATION'];col=root.users_collection[0]
source=pathlib.Path(bpy.data.filepath);source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
before={o.name:{'matrix':[list(row) for row in o.matrix_world],'vertices':hashlib.sha256(repr([tuple(v.co) for v in o.data.vertices]).encode()).hexdigest()} for o in S.objects if o.type=='MESH'}
def bounds():
 pts=[o.matrix_world@Vector(c) for o in S.objects if o.type=='MESH' for c in o.bound_box]
 return [[min(p[i] for p in pts) for i in range(3)],[max(p[i] for p in pts) for i in range(3)]]
oldbounds=bounds();mats={}
for m in list(bpy.data.materials):
 if m.name.startswith('V01 | '):
  copy=m.copy();copy.name='DISH_V03 | '+m.name.split(' | ',1)[1];mats[m.name]=copy
for o in S.objects:
 if o.type=='MESH':
  for slot in o.material_slots:
   if slot.material and slot.material.name in mats:slot.material=mats[slot.material.name]
dark=mats['V01 | committed gunmetal'];steel=mats['V01 | committed machined steel']
def mesh(name,vs,fs,mat,parent):
 data=bpy.data.meshes.new(name);data.from_pydata(vs,[],fs);data.update();o=bpy.data.objects.new(name,data);col.objects.link(o);data.materials.append(mat);o.parent=parent;o.matrix_world=Matrix.Identity(4);return o
removed=[o for o in list(S.objects) if o.name.startswith('CURVED_SIDE_RIM_')];assert len(removed)==48
for o in removed:bpy.data.objects.remove(o,do_unlink=True)
rails=[]
for side in (-1,1):
 vs=[];fs=[];N=96;K=16
 for j in range(N+1):
  z=-.95+1.90*j/N;y=.18-.52*(z/.95)**2
  normal=Vector((0,1,1.04*z/(.95**2))).normalized()
  for k in range(K):
   a=2*math.pi*k/K;p=Vector((side*.94,y,2.86+z))+.037*(Vector((1,0,0))*math.cos(a)+normal*math.sin(a));vs.append(tuple(p))
 for j in range(N):
  for k in range(K):fs.append((j*K+k,j*K+(k+1)%K,(j+1)*K+(k+1)%K,(j+1)*K+k))
 fs.extend([tuple(reversed(range(K))),tuple(N*K+k for k in range(K))])
 o=mesh('CONTINUOUS_SIDE_RAIL_'+str(side),vs,fs,dark,pivot);rails.append(o)
 for p in o.data.polygons:p.use_smooth=len(p.vertices)==4
 uv=o.data.uv_layers.new(name='Rail_length_circumference')
 for p in o.data.polygons:
  for li in p.loop_indices:
   index=o.data.loops[li].vertex_index;j,k=divmod(index,K)
   # Per-face seam wrap prevents the last quad stretching across the cylinder.
   u=k/K
   if p.index<N*K and p.index%K==K-1 and k==0:u=1
   uv.data[li].uv=(u,j/N*4)
def bolt(name,loc,axis,radius,depth,parent):
 bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=radius,depth=depth,location=loc);o=bpy.context.object;o.name=name;o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
 for c in list(o.users_collection):c.objects.unlink(o)
 col.objects.link(o);o.data.materials.append(steel);bpy.context.view_layer.update();mw=o.matrix_world.copy();o.parent=parent;o.matrix_world=mw
 bevel=o.modifiers.new('Fastener edge chamfer','BEVEL');bevel.width=.003;bevel.segments=2
 return o
for x in (-.53,.53):
 for y in (-.33,.33):bolt('PEDESTAL_FASTENER', (x,y,1.942),(0,0,1),.045,.025,root)
for side in (-1,1):bolt('TRUNNION_RETAINER',(side*.836,0,2.34),(1,0,0),.09,.018,root)
# Both large surfaces use width / physical arc length, never independent smart
# islands per strip. Original image maps and PBR channels remain packed.
arc=[0.0];zs=[-.95+1.9*j/24 for j in range(25)]
for j in range(1,25):
 a,b=zs[j-1],zs[j];arc.append(arc[-1]+math.hypot(b-a,.52*((b/.95)**2-(a/.95)**2)))
for name in ('CURVED_REFLECTOR','RED_REFLECTOR_BACKING'):
 o=bpy.data.objects[name];uv=o.data.uv_layers.active or o.data.uv_layers.new(name='Panel_arc_length');uv.name='Panel_arc_length'
 for loop in o.data.loops:
  v=o.matrix_world@o.data.vertices[loop.vertex_index].co;j=min(range(25),key=lambda k:abs((2.86+zs[k])-v.z))
  uv.data[loop.index].uv=((v.x+.92)*2,arc[j]*2)
S['stage']='dish V03 continuity and panel-UV refinement; visual candidate, no game integration'
S['mount_interface_z']=1.70;S['elevation_pivot']=[0,0,2.34]
bpy.context.view_layer.update();afterbounds=bounds()
assert max(abs(oldbounds[a][b]-afterbounds[a][b]) for a in range(2) for b in range(3))<1e-5,(oldbounds,afterbounds)
for name,record in before.items():
 if name.startswith('CURVED_SIDE_RIM_'):continue
 o=bpy.data.objects[name];assert record['vertices']==hashlib.sha256(repr([tuple(v.co) for v in o.data.vertices]).encode()).hexdigest(),name
 assert max(abs(o.matrix_world[i][j]-record['matrix'][i][j]) for i in range(4) for j in range(4))<1e-6,name
assert (root.matrix_world.translation-Vector((0,0,1.70))).length<1e-5
assert (pivot.matrix_world.translation-Vector((0,0,2.34))).length<1e-5
for im in bpy.data.images:
 if im.source=='FILE' and not im.packed_file:im.pack()
bpy.ops.object.select_all(action='DESELECT')
for o in col.objects:
 if o.type in ('MESH','EMPTY'):o.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(O/'energy_dish_v03.glb'),use_selection=True,export_format='GLB',export_animations=False,export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(O/'energy_dish_v03.blend'),compress=True)
report={'source_path':source.as_posix(),'source_sha256':source_hash,'reference':'alternatives/v02/reference/owner_turret_sketch.jpg','status':'candidate_pending_independent_export_and_visual_review','removed_segment_meshes':48,'new_continuous_rails':2,'supported_fasteners':6,'old_bounds':oldbounds,'new_bounds':afterbounds,'preserved_existing_meshes':len(before)-48,'mount_interface':[0,0,1.70],'elevation_pivot':[0,0,2.34],'surface_plan':{'reflector':'machined steel; continuous arc-length UV, two repeats per model unit','backing':'oxide red painted plate; same spatial UV density','rails':'gunmetal; circumference and length mapping','mount':'unchanged pedestal geometry; attached steel fasteners'},'no_base_included':True,'no_behavior_changes':True}
(O/'build-validation.json').write_text(json.dumps(report,indent=2)+'\n');print('DISH_V03_BUILT',flush=True)
