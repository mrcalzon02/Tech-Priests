import argparse,collections,hashlib,io,json,pathlib,struct
import numpy as np
from PIL import Image
parser=argparse.ArgumentParser();parser.add_argument('directory',type=pathlib.Path);args=parser.parse_args();root=args.directory.resolve();p=root/'thetazine-v04-regenerative-study.glb';raw=p.read_bytes();magic,version,length=struct.unpack_from('<III',raw);assert magic==0x46546c67 and version==2 and length==len(raw)
offset=12;chunks={}
while offset<len(raw):
 n,t=struct.unpack_from('<II',raw,offset);chunks[t]=raw[offset+8:offset+8+n];offset+=8+n
j=json.loads(chunks[0x4e4f534a]);blob=chunks[0x004e4942]
def accessor(index):
 a=j['accessors'][index];v=j['bufferViews'][a['bufferView']];types={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'};width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']];dtype=np.dtype(types[a['componentType']]);start=v.get('byteOffset',0)+a.get('byteOffset',0)
 return np.ndarray((a['count'],width),dtype=dtype,buffer=blob,offset=start,strides=(v.get('byteStride',width*dtype.itemsize),dtype.itemsize)).copy()
parts=[];total=0;failures=[]
for mesh in j['meshes']:
 tris=zero=uvzero=0;normal_error=0;all_bounds=[]
 for prim in mesh['primitives']:
  assert prim.get('mode',4)==4
  pos=accessor(prim['attributes']['POSITION']);uv=accessor(prim['attributes']['TEXCOORD_0']);normal=accessor(prim['attributes']['NORMAL']);indices=accessor(prim['indices']).reshape(-1,3)
  assert np.isfinite(pos).all() and np.isfinite(uv).all() and np.isfinite(normal).all()
  pts=pos[indices].astype(np.float64);area=np.linalg.norm(np.cross(pts[:,1]-pts[:,0],pts[:,2]-pts[:,0]),axis=1)/2
  zero+=int(sum(area<5e-13))
  if np.min(area)<5e-13:failures.append({'mesh':mesh['name'],'collapsed_geometric_triangles':int(sum(area<5e-13))})
  q=uv[indices].astype(np.float64);a=q[:,1]-q[:,0];b=q[:,2]-q[:,0];uarea=np.abs(a[:,0]*b[:,1]-a[:,1]*b[:,0])/2
  mat=j['materials'][prim['material']];textured=bool(mat.get('pbrMetallicRoughness',{}).get('baseColorTexture'))
  if textured and not (uarea>1e-12).all():failures.append({'mesh':mesh['name'],'collapsed_textured_uv_triangles':int(sum(uarea<=1e-12))})
  uvzero+=int(sum(uarea<=1e-12));tris+=len(indices);normal_error=max(normal_error,float(np.max(np.abs(np.linalg.norm(normal,axis=1)-1))))
  all_bounds.append([pos.min(axis=0).tolist(),pos.max(axis=0).tolist()])
 assert normal_error<1e-5,(mesh['name'],normal_error)
 parts.append({'name':mesh['name'],'triangles':tris,'degenerate_triangles':zero,'degenerate_uv_triangles':uvzero,'max_normal_length_error':normal_error});total+=tris
images=[]
for i in j.get('images',[]):
 v=j['bufferViews'][i['bufferView']];b=blob[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']]
 with Image.open(io.BytesIO(b)) as im:im.verify()
 with Image.open(io.BytesIO(b)) as im:im.load();size=list(im.size)
 images.append({'name':i.get('name'),'bytes':len(b),'size':size,'sha256':hashlib.sha256(b).hexdigest()})
materials=[]
for m in j['materials']:
 pbr=m.get('pbrMetallicRoughness',{});materials.append({'name':m.get('name'),'base_color_texture':pbr.get('baseColorTexture'),'metallic_roughness_texture':pbr.get('metallicRoughnessTexture'),'normal_texture':m.get('normalTexture'),'emissive_texture':m.get('emissiveTexture'),'alpha_mode':m.get('alphaMode','OPAQUE'),'extensions':list(m.get('extensions',{}))})
out={'status':'RAW_GLB_AUDIT_FAIL' if failures else 'RAW_GLB_GEOMETRY_UV_NORMAL_IMAGE_AUDIT_PASS','failures':failures,'glb_sha256':hashlib.sha256(raw).hexdigest(),'mesh_count':len(parts),'triangle_count':total,'parts':parts,'images':images,'materials':materials,'nodes':j['nodes'],'animations':len(j.get('animations',[]))}
(root/'raw-glb-audit.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8');print('GLB',len(parts),'meshes',total,'triangles',len(images),'embedded images',len(materials),'materials')
if failures:print(json.dumps(failures));raise SystemExit(1)
