#!/usr/bin/env python3
"""Independent Cycles difference renders prove RAW/CLEAN bubbles and foam are visible.

Reopens a genuine editable Blender derivative, makes three REAL Cycles images
from its fixed production camera (all, no rising air, no foam), and measures
each effect separately at the two front tank locations. This cannot pass merely
because tiny meshes/keyframes exist somewhere behind opaque liquid.
No camera replacement, asset mutation, composited effect or artificial image.
"""
from __future__ import annotations
import argparse
import array
import hashlib
import json
from pathlib import Path
import sys
import bpy

PIXEL_REGION={
    "raw_water":(208,314,277,426),
    "clean_water":(271,314,337,426),
}
MIN_BUBBLE_CHANGES=12
MIN_FOAM_CHANGES=12
MIN_CHANNEL_CHANGE=.045
FRAME=25
SIZE=512


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _image(path):
    im=bpy.data.images.load(str(path.resolve()),check_existing=False)
    try:
        if tuple(im.size)!=(SIZE,SIZE) or im.channels!=4:
            raise RuntimeError("Expected exact 512x512 real Cycles RGBA proof")
        arr=array.array("f",[0.])*(SIZE*SIZE*4)
        im.pixels.foreach_get(arr)
        return arr
    finally:
        bpy.data.images.remove(im)


def difference(first,second,box):
    x0,y0,x1,y1=box
    samples=0
    maxdiff=0.
    for y in range(y0,y1):
        for x in range(x0,x1):
            off=((SIZE-1-y)*SIZE+x)*4
            if max(first[off+3],second[off+3])<.2:
                continue
            delta=max(abs(first[off+c]-second[off+c]) for c in range(3))
            if delta>MIN_CHANNEL_CHANGE:
                samples+=1
            maxdiff=max(maxdiff,delta)
    return {"changed_pixels":samples,"maximum_color_delta":round(maxdiff,4)}


def render(scene,path):
    if path.exists():
        raise FileExistsError("Refusing to overwrite genuine Cycles visual proof")
    scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)
    if not path.is_file() or path.stat().st_size<4096:
        raise RuntimeError("Native Blender did not produce valid rendered proof "+str(path))
    return _image(path)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--blend",required=True)
    parser.add_argument("--out",required=True)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    dest=Path(args.out).resolve()
    if dest.exists():
        raise FileExistsError("Independent witness proof directory must be new")
    dest.mkdir(parents=True)
    bpy.ops.wm.open_mainfile(filepath=str(Path(args.blend).resolve()))
    scene=bpy.context.scene
    cameras=[o for o in scene.objects if o.type=="CAMERA"]
    if len(cameras)!=1 or scene.camera!=cameras[0]:
        raise RuntimeError("Unexpected camera replacement for witness proof")
    scene.frame_set(FRAME)
    bubbles=[o for o in scene.objects if o.type=="MESH" and
             "sample station " in o.name and "liquid bubble" in o.name and
             not o.hide_render]
    foam=[o for o in scene.objects if o.type=="MESH" and
          ("animated waterline foam crest" in o.name or
           "waterline froth bead" in o.name) and not o.hide_render]
    if len(bubbles)!=24 or len(foam)!=26:
        raise RuntimeError("Real witness bubbling/froth mesh counts incorrect")
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=24
    scene.render.resolution_x=SIZE
    scene.render.resolution_y=SIZE
    scene.render.resolution_percentage=100
    scene.render.film_transparent=True
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.threads_mode="FIXED"
    scene.render.threads=4
    scene.render.use_file_extension=True
    scene.render.image_settings.color_depth="8"
    scene.render.image_settings.compression=22
    scene.render.seed=4359
    fullfile=dest/"all-effects.png"
    bubblefile=dest/"no-bubbles.png"
    foamfile=dest/"no-foam.png"
    full=render(scene,fullfile)
    for o in bubbles:
        o.hide_render=True
    no_bubbles=render(scene,bubblefile)
    for o in bubbles:
        o.hide_render=False
    for o in foam:
        o.hide_render=True
    no_foam=render(scene,foamfile)
    for o in foam:
        o.hide_render=False
    results={}
    for label,roi in PIXEL_REGION.items():
        results[label]={
            "roi":list(roi),
            "bubble_contribution":difference(full,no_bubbles,roi),
            "foam_contribution":difference(full,no_foam,roi),
        }
    passed=all(
        r["bubble_contribution"]["changed_pixels"]>=MIN_BUBBLE_CHANGES and
        r["foam_contribution"]["changed_pixels"]>=MIN_FOAM_CHANGES
        for r in results.values())
    receipt={
        "schema":"fmpl.witness.visual-readback.v12",
        "passed":passed,
        "actual_cycles_render":True,
        "frame":FRAME,
        "source_blend_sha256":sha(args.blend),
        "single_original_camera":True,
        "visible_bubble_meshes":len(bubbles),
        "visible_foam_meshes":len(foam),
        "minimum_bubble_pixels_per_tank":MIN_BUBBLE_CHANGES,
        "minimum_foam_pixels_per_tank":MIN_FOAM_CHANGES,
        "rgb_change_threshold":MIN_CHANNEL_CHANGE,
        "samples_per_pixel":24,
        "images":{p.name:sha(p) for p in (fullfile,bubblefile,foamfile)},
        "tanks":results,
        "owner_approved":False,
        "native_factorio_fluidbox_verified":False,
    }
    (dest/"witness-visibility-qa.json").write_text(
        json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print("FMPL_WITNESS_VISIBLE_BUBBLES_AND_FOAM "+json.dumps({
        "passed":passed,
        "pixels":{name:{
            "bubble":r["bubble_contribution"]["changed_pixels"],
            "foam":r["foam_contribution"]["changed_pixels"]}
            for name,r in results.items()}
    }),flush=True)
    if not passed:
        raise RuntimeError("Real 512px Water Purifier render still hides bubbles or foam")


if __name__=="__main__":
    main()
