"""Independent saved-source/export motion sampling, including loop closure."""
import bpy,json,hashlib,math,sys
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[3];O=Path(sys.argv[sys.argv.index('--asset')+1]).resolve() if '--asset' in sys.argv else R/'art/source-to-3d/conclave-center/v07-aged-and-ambient';STEM='conclave-center-'+O.name.split('-')[0];F=[1,37,73,109,145,181,217,253,289]
def sample():
 s=bpy.context.scene;result=[]
 for f in F:
  s.frame_set(f);dg=bpy.context.evaluated_depsgraph_get();row={}
  for ob in s.objects:
   if ob.type=='MESH' and ('animated flame' in ob.name or 'light smoke' in ob.name):
    ev=ob.evaluated_get(dg);mesh=ev.to_mesh();points=[ev.matrix_world@v.co for v in mesh.vertices];row[ob.name]=dict(center=[sum(p[j] for p in points)/len(points) for j in range(3)],tip=list(max(points,key=lambda p:p.z)));ev.to_mesh_clear()
  result.append(row)
 return result
bpy.ops.wm.open_mainfile(filepath=str(O/(STEM+'.blend')));source=sample();s=bpy.context.scene;source_shader=[]
for f in F:
 s.frame_set(f);source_shader.append(dict(frame=f,screens=[dict(scroll=bpy.data.materials['Conclave V07 | slow doctrine CRT '+str(i)].node_tree.nodes.get('Mapping').inputs['Location'].default_value[1],light=bpy.data.lights['Console %d phosphor keyboard spill'%i].energy) for i in range(3)]))
for ob in list(s.objects):
 if ob.type in ('MESH','EMPTY'):bpy.data.objects.remove(ob,do_unlink=True)
s.frame_set(1);bpy.ops.import_scene.gltf(filepath=str(O/(STEM+'.glb')));export=sample();details=[]
for name in source[0]:
 sd=max((Vector(a[name]['tip'])-Vector(source[0][name]['tip'])).length for a in source[1:-1]);ed=max((Vector(a[name]['tip'])-Vector(export[0][name]['tip'])).length for a in export[1:-1]);closure=(Vector(export[-1][name]['tip'])-Vector(export[0][name]['tip'])).length;parity=max((Vector(a[name]['tip'])-Vector(b[name]['tip'])).length for a,b in zip(source,export));details.append(dict(name=name,source_motion=sd,export_motion=ed,export_loop_error=closure,source_export_max_error=parity,passed=sd>1e-4 and ed>1e-4 and closure<1e-4 and parity<1e-4))
result=dict(passed=all(x['passed'] for x in details),samples=F,effects=details,source_shader_samples=source_shader,shader_export_limit='Screen UV scroll, emission flicker and light spill are source-evaluated for sprites; GLB geometry motion independently measured.',source_sha256=hashlib.sha256((O/(STEM+'.blend')).read_bytes()).hexdigest(),export_sha256=hashlib.sha256((O/(STEM+'.glb')).read_bytes()).hexdigest())
(O/'independent-motion-audit.json').write_text(json.dumps(result,indent=2)+'\n');print('V07_INDEPENDENT_MOTION',result['passed'],flush=True)
if not result['passed']:raise RuntimeError('Inspect real per-effect motion errors')
