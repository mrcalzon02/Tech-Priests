"""Reimport the actual GLB into the source lighting; independently review hidden sides."""
import bpy,json,pathlib,sys,hashlib
from mathutils import Vector
r=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();bpy.ops.wm.open_mainfile(filepath=str(r/'thetazine-v04-regenerative-study.blend'));s=bpy.context.scene;s.frame_set(1)
for o in list(s.objects):
 if o.type not in ['LIGHT','CAMERA']:bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(r/'thetazine-v04-regenerative-study.glb'));s.frame_set(17)
s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=16;s.render.threads_mode='FIXED';s.render.threads=2;s.render.resolution_x=s.render.resolution_y=800
for o in s.objects:
 if o.type=='MESH' and o.get('render_component')=='exhaust':o.hide_render=True
records=[]
for name,location,target,ortho,clay in [('export-front',(0,-13,13),(0,-1.7,-.5),11.8,False),('export-upper',(5,-5,6),(0,.15,.9),5.8,False),('export-fuel-screw',(-1.6,-5.65,6.05),(-1.6,-.65,1.05),2.5,False),('export-bell-rams',(5,-9,2.8),(0,-4.4,-1.9),5.8,False),('export-hinges',(3,-7,2.5),(0,-3.35,-1.35),3.2,False),('export-rear',(6,7,5),(0,-1.7,-.5),10.8,False),('export-rear-clay',(6,7,5),(0,-1.7,-.5),10.8,True)]:
 s.camera.location=location;s.camera.rotation_euler=(Vector(target)-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=ortho
 if clay:
  m=bpy.data.materials.new('Neutral geometry inspection');m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.32,.32,.32,1);bs.inputs['Metallic'].default_value=0;bs.inputs['Roughness'].default_value=.65;s.view_layers[0].material_override=m
 dest=r/(name+'.png');s.render.filepath=str(dest);bpy.ops.render.render(write_still=True);records.append({'file':dest.name,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'scope':'Actual imported GLB at frame17; FX hidden to inspect support geometry.'})
(r/'export-render-receipt.json').write_text(json.dumps({'native_sha256':hashlib.sha256((r/'thetazine-v04-regenerative-study.blend').read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256((r/'thetazine-v04-regenerative-study.glb').read_bytes()).hexdigest(),'files':records},indent=2)+'\n',encoding='utf-8',newline='\n');print('V04_EXPORTED_VIEWS',len(records))
