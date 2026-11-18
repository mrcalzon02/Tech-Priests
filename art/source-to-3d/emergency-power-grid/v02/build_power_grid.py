"""Authored one-tile refractory Emergency Power Grid; FMPL source-indexed images."""
import bpy,bmesh,math,json,hashlib,sys,tempfile
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent
REPO=next(c for p in[O,*O.parents]for c in(p,p/'model-production')if(c/'tools/fmpl/FMPL.json').is_file());sys.path[:0]=[str(O),str(REPO/'tools/fmpl'),str(REPO/'art/source-to-3d/shared-parts/industrial-asset-library')]
from mesh_util import box,cylinder,tube,mesh,lathe
from fmpl_uv import cylinder_uv,sweep_uv,panel_uv
from import_materials import import_materials
from blender_camera_guard import install_canonical_camera,assert_clean,temporary_inspection_camera
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();(O/'export-temp').mkdir(exist_ok=True);tempfile.tempdir=str(O/'export-temp')
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;col=bpy.data.collections.new('POWER GRID | one-tile passive three-terminal pole');s.collection.children.link(col);root=bpy.data.objects.new('EXPORT | Emergency Power Grid',None);col.objects.link(root)
ids=['ferrocrete','ferrocrete_dark','iron','machine_steel','brass','oxide_red','dark_recess','indicator_green','alert','insulator','parchment'];base=import_materials(REPO,ids,pack=True);mats={};roles=[];catalog=json.loads((REPO/'art/source-to-3d/shared-parts/industrial-asset-library/catalog.json').read_text())
for mid in ids:
 m=base[mid].copy();m.name='POWER GRID FMPL | '+mid;mats[mid]=m;record=next(q for q in catalog['materials']if q['material_id']==mid);maps={}
 for kind,rec in record['maps'].items():
  p=REPO/rec['source_path'];data=p.read_bytes();assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==rec['git_blob_sha'];maps[kind]={'source_path':rec['source_path'],'git_blob_sha':rec['git_blob_sha'],'sha256':sha(p),'color_space':'sRGB'if kind=='albedo'else'Non-Color'}
 roles.append({'role':mid,'fmpl_material_id':mid,'model_specific_instance':m.name,'original_maps':maps,'texture_repeat_per_tile':4.0})
