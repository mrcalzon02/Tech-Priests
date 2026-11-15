"""Actual forge load contacts and seventeen guided-ram clearance samples."""
import argparse
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from refine_purifier_v14 import tree,sha,bounds
from verify_purifier_v14 import gap
from audit_electrolyzer_v01 import mesh_stats


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--out',required=True);ap.add_argument('--glb');args=ap.parse_args(sys.argv[sys.argv.index('--')+1:])
    source=Path(args.source).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve forge readbacks')
    out.mkdir(parents=True);bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene
    if args.glb:
        bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(Path(args.glb).resolve()));s=bpy.context.scene;s.render.fps=24
        from electrolyzer_state_clips import activate_imported_clip
        activate_imported_clip(s,'working')
    s.frame_set(0 if args.glb else 1);bpy.context.view_layer.update()
    receipt=json.loads((source.parent/'construction-receipt.json').read_text());contacts=[]
    for pair in receipt['contacts']:
        a,b=(s.objects.get(pair[k]) for k in ('a','b'));distance=gap(a,b) if a and b else None
        contacts.append(dict(**pair,gap_tiles=distance,passed=distance is not None and distance<=.015))
    meshes=[o for o in s.objects if o.type=='MESH' and not o.hide_render]
    moving_tokens=('guided moving crosshead','moving crosshead guide bearing','on-axis press punch','punch mounting shank','telescoping press piston rod')
    fixed_tokens=('fixed press guide rod','guide lower socket','guide upper socket','die supporting transverse bed','open tapered pellet die','rigid overhead press crossbeam','closed hydraulic press cylinder','actuator piston gland','die feed shoe')
    moving=[o for o in meshes if any(t in o.name for t in moving_tokens)];fixed=[o for o in meshes if any(t in o.name for t in fixed_tokens)]
    prefix='TP Pelletization Forge V01 | ';ram=s.objects[prefix+'complete guided ram'];punch=s.objects[prefix+'on-axis press punch'];piston=s.objects[prefix+'telescoping press piston rod']
    rows=[];collisions=[];checks=0;loop={}
    for frame in range(1,194,12):
        s.frame_set(frame-1 if args.glb else frame);bpy.context.view_layer.update();cache={o:tree(o) for o in moving+fixed}
        for a in moving:
            for b in fixed:
                checks+=1;overlap=cache[a].overlap(cache[b])
                if overlap:collisions.append(dict(frame=frame,a=a.name,b=b.name,pairs=len(overlap)))
        ends=[piston.matrix_world@Vector((0,0,z)) for z in (-.5,.5)];lower=min(p.z for p in ends);upper=max(p.z for p in ends)
        endpoint_error=max(abs(lower-(ram.location.z+.055)),abs(upper-1.92))
        punch_center=punch.matrix_world.translation;axis_error=abs(punch_center.x)+abs(punch_center.y+.10)
        rows.append(dict(frame=frame,crosshead_z=ram.location.z,punch_center=list(punch_center),punch_axis_error=axis_error,piston_endpoint_error=endpoint_error))
        if frame in (1,193):loop[frame]={o.name:[float(c) for row in o.matrix_world for c in row] for o in moving}
    loop_error=max(abs(a-b) for name,values in loop[1].items() for a,b in zip(values,loop[193][name]));stats=mesh_stats(s);errors=[]
    if any(not p['passed'] for p in contacts):errors.append('assembly contact')
    if collisions:errors.append('guided ram intersects fixed machine')
    if any(r['punch_axis_error']>1e-5 or r['piston_endpoint_error']>1e-5 for r in rows):errors.append('punch/piston axis attachment')
    if loop_error>1e-5:errors.append('working loop closure')
    if stats['degenerate_triangles'] or not stats['finite'] or stats['missing_uv']:errors.append('mesh validity')
    report=dict(passed=not errors,errors=errors,source_sha256=sha(source),glb_sha256=sha(args.glb) if args.glb else None,contacts=contacts,sampled_motion=rows,moving_fixed_pair_checks=checks,collisions=collisions,loop_world_matrix_error=loop_error,
        mesh_stats=stats,bounds=bounds(meshes),scope='Recorded assembly contacts, on-axis punch/telescoping endpoints and named guided-ram/static surfaces at 17 actual poses. Full solid-material feed/ejection path and working-part finishing remain separate gates.')
    (out/'mechanical-readback.json').write_text(json.dumps(report,indent=2)+'\n');print('FORGE_MECHANICS',not errors,errors,'failed_contacts',sum(not r['passed'] for r in contacts),'collisions',len(collisions),flush=True)


if __name__=='__main__':main()
