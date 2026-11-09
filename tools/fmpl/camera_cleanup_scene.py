#!/usr/bin/env python3
"""Save a camera-clean derivative of a Blender source; original is immutable."""
import argparse
import json
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from blender_camera_guard import install_canonical_camera, assert_clean


def main():
    args = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    p=argparse.ArgumentParser()
    p.add_argument("--profile",required=True)
    p.add_argument("--out")
    p.add_argument("--audit-only",action="store_true")
    opts=p.parse_args(args)
    cfg=json.loads(Path(opts.profile).read_text(encoding="utf-8"))
    scene=bpy.context.scene
    if opts.audit_only:
        assert_clean(scene,cfg,bpy)
        print("FMPL_CAMERA_REOPEN_AUDIT_OK",bpy.data.filepath)
        return
    if not opts.out:p.error("--out required")
    original=Path(bpy.data.filepath).resolve()
    output=Path(opts.out).expanduser().resolve()
    if not original.is_file() or output==original:
        p.error("Source file must exist; output must be a different derived .blend")
    if output.exists():p.error("Refusing to overwrite an existing derivative")
    cleanup=install_canonical_camera(scene,cfg,bpy)
    assert_clean(scene,cfg,bpy)
    output.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output),check_existing=False)
    print("FMPL_CAMERA_CLEANED",json.dumps(cleanup),str(output))


if __name__=="__main__":
    main()
