"""Break exposed castings into service panels, real vent apertures and buttresses."""
import ast,bpy,bmesh,json,math,sys,hashlib,shutil,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
R=Path(__file__).resolve().parents[3];OLD=R/'art/source-to-3d/conclave-center/v04-arch-and-services';O=OLD.parent/'v05-panels-and-buttresses';O.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(OLD/'conclave-center-v04.blend'));s=bpy.context.scene;root=bpy.data.objects['Conclave Center | ground origin'];contacts=json.loads((OLD/'contacts.json').read_text());changes=[]
mats={k:bpy.data.materials.get('Conclave V03 | '+k) or bpy.data.materials.get('Conclave | '+k) for k in ['cast-frame','console-panels','edge-trim','control-keys','floor-tread','cable-jacket']}
for k in ('signal-red','signal-amber','signal-black'):mats[k]=bpy.data.materials['Conclave V04 | '+k]
for key,donor in [('roof-panel','floor-tread'),('rear-hatch','console-panels')]:
 local=mats[donor].copy();local.name='Conclave V05 | '+key
 for node in local.node_tree.nodes:
  if node.type=='TEX_IMAGE':
   kind='albedo' if node.name.endswith('ALBEDO') else 'orm' if node.name.endswith('ORM') else 'normal' if node.name.endswith('NORMAL') else None
   if kind:
    image=bpy.data.images.load(str(O/'textures'/(key+'-'+kind+'.png')),check_existing=True);image.colorspace_settings.name='sRGB' if kind=='albedo' else 'Non-Color';image.pack();node.image=image
 mats[key]=local
 local['model_specific_surface']=json.dumps(json.loads((O/'panel-surfaces.json').read_text())[key])
 local['tp_library_material_id']=json.loads((O/'panel-surfaces.json').read_text())[key]['fmpl_material_id']
helper=R/'tools/art/conclave/refine_v03.py';tree=ast.parse(helper.read_text());names={'uv','mesh','box','joint','cylinder','octrect','ring_xz','replace'};exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[]),str(helper),'exec'))
def signature(prefix):
 return {o.name:hashlib.sha256(json.dumps(dict(vertices=[list(v.co) for v in o.data.vertices],matrix=[list(row) for row in o.matrix_world]),sort_keys=True).encode()).hexdigest() for o in s.objects if o.name.startswith(prefix)}
skulls=signature('Supplied DGordillo low-poly skull');candles=signature('Arch candle');stations=[(0,.18,0,.60),(-.62,-.17,math.pi/4,.49),(.62,-.17,-math.pi/4,.49)]
cuts=[];removed=[];cutters=[]
def remove_prefix(prefix):
 for o in list(s.objects):
  if o.name.startswith(prefix):removed.append(o.name);bpy.data.objects.remove(o,do_unlink=True)
