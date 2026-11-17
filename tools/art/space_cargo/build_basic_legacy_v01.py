"""Basic cargo: flush steel/glass deck over sealed below-grade storage wells."""
import bpy,bmesh,json,math,hashlib,sys
from pathlib import Path
from mathutils import Vector,Matrix
R=Path(__file__).resolve().parents[3];B=R/'art/source-to-3d/space-cargo-inventories/v01';O=B/'basic';T=B/'textures';C=R/'art/source-to-3d/martian-stone-cache/v01'
bpy.ops.wm.open_mainfile(filepath=str(C/'martian-stone-cache-v01.blend'));s=bpy.context.scene
for ob in list(s.objects):
 if ob.type in ('MESH','EMPTY') and not ob.name.startswith('Cache centered emblem |'):bpy.data.objects.remove(ob,do_unlink=True)
root=bpy.data.objects.new('Basic Cargo | grade origin',None);s.collection.objects.link(root);col=bpy.data.collections.new('BASIC CARGO | Physical deck and recessed stock');s.collection.children.link(col);mats={};contacts=[];stock=[]
for role in ('deck-steel','cargo-green','aged-brass','well-liner','timber','barrel-red','tool-steel','glass'):
 mat=bpy.data.materials.new('Basic Cargo | '+role);mat.use_nodes=True;nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF')
 for kind in ('albedo','orm','normal'):
  n=nt.nodes.new('ShaderNodeTexImage');n.name='Cargo '+kind;n.image=bpy.data.images.load(str(T/(role+'-'+kind+'.png')))
  if kind=='albedo':nt.links.new(n.outputs['Color'],bs.inputs['Base Color'])
  else:
   n.image.colorspace_settings.name='Non-Color'
   if kind=='orm':
    sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(n.outputs['Color'],sep.inputs[0]);nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
   else:
    normal=nt.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.04 if role=='glass' else .25;nt.links.new(n.outputs['Color'],normal.inputs['Color']);nt.links.new(normal.outputs[0],bs.inputs['Normal'])
 if role=='glass':
  bs.inputs['Transmission Weight'].default_value=.90;bs.inputs['Alpha'].default_value=.22;bs.inputs['IOR'].default_value=1.45;bs.inputs['Specular IOR Level'].default_value=.20;mat.surface_render_method='DITHERED'
 mats[role]=mat
def finish(ob,name,role,bevel=.004,below=False):
 ob.name=name;ob.parent=root
 for collection in list(ob.users_collection):collection.objects.unlink(ob)
 col.objects.link(ob);ob.data.materials.clear();ob.data.materials.append(mats[role]);bpy.context.view_layer.objects.active=ob
 if bevel:
  mod=ob.modifiers.new('Eased panel and crate edges','BEVEL');mod.width=bevel;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
 if not ob.data.uv_layers:ob.data.uv_layers.new(name='Cargo physical UV')
 bpy.context.view_layer.update()
 for poly in ob.data.polygons:
  axis=max(range(3),key=lambda j:abs(poly.normal[j]));axes=[j for j in range(3) if j!=axis]
  for li in poly.loop_indices:
   p=ob.matrix_world@ob.data.vertices[ob.data.loops[li].vertex_index].co;ob.data.uv_layers.active.data[li].uv=(p[axes[0]]*.65+.5,p[axes[1]]*.65+.5)
 ob['below_grade_geometry']=below
 return ob
def box(name,p,size,role='deck-steel',bevel=.004,below=False):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);ob=bpy.context.object;ob.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(ob,name,role,bevel,below)
def cylinder(name,p,r,depth,role='aged-brass',axis='Z',below=False,vertices=24):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=p);ob=bpy.context.object
 if axis=='Y':ob.rotation_euler.x=math.pi/2
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);return finish(ob,name,role,.001,below)
def joint(a,b,why):contacts.append(dict(a=a.name if hasattr(a,'name') else a,b=b.name if hasattr(b,'name') else b,why=why))
def annulus(name,p,inner,outer,depth,role):
 verts=[];faces=[];n=48
 for zz,rr in [(-depth/2,outer),(depth/2,outer),(-depth/2,inner),(depth/2,inner)]:
  verts.extend([(p[0]+rr*math.cos(j*2*math.pi/n),p[1]+rr*math.sin(j*2*math.pi/n),p[2]+zz) for j in range(n)])
 for j in range(n):
  k=(j+1)%n
  faces.extend([(j,k,n+k,n+j),(2*n+j,3*n+j,3*n+k,2*n+k),(n+j,n+k,3*n+k,3*n+j),(j,2*n+j,2*n+k,k)])
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();ob=bpy.data.objects.new(name,me);s.collection.objects.link(ob);return finish(ob,name,role,.001,True)

