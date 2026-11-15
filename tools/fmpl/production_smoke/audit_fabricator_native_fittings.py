"""Reopen native capture master: rigid mouth/rings, seats and actual feed bore."""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Matrix,Vector
from bpy_extras.object_utils import world_to_camera_view

sys.path.insert(0,str(Path(__file__).resolve().parent))
from fabricator_native_fittings import FabricatorNativeFittings
from audit_fabricator_flow import scene_tree
from audit_electrolyzer_v01 import mesh_stats,port_probe
from mh7_machine_scene import sha
from verify_purifier_v14 import gap


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--capture',required=True);args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);root=Path(args.capture).resolve()
    capture=json.loads((root/'capture.json').read_text());cfg=capture['config'];scale=cfg['camera_override']['ortho_scale'];height=cfg['camera_override']['target'][2]
    bpy.ops.wm.open_mainfile(filepath=str(root/'master.blend'));s=bpy.data.scenes['RENDER'];bpy.context.window.scene=s;s.frame_set(0)
    fitting=FabricatorNativeFittings(s);pivot=s.objects['EXPORT | direction pivot'];original=[v.co.copy() for v in fitting.reducer.data.vertices];errors=[];rows=[]
    for angle in (0,90,180,270):
        pivot.rotation_euler.z=math.radians(angle);fitting.apply(angle);bpy.context.view_layer.update();rotation=Matrix.Rotation(math.radians(angle),3,'Z');normal=rotation@Vector((-1,0,0))
        throat=next(o for o in fitting.mouth if 'reusable machine throat' in o.name);points=[throat.matrix_world@v.co for v in throat.data.vertices];end=max(p.dot(normal) for p in points);rim=[p for p in points if abs(p.dot(normal)-end)<1e-5];center=sum(rim,Vector())/len(rim)
        ndc=world_to_camera_view(s,s.camera,center);actual=((ndc.x-.5)*scale,(.5-ndc.y)*scale-height*math.sqrt(.5));canonical=rotation@Vector((-2,.5,.36));desired=(canonical.x,-canonical.y-.36*math.sqrt(.5));projection=max(abs(a-b) for a,b in zip(actual,desired))
        ring_error=max((a.co-b).length for a,b in zip(fitting.reducer.data.vertices,original));seat=gap(throat,fitting.barrel)
        bores=port_probe(s,[dict(id='forming_fluid_intake',model_mouth_center=list(center),outward_normal=list(normal))],offsets=[i*.047 for i in range(-5,6)],max_radius=.235)
        tree,names=scene_tree();blocked=[];rays=0
        path=[rotation@Vector(p) for p in fitting.feed['flow_path_samples']]
        for a,b in zip(path,path[1:]):
            direction=(b-a).normalized();side=direction.cross(Vector((0,0,1))).normalized();up=direction.cross(side)
            for offset in [Vector()]+[.015*(math.cos(i*math.tau/8)*side+math.sin(i*math.tau/8)*up) for i in range(8)]:
                rays+=1;hit,_,index,_=tree.ray_cast(a+offset,direction,(b-a).length)
                if hit is not None:blocked.append(names[index])
        stats=mesh_stats(s)
        if projection>.002 or ring_error>1e-6 or seat>.015 or not bores['passed'] or blocked or stats['degenerate_triangles'] or not stats['finite'] or stats['missing_uv']:errors.append('Native fitting geometry '+str(angle))
        rows.append(dict(angle=angle,projection_error_tiles=projection,unchanged_reducer_vertex_error=ring_error,throat_barrel_gap=seat,large_bore=bores,small_feed_rays=rays,small_feed_obstructions=blocked,mesh_stats=stats))
    (root/'native-fitting-readback.json').write_text(json.dumps(dict(passed=not errors,errors=errors,source_sha256=capture['source_sha256'],master_sha256=sha(root/'master.blend'),poses=rows,
        scope='Actual rim projection and matching barrel, unchanged 64-section cast reducer, .235-radius receiving core and constant-radius small-feed probes in four capture poses. Native screenshots separately establish visible seating; no owner approval inferred.'),indent=2)+'\n')
    print('FABRICATOR_NATIVE_FITTINGS',not errors,errors,flush=True)


if __name__=='__main__':main()