def cut(target,tools,label):
 bpy.ops.object.select_all(action='DESELECT')
 for obj in tools:obj.select_set(True)
 bpy.context.view_layer.objects.active=tools[0];bpy.ops.object.join();tool=bpy.context.object
 bpy.context.view_layer.objects.active=target;mod=target.modifiers.new(label,'BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=tool;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(tool,do_unlink=True)
 bm=bmesh.new();bm.from_mesh(target.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(target.data);bm.free();target.data.update();cuts.append(dict(mesh=target.name,operation=label))
def bolt(name,p,normal,r=.012,depth=.022,mat='edge-trim'):
 p=Vector(p);n=Vector(normal).normalized();return cylinder(name,p-n*depth*.35,p+n*depth*.65,r,mat,6)
for i,(cx,cy,yaw,w) in enumerate(stations):
 M=Matrix.Translation((cx,cy,0))@Matrix.Rotation(yaw,4,'Z');pre='Console %d | '%i;cab=bpy.data.objects[pre+'deep monitor cabinet']
 # Side vent slots genuinely penetrate the tapered casing wall.
 tools=[]
 for sign in (-1,1):
  for j in range(5):tools.append(box('temporary side vent cutter',(sign*w*.47,.06,1.04+j*.04),(.17,.135,.018),'cast-frame',M,0))
 cut(cab,tools,'Actual side ventilation slots')
 for sign in (-1,1):
  def sidepoint(y,z,out=.010):return (sign*(w*.5-w*.06*(y+.113)/.337+out),y,z)
  def sidepiece(label,y,z,dy,dz,depth=.014,mat='edge-trim',out=.010):
   p=sidepoint(y,z,out);frame=M@Matrix.Translation(p)@Matrix.Rotation(sign*math.atan(w*.06/.337),4,'Z');return box(pre+label,(0,0,0),(depth,dy,dz),mat,frame,.003)
  # Vent frame and internal dark plenum make the aperture depth legible.
  for y in (-.024,.144):
   rail=sidepiece('vent upright '+str((sign,y)),y,1.12,.020,.252);joint(rail,cab,'vent frame retained on casting beside actual slots')
  for z in (.996,1.244):
   rail=sidepiece('vent cross rail '+str((sign,z)),.06,z,.187,.020);joint(rail,cab,'cross rail retained around vent aperture')
  for j in range(5):
   louver=sidepiece('angled side vent lip '+str((sign,j)),.06,1.052+j*.04,.143,.010,.022,'cast-frame',.006);joint(louver,cab,'louver root retained above through-slot')
  for y in (-.025,.145):
   for z in (1.00,1.24):
    p=M@Vector(sidepoint(y,z,.017));normal=M.to_3x3()@Vector((sign,0,0));b=bolt(pre+'vent captive screw '+str((sign,y,z)),p,normal,.008,.017);joint(b,cab,'vent frame screw fastens through casting')
 # Roof gasket, removable lid, raised ribs and actual fastener seats.
 pitch=math.atan(-.04/.337);topz=1.385-.04*(.05+.113)/.337;roof=M@Matrix.Translation((0,.05,topz))@Matrix.Rotation(pitch,4,'X')
 gasket=box(pre+'roof access gasket',(0,0,.003),(w*.78,.252,.010),'cable-jacket',roof,.004);joint(gasket,cab,'roof gasket seals original cast top')
 lid=box(pre+'removable roof access panel',(0,0,.014),(w*.74,.235,.016),'roof-panel',roof,.006);joint(lid,gasket,'roof lid sits on continuous gasket')
 for x in (-w*.24,0,w*.24):
  rib=box(pre+'raised roof strengthening rib '+str(x),(x,0,.032),(.015,.221,.025),'cast-frame',roof,.004);joint(rib,lid,'longitudinal strengthening rib cast onto access lid')
 for x in (-w*.32,w*.32):
  for y in (-.092,.092):
   p=roof@Vector((x,y,.027));b=bolt(pre+'roof captive stud '+str((x,y)),p,roof.to_3x3()@Vector((0,0,1)),.010,.019);joint(b,lid,'roof fastener root seated in service lid')
 for x in (-w*.23,w*.23):
  hinge=box(pre+'roof hinge block '+str(x),(x,.132,.011),(.052,.032,.026),'edge-trim',roof,.005);joint(hinge,cab,'hinge block retained in original casting')
 # Replace the rear blank panel by a genuinely open grille and eight louvers.
 replace(pre+'rear connector backplate',ring_xz('rear grille frame',octrect(w*.75,.36,.025),octrect(w*.59,.245,.018),.218,.247,1.10,'console-panels',M))
 midrail=box(pre+'rear centre gland rail',(0,.246,1.10),(w*.63,.035,.042),'edge-trim',M,.004);joint(midrail,pre+'rear connector backplate','centre service gland rail spans into grille side frame')
 if i in (1,2):
  sign=-1 if i==1 else 1;strip=box(pre+'rear multipin gland strip',(sign*.13,.246,1.08),(.056,.035,.24),'edge-trim',M,.004);joint(strip,pre+'rear connector backplate','vertical gland strip overlaps actual frame edge beneath cable terminals')
 remove_prefix(pre+'recessed ventilation fin')
 for j in range(8):
  vent=box(pre+'deep rear louver '+str(j),(0,.252,.995+j*.029),(w*.62,.027,.013),'cast-frame',M,.003);joint(vent,pre+'rear connector backplate','louver end roots enter open service grille frame')
 shield=box(pre+'recessed passive circuit shield',(0,.169,1.10),(w*.67,.015,.285),'cable-jacket',M,.005);joint(shield,cab,'dark passive shield retained inside casing behind vent bank')
 for sign in (-1,1):
  for z in (1.02,1.18):
   tab=box(pre+'internal shield retained tab '+str((sign,z)),(sign*w*.35,.174,z),(w*.20,.035,.030),'control-keys',M,.003);joint(tab,cab,'shield retaining tab reaches inside casting wall');joint(shield,tab,'internal passive shield fixed to actual retaining tab')
 for j in range(5):
  fin=box(pre+'internal cooling fin '+str(j),((j-2)*w*.10,.185,1.10),(.014,.025,.242),'control-keys',M,.002);joint(fin,shield,'passive heat fin seated on internal shield')
 # Pedestal service lid gets a perimeter frame, vented top and stiffening ridges.
 lidframe=ring_xz(pre+'pedestal service frame',octrect(w*.65,.382,.022),octrect(w*.49,.285,.016),-.232,-.190,.43,'cast-frame',M);joint(lidframe,pre+'grounded pedestal','service surround embeds into pedestal face')
 for z in (.335,.387):
  ridge=box(pre+'pedestal hatch stiffener '+str(z),(0,-.232,z),(w*.45,.025,.018),'edge-trim',M,.004);joint(ridge,pre+'service lid','stiffener root seated on removable hatch')
 for j in range(4):
  slot=box(pre+'pedestal recessed vent '+str(j),(0,-.222,.465+j*.024),(w*.41,.012,.010),'cable-jacket',M,.002);joint(slot,pre+'service lid','recessed vent bank seated in service lid')
 for x in (-w*.26,w*.26):
  for z in (.275,.585):
   b=bolt(pre+'pedestal frame stud '+str((x,z)),M@Vector((x,-.238,z)),M.to_3x3()@Vector((0,-1,0)),.010,.022);joint(b,lidframe,'captive hatch frame stud seated in surround')
 # Pierced, load-bearing buttress webs support the outer desk wings.
 sides=(-1,1) if i==0 else (-1,) if i==1 else (1,)
 for sign in sides:
  x=sign*w*.32;outline=[(-.09,.13),(.13,.13),(.12,.67),(-.37,.67),(-.32,.56)];n=len(outline);verts=[(x+dx,y,z) for dx in (-.022,.022) for y,z in outline];faces=[tuple(range(n-1,-1,-1)),tuple(n+k for k in range(n))]+[(k,(k+1)%n,n+(k+1)%n,n+k) for k in range(n)]
  web=mesh(pre+'shaped desk buttress '+str(sign),verts,faces,'cast-frame',M,.006)
  cutter=box('temporary buttress relief',(x,-.045,.40),(.12,.16,.20),'cast-frame',M,.015);cut(web,[cutter],'Open buttress service relief')
  joint(web,pre+'sloped control deck','buttress top carries desk wing');joint(web,'Octagonal sole casting','buttress foot lands on sole');joint(web,pre+'grounded pedestal','buttress side ties into pedestal')
  foot=box(pre+'buttress retained shoe '+str(sign),(x,.015,.155),(.105,.26,.050),'edge-trim',M,.008);joint(foot,web,'buttress retained in machined foot shoe');joint(foot,'Octagonal sole casting','shoe bolted to equipment sole')
# Front shrine face also receives real retained covers and continuous cast ribs.
for sign in (-1,1):
 rib=box('V05 front shrine structural rib '+str(sign),(sign*.68,.404,.88),(.065,.049,1.22),'cast-frame',bevel=.015);joint(rib,'Back shrine structural casting','front load rib has continuous seat into shrine casting')
 for z in (.48,.84,1.17,1.43):
  band=box('V05 front rib retained collar '+str((sign,z)),(sign*.68,.377,z),(.088,.025,.038),'edge-trim',bevel=.005);joint(band,rib,'retaining collar wraps front structural rib')
 seal=box('V05 front upper service seal '+str(sign),(sign*.27,.410,1.49),(.165,.018,.245),'cable-jacket',bevel=.014);joint(seal,'Back shrine structural casting','upper service gasket seats into uncut shrine face')
 panel=box('V05 front upper service cover '+str(sign),(sign*.27,.395,1.49),(.145,.022,.222),'console-panels',bevel=.013);joint(panel,seal,'front inspection cover seated on retained gasket')
 for z in (1.432,1.490,1.548):
  ridge=box('V05 front inspection cover ridge '+str((sign,z)),(sign*.27,.380,z),(.119,.014,.014),'edge-trim',bevel=.003);joint(ridge,panel,'front cover cast stiffening ridge')
 for dx in (-.051,.051):
  for z in (1.404,1.576):
   b=bolt('V05 front inspection captive stud '+str((sign,dx,z)),(sign*.27+dx,.378,z),(0,-1,0),.0075,.017);joint(b,panel,'front service cap screw seated in corner')
for i,radius in [(0,.153),(1,.098),(2,.098)]:
 head=bpy.data.objects['Supplied DGordillo low-poly skull '+str(i)];x,y,z=head.location
 for j in range(10):
  a=math.tau*j/10;p=(x+radius*math.cos(a),.399,z+radius*math.sin(a));b=bolt('V05 skull medallion retained stud '+str((i,j)),p,(0,-1,0),.007 if i else .009,.022);joint(b,'Skull retained medallion '+str(i),'skull medallion stud retained on actual backing flange, anatomy unchanged')
# Main rear bay: true casting opening, stepped frame, split hatches and deep grille.
back=bpy.data.objects['Back shrine structural casting'];tool=box('temporary rear service opening',(0,.54,.73),(.75,.40,.65),'cast-frame',bevel=.018);cut(back,[tool],'Actual rear electronics service bay')
replace('Rear access cover',ring_xz('stepped rear access frame',octrect(.96,.87,.04),octrect(.75,.65,.027),.652,.700,.73,'edge-trim',Matrix.Identity(4)))
spine=box('V05 central rear hatch spine',(0,.704,.73),(.043,.045,.67),'cast-frame',bevel=.006);joint(spine,'Rear access cover','central hinge spine retained in upper and lower frame borders')
for sign in (-1,1):
 frame=box('V05 rear split-hatch seal '+str(sign),(sign*.188,.707,.84),(.378,.018,.430),'cable-jacket',bevel=.010);joint(frame,'Rear access cover','split hatch gasket overlaps outer frame edge');joint(frame,spine,'inner gasket edge retained on central spine')
 panel=box('V05 rear split service hatch '+str(sign),(sign*.188,.724,.84),(.326,.023,.396),'rear-hatch',bevel=.014);joint(panel,frame,'removable electronics service panel seated on gasket')
 for x in (sign*.188-.11,sign*.188+.11):
  rib=box('V05 rear hatch rib '+str((sign,x)),(x,.744,.84),(.018,.026,.32),'cast-frame',bevel=.004);joint(rib,panel,'panel strengthening ridge retained on hatch')
 handle=box('V05 rear hatch lift handle '+str(sign),(sign*.188,.765,.86),(.073,.020,.045),'edge-trim',bevel=.009)
 for x in (sign*.188-.030,sign*.188+.030):
  lug=box('V05 rear handle mounting lug '+str((sign,x)),(x,.746,.86),(.018,.038,.035),'edge-trim',bevel=.004);joint(lug,panel,'lift handle lug seated in service panel');joint(handle,lug,'handle captured by mounted lug')
 for z in (.69,.99):
  for dx in (-.127,.127):
   b=bolt('V05 rear hatch captive stud '+str((sign,z,dx)),(sign*.188+dx,.745,z),(0,1,0),.009,.018);joint(b,panel,'hatch screw seated in reinforced panel corner')
for j in range(6):
 fin=box('V05 deep rear bay vent '+str(j),(0,.722,.432+j*.026),(.79,.050,.015),'cast-frame',bevel=.003);joint(fin,'Rear access cover','deep vent ends enter actual bay perimeter side rails')
shield=box('V05 rear bay recessed shield',(0,.59,.72),(.72,.018,.60),'cable-jacket',bevel=.008);joint(shield,back,'recessed shield retained in casting opening')
for sign in (-1,1):
 for z in (.46,.98):
  tab=box('V05 main bay shield retaining tab '+str((sign,z)),(sign*.38,.60,z),(.065,.04,.06),'control-keys',bevel=.004);joint(tab,back,'main bay tab overlaps actual cut casting edge');joint(shield,tab,'bay shield fastened to retained tab')
for sign in (-1,1):
 # Large triangular buttresses make the rear wall load path visible.
 x=sign*.62;profile=[(.61,.13),(.84,.13),(.80,.33),(.68,1.32),(.61,1.32)];n=len(profile);verts=[(x+dx,y,z) for dx in (-.055,.055) for y,z in profile];faces=[tuple(range(n-1,-1,-1)),tuple(n+k for k in range(n))]+[(k,(k+1)%n,n+(k+1)%n,n+k) for k in range(n)]
 buttress=mesh('V05 rear cast buttress '+str(sign),verts,faces,'cast-frame',bevel=.009);joint(buttress,back,'rear buttress tied into upper casting');joint(buttress,'Octagonal sole casting','rear buttress foot carried by sole')
 for z,y in ((.28,.805),(.65,.755),(1.02,.705)):
  ridge=box('V05 rear buttress cross rib '+str((sign,z)),(x,y,z),(.142,.050,.036),'edge-trim',bevel=.005);joint(ridge,buttress,'transverse rib retained on buttress web')
 cap=box('V05 upper rear inspection seal '+str(sign),(sign*.48,.668,1.315),(.21,.026,.24),'cable-jacket',bevel=.013);joint(cap,back,'inspection cap gasket seats on upper casting')
 plate=box('V05 upper rear inspection panel '+str(sign),(sign*.48,.688,1.315),(.18,.025,.21),'console-panels',bevel=.014);joint(plate,cap,'small inspection panel retained on gasket')
 for z in (1.247,1.383):
  b=bolt('V05 upper panel captive stud '+str((sign,z)),(sign*.48,.707,z),(0,1,0),.012,.022);joint(b,plate,'inspection stud seated on cap')
 # Separate service plates break the exposed sole margins beside the grate.
 plate=box('V05 sole service hatch '+str(sign),(sign*.58,-.55,.145),(.235,.245,.024),'console-panels',bevel=.016);joint(plate,'Octagonal sole casting','sole service hatch seated over equipment channel')
 for dx in (-.083,.083):
  for y in (-.63,-.47):
   b=bolt('V05 sole hatch retained stud '+str((sign,dx,y)),(sign*.58+dx,y,.163),(0,0,1),.010,.020);joint(b,plate,'sole service hatch stud anchored on plate')
# Extra panel-to-plinth looms are clipped to the outer faces, clear of the keys.
spec=importlib.util.spec_from_file_location('conclave_v05_pipette',R/'tools/fmpl/pipette/blender_adapter.py');adapter=importlib.util.module_from_spec(spec);sys.modules[spec.name]=adapter;spec.loader.exec_module(adapter)
requests=json.loads((OLD/'pipette-requests.json').read_text());plans=json.loads((OLD/'pipette-plans.json').read_text());additional=[]
source=(R/'tools/art/conclave/refine_v04_services.py').read_text();tree=ast.parse(source)
for name in ('smooth','service'):
 node=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name==name);text=ast.get_source_segment(source,node).replace('conclave-v04-','conclave-v05-');exec(compile(text,str(R/'tools/art/conclave/refine_v04_services.py'),'exec'))
for sign,index in [(-1,1),(1,2)]:
 cx,cy,yaw,w=stations[index];M=Matrix.Translation((cx,cy,0))@Matrix.Rotation(yaw,4,'Z')
 for k,colour in enumerate(('signal-red','signal-amber')):
  a=list(M@Vector((sign*(w*.34+k*.035),-.20,.55)));b=list(M@Vector((sign*(w*.34+k*.035),-.12,.23)))
  shoe=box('V05 pedestal loom gland '+str((sign,k)),(sign*(w*.34+k*.035),-.203,.55),(.055,.045,.06),'cast-frame',M,.006);joint(shoe,'Console %d | grounded pedestal'%index,'loom gland retained outside service lid frame')
  foot=box('V05 pedestal loom foot '+str((sign,k)),(sign*(w*.34+k*.035),-.12,.22),(.065,.06,.065),'cast-frame',M,.007);joint(foot,'Console %d | grounded pedestal'%index,'return gland mounted on lower pedestal cheek')
  points=[a,list(M@Vector((sign*(w*.46+k*.027),-.24,.46))),list(M@Vector((sign*(w*.47+k*.025),-.23,.30))),b]
  service('pedestal-panel-return-'+str((sign,k)),points,shoe.name,foot.name,'wire_bundle',.022,colour)
  p=M@Vector((sign*w*.33,-.185,.375));q=M@Vector((sign*(w*.46+k*.027),-.235,.375));stand=cylinder('V05 pedestal clip supported standoff '+str((sign,k)),p,q,.012,'control-keys',16);joint(stand,'Console %d | grounded pedestal'%index,'clip standoff root embeds into outer pedestal cheek')
  clip=box('V05 pedestal loom retaining clip '+str((sign,k)),(sign*(w*.46+k*.027),-.235,.375),(.052,.045,.028),'edge-trim',M,.005);joint(clip,stand,'retaining clip seated on actual pedestal standoff')
contacts=[x for x in contacts if x['a'] not in removed and x['b'] not in removed]
for name in ['contract.json','capture-profile.json','orientation-and-skull-preservation.json','support-objects.json','original-prototype.lua','supplied-skull-reuse.json','ATTRIBUTION.txt','surface-manifest.json','arch-and-services.json','arch-seat-and-access-audit.json']:
 shutil.copy2(OLD/name,O/name)
surfaces=json.loads((O/'surface-manifest.json').read_text());surfaces.update(json.loads((O/'panel-surfaces.json').read_text()));(O/'surface-manifest.json').write_text(json.dumps(surfaces,indent=2)+'\n')
arch=json.loads((O/'arch-and-services.json').read_text());arch['v04_module_reference_sha256']=hashlib.sha256((OLD/'arch-and-services.json').read_bytes()).hexdigest();arch['stage']='V05 retained arch module with panel/structural refinement; source/export review candidate';arch['services']['additional_routes'].extend(additional);arch['services']['total_routes']=len(requests);(O/'arch-and-services.json').write_text(json.dumps(arch,indent=2)+'\n')
assert signature('Supplied DGordillo low-poly skull')==skulls,'Supplied skull changed';assert signature('Arch candle')==candles,'Arch candle geometry/placement changed'
(O/'contacts.json').write_text(json.dumps(contacts,indent=2)+'\n');(O/'pipette-requests.json').write_text(json.dumps(requests,indent=2)+'\n');(O/'pipette-plans.json').write_text(json.dumps(plans,indent=2)+'\n')
(O/'panel-refinement.json').write_text(json.dumps(dict(previous_source_sha256=hashlib.sha256((OLD/'conclave-center-v04.blend').read_bytes()).hexdigest(),stage='source/export review candidate; not integrated',actual_boolean_apertures=cuts,extra_services=additional,total_service_routes=len(requests),skulls_unchanged=skulls,arch_candles_unchanged=candles,exposed_surface_plan={'monitor roofs':'gasketed removable plates, raised longitudinal ribs, hinges and captive studs','monitor sides':'actual through-slots, retained vent frames and louvers','monitor rear':'open grille frames, deep slats and internal passive shields','pedestals':'stepped hatch surround, vent bank, hatch ribs, gland shoes and shaped pierced buttress webs','rear wall':'true bay opening, stepped perimeter, split service hatches, deep grille, lift handles, upper inspection caps and cast buttresses','sole':'retained service hatches beside the open central grate'}),indent=2)+'\n')
sys.path.insert(0,str(R/'tools/fmpl'));from blender_camera_guard import assert_clean;assert_clean(s,json.loads((O/'capture-profile.json').read_text()),bpy)
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='OPTIX'
if any(d.use for d in prefs.devices):s.cycles.device='GPU'
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(O/'conclave-center-v05.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in s.objects:
 if obj.type=='MESH':obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'conclave-center-v05.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
s.render.filepath=str(O/'source-front.png');bpy.ops.render.render(write_still=True);print('CONCLAVE_PANEL_BUTTRESS_REFINEMENT_SAVED',len(cuts),len(contacts),len(requests),flush=True)
