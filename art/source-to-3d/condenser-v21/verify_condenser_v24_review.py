"""Reopen both scenes and verify V24 changes only the intake effects."""
import argparse,hashlib,json,sys
from pathlib import Path
import bpy

def snapshot(path):
    bpy.ops.wm.open_mainfile(filepath=str(path))
    s=bpy.context.scene
    objects=[o for o in s.objects if o.type=='MESH' and not o.get('FX_ONLY_INWARD_ATMOSPHERIC_INTAKE')]
    geometry={o.name:hashlib.sha256(repr(([tuple(v.co) for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons])).encode()).hexdigest() for o in objects}
    materials={o.name:[m.name if m else None for m in o.data.materials] for o in objects}
    matrices={}
    for f in range(1,98):
        s.frame_set(f);bpy.context.view_layer.update()
        matrices[f]={o.name:[v for row in o.matrix_world for v in row] for o in objects}
    return geometry,materials,matrices

def run(source,candidate,out):
    old,oldmat,om=snapshot(source)
    new,newmat,nm=snapshot(candidate)
    assert old==new,'Hardware mesh geometry changed'
    assert oldmat==newmat,'Hardware material assignments changed'
    maxerr=max(abs(x-y) for f in om for n in old for x,y in zip(om[f][n],nm[f][n]))
    assert maxerr<1e-5,'Hardware animation changed'
    s=bpy.context.scene
    assert (s.frame_start,s.frame_end,s.render.fps)==(1,96,8)
    clouds=[o for o in s.objects if o.get('FX_ONLY_INWARD_ATMOSPHERIC_INTAKE')]
    assert len(clouds)==40
    assert len({o.data.materials[0].name for o in clouds})==40
    for cloud in clouds:
        aim=cloud.constraints.get('V24 stretch axis points into inlet')
        assert aim and aim.track_axis=='TRACK_X' and aim.lock_axis=='LOCK_Z'
        assert max(abs(x-y) for x,y in zip(aim.target.location,cloud['fx_destination']))<1e-6
    s.frame_set(1)
    start={o.name:(tuple(o.location),tuple(o.scale)) for o in clouds}
    s.frame_set(97)
    end={o.name:(tuple(o.location),tuple(o.scale)) for o in clouds}
    assert start==end,'Mist transform loop seam'
    result={'result':'PASS','hardware_meshes':len(old),'modified_hardware_meshes':0,'hardware_material_assignments_unchanged':True,'frames_verified':97,'max_hardware_world_matrix_error':maxerr,'mist_particles':40,'distinct_mist_materials':40,'inlet_aim_constraints_verified':40,'mist_transform_loop_seam':'PASS','cycle_seconds':12,'owner_visual_approval':'PENDING','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'candidate_sha256':hashlib.sha256(candidate.read_bytes()).hexdigest()}
    out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(result,indent=2));print(json.dumps(result))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--candidate',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
    a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);run(a.source.resolve(),a.candidate.resolve(),a.out.resolve())
