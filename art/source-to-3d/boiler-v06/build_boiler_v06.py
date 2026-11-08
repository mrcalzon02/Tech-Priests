"""Replace rejected reducing elbows with separate rear interface manifolds."""
import bpy,bmesh,math,json,hashlib,struct,ast
from pathlib import Path
from mathutils import Vector,Matrix
R=Path(__file__).resolve().parent;D=R/'boiler_v06';D.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(R/'boiler_v05/tech_priests_emergency_boiler_v05.blend'))
s=bpy.context.scene;ports=bpy.data.collections['BOILER_EXTERNAL_FLUID_PORTS'];ports.name='BOILER_REAR_INTERFACE_MANIFOLDS';refs=bpy.data.collections['BOILER_REFERENCE_ADJACENT_PIPES']
core=[o for o in s.objects if o.type=='MESH' and o.parent and o.parent.name=='BOILER_TILE_CALIBRATION']
def sig(o):return hashlib.sha256(b''.join(struct.pack('3f',*(o.matrix_world@v.co)) for v in o.data.vertices)).hexdigest()
before={o.name:sig(o) for o in core}
for o in list(ports.objects):
 if o.type=='MESH' and any(t in o.name for t in ['full-size reducing elbow','matching external flange','inner rolled throat']):bpy.data.objects.remove(o,do_unlink=True)
collar=bpy.data.objects['Water reference near collar'].data.materials[0]
iron=bpy.data.materials.get('Emergency shared iron') or bpy.data.objects['Right sight chamber pressure body'].data.materials[0]
cast=bpy.data.objects['Boiler continuous foundation'].data.materials[0]
transition=iron;added=[]
# Reuse the closed tube/ring constructors, with constant bore rather than taper.
tree=ast.parse((R/'build_boiler_v05.py').read_text());defs=[x for x in tree.body if isinstance(x,ast.FunctionDef) and x.name in ['mesh','ring','tube']];exec(compile(ast.Module(body=defs,type_ignores=[]),'boiler_geometry_helpers','exec'),globals())
def cube(name,lo,hi,mat):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(Vector(lo)+Vector(hi))/2);o=bpy.context.object;o.name=name;o.dimensions=Vector(hi)-Vector(lo);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for c in list(o.users_collection):c.objects.unlink(o)
 ports.objects.link(o);o.data.materials.append(mat);added.append(o);return o
def cleanup(o):
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
 wires=[e for e in bm.edges if not e.link_faces]
 if wires:bmesh.ops.delete(bm,geom=wires,context='EDGES')
 loose=[v for v in bm.verts if not v.link_edges]
 if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update()
def boolean(body,target,operation):
 bpy.context.view_layer.objects.active=body;mod=body.modifiers.new('Manifold '+operation,'BOOLEAN');mod.operation=operation;mod.solver='EXACT';mod.object=target
 while body.modifiers.find(mod.name)>0:bpy.ops.object.modifier_move_up(modifier=mod.name)
 bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(target,do_unlink=True);cleanup(body)
def cutter(P,N,r,depth):
 bpy.ops.mesh.primitive_cylinder_add(vertices=96,radius=r,depth=depth,location=P);o=bpy.context.object;o.rotation_euler=Vector(N).to_track_quat('Z','Y').to_euler();return o
