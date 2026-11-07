"""V05 visual game-asset loader for loose pineapple grenades.
Preserve V04 cannon meshes, X/Y positions and aim; translate complete upper
stations vertically only. This is an exterior concept, not a functional
weapon mechanism, and contains no arming or fuze-actuation design.
"""
import bpy,math,json,hashlib,shutil,os
from pathlib import Path
from mathutils import Vector,Matrix
O=Path("art/source-to-3d/martian-bunker/alternatives/v05").resolve()
source=O.parent/"v04"/"six_cast_iron_lobber_v04.blend"
O.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source))
S=bpy.context.scene;S.frame_set(1);bpy.context.view_layer.update()
col=bpy.data.collections["SIX_CAST_IRON_LOBBER"];col.name="SIX_LOBBER_LOOSE_GRENADE_LOADERS"
root=bpy.data.objects["TURRET_TRAVERSE"];pivot=bpy.data.objects["LOBBER_ELEVATION"];plane=bpy.data.objects["SYMMETRY_CENTRELINE_X0"]
iron=bpy.data.materials["CAST_IRON | existing dark gunmetal tile"]
red=bpy.data.materials["FIN | existing oxide red tile"]
steel=bpy.data.materials.new("LOADER | grey steel");steel.use_nodes=True
p=steel.node_tree.nodes.get("Principled BSDF");p.inputs["Base Color"].default_value=(.16,.18,.16,1);p.inputs["Metallic"].default_value=.65;p.inputs["Roughness"].default_value=.66
inner=bpy.data.materials["CAST_IRON | dark bore interior"]
original=list(col.objects);before={}
def mesh_hash(o):
 return hashlib.sha256(repr(([tuple(v.co) for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons])).encode()).hexdigest()
for o in original:
 if o.type=="MESH":
  before[o.name]={"hash":mesh_hash(o),"world":[list(r) for r in o.matrix_world],"uv":[[(float(v.uv.x),float(v.uv.y)) for v in layer.data] for layer in o.data.uv_layers]}
# Upper station +.28, middle +.14, lower fixed. All air-feed parts translate
# together with their original cannon; no barrel geometry or angle changes.
offsets={1:.28,2:.14,3:0.}
station_prefixes=("CAST_CANNON_LEFT_","ROUNDED_MUZZLE_LEFT_","FIN_TO_CANNON_MOUNT_","BOTTOM_FEED_LEFT_","BOTTOM_FEED_SOCKET_LEFT_")
for o in original:
 if o.name.startswith(station_prefixes):
  station=int(o.name.rsplit("_",1)[1]);mw=o.matrix_world.copy();mw.translation.z+=offsets[station];o.matrix_world=mw
fin=bpy.data.objects["CENTRAL_FIN"]
for v in fin.data.vertices:
 v.co.z+=max(0,min(1,(v.co.z-1.96)/(3.25-1.96)))*.28
bpy.context.view_layer.update()
for o in original:
 if o.type!="MESH" or o.name=="CENTRAL_FIN":continue
 assert mesh_hash(o)==before[o.name]["hash"],o.name
 expected=Matrix(before[o.name]["world"])
 if o.name.startswith(station_prefixes):expected.translation.z+=offsets[int(o.name.rsplit("_",1)[1])]
 assert max(abs(o.matrix_world[i][j]-expected[i][j]) for i in range(4) for j in range(4))<.00001,o.name
 assert before[o.name]["uv"]==[[(float(v.uv.x),float(v.uv.y)) for v in layer.data] for layer in o.data.uv_layers],o.name
created=[]

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


