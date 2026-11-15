"""Inspect actual animated stock against the machine, not just the empty ram."""
import argparse
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from refine_purifier_v14 import tree,sha,bounds


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--out',required=True);ap.add_argument('--glb')
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);source=Path(args.source).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve material-path studies')
    out.mkdir(parents=True);bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene
    if args.glb:
        bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(Path(args.glb).resolve()))
        s=bpy.context.scene;s.render.fps=24
        from electrolyzer_state_clips import activate_imported_clip
        activate_imported_clip(s,'working')
    def pose(frame):
        f=frame-1 if args.glb else frame
        s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
    stock=next(o for o in s.objects if o.name.endswith('one visible transforming pellet'))
    objects=[o for o in s.objects if o.type=='MESH' and o!=stock and not o.hide_render]
    def animated(o):
        while o:
            if o.animation_data:return True
            o=o.parent
        return False
    static={};collisions=[];rows=[];pair_checks=0
    flight=next(o for o in objects if o.name.endswith('actual auger flight'))
    rotor_collisions=[];rotor_checks=0
    fixed=[o for o in objects if not animated(o)]
    def intersects(a,b):return not any(a[1][i]<b[0][i]-.003 or b[1][i]<a[0][i]-.003 for i in range(3))
    for sample in range(4,193*4+1):
        frame=sample/4;pose(frame)
        fb=bounds([flight]);ft=tree(flight)
        for ob in fixed:
            if not intersects(fb,bounds([ob])):continue
            if ob not in static:static[ob]=tree(ob)
            rotor_checks+=1;overlap=ft.overlap(static[ob])
            if overlap:rotor_collisions.append(dict(frame=frame,object=ob.name,pairs=len(overlap)))
        if min(stock.scale)<1e-5:continue
        sb=bounds([stock]);st=tree(stock);closest=None
        for ob in objects:
            bb=bounds([ob])
            if any(sb[1][i]<bb[0][i]-.003 or bb[1][i]<sb[0][i]-.003 for i in range(3)):continue
            pair_checks+=1
            if animated(ob):ot=tree(ob)
            else:
                if ob not in static:static[ob]=tree(ob)
                ot=static[ob]
            overlap=st.overlap(ot)
            # Coincident punch contact is an intentional load contact. Crossing
            # its plane is still a failure; other intersections are not waived.
            contact=ob.name.endswith('on-axis press punch') and bb[0][2]>=sb[1][2]-2e-6
            if overlap and not contact:collisions.append(dict(frame=frame,object=ob.name,pairs=len(overlap)))
        rows.append(dict(frame=frame,center=list(stock.matrix_world.translation),scale=list(stock.scale),bounds=sb))
    # Direct full-size envelope checks also cover containment within closed
    # shells, which surface intersection alone cannot detect.
    envelope=[]
    for row in rows:
        frame=row['frame'];u=(frame-1)/192;x,y,z=row['center']
        if .12<=u<=.40:
            radial=(x*x+(z-.8)**2)**.5
            envelope.append(dict(frame=frame,bore_clearance=.25-radial-.075,
                                 shaft_clearance=radial-.075-.025))
    errors=[]
    if collisions:errors.append('stock intersects machine surfaces')
    if not envelope or min(min(r['bore_clearance'],r['shaft_clearance']) for r in envelope)<.001:errors.append('auger transport envelope')
    # The delivery must genuinely visit load, feeder, die, compression, ejection
    # and tray; a stationary/hidden pellet cannot satisfy the material audit.
    landmarks={}
    for label,frame in [('hopper',6),('auger',50),('die',101),('compressed',145),('ejected',156),('tray',188)]:
        pose(frame);landmarks[label]=dict(frame=frame,center=list(stock.matrix_world.translation),scale=list(stock.scale))
    if landmarks['hopper']['center'][2]<1.2 or landmarks['compressed']['scale'][0]>.71 or landmarks['tray']['center'][1]>-1.2:errors.append('missing functional phase')
    if rotor_collisions:errors.append('rotating flight intersects fixed machine')
    report=dict(passed=not errors,errors=errors,source_sha256=sha(source),glb_sha256=sha(args.glb) if args.glb else None,visible_poses=len(rows),nearby_surface_pair_checks=pair_checks,
        collisions=collisions,auger_full_size_envelope=envelope,landmarks=landmarks,poses=rows,
        rotor_static_pair_checks=rotor_checks,rotor_collisions=rotor_collisions,
        scope='Quarter-frame sampling of the full cycle: actual visible stock surface overlap with all renderable machine meshes, auger flight versus every fixed mesh, full radial transport envelope and functional phase readback. Continuous clearance between samples and physical force/volume simulation are not certified.')
    (out/'material-path-readback.json').write_text(json.dumps(report,indent=2)+'\n')
    print('FORGE_MATERIAL_PATH',not errors,errors,'collisions',len(collisions),flush=True)


if __name__=='__main__':main()