record=[]
old=json.loads((R/'boiler_v05/Boiler_V05_Validation.json').read_text())
for label,sign,key in [('Water',-1,'water_vessel_seat'),('Steam',1,'steam_vessel_seat')]:
 xlo,xhi=sorted([sign*.69,sign*.90]);body=cube(label+' cast interface manifold',(xlo,.14,.04),(xhi,.89,.79),cast)
 cavity=cube(label+' temporary empty chamber',(xlo+.025,.165,.065),(xhi-.025,.865,.765),cast);boolean(body,cavity,'DIFFERENCE')
 # Large outer opening stays at full native pipe diameter; the plenum handles the size change.
 boolean(body,cutter((sign*.89,.5,.36),(1,0,0),.247,.12),'DIFFERENCE')
 end=Vector(old[key])
 if label=='Water':
  small_center=Vector((-.69,end.y+.222,end.z));direction=Vector((1,0,0))
  path=[(-.72,small_center.y,end.z),(-.69,small_center.y,end.z)]
  for degrees in [75,60,45,30,15,0]:
   a=math.radians(degrees);path.append((-.69+.222*math.cos(a),end.y+.222*math.sin(a),end.z))
  path[-1]=tuple(end);path.insert(len(path)-1,(end.x,end.y+.02,end.z))
 else:
  direction=Vector((-1,-1,0)).normalized();small_center=Vector((.69,end.y+(.69-end.x),end.z));path=[tuple(end-direction*.33),tuple(end-direction*.17),tuple(end)]
 boolean(body,cutter(small_center-direction*.025,direction,.087,.16),'DIFFERENCE')
 neck=ring(label+' full-size straight inlet',(sign*.94,.5,.36),(1,0,0),.285,.245,.12,cast);neck.modifiers.clear()
 boolean(body,neck,'UNION')
 # Small constant-size machine fitting; no stretching of a large pipe into a thin spout.
 small=tube(label+' native-size machine coupling',path,[.10]*len(path));boolean(body,small,'UNION')
 flange=ring(label+' full-size bolted inlet flange',(sign*.9625,.5,.36),(1,0,0),.34,.245,.075,collar)
 # Paint the short exposed full-size neck exactly like its external pipe.
 if collar.name not in body.data.materials:body.data.materials.append(collar)
 ci=list(body.data.materials).index(collar)
 for p in body.data.polygons:
  world=body.matrix_world@p.center
  if world.x*sign>.905:p.material_index=ci
 bevel=body.modifiers.new('Cast edge breaks','BEVEL');bevel.width=.006;bevel.segments=3
 cube(label+' manifold mounting foot',(xlo-.025,.11,.025),(xhi+.025,.92,.12),cast)
 cube(label+' removable top cover',(xlo-.006,.13,.788),(xhi+.006,.90,.818),cast)
 for i,y in enumerate([.22,.81]):
  bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=.018,depth=.018,location=((xlo+xhi)/2,y,.826));o=bpy.context.object;o.name=label+' manifold cover bolt '+str(i)
  for c in list(o.users_collection):c.objects.unlink(o)
  ports.objects.link(o);o.data.materials.append(iron);added.append(o)
 cleanup(body);bm=bmesh.new();bm.from_mesh(body.data);bad=sum(not e.is_manifold for e in bm.edges);seen=set();components=0
 for v in bm.verts:
  if v in seen:continue
  components+=1;stack=[v];seen.add(v)
  while stack:
   w=stack.pop()
   for e in w.link_edges:
    vv=e.other_vert(w)
    if vv not in seen:seen.add(vv);stack.append(vv)
 if bad:print('BAD_EDGES',label,[{'length':e.calc_length(),'faces':len(e.link_faces),'coords':[list(v.co) for v in e.verts],'areas':[f.calc_area() for f in e.link_faces]} for e in bm.edges if not e.is_manifold],flush=True)
 bm.free();assert bad==0 and components==1,(label,bad,components)
 record.append({'fluid':label,'body':body.name,'closed_mesh_nonmanifold_edges':bad,'connected_components':components,'full_size_pipe_center':[sign,.5,.36],'external_body_diameter':.57,'external_bore_diameter':.49,'machine_coupling_outer_diameter':.20,'machine_coupling_bore_diameter':.20*(.245/.285),'vessel_seat':list(end),'separate_plenum':True})
bpy.context.view_layer.update();assert all(sig(bpy.data.objects[n])==h for n,h in before.items())
# Deleted boolean operands are no longer asset objects.
asset=core+[o for o in ports.objects if o.type=='MESH']
validation={'revision':'V06','rejected_design':'V05 continuously tapered reducing elbows removed','design':'Separate cast water/steam interface plenums behind the machinery; full-size external openings and native-size machine fittings','core_202_world_geometry_unchanged':True,'footprint_tiles':[2,2],'manifolds':record,'geometry_scope':'Two independent hollow chambers, without hidden mechanism detail','runtime_integration':'Pending; no runtime or animation changes'}
(D/'Boiler_V06_Validation.json').write_text(json.dumps(validation,indent=2))
s['asset_revision']='V06 separate rear water and steam interface manifolds';cam=bpy.data.objects['BOILER_FACTORIO_EXPORT_45'];s.camera=cam;cam.data.ortho_scale=4.65;refs.hide_render=False;s.render.resolution_x=1200;s.render.resolution_y=850;s.cycles.samples=24
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(D/'tech_priests_emergency_boiler_v06.blend'),compress=True)
for o in s.objects:o.select_set(False)
for o in asset:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(D/'tech_priests_emergency_boiler_v06.glb'),export_format='GLB',use_selection=True,export_apply=True)
s.render.filepath=str(D/'Boiler_V06_Pipe_Fit.png');bpy.ops.render.render(write_still=True)
refs.hide_render=True;cam.data.ortho_scale=2.9;s.render.resolution_x=1000;s.render.resolution_y=1000
world={o.name:o.matrix_world.copy() for o in asset}
for heading,degrees in [('North',0),('South',180)]:
 rot=Matrix.Rotation(math.radians(degrees),4,'Z')
 for o in asset:o.matrix_world=rot@world[o.name]
 s.render.filepath=str(D/('Boiler_V06_'+heading+'.png'));bpy.ops.render.render(write_still=True)
print('BOILER_V06_COMPLETE',flush=True)
