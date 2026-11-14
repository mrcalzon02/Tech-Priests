"""Fresh-process V14 source/GLB contact and texture inspection, honest gates."""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from refine_purifier_v14 import tree, bounds, sha, PREFIX
from refine_process import hash_original_meshes
from pipe_bore_clearance import verify_bores
from camera_profile import audit_scene

def gap(a,b):
    ta,tb=tree(a),tree(b)
    if ta.overlap(tb): return 0.
    values=[]
    for src,dst in ((a,tb),(b,ta)):
        for v in src.data.vertices:
            hit=dst.find_nearest(src.matrix_world @ v.co)
            if hit[0] is not None: values.append(hit[3])
    return min(values) if values else None

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--dir',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]); out=Path(args.dir).resolve()
    source=out/'water-purifier-v14.blend'
    construction=json.loads((out/'construction-receipt.json').read_text())
    bpy.ops.wm.open_mainfile(filepath=str(source)); s=bpy.context.scene; s.frame_set(25)
    originals=[o for o in s.objects if o.type=='MESH' and o.name.startswith(('MH7_','FMPL_PROCESS |'))]
    errors=[]
    if hash_original_meshes(originals)!=construction['source_mesh_digest']: errors.append('source mesh digest')
    camera=audit_scene(s,bpy)
    bores=verify_bores(s)
    if not bores['passed']: errors.append('native model bore')
    images=[dict(name=i.name,packed=bool(i.packed_file),size=list(i.size)) for i in bpy.data.images if i.type=='IMAGE']
    if any(not x['packed'] or min(x['size'])==0 for x in images): errors.append('unpacked/missing source image')
    contact=[]
    for side in (-1,1):
        names=[
            ('FMPL_PROCESS | agitator motor gearbox housing','FMPL_PROCESS | agitator gearbox bearing ring'),
            ('FMPL_PROCESS | agitator gearbox bearing ring',PREFIX+'drive I beam flange 3.161'),
            (PREFIX+'drive I beam flange 3.055','FMPL_PROCESS | gearbox crossbeam pedestal '+str(side*.84)),
            ('FMPL_PROCESS | gearbox crossbeam pedestal '+str(side*.84),PREFIX+'drive metal landing shoe '+str(side)),
            (PREFIX+'drive metal landing shoe '+str(side),PREFIX+'drive gusset '+str((side,.025))),
            (PREFIX+'drive gusset '+str((side,.025)),'FMPL_PROCESS | open double-wall steel treatment vessel'),
        ]
        for a,b in names:
            distance=gap(bpy.data.objects[a],bpy.data.objects[b])
            contact.append(dict(a=a,b=b,distance_tiles=distance,pass_contact=distance is not None and distance<=.015))
    if any(not x['pass_contact'] for x in contact): errors.append('upper drive contact graph')
    joint_checks=[]
    for row in json.loads((out/'fitted-joints.json').read_text()):
        route=row['line_name'].removeprefix('FMPL_PROCESS | ').removesuffix(' / section 1')
        prefix=PREFIX+'process union '+route+' '+str(row['end'])
        parts=[o for o in s.objects if o.type=='MESH' and o.name.startswith(prefix)]
        receiver=bpy.data.objects[row['receiving_object']]
        d=min(gap(o,receiver) for o in parts)
        joint_checks.append(dict(line=row['line_name'],end=row['end'],receiver=receiver.name,
                                 contact_distance=d,passed=d<=.015))
    if any(not x['passed'] for x in joint_checks): errors.append('main process union contact')
    rotor=bpy.data.objects['FMPL_PROCESS | keyframed central agitator rotor']
    motion=[]
    bars=[o for o in s.objects if o.name.startswith(PREFIX+'console live green bar')]
    for frame in (1,25,97):
        s.frame_set(frame)
        motion.append(dict(frame=frame,agitator_z=rotor.rotation_euler.z,green_bar_scale=[o.scale.z for o in bars]))
    if abs(motion[-1]['agitator_z']-motion[0]['agitator_z']-math.pi/2)>.001: errors.append('slow quarter-turn animation')
    if motion[0]['green_bar_scale']==motion[1]['green_bar_scale']: errors.append('green bar animation')
    s.frame_set(25)
    meshes=[o for o in s.objects if o.type=='MESH' and not o.hide_render]
    original_bounds=bounds(meshes)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in s.objects:
        if (ob.type=='MESH' and not ob.hide_render) or ob.type=='EMPTY': ob.select_set(True)
    glb=out/'water-purifier-v14.glb'
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,
        export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,
        export_materials='EXPORT',export_image_format='AUTO',export_texcoords=True,
        export_normals=True,export_apply=False)
    # Independent runtime import in the same clean process, with no mesh data
    # retained from the source. Camera/lamps are copied for actual-export views.
    camera_matrix=[list(r) for r in s.camera.matrix_world]
    camera_scale=s.camera.data.ortho_scale
    lamps=[dict(name=o.name,type=o.data.type,energy=o.data.energy,color=list(o.data.color),
                size=getattr(o.data,'size',1.),matrix=[list(r) for r in o.matrix_world])
           for o in s.objects if o.type=='LIGHT']
    background=s.world.node_tree.nodes.get('Background') if s.world and s.world.use_nodes else None
    world_color=list(background.inputs['Color'].default_value) if background else [.1,.1,.1,1]
    world_strength=background.inputs['Strength'].default_value if background else 1.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb)); s=bpy.context.scene
    imported=[o for o in s.objects if o.type=='MESH']
    imported_bounds=bounds(imported)
    max_bounds_error=max(abs(original_bounds[i][j]-imported_bounds[i][j]) for i in range(2) for j in range(3))
    if max_bounds_error>.002: errors.append('runtime bounds mismatch')
    runtime_bores=verify_bores(s)
    if not runtime_bores['passed']: errors.append('runtime bore')
    triangles=0; nonfinite=0; degenerate=0; uv_missing=[]
    for ob in imported:
        me=ob.data; me.calc_loop_triangles(); triangles+=len(me.loop_triangles)
        nonfinite+=sum(not all(math.isfinite(float(c)) for c in v.co) for v in me.vertices)
        degenerate+=sum(t.area<1e-12 for t in me.loop_triangles)
        if not me.uv_layers: uv_missing.append(ob.name)
    if nonfinite: errors.append('nonfinite runtime vertices')
    if uv_missing: errors.append('missing runtime UV')
    # Inspect actual GLB JSON for texture channels; procedural source nodes do
    # not count as exported images or normal maps.
    raw=glb.read_bytes(); n=int.from_bytes(raw[12:16],'little'); doc=json.loads(raw[20:20+n])
    channels=[]
    for mat in doc.get('materials',[]):
        pbr=mat.get('pbrMetallicRoughness',{})
        channels.append(dict(name=mat.get('name'),base_color='baseColorTexture' in pbr,
            metallic_roughness='metallicRoughnessTexture' in pbr,normal='normalTexture' in mat))
    report=dict(status='PASS_TARGETED_GEOMETRY' if not errors else 'FAIL',errors=errors,
        source_sha256=sha(source),glb_sha256=sha(glb),source_images=images,
        source_geometry_preserved='source mesh digest' not in errors,camera=camera,
        native_bores=bores,runtime_bores=runtime_bores,upper_drive_contact_graph=contact,
        fitted_process_joint_contacts=joint_checks,motion=motion,native_bounds=original_bounds,
        runtime_bounds=imported_bounds,max_bounds_error=max_bounds_error,
        runtime_meshes=len(imported),triangles=triangles,nonfinite_vertices=nonfinite,
        degenerate_triangles=degenerate,missing_UV=uv_missing,GLB_PBR_channels=channels,
        animation_clips=[a.get('name') for a in doc.get('animations',[])],
        pending=['remaining service lines and original sight routes','complete source/export visual assessment',
                 'effect isolation','production atlases','native prototype/pipe placement','owner review'])
    (out/'independent-readback.json').write_text(json.dumps(report,indent=2)+'\n')
    print('V14_READBACK',report['status'],errors,flush=True)
    # Real reimported-export inspection under the preserved production camera.
    from mathutils import Matrix
    cam=bpy.data.cameras.new('Preserved production camera'); cam.type='ORTHO'; cam.ortho_scale=camera_scale
    oldcamera=bpy.data.objects.new('Preserved production camera',cam)
    oldcamera.matrix_world=Matrix(camera_matrix)
    s.collection.objects.link(oldcamera); s.camera=oldcamera
    for record in lamps:
        data=bpy.data.lights.new(record['name'],record['type']); data.energy=record['energy']; data.color=record['color']
        if hasattr(data,'size'): data.size=record['size']
        ob=bpy.data.objects.new(record['name'],data); ob.matrix_world=Matrix(record['matrix']); s.collection.objects.link(ob)
    s.world=bpy.data.worlds.new('Preserved source background'); s.world.use_nodes=True
    bg=s.world.node_tree.nodes.get('Background'); bg.inputs['Color'].default_value=world_color
    bg.inputs['Strength'].default_value=world_strength
    s.frame_set(25)
    s.render.engine='CYCLES'; s.cycles.device='CPU'; s.cycles.samples=24
    s.render.resolution_x=512; s.render.resolution_y=512; s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'
    s.render.film_transparent=True; s.render.filepath=str(out/'runtime-front.png')
    bpy.ops.render.render(write_still=True)
    clay=bpy.data.materials.new('Neutral geometry inspection'); clay.use_nodes=True
    bs=clay.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(.3,.3,.3,1)
    bs.inputs['Roughness'].default_value=.7
    s.view_layers[0].material_override=clay; s.render.filepath=str(out/'runtime-clay.png')
    bpy.ops.render.render(write_still=True)
    if errors: raise RuntimeError('Independent geometry gates failed: '+str(errors))

if __name__=='__main__': main()
