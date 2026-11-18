"""Measure hatch support and invariant circuit mouths in source and actual GLB."""
import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/item-vault/v01';C=R/'art/source-to-3d/martian-stone-cache/v01'
def tree(ob):return BVHTree.FromPolygons([ob.matrix_world@v.co for v in ob.data.vertices],[list(p.vertices) for p in ob.data.polygons])
def audit(label):
 bpy.context.view_layer.update();names=['Vault | rectangular reinforced door leaf','Vault | rectangular door gasket','Vault | continuous metal infill panel'];trees=[tree(bpy.data.objects[n]) for n in names];seats=[]
 for x,y in [(.47,0),(-.47,0),(0,.42),(0,-.42),(.43,.38),(-.43,.38),(.43,-.38),(-.43,-.38)]:
  p=Vector((x,y,1.2));hits=[]
  for t in trees:
   q,n,f,d=t.ray_cast(p,Vector((0,0,-1)));assert q is not None
   q2,n,f,d=t.ray_cast(q-Vector((0,0,.00001)),Vector((0,0,-1)));assert q2 is not None;hits.append([q2.z,q.z])
  gaps=[hits[0][0]-hits[1][1],hits[1][0]-hits[2][1]];seats.append(dict(xy=[x,y],vertical_intervals=hits,gaps=gaps,passed=all(-.02<g<.002 for g in gaps)))
 terminals=[]
 for rec in json.loads((C/'masonry-and-cover.json').read_text())['circuit_support']['terminals']:
  p=Vector(rec['mouth']);q,n,f,d=tree(bpy.data.objects[rec['object']]).find_nearest(p);projected=[p.x,-(p.y+p.z)/math.sqrt(2)+.125];error=max(abs(a-b) for a,b in zip(projected,rec['native']));terminals.append(dict(wire=rec['wire'],error=error,surface_distance=d,passed=error<1e-6 and d<1e-5))
 passages=[]
 for i in range(2):
  for name in ('Vault | lock keeper %d'%i,'Vault | sliding bar guide %d'%i):
   ob=bpy.data.objects[name];bvh=tree(ob);clear=True
   for dx in (-.020,0,.020):
    for dz in (-.0175,0,.0175):
     q,n,f,d=bvh.ray_cast(Vector((.28+dx,ob.location.y-.2,.791+dz)),Vector((0,1,0)),.4);clear=clear and q is None
   passages.append(dict(object=name,bolt_envelope_clear=clear,passed=clear))
 return dict(label=label,hatch_seats=seats,terminals=terminals,bolt_passages=passages,passed=all(x['passed'] for x in seats+terminals+passages))
bpy.ops.wm.open_mainfile(filepath=str(O/'item-vault-v01.blend'));source=audit('reopened source')
for ob in list(bpy.context.scene.objects):
 if ob.type in ('MESH','EMPTY'):bpy.data.objects.remove(ob,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(O/'item-vault-v01.glb'));export=audit('actual GLB import');h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();receipt=dict(passed=source['passed'] and export['passed'],source=source,export=export,source_sha256=h(O/'item-vault-v01.blend'),export_sha256=h(O/'item-vault-v01.glb'));(O/'seat-audit.json').write_text(json.dumps(receipt,indent=2)+'\n');print('ITEM_VAULT_HATCH_CIRCUIT_SEATS',receipt['passed']);assert receipt['passed']