apertures=[dict(id='pane-%d'%i,xmin=x-.81,xmax=x+.81,ymin=-.90,ymax=.90) for i,x in enumerate((-1.74,0,1.74))]
manifest=dict(schema='fmpl.below-grade-aperture.v1',grade_z=0,model_bounds=[[-2.95,-1.25,-1.02],[2.95,1.25,.27]],bearing_objects=[],apertures=apertures,environment_half_extent=40,mask_edge_allowance_pixels=1,scope='Below-grade objects may draw only through glass apertures; above-grade details can project normally. Render-only holdouts excluded from GLB; manifest required for independent render.')
for label,y in [('front',-1.07),('rear',1.07)]:
 beam=box('Cargo | '+label+' grade-bearing deck rail',(0,y,.050),(5.88,.34,.100));manifest['bearing_objects'].append(beam.name)
for label,x in [('left',-2.745),('right',2.745)]:
 beam=box('Cargo | '+label+' grade-bearing end rail',(x,0,.05),(.39,1.80,.100));manifest['bearing_objects'].append(beam.name);joint(beam,'Cargo | front grade-bearing deck rail','end rail lap joins bearing frame')
for i,x in enumerate((-.87,.87)):
 beam=box('Cargo | pane mullion %d'%i,(x,0,.050),(.12,1.80,.100));manifest['bearing_objects'].append(beam.name);joint(beam,'Cargo | front grade-bearing deck rail','mullion joins front/rear bearing frame')
floor=box('Cargo | sealed suspended well floor',(0,0,-.975),(5.30,1.96,.090),'well-liner',below=True)
for label,y in [('front',-.94),('rear',.94)]:
 wall=box('Cargo | '+label+' opaque well baffle',(0,y,-.475),(5.30,.08,.950),'well-liner',below=True);joint(wall,floor,'full-depth baffle joins sealed well floor');joint(wall,'Cargo | '+label+' grade-bearing deck rail','well suspension walls enter bearing flange')
for i,x in enumerate((-2.60,-.87,.87,2.60)):
 wall=box('Cargo | opaque compartment wall %d'%i,(x,0,-.475),(.10 if abs(x)>2 else .12,1.96,.950),'well-liner',below=True);joint(wall,floor,'compartment wall supports well floor and closes under-deck sides')
# Wall-mounted Warren trusses transfer suspended-well load into bearing rim.
# Every brace has a continuous chord and a welded/bolted gusset receiver.
def brace(name,a,b):
 a=Vector(a);b=Vector(b);ob=box(name,(a+b)/2,(.055,.055,(b-a).length),'deck-steel',.003,True);ob.rotation_mode='QUATERNION';ob.rotation_quaternion=(b-a).to_track_quat('Z','Y');return ob
for side in (-1,1):
 y=side*.87;host='Cargo | '+('front' if side<0 else 'rear')+' opaque well baffle'
 for bay,cx in enumerate((-1.74,0,1.74)):
  chords=[]
  for label,z in [('lower',-.82),('upper',-.15)]:
   chord=box('Cargo | wall truss %d %d %s chord'%(side,bay,label),(cx,y,z),(1.60,.085,.070),'deck-steel',.004,True);joint(chord,host,'continuous truss chord seated against opaque well wall');chords.append(chord)
  nodes=[]
  for n in range(4):
   x=cx-.75+n*.50;z=-.82 if n%2==0 else -.15
   gusset=box('Cargo | wall truss %d %d gusset %d'%(side,bay,n),(x,y-side*.025,z),(.15,.035,.13),'aged-brass',.006,True);joint(gusset,chords[n%2],'gusset overlaps continuous structural chord');nodes.append((x,y-side*.030,z))
  for n in range(3):
   ob=brace('Cargo | wall truss %d %d diagonal %d'%(side,bay,n),nodes[n],nodes[n+1]);joint(ob,chords[n%2],'diagonal bears on lower/upper chord through fitted gusset');joint(ob,chords[(n+1)%2],'opposite diagonal endpoint bears on structural chord')
# Cross-trusses stiffen both ends and compartment partitions; no bar crosses a viewport.
for n,x in enumerate((-2.54,-.80,.80,2.54)):
 host='Cargo | opaque compartment wall %d'%n
 for label,z in [('lower',-.82),('upper',-.15)]:
  chord=box('Cargo | end truss %d %s chord'%(n,label),(x,0,z),(.11,1.70,.07),'deck-steel',.004,True);joint(chord,host,'end/partition chord seated against wall')
 for k in range(3):
  a=(x,-.78+k*.52,-.82 if k%2==0 else -.15);b=(x,-.78+(k+1)*.52,-.82 if (k+1)%2==0 else -.15)
  ob=brace('Cargo | end truss %d diagonal %d'%(n,k),a,b)
  for label in ('lower','upper'):joint(ob,'Cargo | end truss %d %s chord'%(n,label),'cross-brace terminates in chord')
