#!/usr/bin/env python3
"""V13 visual proof: real Cycles on/off isolations for agitation and CRT.

Each effect group is render-disabled in a temporary open Blender process,
never deleted or composited into the original .blend. Compare real 512px
render pixels for central swirl, foam, recirculating bubbles, green readout.
"""
from __future__ import annotations
import argparse
import array
import hashlib
import json
from pathlib import Path
import sys
import bpy

SIZE=512
FRAME=25
ROI={
    "central":(175,105,347,273),
    "screen":(307,319,418,431),
}
PIXEL_THRESHOLD=.045
REQUIRED={"central_surface":30,"central_foam":14,
          "central_bubbles":10,"console_readout":8}

def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def pixels(path):
    image=bpy.data.images.load(str(path),check_existing=False)
    try:
        if tuple(image.size)!=(SIZE,SIZE) or image.channels!=4:
            raise RuntimeError("Not a native 512px Blender RGBA render")
        result=array.array("f",[0.])*(SIZE*SIZE*4)
        image.pixels.foreach_get(result)
        return result
    finally:
        bpy.data.images.remove(image)

def delta(a,b,roi):
    x0,y0,x1,y1=roi
    changed=0
    total=0.
    for y in range(y0,y1):
        for x in range(x0,x1):
            off=((SIZE-1-y)*SIZE+x)*4
            if max(a[off+3],b[off+3])<.2:
                continue
            d=max(abs(a[off+c]-b[off+c]) for c in range(3))
            total+=d
            if d>PIXEL_THRESHOLD:
                changed+=1
    return {"visible_changed_pixels":changed,"sum_channel_delta":round(total,4)}

def draw(scene,path):
    if path.exists():
        raise FileExistsError("Refusing to overwrite native Blender QA render")
    scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)
    if not path.exists() or path.stat().st_size<4096:
        raise RuntimeError("Blender did not render real Cycles effect proof "+str(path))
    return pixels(path)

def named(scene,needle):
    return [o for o in scene.objects if o.type=="MESH" and
            needle in o.name and not o.hide_render]

def main():
    a=argparse.ArgumentParser()
    a.add_argument("--blend",required=True)
    a.add_argument("--out",required=True)
    args=a.parse_args(sys.argv[sys.argv.index("--")+1:])
    target=Path(args.out).resolve()
    if target.exists():
        raise FileExistsError("Native central agitation proof directory must be new")
    target.mkdir(parents=True)
    bpy.ops.wm.open_mainfile(filepath=str(Path(args.blend).resolve()))
    scene=bpy.context.scene
    if len([o for o in scene.objects if o.type=="CAMERA"])!=1:
        raise RuntimeError("Camera policy violated in central proof")
    scene.frame_set(FRAME)
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=24
    scene.render.resolution_x=SIZE
    scene.render.resolution_y=SIZE
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.image_settings.color_depth="8"
    scene.render.film_transparent=True
    scene.render.threads_mode="FIXED"
    scene.render.threads=4
    scene.cycles.seed=4359
    groups={
        "central_surface":named(scene,"central real animated agitator liquid top")+
            named(scene,"central stirring current ribbon"),
        "central_foam":named(scene,"central floating foam clump")+
            named(scene,"central impeller turbulence froth"),
        "central_bubbles":named(scene,"central recirculating bubble"),
        "console_readout":named(scene,"angled CRT live green readout bar"),
    }
    expected={"central_surface":5,"central_foam":36,
              "central_bubbles":24,"console_readout":5}
    for name,objs in groups.items():
        if len(objs)!=expected[name]:
            raise RuntimeError("Actual Blender scene missing V13 object family "+name+":"+str(len(objs)))
    baseline=draw(scene,target/"all-central-effects.png")
    results={}
    receipts={"all-central-effects.png":sha(target/"all-central-effects.png")}
    for name,objs in groups.items():
        for obj in objs:
            obj.hide_render=True
        p=target/("without-"+name+".png")
        off=draw(scene,p)
        for obj in objs:
            obj.hide_render=False
        receipts[p.name]=sha(p)
        results[name]=delta(baseline,off,ROI["screen" if name=="console_readout" else "central"])
    passed=all(results[name]["visible_changed_pixels"]>=REQUIRED[name] for name in REQUIRED)
    output={
        "schema":"fmpl.central-v13.render-isolation.v1",
        "passed":passed,
        "real_blender_cycles":True,
        "sample_frame":FRAME,
        "camera_preserved":True,
        "blender_sha256":sha(args.blend),
        "water_center_roi":list(ROI["central"]),
        "console_roi":list(ROI["screen"]),
        "min_visible_pixels":REQUIRED,
        "actual_object_count":expected,
        "effect_pixel_differences":results,
        "png_sha256":receipts,
        "factorio_integrated":False,"owner_visual_approval":False,
    }
    (target/"central-console-visual-proof.json").write_text(
        json.dumps(output,indent=2)+"\n",encoding="utf-8")
    print("FMPL_CENTRAL_CONSOLE_CYCLES_VISUAL_QA "+json.dumps({
        "passed":passed,"visible_pixels":{
            k:v["visible_changed_pixels"] for k,v in results.items()}
    }),flush=True)
    if not passed:
        raise RuntimeError("Central swirl, foam, bubbles or moved CRT still invisible in actual Cycles render")

if __name__=="__main__":
    main()
