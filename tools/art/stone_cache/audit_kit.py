"""Append the saved wall library independently and compare against the master."""
import bpy,json,hashlib
from pathlib import Path
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/martian-stone-cache/v01';name='CACHE KIT | Stone enclosure'
def snapshot(collection):
 bpy.context.view_layer.update()
 return {ob.name:dict(vertices=[tuple(ob.matrix_world@v.co) for v in ob.data.vertices],faces=[tuple(p.vertices) for p in ob.data.polygons]) for ob in collection.all_objects if ob.type=='MESH'}
bpy.ops.wm.open_mainfile(filepath=str(O/'martian-stone-cache-v01.blend'));expected=snapshot(bpy.data.collections[name])
bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(str(O/'martian-stone-enclosure-kit.blend'),link=False) as (src,dest):dest.collections=[name]
bpy.context.scene.collection.children.link(dest.collections[0]);actual=snapshot(dest.collections[0]);assert actual==expected
images=[]
for im in bpy.data.images:
 if im.users and im.type=='IMAGE':
  assert im.packed_file;_=im.pixels[0];images.append(im.name)
result=dict(passed=True,meshes=len(actual),geometry_matches_master=True,packed_images=images,kit_sha256=hashlib.sha256((O/'martian-stone-enclosure-kit.blend').read_bytes()).hexdigest(),source_sha256=hashlib.sha256((O/'martian-stone-cache-v01.blend').read_bytes()).hexdigest(),scope='Reusable wall library only; cover/emblem remain separate in master; owner material acceptance pending')
(O/'kit-inspection.json').write_text(json.dumps(result,indent=2)+'\n');print('CACHE_KIT_INDEPENDENT_APPEND_PASS',len(actual))