for i,pane in enumerate(apertures):
 cx=(pane['xmin']+pane['xmax'])/2;glass=box('Cargo | green transmitting viewport %d'%i,(cx,0,-.020),(1.618,1.798,.030),'glass',.001);glass['cargo_glass']=True
 # A real continuous receiving ledge under the glass, not floating pane corners.
 for j,(p,size) in enumerate([((cx,-.89,-.04),(1.62,.045,.030)),((cx,.89,-.04),(1.62,.045,.030)),((cx-.80,0,-.04),(.045,1.80,.030)),((cx+.80,0,-.04),(.045,1.80,.030))]):
  seat=box('Cargo | viewport %d receiving ledge %d'%(i,j),p,size,below=True);joint(seat,glass,'glazing edge rests on receiving ledge');joint(seat,('Cargo | '+('front' if j==0 else 'rear')+' opaque well baffle') if j<2 else 'Cargo | opaque compartment wall %d'%(i+(j==3)),'glazing ledge retained by adjoining well wall')
 for k,(dx,dy,w,d,h) in enumerate([(-.30,.15,.80,1.18,.55),(.45,.30,.50,.74,.38)] if i==0 else []):
  z=-.930+h/2;case=box('Cargo | sealed stock case %d %d'%(i,k),(cx+dx,dy,z),(w,d,h),'timber' if k==0 else 'cargo-green',.012,True);joint(case,floor,'cargo case base bears on suspended well floor');stock.append(case.name)
  lid=box('Cargo | stock case lid %d %d'%(i,k),(cx+dx,dy,z+h/2+.009),(w+.012,d+.012,.025),'timber' if k==0 else 'cargo-green',.006,True);joint(lid,case,'sealed cargo lid directly seats on case')
  for sx in (-1,1):
   strap=box('Cargo | case hoop %d %d %d'%(i,k,sx),(cx+dx+sx*w*.30,dy,z),(.045,d+.026,h+.024),'deck-steel',.003,True);joint(strap,case,'iron hoop fitted around cargo case')
  for sy in (-1,1):
   edge=box('Cargo | case lid band %d %d %d'%(i,k,sy),(cx+dx,dy+sy*d*.43,z+h/2+.025),(w+.024,.040,.023),'aged-brass',.002,True);joint(edge,lid,'lid band seated on sealed case lid')
  latch=box('Cargo | case latch %d %d'%(i,k),(cx+dx,dy-d/2-.025,z+h*.15),(.11,.055,.13),'aged-brass',.004,True);joint(latch,case,'latch housing mounted on case face')
  if k==0:
   # Separate dressed timber planks and frame rails make this a wooden crate.
   for n in range(5):
    plank=box('Cargo | wooden crate lid plank %d'%n,(cx+dx,dy-d*.4+n*d*.2,z+h/2+.030),(w-.055,d*.185,.028),'timber',.003,True);joint(plank,lid,'plank seats directly on crate lid')
   for side in (-1,1):
    for n in range(4):
     plank=box('Cargo | wooden crate face plank %d %d'%(side,n),(cx+dx,dy+side*(d/2+.009),z-h*.375+n*h*.25),(w-.04,.026,h*.235),'timber',.003,True);joint(plank,case,'wooden side plank fixed to crate body')
 if i==1:
  # Upright sealed drums with real chimes, rolled hoops and off-center bungs.
  for n,(dx,dy,r,h) in enumerate([(-.36,.30,.29,.68),(.35,.34,.28,.59),(0,-.36,.255,.50)]):
   z=-.93+h/2;drum=cylinder('Cargo | sealed barrel %d'%n,(cx+dx,dy,z),r,h,'barrel-red',below=True,vertices=48);joint(drum,floor,'barrel base bears on well floor');stock.append(drum.name)
   for k,zz in enumerate((-.93+.018,-.93+h*.28,-.93+h*.72,-.93+h-.018)):
    ring=annulus('Cargo | barrel rolled hoop %d %d'%(n,k),(cx+dx,dy,zz),r-.012,r+.014,.035,'deck-steel');joint(ring,drum,'rolled hoop fits barrel shell')
   lid=cylinder('Cargo | barrel lid %d'%n,(cx+dx,dy,-.93+h-.008),r-.012,.024,'barrel-red',below=True,vertices=48);joint(lid,drum,'sealed lid fits inside barrel top chime')
   bung=cylinder('Cargo | barrel bung %d'%n,(cx+dx+r*.45,dy,-.93+h+.010),.045,.022,'aged-brass',below=True,vertices=8);joint(bung,lid,'bung threaded into barrel lid')
 if i==2:
  # Supported removable tool tray: tools sit above the tray floor, below the pane.
  tray=box('Cargo | tools tray base',(cx,.25,-.515),(1.35,1.05,.055),'deck-steel',.008,True);stock.append(tray.name)
  for side in (-1,1):
   runner=box('Cargo | tools tray load runner %d'%side,(cx+side*.50,.25,-.73625),(.15,.94,.3875),'well-liner',.005,True);joint(runner,floor,'tool tray runner bears on well floor');joint(runner,tray,'tray floor rests on load runner')
  for side in (-1,1):
   wall=box('Cargo | tools tray side %d'%side,(cx+side*.66,.25,-.455),(.035,1.05,.105),'deck-steel',.003,True);joint(wall,tray,'tray side folded up from base')
   wall=box('Cargo | tools tray end %d'%side,(cx,.25+side*.51,-.455),(1.35,.035,.105),'deck-steel',.003,True);joint(wall,tray,'tray end closes retaining lip')
  # Two open-jaw spanners with deliberate open mouths and joined forged necks.
  for n,(x,y,length) in enumerate([(cx-.30,.30,.65),(cx+.16,.34,.51)]):
   z=-.46;shaft=box('Cargo | tool spanner shaft %d'%n,(x,y,z),(.075,length,.045),'tool-steel',.008,True);joint(shaft,tray,'spanner laid on tray floor');stock.append(shaft.name)
   for end in (-1,1):
    yy=y+end*length*.5
    neck=box('Cargo | tool spanner neck %d %d'%(n,end),(x,yy,z),(.22,.10,.055),'tool-steel',.007,True);joint(neck,shaft,'forged wrench neck continuous with handle')
    for side in (-1,1):
     jaw=box('Cargo | tool open spanner jaw %d %d %d'%(n,end,side),(x+side*.092,yy+end*.075,z),(.052,.115,.055),'tool-steel',.005,True);joint(jaw,neck,'open wrench jaw continuous with forged head')
  handle=box('Cargo | tool hammer timber handle',(cx+.45,.22,-.45),(.060,.69,.075),'timber',.012,True);joint(handle,tray,'hammer handle rests in tool tray');stock.append(handle.name)
  head=box('Cargo | tool hammer forged head',(cx+.45,.49,-.42),(.29,.13,.13),'tool-steel',.012,True);joint(head,handle,'hammer head receives handle through central eye')
  for n in range(2):
   h=box('Cargo | tool driver handle %d'%n,(cx-.37+n*.30,-.08,-.455),(.12,.19,.065),'barrel-red',.013,True);joint(h,tray,'driver handle rests in tray');stock.append(h.name)
   shaft=box('Cargo | tool driver steel shank %d'%n,(cx-.37+n*.30,.07,-.46),(.025,.18,.030),'tool-steel',.002,True);joint(shaft,h,'steel shank enters driver handle')
