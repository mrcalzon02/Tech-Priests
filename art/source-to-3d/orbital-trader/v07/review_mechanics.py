import bpy,json,sys,hashlib,math
from pathlib import Path
from mathutils import Vector
A=Path(sys.argv[sys.argv.index('--')+1]);sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();reports=[]
for runtime in (False,True):
 artifact=A/('orbital-v07.glb'if runtime else'orbital-v07.blend')
 if runtime:bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(artifact));bpy.context.scene.frame_set(0)
 else:bpy.ops.wm.open_mainfile(filepath=str(artifact));bpy.context.scene.frame_set(1)
 raw=json.loads((A/('attachment-support-runtime-raw.json'if runtime else'attachment-support-raw.json')).read_text());clear=json.loads((A/('clearance-runtime-raw.json'if runtime else'clearance-raw.json')).read_text());owners=clear['motion_owners'];adj={o:set()for o in owners}
 for e in raw['measured_edges']:adj[e['a']].add(e['b']);adj[e['b']].add(e['a'])
 founded=set(raw['root_foundation_meshes']);todo=list(founded)
 while todo:
  for n in adj[todo.pop()]-founded:founded.add(n);todo.append(n)
 assert len(founded)==1924
 groups=raw['unattached_components'];bearings=[]
 for group in groups:
  names=set(group['objects']);motion={owners[n]for n in names};assert len(motion)==1 and None not in motion;owner=motion.pop();assert names=={n for n,o in owners.items()if o==owner}
  hinge=bpy.data.objects[owner];inv=hinge.matrix_world.inverted();isfan='cooling rotor'in owner
  pin=next(bpy.data.objects[n]for n in names if ('bored rotating hub'if isfan else'rigid rotating drive pin')in n)
  fixed_names=[n for n in founded if ('fan fixed shaft'==n.removeprefix('ORBITAL | '))]if isfan else[n for n in founded if 'fixed bored journal ear'in n and (inv@bpy.data.objects[n].matrix_world.translation).length<.3]
  assert len(fixed_names)==(1 if isfan else 2)
  dg=bpy.context.evaluated_depsgraph_get()
  def radii(obj):
   ev=obj.evaluated_get(dg);m=ev.to_mesh();coords=[inv@(ev.matrix_world@v.co)for v in m.vertices];r=[math.hypot(v.x,v.y)if isfan else math.hypot(v.x,v.z)for v in coords];ev.to_mesh_clear();return min(r),max(r)
  moving=radii(pin)
  if isfan:
   bore=moving[0];shaft=radii(bpy.data.objects[fixed_names[0]])[1]
  else:
   shaft=moving[1];bore=min(radii(bpy.data.objects[n])[0]for n in fixed_names)
  gap=bore-shaft;assert abs(gap-.0005)<2e-6,(owner,gap)
  seats=group['nearest_founded_seats'];assert seats[0]['gap']>.00048 and seats[0]['gap']<.00052
  bearings.append({'motion_owner':owner,'rigid_mesh_count':len(names),'exact_component_matches_all_motion_owner_meshes':True,'fixed_grounded_journals':fixed_names,'measured_shaft_radius':shaft,'measured_bore_radius':bore,'measured_radial_running_clearance':gap,'nearest_founded_surface':seats[0]})
 foreign=[];same=0;fixed=0
 for pair,info in clear['pairs'].items():
  x,y=(owners[n]for n in pair.split(' <> '))
  if x or y:
   if x!=y:foreign.append(pair)
   else:same+=1
  else:fixed+=1
 assert not foreign and len(bearings)==5
 reports.append({'artifact':artifact.name,'sha256':sha(artifact),'stationary_grounded_meshes':len(founded),'journal_supported_moving_meshes':sum(b['rigid_mesh_count']for b in bearings),'bearings':bearings,'sampled_sweep_poses':clear['sampled_poses'],'foreign_moving_contacts':foreign,'same_rigid_assembly_contact_pairs':same,'fixed_contact_pairs':fixed,'fixed_contact_inventory_fully_adjudicated':False})
r={'support_and_moving_clearance_passed':True,'source_and_runtime':reports,'scope':'All stationary details have measured physical paths to the founded slab. All five moving components match their entire rigid assembly and are supported by measured coaxial grounded journals with running clearance. No cross-assembly moving contacts across244 sampled poses per artifact. Fixed casting/plating/fastener contacts remain a raw inventory; this is not a claim that every static overlap was independently adjudicated.','owner_visual_approved':False};(A/'mechanical-support-and-clearance.json').write_text(json.dumps(r,indent=2));print('SUPPORT_AND_MOVING_CLEARANCE_PASS',flush=True)
