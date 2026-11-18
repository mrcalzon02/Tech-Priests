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
s.frame_set(0);s.render.resolution_x=s.render.resolution_y=128;s.camera.data.ortho_scale=2.0;s.render.filepath=str(out/'icon.png');bpy.ops.render.render(write_still=True)
p=A/'capture-manifest.json';d=json.loads(p.read_text());d['files']['icon.png']=sha(out/'icon.png');d['icon_camera_ortho_scale']=2.0;p.write_text(json.dumps(d,indent=2));print('ICON_COMPLETE_UNCROPPED')
