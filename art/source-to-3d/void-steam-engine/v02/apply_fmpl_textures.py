"""FMPL source-indexed surfacing. Preserve every geometry vertex and keyed mechanism.

Eight canonical image-backed FMPL materials plus model-specific instances.
Copper uses one declared, image-baked pigment derivative of canonical brass;
its ORM and normal remain original. No generic replacement noise shaders.
"""
import bpy,json,math,sys,hashlib,tempfile
import numpy as np
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent
def locate_repo():
 for parent in (O,*O.parents):
  for candidate in (parent,parent/'model-production'):
   if (candidate/'tools/fmpl/FMPL.json').is_file():return candidate
 raise FileNotFoundError('Pass a source checkout containing tools/fmpl and canonical material maps.')
REPO=locate_repo()
(O/'export-temp').mkdir(exist_ok=True);tempfile.tempdir=str(O/'export-temp')
sys.path.insert(0,str(REPO/'art/source-to-3d/shared-parts/industrial-asset-library'))
from import_materials import import_materials
sys.path.insert(0,str(REPO/'tools/fmpl'))
from blender_camera_guard import assert_clean
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
source=O/'studies/geometry-source.blend'
bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene
geometry={o.name:[tuple(v.co) for v in o.data.vertices] for o in s.objects if o.type=='MESH'}
old_materials={o.name:o.data.materials[0].name.split(' | ')[-1] for o in s.objects if o.type=='MESH'}
catalog=json.loads((O/'fmpl-source-catalog.json').read_text());local=json.loads((REPO/'art/source-to-3d/shared-parts/industrial-asset-library/catalog.json').read_text());assert catalog==local
role_ids={'cast-chassis':'gunmetal_dark','pressure-steel':'machine_steel','machined-bronze':'brass','copper-winding':'brass','martian-enamel':'martian_red','ceramic-insulator':'insulator','rubber-belt':'primer_black','polished-piston':'machined_bright','control-phosphor':'indicator_green'}
ids=sorted(set(role_ids.values()));provenance={}
for rec in catalog['materials']:
 if rec['material_id'] not in ids:continue
 row={'material_id':rec['material_id'],'family':rec['family'],'source_commit':catalog['source_commit'],'uv_repeat_per_tile_unit':rec['uv_repeat_per_tile_unit'],'maps':{}}
 for kind,entry in rec['maps'].items():
  p=REPO/entry['source_path'];data=p.read_bytes();blob=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest();assert blob==entry['git_blob_sha'],(p,blob)
  row['maps'][kind]={'source_path':entry['source_path'],'git_blob_sha':blob,'sha256':sha(p),'color_space':'sRGB' if kind=='albedo' else 'Non-Color'}
 provenance[rec['material_id']]=row
base=import_materials(REPO,ids,pack=True);materials={};surface_rows=[]
for role,mid in role_ids.items():
 m=base[mid].copy();m.name='VOID FMPL | '+role;m['void_surface_role']=role;m['fmpl_model_specific_placement']='Continuous physical swept/cylindrical UVs; planar machined caps and chassis panels; repeat1.25/tile.'
 m['fmpl_original_map_identities']=json.dumps(provenance[mid]['maps'],sort_keys=True)
 row={'role':role,'fmpl_material_id':mid,'model_specific_instance':m.name,'original_maps':provenance[mid]['maps'],'texture_repeat_per_tile':1.25}
 if role=='copper-winding':
  # A declared copper pigment derivative of the indexed FMPL metal, preserving
  # its actual machined image detail. ORM and normal are not replaced/generated.
  tex=m.node_tree.nodes['TP_LIBRARY_ALBEDO'];im=tex.image;data=np.array(im.pixels[:],dtype=np.float32).reshape(im.size[1],im.size[0],4);data[:,:,:3]*=np.array([1.00,.56,.30]);new=bpy.data.images.new('void-copper-from-fmpl-brass-albedo',width=im.size[0],height=im.size[1],alpha=True);new.pixels.foreach_set(data.ravel());new.file_format='PNG';(O/'textures').mkdir(exist_ok=True);p=O/'textures/void-copper-from-fmpl-brass-albedo.png';new.filepath_raw=str(p);new.save();new.pack();tex.image=new
  row['declared_derivative']={'operation':'Linear RGB multiply [1.0,0.56,0.30], copper winding pigment only','source_albedo_sha256':provenance[mid]['maps']['albedo']['sha256'],'derived_albedo_sha256':sha(p),'derived_file':str(p.relative_to(O)),'normal_and_orm_original':True}
 if role=='control-phosphor':
  bs=m.node_tree.nodes['Principled BSDF'];bs.inputs['Emission Color'].default_value=(.012,.19,.025,1);bs.inputs['Emission Strength'].default_value=.65
  row['model_specific_emission']='Low green instrument phosphor; original albedo/ORM/normal retained.'
 materials[role]=m;surface_rows.append(row)

