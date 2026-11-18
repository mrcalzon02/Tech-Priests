"""Arch-arrayed candle holders and mounted internal service density refinement."""
import ast,bpy,bmesh,json,math,sys,hashlib,shutil,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
R=Path(__file__).resolve().parents[3];OLD=R/'art/source-to-3d/conclave-center/v03-authored-housings';O=OLD.parent/'v04-arch-and-services';O.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(OLD/'conclave-center-v03.blend'));s=bpy.context.scene;root=bpy.data.objects['Conclave Center | ground origin'];contacts=json.loads((OLD/'contacts.json').read_text());changes=[]
mats={k:bpy.data.materials.get('Conclave V03 | '+k) or bpy.data.materials.get('Conclave | '+k) for k in ['cast-frame','console-panels','edge-trim','control-keys','floor-tread','cable-jacket']}
mats['wax']=bpy.data.materials['Conclave V03 | aged ritual wax'];mats['flame']=bpy.data.materials['Conclave V03 | static candle flame']
# Reuse geometry helpers only, never execute/rebuild the previous scene.
helper=R/'tools/art/conclave/refine_v03.py';tree=ast.parse(helper.read_text());names={'uv','mesh','box','joint','cylinder','octrect','ring_xz'};defs=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names];exec(compile(ast.Module(body=defs,type_ignores=[]),str(helper),'exec'))
def signatures():
 return {o.name:hashlib.sha256(json.dumps(dict(vertices=[list(v.co) for v in o.data.vertices],uvs=[[list(d.uv) for d in layer.data] for layer in o.data.uv_layers],matrix=[list(row) for row in o.matrix_world]),sort_keys=True).encode()).hexdigest() for o in s.objects if o.name.startswith('Supplied DGordillo low-poly skull')}
skulls_before=signatures()
stations=[(0,.18,0,.60),(-.62,-.17,math.pi/4,.49),(.62,-.17,-math.pi/4,.49)]
def own_uv(o,name,material):o.name=name;o.parent=root;o.data.materials.clear();o.data.materials.append(material);uv(o);return o
def bead(name,p,r,material):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=r,location=p);return own_uv(bpy.context.object,name,material)
def ring_xy(name,p,outer,inner,z0,z1,material='edge-trim'):
 n=32;v=[(p[0]+r*math.cos(math.tau*i/n),p[1]+r*math.sin(math.tau*i/n),p[2]+z) for r,z in [(outer,z0),(outer,z1),(inner,z1),(inner,z0)] for i in range(n)];f=[]
 for k in range(4):
  for i in range(n):j=(i+1)%n;f.append((k*n+i,k*n+j,((k+1)%4)*n+j,((k+1)%4)*n+i))
 return mesh(name,v,f,material,bevel=.002)
# Remove the old flat-row ritual fixtures, including obsolete original lamp stems.
removed=[]
for obj in list(s.objects):
 if obj.name.startswith(('Candle cup structural stem','Retained ritual candle cup','Wax candle','Candle wick','Static candle flame','Shrine lamp mounted stem')):
  removed.append(obj.name);bpy.data.objects.remove(obj,do_unlink=True)
