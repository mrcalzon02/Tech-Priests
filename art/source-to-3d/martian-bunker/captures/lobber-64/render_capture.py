"""Render one resumable 32-frame chunk plus optional idle/entry/settle states."""
import bpy,sys,argparse,json,hashlib,time,struct,zlib,shutil
from pathlib import Path
O=Path(__file__).resolve().parent;sys.path.insert(0,str(O))
from capture_common import C,pose
p=argparse.ArgumentParser();p.add_argument('--direction',type=int,default=0);p.add_argument('--chunk',type=int,default=0);p.add_argument('--out',default='rendered');p.add_argument('--pilot',action='store_true');a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
assert 0<=a.direction<64 and 0<=a.chunk<6
S=bpy.context.scene;S.render.threads_mode='FIXED';S.render.threads=4
D=Path(a.out).resolve()/f'd{a.direction:02}';D.mkdir(parents=True,exist_ok=True)
identity={'source_sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest(),'config_sha256':hashlib.sha256((O/'capture_config.json').read_bytes()).hexdigest(),'renderer_sha256':hashlib.sha256(Path(__file__).read_bytes()+(O/'capture_common.py').read_bytes()).hexdigest()}
identity_file=D/'identity.json'
if identity_file.exists():assert json.loads(identity_file.read_text())==identity,'Cached capture identity mismatch'
else:identity_file.write_text(json.dumps(identity,indent=2))
def valid_png(path,size):
 try:
  data=path.read_bytes();assert data[:8]==b'\x89PNG\r\n\x1a\n';pos=8;ended=False
  while pos<len(data):
   n=struct.unpack('>I',data[pos:pos+4])[0];kind=data[pos+4:pos+8];payload=data[pos+8:pos+8+n];crc=struct.unpack('>I',data[pos+8+n:pos+12+n])[0];assert zlib.crc32(kind+payload)&0xffffffff==crc
   if kind==b'IHDR':assert struct.unpack('>II',payload[:8])==(size,size) and payload[9]==6
   pos+=n+12
   if kind==b'IEND':ended=True;break
  return ended and pos==len(data)
 except (OSError,AssertionError,struct.error):return False
# Blender 5 compositor uses a node group and file_output_items.
tree=bpy.data.node_groups.new('Capture beauty and emission','CompositorNodeTree');tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
r=tree.nodes.new('CompositorNodeRLayers');r.layer='TOPPER';out=tree.nodes.new('NodeGroupOutput');tree.links.new(r.outputs['Image'],out.inputs['Image'])
alpha=tree.nodes.new('CompositorNodeSetAlpha');tree.links.new(r.outputs['Emission'],alpha.inputs['Image'])
luma=tree.nodes.new('CompositorNodeRGBToBW');tree.links.new(r.outputs['Emission'],luma.inputs[0]);tree.links.new(luma.outputs[0],alpha.inputs['Alpha'])
file=tree.nodes.new('CompositorNodeOutputFile');file.file_output_items.new('RGBA','Emission');file.format.media_type='IMAGE';file.format.file_format='PNG';file.format.color_mode='RGBA';file.format.color_depth='8';tree.links.new(alpha.outputs['Image'],file.inputs[0])
# Denoise the unclamped shadow-catcher light ratio before converting to a
# black alpha shadow. Denoising already-clamped Combined alpha leaves a haze.
S.view_layers[0].cycles.use_pass_shadow_catcher=True
shadow_tree=bpy.data.node_groups.new('Capture denoised neutral shadow','CompositorNodeTree');shadow_tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
sr=shadow_tree.nodes.new('CompositorNodeRLayers');sr.layer='TOPPER'
denoise=shadow_tree.nodes.new('CompositorNodeDenoise');shadow_tree.links.new(sr.outputs['Shadow Catcher'],denoise.inputs['Image'])
sl=shadow_tree.nodes.new('CompositorNodeRGBToBW');shadow_tree.links.new(denoise.outputs['Image'],sl.inputs[0])
inv=shadow_tree.nodes.new('ShaderNodeMath');inv.operation='SUBTRACT';inv.inputs[0].default_value=1;inv.use_clamp=True;shadow_tree.links.new(sl.outputs[0],inv.inputs[1])
# Finite, softly bounded receiving footprint: retain the central physical
# shadow and fade distant ambient tails before the sprite edge.
from array import array
import math
mask=bpy.data.images.new('Registered soft receiver',width=C['shadow_size'],height=C['shadow_size'],alpha=True,float_buffer=True);pixels=array('f');mc=C['shadow_receiver_mask'];cx,cy=mc['center'];rx,ry=mc['radii'];start=mc['fade_start']
for y in range(C['shadow_size']):
 for x in range(C['shadow_size']):
  radius=math.sqrt(((x-cx)/rx)**2+((C['shadow_size']-1-y-cy)/ry)**2);t=max(0,min(1,(radius-start)/(1-start)));value=1-t*t*(3-2*t);pixels.extend((value,value,value,1))
mask.pixels.foreach_set(pixels);mi=shadow_tree.nodes.new('CompositorNodeImage');mi.image=mask;mul=shadow_tree.nodes.new('ShaderNodeMath');mul.operation='MULTIPLY';shadow_tree.links.new(inv.outputs[0],mul.inputs[0]);shadow_tree.links.new(mi.outputs['Image'],mul.inputs[1])
sa=shadow_tree.nodes.new('CompositorNodeSetAlpha');sa.inputs['Image'].default_value=(0,0,0,1);shadow_tree.links.new(mul.outputs[0],sa.inputs['Alpha']);so=shadow_tree.nodes.new('NodeGroupOutput');shadow_tree.links.new(sa.outputs['Image'],so.inputs['Image'])
receiver=bpy.data.objects['CAPTURE_SHADOW_RECEIVER'];camera_scale=C['ortho_scale'];times=[]
def render(mode,f):
 paths={pas:D/pas/f'{mode}_{f:03}.png' for pas in C['passes']}
 if all(valid_png(path,C['shadow_size'] if pas=='shadow' else C['beauty_size']) for pas,path in paths.items()):return
 pose(a.direction,f,mode);receiver.hide_render=True
 S.render.resolution_x=S.render.resolution_y=C['beauty_size'];S.camera.data.ortho_scale=camera_scale;S.compositing_node_group=tree
 for path in paths.values():path.parent.mkdir(exist_ok=True)
 temp=D/'_emission';temp.mkdir(exist_ok=True)
 for q in temp.glob('*.png'):q.unlink()
 file.directory=str(temp);file.file_name='emission';S.render.filepath=str(paths['beauty']);t=time.monotonic();bpy.ops.render.render(write_still=True)
 emitted=list(temp.rglob('*.png'));assert len(emitted)==1,emitted;shutil.move(str(emitted[0]),paths['emission'])
 S.compositing_node_group=shadow_tree;receiver.hide_render=False
 visible=[]
 for o in S.objects:
  if o.type in ['MESH','CURVE'] and o!=receiver and o.visible_camera:visible.append(o);o.visible_camera=False
 S.render.resolution_x=S.render.resolution_y=C['shadow_size'];S.camera.data.ortho_scale=camera_scale*C['shadow_size']/C['beauty_size'];S.render.filepath=str(paths['shadow'])
 bpy.ops.render.render(write_still=True)
 for o in visible:o.visible_camera=True
 receiver.hide_render=True
 for pas,path in paths.items():assert valid_png(path,C['shadow_size'] if pas=='shadow' else C['beauty_size']),(pas,path)
 times.append(time.monotonic()-t);print('CAPTURE_COMPLETE',a.direction,mode,f,'seconds',times[-1],flush=True)
if a.pilot:
 for mode,f in [('idle',0),('cycle',1),('cycle',4)]:render(mode,f)
else:
 for f in range(a.chunk*32,(a.chunk+1)*32):render('cycle',f)
 if a.chunk==0:
  render('idle',0)
  for f in range(C['entry_frames']):render('entry',f)
 if a.chunk==5:
  for f in range(C['settle_frames']):render('settle',f)
(D/f'chunk_{a.chunk:02}.json').write_text(json.dumps({'direction':a.direction,'chunk':a.chunk,'pilot':a.pilot,'frame_times_seconds':times,'identity':identity},indent=2))
print('LOBBER_CAPTURE_REQUEST_COMPLETE',flush=True)
