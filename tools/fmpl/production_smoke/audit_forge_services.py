"""Bounded service-mouth and moving/service collision checks on actual meshes."""
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
    if out.exists():raise FileExistsError('Preserve service studies')
    out.mkdir(parents=True);bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene
    if args.glb:
        bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(Path(args.glb).resolve()));s=bpy.context.scene;s.render.fps=24
        from electrolyzer_state_clips import activate_imported_clip
        activate_imported_clip(s,'working')
    def pose(frame):s.frame_set(frame-1 if args.glb else frame);bpy.context.view_layer.update()
    meshes=[o for o in s.objects if o.type=='MESH' and not o.hide_render]
    added=[o for o in meshes if o.name.startswith('TP Forge V03 | ')]
    moving=[o for o in meshes if any(t in o.name for t in ('guided moving crosshead','moving crosshead guide bearing','on-axis press punch','punch mounting shank','telescoping press piston rod','actual auger flight','auger supported drive shaft'))]
    cache={};collisions=[];checks=0
    pose(1)
    for o in added:cache[o]=tree(o)
    for frame in range(1,194,3):
        pose(frame)
        for a in moving:
            ab=bounds([a]);at=None
            for b in added:
                bb=bounds([b])
                if any(ab[1][i]<bb[0][i] or bb[1][i]<ab[0][i] for i in range(3)):continue
                if at is None:at=tree(a)
                checks+=1;overlap=at.overlap(cache[b])
                if overlap:collisions.append(dict(frame=frame,a=a.name,b=b.name,pairs=len(overlap)))
    pose(1);hits=[];rays=0
    receipt=json.loads((source.parent/'construction-receipt.json').read_text())
    contacts={frozenset((r['a'],r['b'])) for r in receipt['contacts']}
    route_checks=0;route_collisions=[]
    routes=[o for o in added if o.name.endswith(' hose')]
    for a in routes:
        ab=bounds([a]);at=tree(a)
        for b in meshes:
            if a==b or frozenset((a.name,b.name)) in contacts or b in moving or 'one visible transforming pellet' in b.name:continue
            bb=bounds([b])
            if any(ab[1][i]<bb[0][i] or bb[1][i]<ab[0][i] for i in range(3)):continue
            route_checks+=1;overlap=at.overlap(tree(b))
            if overlap:route_collisions.append(dict(a=a.name,b=b.name,pairs=len(overlap)))
    ports=[('supply cylinder',Vector((.30,-.10,2.33)),Vector((-1,0,0)),.26),('return cylinder',Vector((.30,-.10,2.12)),Vector((-1,0,0)),.26),
           ('supply reservoir',Vector((1.14,.57,.69)),Vector((0,0,-1)),.18),('return reservoir',Vector((1.02,.57,.69)),Vector((0,0,-1)),.18)]
    for label,center,direction,length in ports:
        a=Vector((0,1,0));b=direction.cross(a).normalized()
        for x in (-.012,0,.012):
            for y in (-.012,0,.012):
                origin=center+a*x+b*y;rays+=1
                for obj in meshes:
                    inv=obj.matrix_world.inverted_safe();local_dir=(inv.to_3x3()@direction).normalized()
                    # Local distance is converted for non-unit object transforms.
                    local_len=(inv.to_3x3()@(direction*length)).length
                    hit=obj.ray_cast(inv@origin,local_dir,distance=local_len)
                    if hit[0]:hits.append(dict(port=label,object=obj.name,offset=[x,y],world_hit=list(obj.matrix_world@hit[1])))
    errors=[]
    if collisions:errors.append('moving assembly intersects added hydraulic service')
    if route_collisions:errors.append('service hose intersects non-contact machine surface')
    if hits:errors.append('service core blocked')
    report=dict(passed=not errors,errors=errors,source_sha256=sha(source),glb_sha256=sha(args.glb) if args.glb else None,
        poses=65,moving_service_pair_checks=checks,collisions=collisions,route_static_pair_checks=route_checks,route_collisions=route_collisions,core_rays=rays,core_hits=hits,
        scope='Source or actual GLB service mouths to nearby chamber/ reservoir cavity, and 65 poses of moving components against added services. Full hydraulic pressure/force simulation is outside this art check.')
    (out/'service-readback.json').write_text(json.dumps(report,indent=2)+'\n');print('FORGE_SERVICES',not errors,errors,flush=True)


if __name__=='__main__':main()
