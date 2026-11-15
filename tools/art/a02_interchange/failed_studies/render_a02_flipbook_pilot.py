"""Actual imported one-belt GLB diagnostic views; rejected pilot, not production art."""
import bpy,pathlib,json,hashlib
from mathutils import Vector
W=pathlib.Path(__file__).parent;O=W/'a02-belt-flipbook-pilot-20261114';bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.fps=24;bpy.ops.import_scene.gltf(filepath=str(O/'belt-discrete-24fps.glb'));s.frame_set(0);bpy.context.view_layer.update();active=[o for o in s.objects if o.type=='MESH' and o.scale.x>.5];assert len(active)==1;obj=active[0];points=[obj.matrix_world@Vector(p) for p in obj.bound_box];center=sum(points,Vector())/8
camera=bpy.data.objects.new('Diagnostic camera',bpy.data.cameras.new('Diagnostic camera'));s.collection.objects.link(camera);s.camera=camera;camera.data.type='ORTHO';camera.data.ortho_scale=1.4
s.world=bpy.data.worlds.new('Neutral world');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.08,.08,.08,1);s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
for name,offset,power,size in [('key',(2,-3,4),500,3),('fill',(-3,1,2),350,3)]:
 light=bpy.data.objects.new(name,bpy.data.lights.new(name,'AREA'));s.collection.objects.link(light);light.location=center+Vector(offset);light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler();light.data.energy=power;light.data.shape='DISK';light.data.size=size
s.render.engine='CYCLES';s.cycles.samples=16;s.cycles.use_denoising=True;s.render.threads_mode='FIXED';s.render.threads=2;s.render.resolution_x=s.render.resolution_y=512;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.film_transparent=True
records=[]
for name,offset in [('front',(2,-3,2)),('rear',(-2,3,2))]:
 camera.location=center+Vector(offset);camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();p=O/('actual-import-'+name+'.png');s.render.filepath=str(p);bpy.ops.render.render(write_still=True);records.append({'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(O/'render-receipt.json').write_text(json.dumps({'status':'REJECTED_PILOT_ACTUAL_IMPORT_DIAGNOSTIC_RENDERS','glb_sha256':hashlib.sha256((O/'belt-discrete-24fps.glb').read_bytes()).hexdigest(),'renders':records,'scope':'Isolated imported belt diagnostic only; no complete cap, owner approval or native game claim.'},indent=2)+'\n',encoding='utf-8',newline='\n')
