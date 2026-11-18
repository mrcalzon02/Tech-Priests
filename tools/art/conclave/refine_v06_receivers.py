"""Explicit receiving bulkheads, coaxial terminations and expanded service banks."""
import ast,bpy,bmesh,json,math,sys,hashlib,shutil,importlib.util,copy,re
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[3];OLD=R/'art/source-to-3d/conclave-center/v05-panels-and-buttresses';O=OLD.parent/'v06-receiving-bulkheads';O.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(OLD/'conclave-center-v05.blend'));s=bpy.context.scene;root=bpy.data.objects['Conclave Center | ground origin'];contacts=json.loads((OLD/'contacts.json').read_text());changes=[];cuts=[]
mats={k:bpy.data.materials.get('Conclave V03 | '+k) or bpy.data.materials.get('Conclave | '+k) for k in ['cast-frame','console-panels','edge-trim','control-keys','floor-tread','cable-jacket']}
for k in ('signal-red','signal-amber','signal-black'):mats[k]=bpy.data.materials['Conclave V04 | '+k]
helper=R/'tools/art/conclave/refine_v03.py';tree=ast.parse(helper.read_text());names={'uv','mesh','box','joint','cylinder','octrect','ring_xz'};exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[]),str(helper),'exec'))
src=(R/'tools/art/conclave/refine_v05_panels.py').read_text();tree=ast.parse(src);exec(compile(ast.get_source_segment(src,next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='cut')),str(R/'tools/art/conclave/refine_v05_panels.py'),'exec'))
def signature(prefix):return {o.name:hashlib.sha256(json.dumps(dict(v=[list(v.co) for v in o.data.vertices],m=[list(row) for row in o.matrix_world]),sort_keys=True).encode()).hexdigest() for o in s.objects if o.name.startswith(prefix)}
skulls=signature('Supplied DGordillo low-poly skull');candles=signature('Arch candle');stations=[(0,.18,0,.60),(-.62,-.17,math.pi/4,.49),(.62,-.17,-math.pi/4,.49)]
oldreq=json.loads((OLD/'pipette-requests.json').read_text());removed=[]
for ob in list(s.objects):
 if ob.get('pipette_route_id') or ob.name.startswith(('V04 cable receiving block','V04 sleeve sole termination','V05 pedestal loom gland','V05 pedestal loom foot','V05 pedestal loom retaining clip','V05 pedestal clip supported standoff','V04 arch cable rear retainer','Armored loom grounded saddle','Armored loom retained strap','Loom strap leg','V04 bundle binding saddle','V04 bundle binding bracket','V04 conduit column standoff')):
  removed.append(ob.name);bpy.data.objects.remove(ob,do_unlink=True)
contacts=[c for c in contacts if c['a'] not in removed and c['b'] not in removed]
for collection in list(bpy.data.collections):
 if collection.name.startswith('FMPL | PIPETTE | ') and not collection.all_objects:bpy.data.collections.remove(collection)
def grow(ob,minsize):
 lo=[min(v.co[j] for v in ob.data.vertices) for j in range(3)];hi=[max(v.co[j] for v in ob.data.vertices) for j in range(3)]
 for v in ob.data.vertices:
  for j,size in enumerate(minsize):
   if size and hi[j]-lo[j]<size:v.co[j]=(v.co[j]-(lo[j]+hi[j])/2)*size/(hi[j]-lo[j])+(lo[j]+hi[j])/2
 ob.data.update()