def matte(name,color,rough=.8,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get("Principled BSDF");p.inputs["Base Color"].default_value=(*color,1);p.inputs["Roughness"].default_value=rough;p.inputs["Metallic"].default_value=metal;return m
olive=matte("GRENADE | olive green raised pineapple segments",(.085,.145,.025))
groove=matte("GRENADE | dark green groove underbody",(.018,.030,.008))
spoon=matte("GRENADE | attached grey spoon and ring",(.22,.235,.22),.58,.65)
def small_cube(name,C,size,mat,R=Matrix.Identity(3),mirror=True):
 o=cube(name,C,size,mat);o.rotation_euler=R.to_euler();o.modifiers.get("Small casting edge radius").width=min(.006,min(size)*.2)
 if mirror:mirrored(o)
 return o
def rod(name,a,b,r,mat=steel):
 return mirrored(cylinder(name,a,b,r,mat))
def loose_grenade(name,C,R=Matrix.Identity(3)):
 C=Vector(C)
 def point(p):return C+R@Vector(p)
 # Dark ovoid underbody with raised individual green tiles over it.
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,radius=1,location=C)
 body=bpy.context.object;body.scale=(.049,.049,.071);body.rotation_euler=R.to_euler();own(body,name+"_PINEAPPLE_BODY",groove);mirrored(body)
 for p in body.data.polygons:p.use_smooth=True
 vs=[];fs=[]
 for row in range(5):
  lo=-1.20+row*2.40/5+.035;hi=-1.20+(row+1)*2.40/5-.035
  for column in range(8):
   a=column*math.tau/8+.045;b=(column+1)*math.tau/8-.045;start=len(vs)
   for radius in [.049,.055]:
    for phi,theta in [(lo,a),(lo,b),(hi,b),(hi,a)]:
     vs.append(tuple(point((radius*math.cos(phi)*math.cos(theta),radius*math.cos(phi)*math.sin(theta),.072*math.sin(phi)))))
   fs.extend(tuple(start+i for i in f) for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
 mirrored(mesh(name+"_RAISED_SEGMENTS",vs,fs,olive))
 neck=cylinder(name+"_NECK",point((0,0,.066)),point((0,0,.087)),.019,spoon);mirrored(neck)
 # Classic attached spoon silhouette; no pin pulling or arming is modeled.
 for i,(a,b) in enumerate([((0,0,.088),(-.038,0,.088)),((-.038,0,.088),(-.060,0,.033)),((-.060,0,.033),(-.046,0,-.044))]):
  a,b=Vector(a),Vector(b);d=b-a
  small_cube(name+"_SPOON_"+str(i),point((a+b)/2),(.010,.019,d.length),spoon,R@d.to_track_quat("Z","Y").to_matrix())
 bpy.ops.mesh.primitive_torus_add(major_radius=.016,minor_radius=.0035,major_segments=24,minor_segments=8,location=point((-.023,.014,.084)))
 ring=bpy.context.object;ring.rotation_euler=(R@Matrix.Rotation(math.pi/2,3,"Y")).to_euler();own(ring,name+"_PULL_RING",spoon);mirrored(ring)
 return body
def open_trough(name,points,width=.145,height=.072,wall=.014):
 path=smooth(points,6);section=[(-width/2,height),(-width/2,0),(width/2,0),(width/2,height),(width/2-wall,height),(width/2-wall,wall),(-width/2+wall,wall),(-width/2+wall,height)]
 vs=[]
 for i,c in enumerate(path):
  t=path[min(i+1,len(path)-1)]-path[max(i-1,0)];t.z=0;t.normalize();across=Vector((-t.y,t.x,0))
  for x,z in section:vs.append(tuple(c+across*x+Vector((0,0,z))))
 fs=[tuple(reversed(range(8)))]
 for i in range(len(path)-1):
  for j in range(8):fs.append((i*8+j,i*8+(j+1)%8,(i+1)*8+(j+1)%8,(i+1)*8+j))
 fs.append(tuple((len(path)-1)*8+j for j in range(8)))
 return mirrored(mesh(name,vs,fs,steel))
loaders=[]
for row in range(3):
 C=Vector((-.27,.04-.26*row,3.10-.38*row+offsets[row+1]))
 # One open cradle per cannon. The paired support beam is a single shared
 # centreline part attached into the existing fin.
 cross=cube("CRADLE_SHARED_FIN_SUPPORT_%d"%(row+1),(0,.275,C.z-.18),(.50,.25,.06),red)
 floor=small_cube("OPEN_CRADLE_FLOOR_LEFT_%d"%(row+1),(-.21,.435,C.z-.15),(.24,.28,.025),red)
 small_cube("OPEN_CRADLE_BACK_LEFT_%d"%(row+1),(-.21,.575,C.z-.025),(.24,.020,.25),red)
 for x in [-.335,-.085]:
  for y in [.300,.570]:rod("CRADLE_POST_LEFT", (x,y,C.z-.14),(x,y,C.z+.105),.009)
  for z in [C.z-.060,C.z+.105]:rod("CRADLE_OPEN_RAIL_LEFT",(x,.30,z),(x,.57,z),.009)
 # Loose irregular pieces in an open cradle, not a fitted cartridge belt.
 for j,(y,z) in enumerate([(.370,C.z-.063),(.500,C.z-.063),(.435,C.z+.045)]):
  loose_grenade("HOPPER_LEFT_%d_GRENADE_%d"%(row+1,j+1),(-.21,y,z),Matrix.Rotation([-.10,.12,-.08][j],3,"Y")@Matrix.Rotation([.12,-.15,.08][j],3,"Z"))
 hood=Vector((-.475,C.y+.075,C.z-.13))
 small_cube("SIDE_LOADING_HOOD_LEFT_%d"%(row+1),hood,(.15,.22,.20),iron)
 small_cube("SIDE_LOADING_SHADOW_LEFT_%d"%(row+1),(-.552,hood.y,hood.z),(.006,.145,.10),inner)
 small_cube("LOADING_HOOD_UPPER_GUARD_LEFT_%d"%(row+1),(-.561,hood.y,hood.z+.065),(.035,.19,.025),steel)
 tray_end=Vector((-.535,hood.y,C.z-.17))
 tray_path=[Vector((-.25,.435,C.z-.15)),Vector((-.45,.435,C.z-.15)),Vector((-.535,.365,C.z-.155)),tray_end]
 open_trough("OPEN_GRENADE_GUIDE_LEFT_%d"%(row+1),tray_path)
 # An intact pineapple grenade resting in the visible presentation trough.
 loose_grenade("PRESENTED_LEFT_%d"%(row+1),(-.535,hood.y+.13,C.z-.105),Matrix.Rotation(math.pi/2,3,"X"))
 loaders.append({"station":row+1,"cannon_center":list(C),"only_vertical_translation":offsets[row+1],"cradle_center":[-.21,.435,C.z-.025],"guide_start":list(tray_path[0]),"guide_end_at_side_hood":list(tray_end),"air_feeder_retained":True,"visible_loose_grenades_per_cradle":3})
bpy.context.view_layer.update()
# Unwrap only new geometry. V04 UVs and cannon meshes stay byte-identical.
bpy.ops.object.select_all(action="DESELECT")
for o in created:
 if o.type=="MESH":o.select_set(True)
bpy.context.view_layer.objects.active=created[0]
bpy.ops.object.mode_set(mode="EDIT");bpy.ops.mesh.select_all(action="SELECT");bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.02);bpy.ops.object.mode_set(mode="OBJECT")
for o in original:
 if o.type=="MESH" and o.name!="CENTRAL_FIN":
  assert mesh_hash(o)==before[o.name]["hash"],o.name