# Segmented flush surface detail and fasteners remain above the platform plane.
for y in (-1.07,1.07):
 for x in (-2.76,-2.15,-1.54,-.93,-.32,.32,.93,1.54,2.15,2.76):
  rivet=cylinder('Cargo | deck captive fastener %.2f %.2f'%(x,y),(x,y,.107),.024,.024,vertices=8);joint(rivet,'Cargo | '+('front' if y<0 else 'rear')+' grade-bearing deck rail','fastener captured in deck rail')
for i,(x,y) in enumerate([(-2.77,-1.08),(2.77,-1.08),(-2.77,1.08),(2.77,1.08)]):
 housing=box('Cargo | corner locking housing %d'%i,(x,y,.135),(.22,.22,.14),'deck-steel',.012);joint(housing,'Cargo | '+('front' if y<0 else 'rear')+' grade-bearing deck rail','small above-deck lock mounted to bearing frame')
 pin=cylinder('Cargo | corner latch pivot %d'%i,(x,y,.215),.043,.035,'aged-brass');joint(pin,housing,'latch pivot seated in corner housing')
 handle=box('Cargo | parked corner latch %d'%i,(x-.055,y,.238),(.16,.045,.030),'deck-steel');joint(handle,pin,'static latch handle keyed to pivot, no native opening animation')