def boxport(host,point,axis,sign):return dict(host=host,nominal=list(point),axis=axis,sign=sign)
hosts={};Mats=[]
# Receiving carriers replace overlapping individual pads with proper gang banks.
for sign,index in [(-1,1),(1,2)]:
 cx,cy,yaw,w=stations[index];M=Matrix.Translation((cx,cy,0))@Matrix.Rotation(yaw,4,'Z');Mats.append(M)
 for vertex in bpy.data.objects['Lower rear signal junction '+str(sign)].data.vertices:vertex.co.x-=sign*.035
 grow(bpy.data.objects['Back casting structural flute '+str(sign*.69)],(0,.14,0))
 rail=box('V06 outer return terminal bank '+str(sign),(sign*.765,.49,.754),(.13,.12,.24),'cast-frame',bevel=.008);joint(rail,'Back shrine structural casting','three-way receiving bank welded onto backplane flank');hosts['returns',sign]=rail.name
 for kind,z,y in [('upper',.6225,-.17),('lower',.2675,.01)]:
  bank=box('V06 pedestal '+kind+' gang bank '+str(sign),(sign*.20,y,z),(.084,.10,.16),'cast-frame',M,.008);joint(bank,'Console %d | grounded pedestal'%index,'gang bank root embeds into solid pedestal cheek');hosts[kind,sign]=bank.name
 # One chamfered sole bay carries the original large sleeve and two new hoses.
 poly=octrect(.22,.30,.045);verts=[(sign*.68+x,-.63+y,z) for z in (.13,.23) for x,y in poly];faces=[tuple(range(7,-1,-1)),tuple(8+j for j in range(8))]+[(j,(j+1)%8,8+(j+1)%8,8+j) for j in range(8)]
 bay=mesh('V06 sole service bank '+str(sign),verts,faces,'cast-frame',bevel=.006);joint(bay,'Octagonal sole casting','chamfered receiving bay fully seated on equipment sole');hosts['sole',sign]=bay.name
 # Lower sockets sit directly below their upper mates, with matching outward
 # axes. This permits one broad planar hanging bend, not a three-axis hook.
 lower=box('V06 lower flank hose bank '+str(sign),(sign*.21,-.01,.38),(.11,.26,.13),'cast-frame',M,.008);joint(lower,'Console %d | grounded pedestal'%index,'lower hose bank retained on pedestal cheek');hosts['lower-hoses',sign]=lower.name
 lowerbig=box('V06 lower large sleeve bank '+str(sign),(sign*.196,-.15,.18),(.060,.15,.14),'cast-frame',M,.006);joint(lowerbig,'Console %d | grounded pedestal'%index,'large sleeve lower receiving bank carried by pedestal and sole');hosts['lower-big',sign]=lowerbig.name
 foot=box('V06 lower sleeve mounting shoe '+str(sign),(sign*.196,-.15,.137),(.15,.19,.035),'edge-trim',M,.006);joint(foot,lowerbig,'lower sleeve bank fixed in retained shoe');joint(foot,'Octagonal sole casting','sleeve shoe seated on equipment sole')
 upper=box('V06 upper flank hose bank '+str(sign),(sign*.21,-.01,.57),(.11,.26,.24),'cast-frame',M,.008);joint(upper,'Console %d | grounded pedestal'%index,'hose receiving bank root embeds into outer pedestal cheek');hosts['hoses',sign]=upper.name
 header=box('V06 monitor header receiving plate '+str(sign),(0,.252,1.255),(.20,.07,.12),'cast-frame',M,.006);joint(header,'Console %d | deep monitor cabinet'%index,'header receiving plate bridges rear upper casting and grille frame');hosts['header',sign]=header.name
 post=box('V06 shrine front service bank '+str(sign),(sign*.68,.36,1.12),(.12,.10,.54),'cast-frame',bevel=.008);joint(post,'V05 front shrine structural rib '+str(sign),'front service bank seated continuously on structural rib');hosts['front',sign]=post.name
 grow(bpy.data.objects['V04 arch raceway terminal '+str(sign)],(.18,.15,.18))
 theta=math.radians(135 if sign<0 else 45);direction=Vector((math.sin(theta) if sign<0 else -math.sin(theta),0,-math.cos(theta) if sign<0 else math.cos(theta)));mouth=Vector((.68*math.cos(theta),.705,1.37+.68*math.sin(theta)));carrier=mouth-direction*(.047+.045);frame=Matrix.Translation(carrier)@direction.to_track_quat('Z','Y').to_matrix().to_4x4();angled=box('V06 tangential arch socket carrier '+str(sign),(0,0,0),(.12,.12,.09),'cast-frame',frame,.006);joint(angled,'V04 arch raceway terminal '+str(sign),'tangential socket carrier root seats into arch junction');hosts['arc',sign]=angled.name
 grow(bpy.data.objects['V04 sleeve console seat '+str(sign)],(0,.15,.15))
 for vertex in bpy.data.objects['V04 sleeve console seat '+str(sign)].data.vertices:vertex.co.y-=.105
 for name in ['Console %d | rear centre gland rail'%index,'Console %d | rear multipin gland strip'%index]:
  grow(bpy.data.objects[name],(.085 if 'multipin' in name else 0,0,.10 if 'centre' in name else 0))
