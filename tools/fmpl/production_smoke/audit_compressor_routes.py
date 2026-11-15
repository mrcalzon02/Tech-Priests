"""Probe source-authored suction/discharge paths against actual scene surfaces."""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from refine_purifier_v14 import tree,sha


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--report',required=True);ap.add_argument('--glb')
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);source=Path(args.source).resolve();report=Path(args.report).resolve()
    if report.exists():raise FileExistsError('Preserve path readbacks')
    bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(25)
    routes=[dict(name=o.name,points=[list(p) for p in o['flow_path_samples']],bore=float(o['bore_diameter'])) for o in s.objects
            if o.get('flow_path_samples') and any(t in o.name for t in ('independent pressure header','cell branch'))]
    if len(routes)!=8:raise RuntimeError('Expected two independent headers and six true branches')
    if args.glb:
        bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(Path(args.glb).resolve()));s=bpy.context.scene
        from electrolyzer_state_clips import activate_imported_clip
        activate_imported_clip(s,'working');s.frame_set(24)
    bpy.context.view_layer.update();meshes=[o for o in s.objects if o.type=='MESH' and not o.hide_render];cache={o.name:tree(o) for o in meshes}
    blockers=[];closures=[];count=0
    for route in routes:
        points=[Vector(p) for p in route['points']];radius=.7*route['bore']/2
        for a,b in zip(points,points[1:]):
            delta=b-a;length=delta.length
            if length<1e-6:continue
            d=delta.normalized();u=d.cross(Vector((0,0,1)))
            if u.length<.001:u=d.cross(Vector((0,1,0)))
            u.normalize();v=d.cross(u).normalized()
            offsets=[Vector()]+[radius*(u*math.cos(k*math.tau/8)+v*math.sin(k*math.tau/8)) for k in range(8)]
            for sample,offset in enumerate(offsets):
                count+=1
                for ob in meshes:
                    hit=cache[ob.name].ray_cast(a+offset+d*.00001,d,max(0,length-.00002))
                    if hit[0] is None:continue
                    row=dict(route=route['name'],object=ob.name,sample=sample,point=list(hit[0]))
                    label='suction' if 'suction' in route['name'] else 'discharge'
                    intended='independent pressure header' in route['name'] and label+' closed header end' in ob.name and (hit[0]-points[-1]).length<.085
                    (closures if intended else blockers).append(row)
    wall_checks=[]
    for label,y,height in (('suction',.2,1.20),('discharge',.75,1.34)):
        header=next(o for o in meshes if label+' independent pressure header' in o.name)
        tests=[(x,1) for x in (-.72,0,.72)]+([(.38,-1),(-.35,-1)] if label=='discharge' else [])
        for x,side in tests:
            start=Vector((x,y,height+side*.20));direction=Vector((0,0,-side))
            hit=cache[header.name].ray_cast(start,direction,.16)
            valid=hit[0] is not None and abs(hit[0].z-(height+side*.08))<.003
            wall_checks.append(dict(header=header.name,x=x,side='upper' if side==1 else 'lower',passed=valid,
                                    actual_surface=list(hit[0]) if hit[0] is not None else None))
    result=dict(passed=not blockers and all(r['passed'] for r in wall_checks),source_sha256=sha(source),glb_sha256=sha(args.glb) if args.glb else None,
        routes=len(routes),sampled_core_rays=count,blockers=blockers,intentional_closed_header_ends=closures,
        opposite_pressure_wall_checks=wall_checks,
        scope='Centre and eight offsets at 70% bore radius; named terminal pressure caps classified explicitly. Opposite header walls must remain sealed at branch/tap cuts.')
    report.write_text(json.dumps(result,indent=2)+'\n');print('COMPRESSOR_ROUTES',result['passed'],'rays',count,'blockers',len(blockers),'open_opposite_walls',sum(not r['passed'] for r in wall_checks),flush=True)
    if not result['passed']:raise RuntimeError('Actual path obstruction or unintended pressure opening; preserve readback')


if __name__=='__main__':main()
