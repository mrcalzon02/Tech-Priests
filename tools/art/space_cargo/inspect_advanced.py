"""Actual source/GLB inspection plus measured below-grade aperture clipping."""
import bpy,json,math,hashlib,sys
import numpy as np
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/space-cargo-inventories/v01/advanced';V=O/'inspection';V.mkdir(exist_ok=True);manifest=json.loads((O/'occlusion.json').read_text());sys.path.insert(0,str(R/'tools/fmpl'));from below_grade_occlusion import add_grade_holdouts,add_aperture_mask
def model():return [o for o in bpy.context.scene.objects if o.type=='MESH' and not o.get('fmpl_render_only')]
def audit(label):
 bpy.context.view_layer.update();pts=[];bad=[];missing=[]
 for ob in model():
  me=ob.data;me.calc_loop_triangles();pts.extend(ob.matrix_world@v.co for v in me.vertices)
  if not me.uv_layers:missing.append(ob.name)
  for t in me.loop_triangles:
   a,b,c=[me.vertices[i].co for i in t.vertices]
   if (b-a).cross(c-a).length<1e-12:bad.append(ob.name)
  for mat in me.materials:
   if mat and mat.use_nodes:
    for n in mat.node_tree.nodes:
     if n.type=='TEX_IMAGE':
      if not n.image:missing.append(ob.name)
      else:_=n.image.pixels[0]
 lo=[min(p[k] for p in pts) for k in range(3)];hi=[max(p[k] for p in pts) for k in range(3)];bearings=[]
 for name in manifest['bearing_objects']:
  ob=bpy.data.objects[name];z=min((ob.matrix_world@v.co).z for v in ob.data.vertices);bearings.append(dict(name=name,bottom=z,passed=abs(z)<1e-5))
 contacts=[]
 for pair in json.loads((O/'contacts.json').read_text()):
  bounds=[]
  for name in (pair['a'],pair['b']):
   ob=bpy.data.objects[name];v=[ob.matrix_world@p.co for p in ob.data.vertices];bounds.append(([min(p[k] for p in v) for k in range(3)],[max(p[k] for p in v) for k in range(3)]))
  gap=max(max(bounds[0][0][k]-bounds[1][1][k],bounds[1][0][k]-bounds[0][1][k],0) for k in range(3));contacts.append(dict(**pair,gap=gap,passed=gap<.012))
 return dict(label=label,meshes=len(model()),bounds=[lo,hi],degenerate=bad,missing_uv_or_images=missing,bearings=bearings,contacts=contacts,passed=not bad and not missing and lo[0]>=-2.5 and hi[0]<=2.5 and lo[1]>=-2.5 and hi[1]<=2.5 and abs(lo[2]-manifest['model_bounds'][0][2])<1e-5 and all(b['passed'] for b in bearings) and all(c['passed'] for c in contacts))
def render(path):bpy.context.scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
def alpha(path):
 im=bpy.data.images.load(str(path),check_existing=False);a=np.array(im.pixels[:],dtype=np.float32).reshape(im.size[1],im.size[0],4)[:,:,3];bpy.data.images.remove(im);return a
bpy.ops.wm.open_mainfile(filepath=str(O/'advanced-space-cargo-v01.blend'));s=bpy.context.scene;source=audit('reopened packed source');source['all_images_packed']=all(im.packed_file for im in bpy.data.images if im.users and im.type=='IMAGE');source['passed'] &= source['all_images_packed']
for ob in list(s.objects):
 if ob.type in ('MESH','EMPTY'):bpy.data.objects.remove(ob,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(O/'advanced-space-cargo-v01.glb'));export=audit('independent actual GLB');export['bounds_match']=max(abs(export['bounds'][i][j]-source['bounds'][i][j]) for i in range(2) for j in range(3))<1e-5;export['passed'] &= export['bounds_match'];roots=[o for o in s.objects if o.type in ('MESH','EMPTY') and o.parent is None];root=bpy.data.objects.new('TEMP | inspection turntable',None);s.collection.objects.link(root)
