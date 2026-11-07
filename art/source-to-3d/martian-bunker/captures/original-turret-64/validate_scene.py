import bpy,json,math,sys
from pathlib import Path
from mathutils import Vector,Matrix
S=bpy.context.scene;P=bpy.data.objects['TURRET_TRAVERSE_PIVOT_Z_1_70']
bpy.context.window.view_layer=S.view_layers['TURRET_ONLY']
assert not list(bpy.data.collections['BASE_STATIC'].all_objects)
assert all(im.packed_file or im.source in ['GENERATED','VIEWER'] for im in bpy.data.images)
assert not any(o.name.startswith(('SYMBOL_BRASS_ROOF_MARS','SYMBOL_BRASS_SERVICE_PLATE_MARS')) for o in S.objects)
rock=bpy.data.objects['TURRET_SHOT_ROCK']
for name in ['19_machined_barrel_socket','72_recoil_piston_service_collar_W','72_recoil_piston_service_collar_E','71_recoil_piston_base_bracket_W','71_recoil_piston_base_bracket_E','25_recoil_guard_W','25_recoil_guard_E']:
 assert bpy.data.objects[name].parent==rock,name
assert bpy.data.objects['CANNON_RECOIL_LOCAL_Y'].parent==rock
assert bpy.data.objects['INNER_BARREL_RECOIL_LOCAL_Y'].parent==bpy.data.objects['CANNON_RECOIL_LOCAL_Y']
S.frame_set(1);bpy.context.view_layer.update()
rest={o.name:o.matrix_world.copy() for o in S.objects if o.type in ['MESH','CURVE'] and not o.name.startswith('SHOT_')}
S.frame_set(32);bpy.context.view_layer.update()
assert all(max(abs(bpy.data.objects[n].matrix_world[i][j]-m[i][j]) for i in range(4) for j in range(4))<1e-5 for n,m in rest.items())
S.frame_set(5);bpy.context.view_layer.update()
assert abs(bpy.data.objects['CANNON_RECOIL_LOCAL_Y'].location.y-.13)<1e-6
assert abs(bpy.data.objects['INNER_BARREL_RECOIL_LOCAL_Y'].location.y-.13)<1e-6
S.frame_set(14);P.rotation_euler.z=math.pi/2;bpy.context.view_layer.update()
reference={o.name:o.matrix_world.copy() for o in S.objects if o.name.startswith('SHOT_SMOKE_')}
for d in range(64):
 yaw=math.radians(180-d*5.625);P.rotation_euler.z=yaw;bpy.context.view_layer.update()
 R=Matrix.Rotation(yaw-math.pi/2,4,'Z')
 for n,m in reference.items():
  expected=R@m
  assert max(abs(bpy.data.objects[n].matrix_world[i][j]-expected[i][j]) for i in range(4) for j in range(4))<1e-5,(d,n)
S.frame_set(1);P.rotation_euler.z=math.pi
report={'status':'PASS','directions':64,'source_reopened':True,'barrel_recoil':.13,'inner_recoil':.13,'mount_rings_fixed_to_housing':True,'first_last_turret_poses_match':True,'smoke_follows_all_64_headings':True,'base_absent':True,'textures_packed':True}
out=Path(sys.argv[sys.argv.index('--')+1]) if '--' in sys.argv else Path('scene_validation.json')
out.write_text(json.dumps(report,indent=2));print(json.dumps(report))
