"""Enclosed Orbital Trader cargo exchange and sorting altar."""
import bpy,bmesh,json,math,hashlib,sys,tempfile
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent
def locate_repo():
 for parent in (O,*O.parents):
  for candidate in (parent,parent/'model-production'):
   if (candidate/'tools/fmpl/FMPL.json').is_file():return candidate
 raise FileNotFoundError('Canonical FMPL source checkout required')
REPO=locate_repo();sys.path.insert(0,str(O));sys.path.insert(0,str(REPO/'art/source-to-3d/shared-parts/industrial-asset-library'));sys.path.insert(0,str(REPO/'tools/fmpl'))
from mesh_util import box,cylinder,tube,mesh
from fmpl_uv import cylinder_uv,sweep_uv,panel_uv
from import_materials import import_materials
from blender_camera_guard import install_canonical_camera,assert_clean,temporary_inspection_camera
(O/'export-temp').mkdir(exist_ok=True);tempfile.tempdir=str(O/'export-temp')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene
col=bpy.data.collections.new('ORBITAL | enclosed manufacturing cathedral');s.collection.children.link(col);root=bpy.data.objects.new('EXPORT | Orbital Trader',None);col.objects.link(root)
ids=['ferrocrete_dark','gunmetal_dark','machine_steel','brass','martian_red','glass','insulator','machined_bright','indicator_green','dark_recess','iron']
catalog=json.loads((REPO/'art/source-to-3d/shared-parts/industrial-asset-library/catalog.json').read_text());provenance={}
for rec in catalog['materials']:
 if rec['material_id']not in ids:continue
 maps={}
 for kind,entry in rec['maps'].items():
  p=REPO/entry['source_path'];data=p.read_bytes();blob=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest();assert blob==entry['git_blob_sha']
  maps[kind]={'source_path':entry['source_path'],'git_blob_sha':blob,'sha256':sha(p),'color_space':'sRGB'if kind=='albedo'else'Non-Color'}
 provenance[rec['material_id']]={'family':rec['family'],'source_commit':catalog['source_commit'],'maps':maps}
base=import_materials(REPO,ids,pack=True);mats={};roles=[]
for mid in ids:
 m=base[mid].copy();m.name='ORBITAL FMPL | '+mid;m['orbital_surface_role']=mid;m['fmpl_model_specific_placement']='Enclosed orbital exchange altar: dressed base, retained armored chambers, blind green cargo-rite hatch, supported exterior thermal services and communications dish; physical UV1.25/tile.';mats[mid]=m
 roles.append({'role':mid,'fmpl_material_id':mid,'model_specific_instance':m.name,'original_maps':provenance[mid]['maps'],'texture_repeat_per_tile':1.25})
iron=mats['gunmetal_dark'];steel=mats['machine_steel'];bronze=mats['brass'];red=mats['martian_red'];glass=mats['glass'];dark=mats['dark_recess']
def B(n,p,d,m=iron,parent=root,bevel=.02):return box('ORBITAL | '+n,p,d,m,col,parent,bevel)
def C(n,p,r,d,m=bronze,axis='Z',parent=root,seg=48):return cylinder('ORBITAL | '+n,p,r,d,m,col,parent,axis,seg)
def E(n,p=(0,0,0),parent=root):
 o=bpy.data.objects.new('ORBITAL | '+n,None);col.objects.link(o);o.parent=parent;o.location=p;return o
def bolt(n,p,axis='Z',r=.035,parent=root):return C(n,p,r,.035,bronze,axis,parent,6)
def beam(n,a,b,w=.08,d=.08,m=steel,parent=root):
 a,b=Vector(a),Vector(b);o=B(n,(a+b)/2,(w,d,(b-a).length),m,parent);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def route(n,points,r,m=bronze,bore=0,parent=root,seg=24):
 pts=list(map(Vector,points));ts=[(pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]).normalized()for i in range(len(pts))]
 if bore:return tube('ORBITAL | '+n,[(p,t,r,bore)for p,t in zip(pts,ts)],m,col,parent,seg)
 vv=[]
 for p,t in zip(pts,ts):
  trial=Vector((1,0,0))if abs(t.x)<.9 else Vector((0,1,0));a=(trial-t*trial.dot(t)).normalized();b=t.cross(a)
  vv.extend(tuple(p+r*(math.cos(j*math.tau/seg)*a+math.sin(j*math.tau/seg)*b))for j in range(seg))
 ff=[(i*seg+j,i*seg+(j+1)%seg,(i+1)*seg+(j+1)%seg,(i+1)*seg+j)for i in range(len(pts)-1)for j in range(seg)];ff.extend([tuple(reversed(range(seg))),tuple((len(pts)-1)*seg+j for j in range(seg))]);return mesh('ORBITAL | '+n,vv,ff,m,col,parent)
from mesh_util import lathe
stone=mats['ferrocrete_dark'];ceramic=mats['insulator'];green=mats['indicator_green']
def ring(n,xy,z,r,bore,d,m=bronze,parent=root):
 return tube('ORBITAL | '+n,[((xy[0],xy[1],z-d/2),(0,0,1),r,bore),((xy[0],xy[1],z+d/2),(0,0,1),r,bore)],m,col,parent,64)
