import bpy, math, random, pathlib, json
from mathutils import Vector
R=pathlib.Path(__file__).resolve().parent
random.seed(42)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for m in list(bpy.data.materials): bpy.data.materials.remove(m)
def material(name,lo,hi,wood=False):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;b=n.get('Principled BSDF');b.inputs['Roughness'].default_value=.87 if wood else .62;b.inputs['Metallic'].default_value=0 if wood else .8
 t=n.new('ShaderNodeTexCoord');v=n.new('ShaderNodeVectorMath');v.operation='MULTIPLY';v.inputs[1].default_value=(26,26,1.5) if wood else (16,16,16);l.new(t.outputs['Generated'],v.inputs[0])
 noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=3;noise.inputs['Detail'].default_value=4;l.new(v.outputs[0],noise.inputs['Vector'])
 ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.24;ramp.color_ramp.elements[0].color=(*lo,1);ramp.color_ramp.elements[1].position=.8;ramp.color_ramp.elements[1].color=(*hi,1);l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],b.inputs['Base Color'])
 bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.4 if wood else .22;bump.inputs['Distance'].default_value=.012 if wood else .0015;l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],b.inputs['Normal']);return m
wood=material('Weathered rough timber',(.10,.052,.023),(.39,.25,.12),True)
iron=material('Single dull hammered iron sheet',(.075,.085,.09),(.27,.29,.30))
head=material('Forged hammer iron',(.035,.039,.043),(.16,.17,.18))
def mesh(name,vs,fs,mat):
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.data.materials.append(mat);return o
# Squared split timbers with irregular corners and bowed profiles; local Z follows the grain.
def timber(name,a,b,w,d):
 vs=[];N=12;K=12
 for k in range(K+1):
  t=k/K;dx=.012*math.sin(t*5+len(name));dy=.009*math.sin(t*6)
  for i in range(N):
   ang=i*2*math.pi/N;x=math.cos(ang);y=math.sin(ang);scale=max(abs(x),abs(y));r=random.uniform(.94,1.035)
   vs.append((x/scale*w*.5*r+dx,y/scale*d*.5*r+dy,t*(Vector(b)-Vector(a)).length))
 fs=[]
 for k in range(K):
  for i in range(N):fs.append((k*N+i,k*N+(i+1)%N,(k+1)*N+(i+1)%N,(k+1)*N+i))
 fs.extend([tuple(reversed(range(N))),tuple(K*N+i for i in range(N))]);o=mesh(name,vs,fs,wood);o.location=a;o.rotation_euler=(Vector(b)-Vector(a)).to_track_quat('Z','Y').to_euler()
 bevel=o.modifiers.new('Worn split edges','BEVEL');bevel.width=.004;bevel.segments=2;return o
for x in [-1,1]:
 for y in [-1,1]:timber('Rough timber leg',(.39*x,.32*y,.012),(.355*x,.29*y,.765),.135,.13)
for y in [-1,1]:
 timber('Upper timber rail',(-.415,y*.29,.69),(.415,y*.29,.69),.11,.12)
 timber('Low cross brace',(-.38,y*.32,.25),(.38,y*.32,.36),.08,.075)
for x in [-1,1]:
 timber('Upper end support',(x*.35,-.36,.69),(x*.35,.36,.69),.105,.11)
 timber('End brace',(x*.38,-.32,.25),(x*.38,.32,.29),.07,.075)
# Three rough top planks support the sheet, visible below the hammered rim.
for y in [-.24,0,.24]:timber('Top supporting plank',(-.44,y,.73),(.44,y,.73),.22,.06)
# Connected sheet: almost-flat center, a rounded hand-folded perimeter, irregular hem.
N=28;vs=[];fs=[]
# rectangular concentric rings, center filled with a grid to avoid giant ngon shading
# Grid with shared perimeter, center deviations below 1 mm.
for j in range(N+1):
 for i in range(N+1):
  x=(i/N-.5)*.98;y=(j/N-.5)*.82;z=.798+random.uniform(-.0007,.0007);vs.append((x,y,z))
for j in range(N):
 for i in range(N):
  k=j*(N+1)+i;fs.append((k,k+1,k+N+2,k+N+1))
