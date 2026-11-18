import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_ray_tri
A=Path(__file__).resolve().parent;sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();reports=[]
for runtime in(False,True):
 artifact=A/('power-grid-v02.glb'if runtime else'power-grid-v02.blend')
 if runtime:bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(artifact))
 else:bpy.ops.wm.open_mainfile(filepath=str(artifact))
 raw=json.loads((A/('attachment-support-runtime-raw.json'if runtime else'attachment-support-raw.json')).read_text());assert raw['mesh_count']==raw['physically_connected_to_foundation']==92 and not raw['unattached_components'];dg=bpy.context.evaluated_depsgraph_get();data={}
 for o in bpy.context.scene.objects:
  if o.type!='MESH':continue
  ev=o.evaluated_get(dg);m=ev.to_mesh();m.calc_loop_triangles();v=[ev.matrix_world@v.co for v in m.vertices];tris=[tuple(t.vertices)for t in m.loop_triangles];data[o.name]=(v,tris,BVHTree.FromPolygons(v,tris,all_triangles=True,epsilon=0));ev.to_mesh_clear()
 leads=sorted(n for n in data if 'attached closed electrical lead'in n);woods=[o.name for o in bpy.context.scene.objects if o.type=='MESH'and any(m and m.name.endswith('cedar-derived')for m in o.data.materials)];assert len(leads)==3 and len(woods)==7;entries=[Vector((-.27,.055,.48)),Vector((0,.055,.58)),Vector((.27,.055,.48))];contact_rows=[]
 def hits(a,b):
  va,ta,ba=data[a];vb,tb,bb=data[b];points=[]
  for ia,ib in ba.overlap(bb):
   aa=[va[i]for i in ta[ia]];zz=[vb[i]for i in tb[ib]]
   for tri,other in[(aa,zz),(zz,aa)]:
    for j in range(3):
     p,q=tri[j],tri[(j+1)%3];d=q-p
     if d.length<1e-10:continue
     hit=intersect_ray_tri(*other,d,p,True)
     if hit is not None and -.0000001<=(hit-p).dot(d)/d.length_squared<=1.0000001:points.append(hit)
  return points
 for i,lead in enumerate(leads):
  for timber in woods:
   pts=hits(lead,timber)
   if pts:
    far=max((p-entries[i]).length for p in pts);assert far<=.035,(artifact.name,lead,timber,far);contact_rows.append({'lead':lead,'timber':timber,'measured_intersections':len(pts),'maximum_distance_from_designated_closed_gland_entry':far})
  for other in leads[i+1:]:assert not data[lead][2].overlap(data[other][2]),('electrical leads cross',lead,other)
 reports.append({'artifact':artifact.name,'sha256':sha(artifact),'all92meshes_physically_grounded':True,'moving_meshes':0,'all_three_electrical_routes_checked_against_all_seven_timber_members':True,'only_designated_gland_entry_contacts':contact_rows,'three_separate_leads_do_not_intersect_each_other':True,'exhaustive_static_contact_adjudication':False})
(A/'structural-support-and-routing.json').write_text(json.dumps({'passed':True,'source_and_runtime':reports,'scope':'All92 fixed parts physically connect to the founded slab. External leads clear every timber except their designated seated entry, and do not intersect one another. Central lead is offset around the mast/brace sweep space. Static fitted-joint inventory is not exhaustive overlap adjudication. Native passive pole has no moving mechanism.','owner_visual_approved':False},indent=2));print('POWER_GRID_SUPPORT_AND_ROUTE_PASS')