def stud(n,p,normal=(0,0,1),r=.033):
 p=Vector(p);v=Vector(normal).normalized();head=C(n+' seated head',p+v*.015,r,.03,bronze,seg=6);head.rotation_euler=v.to_track_quat('Z','Y').to_euler();stem=C(n+' retained stem',p-v*.015,r*.52,.06,steel,seg=12);stem.rotation_euler=head.rotation_euler;return head
def radial(n,xy,a,r,z,d,m=steel):
 o=B(n,(xy[0]+r*math.cos(a),xy[1]+r*math.sin(a),z),d,m);o.rotation_euler.z=a;return o
B('founded dressed slab',(0,0,.11),(5.86,5.86,.22),stone,bevel=.07)
for x in range(6):
 for y in range(6):B('fitted masonry course',(-2.44+x*.976,-2.44+y*.976,.285),(.961,.961,.13),stone,bevel=.015)
B('continuous retained armored deck',(0,0,.385),(5.72,5.72,.07),iron,bevel=.025)
for side in(-1,1):
 for j in range(12):
  for x,y in((side*2.80,-2.55+j*.465),(-2.55+j*.465,side*2.80)):
   B('founded perimeter tie',(x,y,.435),(.14,.14,.03),steel,bevel=.009);stud('perimeter anchor',(x,y,.45),r=.027)
# A closed transfer bridge connects two sealed founded process volumes.
B('closed common cargo transfer bridge',(.10,.25,.86),(2.15,2.,.88),iron,bevel=.08)
front=(-.65,-1.0)
C('founded circular cargo-rite chamber',(front[0],front[1],.885),1.25,.93,iron,seg=96)
for z in(.49,1.25):ring('cargo chamber continuous load band',front,z,1.29,1.235,.12,bronze)
C('sealed heavy cargo-rite lid',(front[0],front[1],1.42),1.30,.22,steel,seg=96)
C('opaque green closed rite pane',(front[0],front[1],1.552),1.025,.034,glass,seg=96)
ring('cargo lid retained annular frame',front,1.58,1.30,1.0,.09,bronze)
for k in range(24):
 a=k*math.tau/24
 stud('cargo lid perimeter stud',(front[0]+1.16*math.cos(a),front[1]+1.16*math.sin(a),1.625),r=.029)
 radial('lid seated radial cast relief',front,a,1.15,1.635,(.24,.025,.022),steel)
 if k%2==0:
  a0=Vector((front[0]+.13*math.cos(a),front[1]+.13*math.sin(a),1.579));a1=Vector((front[0]+1.035*math.cos(a),front[1]+1.035*math.sin(a),1.579));beam('closed pane radial retained lattice',a0,a1,.025,.028,iron)
C('pane central retained seal',(front[0],front[1],1.596),.16,.052,bronze,seg=32)
C('sealed green central witness',(front[0],front[1],1.631),.092,.018,green,seg=32)
for k in range(16):
 a=k*math.tau/16
 radial('cargo chamber founded exterior rib',front,a,1.25,.87,(.10,.08,.88),steel)
 radial('closed cargo chamber service tablet',front,a,1.255,.88,(.10,.35,.44),ceramic)
 for z in(.58,1.18):
  stud('chamber rib anchor',(front[0]+1.308*math.cos(a),front[1]+1.308*math.sin(a),z),(math.cos(a),math.sin(a),0),.026)
# Rear storage/exchange dome: opaque enamel, continuous supporting collar and meridional ribs.
rear=(.8,1.30)
C('rear closed chamber founded drum',(rear[0],rear[1],.86),1.20,.88,iron,seg=96)
ring('rear founded cast drum shoe',rear,.51,1.26,1.18,.16,steel)
profile=[(0,1.23),(1.20,1.23)]+[(1.20*math.cos(i*math.pi/64),1.30+1.15*math.sin(i*math.pi/64))for i in range(33)]
lathe('ORBITAL | closed rear vaulted enamel roof',profile,rear,ceramic,col,root,96)
ring('rear dome retained load rim',rear,1.31,1.255,1.19,.11,bronze)
for k in range(16):
 a=k*math.tau/16
 pts=[(rear[0]+1.215*math.cos(t)*math.cos(a),rear[1]+1.215*math.cos(t)*math.sin(a),1.32+1.155*math.sin(t))for t in(i*math.pi/64 for i in range(33))]
 route('rear roof seated meridional rib',pts,.027,steel,seg=12)
 for t in(.20,.60,1.0):
  p=(rear[0]+1.217*math.cos(t)*math.cos(a),rear[1]+1.217*math.cos(t)*math.sin(a),1.32+1.155*math.sin(t));normal=(math.cos(t)*math.cos(a),math.cos(t)*math.sin(a),math.sin(t));stud('dome rib retention',p,normal,.021)
 radial('rear drum retained service cover',rear,a,1.205,.88,(.07,.30,.48),ceramic)
 for j in range(5):radial('cover embossed conductive trace',rear,a,1.245,.71+j*.075,(.018,.21,.018),bronze)
C('rear crown retained cap',(rear[0],rear[1],2.465),.18,.055,steel,seg=32)
# Founded left service tower, with closed green blind panes and ventilated opaque backing.
B('left service tower founded shoe',(-2.10,1.05,.54),(1.23,2.10,.24),steel,bevel=.05)
B('left closed exchange service tower',(-2.10,1.05,1.45),(1.08,1.97,1.60),iron,bevel=.07)
for x in(-2.59,-1.61):
 for y in(.14,1.96):B('tower continuous structural upright',(x,y,1.44),(.11,.11,1.68),steel)
