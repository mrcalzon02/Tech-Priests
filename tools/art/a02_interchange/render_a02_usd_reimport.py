"""Render the independently imported evaluated USD, never the source model as a substitute."""
import bpy,pathlib,json,hashlib,math
from mathutils import Matrix
W=pathlib.Path(__file__).parent;O=W/'a02-evaluated-usd-20261114';SRC=W/'lobber-a02/lobber_capture.blend';bpy.ops.wm.open_mainfile(filepath=str(SRC));s=bpy.context.scene;rig=set(bpy.data.collections['CAPTURE_RIG'].all_objects)
for obj in list(s.objects):
 if obj not in rig:bpy.data.objects.remove(obj,do_unlink=True)
receiver=bpy.data.objects.get('CAPTURE_SHADOW_RECEIVER')
if receiver:receiver.hide_render=True
s.render.fps=24;before=set(bpy.data.objects);bpy.ops.wm.usd_import(filepath=str(O/'idle.usdc'),import_cameras=False,import_lights=False,import_volumes=False,import_visible_only=False,import_subdivision=False,read_mesh_uvs=True,import_materials=True,import_textures_mode='IMPORT_PACK',validate_meshes=False);objects=set(bpy.data.objects)-before;meshes=[o for o in objects if o.type=='MESH'];assert len(meshes)==302,len(meshes)
images=[]
for mat in {m for o in meshes for m in o.data.materials if m and m.use_nodes}:
 for n in mat.node_tree.nodes:
  if n.type=='TEX_IMAGE' and n.image:
   im=n.image;assert im.size[0]>0 and im.size[1]>0;images.append({'image':im.name,'size':list(im.size),'packed':bool(im.packed_file)})
assert len({i['image'] for i in images})==2,images
s.render.engine='CYCLES';s.cycles.samples=16;s.cycles.use_denoising=True;s.render.resolution_x=s.render.resolution_y=640;s.render.resolution_percentage=100;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.threads_mode='FIXED';s.render.threads=4
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices();selected=[]
for dev in prefs.devices:
 dev.use=dev.type=='OPTIX'
 if dev.use:selected.append(dev.name)
if selected:s.cycles.device='GPU'
camera=s.camera;base=camera.matrix_world.copy();s.frame_set(1);records=[]
for name,angle in [('front',0),('rear',180),('left',90),('right',270)]:
 camera.matrix_world=Matrix.Rotation(math.radians(angle),4,'Z')@base;path=O/('imported-usd-'+name+'.png');s.render.filepath=str(path);bpy.ops.render.render(write_still=True);records.append({'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()});print('ACTUAL_IMPORTED_USD_RENDERED',name,flush=True)
report={'status':'FOUR_ACTUAL_USD_IMPORT_RENDERS_REQUIRE_VISUAL_REVIEW','usd_sha256':hashlib.sha256((O/'idle.usdc').read_bytes()).hexdigest(),'imported_meshes':len(meshes),'loaded_images':images,'renders':records,'render_backend':selected or ['CPU'],'preferences_saved':False,'scope':'Actual USD import; native capture camera/world/area lights retained, source geometry removed before import. No native game integration or final owner approval claimed.'};(O/'imported-render-receipt.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
