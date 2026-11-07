"""Six cast-iron lobber cannons: three per mirrored side, each bottom fed.
Blender 5.0.1. Run from repository root with --python-exit-code 12.
"""
import bpy, math, json, hashlib, shutil
from pathlib import Path
from mathutils import Vector
O=Path("art/source-to-3d/martian-bunker/alternatives/v04").resolve()
T=Path("art/source-to-3d/martian-bunker/alternatives/v02/textures").resolve()
O.mkdir(parents=True,exist_ok=True)
source_tiles=T
T=O/"textures"
T.mkdir(exist_ok=True)
for key in ["02_dark_gunmetal","01_oxide_red_paint","03_worn_machined_steel"]:
 if not (T/(key+".png")).exists():
  shutil.copy2(source_tiles/(key+".png"),T/(key+".png"))
bpy.ops.wm.read_factory_settings(use_empty=True)
S=bpy.context.scene
col=bpy.data.collections.new("SIX_CAST_IRON_LOBBER");S.collection.children.link(col)
created=[]
def empty(name,loc,parent=None):
 o=bpy.data.objects.new(name,None);col.objects.link(o);o.location=loc;bpy.context.view_layer.update()
 if parent:
  mw=o.matrix_world.copy();o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted();o.matrix_world=mw
 o.empty_display_type="PLAIN_AXES";o.empty_display_size=.16;created.append(o);return o
root=empty("TURRET_TRAVERSE",(0,0,1.70))
pivot=empty("LOBBER_ELEVATION",(0,.03,2.43),root)
plane=empty("SYMMETRY_CENTRELINE_X0",(0,0,0),root)
def texture_material(name,key,color,metal,rough):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;p=n.get("Principled BSDF")
 p.inputs["Base Color"].default_value=(*color,1);p.inputs["Metallic"].default_value=metal;p.inputs["Roughness"].default_value=rough
 im=bpy.data.images.load(str(T/(key+".png")),check_existing=True);im.pack()
 uv=n.new("ShaderNodeTexCoord");tex=n.new("ShaderNodeTexImage");tex.image=im;l.new(uv.outputs["UV"],tex.inputs["Vector"]);l.new(tex.outputs["Color"],p.inputs["Base Color"])
 return m
iron=texture_material("CAST_IRON | existing dark gunmetal tile","02_dark_gunmetal",(.035,.037,.04),.72,.86)
red=texture_material("FIN | existing oxide red tile","01_oxide_red_paint",(.22,.035,.02),.35,.74)
steel=texture_material("BEARING | existing machined steel tile","03_worn_machined_steel",(.12,.12,.12),.8,.65)
inner=bpy.data.materials.new("CAST_IRON | dark bore interior");inner.diffuse_color=(.018,.019,.021,1);inner.use_nodes=True
p=inner.node_tree.nodes.get("Principled BSDF");p.inputs["Base Color"].default_value=(.018,.019,.021,1);p.inputs["Metallic"].default_value=.6;p.inputs["Roughness"].default_value=.94
def own(o,name,mat,parent=pivot):
 o.name=name
 for c in list(o.users_collection):c.objects.unlink(o)
 col.objects.link(o);o.data.materials.clear();o.data.materials.append(mat);bpy.context.view_layer.update();mw=o.matrix_world.copy();o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted();o.matrix_world=mw;created.append(o);return o
def mesh(name,vs,fs,mat,parent=pivot):
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(name,me);col.objects.link(o);return own(o,name,mat,parent)
def mirrored(o):
 m=o.modifiers.new("Mirror three cannons into three opposite cannons","MIRROR");m.use_axis[0]=True;m.use_axis[1]=False;m.use_axis[2]=False;m.mirror_object=plane;m.use_mirror_merge=True
 return o
def cylinder(name,a,b,r,mat,parent=pivot):
 a,b=Vector(a),Vector(b);d=b-a;bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=r,depth=d.length,location=(a+b)/2);o=bpy.context.object;o.rotation_euler=d.to_track_quat("Z","Y").to_euler();return own(o,name,mat,parent)
def cube(name,loc,size,mat,parent=pivot):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);own(o,name,mat,parent)
 m=o.modifiers.new("Small casting edge radius","BEVEL");m.width=.018;m.segments=3;o.modifiers.new("Weighted normals","WEIGHTED_NORMAL");return o
def smooth(points,n=8):
 p=[Vector(v) for v in points];result=[]
 for i in range(len(p)-1):
  a=p[max(0,i-1)];b=p[i];c=p[i+1];d=p[min(len(p)-1,i+2)]
  for j in range(n):
   t=j/n;result.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
 result.append(p[-1]);return result
