"""Closeups from the actual GLB; these diagnostic cameras are not sprite captures."""
import argparse
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from mh7_machine_scene import sha
from electrolyzer_state_clips import activate_imported_clip


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--glb',required=True);ap.add_argument('--out',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);out=Path(args.out).resolve();source=Path(args.source).resolve();glb=Path(args.glb).resolve()
    if out.exists():raise FileExistsError('Preserve visual inspections')
    out.mkdir(parents=True);bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene
    for ob in list(s.objects):
        if ob.type not in ('CAMERA','LIGHT'):bpy.data.objects.remove(ob,do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=str(glb));activate_imported_clip(s,'working')
    s.render.resolution_x=s.render.resolution_y=640;s.cycles.samples=32;s.render.film_transparent=True
    views=[('hopper-auger',50,(0,.60,1.05),(2,3,2.3),2.15),
           ('die-loading',101,(0,-.03,.80),(2,-3,2.5),1.25),
           ('press-compressed',145,(0,-.10,.68),(2,-3,1.5),1.20),
           ('discharge',175,(0,-.80,.33),(1.5,-3,2.5),1.50),
           ('hydraulic-services',75,(.65,.15,1.60),(3,2,2.0),2.8)]
    rows=[]
    for label,frame,target,offset,scale in views:
        s.frame_set(frame-1);bpy.context.view_layer.update();target=Vector(target);s.camera.location=target+Vector(offset)
        s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=scale
        path=out/(label+'.png');s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        rows.append(dict(view=label,source_frame=frame,sha256=sha(path),target=list(target),camera_offset=offset,ortho_scale=scale))
    (out/'detail-readback.json').write_text(json.dumps(dict(source_sha256=sha(source),glb_sha256=sha(glb),views=rows,visual_approval=False,
        scope='Diagnostic closeups of actual reimported GLB working clip; four canonical sprite directions are a separate delivery.'),indent=2)+'\n')


if __name__=='__main__':main()
