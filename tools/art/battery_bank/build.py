"""Eight supported cells, guarded busbars and fitted Pipette power leads."""
import bpy,json,math,sys,hashlib,importlib.util
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/primitive-battery-bank/v01';C=R/'art/source-to-3d/martian-stone-cache/v01';T=O/'textures'
bpy.ops.wm.open_mainfile(filepath=str(C/'martian-stone-cache-v01.blend'));s=bpy.context.scene
for ob in list(bpy.data.collections['CACHE VARIANT | Domed hide cover'].objects):bpy.data.objects.remove(ob,do_unlink=True)
for ob in list(s.objects):
 if ob.name.startswith('Native '):bpy.data.objects.remove(ob,do_unlink=True)
root=bpy.data.objects['Martian Stone Cache | ground origin'];root.name='Primitive Battery Bank | ground origin';contacts=[r for r in json.loads((C/'contacts.json').read_text()) if r['a'] in bpy.data.objects and r['b'] in bpy.data.objects];mats={};paths=[]
for role in ('cell-ceramic','oxide-iron','aged-copper','insulator','red-cable','black-cable'):
 mat=bpy.data.materials.new('Primitive Bank | '+role);mat.use_nodes=True;nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF')
 for kind in ('albedo','orm','normal'):
  tex=nt.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(T/(role+'-'+kind+'.png')))
  if kind=='albedo':nt.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
  else:
   tex.image.colorspace_settings.name='Non-Color'
   if kind=='orm':
    sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(tex.outputs['Color'],sep.inputs[0]);nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
   else:
    normal=nt.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.25;nt.links.new(tex.outputs['Color'],normal.inputs['Color']);nt.links.new(normal.outputs[0],bs.inputs['Normal'])
 mats[role]=mat
col=bpy.data.collections.new('BATTERY BANK | Cells, guard and terminals');s.collection.children.link(col)
def uv(ob,role):
 if not ob.data.uv_layers:ob.data.uv_layers.new(name='Battery physical surface UV')
 for face in ob.data.polygons:
  axis=max(range(3),key=lambda j:abs(face.normal[j]));axes=[j for j in range(3) if j!=axis]
  for li in face.loop_indices:
   p=ob.matrix_world@ob.data.vertices[ob.data.loops[li].vertex_index].co
   value=(p[axes[0]]*1.8+.5,p.z/.75) if role=='cell-ceramic' and axis!=2 else (p[axes[0]]*1.8+.5,p[axes[1]]*1.8+.5);ob.data.uv_layers.active.data[li].uv=value
def finish(ob,name,role,bevel=.003):
 ob.name=name;ob.parent=root
 for c in list(ob.users_collection):c.objects.unlink(ob)
 col.objects.link(ob);ob.data.materials.clear();ob.data.materials.append(mats[role]);bpy.context.view_layer.objects.active=ob
 if bevel:
  m=ob.modifiers.new('Eased manufactured edges','BEVEL');m.width=bevel;m.segments=2;bpy.ops.object.modifier_apply(modifier=m.name)
 uv(ob,role);return ob
def box(name,p,size,role='oxide-iron',bevel=.004):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);ob=bpy.context.object;ob.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(ob,name,role,bevel)
def cyl(name,p,radius,depth,role='aged-copper',axis='Z',vertices=24):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=p);ob=bpy.context.object
 if axis=='Y':ob.rotation_euler.x=math.pi/2
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);return finish(ob,name,role,.0015)
def joint(a,b,why):contacts.append(dict(a=a.name if hasattr(a,'name') else a,b=b.name if hasattr(b,'name') else b,why=why))
floor='Compacted earth cavity floor'
for i,(x,y) in enumerate([(-.48,-.48),(.48,-.48),(-.48,.48),(.48,.48)]):
 foot=box('Bank | grounded tray foot %d'%i,(x,y,.21),(.11,.11,.37));joint(foot,floor,'foot bears on actual cavity floor')