B('tower sealed upper cover',(-2.10,1.05,2.30),(1.21,2.09,.13),ceramic,bevel=.025)
for y in(.40,1.05,1.70):
 B('tower opaque blind green window',(-2.662,y,1.53),(.025,.43,.87),glass)
 for yy in(y-.24,y+.24):B('tower retained window jamb',(-2.681,yy,1.53),(.035,.035,.95),bronze,bevel=.006)
 for z in(1.10,1.96):B('tower retained glazing sill',(-2.681,y,z),(.035,.51,.045),bronze,bevel=.006)
 for z in(1.32,1.60,1.84):B('tower seated blind crossbar',(-2.681,y,z),(.035,.46,.020),steel,bevel=.004)
for x in(-2.35,-1.85):
 for j in range(8):B('tower front closed thermal fin',(x,.037,.90+j*.12),(.35,.08,.025),steel,bevel=.005)
# Four fully supported ceramic thermal service stacks on the closed tower roof.
for x in(-2.36,-1.84):
 for y in(.52,1.60):
  C('tower thermal stack founded foot',(x,y,2.405),.19,.08,steel,seg=32)
  C('tower closed ceramic thermal core',(x,y,2.64),.115,.42,ceramic,seg=32)
  for z in(2.48,2.56,2.64,2.72,2.80):C('stack seated cooling flange',(x,y,z),.16,.028,bronze,seg=32)
  C('thermal stack closed retained head',(x,y,2.86),.14,.08,steel,seg=32)
# Right front opaque control annex: heavy casting, fitted covers and founded cable entries.
B('control annex founded shoe',(1.90,-1.50,.53),(1.60,1.60,.22),steel,bevel=.045)
B('closed control and cargo sorting annex',(1.90,-1.50,1.04),(1.45,1.45,.82),iron,bevel=.07)
B('closed annex enamel roof',(1.90,-1.50,1.50),(1.57,1.57,.12),ceramic,bevel=.03)
for y in(-1.95,-1.5,-1.05):
 B('annex opaque green blind indicator panel',(2.635,y,1.06),(.035,.30,.40),glass)
 for z in(.84,1.28):B('annex indicator retained rail',(2.66,y,z),(.035,.36,.035),bronze,bevel=.006)
for x in(1.35,2.45):
 for z in(.76,1.30):stud('annex front cast cover screw',(x,-2.2425,z),(0,-1,0),.030)
B('annex front closed access plate',(1.90,-2.25,1.05),(1.23,.035,.43),steel)
for x in(1.52,1.90,2.28):
 C('annex retained control head',(x,-2.29,1.08),.075,.045,bronze,'Y',seg=32)
 C('annex closed green witness',(x,-2.321,1.08),.048,.022,green,'Y',seg=32)
# Retained external service lines run between founded bodies; none is a native fluid socket.
for j in range(4):
 y=.65+j*.13
 points=[(-1.53,y,1.88),(-1.32,y,1.88),(-1.13,y,1.74),(-.93,y,1.69),(-.63,y,1.69)]
 route('tower to rite chamber protected service loop',points,.042,bronze,seg=16)
 for x in(-1.51,-.67):C('service line closed entry gland',(x,y,1.69 if x>-.9 else 1.88),.068,.085,steel,'X',seg=24)
# Decorative plate joints, seated covers and bolted escutcheons cover the shared bridge.
for x in(-.85,-.35,.15,.65):
 B('closed bridge seated enamel tablet',(x,.45,1.32),(.43,.46,.035),ceramic)
 for xx in(x-.16,x+.16):
  for y in(.30,.60):stud('bridge tablet retained stud',(xx,y,1.3375),r=.019)
 for j in range(4):B('bridge tablet embossed trace',(x,.31+j*.087,1.347),(.25,.018,.018),bronze,bevel=.004)
# Supported communications dish preserves the reference silhouette; the process interior is hidden.
B('communications founded shoe',(2.32,.47,.48),(.52,.58,.12),steel)
C('communications founded mast',(2.32,.47,1.44),.09,1.80,steel,seg=32)
for z in(.63,1.2,1.9):C('mast retained collar',(2.32,.47,z),.135,.065,bronze,seg=32)
beam('mast founded diagonal brace',(2.65,.47,.54),(2.32,.47,1.82),.10,.10,steel)
C('dish fixed pitch bearing',(2.32,.47,2.35),.13,.33,bronze,'X',seg=32)
dish=E('closed communications dish',(2.32,.47,2.46));dish.rotation_euler.x=math.radians(25)
C('opaque backed communications plate',(0,0,.04),.48,.08,steel,parent=dish,seg=64)
ring('dish retained circular rim',(0,0),.085,.505,.464,.05,bronze,parent=dish)
for k in range(8):
 a=k*math.tau/8;o=B('dish radial stiffening bar',(.26*math.cos(a),.26*math.sin(a),.096),(.45,.024,.024),bronze,dish,.005);o.rotation_euler.z=a