terminals={}
for color,x in [('red',.45),('green',.59)]:
 seat=cylinder('Cargo | '+color+' circuit receiving shoulder',(x,-1.075,.1175),.035,.035,'deck-steel');joint(seat,'Cargo | front grade-bearing deck rail','receiving shoulder mounted on flush front deck strip')
 pin=cylinder('Cargo | '+color+' circuit contact',(x,-1.075,.155),.016,.055,'aged-brass');joint(pin,seat,'circuit contact captured by receiving shoulder');terminals[color]=[x,-1.075,.1825]
led=cylinder('Cargo | native status LED bezel',(.73,-1.075,.1175),.031,.035,'aged-brass');joint(led,'Cargo | front grade-bearing deck rail','native circuit-status LED seated on surface strip')
# Reuse the actual supplied skull/bionic relief on the centered deck strip.
emblems=[ob for ob in s.objects if ob.name.startswith('Cache centered emblem |')]
for ob in emblems:
 matrix=ob.matrix_world.copy()
 for v in ob.data.vertices:
  p=matrix@v.co;face=-math.sqrt(max(.1,.945**2-p.x**2));depth=face-p.y;v.co=(p.x*.66,-1.075+(p.z-.47)*.66,.101+depth*.66)
 ob.matrix_world=Matrix.Identity(4);ob.parent=root;ob['below_grade_geometry']=False
 # Preserve source contacts among relief parts; deck hosts the assembly.
 if 'twenty tooth cog surround' in ob.name:joint(ob,'Cargo | front grade-bearing deck rail','shared Martian relief centered and seated on front deck strip')
sys.path.insert(0,str(R/'tools/fmpl'));from below_grade_occlusion import add_grade_holdouts;add_grade_holdouts(s,bpy,manifest,parent=root)
from blender_camera_guard import install_canonical_camera;install_canonical_camera(s,json.loads((O/'capture-profile.json').read_text()),bpy)
for ob in s.objects:
 if ob.type=='LIGHT':
  ob.data.energy*=1.6
  if ob.name=='rim':ob.location=(0,-5,6);ob.rotation_euler=(Vector((0,0,-.3))-ob.location).to_track_quat('-Z','Y').to_euler()
for i,cx in enumerate((-1.74,0,1.74)):
 data=bpy.data.lights.new('Studio only | well bounce fill %d'%i,'POINT');data.energy=5;data.shadow_soft_size=.20;data.specular_factor=.10;ob=bpy.data.objects.new(data.name,data);s.collection.objects.link(ob);ob.location=(cx-.35,-.30,-.10);ob.visible_camera=False;ob.visible_glossy=False;ob.visible_transmission=False;ob['fmpl_studio_only']=True
s.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.70;s.cycles.samples=96;s.cycles.max_bounces=12;s.cycles.transmission_bounces=12;s.cycles.transparent_max_bounces=12;s.render.film_transparent=True
(O/'occlusion.json').write_text(json.dumps(manifest,indent=2)+'\n');(O/'contacts.json').write_text(json.dumps(contacts,indent=2)+'\n');(O/'construction.json').write_text(json.dumps(dict(grade=0,underground_floor=-1.02,glass_top=-.005,cargo_stock=stock,cargo_variation=["Slatted timber crate and sealed metal case","Three rolled-hoop red barrels with bungs","Supported tool tray with open-jaw spanners, hammer and screwdrivers"],terminals=terminals,status_led=[.73,-1.075,.135],wall_structure='Continuous upper/lower chords with fitted gussets and alternating diagonal braces along long walls, ends and partitions; no brace crosses a viewport',static='Passive cargo compartment; Mixed crate/barrel/tool arrangement identifies cargo, not live inventory count; no loading mechanism or powered animation invented',occlusion='Opaque sealed well/baffles plus render-only grade holdouts admit below-grade drawing only through the three green panes',native_contract='Existing20-slot platform-only container; four native rotations requested by owner, unchanged recipe/research/collision/selection and standard inserters',source_reuse='Supplied original skull/Bionic source assembly reused from authored cache master; no original editable cargo source found',advanced='Contract read; distinct larger machinery/viewport model waits until Basic cutaway standard is reviewed'),indent=2)+'\n')
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(O/'basic-space-cargo-v01.blend'),compress=True);bpy.ops.object.select_all(action='DESELECT')
for ob in s.objects:
 if ob.type=='MESH' and not ob.get('fmpl_render_only'):ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'basic-space-cargo-v01.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False,export_extras=True)
s.render.filepath=str(O/'source-front.png');bpy.ops.render.render(write_still=True);print('BASIC_CARGO_RECESSED_SOURCE_EXPORT_SAVED')
