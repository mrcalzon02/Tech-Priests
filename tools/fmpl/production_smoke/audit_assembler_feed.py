"""Probe complete open granular path, closed gate/lids and landed sealing tool."""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from audit_fabricator_flow import scene_tree
from electrolyzer_state_clips import activate_imported_clip
from mh7_machine_scene import sha
from verify_purifier_v14 import gap


def set_frame(scene,frame,imported):
    if imported:activate_imported_clip(scene,'idle' if frame==0 else 'working')
    time=max(0,frame-1) if imported else frame;scene.frame_set(int(time),subframe=time-int(time));bpy.context.view_layer.update()


def inspect(scene,paths,starts,imported=False):
    rows=[];errors=[]
    for station,(x,start) in enumerate(zip((-1.0,0.0,1.0),starts)):
        set_frame(scene,1+(start+1.6)*24,imported);tree,names=scene_tree();blocked=[];rays=0
        for label,path,radius in paths:
            path=[Vector((x+p[0],p[1],p[2])) for p in path]
            for a,b in zip(path,path[1:]):
                direction=(b-a).normalized();side=direction.cross(Vector((0,0,1)))
                if side.length<.01:side=direction.cross(Vector((0,1,0)))
                side.normalize();up=direction.cross(side).normalized()
                for offset in [Vector()]+[radius*(math.cos(i*math.tau/8)*side+math.sin(i*math.tau/8)*up) for i in range(8)]:
                    rays+=1;hit,_,index,_=tree.ray_cast(a+offset,direction,(b-a).length)
                    if hit is not None:blocked.append(dict(path=label,object=names[index],at=list(hit)))
        # An open filling path still needs a real closed bottom to retain stock.
        hit,_,index,_=tree.ray_cast(Vector((x,.20,.60)),Vector((0,0,-1)),.20)
        bottom=hit is not None and 'canister closed bottom' in names[index]
        set_frame(scene,1+(start+3.5)*24,imported)
        punch=next(o for o in scene.objects if o.name.endswith('annular cap sealing punch'));cap=next(o for o in scene.objects if o.name.endswith('pressure cap plate '+str(x)));landed=gap(punch,cap)
        passed=not blocked and bottom and landed is not None and landed<.003
        if not passed:errors.append('station '+str(station))
        rows.append(dict(station=station,center_x=x,source_fill_frame=1+(start+1.6)*24,open_core_rays=rays,obstructions=blocked,closed_bottom_verified=bottom,landed_punch_gap=landed,passed=passed))
    set_frame(scene,0,imported);tree,names=scene_tree();closed=[]
    for x in (-1.0,0.0,1.0):
        hit,_,index,_=tree.ray_cast(Vector((x,.20,1.65)),Vector((0,0,-1)),.30)
        passed=hit is not None and 'pressure cap plate' in names[index];closed.append(dict(x=x,closed_lid=passed,obstruction=names[index] if hit is not None else None))
        if not passed:errors.append('closed lid '+str(x))
    hit,_,index,_=tree.ray_cast(Vector((-1,.48,paths[0][1][-1][2]+.08)),Vector((0,0,-1)),.16)
    gate=hit is not None and 'actual sliding pellet gate' in names[index]
    if not gate:errors.append('closed metering gate')
    return dict(passed=not errors,errors=errors,open_station_probes=rows,closed_lids=closed,closed_metering_gate=gate,closed_gate_object=names[index] if hit is not None else None)


def main():
    ap=argparse.ArgumentParser()
    for key in ('source','glb','out'):ap.add_argument('--'+key,required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);source=Path(args.source).resolve();glb=Path(args.glb).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve granular-path evidence')
    bpy.ops.wm.open_mainfile(filepath=str(source));scene=bpy.context.scene;set_frame(scene,0,False)
    receipt=json.loads((source.parent/'construction-receipt.json').read_text());starts=receipt['station_start_seconds']
    feed=next(o for o in scene.objects if o.name.endswith('carriage pellet feed bore'));route=[list(p) for p in feed['flow_path_samples']]
    paths=[('hopper and gate',[(0,.48,2.80),route[0]],.025),('curved feed',route,.025),('guide nozzle and canister',[(0,.20,2.10),(0,.20,.60)],.025)]
    report=dict(source_sha256=sha(source),glb_sha256=sha(glb),source=inspect(scene,paths,starts))
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(glb));scene=bpy.context.scene;scene.render.fps=24;report['runtime']=inspect(scene,paths,starts,True)
    report['passed']=report['source']['passed'] and report['runtime']['passed'];report['scope']='Center plus eight .025-radius offset rays traverse hopper/gate, every authored curved-feed segment and the guide/nozzle/neck at all three actual filling positions in source and GLB. Closed metering gate, closed lids, vessel bottoms and landed punch are independently checked. This is geometric bore evidence, not granular-flow simulation or pressure certification.'
    out.write_text(json.dumps(report,indent=2)+'\n');print('ASSEMBLER_COMPLETE_FEED',report['passed'],flush=True)
    for stage in ('source','runtime'):
        print(stage,report[stage]['errors'],'GATE',report[stage]['closed_metering_gate'],flush=True)
        for row in report[stage]['open_station_probes']:print('STATION',row['station'],row['passed'],'GAP',row['landed_punch_gap'],'BLOCKED',row['obstructions'][:3],flush=True)


if __name__=='__main__':main()
