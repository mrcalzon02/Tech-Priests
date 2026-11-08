"""Calibrate boiler V04 and rebuild its two external ports to the condenser pipe standard."""
import bpy,bmesh,math,json,hashlib,struct
from pathlib import Path
from mathutils import Vector,Matrix
R=Path(__file__).resolve().parent;D=R/'boiler_v05';D.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(R/'boiler_reference/boiler/v04/tech_priests_emergency_boiler_v04.blend'))
s=bpy.context.scene
old_port_prefix=('Water external connection','Steam external connection','Water intake rear left','Steam outlet rear right','Water main vessel receiver','Steam right pressure')
old=[o for o in s.objects if o.type=='MESH' and o.name.startswith(old_port_prefix)]
for o in old:bpy.data.objects.remove(o,do_unlink=True)
for name in ['BOILER_WATER_INLET','BOILER_STEAM_OUTLET']:
 o=bpy.data.objects.get(name)
 if o:bpy.data.objects.remove(o,do_unlink=True)
core=[o for o in s.objects if o.type=='MESH'];assert len(core)==202,len(core)
def sig(o):return hashlib.sha256(b''.join(struct.pack('3f',*v.co) for v in o.data.vertices)).hexdigest()
before={o.name:sig(o) for o in core}
f=bpy.data.objects['Boiler continuous foundation'];bb=[f.matrix_world@Vector(v) for v in f.bound_box]
center=Vector(((min(v.x for v in bb)+max(v.x for v in bb))/2,(min(v.y for v in bb)+max(v.y for v in bb))/2,min(v.z for v in bb)))
scale=1.9/(max(v.y for v in bb)-min(v.y for v in bb));T=Matrix.Scale(scale,4)@Matrix.Translation(-center)
for o in list(s.objects):
 o.matrix_world=T@o.matrix_world
 if o.type=='LIGHT':
  o.data.energy*=scale*scale
  if o.data.type=='AREA':o.data.size*=scale
 if o.type=='CAMERA' and o.data.type=='ORTHO':o.data.ortho_scale*=scale
root=bpy.data.objects.new('BOILER_TILE_CALIBRATION',None);s.collection.objects.link(root);root['units_per_tile']=1.;root['footprint_tiles']=[2,2]
for o in core:mw=o.matrix_world.copy();o.parent=root;o.matrix_world=mw
# Reuse the condenser's actual collar and packed neck-finish materials.
with bpy.data.libraries.load(str(R/'condenser_v21/tech_priests_water_condenser_v21.blend'),link=False) as (src,dst):
 dst.materials=[n for n in src.materials if n in ['Condenser outlet body-to-pipe aged metal','Outlet aged steel','Reference pipe steel']]
transition=next(m for m in dst.materials if m and m.name.startswith('Condenser outlet body-to-pipe'));transition=transition.copy();transition.name='Boiler body-to-adjacent-pipe metal'
collar=next(m for m in dst.materials if m and m.name.startswith('Outlet aged steel'))
refsteel=next(m for m in dst.materials if m and m.name.startswith('Reference pipe steel'))
iron=bpy.data.materials.get('Emergency shared iron') or core[0].data.materials[0]
ports=bpy.data.collections.new('BOILER_EXTERNAL_FLUID_PORTS');s.collection.children.link(ports)
refs=bpy.data.collections.new('BOILER_REFERENCE_ADJACENT_PIPES');s.collection.children.link(refs)
added=[]
def mesh(name,vs,fs,mat,col=ports):
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free();o=bpy.data.objects.new(name,me);col.objects.link(o);me.materials.append(mat)
 for p in me.polygons:p.use_smooth=True
 if col==ports:added.append(o)
 return o
def ring(name,P,N,ro,ri,depth,mat,col=ports):
 P=Vector(P);N=Vector(N).normalized();q=N.to_track_quat('Z','Y');n=64;vs=[];fs=[]
 for z,r in [(-depth/2,ro),(depth/2,ro),(-depth/2,ri),(depth/2,ri)]:vs.extend(P+q@Vector((r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n),z)) for i in range(n))
 for i in range(n):
  j=(i+1)%n;fs.extend([(i,j,n+j,n+i),(n+i,n+j,3*n+j,3*n+i),(2*n+j,2*n+i,3*n+i,3*n+j),(j,i,2*n+i,2*n+j)])
 o=mesh(name,vs,fs,mat,col)
 for p in o.data.polygons:p.use_smooth=abs(p.normal.dot(N))<.5
 m=o.modifiers.new('Rolled edge break','BEVEL');m.width=.003;m.segments=3
 return o
def tube(name,points,radii):
 ps=[Vector(p) for p in points];pts=[];rs=[]
 for i in range(len(ps)-1):
  a=ps[max(i-1,0)];b=ps[i];c=ps[i+1];d=ps[min(i+2,len(ps)-1)]
  for j in range(12):
   t=j/12;pts.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t));rs.append(radii[i]*(1-t)+radii[i+1]*t)
 pts.append(ps[-1]);rs.append(radii[-1]);n=64;vs=[];fs=[];dist=[0]
 for a,b in zip(pts,pts[1:]):dist.append(dist[-1]+(b-a).length)
 for i,p in enumerate(pts):
  tangent=((ps[1]-ps[0]) if i==0 else (ps[-1]-ps[-2]) if i==len(pts)-1 else pts[i+1]-pts[i-1]).normalized();u=tangent.cross(Vector((0,0,1)))
  if u.length<.01:u=tangent.cross(Vector((0,1,0)))
  u.normalize();v=tangent.cross(u).normalized()
  for radius in [rs[i],rs[i]*(.245/.285)]:vs.extend(p+radius*(math.cos(j*math.tau/n)*u+math.sin(j*math.tau/n)*v) for j in range(n))
 for i in range(len(pts)-1):
  for j in range(n):
   a=i*2*n+j;b=i*2*n+(j+1)%n;c=(i+1)*2*n+(j+1)%n;d=(i+1)*2*n+j;fs.extend([(a,b,c,d),(a+n,d+n,c+n,b+n)])
 for i in [0,len(pts)-1]:
  for j in range(n):a=i*2*n+j;b=i*2*n+(j+1)%n;fs.append((a,a+n,b+n,b))
 o=mesh(name,vs,fs,transition);uv=o.data.uv_layers.new(name='OutletTransitionUV')
 for p in o.data.polygons:
  angles=[(o.data.loops[li].vertex_index%n)/n for li in p.loop_indices]
  for li,a in zip(p.loop_indices,angles):
   vi=o.data.loops[li].vertex_index;k=vi//(2*n)
   if max(angles)-min(angles)>.5 and a<.5:a+=1
   uv.data[li].uv=(1-dist[k]/dist[-1],a)
 return o
