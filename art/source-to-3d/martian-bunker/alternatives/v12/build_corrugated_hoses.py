"""V12 corrugated compression hoses on the preserved V11 visual game asset."""
import bpy,math,json,os,hashlib,bisect
from pathlib import Path
from mathutils import Vector
O=Path('art/source-to-3d/martian-bunker/alternatives/v12').resolve();O.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(O.parent/'v11/six_lobber_inset_plating_v11.blend'))
S=bpy.context.scene;col=bpy.data.collections['SIX_LOBBER_LOOSE_GRENADE_LOADERS'];fin=bpy.data.objects['CENTRAL_FIN']
def signature(o):return hashlib.sha256(repr(([tuple(v.co) for v in o.data.vertices],list(map(tuple,o.matrix_world)),[m.name for m in o.data.materials])).encode()).hexdigest()
source={o.name:signature(o) for o in col.objects if o.type=='MESH' and not o.name.startswith('BOTTOM_FEED_LEFT_')};records=[]
for o in list(col.objects):
 if not o.name.startswith('BOTTOM_FEED_LEFT_'):continue
 old=o.data;Nold=24;Lold=len(old.vertices)//(2*Nold);assert Lold*2*Nold==len(old.vertices)
 centers=[sum((old.vertices[i*Nold+j].co for j in range(Nold)),Vector())/Nold for i in range(Lold)]
 distances=[0.]
 for i in range(1,Lold):distances.append(distances[-1]+(centers[i]-centers[i-1]).length)
 length=distances[-1]
 def at(s):
  if s<=0:return centers[0].copy()
  if s>=length:return centers[-1].copy()
  i=bisect.bisect_right(distances,s)-1;return centers[i].lerp(centers[i+1],(s-distances[i])/(distances[i+1]-distances[i]))
 ribs=max(8,round((length-.060)/.028));active=length-.060;pitch=active/ribs
 steps=max(100,ribs*14+24);N=40;vs=[];frames=[];samples=[];previous=None
 for i in range(steps+1):
  s=length*i/steps;c=at(s);t=(at(min(length,s+.001))-at(max(0,s-.001))).normalized()
  if previous is None:
   a=t.cross(Vector((0,0,1)))
   if a.length<.1:a=t.cross(Vector((0,1,0)))
   a.normalize()
  else:a=previous[0].rotation_difference(t)@previous[1];a=(a-t*a.dot(t)).normalized()
  b=t.cross(a).normalized();previous=(t,a);frames.append((c,a,b));samples.append(s)
 for layer in [0,1]:
  for i,(c,a,b) in enumerate(frames):
   s=samples[i];blend=max(0,min(1,s/.03,(length-s)/.03));blend=blend*blend*(3-2*blend)
   radius=.045 if layer else .068*(1-blend)+(.061+.018*(.5+.5*math.cos(math.tau*(s-.03)/pitch)))*blend
   for j in range(N):vs.append(tuple(c+radius*(a*math.cos(math.tau*j/N)+b*math.sin(math.tau*j/N))))
 rings=steps+1;offset=rings*N;fs=[]
 for layer in [0,1]:
  q=layer*offset
  for i in range(rings-1):
   for j in range(N):
    f=(q+i*N+j,q+i*N+(j+1)%N,q+(i+1)*N+(j+1)%N,q+(i+1)*N+j)
    fs.append(f if layer==0 else tuple(reversed(f)))
 for i in [0,rings-1]:
  for j in range(N):fs.append((i*N+j,i*N+(j+1)%N,offset+i*N+(j+1)%N,offset+i*N+j))
 me=bpy.data.meshes.new(o.name+'_CONTINUOUS_CORRUGATED_BELLOWS');me.from_pydata(vs,[],fs);me.update()
 for material in old.materials:me.materials.append(material)
 for face in me.polygons:face.use_smooth=True
 uv=me.uv_layers.new(name='Continuous hose UV')
 for face in me.polygons:
  js=[(me.loops[li].vertex_index%offset)%N for li in face.loop_indices];wrap=max(js)-min(js)>N/2
  for li in face.loop_indices:
   idx=me.loops[li].vertex_index%offset;j=idx%N;i=idx//N
   uv.data[li].uv=((N if wrap and j==0 else j)/N,samples[i]/length*4)
 o.data=me
 for m in list(o.modifiers):
  if m.type in ['BEVEL','WEIGHTED_NORMAL']:o.modifiers.remove(m)
 assert any(m.type=='MIRROR' for m in o.modifiers)
 # Source endpoints and world transforms remain identical to their sockets.
 start=sum((me.vertices[j].co for j in range(N)),Vector())/N;end=sum((me.vertices[(rings-1)*N+j].co for j in range(N)),Vector())/N
 assert (start-centers[0]).length<1e-5 and (end-centers[-1]).length<1e-5
 records.append({'hose':o.name,'corrugation_count':ribs,'pitch':pitch,'valley_radius':.061,'crest_radius':.079,'source_centerline_and_endpoints_preserved':True,'original_iron_material_retained':True,'smooth_socket_transition':True})
bpy.context.view_layer.update()
for name,sig in source.items():assert signature(bpy.data.objects[name])==sig,name
assert len(records)==3
report={'revision':'V12 corrugated compression hoses','six_corrugated_hoses_after_mirroring':True,'hose_records':records,'all_other_V11_geometry_transforms_and_materials_preserved':True,'pneumatic_socket_positions_and_geometry_preserved':True,'existing_bunker_modified':False}
S.render.resolution_x=S.render.resolution_y=int(os.getenv('LOADER_RENDER_SIZE','1100'));S.render.resolution_percentage=100;S.cycles.samples=int(os.getenv('LOADER_RENDER_SAMPLES','32'));cam=S.camera
views=[('oblique',(-4,-6,4.8),(0,.15,3.02),4.05),('rear',(-4,5,4.5),(0,.28,3.02),4.05),('side',(-7,-1,3.3),(0,.15,2.80),3.15),('detail',(-4,-2,3.4),(-.25,-.10,2.90),1.60)]
for i,(name,pos,target,scale) in enumerate(views):
 cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
 if i==0:bpy.ops.wm.save_as_mainfile(filepath=str(O/'six_lobber_corrugated_hoses_v12.blend'),compress=True)
 S.render.filepath=str(O/('hoses_v12_'+name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action='DESELECT')
for o in col.objects:o.select_set(True)
bpy.context.view_layer.objects.active=fin;bpy.ops.export_scene.gltf(filepath=str(O/'six_lobber_corrugated_hoses_v12.glb'),use_selection=True,export_format='GLB',export_apply=True,export_animations=False)
n=sum(o.type=='MESH' for o in col.objects)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(O/'six_lobber_corrugated_hoses_v12.glb'));assert sum(o.type=='MESH' for o in bpy.context.scene.objects)==n
report['GLB_reimported']=True;report['mesh_count']=n;(O/'model_validation.json').write_text(json.dumps(report,indent=2));print('V12_CORRUGATED_HOSES_AND_EXPORT_PASS')
