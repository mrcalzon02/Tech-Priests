#!/usr/bin/env python3
"""Independent native-library reopening and procedural/loop/render verification."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--catalog",required=True)
    ap.add_argument("--out",required=True)
    args=ap.parse_args(sys.argv[sys.argv.index("--")+1:])
    import bpy
    out=Path(args.out).resolve()
    data=json.loads(Path(args.catalog).read_text(encoding="utf-8"))
    receipt=json.loads((out/"library_report.json").read_text(encoding="utf-8"))
    native=out/receipt["native_file"]
    if not native.is_file() or sha(native)!=receipt["native_sha256"]:
        raise RuntimeError("Missing or altered native Blender library")
    bpy.ops.wm.open_mainfile(filepath=str(native))
    scene=bpy.context.scene
    if scene.get("fmpl_fx_registry_sha256")!=sha(args.catalog):
        raise RuntimeError("Library no longer matches pinned FMPL registry")
    if scene.get("fmpl_fx_source_pdf_sha256")!=data["source_guide"]["sha256"]:
        raise RuntimeError("Source provenance missing")
    camera=[o for o in scene.objects if o.type=="CAMERA"]
    if len(camera)!=1 or scene.camera!=camera[0] or scene.camera.data.type!="ORTHO":
        raise RuntimeError("Multiple or missing fixed preview camera")
    from mathutils import Vector
    target=Vector(scene["fmpl_camera_target"])
    direction=(scene.camera.location-target).normalized()
    elevation=math.degrees(math.asin(direction.z))
    if abs(elevation-45)>.002 or abs(direction.x)>.002:
        raise RuntimeError("Production preview camera no longer fixed at 45/0")
    found=[]
    for preset in data["presets"]:
        mat=bpy.data.materials.get("FMPL FX | "+preset["id"])
        if mat is None or mat.get("fmpl_effect_id")!=preset["id"]:
            raise RuntimeError("Missing independently reopened material: "+preset["id"])
        if mat.get("fmpl_effect_version")!=data["version"]:
            raise RuntimeError("Effect version stamp missing: "+preset["id"])
        if getattr(mat,"asset_data",None) is None:
            raise RuntimeError("Material was not marked a Blender asset: "+preset["id"])
        nodes=mat.node_tree.nodes
        for n in ("FMPL | Texture Coordinates","FMPL | Mapping","FMPL | Noise","FMPL | Master Scale"):
            if nodes.get(n) is None:raise RuntimeError("No shared procedural control "+preset["id"]+":"+n)
        found.append(preset["id"])
    if len(found)!=28 or receipt.get("material_ids")!=found:
        raise RuntimeError("Incorrect total/ordered material inventory")
    roots=[]
    for rig in data["rigs"]:
        col=bpy.data.collections.get("FMPL FX RIG | "+rig["id"])
        obj=bpy.data.objects.get("FMPL FX ROOT | "+rig["id"])
        if col is None or obj is None or obj.get("fmpl_effect_rig_id")!=rig["id"]:
            raise RuntimeError("Missing reusable emitter geometry: "+rig["id"])
        if len(obj.children)!=rig["count"]:
            raise RuntimeError("Missing emitted child geometry: "+rig["id"])
        if any(child.type!="MESH" for child in obj.children):
            raise RuntimeError("Emitter child not a real mesh: "+rig["id"])
        roots.append(obj)
    scene.frame_set(1)
    before={o.name:[list(o.location),list(o.rotation_euler),list(o.scale)] for root in roots for o in root.children}
    scene.frame_set(97)
    for root in roots:
        for obj in root.children:
            previous=before[obj.name]
            current=[list(obj.location),list(obj.rotation_euler),list(obj.scale)]
            if any(abs(a-b)>1e-4 for v,w in zip(previous,current) for a,b in zip(v,w)):
                raise RuntimeError("Emitter seam mismatch: "+obj.name)
    if not receipt["one_fixed_camera"] or receipt["simulation_bake"]:
        raise RuntimeError("Unsafe renderer/physics contract")
    frames=receipt["previews"]
    if len(frames)!=receipt["preview_count"]:
        raise RuntimeError("Invalid preview report")
    for row in frames:
        img=out/row["file"]
        if not img.is_file() or sha(img)!=row["sha256"] or img.stat().st_size<1024:
            raise RuntimeError("Missing or modified real rendered preview: "+str(img))
    report={"schema":"fmpl.effects.verify.v1","passed":True,
            "native_sha256":sha(native),"registry_sha256":sha(args.catalog),
            "material_assets_reopened":len(found),"rig_collections_reopened":len(roots),
            "loop_seam_verified":True,"one_fixed_45_camera_verified":True,
            "preview_images_verified":len(frames),"simulation_bake":False,
            "factorio_game_validation":False,"owner_visual_approved":False,
            "blender_version":bpy.app.version_string}
    path=out/"library_verify.json"
    if path.exists():raise FileExistsError("Refusing to overwrite verification")
    path.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print("FMPL_EFFECTS_INDEPENDENT_NATIVE_REOPEN_PASS",len(found),len(roots),len(frames),flush=True)

if __name__=="__main__":main()