# The central monitor receives a lower rail that opens into the actual rear bay,
# rather than a cable drawn through its solid upper casting.
low=box('V06 central monitor lower gland rail',(0,.426,.97),(.39,.035,.10),'edge-trim',bevel=.005);joint(low,'Console 0 | rear connector backplate','low receiving rail bridges actual grille side frame')
grow(bpy.data.objects['Console 0 | rear centre gland rail'],(0,0,.10))
for i,(cx,cy,yaw,w) in enumerate(stations):
 M=Matrix.Translation((cx,cy,0))@Matrix.Rotation(yaw,4,'Z');sign=-1 if i==1 else 1;y=-.065;plane=sign*(w*.5-w*.06*(y+.113)/.337);theta=sign*math.atan(w*.06/.337);normal=Vector((sign*math.cos(theta),sign*math.sin(theta),0));p=Vector((plane,y,.965))+normal*.012
 frame=M@Matrix.Translation(p)@Matrix.Rotation(theta,4,'Z');boss=box('V06 monitor side socket carrier '+str(i),(0,0,0),(.045,.085,.09),'cast-frame',frame,.005);joint(boss,'Console %d | deep monitor cabinet'%i,'angled carrier root embeds in actual tapered monitor side wall');hosts['monitor',i]=boss.name
 for vertex in bpy.data.objects['V04 desk jumper shoe '+str(i)].data.vertices:vertex.co.y-=.045
