"""Distinct static reinforced hatch on the reusable authored stone enclosure."""
import bpy,bmesh,math,json,hashlib,sys
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/item-vault/v01';C=R/'art/source-to-3d/martian-stone-cache/v01';T=O/'textures'
bpy.ops.wm.open_mainfile(filepath=str(C/'martian-stone-cache-v01.blend'));s=bpy.context.scene
for ob in list(bpy.data.collections['CACHE VARIANT | Domed hide cover'].objects):bpy.data.objects.remove(ob,do_unlink=True)
root=bpy.data.objects['Martian Stone Cache | ground origin'];root.name='Item Vault | ground origin';contacts=[r for r in json.loads((C/'contacts.json').read_text()) if r['a'] in bpy.data.objects and r['b'] in bpy.data.objects];mats={}
for role in ('forged-iron','rubbed-iron','gasket'):
 mat=bpy.data.materials.new('Item Vault | '+role);mat.use_nodes=True;nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF')
 for kind in ('albedo','orm','normal'):
  tex=nt.nodes.new('ShaderNodeTexImage');tex.name='Vault '+kind;tex.image=bpy.data.images.load(str(T/(role+'-'+kind+'.png')))
  if kind=='albedo':nt.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
  else:
   tex.image.colorspace_settings.name='Non-Color'
   if kind=='orm':
    sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(tex.outputs['Color'],sep.inputs[0]);nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
   else:
    normal=nt.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.25;nt.links.new(tex.outputs['Color'],normal.inputs['Color']);nt.links.new(normal.outputs[0],bs.inputs['Normal'])
 mats[role]=mat
col=bpy.data.collections.new('ITEM VAULT | Reinforced hatch and manual lock');s.collection.children.link(col)
def finish(ob,name,role,bevel=0):
 ob.name=name;ob.parent=root
 for c in list(ob.users_collection):c.objects.unlink(ob)
 col.objects.link(ob);ob.data.materials.clear();ob.data.materials.append(mats[role]);bpy.context.view_layer.objects.active=ob
 if bevel:
  mod=ob.modifiers.new('Forged eased edges','BEVEL');mod.width=bevel;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
 if not ob.data.uv_layers:ob.data.uv_layers.new(name='Vault physical surface UV')
 for face in ob.data.polygons:
  axis=max(range(3),key=lambda j:abs(face.normal[j]));axes=[j for j in range(3) if j!=axis]
  for li in face.loop_indices:
   p=ob.matrix_world@ob.data.vertices[ob.data.loops[li].vertex_index].co;ob.data.uv_layers.active.data[li].uv=(p[axes[0]]/1.4+.5,p[axes[1]]/1.4+.5)
 return ob
def joint(a,b,why):contacts.append(dict(a=a.name if hasattr(a,'name') else a,b=b.name if hasattr(b,'name') else b,why=why))
def box(name,p,size,role='forged-iron',bevel=.005):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);ob=bpy.context.object;ob.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(ob,name,role,bevel)
def cylinder(name,p,radius,depth,role='rubbed-iron',axis='Z',vertices=32):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=p);ob=bpy.context.object
 if axis=='Y':ob.rotation_euler.x=math.pi/2
 if axis=='X':ob.rotation_euler.y=math.pi/2
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);return finish(ob,name,role,.002)
def door_profile(name,width,height,z0,z1,corner,role):
 x=width/2;y=height/2;c=corner;outline=[(-x+c,-y),(x-c,-y),(x,-y+c),(x,y-c),(x-c,y),(-x+c,y),(-x,y-c),(-x,-y+c)]
 v=[(a,b,z) for z in (z0,z1) for a,b in outline];faces=[tuple(range(7,-1,-1)),tuple(range(8,16))]+[(j,(j+1)%8,(j+1)%8+8,j+8) for j in range(8)]
 me=bpy.data.meshes.new(name);me.from_pydata(v,[],faces);me.update();ob=bpy.data.objects.new(name,me);s.collection.objects.link(ob);return finish(ob,name,role,.004)
