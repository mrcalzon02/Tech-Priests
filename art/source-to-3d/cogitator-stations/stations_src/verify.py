"""Reopen the native scene and reimport the delivered GLB to audit model geometry.

blender -b -t 2 --python-exit-code 1 -P verify.py -- --assets output --reports checks
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Vector
import numpy as np


EDITIONS = ('junior','intermediate','senior','planetary-magos','void')


def fingerprint(path):
    with path.open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()


def inspect_glb(path):
    with path.open('rb') as handle:
        header=handle.read(20)
        magic,version,length,chunk_size,chunk_type=struct.unpack('<4s4I',header)
        if magic!=b'glTF' or version!=2 or chunk_type!=0x4E4F534A or length!=path.stat().st_size:
            raise ValueError('Unfinished or invalid GLB header')
        gltf=json.loads(handle.read(chunk_size))
    images=gltf.get('images',[])
    return {
        'node_count':len(gltf['nodes']),
        'material_count':len(gltf.get('materials',[])),
        'image_count':len(images),
        'embedded_image_count':sum('bufferView' in item and 'uri' not in item for item in images),
        'external_buffers':[item['uri'] for item in gltf['buffers'] if 'uri' in item],
        'camera_count':len(gltf.get('cameras',[])),
        'light_count':len(gltf.get('extensions',{}).get('KHR_lights_punctual',{}).get('lights',[])),
    }


def read_meshes():
    graph=bpy.context.evaluated_depsgraph_get()
    boxes={}
    centres={}
    empty=[]
    bad_uv=[]
    vertices=faces=0
    for item in bpy.context.scene.objects:
        if item.type!='MESH':
            continue
        obj=item.evaluated_get(graph)
        me=obj.data
        vertices+=len(me.vertices)
        faces+=len(me.polygons)
        if not len(me.vertices) or not len(me.polygons):
            empty.append(item.name)
            continue
        coords=np.empty(len(me.vertices)*3,np.float32)
        me.vertices.foreach_get('co',coords)
        transform=np.asarray(obj.matrix_world,dtype=float)
        world=coords.reshape(-1,3)@transform[:3,:3].T+transform[:3,3]
        boxes[item.name]=np.array([world.min(axis=0),world.max(axis=0)])
        centres[item.name]=world.mean(axis=0)
        uv=me.uv_layers.active
        if uv is None:
            bad_uv.append(item.name)
        else:
            uv_coords=np.empty(len(me.loops)*2,np.float32)
            uv.uv.foreach_get('vector',uv_coords)
            if not np.isfinite(uv_coords).all():
                bad_uv.append(item.name)
    scene=bpy.context.scene
    lines=[o for o in scene.objects if o.type=='MESH' and 'fmpl_pipette_architecture' in o]
    wires=[o for o in scene.objects if o.type=='MESH' and 'pipette_architecture_id' in o]
    tubes={}
    for o in lines:
        props=('fmpl_pipette_socket_start_bu','fmpl_pipette_socket_end_bu','fmpl_pipette_terminal_joint',
               'fmpl_pipette_open_bore_diameter_bu')
        tubes[o.name]={'architecture':o['fmpl_pipette_architecture'],
                       'typed_endpoints':all(k in o for k in props)}
        if tubes[o.name]['typed_endpoints']:
            tubes[o.name].update({'start':list(o[props[0]]),'end':list(o[props[1]]),
                                  'joint':o[props[2]],'bore':o[props[3]]})
    chain=[o for o in scene.objects if o.type=='MESH' and 'forged link ' in o.name]
    bounds=np.array([np.min([b[0] for b in boxes.values()],axis=0),
                     np.max([b[1] for b in boxes.values()],axis=0)])
    images=[im for im in bpy.data.images if im.type=='IMAGE' and im.source=='FILE' and im.users]
    packed=len([im for im in images if im.packed_file])
    return {'mesh_objects':len(boxes),'evaluated_vertices':vertices,'evaluated_faces':faces,
            'bounds':bounds.tolist(),'chain_link_count':len(chain),'chain_mesh_datablocks':len({o.data.name for o in chain}),
            'chain_links_with_dimensions':sum(o.get('stock_radius',0.)>0 and o.get('link_inner_width',0.)>0 for o in chain),
            'hydraulic_routes':tubes,'electrical_routes':len(wires),
            'used_file_images':len(images),'packed_images':packed,
            'unpacked_images':[im.name for im in images if not im.packed_file],
            'empty_meshes':empty,'missing_or_nonfinite_uvs':bad_uv,
            'camera_count':sum(o.type=='CAMERA' for o in scene.objects),
            'light_count':sum(o.type=='LIGHT' for o in scene.objects)},boxes,centres


def inspect_badges(boxes,centres):
    pairs=[(name,name.replace(' · cast skull',' · cut wheel')) for name in boxes if name.endswith(' · cast skull')]
    if "void crown | death's head" in boxes:
        pairs.append(("void crown | death's head","void crown | seal back"))
    offsets=[]
    for skull,seat in pairs:
        a,b=boxes[skull],boxes[seat]
        offset=a.mean(axis=0)-b.mean(axis=0)
        span=(b[1]-b[0])
        offsets.append({'skull':skull,'seat':seat,'bounds_center_xz_offset':offset[[0,2]].tolist(),
                        'vertex_centroid_xz_offset':(centres[skull]-centres[seat])[[0,2]].tolist(),
                        'seat_xz_diameter':span[[0,2]].tolist(),
                        'relative_center_offset':float(np.max(abs(offset[[0,2]])/span[[0,2]])),
                        'skull_forward_of_seat':bool(a[0][1]<b[0][1])})
    return offsets


def audit(folder,edition):
    native=folder/(edition+'.blend')
    binary=folder/(edition+'.glb')
    result={'edition':edition,'native_sha256':fingerprint(native),'glb_sha256':fingerprint(binary)}
    gltf=inspect_glb(binary)
    result['glb_structure']=gltf
    bpy.ops.wm.open_mainfile(filepath=str(native))
    scene=bpy.context.scene
    cam=scene.camera
    direction=cam.matrix_world.to_quaternion()@Vector((0,0,-1))
    elevation=math.degrees(math.asin(-direction.z))
    result['native_camera']={'name':cam.name,'projection':cam.data.type,'elevation_degrees':elevation,
                             'role':cam.get('fmpl_camera_role'),'policy':cam.get('fmpl_camera_policy'),
                             'orthographic_scale':cam.data.ortho_scale}
    orig,boxes,centres=read_meshes()
    result['native']=orig
    badges=inspect_badges(boxes,centres)
    result['badge_alignment']=badges

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(binary))
    replay,export_boxes,_=read_meshes()
    result['roundtrip']=replay
    names=set(boxes)
    shared=names.intersection(export_boxes)
    distance={name:float(np.abs(boxes[name]-export_boxes[name]).max()) for name in shared}
    result['missing_object_names']=sorted(names-set(export_boxes))
    result['additional_object_names']=sorted(set(export_boxes)-names)
    result['max_scene_bound_error_bu']=float(np.abs(np.array(orig['bounds'])-replay['bounds']).max())
    result['max_object_bound_error_bu']=max(distance.values())
    result['largest_object_deltas']=dict(sorted(distance.items(),key=lambda pair:-pair[1])[:4])

    expected_tubes=6 if edition=='junior' else 7
    checks={
        'scene_geometry_bounds':result['max_scene_bound_error_bu']<.0001,
        'per_mesh_geometry_bounds':result['max_object_bound_error_bu']<.0001,
        'mesh_node_names':not result['missing_object_names'] and not result['additional_object_names'],
        'all_meshes_nonempty':not orig['empty_meshes'] and not replay['empty_meshes'],
        'all_meshes_have_finite_uvs':not orig['missing_or_nonfinite_uvs'] and not replay['missing_or_nonfinite_uvs'],
        'native_camera':orig['camera_count']==1 and cam_valid(result['native_camera']),
        'meshes_only_glb':not any([gltf['camera_count'],gltf['light_count'],replay['camera_count'],replay['light_count']]),
        'standalone_native_materials':orig['used_file_images']>0 and not orig['unpacked_images'],
        'standalone_glb_materials':gltf['image_count']>0 and gltf['image_count']==gltf['embedded_image_count'] and not gltf['external_buffers'],
        'independent_chain_links':all(stage['chain_link_count']==stage['chain_mesh_datablocks']==stage['chain_links_with_dimensions']==22 for stage in (orig,replay)),
        'fluid_lines_and_fittings':len(orig['hydraulic_routes'])==expected_tubes and orig['hydraulic_routes']==replay['hydraulic_routes'] and all(t['typed_endpoints'] and t.get('bore',0)>0 for t in orig['hydraulic_routes'].values()),
        'wire_linework':orig['electrical_routes']==replay['electrical_routes'] and orig['electrical_routes']>0,
        'cast_skull_alignment':bool(badges) and all(b['relative_center_offset']<.06 and b['skull_forward_of_seat'] for b in badges)}
    result['checks']=checks
    return result


def cam_valid(info):
    return info['projection']=='ORTHO' and info['role']=='production' and abs(info['elevation_degrees']-45)<.01


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--assets',type=Path,required=True)
    parser.add_argument('--reports',type=Path,required=True)
    parser.add_argument('--editions',nargs='+',choices=EDITIONS,default=EDITIONS)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    args.reports.mkdir(parents=True,exist_ok=True)
    failed=[]
    for edition in args.editions:
        result=audit(args.assets.resolve(),edition)
        checks=result['checks']
        (args.reports/('readback-'+edition+'.json')).write_text(json.dumps(result,indent=2)+'\n')
        print('READBACK',edition,json.dumps(checks),flush=True)
        failed.extend(edition+': '+name for name,ok in checks.items() if not ok)
    if failed:
        raise RuntimeError('Review failures: '+', '.join(failed))


if __name__=='__main__':
    main()