axis=Vector((0,-.5,math.sqrt(.75)))
u=Vector((1,0,0));w=axis.cross(u).normalized()
# A short, bulbous, open-bore casting. The separate torus supplies the pronounced
# rounded bagel-like mouth; the feeder enters the open centre of the bottom.
profile=[(.070,-.285),(.110,-.285),(.140,-.255),(.158,-.200),(.162,-.100),(.153,.020),(.148,.120),(.150,.200),(.150,.245),(.137,.265),(.107,.265),(.102,.220),(.100,.040),(.100,-.100),(.088,-.190),(.070,-.210)]
def cannon(name,C):
 N=64;vs=[tuple(C+axis*t+u*(r*math.cos(j*2*math.pi/N))+w*(r*math.sin(j*2*math.pi/N))) for r,t in profile for j in range(N)]
 fs=[]
 for k in range(len(profile)):
  for j in range(N):fs.append((k*N+j,k*N+(j+1)%N,((k+1)%len(profile))*N+(j+1)%N,((k+1)%len(profile))*N+j))
 o=mesh(name,vs,fs,iron);o.data.materials.append(inner)
 for f in o.data.polygons:
  f.use_smooth=True
  if f.index//N>=10:f.material_index=1
 return mirrored(o)
def feeder(name,path):
 points=smooth(path,8);N=24;vs=[]
 # Hollow pipe walls. Both ends terminate inside a fin socket or cannon breech.
 for radius in [.068,.045]:
  for i,c in enumerate(points):
   tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
   a=tangent.cross(Vector((0,0,1)))
   if a.length<.1:a=tangent.cross(Vector((0,1,0)))
   a.normalize();b=tangent.cross(a).normalized()
   for j in range(N):vs.append(tuple(c+radius*(a*math.cos(j*2*math.pi/N)+b*math.sin(j*2*math.pi/N))))
 fs=[];L=len(points);offset=L*N
 for layer in [0,1]:
  q=layer*offset
  for i in range(L-1):
   for j in range(N):fs.append((q+i*N+j,q+i*N+(j+1)%N,q+(i+1)*N+(j+1)%N,q+(i+1)*N+j))
 for i in [0,L-1]:
  for j in range(N):fs.append((i*N+j,i*N+(j+1)%N,offset+i*N+(j+1)%N,offset+i*N+j))
 o=mirrored(mesh(name,vs,fs,iron))
 for f in o.data.polygons:f.use_smooth=True
 return o
cylinder("ROTARY_ADAPTER",(0,0,1.70),(0,0,1.82),.78,iron,root)
cube("FIN_ROOT",(0,.03,1.89),(.34,.62,.14),red,root)
# The fin is the shared centreline structure, not a box around the cannons.
outline=[(.20,1.96),(.22,3.18),(.08,3.25),(-.12,2.90),(-.37,2.53),(-.65,2.15),(-.61,1.98)]
vs=[(x,y,z) for x in [-.06,.06] for y,z in outline];L=len(outline)
fs=[tuple(reversed(range(L))),tuple(range(L,2*L))]+[(i,(i+1)%L,(i+1)%L+L,i+L) for i in range(L)]
fin=mesh("CENTRAL_FIN",vs,fs,red)
b=fin.modifiers.new("Rounded fin edges","BEVEL");b.width=.018;b.segments=3;fin.modifiers.new("Fin weighted normals","WEIGHTED_NORMAL")
records=[]
for row in range(3):
 C=Vector((-.27,.04-.26*row,3.10-.38*row));body=cannon("CAST_CANNON_LEFT_%d"%(row+1),C)
 muzzle=C+axis*.265
 bpy.ops.mesh.primitive_torus_add(major_radius=.137,minor_radius=.035,major_segments=64,minor_segments=16,location=muzzle)
 lip=bpy.context.object;lip.rotation_euler=axis.to_track_quat("Z","Y").to_euler();mirrored(own(lip,"ROUNDED_MUZZLE_LEFT_%d"%(row+1),iron))
 for f in lip.data.polygons:f.use_smooth=True
 # Small paired trunnion stubs carry each casting directly into the central fin.
 mirrored(cylinder("FIN_TO_CANNON_MOUNT_%d"%(row+1),(-.06,C.y,C.z),(-.17,C.y,C.z),.085,iron))
 end=C-axis*.285
 start=Vector((-.055,C.y+.14,max(2.03,C.z-.39)))
 path=[start,Vector((-.15,start.y,start.z)),Vector((-.25,C.y+.23,C.z-.38)),end-axis*.10,end]
 feeder("BOTTOM_FEED_LEFT_%d"%(row+1),path)
 # Feed socket is part of the cannon's bottom, and the pipe end coincides with it.
 mirrored(cylinder("BOTTOM_FEED_SOCKET_LEFT_%d"%(row+1),end-axis*.022,end+axis*.02,.080,iron))
 records.append({"station":row+1,"left_cannon_center":list(C),"left_feeder_start_on_fin":list(start),"left_feeder_end":list(end),"left_breech_feed_center":list(end),"mirrors_to_right":True})
