"""Non-destructive evaluated GLTF pilot for one topology-changing A02 loader belt."""
import bpy,pathlib,json,hashlib,struct,os,numpy as np
W=pathlib.Path(__file__).parent;O=W/'a02-belt-flipbook-pilot-20261114';assert not O.exists(),'Inspect checkpoint instead of duplicating pilot';O.mkdir()
SRC=W/'a02-gltf-20261114/cycle-derivative.blend';ORIGINAL=W/'lobber-a02/lobber_capture.blend';EXPECTED='0c9ebf42b16ddd53a8162d836bb88a052c77f16c28f4e7265172300797e372ed';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();assert sha(ORIGINAL)==EXPECTED
name='CONTINUOUS_SEGMENTED_RUBBER_TRACK_LEFT_3_ANIM_L';state={'status':'SAMPLING_ONE_BELT','pid':os.getpid(),'original_source_sha256':EXPECTED,'derivative_sha256':sha(SRC),'target':name,'frames':193,'fps':24,'completed_samples':0}
def save(): (O/'CHECKPOINT.json').write_text(json.dumps(state,indent=2)+'\n',encoding='utf-8',newline='\n')
save();bpy.ops.wm.open_mainfile(filepath=str(SRC));s=bpy.context.scene;source=bpy.data.objects[name];objects=[];references=[]
for frame in range(1,194):
 s.frame_set(frame);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();ev=source.evaluated_get(dg);mesh=bpy.data.meshes.new_from_object(ev,preserve_all_data_layers=True,depsgraph=dg);mesh.transform(source.matrix_world);obj=bpy.data.objects.new(f'A02_BELT_SAMPLE_{frame:03}',mesh);s.collection.objects.link(obj);objects.append(obj);mesh.calc_loop_triangles()
 coords=np.asarray([v.co[:] for v in mesh.vertices],dtype=np.float32);indices=np.asarray([t.vertices[:] for t in mesh.loop_triangles],dtype=np.int32);normals=np.asarray([n.vector[:] for n in mesh.corner_normals],dtype=np.float32);loopids=np.asarray([t.loops[:] for t in mesh.loop_triangles],dtype=np.int32)
 np.savez_compressed(O/f'source-{frame:03}.npz',corners=coords[indices],normals=normals[loopids]);references.append({'frame':frame,'vertices':len(mesh.vertices),'triangles':len(mesh.loop_triangles),'reference_sha256':sha(O/f'source-{frame:03}.npz')});state['completed_samples']=frame
 if frame%24==0:save();print('BELT_EVALUATED_SAMPLE',frame,flush=True)
for obj in list(s.objects):
 if obj not in objects:bpy.data.objects.remove(obj,do_unlink=True)
s.frame_set(1);bpy.ops.object.select_all(action='SELECT');state['status']='EXPORTING_STATIC_EVALUATED_POSE_MESHES';save();dest=O/'belt-discrete-24fps.glb'
bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_apply=False,export_normals=True)
raw=dest.read_bytes();off=12;chunks=[]
while off<len(raw):
 size,kind=struct.unpack_from('<II',raw,off);chunks.append((kind,raw[off+8:off+8+size]));off+=8+size
doc=json.loads(next(data for kind,data in chunks if kind==0x4e4f534a));binary=bytearray(next(data for kind,data in chunks if kind==0x004e4942));views=doc.setdefault('bufferViews',[]);accessors=doc.setdefault('accessors',[])
def accessor(data,kind,count,minimum=None,maximum=None):
 while len(binary)%4:binary.append(0)
 view=len(views);views.append({'buffer':0,'byteOffset':len(binary),'byteLength':len(data)});binary.extend(data);a={'bufferView':view,'componentType':5126,'count':count,'type':kind}
 if minimum is not None:a['min']=minimum;a['max']=maximum
 accessors.append(a);return len(accessors)-1
times=np.arange(193,dtype=np.float32)/24;time_accessor=accessor(times.tobytes(),'SCALAR',193,[0.],[8.]);samplers=[];channels=[]
for index,node in enumerate(doc['nodes']):
 if not node.get('name','').startswith('A02_BELT_SAMPLE_'):continue
 frame=int(node['name'].rsplit('_',1)[-1]);values=np.zeros((193,3),dtype=np.float32);values[frame-1]=1;node.pop('matrix',None);node['scale']=[1,1,1] if frame==1 else [0,0,0];samplers.append({'input':time_accessor,'output':accessor(values.tobytes(),'VEC3',193),'interpolation':'STEP'});channels.append({'sampler':len(samplers)-1,'target':{'node':index,'path':'scale'}})
assert len(channels)==193;doc['animations']=[{'name':'A02_one_belt_cycle_discrete_24fps','samplers':samplers,'channels':channels}];doc['buffers'][0]['byteLength']=len(binary);j=json.dumps(doc,separators=(',',':')).encode();j+=b' '*((-len(j))%4);binary+=b'\x00'*((-len(binary))%4);payload=struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(binary),0x004e4942)+binary;dest.write_bytes(struct.pack('<III',0x46546c67,2,12+len(payload))+payload)
(O/'source-samples.json').write_text(json.dumps(references,indent=2)+'\n',encoding='utf-8',newline='\n');state.update(status='ONE_BELT_DISCRETE_GLTF_REQUIRES_INDEPENDENT_IMPORT',glb_sha256=sha(dest),glb_bytes=dest.stat().st_size,source_unchanged=sha(ORIGINAL)==EXPECTED,scope='One belt only; exact discrete24fps samples, no subframe interpolation, no whole-cap GLTF acceptance');save();print(json.dumps(state),flush=True)
