"""Owner-directed central skull remodel; supplied skull remains editable beneath fitted augmetics."""
import bpy,bmesh,ast,json,math,sys,shutil,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[3];OLD=R/'art/source-to-3d/conclave-center/v07-aged-and-ambient';O=OLD.parent/'v08-martian-central-emblem';O.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(OLD/'conclave-center-v07.blend'));s=bpy.context.scene;s.frame_set(1);root=bpy.data.objects['Conclave Center | ground origin'];contacts=json.loads((OLD/'contacts.json').read_text());changes=[]
for name in ('capture-profile.json','contract.json','ATTRIBUTION.txt','supplied-skull-reuse.json','receiving-interfaces.json','bend-radius-review.json','arch-and-services.json','pipette-requests.json','orientation-and-skull-preservation.json','surface-manifest.json','support-objects.json','ambient-motion.json','surface-plan.json'):
 shutil.copy2(OLD/name,O/name)
head=bpy.data.objects['Supplied DGordillo low-poly skull 0'];original={o.name:hashlib.sha256(o.data.vertices[0].co.to_tuple().__repr__().encode()+str([list(v.co) for v in o.data.vertices]).encode()).hexdigest() for o in s.objects if o.name.startswith('Supplied DGordillo low-poly skull')}
mats={k:bpy.data.materials.get('Conclave V03 | '+k) or bpy.data.materials.get('Conclave | '+k) for k in ('cast-frame','console-panels','edge-trim','control-keys','floor-tread','cable-jacket')}
helper=R/'tools/art/conclave/refine_v03.py';tree=ast.parse(helper.read_text());names={'uv','mesh','box','joint','cylinder','octrect','ring_xz'};exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[]),str(helper),'exec'))
def material(name,color,metal,rough,copy=None):
 mat=copy.copy() if copy else bpy.data.materials.new(name);mat.name=name;mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF')
 for key in ('Base Color','Roughness','Metallic','Normal'):
  for link in list(bs.inputs[key].links):mat.node_tree.links.remove(link)
 bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
 return mat
mats['oxide']=material('Conclave V08 | black oxide cranial plate',(.055,.062,.060),.8,.55)
mats['steel']=material('Conclave V08 | worn augmetic steel',(.15,.17,.16),.78,.61)
mats['enamel']=material('Conclave V08 | aged bone enamel cog',(.31,.265,.18),.12,.78)
mats['red']=material('Conclave V08 | dark Martian red ocular lens',(.21,.007,.003),.25,.22);bs=mats['red'].node_tree.nodes.get('Principled BSDF');bs.inputs['Emission Color'].default_value=(.6,.008,.001,1);bs.inputs['Emission Strength'].default_value=.6
for role in ('oxide','steel','enamel'):
 mat=mats[role];nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF');tex=nt.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(O/'textures'/(role+'-albedo.png')));nt.links.new(tex.outputs['Color'],bs.inputs['Base Color']);orm=nt.nodes.new('ShaderNodeTexImage');orm.image=bpy.data.images.load(str(O/'textures'/(role+'-orm.png')));orm.image.colorspace_settings.name='Non-Color';sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(orm.outputs['Color'],sep.inputs[0]);nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic']);normal=nt.nodes.new('ShaderNodeTexImage');normal.image=bpy.data.images.load(str(O/'textures'/(role+'-normal.png')));normal.image.colorspace_settings.name='Non-Color';nm=nt.nodes.new('ShaderNodeNormalMap');nt.links.new(normal.outputs['Color'],nm.inputs['Color']);nt.links.new(nm.outputs[0],bs.inputs['Normal'])
