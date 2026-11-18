"""Reopen the delivered native source without saving it; verify packed images."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
import bpy

p=argparse.ArgumentParser()
for n in ('source','glb','out'):p.add_argument('--'+n,type=Path,required=True)
p.add_argument('--source-sha256',required=True);p.add_argument('--glb-sha256',required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
for n in ('source','glb','out'):setattr(a,n,getattr(a,n).resolve())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(a.source)==a.source_sha256 and sha(a.glb)==a.glb_sha256
bpy.ops.wm.open_mainfile(filepath=str(a.source))
images={}
for material in bpy.data.materials:
    if not material.use_nodes:continue
    for node in material.node_tree.nodes:
        if node.type=='TEX_IMAGE'and node.image:
            im=node.image
            packed=bool(im.packed_file or len(im.packed_files))
            # Packed image decoding may be lazy on a headless reopen.
            assert len(im.pixels)>0,('Empty delivered texture',im.name)
            first_pixel=float(im.pixels[0])
            assert packed and im.has_data and min(im.size)>0,('Unloaded or external delivered texture',im.name)
            images[im.name]={'size':list(im.size),'loaded':bool(im.has_data),'packed':packed}
assert images
blob=a.glb.read_bytes();magic,version,total=struct.unpack_from('<III',blob)
assert magic==0x46546C67 and version==2 and total==len(blob)
length,kind=struct.unpack_from('<II',blob,12);assert kind==0x4E4F534A
doc=json.loads(blob[20:20+length].decode('utf-8'))
physical=sum('mesh'in n for n in doc['nodes']);empty=sum('mesh'not in n for n in doc['nodes'])
assert physical==3202 and empty==21
assert all('bufferView'in im and 'uri'not in im for im in doc.get('images',[]))
assert len(doc.get('animations',[]))==1 and len(doc['animations'][0]['channels'])==150
assert sha(a.source)==a.source_sha256 and sha(a.glb)==a.glb_sha256
report={'status':'PASS_REOPENED_PACKAGED_SOURCE_TEXTURES_AND_EXACT_SOURCE_EXPORT_HASHES',
        'source':{'path':str(a.source),'sha256':a.source_sha256},'glb':{'path':str(a.glb),'sha256':a.glb_sha256},
        'script_sha256':sha(Path(__file__)),'source_fps':bpy.context.scene.render.fps,
        'source_saved_scene_range':[bpy.context.scene.frame_start,bpy.context.scene.frame_end],
        'capture_contract':{'cold':0,'working':[1,64],'wrap':65,'export_range':[0,65]},
        'packed_loaded_material_images':images,'actual_glb_mesh_nodes':physical,'actual_glb_empty_nodes':empty,
        'actual_glb_animation_channels':150,'embedded_glb_images':len(doc.get('images',[])),
        'scope':'Native delivery reopened in place without saving; packed source maps loaded. GLB byte identity, physical hierarchy and embedded images verified; existing66-pose actual-export report carries by unchanged SHA256.'}
a.out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(report['status'],len(images),flush=True)
