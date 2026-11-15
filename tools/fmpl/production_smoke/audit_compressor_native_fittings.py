"""Read actual rim geometry and posed bores in the native fitting master."""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Matrix,Vector
from bpy_extras.object_utils import world_to_camera_view

sys.path.insert(0,str(Path(__file__).resolve().parent))
from compressor_native_fittings import CompressorNativeFittings
from audit_electrolyzer_v01 import port_probe,mesh_stats
from refine_purifier_v14 import sha


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--capture',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);root=Path(args.capture).resolve()
    bpy.ops.wm.open_mainfile(filepath=str(root/'master.blend'));s=bpy.data.scenes['RENDER'];bpy.context.window.scene=s;s.frame_set(0)
    fit=CompressorNativeFittings(s);pivot=s.objects['EXPORT | direction pivot'];rows=[];errors=[]
    for angle in (0,90,180,270):
        pivot.rotation_euler.z=math.radians(angle);pose=fit.apply(angle);bpy.context.view_layer.update();rotation=Matrix.Rotation(math.radians(angle),3,'Z')
        ports=[];measurements=[]
        for row in pose:
            role=row['role'];center=Vector(fit.PORTS[role][0]);normal=rotation @ Vector((-1,0,0) if center.x<0 else (1,0,0))
            throat=next(o for o in fit.groups[role] if 'reusable machine throat' in o.name)
            vertices=[throat.matrix_world @ v.co for v in throat.data.vertices];end=max(v.dot(normal) for v in vertices)
            rim=[v for v in vertices if abs(v.dot(normal)-end)<1e-5];actual=sum(rim,Vector())/len(rim)
            projected=world_to_camera_view(s,s.camera,actual)
            tiles=((projected.x-.5)*6.1,(.5-projected.y)*6.1-.82*math.sqrt(.5));canonical=rotation @ center
            desired=(canonical.x,-canonical.y-.36*math.sqrt(.5));error=max(abs(a-b) for a,b in zip(tiles,desired))
            if error>.002:errors.append('rim projection '+str((angle,role,error)))
            measurements.append(dict(role=role,actual_mouth_center=list(actual),projected_native_tiles=tiles,desired_before_whole_sprite_shift=desired,error_tiles=error))
            ports.append(dict(id=role,model_mouth_center=list(actual),outward_normal=list(normal)))
        bores=port_probe(s,ports,offsets=[k*.047 for k in range(-5,6)],max_radius=.235);stats=mesh_stats(s)
        if not bores['passed']:errors.append('mouth obstruction '+str(angle))
        if stats['degenerate_triangles'] or not stats['finite'] or stats['missing_uv']:errors.append('mesh validity '+str(angle))
        rows.append(dict(angle=angle,mouths=measurements,bores=bores,mesh_stats=stats))
    result=dict(passed=not errors,errors=errors,master_sha256=sha(root/'master.blend'),poses=rows,
        scope='Measured real throat rims, camera mapping and .235-radius bore samples. Native whole-sprite offset and visible pipe occlusion require separate actual screenshots; numerical geometry is not visual approval.')
    (root/'native-fitting-readback.json').write_text(json.dumps(result,indent=2)+'\n');print('COMPRESSOR_FITTING_GEOMETRY',not errors,errors,flush=True)
    if errors:raise RuntimeError('Actual posed fitting failure')


if __name__=='__main__':main()
