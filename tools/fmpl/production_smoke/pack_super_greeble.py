#!/usr/bin/env python3
"""Pillow-free Blender assembler for ONE Factorio production direction.

Input is the actual saved/reopened FMPL sprite master and nine frame PNGs:
idle: frame1; working: 1,13,25,37,49,61,73,85.  Output is three sizes of
static/working transparent animation atlases plus one real contact sheet.
"""
from __future__ import annotations
import argparse
import array
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys
import bpy

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("fmpl_native_atlas_primitives",HERE/"pack_blender_atlases.py")
helper=importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)

def sha(path):
    h=hashlib.sha256()
    with Path(path).open("rb") as f:
        for block in iter(lambda:f.read(1024*1024),b""):
            h.update(block)
    return h.hexdigest()

def tiled(frames,size,columns):
    rows=math.ceil(len(frames)/columns)
    width,height=columns*size,rows*size
    out=array.array("f",[0.0])*(width*height*4)
    for i,src in enumerate(frames):
        x0=(i%columns)*size
        y0=(rows-1-i//columns)*size
        for y in range(size):
            dest=((y0+y)*width+x0)*4
            source=y*size*4
            out[dest:dest+size*4]=src[source:source+size*4]
    return out,(width,height),rows

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--out",required=True)
    a=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    out=Path(a.out).resolve()
    manifest=json.loads((out/"capture.json").read_text(encoding="utf-8-sig"))
    cfg=manifest.get("config",{})
    if (manifest.get("schema")!=1 or cfg.get("directions")!=[0] or
        cfg.get("source_size")!=256 or
        cfg.get("sizes")!=[64,128,256]):
        raise RuntimeError("No canonical one-angle 256px Blender source profile")
    states=cfg.get("states",{})
    if states.get("idle")!=[1] or states.get("working")!=[1,13,25,37,49,61,73,85]:
        raise RuntimeError("Unexpected keyed idle/working frame list")
    if sha(out/"master.blend")!=manifest.get("master_sha256"):
        raise RuntimeError("Source Blender master digest does not match capture")
    reopened=json.loads((out/"reopen-qa.json").read_text(encoding="utf-8-sig"))
    if reopened.get("passed") is not True:
        raise RuntimeError("Native Blender master not independently reopened")
    frames=manifest.get("frames",[])
    if len(frames)!=9:
        raise RuntimeError("Exactly nine source frames expected")
    by_key={(x["state"],x["direction"],x["index"],x["timeline_frame"]):x for x in frames}
    if len(by_key)!=9:
        raise RuntimeError("Duplicate or missing source frame metadata")
    source={}
    bounds={}
    for state,frameset in (("idle",[1]),("working",states["working"])):
        source[state]=[]
        bounds[state]=[]
        for i,frame in enumerate(frameset):
            key=(state,0,i,frame)
            record=by_key.get(key)
            if record is None:
                raise RuntimeError("Missing real Blender frame "+str(key))
            image=out/record["path"]
            if sha(image)!=record["sha256"]:
                raise RuntimeError("Source frame digest changed "+str(image))
            rgba=helper.get_frame(image,256)
            bounds[state].append(helper.assert_alpha_geometry(rgba,256))
            source[state].append(rgba)
    created=[]
    for size in (64,128,256):
        for state,count,columns in (("idle",1,1),("working",8,4)):
            frameset=[helper.scale_frame_nearest(src,256,size) for src in source[state]]
            raw,(w,h),rows=tiled(frameset,size,columns)
            target=out/(state+"-"+str(size)+".png")
            if target.exists():
                raise FileExistsError("Refusing to overwrite previous sprite "+str(target))
            helper.save_rgba(target,w,h,raw)
            if target.stat().st_size<150:
                raise RuntimeError("No actual Blender RGBA output generated")
            created.append({
              "state":state,"path":target.name,"sha256":sha(target),
              "cell_size":size,"frame_count":count,"direction_count":1,
              "columns":columns,"rows":rows,"dimensions":[w,h],
              "timeline_frames":([1] if state=="idle" else states["working"])
            })
    # Genuine frame-by-frame visual proof, not a generated concept sheet.
    full=[source["idle"][0]]+source["working"]
    pixels,(w,h),rows=tiled(full,256,9)
    sheet=out/"super-greeble-contact-sheet.png"
    if sheet.exists():raise FileExistsError("Previous contact sheet already exists")
    helper.save_rgba(sheet,w,h,pixels)
    qa={
      "schema":"fmpl.super-greeble-atlas.v1","passed":True,
      "native_master_sha256":manifest["master_sha256"],
      "fixed_factorio_camera":True,"directions":[0],
      "states":["idle","working"],"unique_source_frames":9,
      "outputs":created,"contact_sheet_sha256":sha(sheet),
      "frame_alpha_bounds":bounds,"production_native_accepted":False,
      "game_integrated":False,"owner_visual_approval":False
    }
    (out/"super-greeble-qa.json").write_text(json.dumps(qa,indent=2)+"\n",encoding="utf-8")
    print("FMPL_SUPER_GREEBLE_ATLAS_PASS 1 angle, 1 static, 8 working frames, 6 RGBA sheets",flush=True)

if __name__=="__main__":
    main()
