"""Retain V06 construction; aged original skulls and authored ambient motion."""
import bpy,json,math,shutil,hashlib,sys
from pathlib import Path
from mathutils import Vector,Matrix
R=Path(__file__).resolve().parents[3];OLD=R/'art/source-to-3d/conclave-center/v06-receiving-bulkheads';O=OLD.parent/'v07-aged-and-ambient';T=O/'textures'
bpy.ops.wm.open_mainfile(filepath=str(OLD/'conclave-center-v06.blend'));s=bpy.context.scene;root=bpy.data.objects['Conclave Center | ground origin']
for name in ('contract.json','capture-profile.json','contacts.json','ATTRIBUTION.txt','supplied-skull-reuse.json','receiving-interfaces.json','bend-radius-review.json','arch-and-services.json','pipette-requests.json','orientation-and-skull-preservation.json','surface-manifest.json','support-objects.json'):
 shutil.copy2(OLD/name,O/name)
def signature(ob):return hashlib.sha256(json.dumps(dict(v=[list(v.co) for v in ob.data.vertices],matrix=[list(r) for r in ob.matrix_world]),sort_keys=True).encode()).hexdigest()
fixed={ob.name:signature(ob) for ob in s.objects if ob.type=='MESH' and 'static flame' not in ob.name}
def image(path,noncolor=False):
 im=bpy.data.images.load(str(path),check_existing=True)
 if noncolor:im.colorspace_settings.name='Non-Color'
 return im
for i in range(3):
 mat=bpy.data.materials['Conclave | supplied DGordillo ivory '+str(i)];nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF');uv=nt.nodes.new('ShaderNodeUVMap');uv.uv_map='SkullUV'
 al=nt.nodes.new('ShaderNodeTexImage');al.name='Actual original UV aged bone';al.image=image(T/'aged-original-skull-albedo.png');nt.links.new(uv.outputs['UV'],al.inputs['Vector']);nt.links.new(al.outputs['Color'],bs.inputs['Base Color'])
 orm=nt.nodes.new('ShaderNodeTexImage');orm.image=image(T/'aged-original-skull-orm.png',True);nt.links.new(uv.outputs['UV'],orm.inputs['Vector']);sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(orm.outputs['Color'],sep.inputs[0]);nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);bs.inputs['Metallic'].default_value=0
 # Redundant unused cast maps are removed; donor sculpt normal and original UV survive.
 for n in list(nt.nodes):
  if n.type=='TEX_IMAGE' and n.image and n.image.name.startswith('skull-cast'):nt.nodes.remove(n)
# Model-specific finishes already carry panel-seam wear. Reduce polished glare on
# untouched fasteners and wax so worn metal and ritual wax read as different materials.
for mat in bpy.data.materials:
 if not mat.use_nodes:continue
 bs=mat.node_tree.nodes.get('Principled BSDF')
 if not bs:continue
 if 'aged ritual wax' in mat.name:bs.inputs['Base Color'].default_value=(.28,.18,.065,1);bs.inputs['Roughness'].default_value=.82
 if 'edge-trim' in mat.name and not bs.inputs['Roughness'].is_linked:bs.inputs['Roughness'].default_value=.65
s.render.fps=24;s.frame_start=1;s.frame_end=289;TAU=math.tau
def wave(frame,phase):
 t=TAU*(frame-1)/288
 return .80+.10*math.sin(17*t+phase)+.065*math.sin(31*t+phase*.7)+.035*math.sin(43*t+phase*1.3)
def light(name,kind,p,color,power,size=.1,target=None):
 data=bpy.data.lights.new(name,kind);data.energy=power;data.color=color
 if kind=='AREA':data.shape='DISK';data.size=size
 else:data.shadow_soft_size=size
 ob=bpy.data.objects.new(name,data);s.collection.objects.link(ob);ob.location=p
 if target is not None:ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
 return ob