bpy.context.view_layer.update()
bpy.ops.object.select_all(action="DESELECT")
for o in col.objects:
 if o.type=="MESH":o.select_set(True)
bpy.context.view_layer.objects.active=fin
bpy.ops.object.mode_set(mode="EDIT");bpy.ops.mesh.select_all(action="SELECT");bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.02);bpy.ops.object.mode_set(mode="OBJECT")
# Native source retains the half-model + Mirror modifiers for direct review.
for o in col.objects:
 if o.type=="MESH" and any(m.type=="MIRROR" for m in o.modifiers):
  assert max((o.matrix_world@v.co).x for v in o.data.vertices)<.00001,o.name
report={"revision":"V04 six cast-iron lobber cannons","source_cannons_on_one_side":3,"total_cannons_after_mirroring":6,"rounded_muzzle_rims_after_mirroring":6,"bottom_feeders_after_mirroring":6,"central_fin_count":1,"bearing_interface_z":1.70,"connections":records,"existing_bunker_modified":False,"scope":"turret-only native asset; existing bunker not loaded or replaced"}
assert len([o for o in col.objects if o.name.startswith("CAST_CANNON_LEFT_")])==3
assert len([o for o in col.objects if o.name.startswith("BOTTOM_FEED_LEFT_")])==3
for r in records:assert r["left_feeder_end"]==r["left_breech_feed_center"]
S.render.engine="CYCLES";S.cycles.device="CPU";S.cycles.samples=32;S.cycles.use_denoising=True
S.render.resolution_x=S.render.resolution_y=1000;S.render.resolution_percentage=100;S.render.film_transparent=True;S.render.image_settings.file_format="PNG";S.render.image_settings.color_mode="RGBA"
S.world=bpy.data.worlds.new("Studio world");S.world.use_nodes=True;bg=S.world.node_tree.nodes.get("Background");bg.inputs["Color"].default_value=(.12,.14,.18,1);bg.inputs["Strength"].default_value=.4
for name,loc,power,size in [("Key",(-3,-4,6),650,4),("Fill",(4,-2,4),350,5),("Rear",(1,4,5),550,3)]:
 d=bpy.data.lights.new(name,"AREA");d.energy=power;d.shape="DISK";d.size=size;o=bpy.data.objects.new(name,d);S.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,2.6))-o.location).to_track_quat("-Z","Y").to_euler()
d=bpy.data.cameras.new("Review camera");cam=bpy.data.objects.new(d.name,d);S.collection.objects.link(cam);S.camera=cam;d.type="ORTHO";d.ortho_scale=2.65
def set_camera(pos):
 cam.location=pos;cam.rotation_euler=(Vector((0,-.16,2.58))-cam.location).to_track_quat("-Z","Y").to_euler()
set_camera((-4,-6,4.3))
bpy.ops.wm.save_as_mainfile(filepath=str(O/"six_cast_iron_lobber_v04.blend"),compress=True)
for view,pos in [("oblique",(-4,-6,4.3)),("front",(0,-7,3.1)),("side",(-7,0,2.8)),("feeders",(-4,4,2.2))]:
 set_camera(pos);S.render.filepath=str(O/("six_lobber_"+view+".png"));bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action="DESELECT")
for o in col.objects:o.select_set(True)
bpy.context.view_layer.objects.active=fin;bpy.ops.export_scene.gltf(filepath=str(O/"six_cast_iron_lobber_v04.glb"),use_selection=True,export_format="GLB",export_apply=True,export_animations=False)
native_meshes=sum(o.type=="MESH" for o in col.objects)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(O/"six_cast_iron_lobber_v04.glb"))
imported=[o for o in bpy.context.scene.objects if o.type=="MESH"]
assert len(imported)==native_meshes
assert len([o for o in imported if o.name.startswith("CAST_CANNON_LEFT_")])==3
# Each source casting's exported mesh must occupy both sides of the fin.
for o in imported:
 if o.name.startswith("CAST_CANNON_LEFT_"):
  xs=[(o.matrix_world@v.co).x for v in o.data.vertices]
  assert min(xs)<-.15 and max(xs)>.15,o.name
report["glb_reimported"]=True;report["native_mesh_count"]=native_meshes;report["exported_casting_objects_each_contain_one_mirrored_pair"]=True
(O/"validation.json").write_text(json.dumps(report,indent=2))
print("SIX_CAST_IRON_LOBBER_RENDERED_AND_REIMPORTED")
