#!/usr/bin/env python3
"""Independent Blender decode of native Water Purifier sprite fluid motion.

Checks the two calibrated forward-canister pixel regions at the approved
256px Factorio camera, not the distant steam plume or source keyframe lists.
Generated images are genuine Cycles output; never synthesize motion as proof.
"""
from __future__ import annotations
import argparse
import array
import hashlib
import json
from pathlib import Path
import sys

import bpy

REGIONS = {
    "raw_forward_canister": (104, 126, 169, 211),
    "clean_forward_canister": (128, 152, 169, 211),
}
FRAMES = tuple(range(8))


def image_pixels(path):
    im = bpy.data.images.load(str(path.resolve()), check_existing=False)
    try:
        if tuple(im.size) != (256, 256) or im.channels != 4:
            raise RuntimeError("Expected real 256px transparent Blender RGBA render")
        values = array.array("f", (0.0 for _ in range(256*256*4)))
        im.pixels.foreach_get(values)
        return values
    finally:
        bpy.data.images.remove(im)


def changes(baseline, candidate, crop, threshold):
    left,right,top,bottom=crop
    count=0
    total=0.
    max_delta=0.
    for y in range(top,bottom):
        for x in range(left,right):
            # bpy pixel buffers have a bottom-left origin; sprite crops use top-left.
            offset=((255-y)*256+x)*4
            if baseline[offset+3]<.15 and candidate[offset+3]<.15:
                continue
            delta=max(abs(baseline[offset+c]-candidate[offset+c]) for c in range(3))
            total+=delta
            max_delta=max(max_delta,delta)
            if delta>threshold:
                count+=1
    return {
        "visibly_changed_pixels":count,
        "summed_color_delta":round(total,4),
        "max_pixel_color_delta":round(max_delta,4),
    }


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--frames-dir",required=True)
    parser.add_argument("--out",required=True)
    parser.add_argument("--threshold",type=float,default=.052)
    parser.add_argument("--required-pixels",type=int,default=6)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    root=Path(args.frames_dir).resolve()
    filepaths=[root/("f%03d.png"%i) for i in FRAMES]
    if not all(p.is_file() for p in filepaths):
        raise FileNotFoundError("Missing real eight-frame Water Purifier Cycles capture")
    frames=[image_pixels(p) for p in filepaths]
    qa={
        "schema":"fmpl.fluid-motion-sprite.v1","passed":False,
        "resolution":[256,256],"camera":"canonical-fmpl.factorio45.v1",
        "roi_origin":"upper-left","threshold":args.threshold,
        "required_pixels_per_canister":args.required_pixels,
        "source_frame_sha256":[hashlib.sha256(p.read_bytes()).hexdigest() for p in filepaths],
        "canister_motion":{},
        "steam_region_excluded":True,"game_integrated":False,
    }
    for name,region in REGIONS.items():
        diffs=[changes(frames[0],frame,region,args.threshold) for frame in frames[1:]]
        best=max(diffs,key=lambda d:d["visibly_changed_pixels"])
        qa["canister_motion"][name]={
            "region":list(region),"comparisons":diffs,"max_changed_pixels":best["visibly_changed_pixels"],
        }
    qa["passed"]=all(x["max_changed_pixels"]>=args.required_pixels for x in qa["canister_motion"].values())
    output=Path(args.out).resolve()
    if output.exists():
        raise FileExistsError("Refusing overwritten independent fluid motion proof")
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(qa,indent=2)+"\n",encoding="utf-8")
    print("FMPL_FLUID_MOTION_PIXEL_CHECK "+json.dumps({
        "passed":qa["passed"],
        "canisters":{k:v["max_changed_pixels"] for k,v in qa["canister_motion"].items()}
    }),flush=True)
    if not qa["passed"]:
        raise RuntimeError("Keyed water is still not visibly moving at actual Factorio pixel scale")


if __name__=="__main__":
    main()