C('dish central retained feed foot',(0,0,.115),.075,.07,bronze,parent=dish,seg=24)
C('dish supported feed stalk',(0,0,.25),.025,.25,steel,parent=dish,seg=16)
C('dish closed feed head',(0,0,.40),.065,.075,bronze,parent=dish,seg=24)
# A bored, retained exterior roof cooling fan is the only working mechanism.
fanxy=(1.90,-1.50)
C('fan opaque founded backplate',(*fanxy,1.61),.38,.10,iron,seg=64)
ring('fan fixed annular housing',fanxy,1.74,.405,.350,.18,steel)
C('fan fixed shaft',(*fanxy,1.75),.0345,.24,steel,seg=24)
rotor=E('WORKING externally guarded cooling rotor',(*fanxy,1.74));ring('fan bored rotating hub',(0,0),0,.09,.035,.024,bronze,parent=rotor)
for k in range(5):
 a=k*math.tau/5;o=B('fan retained blade',(.20*math.cos(a),.20*math.sin(a),0),(.25,.060,.018),steel,rotor,.008);o.rotation_euler.z=a
for z in(1.7235,1.7565):ring('fan fixed shaft axial washer',fanxy,z,.052,.0345,.008,bronze)
for i in range(-4,5):
 x=i*.066;length=2*math.sqrt(.35**2-x*x);B('fan fixed retained grille',(fanxy[0]+x,fanxy[1],1.86),(.014,length,.016),bronze,bevel=.003)
ring('fan seated guard rim',fanxy,1.86,.405,.344,.025,bronze)
C('fan shaft retained end cap',(*fanxy,1.86),.05,.025,steel,seg=24)
for f,a in((1,0),(193,math.tau)):
 rotor.rotation_euler.z=a;rotor.keyframe_insert(data_path='rotation_euler',frame=f,group='working exterior cooling fan')
for act in bpy.data.actions:
 for layer in act.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for fc in bag.fcurves:
     for key in fc.keyframe_points:key.interpolation='LINEAR'
# Fitted exterior skin: sealed service casings, conforming dome panels, retained
# hatch tracery and founded perimeter chambers. No factory interior is exposed.
for x,y,w,d in[(-2.40,-1.30,.65,1.92),(-2.02,2.46,1.25,.57),(2.48,1.85,.58,1.45),(.75,-2.55,1.40,.48)]:
 B('low service casing founded shoe',(x,y,.48),(w+.07,d+.07,.12),steel)
 B('closed perimeter service casing',(x,y,.80),(w,d,.53),iron,bevel=.035)
 B('service casing retained enamel cap',(x,y,1.10),(w+.035,d+.035,.075),ceramic)
 for xx in(x-w*.34,x+w*.34):
  for yy in(y-d*.34,y+d*.34):stud('perimeter casing cap bolt',(xx,yy,1.1375),r=.024)
 for j in range(5):
  B('perimeter casing seated top lattice',(x,y-d*.36+j*d*.18,1.15),(.72*w,.018,.025),bronze,bevel=.004)
# A founded closed front gate merges into the circular chamber casting.
B('front cargo gate founded boot',(-.65,-2.49,.52),(.84,.70,.20),steel)
B('front closed cargo gate casting',(-.65,-2.49,.98),(.71,.58,.79),iron,bevel=.055)
B('front opaque green sealed gate',(-.65,-2.795,1.02),(.47,.035,.62),glass)
for x in(-.93,-.37):B('gate founded bronze jamb',(x,-2.82,1.02),(.07,.07,.78),bronze)
for z in(.67,1.37):B('gate seated arch tie',(-.65,-2.82,z),(.63,.07,.07),bronze)
for x in(-.80,-.65,-.50):B('gate retained vertical tracery',(x,-2.823,1.02),(.022,.04,.62),steel,bevel=.004)
for z in(.83,1.14):B('gate closed pane crossbar',(-.65,-2.823,z),(.47,.04,.022),bronze,bevel=.004)
for x in(-.93,-.37):
 for z in(.79,1.25):stud('front gate retaining stud',(x,-2.857,z),(0,-1,0),.023)
# Concentric retained traces and separated glyph tablets cover the opaque rite lid.
for r in(.29,.51,.74,.92):ring('rite pane seated concentric lattice',front,1.584,r+.012,r-.012,.028,bronze)
for k in range(24):
 a=k*math.tau/24;x=front[0]+.84*math.cos(a);y=front[1]+.84*math.sin(a)
 o=B('closed rite pane retained index tablet',(x,y,1.5815),(.12,.09,.025),iron,bevel=.006);o.rotation_euler.z=a
 for j in(-1,0,1):
  o=B('index tablet embossed glyph',(x+j*.026*math.cos(a),y+j*.026*math.sin(a),1.5985),(.012,.055,.014),bronze,bevel=.003);o.rotation_euler.z=a
 if k%3==0:C('sealed rite index witness',(front[0]+.66*math.cos(a),front[1]+.66*math.sin(a),1.586),.035,.035,green,seg=16)
# Continuous latitude seams and curved mounted scales follow the dome surface.
def domepoint(a,t,offset=0):
 return(rear[0]+(1.20+offset)*math.cos(t)*math.cos(a),rear[1]+(1.20+offset)*math.cos(t)*math.sin(a),1.30+(1.15+offset)*math.sin(t))
def domepatch(n,a,t,da,dt,m):
 vv=[];N=5;T=4
 for off in(.003,.025):
  for j in range(T):
   for i in range(N):vv.append(domepoint(a-da/2+da*i/(N-1),t-dt/2+dt*j/(T-1),off))
 ff=[];layer=N*T
 for side in(0,1):
  for j in range(T-1):
   for i in range(N-1):
    q=(side*layer+j*N+i,side*layer+j*N+i+1,side*layer+(j+1)*N+i+1,side*layer+(j+1)*N+i);ff.append(tuple(reversed(q))if side==0 else q)
 perimeter=list(range(N))+[j*N+N-1 for j in range(1,T)]+list(range((T-1)*N+N-2,(T-1)*N-1,-1))+[j*N for j in range(T-2,0,-1)]
 for i,k in enumerate(perimeter):q=perimeter[(i+1)%len(perimeter)];ff.append((k,q,q+layer,k+layer))
 return mesh('ORBITAL | '+n,vv,ff,m,col,root)
