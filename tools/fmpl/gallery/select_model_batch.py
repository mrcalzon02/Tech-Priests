#!/usr/bin/env python3
"""Select the next N distinct 3D model sources from a completed FMPL inventory.

Uses original source SHA records, so previously rendered interchangeable or
versioned copies are not blindly rerendered. No remote network or Blender call.
"""
from __future__ import annotations
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import sys

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--inventory",required=True)
    ap.add_argument("--previous-models-report",required=True)
    ap.add_argument("--out",required=True)
    ap.add_argument("--batch-index",type=int,default=0)
    ap.add_argument("--count",type=int,default=36)
    args=ap.parse_args()
    if not 0<=args.batch_index<=10000 or not 1<=args.count<=100:
        raise ValueError("Invalid bounded 3D model batch offset/size")
    root=Path(args.inventory).resolve()
    previous=json.loads(Path(args.previous_models_report).read_text(encoding="utf-8"))
    if previous["schema"]!="fmpl.gallery-models.v1":
        raise ValueError("No trusted prior model report")
    already={row["source"]["git_blob_sha"] for row in previous["rows"] if row["status"]=="rendered"}
    source=[]
    seen=set()
    for file in sorted(root.glob("*.jsonl.gz")):
        with gzip.open(file,"rt",encoding="utf-8") as fp:
            for line in fp:
                rec=json.loads(line)
                if rec["role"] not in ("native-model","interchange-model"):
                    continue
                if rec["git_blob_sha"] in already or rec["git_blob_sha"] in seen:
                    continue
                if Path(rec["path"]).suffix.lower() not in (".blend",".obj",".glb",".gltf",".fbx",".ply",".stl"):
                    continue
                seen.add(rec["git_blob_sha"])
                source.append(rec)
    prio={"Tech-Priests":0,"Tanks-for-bob-Fork":1,"The-Beckenburg-Project":2,
          "Magenheim":3,"HB-TTRPG-tools":4,"The-Malefic-Veil":5,"ReverieVR":6}
    def sort_key(rec):
        name=rec["repository"].split("/")[-1]
        ext=Path(rec["path"]).suffix.lower()
        versioned=1 if any("/"+str(i)+"/" in rec["path"].lower() for i in range(1,30)) else 0
        size=rec.get("size_bytes") or 0
        return (prio.get(name,10),versioned,0 if ext in (".glb",".obj") else 1,
                1 if size>15_000_000 else 0,size,rec["path"])
    source.sort(key=sort_key)
    start=args.batch_index*args.count
    selected=source[start:start+args.count]
    output=Path(args.out).resolve()
    if output.exists():raise FileExistsError("Never overwrite a prior model selection")
    output.parent.mkdir(parents=True,exist_ok=True)
    result={"schema":"fmpl.gallery-render-queue.v1",
      "initial_model_cap":args.count,"all_model_files":len(source)+len(already),
      "models":selected,"source_cursor":start,
      "distinct_unrendered_candidates":len(source),
      "previous_rendered_source_blobs":len(already),
      "batch_index":args.batch_index,"next_cursor":start+len(selected),
      "status":"selected-only-not-yet-rendered"}
    output.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print("FMPL_MODEL_RENDERS_NEXT_BATCH_SELECTED",len(selected),"remaining",len(source)-start-len(selected))
if __name__=="__main__":
    main()
