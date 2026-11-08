import bpy,json
from pathlib import Path
R=Path(__file__).resolve().parent;D=R/'boiler_v08'
bpy.ops.wm.open_mainfile(filepath=str(D/'tech_priests_emergency_boiler_v08_animated.blend'))
s=bpy.context.scene;s.render.engine='CYCLES';s.camera=bpy.data.objects['BOILER_FACTORIO_EXPORT_45']
views=[]
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type!='VIEW_3D':continue
  space=area.spaces.active;space.shading.use_scene_world=True;space.shading.use_scene_lights=True
  if hasattr(space.shading,'use_scene_world_render'):space.shading.use_scene_world_render=True
  if hasattr(space.shading,'use_scene_lights_render'):space.shading.use_scene_lights_render=True
  if screen.name in ['Layout','Animation','Shading']:
   space.shading.type='RENDERED';space.region_3d.view_perspective='CAMERA'
  views.append({'workspace':screen.name,'shading':space.shading.type,'scene_lights':space.shading.use_scene_lights,'scene_world':space.shading.use_scene_world})
if bpy.context.window and bpy.data.workspaces.get('Layout'):bpy.context.window.workspace=bpy.data.workspaces['Layout']
s.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(D/'tech_priests_emergency_boiler_v08_animated.blend'),compress=True)
(R/'boiler_tubing_audit/Viewport_Correction.json').write_text(json.dumps({'render_engine':s.render.engine,'views':views,'tube_visibility_or_material_alpha_changed':False,'mesh_geometry_changed':False},indent=2));print('VIEWPORT_CORRECTED',views)