for t in(.24,.55,.88,1.16):
 points=[domepoint(i*math.tau/96,t,.012)for i in range(97)];route('dome seated continuous latitude seam',points,.018,bronze,seg=8)
for k in range(16):
 a=(k+.5)*math.tau/16
 for j,t in enumerate((.13,.40,.72,1.03)):
  domepatch('conforming retained armored scale',a,t,.30,.17,steel if j%2==0 else ceramic)
  for dx in(-.105,.105):
   aa=a+dx;p=domepoint(aa,t,.030);normal=(math.cos(t)*math.cos(aa),math.cos(t)*math.sin(aa),math.sin(t));stud('dome scale retaining screw',p,normal,.016)
  for dt in(-.037,0,.037):domepatch('conforming scale embossed rib',a,t+dt,.16,.012,bronze)
# Tower armor panels seat on their closed backing, surrounded by genuine cast rails.
for y in(.35,.95,1.55):
 B('tower front cast exchanger backing',(-2.10,.058,.85+(y-.35)*.6),(.57,.032,.25),ceramic)
for z in(.84,1.28,1.72,2.10):
 B('tower rear enamel service tablet',(-2.10,2.054,z),(.77,.035,.28),ceramic)
 for x in(-2.40,-1.80):stud('tower rear tablet fastener',(x,2.077,z),(0,1,0),.022)
 for j in range(5):B('tower rear tablet engraved rail',(-2.36+j*.13,2.082,z),(.024,.022,.18),bronze,bevel=.004)
for x in(-2.57,-1.63):
 B('tower roof continuous retaining rail',(x,1.05,2.3825),(.045,1.91,.035),bronze)
for y in(.12,1.98):B('tower roof transverse retaining rail',(-2.10,y,2.3825),(1.01,.045,.035),bronze)
# Closed annex roof has fitted embossed service plates around the fan, not a plain slab.
for x,y in[(1.37,-1.02),(2.43,-1.02),(1.37,-2.02),(2.43,-2.02)]:
 B('annex roof retained service tablet',(x,y,1.579),(.42,.37,.038),steel)
 for xx in(x-.14,x+.14):
  for yy in(y-.12,y+.12):stud('annex roof tablet retained stud',(xx,yy,1.598),r=.017)
 for j in range(4):B('annex roof seated trace',(x,y-.095+j*.063,1.6075),(.23,.015,.019),bronze,bevel=.003)
for x in(1.20,2.60):B('annex side founded structural post',(x,-1.50,1.05),(.08,1.30,.08),bronze)
# Sealed underside service lead bundles have founded saddles and retained collars.
for j in range(3):
 z=.70+j*.115;points=[(.63,-1.10,z),(.82,-1.10,z),(.97,-1.0,z),(1.19,-1.0,z)]
 route('chamber to annex closed protected lead',points,.036,bronze,seg=12)
 for x,y in((.66,-1.10),(1.17,-1.0)):
  C('protected lead retained sleeve',(x,y,z),.055,.10,steel,'X',seg=24)
# Source-study correction: lid cast radial reliefs carry their studs at the actual top surface.
for o in col.objects:
 if 'cargo lid perimeter stud seated head'in o.name:o.location.z+=.021
 if 'cargo lid perimeter stud retained stem'in o.name:o.location.z+=.021

# Founded service entries seat the rigid lead terminations in actual supporting castings.
B('tower bundle fixed entry casting',(-1.555,.845,1.88),(.10,.62,.20),steel)
B('bridge bundle founded entry casting',(-.65,.845,1.49),(.22,.64,.40),steel)
old=bpy.data.objects.get('ORBITAL | closed cargo chamber service tablet')
if old:bpy.data.objects.remove(old,do_unlink=True)
B('chamber protected lead seated entry casting',(.61,-1.10,.815),(.14,.22,.51),steel)
# Every perimeter casing gets a seated service face, framed access panel and cast ribs.
for x,y,w,d in[(-2.40,-1.30,.65,1.92),(-2.02,2.46,1.25,.57),(2.48,1.85,.58,1.45),(.75,-2.55,1.40,.48)]:
 for side in(-1,1):
  yy=y+side*(d/2+.015)
  B('perimeter closed retained access face',(x,yy,.82),(.80*w,.03,.33),ceramic)
  for xx in(x-.33*w,x+.33*w):
   for z in(.70,.94):stud('access face retained screw',(xx,yy+side*.015,z),(0,side,0),.019)
  for j in range(4):B('access face seated horizontal lattice',(x,yy+side*.023,.73+j*.055),(.56*w,.018,.013),bronze,bevel=.003)
  xx=x+side*(w/2+.015)
  B('perimeter closed side access face',(xx,y,.82),(.03,.78*d,.33),steel)
  for z in(.67,.97):B('side face seated retaining rail',(xx+side*.023,y,z),(.018,.84*d,.025),bronze,bevel=.004)
  for j in range(max(3,int(d/.16))):B('side face embossed upright rib',(xx+side*.023,y-d*.32+j*d*.64/max(2,int(d/.16)-1),.82),(.018,.025,.25),bronze,bevel=.004)