tray=box('Bank | continuous iron cell tray',(0,0,.408),(1.04,1.16,.055));joint(tray,'Bank | grounded tray foot 0','tray directly bears on its four legs')
for x in (-.52,.52):
 rail=box('Bank | raised tray retaining rail %.2f'%x,(x,0,.47),(.040,1.16,.10));joint(rail,tray,'raised tray lip captures cell feet')
cells=[];posts={}
for column,x in enumerate((-.28,.28)):
 for row,y in enumerate((-.42,-.14,.14,.42)):
  body=box('Bank | ceramic cell %d %d'%(column,row),(x,y,.556),(.35,.22,.245),'cell-ceramic',.014);joint(body,tray,'ceramic cell foot rests on iron tray');cells.append(body)
  lid=box('Bank | seated cell lid %d %d'%(column,row),(x,y,.685),(.36,.23,.030),'oxide-iron');joint(lid,body,'closed lid seats on cell rim')
  for side,dy in [('positive',-.065),('negative',.065)]:
   washer=cyl('Bank | ceramic terminal shoulder %d %d %s'%(column,row,side),(x,y+dy,.706),.034,.022,'insulator');joint(washer,lid,'terminal insulator shoulder receives post')
   post=cyl('Bank | terminal post %d %d %s'%(column,row,side),(x,y+dy,.728),.017,.046);joint(post,washer,'post passes through insulating shoulder');posts[column,row,side]=post
  for sx in (-1,1):
   clip=box('Bank | cell retaining strap %d %d %d'%(column,row,sx),(x+sx*.145,y,.559),(.018,.225,.24));joint(clip,body,'separate retaining strap fits ceramic cell sides');joint(clip,tray,'retainer bottom bears on tray')
for column,x in enumerate((-.28,.28)):
 for row in range(3):
  y0=(-.42,-.14,.14,.42)[row]+.065;y1=(-.42,-.14,.14,.42)[row+1]-.065
  bar=box('Bank | series busbar %d %d'%(column,row),(x,(y0+y1)/2,.743),(.044,y1-y0+.035,.016),'aged-copper',.002);joint(bar,posts[column,row,'negative'],'busbar overlaps negative stud');joint(bar,posts[column,row+1,'positive'],'next positive stud receives busbar')
for side,y,row in [('positive',-.485,0),('negative',.485,3)]:
 bar=box('Bank | parallel %s collector'%side,(0,y,.743),(.61,.043,.018),'aged-copper',.002)
 for column in range(2):joint(bar,posts[column,row,side],'collector directly overlaps cell string post')
for key,post in posts.items():
 cap=cyl('Bank | captive terminal nut %d %d %s'%key,(post.location.x,post.location.y,.757),.023,.018,vertices=6);joint(cap,post,'nut captures cell busbar to threaded post')
# A removable guard stands clear of busbars and cell hardware.
for i,(x,y) in enumerate([(-.53,-.43),(.53,-.43),(-.53,.43),(.53,.43)]):
 support=box('Bank | guard support %d'%i,(x,y,.610),(.065,.065,.35));joint(support,tray,'guard support rooted in tray edge')
for i,x in enumerate((-.53,.53)):
 rail=box('Bank | guard longitudinal carrier %d'%i,(x,0,.797),(.045,1.16,.035));joint(rail,'Bank | guard support %d'%i,'longitudinal carrier bears on front upright');joint(rail,'Bank | guard support %d'%(i+2),'longitudinal carrier bears on rear upright')
for y in (-.56,.56):
 rail=box('Bank | guard cross rail %.2f'%y,(0,y,.798),(1.16,.040,.040));joint(rail,'Bank | guard longitudinal carrier 0','cross rail ends seated on longitudinal carriers');joint(rail,'Bank | guard longitudinal carrier 1','cross rail ends seated on longitudinal carriers')
for x in (-.56,-.28,0,.28,.56):
 rail=box('Bank | removable guard bar %.2f'%x,(x,0,.823),(.022,1.15,.025));joint(rail,'Bank | guard cross rail -0.56','grate bar seated on front cross rail');joint(rail,'Bank | guard cross rail 0.56','grate bar seated on rear cross rail')
