"""Evaluated-mesh clearance: all new cooling paths and all fluid-path pairs."""
import bpy,pathlib,sys,json,hashlib,math,collections,numpy as np
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
R=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();frame=int(sys.argv[sys.argv.index('--frame')+1]) if '--frame' in sys.argv else 1;src=R/'thetazine-v04-regenerative-study.blend';m=json.loads((R/'source-manifest.json').read_text());bpy.ops.wm.open_mainfile(filepath=str(src));s=bpy.context.scene;s.frame_set(1);bpy.context.view_layer.update();joints=m['mechanical_refinement']['seated_pipe_end_joints'];host_inv={j['host']:bpy.data.objects[j['host']].matrix_world.inverted() for j in joints};s.frame_set(0);bpy.context.view_layer.update();core=bpy.data.objects['V04 independently suspended engine core'];core_inv=core.matrix_world.inverted();s.frame_set(frame);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();core_delta=core.matrix_world@core_inv;L=m['leaf_regenerative_cooling'];old_names=[v['pipe'] for v in m['mechanical_refinement']['pipe_routes']];new_names=[v['name'] for v in L['pipe_routes']]+[v['mesh'] for v in L['flex_links']];names=old_names+new_names;assert len(names)==len(set(names))==84
objects={o.name:o for o in s.objects if o.type=='MESH' and not o.get('render_only_volume')};cache={};bounds={};closed={};triangles={};open_meshes=set();ambiguous=[];chamber_profile=None;winding_resolutions=0
for name,o in objects.items():
 ev=o.evaluated_get(dg);pts=[ev.matrix_world@Vector(c) for c in ev.bound_box];bounds[name]=[[min(p[i] for p in pts) for i in range(3)],[max(p[i] for p in pts) for i in range(3)]]
def shape(name):
 if name not in cache:
  o=objects[name];ev=o.evaluated_get(dg);me=ev.to_mesh();pts=[ev.matrix_world@v.co for v in me.vertices];faces=[list(p.vertices) for p in me.polygons];tree=BVHTree.FromPolygons(pts,faces);edges=collections.Counter(tuple(sorted((face[i],face[(i+1)%len(face)]))) for face in faces for i in range(len(face)));closed[name]=bool(edges) and all(v==2 for v in edges.values());me.calc_loop_triangles();triangles[name]=np.asarray([[pts[i] for i in t.vertices] for t in me.loop_triangles],dtype=np.float64);cache[name]=(pts,faces,tree);ev.to_mesh_clear()
  if not closed[name]:open_meshes.add(name)
 return cache[name]
def overlap(a,b):return all(a[0][i]<=b[1][i] and b[0][i]<=a[1][i] for i in range(3))
def terminal_specs(name):
 specs=[]
 if name in old_names:
  for idx,j in enumerate(joints):
   if j['pipe']!=name:continue
   T=objects[j['host']].matrix_world@host_inv[j['host']];specs.append((T@Vector(j['host_surface_point']),.34,[j['host']],f'V04 seated union {idx:03} '))
 elif name.startswith('V04 leaf regenerative four-pass circuit'):
  idx=int(name.rsplit(' ',1)[1]);leaf=objects[f'Nozzle articulated petal {idx:02}']
  for kind in ['inlet','outlet']:
   port=next(p for p in L['ports'] if p['name']==f'V04 leaf {kind} pressure socket {idx:02}');allowed=[p for p in objects if p.startswith('V04 leaf '+kind+' ') and p.endswith(f'{idx:02}')];specs.append((leaf.matrix_world@Vector(port['cap_local']),.15,allowed,''))
 elif name.startswith('V04 leaf regenerative flex'):
  job=next(v for v in L['flex_links'] if v['mesh']==name);idx=job['leaf_index'];kind=job['kind'];fluid=job['fluid'];root='supply' if kind=='inlet' else 'return';host=('V04 stationary regenerative supply half ' if kind=='inlet' else 'V04 leaf cooling warm return collector ')+fluid;specs.append((core_delta@Vector(job['root_rest']),.15,[host],f'V04 leaf {root} root union {idx:02}'))
  allowed=[p for p in objects if p.startswith('V04 leaf '+kind+' ') and p.endswith(f'{idx:02}')];specs.append((objects[job['leaf']].matrix_world@Vector(job['end_local']),.15,allowed,''))
 else:
  fluid=name.rsplit(' ',1)[1]
  for kind in ['collector','receiver']:
   p=next(p for p in L['ports'] if p['name']==f'V04 leaf return trunk {kind} {fluid}');specs.append((core_delta@Vector(p['cap_world_rest']),.15,[p['host']],f'V04 leaf return trunk {kind} union {fluid}'))
 return specs
