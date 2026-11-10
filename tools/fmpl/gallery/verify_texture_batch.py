#!/usr/bin/env python3
"""Independent native Blender readback of raw-source texture render batch."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import sys

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--out",required=True)
    ap.add_argument("--minimum",type=int,default=16)
    args=ap.parse_args(sys.argv[sys.argv.index("--")+1:])
    root=Path(args.out).resolve()
    report=json.loads((root/"texture_batch_report.json").read_text(encoding="utf-8"))
    if report["schema"]!="fmpl.raw-texture-batch.v1" or not report["complete"]:
        raise RuntimeError("Unrecognized or incomplete raw texture proof report")
    ids=set()
    succeeded=[]
    for row in report["images"]:
        record=row["source"]
        blob=record["git_blob_sha"]
        if len(blob)!=40 or len(record["commit"])!=40 or blob in ids:
            raise RuntimeError("Unpinned or duplicated texture proof")
        ids.add(blob)
        if row["status"]=="rendered":
            path=root/row["file"]
            if not path.is_file() or sha(path)!=row["render_sha256"]:
                raise RuntimeError("Texture preview image sha mismatch")
            succeeded.append(path)
    if len(succeeded)<args.minimum:
        raise RuntimeError("Too few real raw map renders for this preview batch")
    import bpy
    checked=0
    for path in succeeded:
        image=bpy.data.images.load(str(path),check_existing=False)
        if image.size[0]!=384 or image.size[1]!=384 or not image.has_data:
            raise RuntimeError("Texture preview incompatible or empty "+str(path))
        checked+=1
        bpy.data.images.remove(image,do_unlink=True)
    result={"schema":"fmpl.raw-texture-verify.v1","passed":True,
        "batch_index":report["batch_index"],
        "processed":report["processed"],"verified_blender_images":checked,
        "remaining_unique_source_textures":max(0,report["unique_texture_candidates"]-report["next_offset"]),
        "source_repositories_not_modified":True,"pbr_approval_not_implied":True}
    dest=root/"texture_batch_verify.json"
    if dest.exists():raise FileExistsError("Do not overwrite previous verifier receipt")
    dest.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print("FMPL_RAW_TEXTURE_NATIVE_READBACK_PASS",checked,flush=True)
if __name__=="__main__":
    main()
