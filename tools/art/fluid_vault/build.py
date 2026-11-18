"""Sealed pressure vault, full-size open ports, supported pressure tap and hatch."""
import bpy,bmesh,json,math,sys,hashlib,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/pressurized-fluid-vault/v01';I=R/'art/source-to-3d/item-vault/v01';T=O/'textures';contract=json.loads((O/'contract.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(I/'item-vault-v01.blend'));s=bpy.context.scene;root=bpy.data.objects['Item Vault | ground origin'];root.name='Pressurized Fluid Vault | ground origin';contacts=[r for r in json.loads((I/'contacts.json').read_text()) if not r['a'].startswith('Native ') and not r['b'].startswith('Native ')]
for ob in s.objects:
 if ob.name.startswith('Vault |'):ob.location.z+=.12
for ob in list(s.objects):
 if ob.name.startswith('Native '):bpy.data.objects.remove(ob,do_unlink=True)
col=bpy.data.collections.new('FLUID VAULT | Sealed liner and open fittings');s.collection.children.link(col);mats={k:bpy.data.materials['Item Vault | '+k] for k in ('forged-iron','rubbed-iron','gasket')}
for role in ('pressure-iron','aged-bronze','gauge-ivory'):
 mat=bpy.data.materials.new('Fluid Vault | '+role);mat.use_nodes=True;nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF')
 for kind in ('albedo','orm','normal'):
  tex=nt.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(T/(role+'-'+kind+'.png')))
  if kind=='albedo':nt.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
  else:
   tex.image.colorspace_settings.name='Non-Color'
   if kind=='orm':
    sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(tex.outputs['Color'],sep.inputs[0]);nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
   else:
    norm=nt.nodes.new('ShaderNodeNormalMap');norm.inputs['Strength'].default_value=.25;nt.links.new(tex.outputs['Color'],norm.inputs['Color']);nt.links.new(norm.outputs[0],bs.inputs['Normal'])
 mats[role]=mat
# Reuse the proven editable hardware builders, not another machine's gameplay.
src=(R/'tools/art/item_vault/build.py').read_text();exec(compile(src[src.index('def finish('):src.index("collar=cylinder(")],str(R/'tools/art/item_vault/build.py'),'exec'))
def mesh(name,v,f,role='pressure-iron'):
 me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.update();bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();ob=bpy.data.objects.new(name,me);s.collection.objects.link(ob);return finish(ob,name,role,0)
def hollow(name,a,b,outer,bore,role='aged-bronze',n=64):
 a=Vector(a);b=Vector(b);axis=(b-a).normalized();u=axis.cross(Vector((0,0,1)) if abs(axis.z)<.9 else Vector((0,1,0))).normalized();v=axis.cross(u)
 verts=[p+r*(u*math.cos(math.tau*j/n)+v*math.sin(math.tau*j/n)) for p,r in ((a,outer/2),(a,bore/2),(b,outer/2),(b,bore/2)) for j in range(n)];faces=[]
 for j in range(n):
  k=(j+1)%n;faces.extend(((j,k,n+k,n+j),(2*n+j,3*n+j,3*n+k,2*n+k),(j,2*n+j,2*n+k,k),(n+j,n+k,3*n+k,3*n+j)))
 return mesh(name,verts,faces,role)
# Front pipe occupies the former front badge location. Move the actual supplied
# skull/cog to a centered inset on the pressure hatch instead of obstructing flow.
emblems=[ob for ob in s.objects if ob.name.startswith('Cache centered emblem |')]
for ob in emblems:
 for v in ob.data.vertices:
  p=ob.matrix_world@v.co;radius=.945;face=-math.sqrt(max(.1,radius*radius-p.x*p.x));depth=face-p.y
  v.co=(p.x*.52,(p.z-.47)*.52-.30,.8664+depth*.52)
 ob.matrix_world=Matrix.Identity(4);ob.parent=root
# Preserve hierarchy/contact names but replace their host with the actual hatch.
for rec in contacts:
 if rec['a'].startswith('Cache centered emblem') and rec['b']=='Grounded carved circuit receiving tablet':rec['b']='Vault | rectangular reinforced door leaf';rec['why']='Shared relief remounted on centered front portion of pressure hatch, clear of pipe bore'