# Cargo drum tablets receive fitted bronze escutcheons and repeated retained raised glyphs.
for k in range(1,16):
 a=k*math.tau/16
 for z in(.72,1.01):radial('cargo tablet seated retaining border',front,a,1.312,z,(.022,.29,.024),bronze)
 for q in range(4):
  x=front[0]+1.314*math.cos(a)-(.09-q*.06)*math.sin(a);y=front[1]+1.314*math.sin(a)+(.09-q*.06)*math.cos(a)
  o=B('cargo tablet mounted embossed character',(x,y,.86),(.018,.024,.17),bronze,bevel=.004);o.rotation_euler.z=a
# Left tower blank structural faces are covered by founded, framed service castings.
for z in(.92,1.38,1.84):
 B('tower inner closed retained service casting',(-1.541,1.58,z),(.038,.70,.35),ceramic)
 for yy in(1.29,1.87):
  for zz in(z-.12,z+.12):stud('tower service casting screw',(-1.522,yy,zz),(1,0,0),.020)
 for j in range(5):B('tower service casting seated louvre',(-1.510,1.58,z-.10+j*.05),(.025,.47,.017),bronze,bevel=.004)
# External thermal headers are fixed to the tower rear wall by actual cast brackets.
for x in(-2.36,-1.86):
 C('tower rear fixed thermal header',(x,2.22,1.50),.075,1.13,bronze,seg=24)
 for z in(1.00,1.40,1.95):
  B('thermal header rooted mounting block',(x,2.08,z),(.20,.10,.12),steel)
  ring('thermal header retained collar',(x,2.22),z,.105,.075,.075,steel)
 C('thermal header closed top retainer',(x,2.22,2.09),.10,.09,steel,seg=24)
 C('thermal header closed lower retainer',(x,2.22,.91),.10,.10,steel,seg=24)
# Rim latches sit on the annular frame, with their locking bars retained over the lid seam.
for k in range(12):
 a=(k+.5)*math.tau/12
 radial('cargo lid retaining latch seat',front,a,1.28,1.58,(.11,.12,.14),steel)
 radial('annular frame retained locking tongue',front,a,1.29,1.66,(.21,.055,.04),bronze)
 stud('cargo latch crown screw',(front[0]+1.28*math.cos(a),front[1]+1.28*math.sin(a),1.68),r=.024)
# Founded front corner retaining towers carry sealed inspection plates and seated terminals.
for x in(-2.45,2.45):
 B('front corner founded buttress',(x,-2.50,.64),(.40,.46,.44),steel)
 B('front corner closed bronze service cap',(x,-2.50,.89),(.43,.49,.08),bronze)
 C('corner retained inspection boss',(x,-2.755,.66),.11,.05,steel,'Y',seg=32)
 C('corner sealed green witness',(x,-2.786,.66),.06,.025,glass,'Y',seg=24)
 for z in(.52,.80):stud('corner inspection cast face retention',(x,-2.755,z),(0,-1,0),.021)

# Structural attachment revision: mounts connect to their actual opaque host,
# not merely to another floating detail. The sealed panes remain visibly recessed.
for y in(.40,1.05,1.70):
 B('tower window founded mounting backplate',(-2.648,y,1.53),(.04,.54,1.03),iron)
 for yy in(y-.24,y+.24):
  for z in(1.13,1.93):stud('tower window wall retention',(-2.701,yy,z),(-1,0,0),.018)
B('front gate founded mounting surround',(-.65,-2.78,1.02),(.70,.04,.86),iron)
for y in(-1.95,-1.50,-1.05):
 for z in(.84,1.28):B('annex glazing founded mounting tongue',(2.6325,y,z),(.035,.36,.045),steel)
 for yy in(y-.166,y+.166):B('annex retained glazing jamb',(2.66,yy,1.06),(.035,.035,.48),bronze)
for k in range(8):
 a=k*math.tau/8;ring('rite witness seated retaining bezel',(front[0]+.66*math.cos(a),front[1]+.66*math.sin(a)),1.5815,.050,.0325,.025,bronze)
# Remove redundant, fully occluded bridge-tablet assemblies under the joined
# chambers/entry block. Hidden decorative objects cannot serve as structural mounts.
for o in list(col.objects):
 if any(key in o.name for key in('closed bridge seated enamel tablet','bridge tablet retained stud','bridge tablet embossed trace')):bpy.data.objects.remove(o,do_unlink=True)

# Owner-directed cargo arrival: four wedge lids open on supported tangent
# journals, a rigid upright pod lands in a real recessed well, then lids close.
import re
obsolete=('founded circular cargo-rite chamber','sealed heavy cargo-rite lid','opaque green closed rite pane','pane central retained seal','sealed green central witness','closed pane radial retained lattice','rite pane seated concentric lattice','closed rite pane retained index tablet','index tablet embossed glyph','sealed rite index witness','rite witness seated retaining bezel')
for o in list(col.objects):
 key=re.sub(r'\.\d+$','',o.name).replace('ORBITAL | ','')
 if key in obsolete:bpy.data.objects.remove(o,do_unlink=True)