stone=mats['ferrocrete'];soot=mats['ferrocrete_dark'];iron=mats['iron'];steel=mats['machine_steel'];brass=mats['brass'];red=mats['oxide_red'];dark=mats['dark_recess'];green=mats['indicator_green'];hot=mats['alert'];ceramic=mats['insulator']
parchment=mats['parchment']
# Retain the original indexed pixels; only this model-specific hot material has emission.
bs=next(n for n in hot.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Emission Color'].default_value=(1,.13,.006,1);bs.inputs['Emission Strength'].default_value=2.5

def B(n,p,d,m=iron,parent=root,bevel=.004):return box('POWER GRID | '+n,p,d,m,col,parent,bevel)
def C(n,p,r,d,m=steel,axis='Z',parent=root,seg=24):return cylinder('POWER GRID | '+n,p,r,d,m,col,parent,axis,seg)
def E(n,p):o=bpy.data.objects.new('POWER GRID | '+n,None);col.objects.link(o);o.parent=root;o.location=p;return o
def pipe(n,points,r,m=steel,parent=root,bore=0):
 points=[Vector(p)for p in points];samples=[(p,(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized(),r,bore)for i,p in enumerate(points)];return tube('POWER GRID | '+n,samples,m,col,parent,24)
def ring(n,p,outer,inner,depth,m=steel,axis='Z',parent=root):
 v=Vector((1,0,0)if axis=='X'else(0,1,0)if axis=='Y'else(0,0,1));q=Vector(p);return tube('POWER GRID | '+n,[(q-v*depth/2,v,outer,inner),(q+v*depth/2,v,outer,inner)],m,col,parent,32)
def stud(n,p,axis='Y',r=.009):return C(n,p,r,.012,brass,axis,seg=12)


# Actual baked original FMPL wood images, not a procedural-only runtime shader.
wood_manifest=json.loads((O/'cedar-bake-manifest.json').read_text());wood=bpy.data.materials.new('POWER GRID FMPL | cedar-derived');wood.use_nodes=True;nodes=wood.node_tree.nodes;links=wood.node_tree.links;bs=nodes['Principled BSDF'];wood_maps={}
for kind,rec in wood_manifest['baked_maps'].items():
 p=O/rec['file'];assert sha(p)==rec['sha256'];im=bpy.data.images.load(str(p),check_existing=True);im.colorspace_settings.name=rec['color_space'];im.pack();n=nodes.new('ShaderNodeTexImage');n.image=im;wood_maps[kind]=n
links.new(wood_maps['albedo'].outputs['Color'],bs.inputs['Base Color']);normal=nodes.new('ShaderNodeNormalMap');links.new(wood_maps['normal'].outputs['Color'],normal.inputs['Color']);links.new(normal.outputs[0],bs.inputs['Normal']);separate=nodes.new('ShaderNodeSeparateColor');links.new(wood_maps['orm'].outputs['Color'],separate.inputs['Color']);links.new(separate.outputs['Green'],bs.inputs['Roughness']);links.new(separate.outputs['Blue'],bs.inputs['Metallic'])
roles.append({'role':'cedar-derived','fmpl_material_id':'power-grid-cedar-original-fmpl','model_specific_instance':wood.name,'model_specific_baked_maps':wood_manifest['baked_maps'],'source_preset':wood_manifest['source_preset'],'provenance':wood_manifest,'grain':'UV.V follows local beamZ; all end grain covered by metal caps.'})

def W(n,a,b,r):
 a,b=Vector(a),Vector(b);o=C(n,tuple((a+b)/2),r,(b-a).length,wood,seg=8);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o['power_grid_longitudinal_wood']=True;return o
# Rigid founded timber frame, keyed metal shoes, grounded braces.
B('dressed stone footing',(0,0,.040),(.88,.80,.080),soot,bevel=.022)
for x,h in[(-.27,.88),(0,1.15),(.27,.88)]:
 C('founded iron post shoe',(x,0,.110),.079,.100,iron,seg=16)
 W('longitudinal timber post',(x,0,.10),(x,0,h),.055)
 ring('retained shoe top band',(x,0,.155),.065,.055,.025,brass)
 C('sealed timber end cap',(x,0,h),.059,.026,iron,seg=16)
 for z in(.105,.151):C('shoe seated cross bolt',(x,-.068,z),.011,.035,steel,'Y',seg=12)
for z in(.43,.74):
 W('retained timber crossarm',(-.35,-.10,z),(.35,-.10,z),.040)
 for x in(-.27,0,.27):
  B('crossarm retained joining strap',(x,-.0575,z),(.105,.012,.15),iron)
  for dz in(-.048,.048):C('crossarm strap fitted bolt',(x,-.078,z+dz),.010,.040,brass,'Y',seg=12)
 for x in(-.355,.355):C('crossarm endgrain metal cap',(x,-.10,z),.047,.030,iron,'X',seg=16)
for side in(-1,1):W('founded diagonal timber brace',(side*.27,.025,.17),(0,.025,.70),.027)
# One continuous hand-thrown ceramic profile for each electrical insulator.
anchors={}
for role,x,bottom,material in[('red',-.27,.88,red),('copper',0,1.15,brass),('green',.27,.88,green)]:
 profile=[(0,bottom-.008),(.045,bottom-.008),(.045,bottom+.006)]
 for k in range(5):
  z=bottom+.016+k*.049;profile.extend([(.072,z),(.076,z+.010),(.048,z+.020),(.040,z+.038)])
 profile.extend([(.035,bottom+.272),(0,bottom+.272)])
 lathe('POWER GRID | continuous '+role+' ceramic insulator',profile,(x,0),ceramic,col,root,64)
 C(role+' fitted terminal lower crown',(x,0,bottom+.276),.045,.024,steel,seg=24)
 C(role+' retained conductor cap',(x,0,bottom+.305),.028,.034,material,seg=24)
 C(role+' fixed wire contact button',(x,0,bottom+.323),.018,.014,brass,seg=16)
 anchors[role]={'model_position':[x,0,bottom+.330],'native_wire_position':[x,-(bottom+.330)/math.sqrt(2)]}
# A supported legend box explains the three independent circuits; it is a
# fixed lacquered diagram, not a false power-generation/status display.
B('junction box founded foot',(0,-.18,.120),(.34,.20,.10),iron)
B('sealed timber junction board',(0,-.18,.275),(.32,.16,.27),iron)
# The junction board stands on its founded foot; cable space stays clear behind it.
B('legend seated dark backing',(0,-.269,.282),(.27,.025,.20),dark)
B('fixed lacquered green legend',(0,-.285,.282),(.235,.012,.160),green)
for x in(-.145,.145):B('legend retained upright',(x,-.278,.282),(.025,.040,.225),brass)
for z in(.17,.394):B('legend retained sill lintel',(0,-.278,z),(.315,.040,.025),brass)
for x in(-.075,0,.075):
 B('legend seated circuit trace',(x,-.294,.282),(.008,.010,.115),brass,bevel=.001)
 C('legend terminal witness',(x,-.302,.345),.011,.014,red if x<0 else green if x>0 else brass,'Y',seg=12)
for x in(-.13,.13):
 for z in(.185,.38):C('legend retained corner head',(x,-.299,z),.009,.023,steel,'Y',seg=12)
# Actual separate internal lead routes terminate in closed glands on the board.
# These are insulated electrical leads, with no fluid mouths or native fluid ports.
for x,z in[(-.27,.48),(0,.58),(.27,.48)]:
 points=[(x,.055,z),(x,.115,z),(x*.5,.115,.24),(x*.5,-.105,.24)]
 if x==0:points=[(0,.055,z),(0,.115,z),(.11,.115,z),(.11,.115,.24),(.11,-.075,.24),(0,-.075,.24),(0,-.105,.24)]
 pipe('attached closed electrical lead',points,.011,dark)
 C('closed lead post gland',(x,.055,z),.021,.030,brass,'Y')
 C('closed lead junction gland',(x*.5,-.105,.24),.021,.030,steel,'Y')
for x in(-.37,.37):
 for y in(-.30,.30):
  B('foundation anchor seat',(x,y,.087),(.052,.055,.024),iron)
  C('foundation seated retained head',(x,y,.108),.015,.022,brass,seg=12)
# Bake final bevels, assign physical UVs and longitudinal timber-specific maps.
dg=bpy.context.evaluated_depsgraph_get();baked={o:bpy.data.meshes.new_from_object(o.evaluated_get(dg))for o in list(col.objects)if o.type=='MESH'and o.modifiers}
for o,m in baked.items():o.data=m;o.modifiers.clear()
uvs=[]
for o in col.objects:
 if o.type!='MESH':continue
 mode='cylinder'if cylinder_uv(o)else'sweep'if sweep_uv(o)else'panel'
 if mode=='panel':panel_uv(o)
 if o.get('power_grid_longitudinal_wood'):
  # Cylindrical side U covers one circumference, V is actual local length.
  for p in o.data.polygons:
   coords=[o.data.vertices[o.data.loops[i].vertex_index].co for i in p.loop_indices];cap=max(v.z for v in coords)-min(v.z for v in coords)<1e-6;angles=[(math.atan2(v.y,v.x)/math.tau)%1 for v in coords];seam=max(angles)-min(angles)>.5
   for i,v,t in zip(p.loop_indices,coords,angles):o.data.uv_layers.active.data[i].uv=(v.x+.5,v.y+.5)if cap else((t+1 if seam and t<.5 else t),v.z/1.8+.5)
  mode='longitudinal-cedar-localZ-covered-endgrain'
 else:
  for uv in o.data.uv_layers.active.data:uv.uv*=4/1.25
 o['fmpl_uv_method']=mode;uvs.append({'object':o.name,'method':mode,'material':o.data.materials[0].name})
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
for _ in range(3):bpy.data.orphans_purge(do_local_ids=True,do_linked_ids=False,do_recursive=True)
profile={'camera_policy':'fmpl.factorio45.v1','capture_kind':'entity','orientation_policy':'fixed','directions':[0],'native_directions':[0],'states':{'idle':[0],'working':[0]},'source_size':512,'fps':1,'camera_override':{'type':'ORTHO','elevation_deg':45,'azimuth_deg':0,'distance':8.48528137423857,'ortho_scale':2.8,'target':[0,0,.6]}}
install_canonical_camera(s,profile,bpy);s.render.engine='CYCLES';s.cycles.samples=32;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.frame_start=s.frame_end=1
s.world=bpy.data.worlds.new('Passive pole studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.25,.25,1)
for loc,power,size in[((2,-3,4),240,3),((-3,2,4),180,3)]:
 l=bpy.data.lights.new('Grid studio','AREA');l.energy=power;l.size=size;o=bpy.data.objects.new(l.name,l);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.6))-o.location).to_track_quat('-Z','Y').to_euler()
