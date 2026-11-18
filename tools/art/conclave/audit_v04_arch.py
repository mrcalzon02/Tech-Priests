"""Independent source/GLB measurements of actual arch seats and candle array."""
import bpy,json,math,hashlib,sys
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[3];O=Path(sys.argv[sys.argv.index('--asset')+1]).resolve() if '--asset' in sys.argv else R/'art/source-to-3d/conclave-center/v04-arch-and-services';STEM='conclave-center-'+O.name.split('-')[0];spec=json.loads((O/'arch-and-services.json').read_text())
def geometry(stage):
 bpy.context.view_layer.update()
 def vertices(o):return [o.matrix_world@v.co for v in o.data.vertices]
 ring=bpy.data.objects['Crown cog continuous rim'];pts=vertices(ring);center=Vector([(min(v[j] for v in pts)+max(v[j] for v in pts))/2 for j in range(3)])
 radii=[math.hypot(v.x-center.x,v.z-center.z) for v in pts];major=(max(radii)+min(radii))/2;minor=(max(radii)-min(radii))/2
 seats=[];candles=[]
 for row in spec['arch']['holders']:
  i=row['index'];points=vertices(bpy.data.objects['Arch candle saddle %02d'%i]);p=Vector((sum(v.x for v in points)/len(points),max(v.y for v in points),sum(v.z for v in points)/len(points)))
  distance=math.hypot(math.hypot(p.x-center.x,p.z-center.z)-major,p.y-center.y)
  seats.append(dict(index=i,measured_seat=list(p),torus_tube_distance=distance,torus_minor_radius=minor,passed=distance<minor-.01))
  points=vertices(bpy.data.objects['Arch candle bowl bottom %02d'%i]);cup=Vector((sum(v.x for v in points)/len(points),sum(v.y for v in points)/len(points),max(v.z for v in points)-.004))
  error=(cup-Vector(row['cup_center'])).length;angle=math.degrees(math.atan2(cup.z-center.z-.042,cup.x-center.x))
  candles.append(dict(index=i,measured_cup=list(cup),actual_angle_degrees=angle,expected_angle_degrees=row['angle_degrees'],seat_error=error,passed=error<1e-5 and abs(angle-row['angle_degrees'])<1e-3))
 height_spread=max(c['measured_cup'][2] for c in candles)-min(c['measured_cup'][2] for c in candles)
 return dict(stage=stage,measured_arch_center=list(center),major_radius=major,minor_radius=minor,seats=seats,candles=candles,actual_cup_height_spread=height_spread,passed=all(x['passed'] for x in seats+candles) and height_spread>.4)
bpy.ops.wm.open_mainfile(filepath=str(O/(STEM+'.blend')));source=geometry('reopened source')
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(O/(STEM+'.glb')));export=geometry('actual reimported GLB')
def crosses_box(a,b,lo,hi):
 t0,t1=0.,1.
 for j in range(3):
  d=b[j]-a[j]
  if abs(d)<1e-12:
   if a[j]<lo[j] or a[j]>hi[j]:return False
  else:
   x,y=(lo[j]-a[j])/d,(hi[j]-a[j])/d
   if x>y:x,y=y,x
   t0=max(t0,x);t1=min(t1,y)
   if t0>t1:return False
 return True
access=[]
for request in json.loads((O/'pipette-requests.json').read_text()):
 if not request['id'].startswith(('conclave-v03-','conclave-v04-','conclave-v05-','conclave-v06-')):continue
 radius=request['size']['outer_diameter']*.75;lo=[-.30-radius,-.80-radius,.18-radius];hi=[.30+radius,-.35+radius,.72+radius];points=request['path']['points'];hits=sum(crosses_box(a,b,lo,hi) for a,b in zip(points,points[1:]));access.append(dict(route=request['id'],segments_crossing_expanded_operator_recess=hits,passed=hits==0))
report=dict(passed=source['passed'] and export['passed'] and all(x['passed'] for x in access),source=source,export=export,operator_recess_checks=access,check_limit='Actual candle/support coordinates measured in source and GLB; analytic torus-seat margins and swept centreline-vs-expanded-access-box checks, not exhaustive surface collision proof.',source_sha256=hashlib.sha256((O/(STEM+'.blend')).read_bytes()).hexdigest(),export_sha256=hashlib.sha256((O/(STEM+'.glb')).read_bytes()).hexdigest())
(O/'arch-seat-and-access-audit.json').write_text(json.dumps(report,indent=2)+'\n');print('CONCLAVE_ACTUAL_ARCH_AUDIT',report['passed'],flush=True)
if not report['passed']:raise RuntimeError('Review actual arch-seat/access failures')