# Grounded service pedestal accommodates the *original* accumulator circuit
# points. Their low front position is not silently replaced with chest points.
pedestal=box('Bank | grounded isolated terminal pedestal',(.85,-.88,.230),(.26,.23,.46),'oxide-iron',.012)
feet=box('Bank | terminal pedestal footing',(.85,-.88,.025),(.28,.24,.05));joint(pedestal,feet,'cabinet bears continuously on ground plinth')
for i,z in enumerate((.13,.34)):
 arm=box('Bank | masonry cabinet tie %d'%i,(.79,-.65,z),(.055,.33,.045));joint(arm,pedestal,'cabinet tie enters rear of grounded enclosure')
 # Select real masonry by nearest surface rather than origin/name order.
 candidates=[]
 for ob in s.objects:
  if ob.name.startswith('Hand-laid'):
   tree=BVHTree.FromPolygons([ob.matrix_world@v.co for v in ob.data.vertices],[list(f.vertices) for f in ob.data.polygons]);q,n,f,d=tree.find_nearest(Vector((.79,-.485,z)));candidates.append((d,ob))
 joint(arm,min(candidates,key=lambda x:x[0])[1],'rear tie embeds into actual nearest masonry course')
terminals=[]
for wire,x,screen_y in [('red',.828125,.625),('green',.890625,.84375)]:
 y=-.997;z=-(screen_y-.20)*math.sqrt(2)-y
 socket=cyl('Bank | native %s insulating receptacle'%wire,(x,-.985,z),.030,.022,'insulator',axis='Y');joint(socket,pedestal,'insulating receptacle seated on cabinet front')
 post=cyl('Bank | native %s circuit mouth'%wire,(x,y+.009,z),.014,.018,'aged-copper',axis='Y');joint(post,socket,'contact pin centered in receiving ceramic');terminals.append(dict(wire=wire,native=[x,screen_y],mouth=[x,y,z],object=post.name))
# Atlas alpha centroids are offset inside the inherited LED images. Seat those
# actual visible centers on cabinet bezels, independently of fixed wire points.
for label,screen_y in [('blue',.725),('red-green',.725+.16875957070440384-.2760876449540326)]:
 z=-(screen_y-.20)*math.sqrt(2)+.997
 bezel=cyl('Bank | seated native %s LED bezel'%label,(.77,-.987,z),.031,.026,'oxide-iron',axis='Y');joint(bezel,pedestal,'native LED bezel mounted in cabinet front with measured atlas centroid alignment')
# Two state lamps only explain supported charge/discharge, never motion.
lamps=[]
for i,(role,color) in enumerate([('charge',(0.08,.65,.18,1)),('discharge',(.85,.25,.025,1))]):
 seat=cyl('Bank | %s lamp socket'%role,(.795+i*.10,-.880,.477),.039,.043,'oxide-iron');joint(seat,pedestal,'lamp bezel mounted on top of service cabinet')
 lens=cyl('Bank | %s lamp lens'%role,(.795+i*.10,-.880,.503),.026,.016,'insulator');joint(lens,seat,'glass lens captured by lamp socket')
 mat=mats['insulator'].copy();mat.name='Bank state | '+role;bs=mat.node_tree.nodes.get('Principled BSDF');mat.node_tree.links.remove(bs.inputs['Base Color'].links[0]);bs.inputs['Base Color'].default_value=tuple(c*.25 if j<3 else c for j,c in enumerate(color));bs.inputs['Emission Color'].default_value=color;bs.inputs['Emission Strength'].default_value=0;lens.data.materials[0]=mat;lamps.append(dict(state=role,object=lens.name,material=mat.name))
