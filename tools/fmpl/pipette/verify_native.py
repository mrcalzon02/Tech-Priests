#!/usr/bin/env python3
"""Independent Blender/GLB readback and REAL Cycles preview for Pipette pilots.

Runs in a separate Blender invocation from the builder. All previews are
preview-material only and not approved Factorio production assets.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector


def sha(p):
    h=hashlib.sha256()
    with open(p,"rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):
            h.update(chunk)
    return h.hexdigest()


def bounds(objs):
    bpy.context.view_layer.update()
    pts=[ob.matrix_world@Vector(point)
         for ob in objs for point in ob.bound_box]
    if not pts:
        raise RuntimeError("No actual mesh bounds in Blender")
    lo=Vector((min(p[i] for p in pts) for i in range(3)))
    hi=Vector((max(p[i] for p in pts) for i in range(3)))
    return lo,hi


def make_camera(scene,lo,hi):
    center=(lo+hi)/2
    span=max((hi-lo).x,(hi-lo).y,(hi-lo).z,.30)
    cam=bpy.data.cameras.new("Pipette proof-only orthographic camera")
    obj=bpy.data.objects.new("Pipette proof-only camera",cam)
    scene.collection.objects.link(obj)
    obj.location=center+Vector((0.,-1.7*span,1.7*span))
    direction=center-obj.location
    obj.rotation_euler=direction.to_track_quat("-Z","Y").to_euler()
    cam.type="ORTHO"
    cam.ortho_scale=max(.66,span*2.0)
    scene.camera=obj
    return obj


def main():
    parser=argparse.ArgumentParser()
    for name in ("blend","glb","build-receipt","preview","report"):
        parser.add_argument("--"+name,required=True)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    files={n:Path(getattr(args,n.replace("-","_"))).resolve()
           for n in ("blend","glb","build-receipt")}
    output=Path(args.report).resolve()
    proof=Path(args.preview).resolve()
    if any(p.exists() for p in (output,proof)):
        raise FileExistsError("Pipette proof and readback must not overwrite prior result")
    record=json.loads(files["build-receipt"].read_text(encoding="utf-8-sig"))
    if sha(files["blend"])!=record["native_blend_sha256"] or \
       sha(files["glb"])!=record["exported_glb_sha256"]:
        raise RuntimeError("Pipette native files do not match builder hashes")
    bpy.ops.wm.open_mainfile(filepath=str(files["blend"]))
    scene=bpy.context.scene
    objs=[o for o in scene.objects if o.type=="MESH" and
          o.get("pipette_route_id")==record["route_id"]]
    if len(objs)!=record["geometric_meshes_constructed"]:
        raise RuntimeError("Missing real Pipette geometry in saved .blend")
    for ob in objs:
        if len(ob.data.vertices)<8 or len(ob.data.polygons)<4:
            raise RuntimeError("Pipette geometry degenerate: "+ob.name)
        if not ob.get("pipette_blender_units_only"):
            raise RuntimeError("Missing Blender-unit sizing provenance")
    hollow=[o for o in objs if o.get("pipette_true_hollow_mesh")]
    if record["family"] in {"rigid_pipe","segmented_conduit","flex_hose","conduit"} and not hollow:
        raise RuntimeError("Expected actual hollow shell geometry")
    if record["family"]=="wire_bundle" and record["route_id"]=="wire-loom-eight-sample":
        cores=[o for o in objs if o.get("pipette_geometry_role")=="visible-conductor"]
        if len(cores)!=8:
            raise RuntimeError("Eight visible pilot conductors were not authored")
    original_cam_count=len([o for o in scene.objects if o.type=="CAMERA"])
    lo,hi=bounds(objs)
    make_camera(scene,lo,hi)
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=12
    scene.render.resolution_x=512
    scene.render.resolution_y=512
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.film_transparent=True
    scene.render.threads_mode="FIXED"
    scene.render.threads=4
    proof.parent.mkdir(parents=True,exist_ok=True)
    scene.render.filepath=str(proof)
    bpy.ops.render.render(write_still=True)
    if not proof.exists() or proof.stat().st_size<2000:
        raise RuntimeError("Genuine Blender Cycles Pipette screenshot absent")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(files["glb"]))
    imported=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    if len(imported)<len(objs):
        raise RuntimeError("GLB roundtrip dropped Pipette mesh")
    result={
        "schema":"fmpl.pipette.native-proof.v0.1",
        "passed":True,
        "route_id":record["route_id"],
        "source_blend_sha256":record.get("source_blend_sha256"),
        "editable_blend_sha256":sha(files["blend"]),
        "glb_sha256":sha(files["glb"]),
        "genuine_cycles_render_sha256":sha(proof),
        "meshes_saved":len(objs),
        "glb_meshes_reimported":len(imported),
        "hollow_shell_meshes":len(hollow),
        "original_cameras_in_saved_source":original_cam_count,
        "visual_gauge_units":"Blender only; no real-world conversion",
        "preview_not_production":bool(record["preview_material_only"]),
        "source_mat_approval":False,
        "owner_visual_approval":False,
        "factorio_game_integration":False
    }
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print("FMPL_PIPETTE_NATIVE_REOPEN_PASS "+json.dumps({
        "route":result["route_id"],
        "meshes":result["meshes_saved"],
        "glb":result["glb_meshes_reimported"],
        "hollow":result["hollow_shell_meshes"]
    }),flush=True)


if __name__=="__main__":
    main()