contacts=[row for row in contacts if row['a'] not in removed and row['b'] not in removed]
arc=[]
for index,degrees in enumerate((18,36,54,72,90,108,126,144,162)):
 angle=math.radians(degrees);radial=Vector((math.cos(angle),0,math.sin(angle)));tangent=Vector((-math.sin(angle),0,math.cos(angle)))
 anchor=Vector((.555*math.cos(angle),.455,1.37+.555*math.sin(angle)))
 cupcenter=Vector((.654*math.cos(angle),.355+.045*math.sin(angle),1.37+.654*math.sin(angle)+.042))
 boss=cylinder('Arch candle saddle %02d'%index,anchor+Vector((0,.02,0)),anchor-Vector((0,.035,0)),.042,'edge-trim',24);joint(boss,'Crown cog continuous rim','saddle embeds in actual curved crown ring')
 for sign in (-1,1):
  p=anchor+tangent*sign*.027;bolt=cylinder('Arch candle saddle captive bolt '+str((index,sign)),p-Vector((0,.048,0)),p-Vector((0,.022,0)),.009,'control-keys',6);joint(bolt,boss,'captive fastener seated on candle saddle')
 a=anchor-Vector((0,.034,0));b=cupcenter-Vector((0,0,.018));arm=cylinder('Arch candle radial bracket %02d'%index,a,b,.018,'edge-trim',20);joint(arm,boss,'individual radial bracket fixed to arch saddle')
 stem=cylinder('Arch candle upright neck %02d'%index,b,cupcenter+Vector((0,0,.006)),.026,'edge-trim',24);joint(stem,arm,'upright neck seats level cup on angled bracket')
 # Closed bottom bowl with raised rim; candle base sits on its floor.
 cup=cylinder('Arch candle bowl bottom %02d'%index,cupcenter-Vector((0,0,.009)),cupcenter+Vector((0,0,.004)),.046,'edge-trim',32);joint(cup,stem,'bowl bottom retained by upright neck')
 rim=ring_xy('Arch candle bowl rim %02d'%index,cupcenter,.054,.034,.002,.024);joint(rim,cup,'annular bowl rim seated on closed floor')
 height=.142+(.020 if index%3==0 else .004 if index%3==1 else -.008)
 # Melted lip and wax relief are part of one continuous candle mesh.
 n=32;verts=[]
 for row,(z,base_r) in enumerate(((.003,.027),(.040,.027),(height-.024,.028),(height,.029),(height-.014,.010))):
  for j in range(n):
   a=j*math.tau/n;relief=.0024*max(0,math.cos(a-1.1))**12*(1 if row in (1,2,3) else .25);zz=z+(.003*math.sin(3*a+index) if row==3 else 0);verts.append(tuple(cupcenter+Vector(((base_r+relief)*math.cos(a),(base_r+relief)*math.sin(a),zz))))
 faces=[tuple(range(n-1,-1,-1)),tuple(4*n+j for j in range(n))]
 for k in range(4):
  for j in range(n):q=(j+1)%n;faces.append((k*n+j,k*n+q,(k+1)*n+q,(k+1)*n+j))
 candle=mesh('Arch wax candle %02d'%index,verts,faces,'wax',bevel=0);joint(candle,cup,'wax base seated on cup floor')
 wickbase=cupcenter+Vector((0,0,height-.013));wicktop=cupcenter+Vector((0,0,height+.020));wick=cylinder('Arch candle wick %02d'%index,wickbase,wicktop,.0038,'cable-jacket',8);joint(wick,candle,'wick retained in depressed wax centre')
 p=cupcenter+Vector((0,0,height+.042));bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=10,radius=1,location=p);fl=bpy.context.object
 for v in fl.data.vertices:
  v.co.x*=.014*(1-.55*max(v.co.z,0));v.co.y*=.014*(1-.55*max(v.co.z,0));v.co.z*=.041
 own_uv(fl,'Arch candle static flame %02d'%index,mats['flame']);joint(fl,wick,'static flame begins at wick tip')
 arc.append(dict(index=index,angle_degrees=degrees,arch_anchor=list(anchor),cup_center=list(cupcenter),candle_height=height,saddle=boss.name,bracket=arm.name))
# Purpose-specific jacket colours: separate signal and insulated return wires.
for key,color in [('signal-red',(.16,.025,.016,1)),('signal-amber',(.25,.15,.028,1)),('signal-black',(.014,.018,.02,1))]:
 mat=mats['cable-jacket'].copy();mat.name='Conclave V04 | '+key;bs=mat.node_tree.nodes.get('Principled BSDF')
 for link in list(mat.node_tree.links):
  if link.to_socket==bs.inputs['Base Color']:mat.node_tree.links.remove(link)
 bs.inputs['Base Color'].default_value=color;bs.inputs['Roughness'].default_value=.72;mats[key]=mat
