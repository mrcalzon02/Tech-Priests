"""Undistorted actual GLB inspection: no sprite-only Y compensation."""
import bpy,math,json,hashlib
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent;model=O/'void-steam-v02.glb';r=json.loads((O/'runtime-inspection.json').read_text());assert hashlib.sha256(model.read_bytes()).hexdigest()==r['runtime_sha256']
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.fps=48;bpy.ops.import_scene.gltf(filepath=str(model));s.frame_set(24)
s.render.engine='CYCLES';s.cycles.samples=32;s.render.resolution_x=s.render.resolution_y=640;s.render.resolution_percentage=100;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
s.world=bpy.data.worlds.new('Undistorted proportions studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.28,.28,.28,1)
for loc,power,size in [((2,-4,6),850,5),((-4,2,4),600,4)]:
 l=bpy.data.lights.new('Proportions area','AREA');l.energy=power;l.size=size;o=bpy.data.objects.new(l.name,l);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.9))-o.location).to_track_quat('-Z','Y').to_euler()
target=Vector((0,0,.95));c=bpy.data.cameras.new('UNSAVED true-proportion review');c.type='ORTHO';c.ortho_scale=3.20;camera=bpy.data.objects.new(c.name,c);s.collection.objects.link(camera);camera.location=(3,-5,3.4);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();s.camera=camera
root=bpy.data.objects['EXPORT | Void Steam Engine'];assert root.parent is None
s.render.filepath=str(O/'actual-glb-proportions.png');bpy.ops.render.render(write_still=True)
(O/'proportion-review.json').write_text(json.dumps({'runtime_sha256':r['runtime_sha256'],'view':'True world proportions, orthographic oblique inspection','sprite_y_compensation':False,'geometry_altered':False,'model_units_per_tile':1,'native_footprint':[2,2],'camera_location':list(camera.location),'camera_ortho_scale':c.ortho_scale,'previous_preview_issue':'The earlier oblique view retained sprite-only Y sqrt2 projection, stretching depth42percent and making width feel compressed.','owner_visual_approved':False},indent=2)+'\n')
print('VOID_UNDISTORTED_PROPORTIONS_RENDERED',flush=True)
