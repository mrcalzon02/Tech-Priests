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


def _add_preview_lighting(scene, lo, hi):
    """Temporary proof-only key/fill lighting; never saved to source .blend."""
    center=(lo+hi)/2
    span=max((hi-lo).x,(hi-lo).y,(hi-lo).z,.30)
    world=bpy.data.worlds.new("Pipette PROOF ambient")
    world.use_nodes=True
    bg=world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value=(.55,.60,.68,1.)
    bg.inputs["Strength"].default_value=.7
    scene.world=world
    for n,pos in enumerate(((-1.5,-1.7,1.9),(1.0,.7,1.3))):
        lamp=bpy.data.lights.new("Pipette PROOF area %d"%n,"AREA")
        lamp.energy=(480. if n==0 else 280.)*span*span
        lamp.shape="DISK"
        lamp.size=span*1.5
        ob=bpy.data.objects.new(lamp.name,lamp)
        scene.collection.objects.link(ob)
        ob.location=center+Vector(pos)*span
        ob.rotation_euler=(center-ob.location).to_track_quat("-Z","Y").to_euler()


def _lit_pixel_count(path):
    """Nonblack actual RGBA pixels; file existence is not visual proof."""
    import array
    img=bpy.data.images.load(str(path),check_existing=False)
    try:
        if tuple(img.size)!=(512,512) or img.channels!=4:
            raise RuntimeError("Native Pipette proof is not 512x512 RGBA")
        values=array.array("f",[0.])*(512*512*4)
        img.pixels.foreach_get(values)
        return sum(1 for i in range(0,len(values),4)
                   if values[i+3]>.2 and max(values[i:i+3])>.08)
    finally:
        bpy.data.images.remove(img)


def _verify_standard_ports(scene,objs,record):
    interfaces=record.get("standard_tile_interfaces") or {}
    if not interfaces:
        return {"count":0,"empty_bore_rays":0,"all_clear":True}
    scope=record.get("scene_scope")
    if not scope:
        raise RuntimeError("Standard fitting without explicit Blender-to-tile scene scope")
    u=float(scope["scene_units_per_tile"])
    rays=0
    for terminal,interface in interfaces.items():
        # The selected candidate count comes from exact source interface
        # and typed terminal mesh roles, not an inferred random neighbor.
        prefix=" | "+terminal+" factorio-fluid-interface-v1 "
        parts=[o for o in objs if prefix in o.name]
        roles={o.get("pipette_geometry_role") for o in parts}
        if roles!={"standard-open-throat","standard-collar","standard-port-hollow-reducer"}:
            raise RuntimeError("Canonical pipe has missing throat/collar/reducer at "+terminal)
        dimensions=interface["dimensions"]
        for role,field in (("standard-open-throat","barrel_outer_diameter_bu"),
                           ("standard-collar","mounting_collar_outer_diameter_bu")):
            obj=next(o for o in parts if o.get("pipette_geometry_role")==role)
            if abs(float(obj.get("pipette_outer_diameter_bu",0))-float(dimensions[field]))>1e-5:
                raise RuntimeError("Actual flange/throat OD differs from scoped reference")
            if not obj.get("pipette_true_hollow_mesh"):
                raise RuntimeError("Standard barrel or flange unexpectedly solid")
            if abs(float(obj.get("pipette_bore_diameter_bu",0))-
                   float(dimensions["open_bore_diameter_bu"]))>1e-5:
                raise RuntimeError("Canonical port bore does not match 0.49 tile fraction")
        p=Vector(interface["expected_xyz_bu"])
        normal=Vector(interface["outer_normal"])
        for y,z in ((0,0),(.10*u,0),(-.10*u,0),(0,.10*u),(0,-.10*u)):
            pos=p+normal*.09*u+Vector((0,y,z))
            direction=-normal
            for obj in objs:
                transform=obj.matrix_world.inverted_safe()
                local_origin=transform@pos
                local_direction=(transform.to_3x3()@direction).normalized()
                hit,_,_,_=obj.ray_cast(local_origin,local_direction,distance=.13*u)
                if hit:
                    raise RuntimeError("Rendered geometry blocks protected external pipe bore: "+
                                       obj.name+" "+terminal)
            rays+=1
    return {"count":len(interfaces),"empty_bore_rays":rays,"all_clear":True}


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
    standard_port_proof=_verify_standard_ports(scene,objs,record)
    original_cam_count=len([o for o in scene.objects if o.type=="CAMERA"])
    lo,hi=bounds(objs)
    make_camera(scene,lo,hi)
    _add_preview_lighting(scene,lo,hi)
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
    lit_pixels=_lit_pixel_count(proof)
    if lit_pixels<120:
        raise RuntimeError("Pipette Cycles screenshot is too dark or missing visible meshes")
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
        "actual_lit_preview_pixels":lit_pixels,
        "meshes_saved":len(objs),
        "glb_meshes_reimported":len(imported),
        "hollow_shell_meshes":len(hollow),
        "tile_scoped_standard_pipe":standard_port_proof,
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
