"""Independent source reopen, packed-image readback and GLB material audit."""
from pathlib import Path
import json,hashlib,struct
import bpy
ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'art/source-to-3d/faction-factories-v4'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
report={}
for model in ['martian','guard','sororitas']:
 folder=ART/'candidates'/model;source=folder/(model+'-source.blend')
 bpy.ops.wm.open_mainfile(filepath=str(source))
 images=[]
 for image in bpy.data.images:
  if image.type!='IMAGE':continue
  assert image.packed_file and min(image.size)>=2048,(model,image.name)
  assert image.has_data and len(image.pixels)>0,(model,image.name,'pixel readback')
  image.pixels[0]
  images.append({'name':image.name,'size':list(image.size),'packed':True,'readable':True})
 assert len(images)>=4
 components=bpy.data.collections.get('Editable source components - solo to edit')
 servo=bpy.context.scene.get('servo_joint_frames')
 if model=='martian':
  assert components and len(components.objects)>350 and servo
  joints=json.loads(servo)
  assert max(joints[k][1] for k in ['shoulder','elbow','wrist'])-min(joints[k][1] for k in ['shoulder','elbow','wrist'])<1e-6
 raw=(folder/(model+'.glb')).read_bytes();magic,version,total=struct.unpack_from('<III',raw,0)
 assert magic==0x46546C67 and version==2 and total==len(raw)
 length,kind=struct.unpack_from('<II',raw,12);gltf=json.loads(raw[20:20+length])
 material=gltf['materials'][0];pbr=material['pbrMetallicRoughness']
 assert 'baseColorTexture' in pbr and 'metallicRoughnessTexture' in pbr and 'normalTexture' in material
 assert all('bufferView' in image for image in gltf['images'])
 report[model]={'source_sha256':sha(source),'glb_sha256':sha(folder/(model+'.glb')),'packed_source_images':images,
  'external_glb_image_uris':False,'pbr_channels_verified':['baseColorTexture','metallicRoughnessTexture','normalTexture'],
  'editable_components':len(components.objects) if components else 'editable joined mesh and generator',
  'servo_joint_frames':json.loads(servo) if servo else None,'status':'PASS'}
(ART/'source-readback.json').write_text(json.dumps(report,indent=2)+'\n')
print('FACTORY_SOURCE_READBACK_PASS three reopened sources, packed pixels and embedded GLB PBR channels')
