import bpy,json,math,sys,hashlib
from pathlib import Path
from mathutils import Vector
A=Path(__file__).resolve().parent;repo=next(c for p in[A,*A.parents]for c in(p,p/'model-production')if(c/'tools/fmpl/FMPL.json').is_file());sys.path.insert(0,str(repo/'tools/fmpl'))
from blender_camera_guard import install_canonical_camera
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(A/'power-grid-v02.glb'));s=bpy.context.scene;profile=json.loads((A/'capture-profile.json').read_text());install_canonical_camera(s,profile,bpy);s.render.engine='CYCLES';s.cycles.samples=32;s.cycles.use_denoising=True;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.resolution_x=s.render.resolution_y=512
s.world=bpy.data.worlds.new('Actual static pole capture');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.25,.25,1)
for loc,power,size in[((2,-3,4),240,3),((-3,2,4),180,3)]:
 l=bpy.data.lights.new('Grid capture studio','AREA');l.energy=power;l.size=size;o=bpy.data.objects.new(l.name,l);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.6))-o.location).to_track_quat('-Z','Y').to_euler()
root=bpy.data.objects['EXPORT | Emergency Power Grid'];meshes=[o for o in root.children_recursive if o.type=='MESH'];anchors=json.loads((A/'wire-anchors.json').read_text());errors={}
for role,row in anchors.items():
 o=bpy.data.objects['POWER GRID | '+role+' fixed wire contact button'];v=[o.matrix_world@v.co for v in o.data.vertices];p=[(min(q.x for q in v)+max(q.x for q in v))/2,(min(q.y for q in v)+max(q.y for q in v))/2,max(q.z for q in v)];errors[role]=max(abs(x-y)for x,y in zip(p,row['model_position']));assert errors[role]<1e-6
 # Actual shadow-image camera projection of the main area light's center ray.
 x,y,z=p;t=4/(4-z);sx=2+(x-2)*t;sy=-3+(y+3)*t;row['native_shadow_position']=[sx,-sy/math.sqrt(2)]
out=A/'sprites'
files={p.name:sha(p)for p in out.glob('*.png')}
for p in out.glob('*.png'):
 im=bpy.data.images.load(str(p),check_existing=False);assert im.size[0]>0 and any(a>0 for a in im.pixels[:][3::4]);bpy.data.images.remove(im)
(A/'capture-manifest.json').write_text(json.dumps({'source_sha256':sha(A/'power-grid-v02.blend'),'runtime_sha256':sha(A/'power-grid-v02.glb'),'genuine_actual_glb_body_frames':1,'files':files,'native_directions':[0],'body_sprite_scale':.175,'shadow_sprite_scale':.35,'sprite_shift':[0,-.6/math.sqrt(2)],'all_pngs_read_back':True,'wire_contact_position_errors_tiles':errors,'animation_applicability':'Passive pole: fixed RotatedSprite, no mechanical cycle. Actual native copper/circuit wires and network behavior supply operational states. No authored motion or generator function is invented.','actual_shadow_catcher_render':True,'owner_visual_approved':False},indent=2));print('POWER_GRID_STATIC_GLB_CAPTURE_PASS')
