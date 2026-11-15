"""Missing energy-dish idle shadow pass only; exact existing bunker camera/receiver."""
import bpy,pathlib,sys,json,hashlib,math,os
W=pathlib.Path(__file__).parent;R=pathlib.Path('C:/GITS/Tech-Priests');P=R/'art/source-to-3d/martian-bunker/alternatives/energy-dish-v03';O=W/'energy-dish-v03-shadow64-sharp';O.mkdir(exist_ok=True);pilot='--pilot' in sys.argv;sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(P/'energy_dish_v03.blend')=='b4851a3cfca888e51eff8f77ba12e0adc8d216b65304448aaefc40bb1cdc5c71'
src=W/'lobber-a02/lobber_capture.blend';assert sha(src)=='0c9ebf42b16ddd53a8162d836bb88a052c77f16c28f4e7265172300797e372ed';bpy.ops.wm.open_mainfile(filepath=str(src));receiver=bpy.data.objects['CAPTURE_SHADOW_RECEIVER'].copy();receiver.data=receiver.data.copy();matrix=receiver.matrix_world.copy()
sys.argv=['blender','--',str(P/'energy_dish_v03.blend'),str(O/'loader-metadata')]
code=(P/'capture_dish_idle64.py').read_text(encoding='utf-8').split('completed=[]')[0];exec(compile(code,str(P/'capture_dish_idle64.py'),'exec'))
S.collection.objects.link(receiver);receiver.parent=None;receiver.matrix_world=matrix;receiver.name='CAPTURE_SHADOW_RECEIVER';receiver.hide_render=False;receiver.is_shadow_catcher=True
C=json.loads((W/'lobber-a02/capture_config.json').read_text());rendercode=(W/'lobber-a02/render_capture.py').read_text();block=rendercode.split('S.view_layers[0].cycles.use_pass_shadow_catcher=True',1)[1].split("receiver=bpy.data.objects['CAPTURE_SHADOW_RECEIVER']",1)[0];S.view_layers[0].name='TOPPER';S.view_layers[0].cycles.use_pass_shadow_catcher=True;exec('S.view_layers[0].cycles.use_pass_shadow_catcher=True\n'+block)
S.render.use_compositing=True;S.compositing_node_group=shadow_tree;S.render.resolution_x=S.render.resolution_y=C['shadow_size'];camera.data.ortho_scale=C['ortho_scale']*C['shadow_size']/C['beauty_size'];S.render.threads_mode='FIXED';S.render.threads=4;S.render.compositor_device='CPU'
devices=bpy.context.preferences.addons['cycles'].preferences;devices.compute_device_type='OPTIX';devices.get_devices();selected=[]
for dev in devices.devices:
 dev.use=dev.type=='OPTIX'
 if dev.use:selected.append(dev.name)
S.cycles.device='GPU' if selected else 'CPU'
for obj in S.objects:
 if obj.type=='MESH' and obj!=receiver:obj.visible_camera=False
# Shadow-only graphical derivative: preserve original key direction; eliminate duplicate fill/rim projections.
for light in S.objects:
 if light.type=='LIGHT':
  if light.name.startswith('01 |'):light.data.size=.25
  else:light.data.energy=0
for node in S.world.node_tree.nodes:
 if node.type=='BACKGROUND':node.inputs['Strength'].default_value=0
identity={'dish_sha256':sha(P/'energy_dish_v03.blend'),'camera_source_sha256':sha(src),'script_sha256':sha(pathlib.Path(__file__)),'shadow_renderer_source_sha256':sha(W/'lobber-a02/render_capture.py'),'config_sha256':sha(W/'lobber-a02/capture_config.json'),'size':C['shadow_size'],'camera_ortho_scale':camera.data.ortho_scale,'camera_matrix':[list(row) for row in camera.matrix_world],'backend':selected or ['CPU'],'samples':16,'mapping':'N0/E16/S32/W48; clockwise yaw180-direction*5.625','receiver':'Original calibrated A02 catcher and soft footprint mask; same fixed bunker mounting frame','lighting_derivative':'Original NW key location/direction/energy; area size0.25; fill/rim and world illumination disabled for a single readable shadow. Beauty remains unchanged.','scope':'Idle shadow only; no beauty recapture, firing state, native integration or source edit'}
ip=O/'shadow-identity.json'
if ip.exists():assert json.loads(ip.read_text())==identity,'Identity mismatch; preserve prior outputs'
else:ip.write_text(json.dumps(identity,indent=2)+'\n',encoding='utf-8',newline='\n')
completed=[]
for direction in ([0,16,32,48] if pilot else range(64)):
 path=O/f'shadow-{direction:02}.png'
 if not path.exists():root.rotation_euler.z=math.radians(180-direction*5.625);bpy.context.view_layer.update();S.render.filepath=str(path);bpy.ops.render.render(write_still=True)
 check=bpy.data.images.load(str(path),check_existing=False);assert tuple(check.size)==(1280,1280);bpy.data.images.remove(check);completed.append({'direction':direction,'sha256':sha(path)})
 (O/'CHECKPOINT.json').write_text(json.dumps({'status':'PILOT_REQUIRES_VISUAL_REVIEW' if pilot else ('SHADOW64_RENDERED_REQUIRES_DECODE_ATLAS_REVIEW' if len(completed)==64 else 'RENDERING_SHADOWS'),'pid':os.getpid(),'completed':completed,'identity':identity},indent=2)+'\n',encoding='utf-8',newline='\n');print('DISH_SHADOW_CAPTURED',direction,flush=True)
