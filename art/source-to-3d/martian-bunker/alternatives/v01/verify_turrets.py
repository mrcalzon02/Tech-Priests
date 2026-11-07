import bpy,json,sys,hashlib,struct,math
from pathlib import Path
from mathutils import Vector
O=Path(sys.argv[sys.argv.index('--')+1]).resolve();build=json.loads((O/'build_validation.json').read_text());report={}
for variant in ['energy_dish','grenade_lobber_12']:
 bpy.ops.wm.open_mainfile(filepath=str(O/(variant+'_v01.blend')));S=bpy.context.scene;S.frame_set(1);bpy.context.view_layer.update()
 col=bpy.data.collections[variant.upper()];meshes=[o for o in col.objects if o.type=='MESH'];base=bpy.data.collections['EXISTING_BUNKER_BASE_UNCHANGED']
 assert len(base.objects)==build['base_mesh_count']
 for o in base.objects:
  before=build['source_base_signature'][o.name]
  assert hashlib.sha256(repr([tuple(v.co) for v in o.data.vertices]).encode()).hexdigest()==before['mesh'],o.name
  assert max(abs(o.matrix_world[i][j]-before['matrix'][i][j]) for i in range(4) for j in range(4))<1e-5,o.name
 assert all(im.packed_file or im.source in ['GENERATED','VIEWER'] for im in bpy.data.images),[(i.name,i.filepath) for i in bpy.data.images if not i.packed_file]
 assert all(o.data.uv_layers and len(o.data.uv_layers.active.data)>0 for o in meshes)
 root=bpy.data.objects['TURRET_TRAVERSE'];pivot=bpy.data.objects['WEAPON_ELEVATION'];assert pivot.parent==root
 assert (root.matrix_world.translation-Vector((0,0,1.70))).length<1e-5
 assert (pivot.matrix_world.translation-Vector((0,0,2.34))).length<1e-5
 pts=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box];lo=min(p.z for p in pts)
 assert lo>=1.699,lo
 tubes=[o for o in meshes if o.name.startswith('GRENADE_TUBE')]
 if variant=='grenade_lobber_12':
  assert len(tubes)==12;assert {(o['row'],o['column']) for o in tubes}=={(r,c) for r in range(1,4) for c in range(1,5)}
  assert all(len(o.data.vertices)==128 and len(o.data.polygons)==128 for o in tubes)
 if variant=='energy_dish':assert 'CURVED_REFLECTOR' in col.objects and 'CENTRAL_FEED' in col.objects
 # Rotation hierarchy must move every turret mesh and leave all base objects fixed.
 before={o.name:o.matrix_world.copy() for o in meshes};base_before={o.name:o.matrix_world.copy() for o in base.objects};root.rotation_euler.z+=math.pi/2;bpy.context.view_layer.update()
 assert all(o.matrix_world!=before[o.name] for o in meshes)
 assert all(o.matrix_world==base_before[o.name] for o in base.objects)
 native_count=len(meshes)
 # Read export JSON and actually reimport into clean Blender scene.
 raw=(O/(variant+'_v01.glb')).read_bytes();size,kind=struct.unpack_from('<II',raw,12);g=json.loads(raw[20:20+size]);assert g['images'] and len(g['materials'])>=3
 assert all('TEXCOORD_0' in p['attributes'] for m in g['meshes'] for p in m['primitives'])
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(O/(variant+'_v01.glb')))
 imported=[o for o in bpy.context.scene.objects if o.type=='MESH'];assert len(imported)==native_count,(len(imported),native_count)
 if variant=='grenade_lobber_12':assert len([o for o in imported if o.name.startswith('GRENADE_TUBE')])==12
 assert not any(o.name.startswith('03_monolithic') for o in imported)
 report[variant]={'status':'PASS','native_reopened':True,'base_geometry_and_world_transforms_unchanged':True,'all_images_packed':True,'mapped_UVs':True,'traverse_moves_turret_only':True,'minimum_turret_z':lo,'mesh_count':native_count,'grenade_tubes':len(tubes),'GLB_reimported':True,'GLB_turret_only':True,'GLB_embedded_images':len(g['images'])}
(O/'reopen_validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report),flush=True)