# Continuous fixed liner and floor. Foundation/deck/bridge receive a genuine bore.
ring('cargo receiver continuous hollow wall',front,.70,1.25,.86,1.30,iron)
ring('fixed annular cargo lid foundation',front,1.42,1.30,.80,.22,steel)
C('cargo receiving well founded floor',(*front,.03),.88,.04,steel,seg=96)
cut=C('TEMP real receiving-well aperture cutter',(*front,.75),.86,2.5,dark,seg=96)
for o in list(col.objects):
 key=re.sub(r'\.\d+$','',o.name).replace('ORBITAL | ','')
 if key in('founded dressed slab','fitted masonry course','continuous retained armored deck','closed common cargo transfer bridge'):
  mod=o.modifiers.new('Real receiving well through closed support volumes','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut
# Local closed-sector mesh, with radial relief around the fixed hinge ears/motor.
def wedge(n,parent,outer,z0,z1,m,angle=44.85,notches=False):
 points=[]
 for k in range(61):
  a=math.radians(-angle+2*angle*k/60);deg=math.degrees(a);r=outer
  if notches and 4<abs(deg)<15:r=min(r,.90)
  if notches and 14<=deg<28:r=min(r,.84)
  points.append((r*math.cos(a)-.98,r*math.sin(a)))
 inner=.045 if notches else .070
 for k in range(60,-1,-1):
  a=math.radians(-angle+2*angle*k/60);points.append((inner*math.cos(a)-.98,inner*math.sin(a)))
 N=len(points);vv=[(x,y,z)for z in(z0,z1)for x,y in points];ff=[tuple(reversed(range(N))),tuple(range(N,2*N))]+[(i,(i+1)%N,(i+1)%N+N,i+N)for i in range(N)]
 return mesh('ORBITAL | '+n,vv,ff,m,col,parent)
def yr(n,y,r,bore,d,m,parent):
 return tube('ORBITAL | '+n,[((0,y-d/2,0),(0,1,0),r,bore),((0,y+d/2,0),(0,1,0),r,bore)],m,col,parent,32)
leaves=[];journals=[]
for k in range(4):
 a=k*math.pi/2;p=(front[0]+.98*math.cos(a),front[1]+.98*math.sin(a),1.68)
 fixed=E('cargo hatch founded hinge station '+str(k),p);fixed.rotation_euler.z=a
 leaf=E('WORKING cargo wedge hinge '+str(k),p);leaf.rotation_euler.z=a;leaves.append(leaf)
 wedge('cargo wedge retained armored leaf',leaf,.98,-.013,.013,iron,notches=True)
 wedge('cargo wedge opaque green inset',leaf,.735,.012,.027,glass,angle=42)
 # The entire hatch leaf, traces and labels are one rigid moving assembly.
 for r in(.28,.49,.70):
  points=[(r*math.cos(t)-.98,r*math.sin(t),.034)for t in[math.radians(-41+82*j/28)for j in range(29)]];route('wedge seated curved trace',points,.012,bronze,parent=leaf,seg=8)
 for deg in(-37.5,-22.5,-7.5,7.5,22.5,37.5):
  t=math.radians(deg);x=.84*math.cos(t)-.98;y=.84*math.sin(t);o=B('wedge retained index tablet',(x,y,.026),(.10,.07,.026),steel,leaf,.005);o.rotation_euler.z=t
  for j in(-1,0,1):
   o=B('wedge tablet seated glyph',(x+j*.022*math.cos(t),y+j*.022*math.sin(t),.046),(.010,.043,.016),bronze,leaf,.003);o.rotation_euler.z=t
 yr('wedge moving bored drive sleeve',0,.042,.0195,.24,bronze,leaf)
 C('wedge rigid rotating drive pin',(0,.0425,0),.0195,.555,steel,'Y',leaf,32)
 for yy in(-.225,.225):C('wedge rotating pin retained end head',(0,yy,0),.035,.020,bronze,'Y',leaf,32)
 for side in(-1,1):
  yy=side*.17;yr('wedge fixed bored journal ear',yy,.043,.020,.05,steel,fixed)
  B('wedge journal founded foot',(.080,yy,-.005),(.09,.05,.11),steel,fixed,.008)
  yr('wedge fixed inner axial washer',side*.1225,.043,.020,.004,bronze,fixed)
  yr('wedge fixed inner journal spacer',side*.13475,.032,.020,.0205,steel,fixed)
  yr('wedge fixed outer retained spacer',side*.20475,.032,.020,.0195,steel,fixed)
 # The drive pin enters an enclosed, founded rotary actuator, through its bore.
 yr('wedge fixed closed rotary actuator casing',.32,.10,.020,.15,iron,fixed)
 C('wedge actuator sealed outer end',(0,.405,0),.10,.020,steel,'Y',fixed,32)
 B('wedge actuator founded support foot',(.11,.32,-.045),(.10,.17,.14),steel,fixed,.008)
 for f,deg in((1,0),(25,0),(73,90),(265,90),(337,0),(481,0)):
  leaf.rotation_euler.y=math.radians(deg);leaf.keyframe_insert(data_path='rotation_euler',frame=f,group='cargo hatch opening then closure')
 journals.append({'leaf':leaf.name,'fixed_station':fixed.name,'pivot':p,'axis':[float(-math.sin(a)),float(math.cos(a)),0],'rotating_pin_radius':.0195,'fixed_journal_bore':.020,'radial_running_clearance':.0005,'inner_axial_clearance':.0005,'leaf_profile_relief_for_ears_and_actuator':True})
# One retained central seal belongs to the first leaf; it clears the other
# three leaves during opening, rather than leaving four colliding apex corners.
B('cargo wedge central seal retained strap',(-.90,0,.021),(.18,.026,.022),bronze,leaves[0],.004)
C('cargo wedge central retained seal',(-.98,0,.042),.055,.024,steel,parent=leaves[0],seg=32)
C('cargo wedge central closed witness',(-.98,0,.061),.032,.014,green,parent=leaves[0],seg=24)

# Existing Factorio cargo-pod model and native landing procession are reused at runtime.
# No authored replacement cargo pod or descent animation belongs in this source.
# Re-key the guarded cooling fan to an exact ten-second working loop.
rotor.animation_data_clear()
for f,a in((1,0),(481,math.tau*3)):
 rotor.rotation_euler.z=a;rotor.keyframe_insert(data_path='rotation_euler',frame=f,group='working cooling fan')
for layer in rotor.animation_data.action.layers:
 for strip in layer.strips:
  for bag in strip.channelbags:
   for fc in bag.fcurves:
    for key in fc.keyframe_points:key.interpolation='LINEAR'
(O/'cargo-animation-construction.json').write_text(json.dumps({'style':'Four hinged wedge lids and receiving well; existing native cargo pod/procession handles arrival.','clip_seconds':10,'source_fps':48,'hatch_open_seconds':[.5,1.5],'native_pod_timing_comes_from_engine_events':True,'hatch_close_seconds':[5.5,7.0],'sealed_landing_well_actual_foundation_bore':True,'existing_native_cargo_pod_reused':True,'authored_replacement_pod_meshes':0,'cargo_pod_reference':'base cargo-pod; unchanged native graphics/procession catalogue','no_actual_native_cargo_transport_gameplay_added':True,'hinge_journals':journals,'owner_visual_approved':False},indent=2))

# Physical image-map UVs, editable save/reopen, and actual runtime export.
uvs=[];dg=bpy.context.evaluated_depsgraph_get();baked={o:bpy.data.meshes.new_from_object(o.evaluated_get(dg))for o in tuple(col.objects)if o.type=='MESH'and o.modifiers}
for o,data in baked.items():o.data=data;o.modifiers.clear()
bpy.data.objects.remove(cut,do_unlink=True)
for o in tuple(col.objects):
 if o.type!='MESH':continue
 mode='cylinder'if cylinder_uv(o)else'sweep'if sweep_uv(o)else'panel'
 if mode=='panel':panel_uv(o)
 o['fmpl_uv_method']=mode;uvs.append({'object':o.name,'method':mode,'material':o.data.materials[0].name})
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
for _ in range(3):bpy.data.orphans_purge(do_local_ids=True,do_linked_ids=False,do_recursive=True)
profile={'camera_policy':'fmpl.factorio45.v1','capture_kind':'entity','orientation_policy':'fixed','directions':[0],'native_directions':[0],'states':{'idle':[0],'working':list(range(1,481,6))},'source_size':512,'fps':8,'camera_override':{'type':'ORTHO','elevation_deg':45,'azimuth_deg':0,'distance':8.48528137423857,'ortho_scale':12.,'target':[0,0,1.15]}}
install_canonical_camera(s,profile,bpy);s.render.engine='CYCLES';s.cycles.samples=24;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.fps=48;s.frame_start=1;s.frame_end=481
s.world=bpy.data.worlds.new('Orbital neutral studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.25,.25,1)
for loc,power,size in[((4,-7,9),1800,7),((-6,3,6),1400,6)]:
 l=bpy.data.lights.new('Orbital authored studio','AREA');l.energy=power;l.size=size;o=bpy.data.objects.new(l.name,l);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,1.4))-o.location).to_track_quat('-Z','Y').to_euler()
