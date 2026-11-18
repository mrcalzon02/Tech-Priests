"""Independently measure retargeted leaf-flex ownership and actual end seats."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector
import numpy as np

p=argparse.ArgumentParser()
p.add_argument("--baseline",type=Path,required=True)
p.add_argument("--source",type=Path,required=True)
p.add_argument("--motion",type=Path,required=True)
p.add_argument("--base-manifest",type=Path,required=True)
p.add_argument("--out",type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index("--")+1:])
for k in("baseline","source","motion","base_manifest","out"):setattr(a,k,getattr(a,k).resolve())
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
pins={k:sha(getattr(a,k))for k in("baseline","source","motion","base_manifest")}
motion=json.loads(a.motion.read_text(encoding="utf-8"))
base=json.loads(a.base_manifest.read_text(encoding="utf-8"))
jobs=base["leaf_regenerative_cooling"]["flex_links"]
assert len(jobs)==24


def world_vertices(obj,depsgraph):
    evaluated=obj.evaluated_get(depsgraph);me=evaluated.to_mesh()
    array=np.empty(len(me.vertices)*3,dtype=np.float32);me.vertices.foreach_get("co",array)
    matrix=np.asarray(obj.matrix_world,dtype=np.float64)
    result=array.reshape(-1,3).astype(np.float64)@matrix[:3,:3].T+matrix[:3,3]
    evaluated.to_mesh_clear();return result


bpy.ops.wm.open_mainfile(filepath=str(a.baseline));old={}
for frame in range(66):
    bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
    old[frame]={j["mesh"]:world_vertices(bpy.data.objects[j["mesh"]],dg)for j in jobs}
bpy.ops.wm.open_mainfile(filepath=str(a.source))
core=bpy.data.objects[motion["moving_root"]]
rest_inv=Matrix(motion["poses"][0]["baseline_core_world"]).inverted()
rows=[];first={};wrap_error=0
for frame in range(66):
    bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
    expected_delta=core.matrix_world@Matrix(motion["poses"][frame]["baseline_core_world"]).inverted()
    matrix=np.asarray(expected_delta,dtype=np.float64)
    for j in jobs:
        name=j["mesh"];actual=world_vertices(bpy.data.objects[name],dg)
        expected=old[frame][name]@matrix[:3,:3].T+matrix[:3,3]
        mesh_error=float(np.max(np.linalg.norm(actual-expected,axis=1)))
        sides=j["ring_sides"];rings=j["rings"]
        start=actual[:sides].mean(axis=0);end=actual[(rings-1)*sides:rings*sides].mean(axis=0)
        target_start=core.matrix_world@rest_inv@Vector(j["root_rest"])
        target_end=bpy.data.objects[j["leaf"]].matrix_world@Vector(j["end_local"])
        start_gap=float(np.linalg.norm(start-np.asarray(target_start)));end_gap=float(np.linalg.norm(end-np.asarray(target_end)))
        assert mesh_error<1e-5,("World-baked ownership mismatch",frame,name,mesh_error)
        assert max(start_gap,end_gap)<2e-5,("Actual leaf-flex end detached",frame,name,start_gap,end_gap)
        rows.append({"frame":frame,"mesh":name,"all_vertices_expected_world_max_error":mesh_error,
                     "actual_core_port_center_gap":start_gap,"actual_leaf_port_center_gap":end_gap})
        if frame==1:first[name]=actual.copy()
        if frame==65:wrap_error=max(wrap_error,float(np.max(np.linalg.norm(actual-first[name],axis=1))))
assert wrap_error<1e-6
for k,value in pins.items():assert sha(getattr(a,k))==value
result={"status":"PASS_24_CORE_OWNED_FLEXES_66POSES_ACTUAL_WORLD_GEOMETRY_AND_ENDPOINTS",
        "input_sha256":pins,"script_sha256":sha(Path(__file__)),"measured_mesh_poses":len(rows),
        "maximum_world_geometry_error":max(r["all_vertices_expected_world_max_error"]for r in rows),
        "maximum_actual_endpoint_gap":max(max(r["actual_core_port_center_gap"],r["actual_leaf_port_center_gap"])for r in rows),
        "working_wrap_max_world_error":wrap_error,"measurements":rows,
        "scope":"Actual evaluated retargeted mesh points and actual core/leaf socket centers. Does not certify remaining interfaces, giant side pistons, overall swept clearance or native runtime."}
a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
print(result["status"],result["maximum_world_geometry_error"],result["maximum_actual_endpoint_gap"],flush=True)
