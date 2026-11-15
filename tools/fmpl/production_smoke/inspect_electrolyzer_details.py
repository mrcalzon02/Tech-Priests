"""Render actual exported-model joint/surface details, under source lighting."""
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
    ap=argparse.ArgumentParser();ap.add_argument('--dir',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);root=Path(args.dir).resolve();out=root/'export-details'
    if out.exists():raise FileExistsError('Retain inspection states')
    out.mkdir()
    source=root/'electrolyzer-v01.blend';glb=root/'electrolyzer-v01.glb'
    bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(25)
    for ob in list(s.objects):
        if ob.type in ('MESH','EMPTY'):bpy.data.objects.remove(ob,do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=str(glb));activate_imported_clip(s,'working');s.frame_set(24);s.cycles.samples=32
    s.render.resolution_x=s.render.resolution_y=640;s.render.resolution_percentage=100
    camera=s.camera;rows=[]
    for name,location,target,scale in (
        ('water-feed-and-console',(2.8,-5,3.4),(0,-.65,.82),3.4),
        ('cell-heads-and-power',(2.8,4.4,4.6),(0,.48,1.98),3.6),
        ('side-routing',(5,-2.8,3.8),(0,0,1.25),5.4)):
        camera.location=location;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
        camera.data.ortho_scale=scale;s.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
        rows.append(dict(file=name+'.png',sha256=sha(s.render.filepath),camera_matrix=[list(r) for r in camera.matrix_world],ortho_scale=scale))
    (out/'inspection.json').write_text(json.dumps(dict(source_sha256=sha(source),glb_sha256=sha(glb),
        scope='Actual GLB reimport, source lighting; oblique diagnostic views, not production capture cameras',images=rows),indent=2)+'\n')
    print('ELECTROLYZER_DETAILS_RENDERED',len(rows),flush=True)


if __name__=='__main__':main()
