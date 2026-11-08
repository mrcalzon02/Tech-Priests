import bpy,json
from pathlib import Path
from mathutils import Vector
D=Path(__file__).resolve().parent/'condenser_v21'
bpy.ops.wm.open_mainfile(filepath=str(D/'tech_priests_water_condenser_v21.blend'))
asset=[o for o in bpy.context.scene.objects if o.type=='MESH' and (o.parent and o.parent.name=='CONDENSER_TILE_CALIBRATION' or o.name.startswith('Water outlet'))]
def bounds(obs):
 pts=[o.matrix_world@Vector(v) for o in obs for v in o.bound_box]
 return [[min(v[i] for v in pts),max(v[i] for v in pts)] for i in range(3)]
before=bounds(asset);count=len(asset)
body=bpy.data.objects['Condenser right continuous side cheek']
transition_faces=[p for p in body.data.polygons if body.data.materials[p.material_index].name.startswith('Condenser outlet body-to-pipe')]
assert len(transition_faces)>20,'Neck material did not survive union'
assert 'OutletTransitionUV' in body.data.uv_layers,'Neck UVs missing'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(D/'tech_priests_water_condenser_v21.glb'))
obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];after=bounds(obs)
error=max(abs(a-b) for x,y in zip(before,after) for a,b in zip(x,y))
materials=[m for m in bpy.data.materials if m.name.startswith('Condenser outlet body-to-pipe')]
texture_images=[n.image.name for m in materials for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
assert len(texture_images)>=2,'Exported colour/roughness textures missing'
check={'native_asset_meshes':count,'glb_meshes':len(obs),'bounds_error_tiles':error,'native_transition_faces':len(transition_faces),'exported_transition_texture_images':texture_images,'reference_meshes_exported':any(o.name.startswith(('Reference','Grid')) for o in obs),'pass':len(obs)==count and error<.01}
assert check['pass'],check
p=D/'Condenser_V21_Validation.json';j=json.loads(p.read_text());j['glb_readback']=check;j['native_and_glb_validation']='Native reopened; GLB mesh count and bounds matched';p.write_text(json.dumps(j,indent=2));print(check)
