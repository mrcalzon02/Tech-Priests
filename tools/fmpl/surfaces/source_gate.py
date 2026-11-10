#!/usr/bin/env python3
"""Quarantine-only BlendSwap CC0 source audit. NEVER downloads/opens a Blender file.

The external creator's license claim does not establish rights over embedded
third-party resources. No source is automatically added to FMPL.
"""
import argparse
import hashlib
import json
from pathlib import Path

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--manifest",required=True)
    p.add_argument("--asset-id",required=True)
    p.add_argument("--file",required=True)
    p.add_argument("--expected-sha256",required=True)
    p.add_argument("--report",required=True)
    args=p.parse_args()
    records=json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    selected=[x for x in records["candidates"] if x["id"]==args.asset_id]
    if len(selected)!=1: raise ValueError("Missing exact candidate asset id")
    row=selected[0]
    if row["license"]!="CC0" or row["license_claim"]!="uploader-declared":
        raise RuntimeError("Only clearly labeled CC0 uploader-declared candidates permitted")
    path=Path(args.file).resolve()
    if path.suffix.lower()!=".blend" or not path.is_file():
        raise FileNotFoundError("Unpacked Blender .blend required; no archives or paths inferred")
    size=path.stat().st_size
    if not 1_024<=size<=250*1024*1024:
        raise RuntimeError("Oversize/invalid external file requires separate manual vetting")
    supplied=args.expected_sha256.lower()
    actual=hashlib.sha256(path.read_bytes()).hexdigest()
    if actual!=supplied or len(supplied)!=64:
        raise RuntimeError("External source SHA mismatch")
    with path.open("rb") as f: magic=f.read(7)
    if magic!=b"BLENDER":
        raise RuntimeError("This is not a native Blender data source")
    out=Path(args.report).resolve()
    if out.exists(): raise FileExistsError("Never overwrite intake receipt")
    if not out.parent.is_dir():raise FileNotFoundError("Review output directory not created")
    receipt={"schema":"fmpl.surface-intake.v1","source_id":row["id"],
            "source_name":row["name"],"source_url":row["listing_url"],
            "declared_license":row["license"],"license_authority":"uploader-declared-unverified",
            "source_hash":actual,"bytes":size,
            "stage":"quarantine-passed-not-imported",
            "external_textures_inspected":False,
            "blender_5_compatibility_verified":False,
            "visual_approved":False,
            "safe_blender_auto_execution_disabled_on_future_open":True,
            "promoted_to_library":False,
            "next_step":"manual rights audit and isolated Blender --disable-autoexec import + native save/reopen + swatch proof"}
    out.write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print("FMPL_CC0_SOURCE_QUARANTINED_NOT_PROMOTED",row["id"],actual)

if __name__=="__main__":
    main()
