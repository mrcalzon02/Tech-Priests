"""Read actual swept process paths against evaluated visible machine geometry.

This is a metal centre-path test, not a full swept-volume certification.
Fluid/glass occupants are reported separately from structural obstructions.
"""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from refine_purifier_v14 import tree, sha


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--source', required=True)
    ap.add_argument('--report', required=True)
    ap.add_argument('--glb', help='Inspect this actual reimport using source path samples')
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:])
    source=Path(args.source).resolve()
    bpy.ops.wm.open_mainfile(filepath=str(source))
    s=bpy.context.scene;s.frame_set(25);bpy.context.view_layer.update()
    routes=[dict(name=o.name,points=[list(p) for p in o['flow_path_samples']],bore=float(o['bore_diameter']))
            for o in s.objects if o.type=='MESH' and not o.hide_render and o.get('flow_path_samples') and
            any(t in o.name for t in ('independent upper gas header','common liquid water trunk','separate water feed branch'))]
    if args.glb:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(Path(args.glb).resolve()))
        s=bpy.context.scene;s.frame_set(25);bpy.context.view_layer.update()
    meshes=[o for o in s.objects if o.type=='MESH' and not o.hide_render]
    cache={o.name:tree(o) for o in meshes}
    blockers=[];occupants=[];probes=0
    for route in routes:
        points=[Vector(p) for p in route['points']]
        radius=route['bore']/2
        for a,b in zip(points,points[1:]):
            d=b-a;length=d.length
            if length<1e-6:continue
            d.normalize()
            u=d.cross(Vector((0,0,1)))
            if u.length<.001:u=d.cross(Vector((0,1,0)))
            u.normalize();v=d.cross(u).normalized()
            offsets=[Vector((0,0,0))]+[radius*.7*(u*math.cos(k*math.tau/8)+v*math.sin(k*math.tau/8)) for k in range(8)]
            for sample,offset in enumerate(offsets):
                probes+=1
                for ob in meshes:
                    hit=cache[ob.name].ray_cast(a+offset+d*.00001,d,max(0,length-.00002))
                    if hit[0] is None:continue
                    row=dict(route=route['name'],object=ob.name,core_sample=sample,point=list(hit[0]),
                             distance_from_endpoint=min((hit[0]-points[0]).length,(hit[0]-points[-1]).length))
                    mats=[m.name.lower() for m in ob.data.materials if m]
                    target=occupants if mats and all(any(t in m for t in ('electrolyte','gas nucleation','pressure window')) for m in mats) else blockers
                    target.append(row)
    report=dict(source_sha256=sha(source),route_count=len(routes),segment_probes=probes,
                glb_sha256=sha(args.glb) if args.glb else None,
                blockers=blockers,fluid_or_glass_occupants=occupants,
                passed=bool(routes) and not blockers,
                scope='actual stored path segments: centre plus eight offsets at 70% bore radius; endpoint hits remain failures; discrete sampled core, not complete swept-volume proof')
    Path(args.report).write_text(json.dumps(report,indent=2)+'\n')
    print('ELECTROLYZER_ROUTE_AUDIT',json.dumps(report),flush=True)


if __name__=='__main__':main()
