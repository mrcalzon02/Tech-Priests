import bpy,json,pathlib,sys,hashlib
from mathutils import Vector
r=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();bpy.ops.wm.open_mainfile(filepath=str(r/'hydrogen-thruster-v01.blend'));s=bpy.context.scene;s.frame_set(0)
for o in list(s.objects):
 if o.type not in ['LIGHT','CAMERA']:bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(r/'hydrogen-thruster-v01.glb'))
s.render.resolution_x=s.render.resolution_y=640;s.camera.data.ortho_scale=8.4;target=Vector((0,-1.3,-.5));records=[]
for name,location,clay in [('oblique',(6,-7,4),False),('rear',(6,5,4),False),('rear-clay',(6,5,4),True)]:
 s.camera.location=location;s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler()
 if clay:
  m=bpy.data.materials.new('Neutral inspected geometry');m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.32,.32,.32,1);bs.inputs['Metallic'].default_value=0;bs.inputs['Roughness'].default_value=.65;s.view_layers[0].material_override=m
 dest=r/(name+'.png');s.render.filepath=str(dest);bpy.ops.render.render(write_still=True);records.append({'file':dest.name,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'scope':'Actual independently reimported GLB inspection in source lighting, hidden-side support and routed interfaces; clay removes material distraction.'})
(r/'review-render-receipt.json').write_text(json.dumps({'native_model_sha256':hashlib.sha256((r/'hydrogen-thruster-v01.blend').read_bytes()).hexdigest(),'actual_glb_sha256':hashlib.sha256((r/'hydrogen-thruster-v01.glb').read_bytes()).hexdigest(),'files':records},indent=2)+'\n',encoding='utf-8');print('MODEL_REVIEW_RENDERED',len(records))