spec=importlib.util.spec_from_file_location('conclave_v04_pipette',R/'tools/fmpl/pipette/blender_adapter.py');adapter=importlib.util.module_from_spec(spec);sys.modules[spec.name]=adapter;spec.loader.exec_module(adapter)
requests=json.loads((OLD/'pipette-requests.json').read_text());plans=json.loads((OLD/'pipette-plans.json').read_text());additional=[]
def smooth(points,samples=6):
 ps=[Vector(p) for p in points];result=[]
 for i in range(len(ps)-1):
  a,b,c,d=ps[max(0,i-1)],ps[i],ps[i+1],ps[min(len(ps)-1,i+2)]
  for j in range(samples):
   t=j/samples;result.append(list(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)))
 result.append(list(ps[-1]));return result
def service(name,points,start,end,family='single_wire',diameter=.02,material='cable-jacket',payload='signal',corrugated=False):
 centerline=smooth(points);a,b=Vector(centerline[0]),Vector(centerline[-1]);fit='compression' if payload=='empty' else 'cable_gland'
 request=dict(id='conclave-v04-'+name,family=family,payload=payload,size=dict(outer_diameter=diameter,wall_fraction=.2 if family in ('flex_hose','segmented_conduit','conduit') else 0),material_id=mats[material].name,path=dict(kind='waypoints',points=centerline),start_socket=dict(id=name+'.start',xyz=list(a),normal=list((Vector(centerline[1])-a).normalized()),role='source',payloads=[payload],parent_mesh=start),end_socket=dict(id=name+'.end',xyz=list(b),normal=list((Vector(centerline[-2])-b).normalized()),role='sink',payloads=[payload],parent_mesh=end),fittings=dict(start=fit,end=fit),supports=dict(binding='individual modeled endpoint seats and intermediate retained saddles'),behavior=dict(internal_visual_service_only=True,live_binding_implemented=False,no_external_native_interface=True),keep_outs=[])
 if family=='segmented_conduit':request['joint_pitch']=.070
 if family=='wire_bundle':request['size'].update(conductor_count=3,strand_diameter=.006);request['expose_cores']=False
 if corrugated:request['surface_profile']=dict(corrugation_pitch=.018,corrugation_depth_ratio=.13)
 plan=adapter.core.plan(request);col,objects=adapter.build(plan,mats[material],mats['edge-trim'])
 for obj in objects:obj.parent=root;uv(obj)
 requests.append(request);plans.append(plan);additional.append(dict(id=request['id'],family=family,payload=payload,diameter=diameter,start=start,end=end,objects=[o.name for o in objects]))
 # Check actual built terminal fittings against modeled endpoint seats.
 for terminal,parent in [('start',start),('end',end)]:
  fitting=next((o for o in objects if (' | '+terminal+' ') in o.name),None)
  if fitting:joint(fitting,parent,'built Pipette terminal fitting seated on named service support')
 return objects
# Two protective corrugated hoses, each with a smaller real signal cable inside.
for sign,index in [(-1,1),(1,2)]:
 cx,cy,yaw,w=stations[index];M=Matrix.Translation((cx,cy,0))@Matrix.Rotation(yaw,4,'Z')
 a=list(M@Vector((sign*w*.40,-.045,.49)));shoe=box('V04 sleeve console seat '+str(sign),(sign*w*.40,-.045,.49),(.06,.09,.10),'cast-frame',M,.008);joint(shoe,'Console %d | grounded pedestal'%index,'protective sleeve gland shoe mounted on outer pedestal cheek')
 end=[sign*.64,-.63,.20];ped=box('V04 sleeve sole termination '+str(sign),(sign*.64,-.63,.175),(.12,.11,.10),'cast-frame',bevel=.01);joint(ped,'Octagonal sole casting','return shoe rests on equipment sole')
 points=[a,[sign*.835,-.39,.42],[sign*.84,-.57,.28],[sign*.76,-.68,.22],end]
 service('corrugated-protective-sleeve-'+str(sign),points,shoe.name,ped.name,'flex_hose',.061,'cable-jacket','empty',True)
 service('sleeve-signal-core-'+str(sign),points,shoe.name,ped.name,'wire_bundle',.028,'signal-red')
