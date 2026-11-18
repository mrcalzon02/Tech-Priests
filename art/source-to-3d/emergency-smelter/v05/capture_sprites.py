import bpy,json,math,sys,hashlib,struct
import numpy as np
from pathlib import Path
from mathutils import Vector
A=Path(__file__).resolve().parent;repo=next(p/'model-production'for p in A.parents if(p/'model-production/tools/fmpl').is_dir());sys.path.insert(0,str(repo/'tools/fmpl'))
from blender_camera_guard import install_canonical_camera
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();source=A/'smelter-v05.glb';bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.fps=48;bpy.ops.import_scene.gltf(filepath=str(source));profile=json.loads((A/'capture-profile.json').read_text());install_canonical_camera(s,profile,bpy);s.render.engine='CYCLES';s.cycles.samples=32;s.cycles.use_denoising=True;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.resolution_x=s.render.resolution_y=512
s.world=bpy.data.worlds.new('Actual GLB capture');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.25,.25,1)
for loc,power,size in[((2,-3,4),240,3),((-3,2,4),180,3)]:
 l=bpy.data.lights.new('Capture studio','AREA');l.energy=power;l.size=size;o=bpy.data.objects.new(l.name,l);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.5))-o.location).to_track_quat('-Z','Y').to_euler()
root=bpy.data.objects['EXPORT | Emergency Smelter'];projection=bpy.data.objects.new('UNSAVED square ground',None);s.collection.objects.link(projection);projection.scale.y=math.sqrt(2);root.parent=projection;meshes=[o for o in root.children_recursive if o.type=='MESH'];hot=[o for o in meshes if 'burner sight slit'in o.name];rec=[];temp=A/'capture-temp';temp.mkdir(exist_ok=True);out=A/'sprites';out.mkdir(exist_ok=True)
def render(name,frame,idle=False):
 # Source frame1 maps to imported runtime frame0 at48FPS.
 s.frame_set(frame-1)
 for o in hot:o.hide_render=idle
 p=temp/name;s.render.filepath=str(p);bpy.ops.render.render(write_still=True);rec.append({'file':name,'authored_frame':frame,'runtime_frame':frame-1,'idle_visibility':'Only the three fixed hot refractory sight inserts are hidden when idle.'if idle else'All actual GLB meshes visible.','sha256':sha(p)});return p
idle=render('idle.png',1,True)
working=[render('working-%02d.png'%k,1+4*k)for k in range(24)]
def pixels(p):
 im=bpy.data.images.load(str(p),check_existing=False);arr=np.array(im.pixels[:],dtype=np.float32).reshape(im.size[1],im.size[0],4);bpy.data.images.remove(im);return arr

def save(name,data):
 h,w,_=data.shape;im=bpy.data.images.new('Packed '+name,width=w,height=h,alpha=True,float_buffer=False);im.pixels.foreach_set(data.ravel());im.filepath_raw=str(out/name);im.file_format='PNG';im.save();bpy.data.images.remove(im);re=pixels(out/name);assert re.shape==data.shape and np.max(abs(re-data))<.01

def atlas(arrs):
 result=np.zeros((4*512,6*512,4),np.float32)
 for k,v in enumerate(arrs):row,col=divmod(k,6);result[(3-row)*512:(4-row)*512,col*512:(col+1)*512]=v
 return result
save('working.png',atlas([pixels(p)for p in working]));save('idle.png',atlas([pixels(idle)]*24))
# Actual shadow-catcher render: model invisible to camera, still casts its real shadow.
for o in meshes:o.visible_camera=False
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.002));plane=bpy.context.object;plane.is_shadow_catcher=True;s.frame_set(0);s.render.filepath=str(temp/'shadow.png');bpy.ops.render.render(write_still=True);shadow=pixels(temp/'shadow.png');save('shadow.png',shadow)
for o in meshes:o.visible_camera=True
bpy.data.objects.remove(plane,do_unlink=True)
# Genuine icon capture uses the same source, no raster recreation.
s.render.resolution_x=s.render.resolution_y=128;s.camera.data.ortho_scale=2.0;s.render.filepath=str(out/'icon.png');bpy.ops.render.render(write_still=True)
manifest={'source_sha256':sha(A/'smelter-v05.blend'),'runtime_sha256':sha(source),'genuine_actual_glb_frames':25,'records':rec,'files':{p.name:sha(p)for p in out.glob('*.png')},'native_directions':[0],'frames':24,'working_fps_at_actual_crafting_speed':12,'idle_atlas':'One genuine idle capture repeated24times to match native furnace frame-count schema.','shadow':'Actual Cycles shadow catcher with camera-invisible model.','idle_source_visibility':'Only three hot refractory sight inserts hidden; native furnace switches complete idle/working animations.','sprite_scale':.15,'sprite_shift':[0,-.5/math.sqrt(2)],'owner_visual_approved':False};(A/'capture-manifest.json').write_text(json.dumps(manifest,indent=2));print('SMELTER_ACTUAL_GLB_CAPTURE_COMPLETE',flush=True)
