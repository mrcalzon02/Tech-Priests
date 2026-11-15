"""Source/actual GLB deformation, recorded contacts and open-frame phase views."""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree

sys.path.insert(0,str(Path(__file__).resolve().parent))
from mh7_machine_scene import sha
from verify_purifier_v14 import gap
from electrolyzer_state_clips import activate_imported_clip


def points(obj):
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
    try:return [obj.matrix_world@v.co for v in mesh.vertices]
    finally:evaluated.to_mesh_clear()


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--glb',required=True);ap.add_argument('--out',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);source=Path(args.source).resolve();glb=Path(args.glb).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve fabricator readbacks')
    out.mkdir(parents=True);bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(0);bpy.context.view_layer.update()
    receipt=json.loads((source.parent/'construction-receipt.json').read_text());contacts=[]
    for row in receipt['contacts']:
        a,b=(s.objects.get(row[k]) for k in ('a','b'));d=gap(a,b) if a and b else None
        contacts.append(dict(**row,gap_tiles=d,passed=d is not None and d<=.015))
    blank=next(o for o in s.objects if o.name.endswith('welded two-plate pressure blank'))
    frames=(0,1,25,73,109,145,163,181,199,217,253,289);native={}
    for frame in frames:
        s.frame_set(frame);bpy.context.view_layer.update();native[frame]=points(blank)
    # Keep source inspection lighting, but replace every geometry object with
    # the actual exported artifact before taking any phase preview.
    for obj in list(s.objects):
        if obj.type not in ('CAMERA','LIGHT'):bpy.data.objects.remove(obj,do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=str(glb));s=bpy.context.scene;s.render.fps=24
    blank=next(o for o in s.objects if o.name.endswith('welded two-plate pressure blank'))
    rows=[];max_error=0
    for frame in frames:
        activate_imported_clip(s,'idle' if frame==0 else 'working');s.frame_set(max(0,frame-1));bpy.context.view_layer.update();actual=points(blank)
        tree=KDTree(len(native[frame]))
        for i,point in enumerate(native[frame]):tree.insert(point,i)
        tree.balance();error=max(tree.find(point)[2] for point in actual)
        reverse=KDTree(len(actual))
        for i,point in enumerate(actual):reverse.insert(point,i)
        reverse.balance();error=max(error,max(reverse.find(point)[2] for point in native[frame]));max_error=max(max_error,error)
        extent=[max(p[i] for p in actual)-min(p[i] for p in actual) for i in range(3)]
        rows.append(dict(source_frame=frame,world_vertex_error=error,extent=extent))
    s.render.resolution_x=s.render.resolution_y=640;s.cycles.samples=24;cam=s.camera;cam.data.ortho_scale=5.3;target=Vector((0,0,1.02));cam.location=target+Vector((3,-5,4.2));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    views=[]
    for label,frame in [('plate-welding-open',49),('clamped-expanding',175),('formed-vessel-exposed',255)]:
        activate_imported_clip(s,'working');s.frame_set(frame-1);bpy.context.view_layer.update();p=out/(label+'.png');s.render.filepath=str(p);bpy.ops.render.render(write_still=True);views.append(dict(name=label,source_frame=frame,sha256=sha(p)))
    initial=next(r for r in rows if r['source_frame']==1)['extent'];formed=next(r for r in rows if r['source_frame']==199)['extent'];errors=[]
    if max_error>1e-5:errors.append('actual exported morph differs')
    if formed[2]<initial[2]*3 or abs(formed[0]-initial[0])>1e-5 or abs(formed[1]-initial[1])>1e-5:errors.append('wrong hydroforming expansion')
    report=dict(morph_passed=not errors,errors=errors,source_sha256=sha(source),glb_sha256=sha(glb),recorded_contacts_passed=all(r['passed'] for r in contacts),contacts=contacts,
        maximum_deformed_world_vertex_error=max_error,morph_samples=rows,views=views,
        scope='Actual runtime deformed vertices versus source at 12 idle/working phases; recorded static assembly contacts. Full moving-frame/pressure-route clearance, dedicated finish and native prototype remain open; diagnostic cameras are not production capture.')
    (out/'hydroforming-readback.json').write_text(json.dumps(report,indent=2)+'\n');print('HYDROFORMING_MORPH',not errors,'CONTACTS',report['recorded_contacts_passed'],'ERROR',max_error,flush=True)


if __name__=='__main__':main()