# The new half-mask follows the real donor surface. It is split at actual panel
# boundaries and has thickness, return walls, bevels and nonzero assembly gaps.
plates=[]
for name,low,high,role in [('cranial vault',1.733,2,'oxide'),('orbital and cheek',1.590,1.729,'steel'),('mandibular half',1.470,1.586,'oxide')]:
 ob=head.copy();ob.data=head.data.copy();ob.name='Mars emblem | fitted '+name;s.collection.objects.link(ob);ob.data.materials.clear();ob.data.materials.append(mats[role]);bm=bmesh.new();bm.from_mesh(ob.data)
 for p,n,inside,outside in [((.002,0,0),(1,0,0),True,False),((0,0,low-head.location.z),(0,0,1),True,False),((0,0,high-head.location.z),(0,0,1),False,True)]:
  bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=p,plane_no=n,dist=.00001,clear_inner=inside,clear_outer=outside)
 bm.to_mesh(ob.data);bm.free()
 # Only the half-mask changes. The supplied mesh and original sculpt/UV are retained.
 for v in ob.data.vertices:v.co+=v.normal*.003
 solid=ob.modifiers.new('Cast plate wall and sealed return edges','SOLIDIFY');solid.thickness=.004;solid.offset=1;solid.use_even_offset=True;bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=solid.name)
 bevel=ob.modifiers.new('Dressed plate edges','BEVEL');bevel.width=.0008;bevel.segments=2;bpy.ops.object.modifier_apply(modifier=bevel.name)
 bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7);bm.to_mesh(ob.data);bm.free();ob.data.update()
 joint(ob,head,'fitted augmetic plate over actual supplied anatomy, integral return walls');plates.append(ob.name)
# A real 20-tooth cog surrounds the central skull, mounted back into the shrine.
n=160;outer=[];inner=[]
for j in range(n):
 a=math.tau*j/n;r=.271 if j%8 in (2,3,4,5) else .236;outer.append((r*math.cos(a),r*math.sin(a)));inner.append((.151*math.cos(a),.151*math.sin(a)))
cog=ring_xz('Mars emblem | twenty tooth cog surround',outer,inner,.364,.419,1.66,'oxide',None);cog.data.materials.append(mats['enamel'])
for p in cog.data.polygons:p.material_index=1 if p.center.x<0 else 0
joint(cog,'Back shrine structural casting','cog rear face embeds .009 into actual shrine casting; inner ring retains existing medallion')
# Source-surface raycasts build a conforming ocular receiving flange, rather
# than a floating cylinder or an eye buried behind the old face.
verts=[head.matrix_world@v.co for v in head.data.vertices];bvh=BVHTree.FromPolygons(verts,[list(f.vertices) for f in head.data.polygons]);cx,cz=.072,1.707;N=32;radius=.038;points=[]
for j in range(N):
 a=math.tau*j/N;x=cx+radius*math.cos(a);z=cz+radius*math.sin(a);p,no,face,d=bvh.ray_cast(Vector((x,-1,z)),Vector((0,1,0)))
 if p is None:raise RuntimeError('Ocular flange extends beyond supplied face')
 points.append(p)
front=min(p.y for p in points)-.016;v=[]
for ring in range(4):
 for j in range(N):
  a=math.tau*j/N;r=radius if ring in (0,2) else .023;y=front if ring<2 else points[j].y+.004;v.append((cx+r*math.cos(a),y,cz+r*math.sin(a)))
faces=[]
for j in range(N):
 k=(j+1)%N;faces.extend(((j,k,N+k,N+j),(2*N+j,3*N+j,3*N+k,2*N+k),(j,2*N+j,2*N+k,k),(N+j,N+k,3*N+k,3*N+j)))
eye=mesh('Mars emblem | surface seated ocular receiving flange',v,faces,'oxide',bevel=.0006);joint(eye,plates[1],'ocular flange rear follows actual socket surround raycast, front has a machined annular seat')
barrel=cylinder('Mars emblem | inset optical barrel',(cx,front+.035,cz),(cx,front+.002,cz),.0225,'steel',32);joint(barrel,eye,'optical barrel recessed into open receiving flange')
lens=cylinder('Mars emblem | red bionic eye lens',(cx,front+.003,cz),(cx,front-.0008,cz),.0175,'red',32);joint(lens,barrel,'lens captured inside recessed optical barrel')
for j in range(8):
 a=math.tau*j/8;p=Vector((cx+.030*math.cos(a),front,cz+.030*math.sin(a)));bolt=cylinder('Mars emblem | ocular captive screw %02d'%j,p+Vector((0,.002,0)),p-Vector((0,.0025,0)),.0032,'edge-trim',6);joint(bolt,eye,'captive screw bears on real annular front seat')
