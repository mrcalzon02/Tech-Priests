import argparse,bpy,hashlib,json,math,pathlib,sys
from mathutils import Vector
parser=argparse.ArgumentParser();parser.add_argument('directory',type=pathlib.Path);parser.add_argument('--source',type=pathlib.Path,required=True);args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);out=args.directory.resolve();(out/'renders').mkdir(exist_ok=True)
source=args.source.resolve()
views={'front':(3,-5,3.5),'rear':(-3,5,3.5),'left':(-4,-4,3.5),'right':(4,4,3.5)}
receipts=[]
def setup():
 s=bpy.context.scene;s.frame_set(0);s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=12;s.cycles.use_denoising=True;s.render.threads_mode='FIXED';s.render.threads=2
 s.render.resolution_x=s.render.resolution_y=640;s.render.resolution_percentage=100;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.use_compositing=False;s.render.use_sequencer=False
 s.render.image_settings.color_depth='8';s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast';s.view_settings.exposure=0;s.view_settings.gamma=1
 return s
def render(label,view,clay=False):
 s=setup();cam=s.camera;cam.location=views[view];target=Vector((0,.15,.57));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.65
 s.view_layers[0].material_override=None
 if clay:
  mat=bpy.data.materials.get('Inspection neutral clay') or bpy.data.materials.new('Inspection neutral clay');mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.32,.32,.32,1);bs.inputs['Metallic'].default_value=0;bs.inputs['Roughness'].default_value=.65;s.view_layers[0].material_override=mat
 dest=out/'renders'/(label+'-'+view+'.png');s.render.filepath=str(dest);bpy.ops.render.render(write_still=True);receipts.append({'file':dest.name,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'width':640,'height':640,'source':label,'view':view,'clay':clay})
 (out/'render-receipt.json').write_text(json.dumps({'status':'PARTIAL' if len(receipts)<8 else 'CAPTURED_REQUIRES_VISUAL_REVIEW','renders':receipts,'samples':12,'device':'CPU','threads':2},indent=2)+'\n',encoding='utf-8')
bpy.ops.wm.open_mainfile(filepath=str(source))
for view in ['front','rear']:render('approved-source',view)
# Retain the exact authored lighting/world, remove only model objects, import the actual GLB.
for o in list(bpy.context.scene.objects):
 if o.type not in ['LIGHT','CAMERA']:bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(out/'boiler-v08-cold.glb'))
for view in views:render('glb',view)
for view in ['front','rear']:render('glb-clay',view,True)
print('RENDERED',len(receipts),flush=True)