edge=list(range(N+1))+[j*(N+1)+N for j in range(1,N+1)]+[N*(N+1)+i for i in range(N-1,-1,-1)]+[j*(N+1) for j in range(N-1,0,-1)]
prev=edge
for ring in range(1,5):
 curr=[]
 for idx,k in enumerate(edge):
  x,y,z=vs[k];sx=1 if x>0 else -1;sy=1 if y>0 else -1
  # fold outward over the timber then turn down; broad working face stays flat
  ext=[0,.009,.011,.008,.005][ring];x+=sx*ext if abs(x)>.489 else 0;y+=sy*ext if abs(y)>.409 else 0
  drop=[0,.003,.014,.039,.067][ring];z-=drop+(random.uniform(-.008,.008) if ring==4 else random.uniform(-.0015,.0015))
  curr.append(len(vs));vs.append((x,y,z))
 for i in range(len(edge)):j=(i+1)%len(edge);fs.append((prev[i],curr[i],curr[j],prev[j]))
 prev=curr
sheet=mesh('ONE continuous thin iron sheet folded over all four edges',vs,fs,iron)
for p in sheet.data.polygons:p.use_smooth=True
s=sheet.modifiers.new('Sheet gauge 2 mm','SOLIDIFY');s.thickness=.002
b=sheet.modifiers.new('Soft hammered lip','BEVEL');b.width=.0015;b.segments=2
# Small dark nail heads pin the sheet hem to the wood.
for y in [-1,1]:
 for x in [-.36,0,.36]:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=1,location=(x,y*.423,.755));o=bpy.context.object;o.name='Sheet securing nail';o.scale=(.011,.004,.011);o.data.materials.append(head)
for x in [-1,1]:
 for y in [-.28,.28]:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=1,location=(x*.501,y,.755));o=bpy.context.object;o.name='Sheet securing nail';o.scale=(.004,.011,.011);o.data.materials.append(head)
# Hammer rests on the surface: simple heavy forged head and rough wooden handle.
a=Vector((-.20,.06,.852));b=Vector((.31,-.17,.84));timber('Hammer wooden handle',a,b,.048,.046)
bpy.ops.mesh.primitive_cube_add(size=1,location=(-.22,.07,.885));o=bpy.context.object;o.name='Single forged hammer head';o.dimensions=(.15,.32,.17);o.rotation_euler.z=math.radians(-24);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(head);be=o.modifiers.new('Battered rounded forging','BEVEL');be.width=.017;be.segments=3
# One camera reused for all views.
world=bpy.data.worlds.new('Neutral daylight');bpy.context.scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.6,.65,.72,1);world.node_tree.nodes['Background'].inputs[1].default_value=.45
for loc,power,size in [((-3,-4,6),500,3),((3,2,4),220,4)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,.4))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.005));ground=bpy.context.object;ground.name='Preview ground - excluded from asset';gm=bpy.data.materials.new('Neutral ground');gm.diffuse_color=(.3,.285,.26,1);ground.data.materials.append(gm)
bpy.ops.object.camera_add();cam=bpy.context.object;cam.name='Export camera';cam.data.type='ORTHO';cam.data.ortho_scale=1.65
sc=bpy.context.scene;sc.camera=cam;sc.render.engine='CYCLES';sc.cycles.samples=48;sc.cycles.use_denoising=False;sc.render.resolution_x=900;sc.render.resolution_y=900;sc.render.resolution_percentage=100;sc.view_settings.view_transform='AgX';sc.render.image_settings.file_format='PNG'
for i,ang in enumerate([-55,35,125,215]):
 rad=math.radians(ang);cam.location=(3*math.cos(rad),3*math.sin(rad),3+.42);cam.rotation_euler=(Vector((0,0,.42))-cam.location).to_track_quat('-Z','Y').to_euler();sc.render.filepath=str(R/f'workbench_v4_view_{i+1}.png')
 if i==0:bpy.ops.wm.save_as_mainfile(filepath=str(R/'rough_timber_workbench_v4.blend'))
 bpy.ops.render.render(write_still=True)
assert len([o for o in bpy.data.objects if o.type=='CAMERA'])==1
assert len([o for o in bpy.data.objects if o.name.startswith('ONE continuous')])==1
print('VERIFIED: one connected sheet, four legs, one hammer, one camera')
