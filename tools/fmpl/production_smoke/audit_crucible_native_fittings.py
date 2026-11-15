"""Measure real native-profile mouths, unchanged reducer rings and bore cores."""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Matrix,Vector
from bpy_extras.object_utils import world_to_camera_view

sys.path.insert(0,str(Path(__file__).resolve().parent))
from crucible_native_fittings import CrucibleNativeFittings
from audit_electrolyzer_v01 import mesh_stats,port_probe
from refine_purifier_v14 import sha
from verify_purifier_v14 import gap


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--capture',required=True);args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);root=Path(args.capture).resolve()
    capture=json.loads((root/'capture.json').read_text());cfg=capture['config'];scale=cfg['camera_override']['ortho_scale'];height=cfg['camera_override']['target'][2]
    bpy.ops.wm.open_mainfile(filepath=str(root/'master.blend'));s=bpy.data.scenes['RENDER'];bpy.context.window.scene=s;s.frame_set(0)
    fit=CrucibleNativeFittings(s);pivot=s.objects['EXPORT | direction pivot'];rows=[];errors=[]
    for angle in (0,90,180,270):
        pivot.rotation_euler.z=math.radians(angle);fit.apply(angle);bpy.context.view_layer.update();rotation=Matrix.Rotation(math.radians(angle),3,'Z');ports=[];measurements=[]
        for role,(position,_,_) in fit.PORTS.items():
            center=Vector(position);normal=rotation@Vector((-1,0,0) if center.x<0 else (1,0,0))
            throat=next(o for o in fit.groups[role] if 'reusable machine throat' in o.name)
            points=[throat.matrix_world@v.co for v in throat.data.vertices];end=max(p.dot(normal) for p in points)
            rim=[p for p in points if abs(p.dot(normal)-end)<1e-5];actual=sum(rim,Vector())/len(rim)
            projected=world_to_camera_view(s,s.camera,actual);tiles=((projected.x-.5)*scale,(.5-projected.y)*scale-height*math.sqrt(.5));canonical=rotation@center
            desired=(canonical.x,-canonical.y-.36*math.sqrt(.5));error=max(abs(a-b) for a,b in zip(tiles,desired))
            seated=gap(throat,fit.barrels[role]);reducer=fit.reducers[role]
            # Every original 64-section reducer ring remains unwarped. The
            # derivative adds a straight full-bore neck, rather than twisting it.
            vertex_error=max((v.co-old).length for v,old in zip(reducer.data.vertices,fit.vertices[reducer]))
            if error>.002 or seated>.015 or vertex_error>1e-6:errors.append('actual interface geometry '+str((angle,role)))
            measurements.append(dict(role=role,kind='fluid input' if role=='conditioned_hydrogen_input' else 'solid pellet transfer',actual_center=list(actual),projection_error_tiles=error,
                throat_receiving_gap=seated,reducer_vertex_error=vertex_error))
            ports.append(dict(id=role,model_mouth_center=list(actual),outward_normal=list(normal)))
        bores=port_probe(s,ports,offsets=[k*.047 for k in range(-5,6)],max_radius=.235);stats=mesh_stats(s)
        if not bores['passed'] or stats['degenerate_triangles'] or not stats['finite'] or stats['missing_uv']:errors.append('bore/mesh '+str(angle))
        rows.append(dict(angle=angle,interfaces=measurements,bores=bores,mesh_stats=stats))
    result=dict(passed=not errors,errors=errors,master_sha256=sha(root/'master.blend'),source_sha256=capture['source_sha256'],poses=rows,
        horizontal_axis_residual_native_pixels=-.36*math.sqrt(.5)*32+7-(-1),
        scope='Actual rim projection, seated receiving barrels, unchanged coaxial reducer vertices and .235-radius clear core samples. Whole-sprite +7-pixel placement and visible cap seating are independently native-viewed; owner acceptance is separate.')
    (root/'native-fitting-readback.json').write_text(json.dumps(result,indent=2)+'\n');print('CRUCIBLE_NATIVE_FITTING_GEOMETRY',not errors,errors,flush=True)


if __name__=='__main__':main()
