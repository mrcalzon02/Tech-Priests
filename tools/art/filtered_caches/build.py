"""Rapid user-directed shared wall/tablet with ten distinct stock fillings."""
import bpy,bmesh,json,math,random,hashlib,sys
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[3];B=R/'art/source-to-3d/filtered-stone-caches/v01';catalog=json.loads((B/'catalog.json').read_text());T=B/'textures';helper=(R/'tools/art/item_vault/build.py').read_text();helper=helper[helper.index('def finish('):helper.index('collar=cylinder(')]
for row in catalog['rows']:
 if '--only' in sys.argv and row['key'] not in sys.argv[sys.argv.index('--only')+1].split(','):continue
 key=row['key'];O=R/row['path'];rng=random.Random(1040+catalog['rows'].index(row));bpy.ops.wm.open_mainfile(filepath=str(R/catalog['shared_source']));s=bpy.context.scene;root=bpy.data.objects['Martian Stone Cache | ground origin'];root.name='Filtered Cache | '+key
 for ob in list(bpy.data.collections['CACHE VARIANT | Domed hide cover'].objects):bpy.data.objects.remove(ob,do_unlink=True)
 contacts=[r for r in json.loads((R/'art/source-to-3d/martian-stone-cache/v01/contacts.json').read_text()) if r['a'] in bpy.data.objects and r['b'] in bpy.data.objects];col=bpy.data.collections.new('FILTERED STOCK | '+key);s.collection.children.link(col);mats={}
 for role in ('coal','copper-ore','copper','iron','iron-ore','stone','wood','wood-end'):
  mat=bpy.data.materials.new('Cache stock | '+key+' | '+role);mat.use_nodes=True;nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF')
  for kind in ('albedo','orm','normal'):
   tex=nt.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(T/(role+'-'+kind+'.png')))
   if kind=='albedo':nt.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
   else:
    tex.image.colorspace_settings.name='Non-Color'
    if kind=='orm':
     sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(tex.outputs['Color'],sep.inputs[0]);nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
    else:
     normal=nt.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.24;nt.links.new(tex.outputs['Color'],normal.inputs['Color']);nt.links.new(normal.outputs[0],bs.inputs['Normal'])
  mats[role]=mat
 exec(compile(helper,str(R/'tools/art/item_vault/build.py'),'exec'))
 def joint(a,b,why):contacts.append(dict(a=a.name if hasattr(a,'name') else a,b=b.name if hasattr(b,'name') else b,why=why))
 objects=[]
 if key in ('coal','copper-ore','iron-ore','stone'):
  role=key;bed=cylinder('Stock | underlying '+key+' mass',(0,0,.255),.64,.410,role,vertices=48);joint(bed,'Compacted earth cavity floor','bulk stock rests on actual cavity floor')
  layers=[];count=15 if key=='coal' else 11
  for layer in range(2):
   rocks=[]
   for i in range(count if layer==0 else count-4):
    a=math.tau*i/(count if layer==0 else count-4)+layer*.35;r=(.46 if layer==0 else .26)*math.sqrt(rng.uniform(.3,1));p=Vector((r*math.cos(a),r*math.sin(a),.485+layer*.115));radius=rng.uniform(.10,.145) if key!='stone' else rng.uniform(.12,.17)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1 if key in ('coal','copper-ore','stone') else 2,radius=1,location=p);ob=bpy.context.object
    for v in ob.data.vertices:v.co=Vector((v.co.x*radius,v.co.y*radius*.87,v.co.z*radius*.75))*(1+rng.uniform(-.18,.18))
    ob=finish(ob,'Stock | %s lump %d %d'%(key,layer,i),role,0);objects.append(ob);rocks.append(ob)
    parent=bed if layer==0 else min(layers[0],key=lambda lower:(lower.location-p).length)
    if layer:
     bpy.context.view_layer.update();aa=[ob.matrix_world@Vector(v) for v in ob.bound_box];bb=[parent.matrix_world@Vector(v) for v in parent.bound_box];gap=math.sqrt(sum(max(min(a[k] for a in aa)-max(b[k] for b in bb),min(b[k] for b in bb)-max(a[k] for a in aa),0)**2 for k in range(3)))
     if gap>.002:ob.location=ob.location.lerp(parent.location,.5)
    joint(ob,parent,'overlapping rough stock pile, supported by underlying bulk/lumps')
   layers.append(rocks)
 else:
  bed=box('Stock | timber dunnage',(0,0,.235),(.89,.89,.37),'wood',.008);joint(bed,'Compacted earth cavity floor','stock dunnage bears on actual cavity floor')
  if key in ('copper-plate','iron-plate'):
   role='copper' if key=='copper-plate' else 'iron'
   for stack,(x,y) in enumerate([(-.24,-.24),(.24,-.24),(-.24,.24),(.24,.24)]):
    parent=bed
    for n in range(8):
     ob=box('Stock | %s plate %d %d'%(key,stack,n),(x+rng.uniform(-.012,.012),y+rng.uniform(-.012,.012),.435+n*.030),(.35,.32,.032),role,.004);ob.rotation_euler.z=rng.uniform(-.05,.05);joint(ob,parent,'plate stack sits directly on dunnage/previous plate');parent=ob;objects.append(ob)
  elif key=='copper-cable':
   for i,(x,y) in enumerate([(-.25,-.23),(.25,-.23),(0,.27)]):
    curve=bpy.data.curves.new('Editable copper stock helix','CURVE');curve.dimensions='3D';curve.bevel_depth=.012;curve.bevel_resolution=2;sp=curve.splines.new('POLY');points=[]
    for j in range(193):a=j/192*math.tau*4;r=.145;points.append((x+r*math.cos(a),y+r*math.sin(a),.433+.20*j/192))
    sp.points.add(len(points)-1)
    for pt,p in zip(sp.points,points):pt.co=(*p,1)
    ob=bpy.data.objects.new('Stock | loose copper cable coil %d'%i,curve);s.collection.objects.link(ob);bpy.context.view_layer.objects.active=ob;ob.select_set(True);bpy.ops.object.convert(target='MESH');ob=finish(bpy.context.object,ob.name,'copper',0);joint(ob,bed,'loose stock coil rests on dunnage; open ends are stock, not unseated machine interfaces');objects.append(ob)
  elif key=='iron-gear-wheel':
   for i,(x,y) in enumerate([(-.25,-.22),(.25,-.22),(0,.27)]):
    parent=bed
    for layer in range(4):
     n=48;z=.420+layer*.056;v=[]
     for zz,inner in [(z,False),(z,True),(z+.056,False),(z+.056,True)]:
      for j in range(n):a=math.tau*j/n+layer*.13;r=.043 if inner else (.172 if j%4 in (1,2) else .142);v.append((x+r*math.cos(a),y+r*math.sin(a),zz))
     f=[]
     for j in range(n):k=(j+1)%n;f.extend(((j,k,n+k,n+j),(2*n+j,3*n+j,3*n+k,2*n+k),(j,2*n+j,2*n+k,k),(n+j,n+k,3*n+k,3*n+j)))
     me=bpy.data.meshes.new('Twelve-tooth bored gear');me.from_pydata(v,[],f);me.update();bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();ob=bpy.data.objects.new('Stock | stacked gear %d %d'%(i,layer),me);s.collection.objects.link(ob);ob=finish(ob,ob.name,'iron',.002);joint(ob,parent,'bored gear stack rests on preceding stock');parent=ob;objects.append(ob)
  elif key=='iron-stick':
   for layer in range(7):
    for i in range(9):
     bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.023,depth=.94,location=(0,(i-4)*.050+(layer%2)*.025,.443+layer*math.sqrt(.046**2-.025**2)));ob=bpy.context.object;ob.rotation_euler.y=math.pi/2;bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);ob=finish(ob,'Stock | iron rod %d %d'%(layer,i),'iron',.001);joint(ob,bed if layer==0 else 'Stock | iron rod %d %d'%(layer-1,i),'stacked rods bear on dunnage or preceding layer');objects.append(ob)
  elif key=='wood':
   for layer,count in enumerate((4,3,2)):
    for i in range(count):
     bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.076,depth=.90,location=((i-(count-1)/2)*.16,0,.495+layer*math.sqrt(.152**2-.080**2)));ob=bpy.context.object;ob.rotation_euler.x=math.pi/2;bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);ob=finish(ob,'Stock | cross-cut log %d %d'%(layer,i),'wood',.002);ob.data.materials.append(mats['wood-end'])
     for face in ob.data.polygons:
      if abs(face.normal.y)>.9:
       face.material_index=1
       for li in face.loop_indices:p=ob.data.vertices[ob.data.loops[li].vertex_index].co;ob.data.uv_layers.active.data[li].uv=(p.x/.152+.5,p.z/.152+.5)
      else:
       for li in face.loop_indices:p=ob.data.vertices[ob.data.loops[li].vertex_index].co;ob.data.uv_layers.active.data[li].uv=(math.atan2(p.z,p.x)/math.tau+.5,(p.y+.45)/.90)
     joint(ob,bed if layer==0 else 'Stock | cross-cut log %d %d'%(layer-1,min(i,count-1)),'roundwood stack rests on dunnage/underlying logs');objects.append(ob)
 (O/'contacts.json').write_text(json.dumps(contacts,indent=2)+'\n');(O/'support-objects.json').write_text(json.dumps(['Continuous grounded rubble footing','Compacted earth cavity floor',bed.name],indent=2));(O/'construction.json').write_text(json.dumps(dict(shared_wall_and_tablet='Unchanged from inspected cache master',fill=key,objects=[ob.name for ob in objects],stock_bed=bed.name,state='Static stock identity; no inventory-volume animation, power or fluid mechanism invented',native='Six-slot named filtered cache; existing runtime steward and ordinary inserter access preserved'),indent=2)+'\n')
 bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(O/(row['stem']+'.blend')),compress=True);bpy.ops.object.select_all(action='DESELECT')
 for ob in s.objects:
  if ob.type=='MESH':ob.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(O/(row['stem']+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
 s.render.filepath=str(O/'source-front.png');bpy.ops.render.render(write_still=True);print('FILTERED_CACHE_SOURCE_EXPORT_SAVED',key,flush=True)