s.frame_set(1);assert_clean(s,profile,bpy);bpy.ops.file.pack_all();source=O/'orbital-v07.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True);bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;root=bpy.data.objects['EXPORT | Orbital Trader'];bpy.ops.object.select_all(action='DESELECT')
for o in[root,*root.children_recursive]:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'orbital-v07.glb'),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_force_sampling=True,export_frame_range=True,export_anim_slide_to_zero=True,export_apply=True)
(O/'capture-profile.json').write_text(json.dumps(profile,indent=2));(O/'fmpl-surface-manifest.json').write_text(json.dumps({'status':'candidate-not-native-integrated','source_sha256':sha(source),'runtime_sha256':sha(O/'orbital-v07.glb'),'role_instances':roles,'uv_assignments':uvs,'native_footprint':[6,6],'native_directions':[0],'all_original_source_maps_git_blob_verified':True,'owner_visual_approved':False},indent=2))
projection=bpy.data.objects.new('UNSAVED canonical square ground',None);s.collection.objects.link(projection);projection.scale.y=math.sqrt(2);root.parent=projection;s.frame_set(25);s.render.resolution_x=s.render.resolution_y=768;s.render.filepath=str(O/'front-review.png');bpy.ops.render.render(write_still=True);projection.scale.y=1
with temporary_inspection_camera(s,bpy,'Orbital true proportions')as camera:
 target=Vector((0,0,1.4));camera.data.type='ORTHO';camera.data.ortho_scale=8.8;camera.location=(7,-10,8);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();s.camera=camera;s.render.filepath=str(O/'detail-review.png');bpy.ops.render.render(write_still=True)
print('ORBITAL_EDITABLE_SOURCE_AND_RUNTIME_SAVED',sha(source),flush=True)
