#!/usr/bin/env python3
"""Fresh Blender process verifies the genuine surfaces library and proof."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--catalog",required=True)
    ap.add_argument("--out",required=True)
    args=ap.parse_args(sys.argv[sys.argv.index("--")+1:])
    import bpy
    from mathutils import Vector
    out=Path(args.out).resolve()
    catalog=Path(args.catalog).resolve()
    manifest=json.loads(catalog.read_text(encoding="utf-8"))
    report=json.loads((out/"surface_report.json").read_text(encoding="utf-8"))
    master=out/report["native_file"]
    if not master.is_file() or sha(master)!=report["native_sha256"]:
        raise RuntimeError("Native surfaces source missing or altered")
    proof=out/report["proof_file"]
    if not proof.is_file() or sha(proof)!=report["proof_sha256"]:
        raise RuntimeError("Real material proof missing or changed")
    bpy.ops.wm.open_mainfile(filepath=str(master))
    scene=bpy.context.scene
    if scene["fmpl_surface_catalog_sha256"]!=sha(catalog):
        raise RuntimeError("Native surface registry source receipt differs")
    cameras=[o for o in scene.objects if o.type=="CAMERA"]
    if len(cameras)!=1 or scene.camera!=cameras[0] or scene.camera.data.type!="ORTHO":
        raise RuntimeError("One-camera policy failed")
    target=Vector(scene["fmpl_surface_camera_target"])
    direct=(scene.camera.location-target).normalized()
    if abs(math.degrees(math.asin(direct.z))-45)>.001 or abs(direct.x)>.001:
        raise RuntimeError("Factorio 45 fixed camera orientation failed")
    expected=[p["id"] for p in manifest["presets"]]
    if expected!=report["surface_ids"] or len(expected)!=25:
        raise RuntimeError("Wrong material registry order")
    for row in manifest["presets"]:
        ident=row["id"]
        material=bpy.data.materials.get("FMPL SURFACE | "+ident)
        plate=bpy.data.objects.get("FMPL PLATE | "+ident)
        if material is None or material.get("fmpl_surface_id")!=ident:
            raise RuntimeError("Missing native Blender procedural material: "+ident)
        if material.get("fmpl_surface_version")!=manifest["version"] or getattr(material,"asset_data",None) is None:
            raise RuntimeError("Material asset has invalid version/provenance: "+ident)
        if not plate or plate.type!="MESH" or plate.get("fmpl_surface_plate_id")!=ident:
            raise RuntimeError("Missing rendered test mesh for "+ident)
        nodes=material.node_tree.nodes
        for name in ("FMPL | Object Coordinates","FMPL | Object Mapping","FMPL | Color Variation","FMPL | Grain Frequency"):
            if not nodes.get(name):
                raise RuntimeError("Missing explicit mapped procedural graph "+ident+":"+name)
        if ident=="dried-cracked-mud-rocks":
            for name in ("FMPL CRACKS | Distances To Edge","FMPL CRACKS | Width & Dark Interior",
                         "FMPL ROCKS | Stone Coverage Mask","FMPL ROCKS | Mud/Embedded Rock Pigment",
                         "FMPL ROCKS | Raised Rock Bump"):
                if not nodes.get(name):
                    raise RuntimeError("Sam Bowman technique-stage component missing: "+name)
    result={"schema":"fmpl.surface-verify.v1","passed":True,
            "material_assets_verified":25,"camera_45_verified":True,
            "cracked_rock_mud_procedural_layers_verified":True,
            "proof_sha256":sha(proof),"native_sha256":sha(master),
            "source_sha256":sha(catalog),"blender":bpy.app.version_string,
            "simulation_bake":False,"owner_visual_approval":False}
    target=out/"surface_verify.json"
    if target.exists():raise FileExistsError("Verification receipt already exists")
    target.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print("FMPL_SURFACES_INDEPENDENT_NATIVE_REOPEN_PASS",len(expected),flush=True)

if __name__=="__main__":
    main()
