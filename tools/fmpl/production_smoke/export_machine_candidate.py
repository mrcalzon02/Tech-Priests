"""Export and reimport a real 0/1..97 MH7 machine state candidate."""
import argparse
import json
from pathlib import Path
import sys
import bpy

sys.path.insert(0,str(Path(__file__).resolve().parent))
from refine_purifier_v14 import bounds,sha
from audit_electrolyzer_v01 import mesh_stats,port_probe
from electrolyzer_state_clips import prepare_state_tracks,activate_imported_clip


def poses(scene,frames,imported=False):
    result={}
    for frame in frames:
        if imported:activate_imported_clip(scene,'idle' if frame==0 else 'working')
        scene.frame_set(max(0,frame-1) if imported else frame);bpy.context.view_layer.update()
        result[frame]={o.name:[float(c) for row in o.matrix_world for c in row] for o in scene.objects if o.type in ('MESH','EMPTY') and not o.hide_render}
    return result


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--native',required=True);ap.add_argument('--glb',required=True);ap.add_argument('--report',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);native=Path(args.native).resolve();glb=Path(args.glb).resolve();report=Path(args.report).resolve()
    if glb.exists() or report.exists():raise FileExistsError('Retain export/readback evidence')
    bpy.ops.wm.open_mainfile(filepath=str(native));s=bpy.context.scene;s.frame_set(25);bpy.context.view_layer.update()
    ports=json.loads((native.parent/'port_manifest.json').read_text())['ports']
    native_stats=mesh_stats(s);native_bounds=bounds([o for o in s.objects if o.type=='MESH' and not o.hide_render])
    native_bores=port_probe(s,ports);images=[dict(name=i.name,size=list(i.size),packed=bool(i.packed_file)) for i in bpy.data.images if i.source=='FILE']
    frames=(0,1,13,25,37,49,61,73,85,97);native_poses=poses(s,frames)
    prepare_state_tracks(s);bpy.ops.object.select_all(action='DESELECT')
    for o in s.objects:
        if o.type in ('MESH','EMPTY') and not o.hide_render:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_apply=True,
        export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,
        export_frame_range=False,export_anim_slide_to_zero=True,export_optimize_animation_size=False,
        export_optimize_animation_keep_anim_object=True,export_materials='EXPORT',export_image_format='AUTO',export_texcoords=True,export_normals=True)
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(glb));s=bpy.context.scene
    runtime_poses=poses(s,frames,imported=True);activate_imported_clip(s,'working');s.frame_set(24);bpy.context.view_layer.update()
    runtime_stats=mesh_stats(s);runtime_bounds=bounds([o for o in s.objects if o.type=='MESH']);runtime_bores=port_probe(s,ports)
    errors=[];pose_error=0;missing=set()
    for frame,objects in native_poses.items():
        for name,matrix in objects.items():
            if name not in runtime_poses[frame]:missing.add(name);continue
            pose_error=max(pose_error,max(abs(a-b) for a,b in zip(matrix,runtime_poses[frame][name])))
    bound_error=max(abs(native_bounds[i][j]-runtime_bounds[i][j]) for i in range(2) for j in range(3))
    if missing:errors.append('exported objects missing')
    if pose_error>1e-4:errors.append('actual imported state pose mismatch')
    if bound_error>.002:errors.append('bounds mismatch')
    if not native_bores['passed'] or not runtime_bores['passed']:errors.append('pipe mouth obstructions')
    if any(r['degenerate_triangles'] or not r['finite'] or r['missing_uv'] for r in (native_stats,runtime_stats)):errors.append('mesh validity')
    if any(not i['packed'] or min(i['size'])==0 for i in images):errors.append('unpacked or unloaded images')
    raw=glb.read_bytes();doc=json.loads(raw[20:20+int.from_bytes(raw[12:16],'little')]);clips=[]
    for animation in doc.get('animations',[]):
        accessors=[doc['accessors'][r['input']] for r in animation['samplers']]
        clips.append(dict(name=animation.get('name'),duration=max(a['max'][0] for a in accessors)-min(a['min'][0] for a in accessors),channels=len(animation['channels'])))
    if {c['name'] for c in clips}!={'idle','working'}:errors.append('missing coherent state clips')
    if any(abs(c['duration']-4)>1e-5 for c in clips if c['name']=='working'):errors.append('working clock differs')
    result=dict(passed=not errors,errors=errors,native_sha256=sha(native),glb_sha256=sha(glb),native_stats=native_stats,runtime_stats=runtime_stats,
        native_bounds=native_bounds,runtime_bounds=runtime_bounds,bounds_error=bound_error,native_bores=native_bores,runtime_bores=runtime_bores,
        source_images=images,maximum_sampled_world_pose_error=pose_error,missing_objects=sorted(missing),clips=clips,
        inspected_frames=list(frames),scope='Actual GLB reimport and ten selected state poses for every exported object; visual and native engine acceptance remain separate')
    report.write_text(json.dumps(result,indent=2)+'\n')
    print('MACHINE_EXPORT_READBACK',result['passed'],errors,'world_pose_error',pose_error,flush=True)
    if errors:raise RuntimeError('Export readback failed; preserve study')


if __name__=='__main__':main()
