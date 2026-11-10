#!/usr/bin/env python3
"""Optional Blender Asset Browser registration of an already verified native FMPL library.

No changes to scene data, material names, source files, or any Git repo.
Global Blender preferences are modified ONLY with --install.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import sys

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--blend",required=True)
    ap.add_argument("--expected-sha256",required=True)
    ap.add_argument("--name",default="FMPL Effects Materials v1")
    ap.add_argument("--install",action="store_true")
    args=ap.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else sys.argv[1:])
    source=Path(args.blend).resolve()
    if source.suffix.lower()!=".blend" or not source.is_file():
        raise FileNotFoundError("Verified .blend library is missing")
    digest=hashlib.sha256(source.read_bytes()).hexdigest()
    if digest!=args.expected_sha256:
        raise RuntimeError("Refusing to register changed/unverified native Blender bytes")
    if len(args.name)>64 or not args.name.strip():
        raise ValueError("Invalid Blender asset-browser library name")
    import bpy
    libs=bpy.context.preferences.filepaths.asset_libraries
    existing=next((lib for lib in libs if lib.name==args.name),None)
    if existing is not None and Path(existing.path).resolve()!=source.parent:
        raise RuntimeError("Existing Asset Browser name belongs to another directory")
    plan={"schema":"fmpl.effects.asset-browser-registration.v1",
          "name":args.name,"directory":str(source.parent),"blend":str(source),
          "sha256":digest,"install_requested":args.install,
          "already_registered":existing is not None}
    if args.install and existing is None:
        libs.new(name=args.name,directory=str(source.parent))
        bpy.ops.wm.save_userpref()
        plan["registered"]=True
    else:
        plan["registered"]=existing is not None
    print("FMPL_EFFECTS_ASSET_BROWSER",json.dumps(plan,sort_keys=True),flush=True)

if __name__=="__main__":main()
