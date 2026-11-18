"""Soften overstated stone pores without moving the reviewed cache geometry."""
from pathlib import Path
import sys,json,hashlib,shutil
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/martian-stone-cache/v01';T=O/'textures'
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
if '--blender' not in sys.argv:
 import numpy as np
 from PIL import Image
 study=O/'studies/over-pitted-stone';study.mkdir(parents=True,exist_ok=True)
 for name in ('martian-stone-cache-v01.blend','martian-stone-cache-v01.glb','source-front.png','surface-plan.json','visual-review.json'):
  if not (study/name).exists():shutil.copy2(O/name,study/name)
 if not (study/'textures').exists():shutil.copytree(T,study/'textures')
 rng=np.random.default_rng(5402);N=1024;y,x=np.mgrid[0:N,0:N]/N
 def noise(n):return np.asarray(Image.fromarray(np.uint8(rng.uniform(0,255,(n,n)))).resize((N,N),Image.Resampling.BICUBIC),dtype=float)/255-.5
 broad=noise(8);mottle=noise(28);grain=noise(150);fine=noise(1024)
 # Large mineral variation carries the stone identity; tiny pits stay subordinate.
 value=.57+.17*broad+.075*mottle+.035*grain+.010*fine
 pores=np.maximum(0,-grain-.22)**2
 height=.020*broad+.014*mottle+.011*grain+.002*fine-.045*pores
 gy,gx=np.gradient(height);nx=-gx*35;ny=-gy*35;nz=np.ones_like(nx);length=np.sqrt(nx*nx+ny*ny+nz*nz)
 normal=np.stack([nx/length*.5+.5,ny/length*.5+.5,nz/length*.5+.5],axis=2)
 for role in ('stone','ground-stone','dressed-stone'):
  rgb=np.stack([value*165,value*150,value*121],axis=2)
  if role=='ground-stone':rgb*=np.clip(.56+y*.72,.56,1)[...,None]
  rough=np.clip((.79 if role=='dressed-stone' else .87)+.04*mottle,0,1)
  orm=np.stack([np.ones_like(rough),rough,np.zeros_like(rough)],axis=2)
  for kind,array in [('albedo',rgb/255),('normal',normal),('orm',orm)]:Image.fromarray(np.uint8(np.clip(array*255,0,255))).save(T/(role+'-'+kind+'.png'))
 plan=json.loads((O/'surface-plan.json').read_text());plan['revision']='Stone material pass 2: restrained pores, broad mineral mottle, separate dressed front stone; geometry unchanged'
 plan['regions']['stone']='Warm weathered rubble: broad mineral variation, subdued small pores; chipped edges remain actual geometry.'
 plan['regions']['dressed-stone']='Carved front wall section: same quarry family, smoother dressed face and lower roughness; near-flush original skull remains separate.'
 for role in ('stone','ground-stone','dressed-stone'):plan['maps'][role]={k:dict(path=(T/(role+'-'+k+'.png')).relative_to(R).as_posix(),sha256=h(T/(role+'-'+k+'.png'))) for k in ('albedo','normal','orm')}
 (O/'surface-plan.json').write_text(json.dumps(plan,indent=2)+'\n');print('CACHE_STONE_MAP_REVISION_READY');sys.exit()
import bpy
bpy.ops.wm.open_mainfile(filepath=str(O/'martian-stone-cache-v01.blend'));s=bpy.context.scene
def geometry():
 return {ob.name:hashlib.sha256(repr((list(ob.matrix_world),[tuple(v.co) for v in ob.data.vertices],[tuple(p.vertices) for p in ob.data.polygons],[tuple(v.uv) for v in ob.data.uv_layers.active.data])).encode()).hexdigest() for ob in s.objects if ob.type=='MESH'}
before=geometry()
for image in bpy.data.images:
 if image.name in [r+'-'+k+'.png' for r in ('stone','ground-stone') for k in ('albedo','normal','orm')]:
  image.unpack(method='REMOVE');image.filepath=str(T/image.name);image.reload();image.pack()
for mat in bpy.data.materials:
 if mat.name in ('Martian cache | stone','Martian cache | ground-stone'):
  for node in mat.node_tree.nodes:
   if node.type=='NORMAL_MAP':node.inputs['Strength'].default_value=.35
tablet=bpy.data.objects['Grounded carved circuit receiving tablet'];mat=bpy.data.materials['Martian cache | stone'].copy();mat.name='Martian cache | dressed front stone';tablet.data.materials[0]=mat
for node in mat.node_tree.nodes:
 if node.type=='TEX_IMAGE':
  kind=node.name.rsplit(' ',1)[-1];node.image=bpy.data.images.load(str(T/('dressed-stone-'+kind+'.png')),check_existing=True)
  if kind!='albedo':node.image.colorspace_settings.name='Non-Color'
 if node.type=='NORMAL_MAP':node.inputs['Strength'].default_value=.12
assert before==geometry(),'Material pass moved reviewed geometry/UVs'
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(O/'martian-stone-cache-v01.blend'),compress=True)
bpy.data.libraries.write(str(O/'martian-stone-enclosure-kit.blend'),{bpy.data.collections['CACHE KIT | Stone enclosure']},fake_user=True,compress=True)
bpy.ops.object.select_all(action='DESELECT')
for ob in s.objects:
 if ob.type=='MESH':ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'martian-stone-cache-v01.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
s.render.filepath=str(O/'source-front.png');bpy.ops.render.render(write_still=True)
(O/'material-revision.json').write_text(json.dumps(dict(geometry_unchanged=True,geometry_hashes=before,source_sha256=h(O/'martian-stone-cache-v01.blend'),export_sha256=h(O/'martian-stone-cache-v01.glb'),owner_approval='Pending review of material candidate'),indent=2)+'\n')