def ring(name,inner,outer,z0,z1,role='forged-iron',n=64):
 v=[(r*math.cos(math.tau*j/n),r*math.sin(math.tau*j/n),z) for z,r in ((z0,outer),(z0,inner),(z1,outer),(z1,inner)) for j in range(n)];f=[]
 for j in range(n):
  k=(j+1)%n;f.extend(((j,k,n+k,n+j),(2*n+j,3*n+j,3*n+k,2*n+k),(j,2*n+j,2*n+k,k),(n+j,n+k,3*n+k,3*n+j)))
 me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.update();ob=bpy.data.objects.new(name,me);s.collection.objects.link(ob);return finish(ob,name,role,.003)
collar=cylinder('Vault | continuous metal infill panel',(0,0,.6725),.727,.055,'forged-iron',vertices=96)
# Cut a rectangular aperture in the surrounding metal panel. The door and
# gasket overlap this opening on all sides; the panel itself fills the ring.
cutter=door_profile('TEMP actual rectangular panel aperture',.86,.74,.50,.85,.045,'gasket');bpy.context.view_layer.objects.active=collar
boolean=collar.modifiers.new('Actual rectangular door opening','BOOLEAN');boolean.operation='DIFFERENCE';boolean.object=cutter;bpy.ops.object.modifier_apply(modifier=boolean.name);bpy.data.objects.remove(cutter,do_unlink=True)
joint(collar,'Grounded carved circuit receiving tablet','circumferential collar bears on inner wall masonry')
gasket=door_profile('Vault | rectangular door gasket',1.028,.928,.695,.707,.075,'gasket');joint(gasket,collar,'rectangular gasket bears on metal around actual aperture')
door=door_profile('Vault | rectangular reinforced door leaf',1.00,.90,.706,.746,.080,'forged-iron');joint(door,gasket,'thick rectangular door bears on its perimeter gasket')
# A restrained rectangular perimeter frame replaces the rejected cross ribs.
perimeter=[]
for i,(p,size) in enumerate([((-.456,0,.751),(.030,.68,.020)),((.456,0,.751),(.030,.68,.020)),((0,-.406,.751),(.78,.030,.020)),((0,.406,.751),(.78,.030,.020))]):
 rib=box('Vault | door perimeter flange %d'%i,p,size);joint(rib,door,'perimeter reinforcement follows rectangular door edges');perimeter.append(rib)
for x,y in [(-.456,-.28),(-.456,0),(-.456,.28),(.456,-.28),(.456,0),(.456,.28),(-.28,-.406),(0,-.406),(.28,-.406),(-.28,.406),(0,.406),(.28,.406)]:
  rivet=cylinder('Vault | hatch captive rivet %.2f %.2f'%(x,y),(x,y,.766),.014,.015,vertices=8);idx=(0 if x<0 else 1) if abs(x)==.456 else (2 if y<0 else 3);joint(rivet,perimeter[idx],'visible rivet crown embeds in perimeter flange')
# Two real hinge barrels and their continuous captive pins, parallel to Y.
for i,y in enumerate((-.28,.28)):
 support=box('Vault | hinge fixed saddle %d'%i,(-.585,y,.724),(.14,.16,.075));joint(support,collar,'fixed hinge saddle bolted to continuous surrounding panel')
 strap=box('Vault | hinge leaf strap %d'%i,(-.44,y,.757),(.26,.075,.032));joint(strap,door,'hinge strap bolted on rectangular door surface')
 barrel=cylinder('Vault | hinge barrel %d'%i,(-.535,y,.786),.044,.18,axis='Y');joint(barrel,support,'hinge barrel embeds in fixed saddle');joint(barrel,strap,'hinge strap reaches common hinge axis')
 pin=cylinder('Vault | captive hinge pin %d'%i,(-.535,y,.786),.018,.215,axis='Y');joint(pin,barrel,'full pin runs through barrel bore')
 for end in (-1,1):
  head=cylinder('Vault | hinge pin head %d %d'%(i,end),(-.535,y+end*.108,.786),.029,.018,axis='Y',vertices=12);joint(head,pin,'pin head captures barrel end')
 for dx in (-.03,.03):
  bolt=cylinder('Vault | hinge saddle bolt %d %.2f'%(i,dx),(-.60+dx,y,.768),.014,.018,vertices=6);joint(bolt,support,'saddle bolt rooted in fixed hinge mounting plate')