# Raised rear service columns feed a curved arch raceway rather than stopping in air.
arch_ends={}
for sign in (-1,1):
 a=[sign*.77,.625,.41];theta=math.radians(145 if sign<0 else 35);end=[.63*math.cos(theta),.705,1.37+.63*math.sin(theta)]
 block=box('V04 arch raceway terminal '+str(sign),(end[0],.665,end[2]),(.105,.13,.10),'cast-frame',bevel=.015)
 inner=[.555*math.cos(theta),.555,1.37+.555*math.sin(theta)];outer=[.555*math.cos(theta),.585,1.37+.555*math.sin(theta)]
 foot=cylinder('V04 arch junction retained foot '+str(sign),inner,outer,.031,'edge-trim',24);joint(foot,'Crown cog continuous rim','junction foot embeds at actual arch tube radius')
 neck=cylinder('V04 arch junction radial standoff '+str(sign),outer,[end[0],.665,end[2]],.024,'edge-trim',24);joint(neck,foot,'radial cantilever seats on retained arch foot');joint(block,neck,'junction housing retained by supported radial standoff')
 for z in (.59,.92,1.25):
  support=box('V04 conduit column standoff '+str((sign,z)),(sign*.77,.674,z),(.075,.11,.065),'edge-trim',bevel=.006);joint(support,'Back shrine structural casting','column standoff enters rear shell edge')
 points=[a,[sign*.80,.72,.61],[sign*.80,.735,1.18],[sign*.69,.73,1.55],end]
 service('arch-service-rise-'+str(sign),points,'Lower rear signal junction '+str(sign),block.name,'segmented_conduit',.049)
 arch_ends[sign]=(end,block.name)
points=[[.63*math.cos(math.radians(d)),.705,1.37+.63*math.sin(math.radians(d))] for d in range(145,34,-5)]
service('curved-arch-raceway',points,arch_ends[-1][1],arch_ends[1][1],'segmented_conduit',.045)
for degrees in (45,70,90,110,135):
 a=math.radians(degrees);x=.63*math.cos(a);z=1.37+.63*math.sin(a)
 mount=cylinder('V04 arch cable rear retainer '+str(degrees),(.555*math.cos(a),.545,1.37+.555*math.sin(a)),(x,.709,z),.014,'edge-trim',16);joint(mount,'Crown cog continuous rim','rear retainer pins into curved crown at actual torus tube radius')
# Pairs of restrained coloured cable bundles on both outer monitor flanks.
for sign,index in [(-1,1),(1,2)]:
 cx,cy,yaw,w=stations[index];M=Matrix.Translation((cx,cy,0))@Matrix.Rotation(yaw,4,'Z')
 for k,colour in enumerate(('signal-red','signal-amber','signal-black')):
  a=list(M@Vector((sign*.13,.247,1.00+k*.062)));end=[sign*.765,.49,.69+k*.064]
  plate=box('V04 cable receiving block '+str((sign,k)),(sign*.765,.49,end[2]),(.085,.10,.052),'cast-frame',bevel=.008);joint(plate,'Back shrine structural casting','receiving block mounted on backplane flank')
  points=[a,[sign*(.86+k*.021),.12,1.04+k*.047],[sign*(.875+k*.018),.34,.83+k*.058],end]
  service('outer-monitor-bundle-'+str((sign,k)),points,'Console %d | rear connector backplate'%index,plate.name,'wire_bundle',.027,colour)
  # Secured at the rear flank; the middle span remains a purposeful service loop.
  clamp=box('V04 bundle binding saddle '+str((sign,k)),(sign*(.875+k*.018),.34,.83+k*.058),(.06,.035,.035),'edge-trim',bevel=.005)
  bracket=box('V04 bundle binding bracket '+str((sign,k)),(sign*.82,.38,.83+k*.058),(.16,.10,.025),'cast-frame',bevel=.005);joint(bracket,'Back shrine structural casting','bundle bracket extends from backplane flank');joint(clamp,bracket,'binding saddle retained on bracket')
