import json,struct,pathlib,numpy as np
P=pathlib.Path(__file__).parent/'a02-belt-flipbook-pilot-20261114';raw=(P/'belt-discrete-24fps.glb').read_bytes();jlen=struct.unpack_from('<I',raw,12)[0];d=json.loads(raw[20:20+jlen]);blob=raw[28+jlen:]
def a(i):
 q=d['accessors'][i];v=d['bufferViews'][q['bufferView']];kind={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[q['componentType']];width={'VEC3':3,'VEC2':2,'SCALAR':1}[q['type']];return np.frombuffer(blob,dtype=kind,count=q['count']*width,offset=v.get('byteOffset',0)+q.get('byteOffset',0)).reshape(q['count'],width)
def rows(c,n):
 order=np.lexsort((c[:,:,2],c[:,:,1],c[:,:,0]),axis=1);x=np.concatenate([np.take_along_axis(c,order[:,:,None],axis=1),np.take_along_axis(n,order[:,:,None],axis=1)],axis=2).reshape(-1,18);pos=x[:,[0,1,2,6,7,8,12,13,14]];sort=np.lexsort(tuple(np.round(pos.astype(np.float64),5)[:,i] for i in reversed(range(9))));return x[sort]
records=[]
for node in d['nodes']:
 if not node.get('name','').startswith('A02_BELT_SAMPLE_'):continue
 frame=int(node['name'].rsplit('_',1)[-1]);p=d['meshes'][node['mesh']]['primitives'][0];c=a(p['attributes']['POSITION']);n=a(p['attributes']['NORMAL']);ix=a(p['indices']).reshape(-1,3);c=c[:,[0,2,1]]*np.array([1,-1,1]);n=n[:,[0,2,1]]*np.array([1,-1,1]);ref=np.load(P/f'source-{frame:03}.npz');old=rows(ref['corners'],ref['normals']);new=rows(c[ix],n[ix]);pc=[0,1,2,6,7,8,12,13,14];nc=[3,4,5,9,10,11,15,16,17];records.append({'frame':frame,'position_error':float(abs(old[:,pc]-new[:,pc]).max()),'normal_error':float(abs(old[:,nc]-new[:,nc]).max()),'source_normal_length_min':float(np.linalg.norm(ref['normals'],axis=2).min())})
out={'status':'RAW_BUFFER_DIAGNOSTIC','frames':records,'max_position_error':max(r['position_error'] for r in records),'max_normal_error':max(r['normal_error'] for r in records)};(P/'raw-buffer-diagnostic.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8');print({k:v for k,v in out.items() if k!='frames'});print(records[0])