# A mechanical spindle in its bearing drives two opposite captured locking bars.
gearbox=box('Vault | manual lock gearbox',(.18,-.04,.782),(.19,.22,.095));joint(gearbox,door,'manual gearbox foot bolted directly to hatch')
for i,y in enumerate((-.40,.40)):
 receiver=box('Vault | lock keeper %d'%i,(.28,y*1.52,.763),(.14,.12,.135));joint(receiver,collar,'keeper mounted on surrounding metal panel')
 guide=box('Vault | sliding bar guide %d'%i,(.28,y,.778),(.10,.11,.080));joint(guide,door,'bar guide feet embedded slightly in hatch')
 for host in (receiver,guide):
  slot=box('TEMP locking bar rectangular bore',(.28,host.location.y,.791),(.046,.20,.043),'gasket',.001);bpy.context.view_layer.objects.active=host;cut=host.modifiers.new('Actual locking bolt passage','BOOLEAN');cut.operation='DIFFERENCE';cut.object=slot;bpy.ops.object.modifier_apply(modifier=cut.name);bpy.data.objects.remove(slot,do_unlink=True)
 bar=box('Vault | captured locking bolt %d'%i,(.28,y*.82,.791),(.040,.58,.035),'rubbed-iron');joint(bar,gearbox,'bolt inner end enters gearbox guide');joint(bar,guide,'bolt runs through captured guide');joint(bar,receiver,'bolt outer end seats inside keeper')
stem=cylinder('Vault | handwheel bearing spindle',(.18,-.04,.844),.036,.132);joint(stem,gearbox,'continuous spindle penetrates gearbox bearing')
mount=cylinder('Vault | spindle receiving boss',(.18,-.04,.830),.067,.035);joint(mount,gearbox,'receiving boss mounted in upper gearbox casing');joint(mount,stem,'boss surrounds spindle')
bpy.ops.mesh.primitive_torus_add(major_segments=64,minor_segments=12,location=(.18,-.04,.902),major_radius=.202,minor_radius=.017);wheel=finish(bpy.context.object,'Vault | forged handwheel rim','rubbed-iron')
hub=cylinder('Vault | keyed handwheel hub',(.18,-.04,.902),.060,.046);joint(hub,stem,'hub keyed to continuous spindle')
for i in range(4):
 a=i*math.pi/2;p=Vector((.18+math.cos(a)*.125,-.04+math.sin(a)*.125,.902));spoke=box('Vault | rigid handwheel spoke %d'%i,p,(.175,.022,.020),'rubbed-iron');spoke.rotation_euler.z=a;joint(spoke,hub,'spoke roots overlap keyed hub');joint(spoke,wheel,'spoke ends embed in handwheel ring')
nut=cylinder('Vault | spindle captive crown nut',(.18,-.04,.930),.035,.018,vertices=6);joint(nut,hub,'crown nut captures handwheel hub on spindle')
# Keep current camera, shared relief and actual circuit seats, preserving all
# fixed native wire points. No decorative power wires or invented fluid ports.
(O/'contacts.json').write_text(json.dumps(contacts,indent=2)+'\n');(O/'support-objects.json').write_text((C/'support-objects.json').read_text())
(O/'construction.json').write_text(json.dumps(dict(kit=str((C/'martian-stone-enclosure-kit.blend').relative_to(R)),kit_hash=hashlib.sha256((C/'martian-stone-enclosure-kit.blend').read_bytes()).hexdigest(),reuse='Stone wall and ground plane from inspected authored cache source, material review state pending; independent iron hatch replaces all hide/stitch/weight/rope geometry',mechanism='Static manual handwheel, keyed spindle, fitted bearing/gearbox, opposing guided bolts and keepers, two real hinge barrels/pins/leaf straps',native='No new open animation, power, fluids, filters or precision inserter requirements',registration=dict(scale=3*32/512,shift=[0,-.08713203435596423]),contacts=contacts),indent=2)+'\n')
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(O/'item-vault-v01.blend'),compress=True);bpy.ops.object.select_all(action='DESELECT')
for ob in s.objects:
 if ob.type=='MESH':ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'item-vault-v01.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
s.render.filepath=str(O/'source-front.png');bpy.ops.render.render(write_still=True);print('ITEM_VAULT_AUTHORED_SOURCE_EXPORT_SAVED',len(contacts))
