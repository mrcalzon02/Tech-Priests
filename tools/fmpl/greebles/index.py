#!/usr/bin/env python3
"""Blender 5+ object inventory; launched with original .blend as opened file."""
import argparse
import hashlib
import json
import sys
from pathlib import Path
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent

def sha256(path):
    h=hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda:stream.read(8*1024*1024), b""):
            h.update(chunk)
    return h.hexdigest()

def limits(corners):
    return {"min":[float(min(p[i] for p in corners)) for i in range(3)],
            "max":[float(max(p[i] for p in corners)) for i in range(3)]}

def describe(obj):
    entry={"name":obj.name,"type":obj.type,
           "collections":sorted(c.name for c in obj.users_collection),
           "status":"unreviewed-candidate","verified_native_port":False}
    if obj.type=="MESH":
        corners=[Vector(p) for p in obj.bound_box]
        entry.update({
            "mesh_name":obj.data.name,
            "vertices":len(obj.data.vertices),"faces":len(obj.data.polygons),
            "bounds_local":limits(corners),
            "bounds_world_at_source":limits([obj.matrix_world @ p for p in corners]),
            "source_matrix_world":[list(row) for row in obj.matrix_world],
            "materials":[slot.material.name if slot.material else None for slot in obj.material_slots],
            "style_tags":[],"design_role":None,"contact_sheet_review":"pending"
        })
    return entry

def main():
    args=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    parser=argparse.ArgumentParser()
    parser.add_argument("--out",required=True)
    a=parser.parse_args(args)
    source=Path(bpy.data.filepath).resolve()
    info=json.loads((HERE/"source.json").read_text(encoding="utf-8"))
    if not source.is_file() or source.stat().st_size!=info["payload_bytes"] or sha256(source)!=info["sha256"]:
        raise RuntimeError("Open the pinned Greebles.blend source with blender -b first")
    bpy.context.view_layer.update()
    report={"schema":"fmpl.greebles.object-index.v1","source_id":info["id"],
            "source_sha256":info["sha256"],"blender_version":list(bpy.app.version),
            "counts":{"objects":len(bpy.data.objects),"meshes":len(bpy.data.meshes),
                      "materials":len(bpy.data.materials)},
            "objects":[describe(x) for x in sorted(bpy.data.objects,key=lambda v:v.name.casefold())],
            "promotion_policy":"Visual and dimensional evidence required for every part."}
    output=Path(a.out).resolve()
    if output==source:raise ValueError("Refusing to overwrite donor .blend")
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print("FMPL_GREEBLES_INDEXED",str(output),report["counts"])

if __name__=="__main__":
    main()