def decode_sign(text):return -1 if ('--1' in text or '(-1,' in text or text.endswith('-1') and not text.endswith('--1') and False) else 1
definitions=[]
for original in oldreq:
 req=copy.deepcopy(original);rid=req['id'];pts=req['path']['points'];ports={};sgn=-1 if ('--1' in rid or '(-1,' in rid) else 1
 if rid.startswith('conclave-v03-console-service-'):
  i=int(rid.rsplit('-',1)[1]);p=pts[0]
  if i==0:
   ports['start']=boxport(low.name,[0,.426,.97],1,1);ports['end']=boxport('V05 rear bay recessed shield',[0,.581,.97],1,-1);req['path']['points']=[[0,.426,.97],[0,.581,.97]]
  else:
   sign=-1 if i==1 else 1;ports['start']=boxport('Console %d | rear centre gland rail'%i,p,1,1);ports['end']=boxport('Back casting structural flute '+str(sign*.69),[sign*.7475,.672,1.0],0,sign)
 elif 'conclave-v03-armored-return-' in rid:
  ports['start']=boxport('Lower rear signal junction '+str(sgn),pts[0],0,sgn);ports['end']=boxport('Console lower gland seat '+str(sgn),pts[-1],0,sgn)
 elif 'corrugated-protective-sleeve-' in rid or 'sleeve-signal-core-' in rid:
  i=1 if sgn<0 else 2;cx,cy,yaw,w=stations[i];M=Matrix.Translation((cx,cy,0))@Matrix.Rotation(yaw,4,'Z');ports['start']=boxport('V04 sleeve console seat '+str(sgn),M@Vector((sgn*.196,-.15,.49)),0,sgn);ports['end']=boxport(hosts['lower-big',sgn],M@Vector((sgn*.196,-.15,.18)),0,sgn)
 elif 'arch-service-rise-' in rid:
  ports['start']=boxport('Lower rear signal junction '+str(sgn),pts[0],1,1);ports['end']=boxport('V04 arch raceway terminal '+str(sgn),pts[-1],2,-1)
 elif 'curved-arch-raceway' in rid:
  ports['start']=boxport(hosts['arc',-1],bpy.data.objects[hosts['arc',-1]].matrix_world@Vector((0,0,.045)),2,1);ports['end']=boxport(hosts['arc',1],bpy.data.objects[hosts['arc',1]].matrix_world@Vector((0,0,.045)),2,1)
 elif 'outer-monitor-bundle-' in rid:
  i=1 if sgn<0 else 2;ports['start']=boxport('Console %d | rear multipin gland strip'%i,pts[0],1,1);ports['end']=boxport(hosts['returns',sgn],pts[-1],1,-1)
 elif 'monitor-control-jumper-' in rid:
  i=int(rid.rsplit('-',1)[1]);sign=-1 if i==1 else 1;cx,cy,yaw,w=stations[i];M=Matrix.Translation((cx,cy,0))@Matrix.Rotation(yaw,4,'Z');ports['start']=boxport(hosts['monitor',i],pts[0],0,sign);ports['end']=boxport('V04 desk jumper shoe '+str(i),M@Vector((sign*w*.43,-.29,.8185)),2,1)
 elif 'pedestal-panel-return-' in rid:
  k=int(re.search(r', (\d)\)',rid).group(1));i=1 if sgn<0 else 2;cx,cy,yaw,w=stations[i];M=Matrix.Translation((cx,cy,0))@Matrix.Rotation(yaw,4,'Z');ports['start']=boxport(hosts['upper',sgn],M@Vector((sgn*.21,-.22,.595+k*.055)),1,-1);ports['end']=boxport(hosts['lower',sgn],M@Vector((sgn*.21,-.04,.235+k*.065)),1,-1)
 else:raise RuntimeError('Unreviewed legacy endpoint '+rid)
 definitions.append(dict(request=req,ports=ports,legacy=True))
def addroute(name,points,ports,family,diameter,colour='cable-jacket',payload='signal',corrugated=False):
 request=dict(id='conclave-v06-'+name,family=family,payload=payload,size=dict(outer_diameter=diameter,wall_fraction=.20 if family in ('flex_hose','segmented_conduit') else 0),material_id=mats[colour].name,path=dict(kind='waypoints',points=[list(p) for p in points]),fittings=dict(start='compression' if payload=='empty' else 'cable_gland',end='compression' if payload=='empty' else 'cable_gland'),supports=dict(named_receiving_bulkheads=True),behavior=dict(internal_visual_service_only=True,live_binding_implemented=False,no_external_native_interface=True),keep_outs=[])
 if family=='segmented_conduit':request['joint_pitch']=.065
 if family=='wire_bundle':request['size'].update(conductor_count=3,strand_diameter=.0055);request['expose_cores']=False
 if corrugated:request['surface_profile']=dict(corrugation_pitch=.017,corrugation_depth_ratio=.11)
 definitions.append(dict(request=request,ports=ports,legacy=False))