water_end=T@Vector((-.258789,.150,.320));water_pre=T@Vector((-.258789,.225,.320))
steam_end=T@Vector((.269125,.124894,.369));steam_pre=T@Vector((.3278,.1836,.369))
paths={'Water':[(-1,.5,.36),(-.83,.5,.36),(-.68,.5,.39),(-.55,.5,.48),water_pre,water_end],'Steam':[(1,.5,.36),(.83,.5,.36),(.72,.5,.4),(.66,.5,.54),steam_pre,steam_end]}
for label,points in paths.items():
 sign=-1 if label=='Water' else 1;N=Vector((sign,0,0));P=Vector(points[0]);tube(label+' full-size reducing elbow',points,[.285,.285,.22,.155,.115,.10])
 ring(label+' matching external flange',P-N*.0375,N,.34,.245,.075,collar)
 ring(label+' inner rolled throat',P-N*.01,N,.285,.245,.02,collar)
 end=Vector(points[-1]);endN=(end-Vector(points[-2])).normalized();ring(label+' seated vessel receiver',end-endN*.012,endN,.125,.086,.06,iron)
 ring(label+' vessel union rim',end-endN*.035,endN,.135,.10,.012,iron)
 marker=bpy.data.objects.new('BOILER_'+label.upper()+'_PORT',None);ports.objects.link(marker);marker.location=P;marker['factorio_position']=[sign*.5,-.5];marker['adjacent_pipe_center']=[sign*1.5,-.5]
 ring(label+' reference one-tile barrel',Vector((sign*1.5,.5,.36)),N,.285,.245,1.,refsteel,refs)
 ring(label+' reference near collar',Vector((sign*1.0375,.5,.36)),N,.34,.245,.075,collar,refs)
 ring(label+' reference far collar',Vector((sign*1.9625,.5,.36)),N,.34,.245,.075,collar,refs)
bpy.context.view_layer.update();assert all(sig(bpy.data.objects[n])==v for n,v in before.items())
checks=[]
for o in added:
 bm=bmesh.new();bm.from_mesh(o.data);bad=sum(not e.is_manifold for e in bm.edges);bm.free();checks.append({'mesh':o.name,'nonmanifold_edges':bad});assert bad==0
record={'revision':'V05','core_meshes_preserved':202,'source_vertex_hashes':before,'new_port_meshes':len(added),'uniform_scale':scale,'ground_center_transform':list(center),'footprint_tiles':[2,2],'foundation_dimensions':list(f.dimensions),'water_mouth':[-1,.5,.36],'steam_mouth':[1,.5,.36],'mouth_body_diameter':.57,'flange_diameter':.68,'bore_diameter':.49,'water_vessel_seat':list(water_end),'steam_vessel_seat':list(steam_end),'closed_port_mesh_checks':checks,'finish':'Packed condenser metal transition and exact matching collar material','camera_elevation':45,'runtime_integration':'Existing two-port patch remains unapplied; no runtime validation claimed'}
(D/'Boiler_V05_Validation.json').write_text(json.dumps(record,indent=2))
cam=bpy.data.objects.new('BOILER_FACTORIO_EXPORT_45',bpy.data.cameras.new('BOILER_FACTORIO_EXPORT_45'));s.collection.objects.link(cam);cam.location=(0,-6,6.37);cam.rotation_euler=(Vector((0,0,.37))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=4.65;s.camera=cam
s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=24;s.render.resolution_x=1200;s.render.resolution_y=850;s.render.resolution_percentage=100;s.render.film_transparent=False
s['asset_revision']='Boiler V05 calibrated 2x2 and matching rear water/steam pipe connections';bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(D/'tech_priests_emergency_boiler_v05.blend'),compress=True)
s.render.filepath=str(D/'Boiler_V05_Pipe_Fit.png');bpy.ops.render.render(write_still=True)
refs.hide_render=True;cam.data.ortho_scale=2.65;s.render.resolution_x=900;s.render.resolution_y=900
asset=core+added;world={o.name:o.matrix_world.copy() for o in asset}
for label,degrees in [('North',0),('East',-90)]:
 rot=Matrix.Rotation(math.radians(degrees),4,'Z')
 for o in asset:o.matrix_world=rot@world[o.name]
 s.render.filepath=str(D/('Boiler_V05_'+label+'.png'));bpy.ops.render.render(write_still=True)
for o in asset:o.matrix_world=world[o.name]
for o in s.objects:o.select_set(False)
for o in asset:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(D/'tech_priests_emergency_boiler_v05.glb'),export_format='GLB',use_selection=True,export_apply=True)
print('BOILER_V05_COMPLETE',len(core),len(added),flush=True)
