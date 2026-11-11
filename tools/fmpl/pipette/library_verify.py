#!/usr/bin/env python3
"""Independent Pipette V1 architecture .blend / GLB / Cycles proof validator.

Run in a SEPARATE Blender 5.2 process from library_blender.py; no model edits.
The proof validates native geometry, port data, preview pixels and provenance,
not structural ratings, game fluid boxes, pressure, or electrical simulation.
"""
from __future__ import annotations

import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import library_geometry as lib


def sha256(path):
    h=hashlib.sha256()
    with open(path,"rb") as f:
        for part in iter(lambda:f.read(1024*1024),b""):
            h.update(part)
    return h.hexdigest()


def pixels(path):
    img=bpy.data.images.load(str(path),check_existing=False)
    try:
        if img.channels!=4 or img.size[0]<400 or img.size[1]<400:
            raise RuntimeError("Native proof missing RGBA preview pixels")
        size=img.size[0]*img.size[1]*4
        vals=array.array("f",[0.])*size
        img.pixels.foreach_get(vals)
        # Count lit *opaque* points; transparent background does not pass.
        count=0
        for i in range(0,len(vals),4):
            if vals[i+3]>.2 and max(vals[i:i+3])>.09:
                count+=1
        if count < 150:
            raise RuntimeError("Cycles proof has no actually visible object")
        return count
    finally:
        bpy.data.images.remove(img)


def validate(args):
    receipt=json.loads(Path(args.build_receipt).read_text(encoding="utf-8"))
    if not receipt.get("native_blender_generated") or \
       not receipt.get("native_glb_generated") or \
       not receipt.get("real_cycles_render_generated"):
        raise RuntimeError("Missing real native generation receipts")
    for suffix,key in (("blend",args.blend),("glb",args.glb),
                       ("preview_png",args.preview)):
        artifact=receipt["outputs"][suffix]
        if sha256(key)!=artifact["sha256"]:
            raise RuntimeError("Native source/proof hash mismatch: "+suffix)
    original=lib.source_json("comparison_fixture.v1.json")
    topology=receipt["topology"]
    expected_ports=original["topologies"][topology]["ports"]
    if receipt["public_ports"]!=expected_ports:
        raise RuntimeError("Receipt contains modified reference port coordinates")
    bpy.ops.wm.open_mainfile(filepath=str(Path(args.blend).resolve()))
    collections=[c for c in bpy.data.collections
                 if c.name.startswith("PIPETTE | architecture | ")]
    if len(collections)!=1:
        raise RuntimeError("Expected one isolated native architecture collection")
    col=collections[0]
    actual_ports=json.loads(col["pipette_public_ports_json"])
    if actual_ports!=expected_ports:
        raise RuntimeError("Blender port XYZ/normal differs from comparison fixture")
    objects=[o for o in col.objects if o.type=="MESH"]
    if not objects:
        raise RuntimeError("Native file has no mesh objects")
    if len(objects)!=receipt["mesh_count"]:
        raise RuntimeError("Native object count differs from builder receipt")
    for ob in objects:
        if len(ob.data.vertices)==0 or len(ob.data.polygons)==0:
            raise RuntimeError("Native object mesh is empty: "+ob.name)
        if not ob.get("pipette_preview_only",False) and receipt["approved_materials"] is False:
            # Boolean manifold is preview-only too, despite different role.
            if not ob.get("pipette_visual_candidate_not_game_validated",False):
                raise RuntimeError("Unapproved native mesh lost visual status")
    if receipt["requires_native_csg_manifold"]:
        booleans=[ob for ob in objects
                  if ob.get("pipette_native_boolean_bore_constructed",False)]
        if len(booleans)!=1 or len(booleans[0].data.polygons)<100:
            raise RuntimeError("Missing genuine native hollow CSG manifold")
        # A Boolean modifier applying without error is NOT proof of a joined
        # pipe. The previous pilot produced a disconnected visual Y because
        # cylinder transform_apply rotated already selected manifold geometry.
        # Demand real surface coverage along every public branch (not rings).
        manifold=booleans[0]
        hub=Vector(receipt["junctions"][0]["xyz_bu"])
        verts=[manifold.matrix_world @ v.co for v in manifold.data.vertices]
        if not verts:
            raise RuntimeError("CSG manifold has no vertices")
        od=float(receipt["nominal_outer_diameter_bu"])
        for port in expected_ports:
            q=Vector(port["xyz_bu"])
            for t in (.12,.30,.50,.70,.88):
                probe=hub.lerp(q,t)
                gap=min((v-probe).length for v in verts)
                if gap>od*.92:
                    raise RuntimeError(
                        "Disconnected CSG pipe branch: %s at %.2f gap %.4f BU"
                        %(port["id"],t,gap))
        # The bounds must contain geometry on both sides of central Y hub.
        if not (min(v.x for v in verts)<hub.x-.5 and
                max(v.x for v in verts)>hub.x+.5):
            raise RuntimeError("CSG Y misses one or more branch directions")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(Path(args.glb).resolve()))
    glbmeshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    if len(glbmeshes)<receipt["mesh_count"]:
        raise RuntimeError("GLB reimport lost one or more native meshes")
    count=pixels(args.preview)
    result={
        "schema":"fmpl.pipette.architecture-native-proof.v1",
        "passed":True,
        "architecture_id":receipt["architecture_id"],
        "topology":topology,
        "reference_ports_identical":True,
        "independent_blend_reopened":True,
        "independent_glb_reimported":True,
        "native_mesh_count":len(objects),
        "glb_mesh_count":len(glbmeshes),
        "lit_cycles_preview_pixels":count,
        "genuine_blend_sha256":sha256(args.blend),
        "glb_sha256":sha256(args.glb),
        "cycles_preview_sha256":sha256(args.preview),
        "csg_manifold_native_verified":bool(receipt["requires_native_csg_manifold"]),
        "approved_materials":receipt["approved_materials"],
        "game_native_verified":False,
        "owner_visual_approval":False
    }
    target=Path(args.out_report)
    if target.exists():
        raise FileExistsError("No overwriting native readback")
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print("FMPL_PIPETTE_ARCH_NATIVE_REOPEN_PASS",
          result["architecture_id"],result["topology"],
          result["native_mesh_count"],result["glb_mesh_count"],count)


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--blend",required=True)
    ap.add_argument("--glb",required=True)
    ap.add_argument("--preview",required=True)
    ap.add_argument("--build-receipt",required=True)
    ap.add_argument("--out-report",required=True)
    args=ap.parse_args(sys.argv[sys.argv.index("--")+1:])
    validate(args)


if __name__=="__main__":
    main()
