"""Clean-scene append and actual geometry thumbnail for one harvested part."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--part',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);root=Path(args.part).resolve()
    record=json.loads((root/'part.json').read_text());source=root/'part.blend'
    if sha(source)!=record['source_sha256']:raise RuntimeError('Part source changed')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    with bpy.data.libraries.load(str(source),link=False) as (fr,to):
        if record['collection'] not in fr.collections:raise RuntimeError('Missing registered collection')
        to.collections=[record['collection']]
    collection=to.collections[0];bpy.context.scene.collection.children.link(collection)
    meshes=[o for o in collection.all_objects if o.type=='MESH']
    if len(meshes)!=record['mesh_count']:raise RuntimeError('Appended part census mismatch')
    bpy.context.scene.frame_set(25);bpy.context.view_layer.update()
    points=[o.matrix_world @ Vector(v) for o in meshes for v in o.bound_box]
    bounds=[[min(p[i] for p in points) for i in range(3)],[max(p[i] for p in points) for i in range(3)]]
    finite=all(math.isfinite(c) for p in points for c in p)
    images=[i for i in bpy.data.images if i.source=='FILE']
    loaded=all(i.packed_file and min(i.size)>0 for i in images)
    bore=None
    if record['family']=='fluid-mouth':
        hits=[];rays=0
        for y in (-.18,-.12,-.06,0,.06,.12,.18):
            for z in (-.18,-.12,-.06,0,.06,.12,.18):
                if y*y+z*z>.205**2:continue
                rays+=1
                for ob in meshes:
                    inv=ob.matrix_world.inverted_safe()
                    hit=ob.ray_cast(inv @ Vector((.02,y,z)),(inv.to_3x3() @ Vector((-1,0,0))).normalized(),distance=.32)
                    if hit[0]:hits.append(dict(object=ob.name,y=y,z=z))
        bore=dict(rays=rays,hits=hits,passed=not hits)
    s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=24
    camdata=bpy.data.cameras.new('Part inspection');camdata.type='ORTHO';camdata.ortho_scale=1.4
    cam=bpy.data.objects.new('Part inspection',camdata);s.collection.objects.link(cam);s.camera=cam
    cam.location=(1.1,-2.5,1.3);cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler()
    for name,loc,power,size in (('Key',(-2,-3,4),350,3),('Fill',(3,1,2),200,2)):
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
        light=bpy.data.objects.new(name,data);s.collection.objects.link(light);light.location=loc
        light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
    s.world=bpy.data.worlds.new('Part neutral world');s.world.use_nodes=True
    s.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.12,.12,.12,1)
    s.render.resolution_x=384;s.render.resolution_y=384;s.render.resolution_percentage=100
    s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
    s.render.filepath=str(root/'thumbnail.png');bpy.ops.render.render(write_still=True)
    report=dict(passed=finite and loaded and (bore is None or bore['passed']),source_sha256=sha(source),
        thumbnail_sha256=sha(root/'thumbnail.png'),mesh_count=len(meshes),bounds=bounds,
        dimensions=[bounds[1][i]-bounds[0][i] for i in range(3)],packed_images=len(images),loaded_packed_images=loaded,
        bore=bore,native_socket_connectivity='not claimed by reusable geometry validation')
    (root/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print('PART_CLEAN_APPEND',record['part_id'],report['passed'],flush=True)
    if not report['passed']:raise RuntimeError('Part append QA failed')

if __name__=='__main__':main()