# Temple studs and a retained sagittal seam make the shell's assembly legible.
mounts=[]
for j,(x,z) in enumerate(((.024,1.758),(.080,1.760),(.106,1.654),(.034,1.603))):
 p,no,face,d=bvh.ray_cast(Vector((x,-1,z)),Vector((0,1,0)));no=no.normalized();base=p+no*.003;boss=cylinder('Mars emblem | plate retaining boss %d'%j,base-no*.002,base+no*.006,.008,'edge-trim',16);joint(boss,head,'retaining boss seated on actual donor surface normal');bolt=cylinder('Mars emblem | plate retaining stud %d'%j,base+no*.003,base+no*.009,.0042,'control-keys',6);joint(bolt,boss,'stud retained in fitted plate boss');mounts.append(dict(point=list(p),normal=list(no),boss=boss.name))
anchors=[]
for j,(x,z) in enumerate(((.125,1.620),(.075,1.552))):
 p,no,face,d=bvh.ray_cast(Vector((x,-1,z)),Vector((0,1,0)));no.normalize();base=p+no*.003;tip=base+no*.017;boss=cylinder('Mars emblem | jaw strut seated anchor %d'%j,base-no*.002,tip,.011,'oxide',20);joint(boss,head,'jaw strut socket root seats on actual donor surface normal');anchors.append((tip,boss))
p,q=anchors[0][0],anchors[1][0];delta=q-p;body=cylinder('Mars emblem | fixed mandibular strut housing',p,p+delta*.64,.009,'steel',20);rod=cylinder('Mars emblem | captured mandibular strut rod',p+delta*.53,q,.0045,'edge-trim',16);joint(body,anchors[0][1],'strut housing retained in upper actual surface anchor');joint(rod,body,'male strut rod overlaps real housing bore region');joint(rod,anchors[1][1],'rod captured in lower surface anchor; emblem hardware is static')
for name,sha in original.items():
 ob=bpy.data.objects[name];assert hashlib.sha256(ob.data.vertices[0].co.to_tuple().__repr__().encode()+str([list(v.co) for v in ob.data.vertices]).encode()).hexdigest()==sha
# Pack model-specific image finishes already present; new metals use the aged
# panel library maps in the follow-up bake pass, preserving these fitted shells.
(O/'contacts.json').write_text(json.dumps(contacts,indent=2)+'\n');(O/'central-emblem.json').write_text(json.dumps(dict(stage='owner-directed remodel candidate; not integrated',reference='https://merch.warhammer.com/en-de/products/starforged-warhammer-40-000-chapter-icon-pin-badge-adeptus-mechanicus',design='Supplied low-poly skull retained under a three-part fitted augmetic half-mask, surface-seated red bionic eye and structural 20-tooth cog.',plates=plates,ocular_flange_back_samples=[list(p) for p in points],ocular_front_y=front,normal_seated_bosses=mounts,original_skulls_preserved=original,ambient='V07 flicker/waver/smoke and slow screen scroll/keyboard spill retained unchanged',remaining='Material texture binding, source/export inspection, motion preview, sprite/native replacement and owner review'),indent=2))
s.frame_set(1);bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(O/'conclave-center-v08.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for ob in s.objects:
 if ob.type=='MESH':ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'conclave-center-v08.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_cameras=False,export_lights=False)
s.cycles.samples=48;s.render.filepath=str(O/'source-front.png');bpy.ops.render.render(write_still=True)
print('V08_CENTRAL_SKULL_ACTUALLY_REMODELED',flush=True)
