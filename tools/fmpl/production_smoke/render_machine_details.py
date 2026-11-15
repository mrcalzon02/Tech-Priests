"""Actual GLB detail renders, source lighting, explicit diagnostic cameras."""
import argparse
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from refine_purifier_v14 import sha
from electrolyzer_state_clips import activate_imported_clip


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--native',required=True);ap.add_argument('--glb',required=True)
    ap.add_argument('--views',required=True);ap.add_argument('--out',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);native=Path(args.native).resolve();glb=Path(args.glb).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve existing inspection views')
    out.mkdir(parents=True);views=json.loads(Path(args.views).read_text())
    bpy.ops.wm.open_mainfile(filepath=str(native));s=bpy.context.scene
    for ob in list(s.objects):
        if ob.type in ('MESH','EMPTY'):bpy.data.objects.remove(ob,do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=str(glb));activate_imported_clip(s,'working');s.frame_set(24)
    s.cycles.samples=32;s.render.resolution_x=s.render.resolution_y=640;s.render.resolution_percentage=100;records=[]
    for view in views:
        cam=s.camera;cam.location=view['location'];cam.rotation_euler=(Vector(view['target'])-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=view['scale']
        s.render.filepath=str(out/(view['name']+'.png'));bpy.ops.render.render(write_still=True)
        records.append(dict(**view,sha256=sha(s.render.filepath),matrix=[list(r) for r in cam.matrix_world]))
    (out/'inspection.json').write_text(json.dumps(dict(native_sha256=sha(native),glb_sha256=sha(glb),views=records,
        scope='Actual GLB reimport under source lighting; diagnostic cameras, not production sprite orientations'),indent=2)+'\n')


if __name__=='__main__':main()