for sign,i in [(-1,1),(1,2)]:
 cx,cy,yaw,w=stations[i];M=Matrix.Translation((cx,cy,0))@Matrix.Rotation(yaw,4,'Z')
 for k,yy in enumerate((-.07,.05)):
  a=M@Vector((sign*.265,yy,.62));b=M@Vector((sign*.265,yy,.38));ports=dict(start=boxport(hosts['hoses',sign],a,0,sign),end=boxport(hosts['lower-hoses',sign],b,0,sign));points=[list(a),list(b)]
  addroute('flank-protective-hose-'+str((sign,k)),points,ports,'flex_hose',.045,payload='empty',corrugated=True);addroute('flank-hose-wire-core-'+str((sign,k)),points,ports,'wire_bundle',.024,'signal-red' if k==0 else 'signal-amber')
 for k in (0,1):
  a=M@Vector((-.0525 if k==0 else .0525,.287,1.255));host=hosts['front',sign] if k==0 else 'V05 upper rear inspection panel '+str(sign);b=[sign*.74,.36,1.31] if k==0 else [sign*.48,.701,1.315];ports=dict(start=boxport(hosts['header',sign],a,1,1),end=boxport(host,b,0 if k==0 else 1,sign if k==0 else 1))
  points=[list(a),[sign*.91,.18,1.43],[sign*.83,.27,1.47],b] if k==0 else [list(a),[sign*.89,.40,1.46],[sign*.66,.79,1.43],b]
  addroute('upper-service-conduit-'+str((sign,k)),points,ports,'segmented_conduit',.034);addroute('upper-service-wire-core-'+str((sign,k)),points,ports,'wire_bundle',.022,'signal-amber')
# Receiving banks abandoned during the bend redesign are removed in memory.
used_hosts={port['host'] for definition in definitions for port in definition['ports'].values()}
for sign in (-1,1):
 name=hosts['sole',sign]
 if name not in used_hosts:bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)
# Group coaxial hose/core endpoints: one physical receiving socket per landing.
groups={}
for definition in definitions:
 req=definition['request'];D=req['size']['outer_diameter']
 for terminal,port in definition['ports'].items():
  key=(port['host'],port['axis'],port['sign'],*(round(v,4) for v in port['nominal']))
  group=groups.setdefault(key,dict(port=port,diameter=D,members=[]));group['diameter']=max(group['diameter'],D);group['members'].append((definition,terminal));definition['ports'][terminal]['group_key']=key
def face(group):
 port=group['port'];ob=bpy.data.objects[port['host']];axis,sign=port['axis'],port['sign'];D=group['diameter'];ri=.66*D+.002;ro=ri+.006;rf=max(.020,ro*1.16)
 # Enlarge thin receiving carriers in their face plane before drilling.
 if ob.name.startswith(('V04 sleeve console seat','Console lower gland seat','Lower rear signal junction','Console ')) and 'deep monitor' not in ob.name:
  minimum=[0,0,0]
  for j in range(3):
   if j!=axis:minimum[j]=2*(rf+.012)
  grow(ob,minimum)
 lo=[min(v.co[j] for v in ob.data.vertices) for j in range(3)];hi=[max(v.co[j] for v in ob.data.vertices) for j in range(3)];p=ob.matrix_world.inverted()@Vector(port['nominal']);p[axis]=hi[axis] if sign>0 else lo[axis]
 for j in range(3):
  if j!=axis:p[j]=max(lo[j]+rf+.006,min(hi[j]-rf-.006,p[j]))
 unit=Vector((0,0,0));unit[axis]=sign;n=(ob.matrix_world.to_3x3().inverted().transposed()@unit).normalized();q=ob.matrix_world@p
 group.update(q=q,n=n,ri=ri,ro=ro,rf=rf,extension=max(.031,D*.60+.020),host=ob.name)
for group in groups.values():face(group)
# A shared carrier can have orthogonal ports; project only after every required
# face expansion has been applied, so another port cannot move an earlier seat.
for group in groups.values():face(group)
def annular(name,q,n,z0,z1,outer,inner,material='edge-trim',sides=32):
 n=Vector(n).normalized();u=n.orthogonal().normalized();v=n.cross(u).normalized();verts=[tuple(Vector(q)+n*z+(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides))*r) for r,z in [(outer,z0),(outer,z1),(inner,z1),(inner,z0)] for i in range(sides)];faces=[]
 for k in range(4):
  for i in range(sides):j=(i+1)%sides;faces.append((k*sides+i,k*sides+j,((k+1)%4)*sides+j,((k+1)%4)*sides+i))
 return mesh(name,verts,faces,material,bevel=0)