# Real liner with sealed bottom. Its sidewall will be bored through with the wall.
liner=ring('Fluid | continuous pressure liner',.610,.655,.105,.824,'pressure-iron',96);joint(liner,'Vault | continuous metal infill panel','raised pressure deck gives full inlet-bore clearance above fluid cavity')
bottom=cylinder('Fluid | sealed dished floor backing',(0,0,.122),.655,.035,'pressure-iron',vertices=96);joint(bottom,liner,'continuous welded floor closes bottom of pressure vessel')
for i,(x,y) in enumerate([(-.42,-.42),(.42,-.42),(-.42,.42),(.42,.42)]):
 foot=box('Fluid | liner ground support %d'%i,(x,y,.070),(.13,.13,.140),'pressure-iron');joint(foot,bottom,'floor supported on actual grounded feet')
# Bore actual masonry, liner and footing where the two native pipes pass. The
# hollow sleeve remains open from the mouth all the way into the empty vessel.
ports=[];cut_stones=set()
for sign,name in [(1,'north'),(-1,'south')]:
 cutter=cylinder('TEMP full bore '+name,(0,sign*1.05,.44),.310,1.28,'gasket',axis='Y',vertices=64)
 candidates=[ob for ob in s.objects if ob.type=='MESH' and ob!=cutter and (ob.name.startswith('Hand-laid') or ob.name in ('Grounded carved circuit receiving tablet',liner.name))]
 for ob in candidates:
  points=[ob.matrix_world@Vector(p) for p in ob.bound_box]
  if min(p.x for p in points)>.315 or max(p.x for p in points)<-.315:continue
  if sign>0 and max(p.y for p in points)<.40:continue
  if sign<0 and min(p.y for p in points)>-.40:continue
  if max(p.z for p in points)<.12 or min(p.z for p in points)>.76:continue
  bpy.context.view_layer.objects.active=ob;cut=ob.modifiers.new('True through-wall pipe aperture','BOOLEAN');cut.operation='DIFFERENCE';cut.object=cutter;bpy.ops.object.modifier_apply(modifier=cut.name)
  if ob.name.startswith('Hand-laid'):cut_stones.add(ob.name)
 bpy.data.objects.remove(cutter,do_unlink=True)
 mouth=Vector((0,sign*1.5,.44));inner=Vector((0,sign*.535,.44));throat=hollow('Fluid | '+name+' continuous open throat',mouth,inner,.60,.56);joint(throat,liner,'hollow sleeve penetrates bored liner and communicates with vessel')
 collar=hollow('Fluid | '+name+' full-size mouth collar',(0,sign*1.4625,.44),(0,sign*1.5375,.44),.84,.56);joint(collar,throat,'collar and throat share one continuous 0.56 bore')
 saddle=box('Fluid | '+name+' grounded pipe saddle',(0,sign*1.15,.125),(.55,.26,.25),'pressure-iron')
 cradle=cylinder('TEMP '+name+' saddle recess',(0,sign*1.15,.44),.3002,.36,'gasket',axis='Y',vertices=64);bpy.context.view_layer.objects.active=saddle;cut=saddle.modifiers.new('Concave load-bearing pipe cradle','BOOLEAN');cut.operation='DIFFERENCE';cut.object=cradle;bpy.ops.object.modifier_apply(modifier=cut.name);bpy.data.objects.remove(cradle,do_unlink=True);joint(saddle,throat,'actual concave saddle supports outer pipe without obstructing bore')
 seal=hollow('Fluid | '+name+' liner sealing collar',(0,sign*.59,.44),(0,sign*.67,.44),.67,.56,'pressure-iron');joint(seal,liner,'sealing collar bridges curved liner to sleeve with an open continuous bore');joint(seal,throat,'continuous sealing annulus overlaps sleeve around bore')
 arch=hollow('Fluid | '+name+' load-bearing wall sleeve',(0,sign*.79,.44),(0,sign*.99,.44),.76,.56,'pressure-iron');joint(arch,'Continuous grounded rubble footing','wall sleeve arch bears into existing foundation and supports bored masonry');joint(arch,throat,'wall sleeve shares continuous open bore with throat')
 for j in range(8):
  a=math.tau*j/8;bolt=cylinder('Fluid | %s flange bolt %d'%(name,j),(.355*math.cos(a),sign*1.54,.44+.355*math.sin(a)),.024,.040,'pressure-iron',axis='Y',vertices=6);joint(bolt,collar,'flange bolts embed in collar annulus clear of open bore')
 ports.append(dict(name=name,source_mouth=list(mouth),normal=[0,sign,0],inner=list(inner),throat=throat.name,collar=collar.name,bore=.56,collar_od=.84,native_position=[0,-sign],adjacent_pipe=[0,-sign*2]))
