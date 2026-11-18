"""Replace rejected procedural castings with the owner's actual low-poly skull."""
import bpy,json,hashlib,sys,shutil
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[3];OLD=R/'art/source-to-3d/conclave-center/v01';O=OLD.parent/'v02-supplied-skull';O.mkdir(exist_ok=True)
DONOR=R/'art/source-to-3d/cogitator-stations/shared-skull/DGordillo-original'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(OLD/'conclave-center-v01.blend'));s=bpy.context.scene;root=bpy.data.objects['Conclave Center | ground origin']
for o in list(s.objects):
 if o.name.startswith('Retained anatomical skull casting'):bpy.data.objects.remove(o,do_unlink=True)
donor_copy=O/'supplied-skull';donor_copy.mkdir(exist_ok=True)
for name in ['craneo.v2.packed.blend','dgordillo-sculpt-normal.png','provenance.json','ATTRIBUTION.txt']:shutil.copy2(DONOR/name,donor_copy/name)
records=[]
for index,(x,z,height) in enumerate([(0,1.66,.36),(-.48,1.48,.235),(.48,1.48,.235)]):
 with bpy.data.libraries.load(str(donor_copy/'craneo.v2.packed.blend'),link=False) as (available,loaded):
  assert 'Craneo' in available.objects;loaded.objects=['Craneo']
 head=loaded.objects[0];s.collection.objects.link(head);head.parent=None;head.location=(0,0,0);head.rotation_euler=(0,0,0);head.scale=(1,1,1)
 # Retain low-poly topology. Subdivision remains disabled, no remesh or reshape.
 for mod in list(head.modifiers):head.modifiers.remove(mod)
 lo=[min(v.co[k] for v in head.data.vertices) for k in range(3)];hi=[max(v.co[k] for v in head.data.vertices) for k in range(3)];scale=height/(hi[2]-lo[2])
 for v in head.data.vertices:v.co=(v.co-Vector([(lo[k]+hi[k])/2 for k in range(3)]))*scale
 depth=(hi[1]-lo[1])*scale
 # Rearmost surface embeds .012 into actual shell front plane y=.41.
 head.location=(x,.422-depth/2,z);head.parent=root;head.name='Supplied DGordillo low-poly skull '+str(index)
 if head.data.uv_layers:head.data.uv_layers.active.name='SkullUV'
 else:raise RuntimeError('Supplied skull lost original UVs')
 mat=bpy.data.materials['Conclave | skull-cast'].copy();mat.name='Conclave | supplied DGordillo ivory '+str(index)
 nodes=mat.node_tree.nodes;links=mat.node_tree.links;bs=nodes.get('Principled BSDF')
 # Original sculpt normal detail follows its original UV, preserving the donor face.
 uv=nodes.new('ShaderNodeUVMap');uv.uv_map='SkullUV'
 tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(donor_copy/'dgordillo-sculpt-normal.png'),check_existing=True);tex.image.colorspace_settings.name='Non-Color';tex.image.pack();links.new(uv.outputs[0],tex.inputs['Vector'])
 normal=nodes.new('ShaderNodeNormalMap');normal.uv_map='SkullUV';normal.inputs['Strength'].default_value=.7;links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs[0],bs.inputs['Normal'])
 # Ivory casting color with original shape/normal; remove donor metal scratch
 # normal and avoid panel-perimeter stains over anatomical UV islands.
 for link in list(links):
  if link.to_socket==bs.inputs['Base Color']:links.remove(link)
 bs.inputs['Base Color'].default_value=(.47,.40,.27,1);bs.inputs['Metallic'].default_value=0;bs.inputs['Roughness'].default_value=.59
 head.data.materials.clear();head.data.materials.append(mat)
 head['source_mesh']='Craneo';head['owner_supplied_low_poly']=True;head['source_sha256']=sha(donor_copy/'craneo.v2.packed.blend');head['attribution']='Low Poly Skull / Craneo by DGordillo, CC BY 3.0. Uniformly resized, original UV/sculpt normal preserved, recolored and mounted. No remesh or anatomical replacement.'
 head.data.calc_loop_triangles();records.append(dict(name=head.name,source_mesh='Craneo',vertices=len(head.data.vertices),triangles=len(head.data.loop_triangles),uniform_scale=scale,location=list(head.location),original_uv_preserved=True,original_normal_preserved=True,no_subdivision_or_remesh=True))
for name in ['surface-manifest.json','contract.json','capture-profile.json','pipette-requests.json','pipette-plans.json','support-objects.json','original-prototype.lua']:
 shutil.copy2(OLD/name,O/name)
contacts=json.loads((OLD/'contacts.json').read_text())
for row in contacts:
 if row['a'].startswith('Retained anatomical skull casting'):row['a']='Supplied DGordillo low-poly skull '+row['a'].rsplit(' ',1)[1];row['why']='actual supplied low-poly mesh rear mounted into structural backplate'
(O/'contacts.json').write_text(json.dumps(contacts,indent=2)+'\n');(O/'supplied-skull-reuse.json').write_text(json.dumps(dict(source=str(donor_copy/'craneo.v2.packed.blend'),sha256=sha(donor_copy/'craneo.v2.packed.blend'),owner_archive='C:/Users/Admin/Downloads/Low Poly Skull.zip',owner_archive_sha256=sha(Path('C:/Users/Admin/Downloads/Low Poly Skull.zip')),instances=records),indent=2)+'\n')
credit='Low Poly Skull (Craneo) by DGordillo\nhttps://blendswap.com/blend/2499\nCC BY 3.0: https://creativecommons.org/licenses/by/3.0/\nConclave adaptation: uniformly resized, original UV and sculpt normal retained, ivory casting material, mounted on rear shrine. No endorsement implied.\n'
(O/'ATTRIBUTION.txt').write_text(credit)
sys.path.insert(0,str(R/'tools/fmpl'));from blender_camera_guard import assert_clean;assert_clean(s,json.loads((O/'capture-profile.json').read_text()),bpy)
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(O/'conclave-center-v02.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for o in s.objects:
 if o.type=='MESH':o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'conclave-center-v02.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='OPTIX'
if any(d.use for d in prefs.devices):s.cycles.device='GPU'
s.render.filepath=str(O/'source-front.png');bpy.ops.render.render(write_still=True)
print('ACTUAL_SUPPLIED_SKULLS_REUSED',json.dumps(records),flush=True)
