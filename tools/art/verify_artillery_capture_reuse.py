"""Prove unchanged rigid geometry/materials/poses before reusing rendered pixels."""
import bpy,sys,json,hashlib
from array import array
from pathlib import Path
old,new,cache,out=map(Path,sys.argv[sys.argv.index('--')+1:]);out.mkdir(parents=True,exist_ok=True)
old_identity=json.loads((cache/'identity.json').read_text());old_ticks=old_identity['ticks']
def digest(value):return hashlib.sha256(json.dumps(value,sort_keys=True,default=str).encode()).hexdigest()
def value(v):
 if isinstance(v,(str,int,float,bool))or v is None:return v
 try:return tuple(v)
 except TypeError:return getattr(v,'name',str(type(v)))
def inspect(path):
 bpy.ops.wm.open_mainfile(filepath=str(path));s=bpy.context.scene
 root=bpy.data.objects['TURRET_TRAVERSE'];root.animation_data_clear();root.rotation_euler=(0,0,0)
 rounds=[bpy.data.objects['LOADED_ARTILLERY_SHELL_'+str(i)]for i in range(3)]
 def descendant(o,p):
  while o.parent:
   o=o.parent
   if o==p:return True
  return False
 objects=sorted([o for o in s.objects if o.type in ('MESH','CURVE')],key=lambda o:o.name)
 body=[o for o in objects if not any(descendant(o,r)for r in rounds)]
 image_hashes={}
 used_materials={m for o in objects for m in o.data.materials if m}
 used_images={n.image for m in used_materials if m.use_nodes for n in m.node_tree.nodes if n.type=='TEX_IMAGE'and n.image}
 for im in used_images:
  pixels=array('f',[0])*len(im.pixels);im.pixels.foreach_get(pixels)
  image_hashes[im.name]=(tuple(im.size),im.colorspace_settings.name,hashlib.sha256(pixels.tobytes()).hexdigest())
 materials={}
 for mat in bpy.data.materials:
  if not mat.use_nodes:continue
  materials[mat.name]=digest({'nodes':[(n.name,n.bl_idname,[(i.name,value(i.default_value))for i in n.inputs if hasattr(i,'default_value')],getattr(getattr(n,'image',None),'name',None))for n in mat.node_tree.nodes],
   'links':[(l.from_node.name,l.from_socket.name,l.to_node.name,l.to_socket.name)for l in mat.node_tree.links]})
 s.frame_set(1);bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();geometry={}
 for obj in objects:
  evaluated=obj.evaluated_get(deps);mesh=obj.data if obj.type=='MESH'else evaluated.to_mesh()
  geometry[obj.name]=digest({'vertices':[tuple(v.co)for v in mesh.vertices],'faces':[tuple(p.vertices)for p in mesh.polygons],
   'uv':[[tuple(v.uv)for v in layer.data]for layer in mesh.uv_layers],
   'modifiers':[(m.type,[(prop.identifier,value(getattr(m,prop.identifier)))for prop in m.bl_rna.properties if prop.type in ('BOOLEAN','INT','FLOAT','ENUM')and prop.identifier not in ('is_override_data',)])for m in obj.modifiers],
   'materials':[(m.name,materials[m.name])for m in mesh.materials if m]})
  if obj.type!='MESH':evaluated.to_mesh_clear()
 poses={layer:{}for layer in ('body','shell0','shell1','shell2')}
 for tick in range(601):
  s.frame_set(tick+1)
  for r in rounds:r.scale=(1,1,1)
  bpy.context.view_layer.update()
  transforms=[(o.name,tuple(tuple(row)for row in o.matrix_world))for o in body]
  base=digest(transforms);poses['body'][str(tick)]=base
  for cell,r in enumerate(rounds):poses['shell'+str(cell)][str(tick)]=digest((base,tuple(tuple(row)for row in r.matrix_world)))
 lights=[(o.name,tuple(tuple(row)for row in o.matrix_world),o.data.type,o.data.energy,tuple(o.data.color),getattr(o.data,'size',None))for o in s.objects if o.type=='LIGHT']
 return {'geometry':geometry,'images':image_hashes,'lights':sorted(lights,key=lambda item:item[0]),'poses':poses}
a=inspect(old);b=inspect(new)
print('GEOMETRY_DIFFERENCES',[name for name in a['geometry']if a['geometry'][name]!=b['geometry'].get(name)],flush=True)
assert a['geometry']==b['geometry'],'Source geometry or surfacing changed; do not reuse rendered pixels'
print('IMAGE_DIFFERENCES',[name for name in a['images']if a['images'][name]!=b['images'].get(name)],flush=True)
if a['lights']!=b['lights']:print('LIGHTS',a['lights'],b['lights'],flush=True)
assert a['images']==b['images']and a['lights']==b['lights'],'Lighting or packed images changed'
aliases={}
for layer in a['poses']:
 lookup={a['poses'][layer][str(t)]:t for t in old_ticks}
 aliases[layer]={tick:lookup[signature]for tick,signature in b['poses'][layer].items()if signature in lookup}
report={'status':'VERIFIED_IDENTICAL_RENDER_INPUTS','source_sha256':hashlib.sha256(new.read_bytes()).hexdigest(),
 'cache_source_sha256':hashlib.sha256(old.read_bytes()).hexdigest(),'cache_identity':old_identity,
 'geometry_signature':digest(a['geometry']),'packed_images_signature':digest(a['images']),'aliases':aliases,
 'scope':'Only matching rigid body/shell transforms with identical authored meshes, modifier parameters, UVs, shader inputs, packed images and lighting may reuse pixels. Changed insertion poses must render.'}
assert report['cache_source_sha256']==old_identity['source_sha256']
(out/'reuse.json').write_text(json.dumps(report,indent=2)+'\n')
print('ARTILLERY_PIXEL_REUSE_VERIFIED',{layer:len(mapping)for layer,mapping in aliases.items()},flush=True)
