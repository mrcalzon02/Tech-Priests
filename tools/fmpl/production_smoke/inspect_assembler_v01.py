"""Construction readback: contacts, state loop and actual GLB indexed poses."""
import argparse
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from mh7_machine_scene import sha
from verify_purifier_v14 import gap
from electrolyzer_state_clips import activate_imported_clip
from audit_fabricator_flow import scene_tree


def main():
    ap=argparse.ArgumentParser()
    for key in ('source','glb','out'):ap.add_argument('--'+key,required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);source=Path(args.source).resolve();glb=Path(args.glb).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve assembler inspections')
    out.mkdir(parents=True);bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(0);bpy.context.view_layer.update();receipt=json.loads((source.parent/'construction-receipt.json').read_text());contacts=[]
    for row in receipt['contacts']:
        a,b=(s.objects.get(row[k]) for k in ('a','b'));d=gap(a,b) if a and b else None;contacts.append(dict(**row,gap_tiles=d,passed=d is not None and d<=.015))
    # A fourteen-second work clip returns every actual object to its first pose.
    loop={}
    for frame in (1,337):
        s.frame_set(frame);bpy.context.view_layer.update();loop[frame]={o.name:[float(v) for row in o.matrix_world for v in row] for o in s.objects if o.type=='MESH'}
    error=max(abs(a-b) for name,values in loop[1].items() for a,b in zip(values,loop[337][name]))
    for o in list(s.objects):
        if o.type not in ('CAMERA','LIGHT'):bpy.data.objects.remove(o,do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=str(glb));s.render.fps=24;activate_imported_clip(s,'working');s.render.resolution_x=s.render.resolution_y=640;s.cycles.samples=24
    cam=s.camera;target=Vector((0,.20,1.30));cam.location=target+Vector((3,-5,4.2));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=5.8;views=[]
    for label,frame in (('first-station-fill',43),('second-station-cap',175),('third-station',247)):
        s.frame_set(frame-1);bpy.context.view_layer.update();path=out/(label+'.png');s.render.filepath=str(path);bpy.ops.render.render(write_still=True);views.append(dict(view=label,source_frame=frame,sha256=sha(path)))
    # A bounded actual-export core probe at the first full nozzle insertion.
    s.frame_set(42);bpy.context.view_layer.update();tree,names=scene_tree();obstructions=[]
    # Expected centerline, with the moving head at the first station X=-1.
    for label,a,b in [('hopper-throat',(-1,.63,2.70),(-1,.63,2.39)),('nozzle-to-vessel',(-1,.20,2.10),(-1,.20,.60))]:
        a,b=Vector(a),Vector(b);direction=(b-a).normalized();hit,_,index,_=tree.ray_cast(a,direction,(b-a).length)
        if hit is not None:obstructions.append(dict(segment=label,object=names[index],at=list(hit)))
    report=dict(source_sha256=sha(source),glb_sha256=sha(glb),recorded_contacts_passed=all(r['passed'] for r in contacts),contacts=contacts,
                work_loop_matrix_error=error,work_loop_passed=error<1e-5,views=views,centerline_obstructions=obstructions,
                scope='Recorded static contacts, actual 14-second first/last object matrices and three real GLB indexed-phase views. Two bounded vertical core probes are diagnostic only. Full swept cap/press/guide clearance, complete granular path, dedicated finish/audio/four-direction/native remain open.')
    (out/'assembler-readback.json').write_text(json.dumps(report,indent=2)+'\n');print('ASSEMBLER_CONTACTS',report['recorded_contacts_passed'],'LOOP',report['work_loop_passed'],'CORE_OBSTRUCTIONS',obstructions,flush=True)


if __name__=='__main__':main()
