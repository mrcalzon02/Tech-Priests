"""Bake cavity occlusion on the supplied, unchanged skull's original UVs."""
import bpy,json
from pathlib import Path
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/conclave-center/v07-aged-and-ambient';(O/'textures').mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(O.parent/'v06-receiving-bulkheads/conclave-center-v06.blend'))
source=bpy.context.scene;ob=bpy.data.objects['Supplied DGordillo low-poly skull 0'];report={}
for mat in bpy.data.materials:
 if mat.use_nodes:report[mat.name]=[dict(name=n.name,type=n.type,image=n.image.name if n.type=='TEX_IMAGE' and n.image else None) for n in mat.node_tree.nodes]
(O/'inherited-material-nodes.json').write_text(json.dumps(report,indent=2))
scene=bpy.data.scenes.new('Isolated original skull cavity bake');bpy.context.window.scene=scene
copy=ob.copy();copy.data=ob.data.copy();scene.collection.objects.link(copy);copy.parent=None;copy.matrix_world.identity();copy.data.materials.clear()
mat=bpy.data.materials.new('Original UV cavity bake target');mat.use_nodes=True;copy.data.materials.append(mat)
image=bpy.data.images.new('DGordillo original UV actual cavity AO',1024,1024,alpha=False);image.generated_color=(1,1,1,1);node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;mat.node_tree.nodes.active=node
scene.render.engine='CYCLES';scene.cycles.samples=48
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='OPTIX'
scene.cycles.device='GPU';scene.render.bake.margin=12
bpy.context.view_layer.objects.active=copy;copy.select_set(True)
bpy.ops.object.bake(type='AO');image.filepath_raw=str(O/'textures/skull-original-uv-cavity-ao.png');image.file_format='PNG';image.save()
(O/'skull-bake.json').write_text(json.dumps(dict(vertices=len(copy.data.vertices),polygons=len(copy.data.polygons),uv=copy.data.uv_layers.active.name,resolution=1024,bake='isolated original mesh AO, no remesh or UV changes'),indent=2))
print('ORIGINAL_SKULL_AO_BAKED',flush=True)
