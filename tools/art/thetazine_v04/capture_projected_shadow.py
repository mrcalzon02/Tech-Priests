"""Actual evaluated geometry, clipped at deck and projected along canonical sun."""
import bpy,pathlib,sys,json,hashlib,argparse,os,numpy as np
p=argparse.ArgumentParser();p.add_argument('study',type=pathlib.Path);p.add_argument('--frames',default='all');a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);R=a.study.resolve();src=R/'thetazine-v04-regenerative-study.blend';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(src));s=bpy.context.scene;casters=[o for o in s.objects if o.type=='MESH' and not o.get('render_only_volume')];direction=np.asarray((4,6,-8),dtype=np.float64);floor=-.001;dest=R/'projected-shadow-frames';dest.mkdir(exist_ok=True);receipt=R/'projected-shadow-capture.json';state={'status':'CAPTURING_PROJECTED_SHADOW','pid':os.getpid(),'native_sha256':sha(src),'renderer_sha256':sha(pathlib.Path(__file__)),'frames':[],'full_cell':[768,1280],'body_cell':[512,1280],'light_travel_direction':list(direction),'platform_plane_z':floor,'camera_contract':'Same optical axis, vertical orthographic scale and pixels per model unit as body. Wider transparent canvas; common occupied bounds will be cropped with exact shift compensation.','method':'Actual evaluated physical triangles including morphs; clip to deck z>=-.001, then parallel-project onto deck. No painted ellipse; render-only flame excluded. Opaque silhouette method matches existing hydrogen pipeline.'}
if receipt.exists():
 old=json.loads(receipt.read_text());assert old['native_sha256']==state['native_sha256'] and old['renderer_sha256']==state['renderer_sha256'];state['frames']=old['frames']
for o in s.objects:
 if o.type in ['MESH','LIGHT']:o.hide_render=True
mat=bpy.data.materials.new('Projected geometry exact black matte');mat.use_nodes=True;nt=mat.node_tree;nt.nodes.clear();em=nt.nodes.new('ShaderNodeEmission');em.inputs['Color'].default_value=(0,0,0,1);out=nt.nodes.new('ShaderNodeOutputMaterial');nt.links.new(em.outputs[0],out.inputs['Surface']);mesh=bpy.data.meshes.new('Projected shadow silhouette');obj=bpy.data.objects.new('Projected shadow silhouette',mesh);s.collection.objects.link(obj);obj.data.materials.append(mat);s.render.engine='BLENDER_EEVEE';s.render.film_transparent=True;s.render.resolution_x=768;s.render.resolution_y=1280;s.render.resolution_percentage=100
if hasattr(s.eevee,'taa_render_samples'):s.eevee.taa_render_samples=16
frames=range(66) if a.frames=='all' else [int(x) for x in a.frames.split(',')]
def checkpoint():receipt.write_text(json.dumps(state,indent=2)+'\n',encoding='utf-8',newline='\n')
checkpoint()
for frame in frames:
 path=dest/f'{frame:02}.png';old=next((x for x in state['frames'] if x['frame']==frame),None)
 if old:assert sha(path)==old['sha256'];continue
 s.frame_set(frame);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();vertices=[];faces=[];active=0;clipped_count=0
 for o in casters:
  ev=o.evaluated_get(dg);me=ev.to_mesh();me.calc_loop_triangles();local=np.asarray([v.co for v in me.vertices],dtype=np.float64);matrix=np.asarray(ev.matrix_world,dtype=np.float64);world=local@matrix[:3,:3].T+matrix[:3,3];tri=np.asarray([t.vertices[:] for t in me.loop_triangles],dtype=np.int32);ev.to_mesh_clear()
  if not len(tri):continue
  above=world[tri,2]>=floor;inside=np.all(above,axis=1);cross=np.any(above,axis=1)&~inside
  if not inside.any() and not cross.any():continue
  active+=1;t=tri[inside]
  if len(t):
   ids,inv=np.unique(t,return_inverse=True);pts=world[ids].copy();pts+=((floor-pts[:,2])/direction[2])[:,None]*direction;polys=inv.reshape(-1,3);u=pts[polys[:,1],:2]-pts[polys[:,0],:2];v=pts[polys[:,2],:2]-pts[polys[:,0],:2];good=np.abs(u[:,0]*v[:,1]-u[:,1]*v[:,0])>1e-12;start=len(vertices);vertices.extend(pts.tolist());faces.extend((polys[good]+start).tolist())
  for ids in tri[cross]:
   poly=[p.copy() for p in world[ids]];cut=[]
   for v,w in zip(poly,poly[1:]+poly[:1]):
    vi=v[2]>=floor;wi=w[2]>=floor
    if vi:cut.append(v)
    if vi!=wi:cut.append(v+(w-v)*((floor-v[2])/(w[2]-v[2])))
   pts=np.asarray(cut);pts+=((floor-pts[:,2])/direction[2])[:,None]*direction
   area=abs(np.sum(pts[:,0]*np.roll(pts[:,1],-1)-pts[:,1]*np.roll(pts[:,0],-1)))
   if area<=1e-12:continue
   start=len(vertices);vertices.extend(pts.tolist());faces.append(list(range(start,start+len(pts))));clipped_count+=1
 mesh.clear_geometry();mesh.from_pydata(vertices,[],faces);mesh.update();s.render.filepath=str(path);bpy.ops.render.render(write_still=True);state['frames'].append({'frame':frame,'file':str(path.relative_to(R)).replace('\\','/'),'sha256':sha(path),'active_caster_meshes':active,'projected_faces':len(faces),'deck_crossing_faces':clipped_count,'world_shadow_bounds':[[min(p[i] for p in vertices) for i in range(3)],[max(p[i] for p in vertices) for i in range(3)]]});checkpoint();print('PROJECTED_SHADOW_FRAME',frame,len(faces),flush=True)
state['status']='COMPLETE_66_SHADOW_POSES_REQUIRES_ALPHA_AND_REGISTRATION_CHECK' if len(state['frames'])==66 else 'PILOT_SHADOW_REQUIRES_VIEW';checkpoint()