socket_records=[];drills={}
for index,group in enumerate(groups.values()):
 q,n,D,ri,ro,rf,E=group['q'],group['n'],group['diameter'],group['ri'],group['ro'],group['rf'],group['extension'];tag='V06 receiving socket %02d'%index;u=n.orthogonal().normalized();v=n.cross(u).normalized()
 flange=annular(tag+' | bolted mounting flange',q,n,0,.010,rf,ri);joint(flange,group['host'],'receiving flange back plane is flush with actual selected carrier face')
 neck=annular(tag+' | hollow receiving neck',q,n,-.006,E-D*.32,ro,ri);joint(neck,flange,'hollow receiving neck is coaxial with mounting flange')
 nose_inner=.58*D+.0005;nose_outer=.66*D+.0005
 nose=annular(tag+' | inserted male nose',q,n,E-D*.72,E+D*.04,nose_outer,nose_inner,'control-keys');nut=annular(tag+' | retained coupling nut',q,n,E-D*.06,E+D*.18,D*.84,nose_inner,'edge-trim',6);joint(nut,nose,'hex coupling retains male nose after measurable axial insertion')
 seal=annular(tag+' | insulating compression seal',q,n,E+D*.04,E+D*.18,nose_inner+.0005,D*.495,'cable-jacket');joint(seal,nut,'compression seal is retained inside coupling nut around the carried jacket')
 for j in range(4):
  a=math.pi/4+j*math.pi/2;p=q+(u*math.cos(a)+v*math.sin(a))*rf*.72;stud=cylinder(tag+' | captive flange stud '+str(j),p-n*.012,p+n*.018,max(.0038,D*.08),'control-keys',6);joint(stud,flange,'four flange studs seat diagonally through actual carrier face')
 # Body drill is real geometry, not a black disc placed over a solid face.
 host=bpy.data.objects[group['host']];thickness=max((host.matrix_world@vv.co-q).dot(-n) for vv in host.data.vertices);depth=min(.12,thickness*.5+.006);drill=cylinder('temporary socket bore',q-n*depth,q+n*.03,ri,'cast-frame',32);drills.setdefault(group['host'],[]).append(drill)
 group.update(index=index,flange=flange.name,neck=neck.name,nose=nose.name)
 socket_records.append(dict(index=index,host=group['host'],q=list(q),normal=list(n),diameter=D,receiving_inner_radius=ri,male_outer_radius=nose_outer,radial_clearance=ri-nose_outer,extension=E,receiver_neck_end=E-D*.32,male_nose_start=E-D*.72,insertion_overlap=D*.40,flange=flange.name,neck=neck.name,nose=nose.name,flange_radius=rf,members=[dict(route=d['request']['id'],terminal=t) for d,t in group['members']]))
for host,tools in drills.items():cut(bpy.data.objects[host],tools,'Real receiving bulkhead bores')
spec=importlib.util.spec_from_file_location('conclave_v06_pipette',R/'tools/fmpl/pipette/blender_adapter.py');adapter=importlib.util.module_from_spec(spec);sys.modules[spec.name]=adapter;spec.loader.exec_module(adapter)
def smooth(points):
 p=[Vector(a) for a in points];out=[]
 for i in range(len(p)-1):
  a,b,c,d=p[max(0,i-1)],p[i],p[i+1],p[min(len(p)-1,i+2)]
  for j in range(5):t=j/5;out.append(list(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)))
 out.append(list(p[-1]));return out
