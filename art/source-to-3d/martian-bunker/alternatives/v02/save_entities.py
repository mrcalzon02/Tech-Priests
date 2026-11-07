import bpy,sys,json
from pathlib import Path
O=Path(sys.argv[sys.argv.index('--')+1]).resolve();report={}
for variant in ['energy_dish','grenade_lobber_12']:
 bpy.ops.wm.open_mainfile(filepath=str(O/(variant+'_v02.blend')))
 for o in list(bpy.data.collections['EXISTING_BUNKER_BASE_UNCHANGED'].objects):bpy.data.objects.remove(o,do_unlink=True)
 bpy.data.collections.remove(bpy.data.collections['EXISTING_BUNKER_BASE_UNCHANGED'])
 for i in range(3):bpy.ops.outliner.orphans_purge(do_recursive=True)
 bpy.ops.wm.save_as_mainfile(filepath=str(O/(variant+'_entity.blend')),compress=True)
 bpy.ops.wm.open_mainfile(filepath=str(O/(variant+'_entity.blend')))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];assert len(meshes)==(73 if variant=='energy_dish' else 47);assert all(i.packed_file or i.source in ['GENERATED','VIEWER'] for i in bpy.data.images)
 assert not any(o.name.startswith('03_monolithic') for o in meshes)
 report[variant]={'status':'PASS','standalone_native_mesh_count':len(meshes),'reopened':True,'all_images_packed':True,'bunker_base_excluded':True,'bytes':(O/(variant+'_entity.blend')).stat().st_size}
(O/'entity_validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