arch=json.loads((O/'arch-and-services.json').read_text());effects=[]
smat=bpy.data.materials.new('Conclave V07 | light candle smoke');smat.use_nodes=True;nt=smat.node_tree;nt.nodes.clear();out=nt.nodes.new('ShaderNodeOutputMaterial');bs=nt.nodes.new('ShaderNodeBsdfPrincipled');bs.inputs['Roughness'].default_value=1;tex=nt.nodes.new('ShaderNodeTexImage');tex.image=image(T/'candle-smoke-feather.png');nt.links.new(tex.outputs['Color'],bs.inputs['Base Color']);nt.links.new(tex.outputs['Alpha'],bs.inputs['Alpha']);nt.links.new(bs.outputs[0],out.inputs['Surface']);smat.surface_render_method='DITHERED'
for holder in arch['arch']['holders']:
 i=holder['index'];phase=i*1.743;fl=bpy.data.objects['Arch candle static flame %02d'%i];fl.name='Arch candle animated flame %02d'%i
 # Put the transform pivot at the flame's fixed wick contact, preserving world geometry.
 zmin=min(v.co.z for v in fl.data.vertices);fl.location.z+=zmin
 for v in fl.data.vertices:v.co.z-=zmin
 fl.shape_key_add(name='Basis');sx=fl.shape_key_add(name='Waver across arch');sy=fl.shape_key_add(name='Waver fore and aft')
 height=max(v.co.z for v in fl.data.vertices)
 for j,v in enumerate(fl.data.vertices):
  h=v.co.z/height;sx.data[j].co.x+=.017*h*h;sy.data[j].co.y+=.010*h*h
 sx.slider_min=-1;sy.slider_min=-1
 mat=fl.data.materials[0].copy();mat.name='Conclave V07 | candle flame %02d'%i;fl.data.materials[0]=mat;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Emission Color'].default_value=(1,.24,.025,1)
 lamp=light('Candle %02d local warm spill'%i,'POINT',fl.location+Vector((0,0,.03)),(1,.29,.045),.12,.045)
 for f in range(1,290,3):
  t=TAU*(f-1)/288;sx.value=.58*math.sin(5*t+phase)+.23*math.sin(13*t+phase);sy.value=.55*math.sin(7*t+phase*.5);sx.keyframe_insert('value',frame=f);sy.keyframe_insert('value',frame=f)
  fl.scale.z=.82+.18*wave(f,phase);fl.keyframe_insert('scale',frame=f);strength=wave(f,phase);bs.inputs['Emission Strength'].default_value=3.8*strength;bs.inputs['Emission Strength'].keyframe_insert('default_value',frame=f);lamp.data.energy=.20*strength;lamp.data.keyframe_insert('energy',frame=f)
 # Three staggered feathered ribbons give a continuous faint rising trace per wick.
 for j in range(3):
  verts=[];faces=[]
  for k in range(13):
   u=k/12;cx=.010*math.sin(u*8+j);width=.008+.013*u
   for sign in (-1,1):verts.append((cx+sign*width,.004*math.sin(u*11),u*.15))
  for k in range(12):faces.append((k*2,k*2+1,k*2+3,k*2+2))
  mesh=bpy.data.meshes.new('Feathered smoke wisp mesh');mesh.from_pydata(verts,[],faces);mesh.materials.append(smat);uv=mesh.uv_layers.new(name='SmokeUV')
  for p in mesh.polygons:
   for li in p.loop_indices:
    vi=mesh.loops[li].vertex_index;uv.data[li].uv=(vi%2,(vi//2)/12)
  ob=bpy.data.objects.new('Candle %02d light smoke %d'%(i,j),mesh);s.collection.objects.link(ob);ob.parent=root
  for f in range(1,290,3):
   age=((f-1)/144+j/3+i*.071)%1;size=max(.025,math.sin(math.pi*age)**.65)
   ob.location=fl.location+Vector((.018*math.sin(age*6+phase)*age,0,.045+age*.14));ob.scale=(size,size,size);ob.rotation_euler.z=.5*math.sin(age*5+phase);ob.keyframe_insert('location',frame=f);ob.keyframe_insert('scale',frame=f);ob.keyframe_insert('rotation_euler',frame=f)
 effects.append(dict(candle=i,flame=fl.name,smoke_wisps=3,root='fixed at original wick contact',phase=phase))
# Separate screen material and UV motion per inward-facing station.
stations=[(0,.18,0),(-.62,-.17,math.pi/4),(.62,-.17,-math.pi/4)]
screens=[]
for i,(cx,cy,yaw) in enumerate(stations):
 ob=bpy.data.objects['Console %d | recessed green doctrine CRT'%i];mat=ob.data.materials[0].copy();mat.name='Conclave V07 | slow doctrine CRT '+str(i);ob.data.materials[0]=mat;nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF');tex=next(n for n in nt.nodes if n.type=='TEX_IMAGE');uv=nt.nodes.new('ShaderNodeTexCoord');mapping=nt.nodes.new('ShaderNodeMapping');mapping.vector_type='POINT';nt.links.new(uv.outputs['UV'],mapping.inputs['Vector']);nt.links.new(mapping.outputs['Vector'],tex.inputs['Vector']);tex.extension='REPEAT'
 M=Matrix.Translation((cx,cy,0))@Matrix.Rotation(yaw,4,'Z');lamp=light('Console %d phosphor keyboard spill'%i,'AREA',M@Vector((0,-.13,1.08)),(.14,1,.035),1.8,.22,M@Vector((0,-.29,.83)))
 for f in range(1,290,3):
  mapping.inputs['Location'].default_value[1]=(f-1)/288+i*.13;mapping.inputs['Location'].keyframe_insert('default_value',frame=f);a=.93+.04*math.sin(TAU*(f-1)/288*19+i)+.025*math.sin(TAU*(f-1)/288*37+i);bs.inputs['Emission Strength'].default_value=.8*a;bs.inputs['Emission Strength'].keyframe_insert('default_value',frame=f);lamp.data.energy=1.8*a;lamp.data.keyframe_insert('energy',frame=f)
 screens.append(dict(screen=ob.name,scroll='one texture height upward per 12 seconds; repeat wrap',keyboard_light=lamp.name))
for name,sha in fixed.items():assert signature(bpy.data.objects[name])==sha,name
contacts=json.loads((O/'contacts.json').read_text())
for row in contacts:
 for key in ('a','b'):row[key]=row[key].replace('Arch candle static flame','Arch candle animated flame')
(O/'contacts.json').write_text(json.dumps(contacts,indent=2)+'\n')
for ob in s.objects:
 if ob.type=='MESH' and 'smoke' in ob.name:ob.visible_shadow=False
s.frame_set(1);s.cycles.samples=32
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='OPTIX'
s.cycles.device='GPU'
sys.path.insert(0,str(Path(__file__).parent));from positive_flame_keys import normalize_flame_keys;normalize_flame_keys(s)
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(O/'conclave-center-v07.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for ob in s.objects:
 if ob.type=='MESH':ob.select_set(True)
props={p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties};kwargs=dict(filepath=str(O/'conclave-center-v07.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=True,export_cameras=False,export_lights=False)
# KHR material animation is not assumed: the sprite capture evaluates source node
# animation. GLB carries real flame morphs and smoke transforms for independent review.
if 'export_animation_mode' in props:kwargs['export_animation_mode']='SCENE'
if 'export_anim_scene_split_object' in props:kwargs['export_anim_scene_split_object']=False
bpy.ops.export_scene.gltf(**kwargs)
(O/'ambient-motion.json').write_text(json.dumps(dict(stage='review candidate; native integration pending',duration_seconds=12,fps=24,source_frames=[1,288],loop_endpoint=289,candles=effects,screens=screens,construction_geometry_preserved=len(fixed),geometry_signatures=fixed,export_limit='GLB carries flame morphs and smoke transforms. Shader UV scroll, emission flicker and local lighting are evaluated in packed Blender source for runtime sprite baking; do not claim glTF shader animation parity.'),indent=2))
s.render.filepath=str(O/'source-front.png');bpy.ops.render.render(write_still=True)
print('V07_AGED_AMBIENT_SOURCE_AND_EXPORT_SAVED',flush=True)
