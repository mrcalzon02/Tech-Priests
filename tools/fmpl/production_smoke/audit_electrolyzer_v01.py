"""Independent native/export audit for the real electrolyzer construction pilot."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from refine_purifier_v14 import bounds

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def port_probe(scene,ports,offsets=None,max_radius=.205):
    meshes=[o for o in scene.objects if o.type=='MESH' and not o.hide_render]
    hits=[];count=0
    for port in ports:
        center=Vector(port['model_mouth_center']);normal=Vector(port['outward_normal']).normalized()
        u=normal.cross(Vector((0,0,1))).normalized();v=normal.cross(u).normalized()
        values=offsets if offsets is not None else (-.18,-.12,-.06,0,.06,.12,.18)
        for a in values:
            for b in values:
                if a*a+b*b>max_radius**2+1e-10:continue
                origin=center+normal*.015+u*a+v*b;count+=1
                for ob in meshes:
                    inv=ob.matrix_world.inverted_safe()
                    hit=ob.ray_cast(inv @ origin,(inv.to_3x3() @ -normal).normalized(),distance=.305)
                    if hit[0]:hits.append(dict(port=port['id'],object=ob.name,offset=[a,b]))
    return dict(passed=not hits,rays=count,hits=hits)

def mesh_stats(scene):
    triangles=0;degenerate=0;finite=True;uv=[];degenerate_objects=[]
    dg=bpy.context.evaluated_depsgraph_get()
    for ob in scene.objects:
        if ob.type!='MESH' or ob.hide_render:continue
        evaluated=ob.evaluated_get(dg);mesh=evaluated.to_mesh()
        try:
            mesh.calc_loop_triangles();triangles+=len(mesh.loop_triangles)
            count=sum(t.area<1e-12 for t in mesh.loop_triangles);degenerate+=count
            if count:degenerate_objects.append(dict(object=ob.name,triangles=count))
            finite=finite and all(math.isfinite(c) for v in mesh.vertices for c in v.co)
            if not mesh.uv_layers:uv.append(ob.name)
        finally:evaluated.to_mesh_clear()
    return dict(triangles=triangles,degenerate_triangles=degenerate,degenerate_objects=degenerate_objects,finite=finite,missing_uv=uv)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--dir',required=True)
    ap.add_argument('--state-clips',action='store_true')
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);out=Path(args.dir).resolve()
    native=out/'electrolyzer-v01.blend';manifest=json.loads((out/'port_manifest.json').read_text())
    bpy.ops.wm.open_mainfile(filepath=str(native));s=bpy.context.scene;s.frame_set(25);bpy.context.view_layer.update()
    meshes=[o for o in s.objects if o.type=='MESH' and not o.hide_render]
    native_bounds=bounds(meshes);native_bores=port_probe(s,manifest['ports']);stats=mesh_stats(s)
    images=[dict(name=i.name,size=list(i.size),packed=bool(i.packed_file)) for i in bpy.data.images if i.source=='FILE']
    frames=[]
    for frame in (1,25,97):
        s.frame_set(frame)
        frames.append(dict(frame=frame,live_green_bars=[o.scale.z for o in s.objects if 'console live green bar' in o.name],
                           bubbles=[o.location.z for o in s.objects if 'visible electrode gas bubble' in o.name]))
    s.frame_set(25);bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT')
    for ob in s.objects:
        if (ob.type=='MESH' and not ob.hide_render) or ob.type=='EMPTY':ob.select_set(True)
    glb=out/'electrolyzer-v01.glb'
    if args.state_clips:
        from electrolyzer_state_clips import prepare_state_tracks
        prepare_state_tracks(s)
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_apply=True,
        export_animations=True,export_animation_mode='NLA_TRACKS' if args.state_clips else 'ACTIONS',export_force_sampling=True,
        export_frame_range=not args.state_clips,export_anim_slide_to_zero=args.state_clips,
        export_optimize_animation_size=not args.state_clips,export_optimize_animation_keep_anim_object=True,
        export_materials='EXPORT',export_image_format='AUTO',export_texcoords=True,export_normals=True)
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(glb));s=bpy.context.scene;s.frame_set(25)
    if args.state_clips:
        from electrolyzer_state_clips import activate_imported_clip
        activate_imported_clip(s,'working');s.frame_set(24)
    runtime_bounds=bounds([o for o in s.objects if o.type=='MESH']);runtime_stats=mesh_stats(s)
    runtime_bores=port_probe(s,manifest['ports'])
    max_error=max(abs(native_bounds[i][j]-runtime_bounds[i][j]) for i in range(2) for j in range(3))
    errors=[]
    if not native_bores['passed'] or not runtime_bores['passed']:errors.append('physical model-space mouth clearance')
    if not stats['finite'] or not runtime_stats['finite']:errors.append('nonfinite geometry')
    if stats['missing_uv'] or runtime_stats['missing_uv']:errors.append('missing UV')
    if stats['degenerate_triangles'] or runtime_stats['degenerate_triangles']:errors.append('degenerate triangles')
    if max_error>.002:errors.append('native/export bounds mismatch')
    if any(not x['packed'] or min(x['size'])==0 for x in images):errors.append('missing packed image')
    if frames[0]['bubbles']==frames[1]['bubbles']:errors.append('gas bubble motion absent')
    report=dict(status='PASS_TECHNICAL_PILOT' if not errors else 'FAIL',errors=errors,native_sha256=sha(native),glb_sha256=sha(glb),
        native_bounds=native_bounds,runtime_bounds=runtime_bounds,bounds_error=max_error,native_stats=stats,runtime_stats=runtime_stats,
        native_bores=native_bores,runtime_bores=runtime_bores,source_images=images,motion_samples=frames,
        provenance='new reconstruction from process packet with four actual registered donor instances',
        owner_approved=False,engine_integrated=False,
        pending=['rear/clay/close visual comparison','support and complete process-line contact audit','finishing and animation capture','actual native target/recipe/pipe jig'])
    (out/'independent-readback.json').write_text(json.dumps(report,indent=2)+'\n')
    print('ELECTROLYZER_TECHNICAL_PILOT',report['status'],errors,flush=True)
    if errors:raise RuntimeError('Pilot failures remain; retain study and repair before promotion')

if __name__=='__main__':main()