sys.path.insert(0,str(Path(__file__).resolve().parent));from v06_route_geometry import plan_centerline
requests=[];plans=[];endpoint_records=[];bend_records=[];route_objects=[]
for definition in definitions:
 req=definition['request'];D=req['size']['outer_diameter'];a,b=[groups[definition['ports'][t]['group_key']] for t in ('start','end')];p=a['q']+a['n']*a['extension'];q=b['q']+b['n']*b['extension'];points,bendrecord=plan_centerline(req,p,a['n'],q,b['n'],max(a['diameter'],b['diameter']),stations);bend_records.append(bendrecord)
 req['path']=dict(kind='waypoints',points=points)
 for terminal,group,position in [('start',a,p),('end',b,q)]:
  req[terminal+'_socket']=dict(id=req['id']+'.'+terminal,xyz=list(position),normal=list(group['n']),role='source' if terminal=='start' else 'sink',payloads=[req['payload']],parent_mesh=group['neck']);endpoint_records.append(dict(route=req['id'],terminal=terminal,socket=group['index'],point=list(position),outward_axis=list(group['n']),legacy_repaired=definition['legacy']))
 plan=adapter.core.plan(req);material=bpy.data.materials.get(req['material_id']) or mats['cable-jacket'];col,objects=adapter.build(plan,material,mats['edge-trim'])
 kept_names=[]
 for obj in list(objects):
  # Replace prototype terminal barrels with the actual mating nose/receptacle.
  if obj.get('pipette_geometry_role') in ('terminal-sleeve','terminal-band','terminal-stop'):
   bpy.data.objects.remove(obj,do_unlink=True);continue
  obj.parent=root;uv(obj)
  route_objects.append(obj)
  kept_names.append(obj.name)
 for endpoint in endpoint_records[-2:]:endpoint['body_parts']=list(kept_names);endpoint['route_diameter']=D
 for terminal,group,position in [('start',a,p),('end',b,q)]:
  n=group['n'];start=group['q']-n*.025;end=position+n*.015
  if req['size'].get('wall_fraction',0)>0:extension=annular('V06 '+req['id']+' '+terminal+' carried sleeve',start,n,0,(end-start).length,D*.5,D*.5*(1-req['size']['wall_fraction']),'cable-jacket',24)
  else:extension=cylinder('V06 '+req['id']+' '+terminal+' carried conductors',start,end,D*.5,'signal-red' if 'red' in req['material_id'] else 'cable-jacket',24)
  joint(extension,group['nose'],'actual cable/sleeve continues through coaxial male nose into receiving bore')
 requests.append(req);plans.append(plan)
# Seat the arch retainers on measured points of the actual new raceway.
arc=next(req for req in requests if 'curved-arch-raceway' in req['id']);pts=arc['path']['points']
for i,fraction in enumerate((.2,.35,.5,.65,.8)):
 end=Vector(pts[round((len(pts)-1)*fraction)]);a=math.atan2(end.z-1.37,end.x);start=(.555*math.cos(a),.545,1.37+.555*math.sin(a));mount=cylinder('V06 retained arch raceway support '+str(i),start,end,.014,'edge-trim',16);joint(mount,'Crown cog continuous rim','arch raceway support foot embeds in torus and tip seats on actual route')
# Intermediate saddles are placed on the rebuilt conduit, not inherited points.
major=[obj for obj in s.objects if obj.type=='MESH' and (obj.name in ('Back shrine structural casting','Octagonal sole casting') or obj.name.startswith('Console ') and any(word in obj.name for word in ('grounded pedestal','deep monitor cabinet','sloped control deck')))]
trees={obj.name:BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[list(f.vertices) for f in obj.data.polygons]) for obj in major}
support_records=[]
for req in requests:
 if req['family']!='segmented_conduit' or 'curved-arch-raceway' in req['id']:continue
 path=[Vector(p) for p in req['path']['points']];D=req['size']['outer_diameter']
 for fraction in (.35,.65):
  j=max(1,min(len(path)-2,round((len(path)-1)*fraction)));p=path[j];t=(path[j+1]-path[j-1]).normalized();options=[]
  for name,tree in trees.items():
   q,n,face,d=tree.find_nearest(p)
   if q is not None and (p-q).dot(n)>=0 and .025<d<.24:options.append((d,name,q,n))
  if not options:continue
  d,name,q,n=min(options,key=lambda item:item[0]);radial=(p-q)-t*(p-q).dot(t)
  if radial.length<.006:continue
  radial.normalize();tag='V06 supported conduit saddle '+str(len(support_records));outer=D*.55+.005;foot=cylinder(tag+' foot',q-n*.002,q+n*.012,.022,'cast-frame',16);joint(foot,name,'saddle foot seats on actual nearest casting surface')
  post=cylinder(tag+' post',q+n*.01,p-radial*(outer-.0015),.006,'control-keys',12);joint(post,foot,'saddle post retained on mounted foot')
  band=annular(tag+' band',p,t,-.009,.009,outer,D*.55,'edge-trim',24);joint(band,post,'post terminates at outer saddle wall, outside conduit bore')
  liner=annular(tag+' compliant liner',p,t,-.009,.009,D*.55+.0002,D*.499,'cable-jacket',24);joint(liner,band,'compliant liner held inside actual saddle around conduit jacket')
  support_records.append(dict(route=req['id'],point=list(p),tangent=list(t),host=name,foot_point=list(q),distance=d,band=band.name))
