#!/usr/bin/env python3
"""One-shot standalone Pipette library mesh build for currently implemented recipes.

Pure Python and no Blender installation required; outputs actual editable OBJ
geometry plus per-entry receipts. Native Blender and Cycles are an additional
independent acceptance gate; never mistake OBJ generation for visual approval.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

import library_geometry as lib

DEFAULT_TOPOLOGY="straight"
SHOWCASE=(("pipe_lead_historical","wye"),
          ("wire_eight_loose_bundle","wye"),
          ("conduit_fmc_interlocked","straight"),
          ("conduit_ent_corrugated","straight"),
          ("conduit_helical_plastic_wrap","straight"),
          ("conduit_split_corrugated_loom","straight"),
          ("hose_metal_annular","straight"),
          ("hose_metal_helical","straight"))


def sha256(path):
    h=hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b""):
            h.update(chunk)
    return h.hexdigest()


def build(root, architecture_ids=None, *, showcase=True):
    root=Path(root).resolve()
    if root.exists():
        raise FileExistsError("Pipette build refuses to overwrite ANY existing target")
    chosen=sorted(lib.RECIPES) if architecture_ids is None else list(architecture_ids)
    if not chosen or len(chosen)!=len(set(chosen)):
        raise ValueError("Select a nonempty unique list of recipes")
    if any(x not in lib.RECIPES for x in chosen):
        raise ValueError("An architecture is not implemented yet")
    plans=[(a,DEFAULT_TOPOLOGY) for a in chosen]
    if showcase:
        plans.extend((a,t) for a,t in SHOWCASE if a in chosen and t!="straight")
    # Validate every fixture and native-manifold requirement BEFORE mkdir/write.
    ready=[]
    for architecture,topology in plans:
        m=lib.build_demo(architecture,topology)
        if len(m["meshes"])<=0:
            raise RuntimeError("Geometry builder produced empty assembly")
        ready.append((architecture,topology,m))
    root.mkdir(parents=True)
    built=[]
    for architecture,topology,model in ready:
        name=architecture+"__"+topology
        file=root/(name+".obj")
        lib.export_obj(model,file)
        record={
            "architecture_id":architecture,"topology":topology,
            "source_fixture":"comparison_fixture.v1.json",
            "obj_filename":file.name,"obj_sha256":sha256(file),
            "public_ports":model["public_ports"],
            "mesh_count":len(model["meshes"]),
            "vertex_count":sum(len(x["vertices"]) for x in model["meshes"]),
            "face_count":sum(len(x["faces"]) for x in model["meshes"]),
            "needs_blender_manifold_csg":model["requires_native_csg_manifold"],
            "preview_only":True,
            "native_blender_verified":False,
            "factorio_connected":False
        }
        (root/(name+".json")).write_text(json.dumps(record,indent=2)+"\n",
                                          encoding="utf-8")
        built.append(record)
    result={
        "schema":"fmpl.pipette.library-export.v1",
        "status":"obj_geometry_complete_blender_and_material_gates_pending",
        "units":"Blender scene units; no real-world mm/AWG conversion",
        "implemented_recipe_count":len(chosen),
        "model_count":len(built),
        "fixed_reference_port_geometry":True,
        "models":built
    }
    (root/"manifest.json").write_text(json.dumps(result,indent=2)+"\n",
                                       encoding="utf-8")
    return result


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--output",required=True,help="new EMPTY destination path; never overwrite")
    ap.add_argument("--architecture",action="append",dest="architectures",
                    choices=sorted(lib.RECIPES))
    ap.add_argument("--no-showcase",action="store_true",
                    help="omit additionally selected exact Y comparison examples")
    args=ap.parse_args()
    receipt=build(args.output,args.architectures,
                  showcase=not args.no_showcase)
    print("FMPL_PIPETTE_LIBRARY_OBJ_GENERATED",
          receipt["implemented_recipe_count"],receipt["model_count"],
          "objects_in",str(Path(args.output).resolve()))


if __name__=="__main__":
    main()
