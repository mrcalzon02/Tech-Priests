"""Measure real radial wall depth and tie seating in source and actual GLB."""
import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/martian-stone-cache/v01';meta=json.loads((O/'masonry-and-cover.json').read_text())
def tree(ob):return BVHTree.FromPolygons([ob.matrix_world@v.co for v in ob.data.vertices],[list(p.vertices) for p in ob.data.polygons])
def audit(label):
 ob=bpy.data.objects['Grounded carved circuit receiving tablet'];bvh=tree(ob);lo,hi=meta['front_wall_section']['angular_bounds'];samples=[]
 for z in (.12,.30,.50,.69):
  for fraction in (.08,.25,.5,.75,.92):
   a=lo+(hi-lo)*fraction;direction=Vector((math.cos(a),math.sin(a),0));origin=Vector((0,0,z));inner,n,f,d=bvh.ray_cast(origin,direction);outer,n,f,d=bvh.ray_cast(inner+direction*.0001,direction);thickness=(outer-inner).length if outer else 0;samples.append(dict(z=z,angle=a,inner_radius=math.hypot(inner.x,inner.y),outer_radius=math.hypot(outer.x,outer.y) if outer else None,radial_thickness=thickness,passed=thickness>.19))
 ties=[]
 for rec in meta['ties']:
  points=[]
  for kind in ('start','end'):
   p=Vector(rec[kind]);host=bpy.data.objects[rec[kind+'_parent']];q,n,f,d=tree(host).find_nearest(p);points.append(dict(endpoint=kind,parent=host.name,surface_distance=d,passed=d<.009))
  ties.append(dict(id=rec['id'],points=points,passed=all(p['passed'] for p in points)))
 relief=[]
 for part in bpy.data.objects:
  if not part.name.startswith('Cache centered emblem |') or part.type!='MESH':continue
  offsets=[]
  for v in part.data.vertices:
   p=part.matrix_world@v.co;q,n,f,d=bvh.ray_cast(Vector((p.x,-2,p.z)),Vector((0,1,0)))
   if q is not None:offsets.append(q.y-p.y)
  relief.append(dict(part=part.name,maximum_projection=max(offsets),minimum_projection=min(offsets),passed=max(offsets)<.014))
 skull=next(p for p in relief if 'Supplied DGordillo' in p['part'])
 seated=skull['minimum_projection']<0 and all(p['passed'] for p in relief)
 terminals=[]
 for rec in meta['circuit_support']['terminals']:
  p=Vector(rec['mouth']);q,n,f,d=tree(bpy.data.objects[rec['object']]).find_nearest(p);projected=[p.x,-(p.y+p.z)/math.sqrt(2)+.125]
  error=max(abs(a-b) for a,b in zip(projected,rec['native']))
  terminals.append(dict(wire=rec['wire'],projection=projected,native=rec['native'],error=error,surface_distance=d,passed=error<1e-6 and d<1e-5))
 return dict(label=label,wall_samples=samples,ties=ties,relief=relief,terminals=terminals,skull_back_embedded=skull['minimum_projection']<0,passed=seated and all(p['passed'] for p in samples) and all(t['passed'] for t in ties) and all(t['passed'] for t in terminals))
bpy.ops.wm.open_mainfile(filepath=str(O/'martian-stone-cache-v01.blend'));source=audit('reopened packed source')
for ob in list(bpy.context.scene.objects):
 if ob.type in ('MESH','EMPTY'):bpy.data.objects.remove(ob,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(O/'martian-stone-cache-v01.glb'));export=audit('actual independent GLB import');result=dict(passed=source['passed'] and export['passed'],source=source,export=export,requirement='Full curved wall section from inner to outer radius, not a face-mounted flat slab.',source_sha256=hashlib.sha256((O/'martian-stone-cache-v01.blend').read_bytes()).hexdigest(),export_sha256=hashlib.sha256((O/'martian-stone-cache-v01.glb').read_bytes()).hexdigest());(O/'wall-and-tie-audit.json').write_text(json.dumps(result,indent=2));print('CACHE_FULL_DEPTH_WALL_AND_SEATS',result['passed']);assert result['passed']