# Broad Bezier bends with exact tangent-aligned receiving lugs and glands.
spec=importlib.util.spec_from_file_location('battery_pipette',R/'tools/fmpl/pipette/blender_adapter.py');adapter=importlib.util.module_from_spec(spec);sys.modules[spec.name]=adapter;spec.loader.exec_module(adapter)
def bezier(control,n=48):
 p=[Vector(v) for v in control];return [sum((p[0]*(1-t)**3,p[1]*3*(1-t)**2*t,p[2]*3*(1-t)*t*t,p[3]*t**3),Vector()) for t in [j/(n-1) for j in range(n)]]
routes=[('positive','red-cable',[[ (.12,-.485,.752),(.12,-.485,1.08),(.80,-.82,1.08),(.80,-.82,.474)]]),('negative','black-cable',[[ (.12,.485,.752),(.12,.485,1.02),(.82,.50,.94),(.82,.10,.94)],[(.82,.10,.94),(.82,-.30,.94),(.92,-.82,.88),(.92,-.82,.474)]])]
for side,role,curves in routes:
 points=[]
 for curve in curves:points+=bezier(curve) if not points else bezier(curve)[1:]
 start=points[0];end=points[-1];parent=bpy.data.objects['Bank | parallel %s collector'%side]
 boss=cyl('Bank | %s cable receiving boss'%side,(end.x,end.y,.465),.033,.031,'insulator');joint(boss,pedestal,'gland receiving boss seated in cabinet roof')
 req=dict(id='battery-'+side,family='single_wire',payload='power',material_id=mats[role].name,size=dict(outer_diameter=.021,wall_fraction=0),path=dict(kind='waypoints',points=[list(p) for p in points]),start_socket=dict(id=side+'-bus',xyz=list(start),normal=list((points[1]-start).normalized()),role='source',payloads=['power'],parent_mesh=parent.name),end_socket=dict(id=side+'-cabinet',xyz=list(end),normal=list((points[-2]-end).normalized()),role='sink',payloads=['power'],parent_mesh=boss.name),fittings=dict(start='lug',end='cable_gland'),supports=dict(binding='Bolted busbar lug to insulated cabinet gland; broad mechanically plausible static slack'),behavior=dict(static_power_lead=True,no_new_native_power_port=True),keep_outs=[])
 plan=adapter.core.plan(req);collection,objects=adapter.build(plan,mats[role],mats['aged-copper'])
 for ob in objects:ob.parent=root;uv(ob,role)
 # The continuous cable spans both fitted endpoints. Fittings themselves are
 # audited separately at their actual socket, not claimed to touch both ends.
 cable=next(ob for ob in objects if ob.get('pipette_role')=='route') if any(ob.get('pipette_role')=='route' for ob in objects) else objects[0]
 paths.append(dict(request=req,objects=[ob.name for ob in objects],start_parent=parent.name,end_parent=boss.name))
(O/'contacts.json').write_text(json.dumps(contacts,indent=2)+'\n');(O/'support-objects.json').write_text(json.dumps(['Continuous grounded rubble footing','Compacted earth cavity floor',feet.name],indent=2));(O/'construction.json').write_text(json.dumps(dict(cells=[ob.name for ob in cells],lamps=lamps,terminals=terminals,routes=paths,registration=dict(shift=[0,-.01213203435596423],vertical_offset=.20),native='Original accumulator circuit points/reach/signal unchanged. LED artwork alone is offset onto measured cabinet bezels. No item inventory or fluid socket. Existing electrical pole coverage behavior unchanged.',shared_finish='Provisional revised cache quarry surfaces; owner acceptance not inferred',animation='Supported native state light pulses only; no invented mechanical cycling'),indent=2)+'\n')
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(O/'primitive-battery-bank-v01.blend'),compress=True);bpy.ops.object.select_all(action='DESELECT')
for ob in s.objects:
 if ob.type=='MESH':ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'primitive-battery-bank-v01.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
s.render.filepath=str(O/'source-front.png');bpy.ops.render.render(write_still=True);print('BATTERY_BANK_AUTHORED_SOURCE_EXPORT_SAVED',len(cells))
