#!/usr/bin/env python3
"""FMPL atlas assembly via Blender's image API: no Pillow installation.

Consumes genuine render_sprite_frames.py RGBA frames, source hashes and a
saved/reopened MODEL/RENDER Blender master. Copies four cardinal directions
into 64/128/256 PNG atlases. Native Factorio draw offsets are not inferred.
"""
from __future__ import annotations
import argparse
import array
import hashlib
import json
from pathlib import Path
import sys

import bpy


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save_rgba(path, width, height, pixels):
    image=bpy.data.images.new("FMPL temporary atlas",width=width,height=height,alpha=True,float_buffer=False)
    try:
        image.pixels.foreach_set(pixels)
        image.update()
        image.file_format="PNG"
        image.filepath_raw=str(path)
        image.save()
    finally:
        bpy.data.images.remove(image)


def get_frame(path, size):
    image=bpy.data.images.load(str(path),check_existing=False)
    try:
        if image.size[0]!=size or image.size[1]!=size or image.channels!=4:
            raise ValueError("Wrong RGBA Blender frame dimensions: "+str(path))
        data=array.array("f",[0.0])*(size*size*4)
        image.pixels.foreach_get(data)
        return data
    finally:
        bpy.data.images.remove(image)


def pixel_at(frame, size, x, y):
    return (int(y)*size+int(x))*4


def assert_alpha_geometry(frame,size):
    visible=[]
    all_opaque=True
    for y in range(size):
        for x in range(size):
            a=float(frame[pixel_at(frame,size,x,y)+3])
            if a<.99: all_opaque=False
            if a>.03:visible.append((x,y))
    if not visible or all_opaque:
        raise ValueError("Blank or rectangular-opaque capture")
    xlo=min(p[0] for p in visible);xhi=max(p[0] for p in visible)
    ylo=min(p[1] for p in visible);yhi=max(p[1] for p in visible)
    if xlo<=0 or ylo<=0 or xhi>=size-1 or yhi>=size-1:
        raise ValueError("Frame clipped at canvas: "+str((xlo,ylo,xhi,yhi)))
    return [xlo,ylo,xhi+1,yhi+1]


def scale_frame_nearest(original, source_size, size):
    if size==source_size:return original
    data=array.array("f",[0.0])*(size*size*4)
    for y in range(size):
        sy=min(source_size-1,int((y+.5)*source_size/size))
        for x in range(size):
            sx=min(source_size-1,int((x+.5)*source_size/size))
            i=pixel_at(original,source_size,sx,sy)
            j=pixel_at(data,size,x,y)
            data[j:j+4]=original[i:i+4]
    return data


def atlas(data,size):
    # Blender pixel row 0 is bottom, so place direction 0 in the TOP atlas row.
    out=array.array("f",[0.0])*(size*(len(data)*size)*4)
    for d,frame in enumerate(data):
        for y in range(size):
            dest=((len(data)-d-1)*size+y)*size*4
            src=y*size*4
            out[dest:dest+size*4]=frame[src:src+size*4]
    return out


def contact(data,size):
    n=len(data)
    out=array.array("f",[0.0])*(n*size*size*4)
    width=n*size
    for d,frame in enumerate(data):
        for y in range(size):
            for x in range(size):
                i=(y*size+x)*4
                j=(y*width+d*size+x)*4
                out[j:j+4]=frame[i:i+4]
    return out


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--out",required=True)
    a=p.parse_args(sys.argv[sys.argv.index("--")+1:])
    root=Path(a.out).resolve()
    capture=json.loads((root/"capture.json").read_text(encoding="utf-8"))
    cfg=capture["config"]
    rotations=list(cfg["directions"])
    if capture.get("schema")!=1 or rotations not in ([0],[0,90,180,270]):
        raise RuntimeError("FMPL packer requires single production angle 0, or explicitly opted-in four cardinal views")
    direction_count=len(rotations)
    if cfg.get("states")!={"idle":[1]}:
        raise RuntimeError("FMPL smoke expected exactly one static idle frame")
    if sha(root/"master.blend") != capture["master_sha256"]:
        raise RuntimeError("Saved native master SHA mismatch")
    records=capture["frames"]
    if len(records)!=direction_count or [(x["direction"],x["index"],x["timeline_frame"]) for x in records]!=[(d,0,1) for d in range(direction_count)]:
        raise RuntimeError("Incorrect Blender frame order")
    source_size=cfg["source_size"]
    source=[]
    bounds=[]
    for row in records:
        path=root/row["path"]
        if sha(path)!=row["sha256"]:
            raise RuntimeError("Blender source frame changed: "+row["path"])
        raw=get_frame(path,source_size)
        bounds.append(assert_alpha_geometry(raw,source_size))
        source.append(raw)
    sheets=[]
    for size in cfg["sizes"]:
        scaled=[scale_frame_nearest(frame,source_size,size) for frame in source]
        target=root/("idle-"+str(size)+".png")
        save_rgba(target,size,direction_count*size,atlas(scaled,size))
        if not target.is_file() or target.stat().st_size<100:
            raise RuntimeError("Atlas image missing or empty")
        rows=[{"direction":d,"rect":[0,d*size,size,size]} for d in range(direction_count)]
        sheets.append({"path":target.name,"sha256":sha(target),"cell_size":size,
                       "direction_count":direction_count,"frame_count":1,"dimensions":[size,direction_count*size],"cells":rows})
    proof=root/"contact-sheet.png"
    save_rgba(proof,source_size*direction_count,source_size,contact(source,source_size))
    qa={"passed":True,"capture_count":direction_count,"atlas_count":3,"sheets":sheets,
        "direction_count":direction_count,
        "production_camera_count":1,
        "source_frame_bounds":bounds,"material_reconstruction":"Blender-packed source",
        "checks":["exact source and master SHA","validated authored direction count and frame order","nonblank transparent alpha",
                  "no clipping","saved PNG dimensions","native Blender image composition"],
        "native_factorio_port_verified":False,
        "owner_visual_approval":False,"game_integrated":False,
        "resampling":"nearest-neighbor; diagnostic static production candidate"}
    (root/"qa.json").write_text(json.dumps(qa,indent=2)+"\n",encoding="utf-8")
    print("FMPL_NATIVE_ATLAS_PASS "+str(direction_count)+" fixed-camera Blender frame(s), 3 RGBA atlases, no Pillow",flush=True)


if __name__=="__main__":
    main()
