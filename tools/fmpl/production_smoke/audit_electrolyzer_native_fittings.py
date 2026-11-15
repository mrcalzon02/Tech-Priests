"""Reopen editable fitting master; measure all four actual posed mouths."""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Matrix,Vector
from bpy_extras.object_utils import world_to_camera_view

sys.path.insert(0,str(Path(__file__).resolve().parent))
from electrolyzer_native_fittings import NativeFittings
from audit_electrolyzer_v01 import port_probe,mesh_stats
from refine_purifier_v14 import sha
from verify_purifier_v14 import gap


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--capture',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);root=Path(args.capture).resolve()
    bpy.ops.wm.open_mainfile(filepath=str(root/'master.blend'))
    scene=bpy.data.scenes['RENDER'];bpy.context.window.scene=scene;scene.frame_set(0)
    fitting=NativeFittings(scene);pivot=scene.objects['EXPORT | direction pivot'];rows=[];errors=[]
    # Independent canonical native plane positions, from actual tested prototype.
    planes={'water_input':(0,2),'hydrogen_output':(-1.5,-.5),'oxygen_output':(1.5,-.5)}
    outward={'water_input':(0,-1,0),'hydrogen_output':(-1,0,0),'oxygen_output':(1,0,0)}
    for angle in (0,90,180,270):
        pivot.rotation_euler.z=math.radians(angle);pose=fitting.apply(angle);bpy.context.view_layer.update()
        rotation=Matrix.Rotation(math.radians(angle),3,'Z');ports=[];measures=[]
        for row in pose:
            role=row['role'];group=fitting.groups[role]
            throat=next(o for o in group if 'reusable machine throat' in o.name)
            normal=rotation @ Vector(outward[role])
            verts=[throat.matrix_world @ v.co for v in throat.data.vertices]
            end=max(v.dot(normal) for v in verts)
            rim=[v for v in verts if abs(v.dot(normal)-end)<1e-5]
            measured=sum(rim,Vector())/len(rim)
            coord=world_to_camera_view(scene,scene.camera,measured)
            # Capture pixel -> native sprite tile via the actual tested scale.
            projected=((coord.x-.5)*6.35, (.5-coord.y)*6.35-1.3*math.sqrt(.5))
            plane=Vector((planes[role][0],-planes[role][1],0));turned=rotation @ plane
            desired=(turned.x,-turned.y-.36*math.sqrt(.5))
            error=max(abs(projected[i]-desired[i]) for i in range(2))
            if error>.002:errors.append('actual rim projection '+str((angle,role,error)))
            ports.append(dict(id=role,model_mouth_center=list(measured),outward_normal=list(normal)))
            measures.append(dict(role=role,rim_vertices=len(rim),actual_mouth_center=list(measured),
                                 projected_native_tiles=list(projected),desired_native_tiles=list(desired),maximum_error_tiles=error))
        bores=port_probe(scene,ports,offsets=[k*.047 for k in range(-5,6)],max_radius=.235);stats=mesh_stats(scene)
        supports=[]
        for shoe in fitting.shoes:
            # Matching column uses authored pre-pose source X. Parent pivot
            # rotates both, so the surface contact is measured in world space.
            x=fitting.basis[shoe].translation.x
            column=next(o for o in scene.objects if 'red upright web' in o.name and abs(o.location.x-x)<.001 and abs(o.location.y-1)<.001)
            distance=gap(shoe,column);supports.append(dict(shoe=shoe.name,column=column.name,gap_tiles=distance,passed=distance<=.015))
        if any(not r['passed'] for r in supports):errors.append('rear column shoe contact '+str(angle))
        if not bores['passed']:errors.append('posed bore '+str(angle))
        if not stats['finite'] or stats['missing_uv'] or stats['degenerate_triangles']:errors.append('posed mesh '+str(angle))
        rows.append(dict(source_yaw=angle,mouths=measures,bores=bores,mesh_stats=stats,support_contacts=supports))
    report=dict(passed=not errors,errors=errors,master_sha256=sha(root/'master.blend'),poses=rows,
                scope='actual throat rim geometry, camera projection, rear shoe/column contact and denser .235-radius mouth rays per pose; native screenshot seating is a separate visual gate')
    (root/'native-fitting-readback.json').write_text(json.dumps(report,indent=2)+'\n')
    print('NATIVE_FITTING_POSES',not errors,errors,flush=True)


if __name__=='__main__':main()
