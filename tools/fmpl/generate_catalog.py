#!/usr/bin/env python3
"""Regenerate human-readable FMPL asset tables from the committed source catalogs."""
import argparse
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]


def escape(value):
    return str(value).replace("|",r"\|").replace("\n"," ")


def link(x):
    return "[%s](https://github.com/%s/blob/%s/%s)" % (
        escape(x["path"]),x["repository"],x["ref"],x["path"])


def build():
    m=json.loads((HERE/"FMPL.json").read_text(encoding="utf-8"))
    c=json.loads((ROOT/m["material_catalog"]).read_text(encoding="utf-8"))
    arr=[
        "# FMPL v%s — Asset Catalog" % m["version"],
        "",
        "Source-indexed asset tabulation. **Not every model is game-ready; not every component is an approved interchangeable part.**",
        "",
        "## Inventory",
        "",
        "| PBR presets | Texture maps | Bunker part candidates | Verified shared parts | Models | Programs | Pipelines |",
        "|---:|---:|---:|---:|---:|---:|---:|",
        "| %s | %s | %s | %s | %s | %s | %s |" % (
            m["inventory"]["materials"],m["inventory"]["pbr_maps"],m["inventory"]["bunker_component_candidates"],
            m["inventory"]["verified_shared_components"],len(m["models"]),len(m["programs"]),len(m["pipelines"])),
        "",
        "## Complete machine records and source state",
        "",
        "| Model ID | Current state | Source |",
        "|---|---|---|",
    ]
    for x in m["models"]:
        arr.append("| `%s` | %s | %s |" % (escape(x["id"]),escape(x["status"]),link(x["source"])))
    arr.extend(["","## Existing PBR materials","","| Preset | Material family | Source color | Albedo / ORM / Normal |","|---|---|---|---|"])
    for x in c["materials"]:
        refs=[link({"repository":m["canonical_repo"],"ref":m["source_commit"],"path":x["maps"][k]["source_path"]})
              for k in ("albedo","orm","normal")]
        arr.append("| `%s` | %s | `%s` | %s |" % (escape(x["material_id"]),escape(x["family"]),
                  x["source_color_hex"]," · ".join(refs)))
    arr.extend(["","## Small reusable component candidates (not yet promoted)","","| Candidate component | Donor machine | Existing source material | Source system |","|---|---|---|---|"])
    for x in c["candidates"]:
        arr.append("| `%s` | %s | `%s` | %s |" % (
            escape(x["source_object"]),escape(x["origin"]),escape(x["source_material"]),escape(x["system"])))
    arr.extend(["","## Reusable programs","","| Program | Type | Existing source |","|---|---|---|"])
    for x in m["programs"]:
        arr.append("| `%s` | %s | %s |" % (x["id"],escape(x["kind"]),link(x["source"])))
    arr.extend(["","## Production paths","","| Pipeline | Implemented state | Source tool | Completion boundary |","|---|---|---|---|"])
    for x in m["pipelines"]:
        arr.append("| `%s` | %s | %s | %s |" % (
            x["id"],escape(x["status"]),link(x["entrypoint"]),escape(x["gate"])))
    arr.extend(["","## Source and acceptance rules","",
        "- Original `.blend`, PBR maps and assembly scripts remain in their source repositories. FMPL indexes rather than cloning them.",
        "- A candidate is not a verified part until real dimensions, anchor transforms, material provenance, a fresh Blender reopen, and supporting visual evidence are recorded.",
        "- Source Blender mouth plane is not automatically an actual Factorio prototype fluid connection cell.",
        "- Working animated sprites, GLB roundtrip, Lua registration, Factorio launch, and visual acceptance are independent evidence stages.",
        "- Use the append-only `checkpoints.json` protocol to record results from iterative runs without erasing earlier revisions.",
        "",
        "Generated from `tools/fmpl/FMPL.json` and the existing industrial asset catalog. Rebuild with `python tools/fmpl/generate_catalog.py`.",
        ""])
    return "\n".join(arr)


if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--check",action="store_true",help="Exit nonzero if committed tabulation is stale")
    a=p.parse_args()
    doc=HERE/"ASSET_CATALOG.md"
    content=build()
    if a.check:
        if not doc.is_file() or doc.read_text(encoding="utf-8") != content:
            raise SystemExit("FMPL_ASSET_CATALOG_STALE")
        print("FMPL_ASSET_CATALOG_CURRENT")
    else:
        doc.write_text(content,encoding="utf-8")
        print("FMPL_ASSET_CATALOG_WRITTEN",len(content.splitlines()),"lines")
