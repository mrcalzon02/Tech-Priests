import bpy,json,math,sys
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent;R=next((p for p in O.parents if (p/'tech-priests_src').is_dir()),O.parents[2])
sys.path.insert(0,str(R/'tools/fmpl' if (R/'tech-priests_src').is_dir() else R.parent/'model-production/tools/fmpl'))
from blender_camera_guard import install_canonical_camera,temporary_inspection_camera
profile=json.loads((O/'capture-profile.json').read_text());bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.fps=24;bpy.ops.import_scene.gltf(filepath=str(O/'sterling-v10.glb'));first=0
install_canonical_camera(s,profile,bpy);s.render.engine='CYCLES';s.cycles.samples=32;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
s.world=bpy.data.worlds.new('Sterling actual GLB neutral studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.28,.28,.28,1)
for loc,power,size in [((2,-4,6),900,5),((-4,2,4),600,4)]:
 l=bpy.data.lights.new('Actual GLB review area','AREA');l.energy=power;l.size=size;o=bpy.data.objects.new(l.name,l);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.7))-o.location).to_track_quat('-Z','Y').to_euler()
root=bpy.data.objects['EXPORT | Sterling actual boiler'];projection=bpy.data.objects.new('REVIEW ONLY | square ground projection',None);s.collection.objects.link(projection);projection.scale.y=math.sqrt(2);root.parent=projection;s.frame_set(int(first+25));s.render.resolution_x=s.render.resolution_y=512;review=bpy.data.objects.new('REVIEW ONLY | independent rear rotation',None);s.collection.objects.link(review);review.parent=projection;root.parent=review;review.rotation_euler.z=math.pi;s.render.filepath=str(O/'actual-glb-rear.png');bpy.ops.render.render(write_still=True)
review.rotation_euler.z=0
clay=bpy.data.materials.new('Sterling neutral clay inspection');clay.use_nodes=True;clay.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.22,.22,.22,1);s.view_layers[0].material_override=clay;s.render.filepath=str(O/'actual-glb-clay.png');bpy.ops.render.render(write_still=True)
print('STERLING_REAR_CLAY_REVIEW_RENDERED',flush=True)