specs={name:terminal_specs(name) for name in names}
def permitted(name,host,p):return any((host in hosts or (prefix and host.startswith(prefix))) and (p-center).length<radius for center,radius,hosts,prefix in specs[name])
principal=('Paired canister','Main pressure chamber','Upper mounting beam','Lower mounting crossmember','Diagonal shoulder','V04 deep gantry','V04 overhead three-dimensional','V04 tank rear','V04 tank fore','V04 tank outrigger','V04 straight structural','V04 vertical pressure intensifier','V04 auger upper','V04 auger lower','V04 transparent','V04 pressure barrel','V04 forward gland','V04 telescoping chrome','V04 elevated injector','V04 cold bulk feeder','V04 cold radial injector','V04 heated central','Nozzle articulated petal','V04 interleaved containment','V04 exposed root hinge','V04 exposed hinge through','V04 guide-rail')
new_components=set(L['added_meshes'])|set(m.get('leaf_collector_seating',{}).get('added_meshes',[]));violations=[];pairs=0
def crossing(name,host,allow=False):
 global chamber_profile,winding_resolutions
 p,faces,t=shape(name);hp,hfaces,ht=shape(host);hits=t.overlap(ht);bad=[]
 for fi,_ in hits:
  c=sum((p[i] for i in faces[fi]),Vector())/len(faces[fi])
  if not allow or not permitted(name,host,c):bad.append(c)
 # Full containment can have no surface crossing; test sparse actual mesh
 # vertices using parity, rather than trusting nearest-face normals alone.
 if not hits:
  hb=bounds[host]
  for v in p[::64]:
   if not all(hb[0][i]<v[i]<hb[1][i] for i in range(3)):continue
   if allow and permitted(name,host,v):continue
   nearest=ht.find_nearest(v)
   if nearest[3]<.0005:continue
   if not closed[host]:
    # An open-ended chamber surface has no ray-parity solid interior.
    # Its actual lathed vertex profile provides the exterior envelope.
    if host=='Main pressure chamber':
     axis=Vector((0,-math.cos(math.radians(25)),-math.sin(math.radians(25))));origin=Vector((0,.35,.2));undo=core_delta.inverted()
     if chamber_profile is None:
      rings=collections.defaultdict(list)
      for p0 in hp:
       rel=(undo@p0)/1.25-origin;z=rel.dot(axis);rings[round(z,4)].append((rel-axis*z).length)
      assert all(max(a)-min(a)<1e-4 for a in rings.values()),'Chamber is not an axisymmetric lathe'
      chamber_profile=sorted((z,sum(a)/len(a)) for z,a in rings.items())
     rel=(undo@v)/1.25-origin;z=rel.dot(axis);radius=(rel-axis*z).length
     for (a,ra),(b,rb) in zip(chamber_profile,chamber_profile[1:]):
      if a<z<b and radius<ra+(rb-ra)*(z-a)/(b-a)-.0016:bad.append(v);break
    continue
   votes=[]
   for vector in [(1,.13,.27),(-.31,1,.17),(.19,-.37,1)]:
    direction=Vector(vector).normalized();origin=v+direction*1e-5;count=0
    for _ in range(64):
     hit=ht.ray_cast(origin,direction,100)
     if hit[0] is None:break
     count+=1;origin=hit[0]+direction*1e-4
    votes.append(count%2)
   if len(set(votes))>1:
    # Resolve edge-grazing rays with a direction-independent solid-angle
    # winding sum over the actual rendered triangles, in float64.
    tri=triangles[host]-np.asarray(v,dtype=np.float64);a,b,c=tri[:,0],tri[:,1],tri[:,2];la=np.linalg.norm(a,axis=1);lb=np.linalg.norm(b,axis=1);lc=np.linalg.norm(c,axis=1);num=np.einsum('ij,ij->i',a,np.cross(b,c));den=la*lb*lc+np.einsum('ij,ij->i',a,b)*lc+np.einsum('ij,ij->i',b,c)*la+np.einsum('ij,ij->i',c,a)*lb;w=float(np.sum(2*np.arctan2(num,den))/(4*math.pi));winding_resolutions+=1
    if abs(w)<1e-4:continue
    if abs(abs(w)-1)<1e-4:bad.append(v);continue
    ambiguous.append({'pipe':name,'obstacle':host,'point':list(v),'votes':votes,'solid_angle_winding':w})
   elif sum(votes)>=2:bad.append(v)
 if bad:violations.append({'pipe':name,'obstacle':host,'samples':len(bad),'points':[list(p) for p in bad[:3]]})
for i,name in enumerate(names):
 for host in objects:
  if host in names or host==name:continue
  if name in old_names and not (host.startswith(principal) or host in new_components):continue
  if not overlap(bounds[name],bounds[host]):continue
  pairs+=1;crossing(name,host,True)
 for other in names[i+1:]:
  if overlap(bounds[name],bounds[other]):pairs+=1;crossing(name,other,False)
report={'status':'PASS_EVALUATED_COOLING_ROUTE_CLEARANCE_POSE' if not violations and not ambiguous else 'FAIL_EVALUATED_COOLING_ROUTE_CLEARANCE_POSE','native_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'auditor_sha256':hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),'frame':frame,'all_fluid_routes':len(names),'new_cooling_routes':len(new_names),'mesh_pairs_checked':pairs,'violations':violations,'ambiguous_closed_solid_samples':ambiguous,'solid_angle_resolutions':winding_resolutions,'open_obstacles_surface_tested':sorted(open_meshes),'chamber_actual_lathe_profile':chamber_profile,'scope':'Actual evaluated mesh vertices, including flexible morphs. New38paths against all physical fixtures except render volume; original46against principal machinery plus every new cooling component. All84fluid paths pairwise. Declared terminal contacts only near actual moving ports. Closed solids use multi-ray parity with float64 solid-angle winding for grazing disagreements; open chamber uses actual lathe envelope. Not an every-solid-pair engineering or behavior test.'};(R/f'leaf-cooling-clearance-frame-{frame:02}.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n');print(report['status'],frame,len(violations),len(ambiguous));print(json.dumps([{k:v for k,v in r.items() if k!='points'} for r in violations[:25]]))
if violations or ambiguous:raise SystemExit(1)