def cylinder_uv(o):
 """Primitive cylinders have interleaved lower/upper vertices in local Z."""
 vv=[v.co for v in o.data.vertices];radii=[math.hypot(v.x,v.y) for v in vv]
 if min(radii)<1e-6 or max(radii)-min(radii)>1e-5:return False
 zs=sorted(set(round(v.z,6) for v in vv))
 if len(zs)!=2:return False
 uv=o.data.uv_layers.active or o.data.uv_layers.new();scale=1.25;rx=max(radii)*abs(o.scale.x);ry=max(radii)*abs(o.scale.y)
 perimeter=math.pi*(3*(rx+ry)-math.sqrt((3*rx+ry)*(rx+3*ry)))
 for p in o.data.polygons:
  cap=max(vv[o.data.loops[i].vertex_index].z for i in p.loop_indices)-min(vv[o.data.loops[i].vertex_index].z for i in p.loop_indices)<1e-6
  angles=[(math.atan2(vv[o.data.loops[i].vertex_index].y,vv[o.data.loops[i].vertex_index].x)/math.tau)%1 for i in p.loop_indices];seam=max(angles)-min(angles)>.5
  for i,a in zip(p.loop_indices,angles):
   c=vv[o.data.loops[i].vertex_index]
   uv.data[i].uv=(c.x*abs(o.scale.x)*scale,c.y*abs(o.scale.y)*scale) if cap else (((a+1 if seam and a<.5 else a)*perimeter*scale),c.z*abs(o.scale.z)*scale)
 return True

def sweep_uv(o):
 """Retain the authored rings and unwrap by real centreline/circumference."""
 vv=[v.co for v in o.data.vertices];N=len(vv);n=None
 for candidate in (6,8,16,24,32,48,64):
  if N%candidate or N<candidate*2:continue
  normal=(vv[1]-vv[0]).cross(vv[2]-vv[0])
  if normal.length<1e-10:continue
  normal.normalize()
  if max(abs((v-vv[0]).dot(normal)) for v in vv[:candidate])<1e-5 and max(abs((v-vv[0]).dot(normal)) for v in vv[candidate:candidate+min(candidate,6)])>1e-5:n=candidate;break
 if n is None:return False
 hollow=bool(o.get('full_hollow_wall'));rings=N//n//(2 if hollow else 1)
 if rings<2:return False
 centers=[sum(vv[k*n:(k+1)*n],Vector())/n for k in range(rings)];radii=[]
 for k,c in enumerate(centers):radii.append(sum((v-c).length for v in vv[k*n:(k+1)*n])/n)
 # Reject accidental detection in a bevelled box or unrelated donor geometry.
 if any(max(abs((v-c).length-radii[k]) for v in vv[k*n:(k+1)*n])>max(.0001,radii[k]*.02) for k,c in enumerate(centers)):return False
 closed=not hollow and all(len(p.vertices)==3 for p in o.data.polygons) and ('winding' in o.name or 'drive belt' in o.name)
 lengths=[0.]
 for a,b in zip(centers,centers[1:]):lengths.append(lengths[-1]+(b-a).length)
 total=lengths[-1]+((centers[-1]-centers[0]).length if closed else 0)
 uv=o.data.uv_layers.active or o.data.uv_layers.new();scale=1.25
 for p in o.data.polygons:
  info=[]
  for i in p.loop_indices:
   idx=o.data.loops[i].vertex_index;layer=idx//(rings*n);ring,j=divmod(idx%(rings*n),n);info.append((i,layer,ring,j))
  cap=len(set(r for _,_,r,_ in info))==1
  if cap:
   r=info[0][2];c=centers[r];a=(vv[r*n]-c).normalized();t=(centers[min(r+1,rings-1)]-centers[max(r-1,0)]).normalized();b=t.cross(a).normalized()
   for i,layer,ring,j in info:
    q=vv[o.data.loops[i].vertex_index]-c;uv.data[i].uv=(q.dot(a)*scale,q.dot(b)*scale)
  else:
   seam=max(j for _,_,_,j in info)-min(j for _,_,_,j in info)>n/2;endseam=closed and max(r for _,_,r,_ in info)-min(r for _,_,r,_ in info)>rings/2
   for i,layer,r,j in info:
    radius=(vv[layer*rings*n+r*n+j]-centers[r]).length;u=(j+n if seam and j<n/2 else j)/n;v=total if endseam and r==0 else lengths[r];uv.data[i].uv=(u*math.tau*radius*scale,v*scale)
 return True