for name in ['contract.json','capture-profile.json','orientation-and-skull-preservation.json','support-objects.json','original-prototype.lua','supplied-skull-reuse.json','ATTRIBUTION.txt','surface-manifest.json','arch-and-services.json','panel-refinement.json','panel-surfaces.json']:
 shutil.copy2(OLD/name,O/name)
arch=json.loads((O/'arch-and-services.json').read_text());arch['stage']='V06 retained arch module; receiving-interfaces.json and bend-radius-review.json are the current service authority';arch['services']['total_routes']=len(requests);(O/'arch-and-services.json').write_text(json.dumps(arch,indent=2)+'\n')
assert signature('Supplied DGordillo low-poly skull')==skulls;assert signature('Arch candle')==candles
contacts=[c for c in contacts if bpy.data.objects.get(c['a']) and bpy.data.objects.get(c['b'])]
(O/'contacts.json').write_text(json.dumps(contacts,indent=2)+'\n');(O/'pipette-requests.json').write_text(json.dumps(requests,indent=2)+'\n');(O/'pipette-plans.json').write_text(json.dumps(plans,indent=2)+'\n')
data=dict(stage='receiving-interface and density review candidate; not integrated',previous_source_sha256=hashlib.sha256((OLD/'conclave-center-v05.blend').read_bytes()).hexdigest(),legacy_routes_reviewed=25,total_routes=len(requests),added_routes=len(requests)-25,physical_receivers=len(socket_records),receivers=socket_records,endpoints=endpoint_records,real_host_bore_operations=cuts,skulls_unchanged=skulls,candles_unchanged=candles,receiving_rule='actual selected flat receiving face, hollow bolted flange/neck, radial clearance, overlapping coaxial male nose, straight cable lead and body bore; shared hose/core landings use one socket')
data['actual_intermediate_conduit_saddles']=support_records
(O/'receiving-interfaces.json').write_text(json.dumps(data,indent=2)+'\n')
(O/'bend-radius-review.json').write_text(json.dumps(dict(passed=all(r['passed'] for r in bend_records),routes=bend_records,method='Analytic hanging semicircles for protective hose groups; straight socket leads and bounded curvature cubic routes for wires/conduits. No inherited Catmull control points.'),indent=2)+'\n')
sys.path.insert(0,str(R/'tools/fmpl'));from blender_camera_guard import assert_clean;assert_clean(s,json.loads((O/'capture-profile.json').read_text()),bpy)
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='OPTIX'
if any(d.use for d in prefs.devices):s.cycles.device='GPU'
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(O/'conclave-center-v06.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in s.objects:
 if obj.type=='MESH':obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'conclave-center-v06.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
s.render.filepath=str(O/'source-front.png');bpy.ops.render.render(write_still=True);print('CONCLAVE_EXPLICIT_RECEIVERS_SAVED',len(requests),len(socket_records),len(contacts),flush=True)