# Pressure tap is a continuous hollow tube with a supported gauge body, not a
# disconnected ornament. No pressure value or moving needle is invented in-game.
tap=hollow('Fluid | gauge pressure tap',(-.285,.175,.81),(-.285,.175,.985),.060,.030,'aged-bronze',32);joint(tap,'Vault | rectangular reinforced door leaf','pressure tap seats through actual hatch leaf')
drill=cylinder('TEMP pressure tap bore',(-.285,.175,.84),.015,.12,'gasket',vertices=32)
for name in ('Vault | rectangular reinforced door leaf','Vault | rectangular door gasket'):
 ob=bpy.data.objects[name];bpy.context.view_layer.objects.active=ob;cut=ob.modifiers.new('Open pressure sensing tap passage','BOOLEAN');cut.operation='DIFFERENCE';cut.object=drill;bpy.ops.object.modifier_apply(modifier=cut.name)
bpy.data.objects.remove(drill,do_unlink=True)
gauge=cylinder('Fluid | pressure gauge case',(-.285,.175,.998),.125,.055,'aged-bronze',vertices=64);joint(gauge,tap,'case receives continuous pressure tap')
face=cylinder('Fluid | aged pressure dial',(-.285,.175,1.029),.107,.010,'gauge-ivory',vertices=64);joint(face,gauge,'dial captured in gauge rim')
mat=mats['gauge-ivory'].copy();mat.name='Fluid Vault | authored dial';face.data.materials[0]=mat
for n in mat.node_tree.nodes:
 if n.type=='TEX_IMAGE' and n.image.name.startswith('gauge-ivory-albedo'):n.image=bpy.data.images.load(str(T/'pressure-dial-albedo.png'))
for poly in face.data.polygons:
 for li in poly.loop_indices:
  p=face.data.vertices[face.data.loops[li].vertex_index].co;face.data.uv_layers.active.data[li].uv=(p.x/.214+.5,p.y/.214+.5)
needle=box('Fluid | static gauge needle',(-.285+.026,.175+.017,1.037),(.115,.010,.007),'pressure-iron',.001);needle.rotation_euler.z=math.radians(35);joint(needle,face,'static needle seated on gauge face, no native pressure animation claimed')
pin=cylinder('Fluid | gauge needle pivot',(-.285,.175,1.039),.015,.012,'aged-bronze',vertices=16);joint(pin,face,'pivot seated in pressure dial')
# The inherited large-tank drawing anchors are outside this compact enclosure.
# Replace their graphical coordinates with true modeled posts; signal behavior,
# read-temperature controls, wire reach and all fluid gameplay stay unchanged.
plate=box('Fluid | mounted circuit terminal plate',(.67,-.700,.540),(.26,.12,.30),'pressure-iron');joint(plate,'Fluid | circuit plate masonry tie 0','plate bears on two ties mounted into actual neighboring masonry')
terminal_points={}
for label,x,z in [('red',.625,.610),('green',.715,.470)]:
 seat=cylinder('Fluid | '+label+' receiving insulator',(x,-.759,z),.026,.025,'gauge-ivory',axis='Y');joint(seat,plate,'ceramic receiving shoulder seats on circuit mounting plate')
 post=cylinder('Fluid | '+label+' native contact post',(x,-.766,z),.014,.020,'aged-bronze',axis='Y');joint(post,seat,'native wire contact fits ceramic receptacle');terminal_points[label]=[x,-.776,z]
