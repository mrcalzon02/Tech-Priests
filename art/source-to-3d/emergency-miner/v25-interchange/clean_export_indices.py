"""Remove only measured zero-area and sub-nanounit UV slivers from interchange indices.
Preserves every vertex, transform, rig key, material, image and approved source byte.
"""
from pathlib import Path
import json,struct,math,hashlib
R=Path(__file__).resolve().parent;A=R/'interchange-v01';p=A/'miner-v25-physical.glb';raw=p.read_bytes();jn=struct.unpack_from('<I',raw,12)[0];j=json.loads(raw[20:20+jn]);off=20+jn;bn=struct.unpack_from('<I',raw,off)[0];blob=bytearray(raw[off+8:off+8+bn]);before=hashlib.sha256(raw).hexdigest();rows=[]
def data(index):
 a=j['accessors'][index];v=j['bufferViews'][a['bufferView']];fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']];count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']];fmt='<'+fmt*count;size=struct.calcsize(fmt);start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',size);return[struct.unpack_from(fmt,blob,start+i*stride)for i in range(a['count'])]
for mesh in j['meshes']:
 for prim in mesh['primitives']:
  assert prim.get('mode',4)==4;pos=data(prim['attributes']['POSITION']);uv=data(prim['attributes']['TEXCOORD_0']);ind=[x[0]for x in data(prim['indices'])];keep=[];removed=[]
  for i in range(0,len(ind),3):
   ids=ind[i:i+3];a,b,c=[pos[k]for k in ids];u=[b[k]-a[k]for k in range(3)];v=[c[k]-a[k]for k in range(3)];cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];area=math.sqrt(sum(x*x for x in cross))*.5;a,b,c=[uv[k]for k in ids];ua=abs((b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]))
   if area<1e-14 or ua<1e-14:
    assert area<1e-9,(mesh['name'],area);removed.append({'area':area,'uv_area':ua})
   else:keep+=ids
  if not removed:continue
  assert keep,mesh['name']
  while len(blob)%4:blob.append(0)
  start=len(blob);buf=struct.pack('<'+'I'*len(keep),*keep);blob.extend(buf);view=len(j['bufferViews']);j['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(buf),'target':34963});acc=len(j['accessors']);j['accessors'].append({'bufferView':view,'componentType':5125,'count':len(keep),'type':'SCALAR','min':[min(keep)],'max':[max(keep)]});prim['indices']=acc;rows.append({'mesh':mesh['name'],'removed':removed})
j['buffers'][0]['byteLength']=len(blob);js=json.dumps(j,separators=(',',':')).encode()
while len(js)%4:js+=b' '
while len(blob)%4:blob.append(0)
out=struct.pack('<III',0x46546c67,2,12+8+len(js)+8+len(blob))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(blob),0x004e4942)+blob;p.write_bytes(out)
(A/'export-index-cleanup.json').write_text(json.dumps({'source_export_sha256':before,'cleaned_export_sha256':hashlib.sha256(out).hexdigest(),'removed_triangles':sum(len(r['removed'])for r in rows),'vertex_transform_rig_material_and_image_data_unchanged':True,'only_zero_geometry_or_zero_uv_sub_nanounit_slivers_removed':True,'rows':rows},indent=2));print('CLEANED_ONLY_DEGENERATE_EXPORT_TRIANGLES',sum(len(r['removed'])for r in rows))