for ob in roots:ob.parent=root
hold=add_grade_holdouts(s,bpy,manifest,parent=root);objects=model();s.cycles.samples=32;records=[]
for index,yaw in enumerate((0,90,180,270)):
 root.rotation_euler.z=math.radians(yaw);bpy.context.view_layer.update();render(V/f'export-d{index}.png')
 for ob in objects:ob.visible_camera=bool(ob.get('below_grade_geometry'))
 render(V/f'underground-d{index}.png');underground=alpha(V/f'underground-d{index}.png')
 for ob in objects:ob.visible_camera=False
 positive=add_aperture_mask(s,bpy,manifest,parent=root);render(V/f'aperture-mask-d{index}.png');mask=alpha(V/f'aperture-mask-d{index}.png')>.01;bpy.data.objects.remove(positive,do_unlink=True)
 dilated=np.logical_or.reduce([np.roll(np.roll(mask,dy,0),dx,1) for dy in (-1,0,1) for dx in (-1,0,1)]);leak=int(np.count_nonzero((underground>.01)&~dilated));records.append(dict(yaw=yaw,underground_visible_pixels=int(np.count_nonzero(underground>.01)),outside_aperture_pixels=leak,passed=leak==0 and np.count_nonzero(underground>.01)>100))
 for ob in objects:ob.visible_camera=True
root.rotation_euler.z=0
# Deliberately out-of-object below-grade geometry must be visible without the
# holdout and fully absent with it. This guards against a vacuous empty test.
for ob in objects:ob.visible_camera=False
bpy.ops.mesh.primitive_cube_add(size=1,location=(3.1,0,-.12));stress=bpy.context.object;stress.scale=(.35,.35,.12);hold.hide_render=True;render(V/'stress-unclipped.png');unclipped=int(np.count_nonzero(alpha(V/'stress-unclipped.png')>.01));hold.hide_render=False;render(V/'stress-clipped.png');clipped=int(np.count_nonzero(alpha(V/'stress-clipped.png')>.01));bpy.data.objects.remove(stress,do_unlink=True)
for ob in objects:ob.visible_camera=True
for ob in objects:
 if ob.get('cargo_glass'):ob.visible_camera=False
render(V/'open-well.png')
for ob in objects:
 if ob.get('cargo_glass'):ob.visible_camera=True
# Separate recess visibility and neutral geometry review from filled beauty.
stock=[o for o in objects if any(k in o.name for k in ('stock case','case hoop','case lid','case latch','wooden crate','barrel','tools tray','tool '))]
for ob in stock:ob.hide_render=True
render(V/'empty-well.png')
for ob in stock:ob.hide_render=False
clay=bpy.data.materials.new('QA | neutral clay');clay.use_nodes=True;clay.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.18,.18,.18,1);clay.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.8;backup={}
for ob in objects:
 backup[ob.name]=list(ob.data.materials)
 ob.data.materials.clear();ob.data.materials.append(clay)
 if ob.get('cargo_glass'):ob.hide_render=True
render(V/'clay-cutaway.png')
for ob in objects:
 ob.hide_render=False;ob.data.materials.clear()
 for mat in backup[ob.name]:ob.data.materials.append(mat)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();receipt=dict(passed=source['passed'] and export['passed'] and all(r['passed'] for r in records) and unclipped>100 and clipped==0,source=source,export=export,occlusion=records,stress=dict(unclipped_pixels=unclipped,clipped_pixels=clipped,passed=unclipped>100 and clipped==0),source_sha256=h(O/'advanced-space-cargo-v01.blend'),export_sha256=h(O/'advanced-space-cargo-v01.glb'),scope='Physical GLB reimport renders with manifest-reconstructed grade holdout; GLB itself does not implement engine cutaway clipping. One-pixel anti-alias boundary allowance.')
(O/'inspection.json').write_text(json.dumps(receipt,indent=2)+'\n');print('ADVANCED_CARGO_SOURCE_EXPORT_OCCLUSION',receipt['passed']);assert receipt['passed']