for label,z in [('blue',.500),('red-green',.590)]:
 bezel=cylinder('Fluid | '+label+' status LED bezel',(.585,-.760,z),.025,.025,'aged-bronze',axis='Y');joint(bezel,plate,'native state LED seated in mounting plate')
for i,z in enumerate((.45,.64)):
 brace=box('Fluid | circuit plate masonry tie %d'%i,(.765,-.61,z),(.040,.24,.045),'pressure-iron');joint(brace,plate,'tie reaches rear of terminal plate')
 candidates=[]
 for ob in s.objects:
  if ob.name.startswith('Hand-laid'):
   if not ob.data.polygons:continue
   pts=[ob.matrix_world@v.co for v in ob.data.vertices];tree=__import__('mathutils.bvhtree',fromlist=['BVHTree']).BVHTree.FromPolygons(pts,[list(p.vertices) for p in ob.data.polygons]);q,n,f,d=tree.find_nearest(Vector((.765,-.50,z)))
   if d is not None:candidates.append((d,ob))
 joint(brace,min(candidates,key=lambda r:r[0])[1],'plate rear tie enters actual nearest masonry course')
# Clean Boolean corner triangles and discard stones completely removed by the
# real aperture. Remaining bored masonry bears on the new load-bearing sleeve.
for ob in list(s.objects):
 if ob.type!='MESH':continue
 bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.dissolve_degenerate(bm,dist=1e-7,edges=list(bm.edges));bm.to_mesh(ob.data);bm.free();ob.data.update()
 if not ob.data.polygons:bpy.data.objects.remove(ob,do_unlink=True)
contacts=[rec for rec in contacts if rec['a'] in bpy.data.objects and rec['b'] in bpy.data.objects]
for rec in contacts:
 if rec['a'] in cut_stones:
  ob=bpy.data.objects[rec['a']];mean_y=sum(v.co.y for v in ob.data.vertices)/len(ob.data.vertices);rec['b']='Fluid | '+('north' if mean_y>0 else 'south')+' load-bearing wall sleeve';rec['why']='Bored masonry edges bear on installed wall sleeve arch instead of removed central stone'
profile=json.loads((O/'capture-profile.json').read_text());sys.path.insert(0,str(R/'tools/fmpl'));from blender_camera_guard import install_canonical_camera;install_canonical_camera(s,profile,bpy)
(O/'contacts.json').write_text(json.dumps(contacts,indent=2)+'\n');(O/'support-objects.json').write_text(json.dumps(['Continuous grounded rubble footing',bottom.name],indent=2));(O/'construction.json').write_text(json.dumps(dict(ports=ports,terminals=terminal_points,leds={'blue':[.585,-.7725,.500],'red-green':[.585,-.7725,.590]},pressure_volume='Closed iron liner and floor under gasketed rectangular hatch; both sleeves open into the shared cavity',gauge='Mounted case and continuous pressure tap; static nominal needle only',shared_sources=['art/source-to-3d/item-vault/v01/item-vault-v01.blend','art/source-to-3d/martian-stone-cache/v01/martian-stone-enclosure-kit.blend'],rotation='Native 0/4 states only. Source review 180/90 views are aliases, not new gameplay facings.',registration=contract['registration'],circuit_registration_justification='Original tank graphic anchors are outside this compact vessel; remap only drawing points to real mounted posts and LED bezels. Keep wire reach, fluid/temperature signals and controls unchanged.',owner_approval=False),indent=2)+'\n')
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(O/'pressurized-fluid-vault-v01.blend'),compress=True);bpy.ops.object.select_all(action='DESELECT')
for ob in s.objects:
 if ob.type=='MESH':ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'pressurized-fluid-vault-v01.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
s.render.filepath=str(O/'source-front.png');bpy.ops.render.render(write_still=True);print('FLUID_VAULT_AUTHORED_SOURCE_EXPORT_SAVED')