def panel_uv(o):
 uv=o.data.uv_layers.active or o.data.uv_layers.new()
 for p in o.data.polygons:
  axes=sorted(range(3),key=lambda k:abs(p.normal[k]))[:2]
  for i in p.loop_indices:
   c=o.data.vertices[o.data.loops[i].vertex_index].co;uv.data[i].uv=(c[axes[0]]*abs(o.scale[axes[0]])*1.25,c[axes[1]]*abs(o.scale[axes[1]])*1.25)

uv_report=[]
for o in s.objects:
 if o.type!='MESH':continue
 role=old_materials[o.name];o.data.materials.clear();o.data.materials.append(materials[role])
 if cylinder_uv(o):mode='continuous cylinder wall with planar end caps'
 elif sweep_uv(o):mode='continuous centreline arc length / physical circumference, separate planar caps'
 else:panel_uv(o);mode='part-local physical panel projection'
 o.data.uv_layers.active.name='FMPL physical UV 1.25 per tile';o['fmpl_uv_method']=mode;o['fmpl_surface_role']=role
 uv_report.append({'object':o.name,'role':role,'fmpl_material_id':role_ids[role],'uv_method':mode})
 assert geometry[o.name]==[tuple(v.co) for v in o.data.vertices],o.name
for _ in range(3):bpy.data.orphans_purge(do_local_ids=True,do_linked_ids=False,do_recursive=True)
profile=json.loads((O/'capture-profile.json').read_text());s.frame_set(1);assert_clean(s,profile,bpy);bpy.ops.file.pack_all()
out=O/'void-steam-v02.blend';bpy.ops.wm.save_as_mainfile(filepath=str(out),compress=True);bpy.ops.wm.open_mainfile(filepath=str(out));s=bpy.context.scene
bpy.ops.object.select_all(action='DESELECT');root=bpy.data.objects['EXPORT | Void Steam Engine']
for o in [root,*root.children_recursive]:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'void-steam-v02.glb'),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_force_sampling=True,export_frame_range=True,export_anim_slide_to_zero=True,export_apply=True)
report={'status':'FMPL-textured-candidate-native-recapture-pending','prior_geometry_source_sha256':sha(source),'source_sha256':sha(out),'runtime_sha256':sha(O/'void-steam-v02.glb'),'all_mesh_vertices_and_mechanism_preserved':True,'canonical_catalog_source_commit':catalog['source_commit'],'canonical_pinned_catalog_read_commit':'bec7c7ed72e77cd2e0cdacc9df0103c46b40120f','all_original_source_maps_git_blob_verified':True,'source_maps_not_duplicated_or_modified':True,'canonical_material_ids':ids,'role_instances':surface_rows,'uv_assignments':uv_report,'packed_images':len([im for im in bpy.data.images if im.users and im.packed_file]),'native_evidence_from_previous_custom_maps_not_final':True,'owner_visual_approved':False}
(O/'fmpl-surface-manifest.json').write_text(json.dumps(report,indent=2)+'\n');print('VOID_FMPL_SURFACE_PASS',len(uv_report),report['packed_images'],flush=True)
