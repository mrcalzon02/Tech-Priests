"""Separate Blender process: reopen source, reimport actual GLB, measure and render."""
import bpy,json,math,sys,hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[3];O=Path(sys.argv[sys.argv.index('--asset')+1]).resolve() if '--asset' in sys.argv else R/'art/source-to-3d/conclave-center/v01';V=O/'inspection';V.mkdir(exist_ok=True)
STEM='conclave-center-'+O.name.split('-')[0]
sys.path.insert(0,str(R/'tools/fmpl'));from blender_camera_guard import assert_clean
cfg=json.loads((O/'capture-profile.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def audit(label):
 scene=bpy.context.scene;meshes=[o for o in scene.objects if o.type=='MESH'];dg=bpy.context.evaluated_depsgraph_get();pts=[];triangles=0;degenerate=[];uv_missing=[];missing_images=[]
 for o in meshes:
  ev=o.evaluated_get(dg);m=ev.to_mesh();m.calc_loop_triangles();triangles+=len(m.loop_triangles);pts += [o.matrix_world@v.co for v in m.vertices]
  if not m.uv_layers:uv_missing.append(o.name)
  for t in m.loop_triangles:
   a,b,c=[m.vertices[i].co for i in t.vertices]
   if (b-a).cross(c-a).length<1e-12:degenerate.append(o.name)
  for mat in m.materials:
   if mat and mat.use_nodes:
    for n in mat.node_tree.nodes:
     if n.type=='TEX_IMAGE':
      if n.image:
       # Blender loads packed GLB/source images lazily. Decode actual pixels.
       try:_=n.image.pixels[0]
       except Exception:missing_images.append(o.name)
      else:missing_images.append(o.name)
  ev.to_mesh_clear()
 lo=[min(p[j] for p in pts) for j in range(3)];hi=[max(p[j] for p in pts) for j in range(3)]
 report=dict(label=label,meshes=len(meshes),triangles=triangles,bounds=[lo,hi],finite=all(math.isfinite(c) for p in pts for c in p),degenerate=degenerate,missing_uv=uv_missing,missing_images=missing_images,within_footprint=lo[0]>=-1 and hi[0]<=1 and lo[1]>=-1 and hi[1]<=1,ground_contact=abs(lo[2])<1e-5)
 report['passed']=report['finite'] and not degenerate and not uv_missing and not missing_images and report['within_footprint'] and report['ground_contact']
 return report
bpy.ops.wm.open_mainfile(filepath=str(O/(STEM+'.blend')));s=bpy.context.scene;bpy.context.view_layer.update();assert_clean(s,cfg,bpy)
source=audit('independently reopened packed source');source['packed_images']=[dict(name=i.name,packed=bool(i.packed_file),size=list(i.size)) for i in bpy.data.images if i.type=='IMAGE' and i.users]
source['all_used_images_packed']=all(x['packed'] for x in source['packed_images']);source['passed'] &= source['all_used_images_packed']
def bounds(o):
 p=[o.matrix_world@Vector(v) for v in o.bound_box];return [[min(v[j] for v in p) for j in range(3)],[max(v[j] for v in p) for j in range(3)]]
contact_results=[]
for row in json.loads((O/'contacts.json').read_text()):
 a,b=[bpy.data.objects[row[k]] for k in ('a','b')];aa,bb=bounds(a),bounds(b);gap=math.sqrt(sum(max(aa[0][j]-bb[1][j],bb[0][j]-aa[1][j],0)**2 for j in range(3)))
 contact_results.append(dict(**row,aabb_gap=gap,passed=gap<.009))
source['contacts']=contact_results;source['contact_limit']='AABB support-seat checks catch separation; not a full mesh intersection proof.';source['passed'] &= all(x['passed'] for x in contact_results)
for o in list(s.objects):
 if o.type in ('MESH','EMPTY'):bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(O/(STEM+'.glb')));s=bpy.context.scene;bpy.context.view_layer.update();export=audit('independent GLB import')
export['bounds_match_source']=max(abs(export['bounds'][i][j]-source['bounds'][i][j]) for i in range(2) for j in range(3))<1e-5;export['passed'] &= export['bounds_match_source']
# Collect imported roots, rotate model beneath the single camera.
roots=[o for o in s.objects if o.type in ('MESH','EMPTY') and o.parent is None];root=bpy.data.objects.new('GLB inspection turntable',None);s.collection.objects.link(root)
for o in roots:o.parent=root
try:
 prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
 for device in prefs.devices:device.use=device.type=='OPTIX'
 if any(d.use for d in prefs.devices):s.cycles.device='GPU'
except Exception:pass
s.cycles.samples=24
for i,angle in enumerate((0,90,180,270)):
 root.rotation_euler.z=math.radians(angle);s.render.filepath=str(V/f'export-d{i}.png');bpy.ops.render.render(write_still=True)
root.rotation_euler.z=0
clay=bpy.data.materials.new('Neutral clay inspection');clay.diffuse_color=(.35,.35,.35,1);s.view_layers[0].material_override=clay;s.render.filepath=str(V/'export-clay.png');bpy.ops.render.render(write_still=True);s.view_layers[0].material_override=None
receipt=dict(passed=source['passed'] and export['passed'],source=source,export=export,source_sha256=sha(O/(STEM+'.blend')),export_sha256=sha(O/(STEM+'.glb')),visual_review='Pending actual image viewing; file presence is not visual acceptance.')
(O/'inspection.json').write_text(json.dumps(receipt,indent=2)+'\n');print('CONCLAVE_INSPECTION',receipt['passed'],flush=True)
if not receipt['passed']:raise RuntimeError('Inspect measured failures in inspection.json')
