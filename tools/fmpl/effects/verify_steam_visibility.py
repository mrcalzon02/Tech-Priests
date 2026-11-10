#!/usr/bin/env python3
"""Fail-closed visibility test on real 512px Blender Cycles Water Purifier images.

Never counts the metal vent lip as steam. Does not draw or recolor pixels,
and never treats native shader/keyframe existence as visual proof.
"""
from __future__ import annotations
import argparse
import array
import hashlib
import json
from pathlib import Path
import sys
import bpy

NOZZLE_STEAM_ROI=(320,90,359,120)  # x0,y0,x1,y1; image top-left
HIGH_RISE_ROI=(322,91,356,107)
MIN_VISIBLE_STEAM_PIXELS=75
MIN_HIGH_RISE_STEAM_PIXELS=12

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def inspect(path):
    im=bpy.data.images.load(str(path.resolve()),check_existing=False)
    try:
        if tuple(im.size)!=(512,512) or im.channels!=4:
            raise RuntimeError("Expected actual native 512x512 RGBA Cycles proof")
        pixels=array.array("f",[0.])* (512*512*4)
        im.pixels.foreach_get(pixels)
        def measure(roi):
            x0,y0,x1,y1=roi
            visible=0
            alpha_total=0.0
            luminosity_total=0.0
            for y in range(y0,y1):
                for x in range(x0,x1):
                    at=((511-y)*512+x)*4
                    r,g,b,a=pixels[at:at+4]
                    # Reject pixels so faint that they disappear at HR scale.
                    if a>=.055 and max(r,g,b)>=.15:
                        visible+=1
                        alpha_total+=a
                        luminosity_total+=max(r,g,b)
            return {
                "visibly_composited_pixels":visible,
                "sum_alpha":round(alpha_total,4),
                "sum_max_rgb":round(luminosity_total,4)
            }
        return {
            "steam_crop":measure(NOZZLE_STEAM_ROI),
            "high_rise":measure(HIGH_RISE_ROI)
        }
    finally:
        bpy.data.images.remove(im)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--idle",required=True)
    parser.add_argument("--working",required=True)
    parser.add_argument("--out",required=True)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    files={k:Path(v).resolve() for k,v in
           (("idle",args.idle),("working",args.working))}
    if any(not v.is_file() for v in files.values()):
        raise FileNotFoundError("Real Cycles idle/working proof images missing")
    output=Path(args.out).resolve()
    if output.exists():
        raise FileExistsError("Refusing to overwrite existing native steam pixel QA")
    states={name:inspect(path) for name,path in files.items()}
    conditions={
        name: (item["steam_crop"]["visibly_composited_pixels"]>=MIN_VISIBLE_STEAM_PIXELS
               and item["high_rise"]["visibly_composited_pixels"]>=MIN_HIGH_RISE_STEAM_PIXELS)
        for name,item in states.items()
    }
    passed=all(conditions.values())
    receipt={
        "schema":"fmpl.steam-visibility.v1",
        "passed":passed,
        "genuine_blender_cycles_images":True,
        "source_sha256":{k:digest(v) for k,v in files.items()},
        "canonical_camera":"45-degree fixed orthographic 512px",
        "source_regions_origin":"top-left",
        "steam_crop":list(NOZZLE_STEAM_ROI),
        "high_rise_crop":list(HIGH_RISE_ROI),
        "nozzle_lip_excluded_from_steam_measurement":True,
        "steam_pixel_alpha_threshold":.055,
        "steam_pixel_rgb_threshold":.15,
        "minimum_visible_steam_pixels":MIN_VISIBLE_STEAM_PIXELS,
        "minimum_high_rise_steam_pixels":MIN_HIGH_RISE_STEAM_PIXELS,
        "frames":states,
        "state_pass":conditions,
        "human_visual_approval":False,
        "factorio_game_integrated":False
    }
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print("FMPL_STEAM_VISIBILITY_PIXEL_QA "+json.dumps({
        "passed":passed,
        "count":{k:v["steam_crop"]["visibly_composited_pixels"] for k,v in states.items()},
        "upper":{k:v["high_rise"]["visibly_composited_pixels"] for k,v in states.items()}
    }),flush=True)
    if not passed:
        raise RuntimeError("Real Water Purifier vent steam remains too faint/disconnected above open nozzle")

if __name__=="__main__":
    main()