# A small insulated wire from each monitor's outside gland to its own desk control.
for index,(cx,cy,yaw,w) in enumerate(stations):
 M=Matrix.Translation((cx,cy,0))@Matrix.Rotation(yaw,4,'Z');sign=-1 if index==1 else 1
 a=list(M@Vector((sign*w*.48,-.085,.96)));b=list(M@Vector((sign*w*.43,-.245,.817)))
 seat=box('V04 desk jumper shoe '+str(index),(sign*w*.43,-.245,.806),(.055,.06,.025),'cast-frame',M,.005);joint(seat,'Console %d | sloped control deck'%index,'control jumper shoe seated beside keyboard, outside key travel')
 points=[a,list(M@Vector((sign*w*.53,-.15,.94))),list(M@Vector((sign*w*.52,-.235,.86))),b]
 service('monitor-control-jumper-'+str(index),points,'Console %d | deep monitor cabinet'%index,seat.name,'single_wire',.013,'signal-amber')
# Save lineage and preserve source-specific camera, consoles and supplied skulls.
for name in ['contract.json','capture-profile.json','orientation-and-skull-preservation.json','support-objects.json','original-prototype.lua','supplied-skull-reuse.json','ATTRIBUTION.txt','surface-manifest.json']:
 shutil.copy2(OLD/name,O/name)
assert signatures()==skulls_before,'Supplied skull geometry/UV/frame was changed'
(O/'contacts.json').write_text(json.dumps(contacts,indent=2)+'\n');(O/'pipette-requests.json').write_text(json.dumps(requests,indent=2)+'\n');(O/'pipette-plans.json').write_text(json.dumps(plans,indent=2)+'\n')
metadata=dict(previous_source_sha256=hashlib.sha256((OLD/'conclave-center-v03.blend').read_bytes()).hexdigest(),helper_sha256=hashlib.sha256(helper.read_bytes()).hexdigest(),stage='source/export review candidate; no runtime replacement',arch=dict(center=[0,.51,1.37],ring_radius=.54,candle_count=len(arc),holders=arc,rule='saddles follow the actual arch angles; upright candles sit on individual radial brackets at varying X/Y/Z, never on an equal-height flat row'),services=dict(existing_count=5,additional_routes=additional,total_routes=len(requests),native_external_interfaces_added=0,protective_hose_payload='empty sleeve, three insulated signal conductors modeled inside; not a gameplay fluid'),skulls_unchanged=skulls_before,console_orientation='V03 inward-facing complete station assemblies retained')
(O/'arch-and-services.json').write_text(json.dumps(metadata,indent=2)+'\n')
sys.path.insert(0,str(R/'tools/fmpl'));from blender_camera_guard import assert_clean;assert_clean(s,json.loads((O/'capture-profile.json').read_text()),bpy)
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='OPTIX'
if any(d.use for d in prefs.devices):s.cycles.device='GPU'
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(O/'conclave-center-v04.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for o in s.objects:
 if o.type=='MESH':o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'conclave-center-v04.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
s.render.filepath=str(O/'source-front.png');bpy.ops.render.render(write_still=True);print('CONCLAVE_ARCH_SERVICES_SAVED',len(arc),len(additional),len(contacts),flush=True)
