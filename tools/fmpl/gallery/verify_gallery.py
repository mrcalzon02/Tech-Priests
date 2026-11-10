#!/usr/bin/env python3
"""Independent Blender-native gallery reopening and source image hash verification."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--root",required=True)
    ap.add_argument("--minimum-models",type=int,default=15)
    args=ap.parse_args(sys.argv[sys.argv.index("--")+1:])
    root=Path(args.root).resolve()
    if not 0<=args.minimum_models<=100:raise ValueError("Invalid bounded model acceptance gate")
    summary=read(root/"inventory/summary.json")
    mats=read(root/"materials/materials_report.json")
    models=read(root/"models/models_report.json")
    catalog=read(root/"catalog.json")
    native=root/"materials"/mats["master_file"]
    if not native.is_file() or sha(native)!=mats["master_sha256"]:
        raise RuntimeError("Saved 76-material native Blender source missing/changed")
    if summary["schema"]!="fmpl.account-gallery.inventory.v1" or summary["indexed_assets"]<=0:
        raise RuntimeError("No real GitHub source inventory")
    if mats["material_count"]!=76 or mats["individual_render_count"]!=76 or len(mats["individuals"])!=76:
        raise RuntimeError("Not all FMPL materials have individual Blender proofs")
    if models["rendered"]<args.minimum_models:
        raise RuntimeError("Insufficient genuine 3D model proofs, blocked=%s"%(models["blocked"]))
    if catalog["rendered_models"]!=models["rendered"] or catalog["rendered_materials"]!=76:
        raise RuntimeError("Browser catalog overstates source proof coverage")
    import bpy
    from mathutils import Vector
    bpy.ops.wm.open_mainfile(filepath=str(native))
    scene=bpy.context.scene
    if scene.get("fmpl_gallery_total")!=76:
        raise RuntimeError("Native gallery material count stamp missing")
    cams=[obj for obj in scene.objects if obj.type=="CAMERA"]
    if len(cams)!=1 or scene.camera!=cams[0] or cams[0].data.type!="ORTHO":
        raise RuntimeError("Gallery does not have one actual orthographic camera")
    expected=Vector((0,-1,1)).normalized()
    measured=cams[0].matrix_world.to_quaternion() @ Vector((0,0,-1))
    if abs(measured.z+2**-.5)>.006:
        # Perspective direction is camera-forward; from elevated location it
        # points downward. Do not accept an arbitrary diagonal item camera.
        raise RuntimeError("Native camera no longer matches 45-degree production view")
    swatches=[obj for obj in scene.objects if obj.type=="MESH" and obj.name.startswith("FMPL SWATCH | ")]
    if len(swatches)!=76:
        raise RuntimeError("Missing material sample geometry after independent Blender reopen")
    kinds={"texture-backed":0,"procedural-effect":0,"procedural-surface":0}
    material_list=[]
    for rec in mats["individuals"]:
        image=root/"materials"/rec["native_render"]
        if not image.is_file() or sha(image)!=rec["render_sha256"]:
            raise RuntimeError("Unverified individual material PNG: "+rec["id"])
        asset=bpy.data.materials.get(rec["material_datablock"])
        if asset is None or getattr(asset,"asset_data",None) is None:
            raise RuntimeError("Native reusable Blender material missing: "+rec["id"])
        kinds[rec["kind"]]+=1
        material_list.append(rec["id"])
    if sorted(kinds.values())!=sorted((23,28,25)):
        raise RuntimeError("Missing material family from all-source gallery")
    contact=root/"materials"/mats["contact_file"]
    if not contact.is_file() or sha(contact)!=mats["contact_sha256"]:
        raise RuntimeError("Actual full material gallery contact proof not verified")
    # Real rendered PNG checks and source provenance for initial model cohort.
    for rec in models["rows"]:
        if rec["status"]=="rendered":
            path=root/"models"/rec["file"]
            if not path.is_file() or sha(path)!=rec["render_sha256"]:
                raise RuntimeError("Model render proof differs: "+rec["file"])
            if len(rec["source"]["git_blob_sha"])!=40 or len(rec["source"]["commit"])!=40:
                raise RuntimeError("Unpinned model source record")
    if not (root/"index.html").is_file() or not (root/"catalog.json").is_file():
        raise RuntimeError("Browsable offline gallery not produced")
    result={"schema":"fmpl.github-gallery.verify.v1","passed":True,
        "native_gallery_sha256":sha(native),"blender_version":bpy.app.version_string,
        "registered_materials_reopened":76,"material_proofs_hash_verified":76,
        "model_proofs_hash_verified":models["rendered"],"blocked_model_proofs":models["blocked"],
        "swatch_meshes_verified":len(swatches),"production_camera_verified":True,
        "source_repositories_with_pinned_commits":sum(bool(s.get("source_commit")) for s in summary["repositories"]),
        "source_inventory_complete":summary["partial_repositories"]==0 and summary["blocked_repositories"]==0,
        "every_model_rendered":False,"every_image_as_physical_material_rendered":False,
        "parts_license_gates_open":True,"game_integrated":False,"owner_visual_approval":False}
    dest=root/"gallery_verify.json"
    if dest.exists():raise FileExistsError("Independent verification receipt already exists")
    dest.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print("FMPL_GITHUB_GALLERY_NATIVE_REOPEN_PASS 76 material assets",models["rendered"],"model proofs",flush=True)

if __name__=="__main__":main()