s.frame_set(1);assert_clean(s,profile,bpy);bpy.ops.file.pack_all();source=O/'power-grid-v02.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True);bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;root=bpy.data.objects['EXPORT | Emergency Power Grid'];bpy.ops.object.select_all(action='DESELECT')
for o in[root,*root.children_recursive]:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'power-grid-v02.glb'),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=False,export_apply=True)
(O/'capture-profile.json').write_text(json.dumps(profile,indent=2));(O/'wire-anchors.json').write_text(json.dumps(anchors,indent=2));(O/'fmpl-surface-manifest.json').write_text(json.dumps({'status':'candidate-not-native-integrated','source_sha256':sha(source),'runtime_sha256':sha(O/'power-grid-v02.glb'),'role_instances':roles,'uv_assignments':uvs,'native_footprint':[1,1],'native_directions':[0],'animation_applicability':'Passive native pole. Fixed geometry and sockets; live native wire/network behavior. No moving mechanism invented.','all_original_source_maps_git_blob_verified':True,'wood_original_fmpl_preset_actually_baked_to_images':True,'owner_visual_approved':False},indent=2))
projection=bpy.data.objects.new('UNSAVED square ground',None);s.collection.objects.link(projection);projection.scale.y=math.sqrt(2);root.parent=projection;s.render.resolution_x=s.render.resolution_y=768;s.render.filepath=str(O/'front-review.png');bpy.ops.render.render(write_still=True);projection.scale.y=1
with temporary_inspection_camera(s,bpy,'true proportions')as c:
 c.data.type='ORTHO';c.data.ortho_scale=2.1;c.location=(2,-3,2);c.rotation_euler=(Vector((0,0,.75))-c.location).to_track_quat('-Z','Y').to_euler();s.camera=c;s.render.filepath=str(O/'detail-review.png');bpy.ops.render.render(write_still=True)
print('POWER_GRID_EDITABLE_SOURCE_SAVED',sha(source),flush=True)