report={"revision":"V05 loose pineapple grenade visual loader","total_cannons":6,"loaders_after_mirroring":6,"open_cradles_after_mirroring":6,"source_grenade_bodies":sum(o.name.endswith("_PINEAPPLE_BODY") for o in created),"grenades_after_mirroring":sum(o.name.endswith("_PINEAPPLE_BODY") for o in created)*2,"cannon_shapes_and_UVs_unchanged":True,"cannon_XY_and_aim_angles_unchanged":True,"station_vertical_shifts":{"upper_pair":.28,"middle_pair":.14,"lower_pair":0},"pneumatic_pipe_shapes_and_connections_retained":True,"central_fin_height_increase":.28,"loader_visuals":"Loose olive-green segmented pineapple bodies with attached spoon levers and pull rings, open cradles and guide troughs into exterior side hoods.","no_arming_or_functional_weapon_internals_modeled":True,"existing_bunker_modified":False,"loaders":loaders}
assert report["source_grenade_bodies"]==12
assert len([o for o in created if o.name.startswith("SIDE_LOADING_HOOD_LEFT_")])==3
(O/"model_validation.json").write_text(json.dumps(report,indent=2))
S.render.resolution_x=S.render.resolution_y=int(os.environ.get("LOADER_RENDER_SIZE","1100"));S.render.resolution_percentage=100;S.cycles.samples=int(os.environ.get("LOADER_RENDER_SAMPLES","32"))
cam=S.camera;cam.data.type="ORTHO"
def camera(pos,target=(0,.0,2.75),scale=3.3):
 cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat("-Z","Y").to_euler();cam.data.ortho_scale=scale
camera((-4,-6,4.6))
bpy.ops.wm.save_as_mainfile(filepath=str(O/"six_lobber_loose_grenade_loader_v05.blend"),compress=True)
views=[("oblique",(-4,-6,4.6),(0,0,2.75),3.3),("front",(0,-7,3.2),(0,0,2.75),3.3),("side",(-7,0,3.0),(0,0,2.75),3.3),("loader_rear",(-4,5,4.0),(0,.15,2.75),3.3),("pineapple_detail",(-3,4,4.3),(-.28,.34,3.28),1.25)]
for view,pos,target,scale in views:
 camera(pos,target,scale);S.render.filepath=str(O/("loader_v05_"+view+".png"));bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action="DESELECT")
for o in col.objects:o.select_set(True)
bpy.context.view_layer.objects.active=fin;bpy.ops.export_scene.gltf(filepath=str(O/"six_lobber_loose_grenade_loader_v05.glb"),use_selection=True,export_format="GLB",export_apply=True,export_animations=False)
native_count=sum(o.type=="MESH" for o in col.objects)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(O/"six_lobber_loose_grenade_loader_v05.glb"))
meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
assert len(meshes)==native_count
assert len([o for o in meshes if o.name.startswith("CAST_CANNON_LEFT_")])==3
assert len([o for o in meshes if o.name.startswith("SIDE_LOADING_HOOD_LEFT_")])==3
report["GLB_reimported"]=True;report["native_mesh_count"]=native_count
(O/"model_validation.json").write_text(json.dumps(report,indent=2))
print("V05_LOOSE_GRENADE_LOADER_RENDER_AND_REIMPORT_PASS")
