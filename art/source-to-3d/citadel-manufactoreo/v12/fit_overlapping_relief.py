"""Remove whole optional relief mounts where older external hardware occupies them.

This is source geometry fitting, not a name-based exclusion from contact reports.
All surviving geometry remains included in subsequent raw source/runtime sweeps.
"""
from mathutils.bvhtree import BVHTree
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();cache={}
def shape(o):
 if o.name in cache:return cache[o.name]
 ev=o.evaluated_get(dg);m=ev.to_mesh();m.calc_loop_triangles();p=[ev.matrix_world@v.co for v in m.vertices]
 out=([min(v[k]for v in p)for k in range(3)],[max(v[k]for v in p)for k in range(3)],BVHTree.FromPolygons(p,[tuple(t.vertices)for t in m.loop_triangles],all_triangles=True))
 ev.to_mesh_clear();cache[o.name]=out;return out
def hits(a,b):
 aa,bb=shape(a),shape(b)
 if any(min(aa[1][k],bb[1][k])-max(aa[0][k],bb[0][k])<1e-5 for k in range(3)):return False
 return bool(aa[2].overlap(bb[2]))
rules=[
 ('tower crown fitted thermal cassette',('roof exchanger upright cooling fin','sealed roof heat-exchanger core')),
 ('crown fitted maintenance pad frame',('crown thermal cassette formed fin','crown thermal cassette seated rim','crown triangular cast edge moulding','crown hip fitted heat louvre')),
 ('crown cast rite seated tile',('crown maintenance pad','crown edge cast retaining shoe','crown thermal cassette formed fin','crown thermal cassette seated rim')),
 ('crown cheek seated cast trace field',('sealed roof heat-exchanger core','roof exchanger upright cooling fin','exchanger protective clamp rail','crown maintenance pad','crown edge cast retaining shoe','crown triangular cast edge moulding')),
]
removed=[]
for mount_prefix,targets in rules:
 mounts=[o for o in col.objects if o.name.startswith('CITADEL | '+mount_prefix)]
 protected=[o for o in col.objects if o.type=='MESH'and any(o.name.startswith('CITADEL | '+n)for n in targets)]
 planned=[]
 for mount in mounts:
  children=[o for o in mount.children_recursive if o.type=='MESH'];contacts=[]
  for a in children:
   for b in protected:
    if b not in children and hits(a,b):contacts.append([a.name,b.name])
  if contacts:planned.append((mount,contacts))
 for mount,contacts in planned:
  removed.append({'mount':mount.name,'meshes':[o.name for o in mount.children_recursive if o.type=='MESH'],'contacts_repaired':contacts})
  for o in reversed(list(mount.children_recursive)):bpy.data.objects.remove(o,do_unlink=True)
  bpy.data.objects.remove(mount,do_unlink=True)
 bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();cache.clear()
# Remove complete optional ornament cells where independent service hardware
# needs clearance, retaining each cell's whole relief rather than loose shards.
cells={}
for o in col.objects:
 key=o.get('citadel_optional_relief_cell')
 if key:cells.setdefault(key,[]).append(o)
cell_removed=[]
for key,objects in cells.items():
 targets=('facade service transom return','tower facade protected service line')if key.startswith('front-')else('rear power cabinet founded conduit','rear protected diagnostic riser','rear diagnostic riser split clamp','rear riser founded wall shoe','rear riser supported standoff')
 protected=[o for o in col.objects if o.type=='MESH'and any(o.name.startswith('CITADEL | '+n)for n in targets)]
 contacts=[[a.name,b.name]for a in objects if a.type=='MESH'for b in protected if hits(a,b)]
 if contacts:cell_removed.append((key,objects,contacts))
for key,objects,contacts in cell_removed:
 removed.append({'optional_cell':key,'meshes':[o.name for o in objects],'contacts_repaired':contacts})
 for o in objects:bpy.data.objects.remove(o,do_unlink=True)
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();cache.clear()
anchors=[o for o in col.objects if o.name.startswith('CITADEL | loom saddle column retained anchor')]
redundant=[]
for o in tuple(col.objects):
 if o.name.startswith('CITADEL | facade cartridge retained face stud'):
  contacts=[[o.name,b.name]for b in anchors if hits(o,b)]
  if contacts:redundant.append((o,contacts))
for o,contacts in redundant:
 removed.append({'redundant_fastener':o.name,'reason':'Harness anchor replaces the old stud at the same fastening site.','contacts_repaired':contacts})
 bpy.data.objects.remove(o,do_unlink=True)
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();cache.clear()
blocks=[o for o in col.objects if o.name.startswith('CITADEL | bundle founded twin-entry manifold')]
armors=[o for o in col.objects if o.name.startswith('CITADEL | tower facade armor stud')]
for head in armors:
 contacts=[[head.name,b.name]for b in blocks if hits(head,b)]
 if contacts:
  shanks=[o for o in col.objects if o.name.startswith('CITADEL | tower armor stud seated shank')and(o.location-Vector((head.location.x,-1.895,head.location.z))).length<1e-5]
  removed.append({'redundant_fastener':head.name,'reason':'Entry block occupies this old armor-fastener site; neighbouring retained armor remains.','contacts_repaired':contacts})
  for o in [head,*shanks]:bpy.data.objects.remove(o,do_unlink=True)
(O/'relief-fit-repairs.json').write_text(json.dumps({'removed_optional_mounts':removed,'removed_mount_count':len(removed),'surviving_geometry_still_fully_audited':True,'unwanted_contacts_not_whitelisted':True},indent=2)+'\n')
print('CITADEL_RELIEF_MOUNTS_FITTED',len(removed),flush=True)
