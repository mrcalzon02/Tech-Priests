#!/usr/bin/env python3
"""Render a bounded, explicitly pinned cross-repository model batch in real Blender.

Every successful preview is a genuine newly rendered 3D object, not a model
thumbnail downloaded from GitHub. A failed import remains a named blocked
record and never receives a fabricated image. Does not mutate source models.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import re
import shutil
from pathlib import Path
import sys
import time
from urllib.parse import quote
from urllib.request import urlopen, Request

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def gitblob(data):
    return hashlib.sha1(("blob "+str(len(data))+"\0").encode()+data).hexdigest()

def download_verified(record,dest,max_bytes):
    repo=record["repository"]
    if not re.fullmatch("mrcalzon02/[A-Za-z0-9_.-]+",repo):
        raise RuntimeError("Refusing unapproved GitHub model source")
    commit=record["commit"]
    if not re.fullmatch("[0-9a-f]{40}",commit):
        raise RuntimeError("Model source is not pinned to a full Git commit")
    if dest.exists():raise FileExistsError("Temporary source collision")
    if (record.get("size_bytes") or 0)>max_bytes:
        raise RuntimeError("Model exceeds per-run size budget")
    url="https://raw.githubusercontent.com/"+repo+"/"+commit+"/"+quote(record["path"],safe="/")
    headers={"User-Agent":"FMPL-original-3d-model-render/1.0"}
    last=None
    for delay in (0,3,9):
        if delay:time.sleep(delay)
        try:
            with urlopen(Request(url,headers=headers),timeout=65) as response:
                data=response.read(max_bytes+1)
            if len(data)>max_bytes:raise RuntimeError("Source exceeds guarded byte cap")
            if data.startswith(b"version https://git-lfs.github.com/spec/v1"):
                raise RuntimeError("GitHub LFS pointer, not full Blender/model binary")
            if gitblob(data)!=record["git_blob_sha"]:
                raise RuntimeError("Source Git blob SHA mismatch; do not render unrelated content")
            dest.parent.mkdir(parents=True,exist_ok=True)
            dest.write_bytes(data)
            return {"bytes":len(data),"source_sha256":hashlib.sha256(data).hexdigest()}
        except Exception as exc:
            last=exc
    raise RuntimeError("Verified model retrieval failed: "+str(last)[:170])

def import_model(bpy,file):
    ext=file.suffix.lower()
    if ext==".obj":
        if hasattr(bpy.ops.wm,"obj_import"):
            try:bpy.ops.wm.obj_import(filepath=str(file),forward_axis="Y",up_axis="Z")
            except TypeError:bpy.ops.wm.obj_import(filepath=str(file))
        else:bpy.ops.import_scene.obj(filepath=str(file),axis_forward="Y",axis_up="Z")
    elif ext in (".glb",".gltf"):
        bpy.ops.import_scene.gltf(filepath=str(file))
    elif ext==".fbx":
        bpy.ops.import_scene.fbx(filepath=str(file))
    elif ext==".blend":
        # Read in a fresh Blender instance, with autoexec disabled by the
        # production worker. Only the disposable downloaded copy is opened.
        bpy.ops.wm.open_mainfile(filepath=str(file),load_ui=False)
        for old in tuple(bpy.context.scene.objects):
            if old.type in ("CAMERA","LIGHT"):
                bpy.data.objects.remove(old,do_unlink=True)
    elif ext==".stl":
        bpy.ops.wm.stl_import(filepath=str(file))
    elif ext==".ply":
        bpy.ops.wm.ply_import(filepath=str(file))
    else:
        raise RuntimeError("Direct model preview format unsupported: "+ext)
    visible=[o for o in bpy.context.scene.objects if o.type in ("MESH","CURVE","SURFACE") and not o.hide_render and not o.hide_viewport]
    if not visible:raise RuntimeError("No real Blender geometry imported")
    return visible

def set_scene(bpy,scene,objects):
    from mathutils import Vector
    bpy.context.view_layer.update()
    corners=[]
    for obj in objects:
        if obj.type=="MESH":
            for vert in obj.bound_box:
                corners.append(obj.matrix_world@Vector(vert))
        elif obj.type=="CURVE":
            for vert in obj.bound_box:
                corners.append(obj.matrix_world@Vector(vert))
    if not corners:raise RuntimeError("No usable mesh bounds for 3D preview")
    small=Vector(tuple(min(p[i] for p in corners) for i in range(3)))
    large=Vector(tuple(max(p[i] for p in corners) for i in range(3)))
    bounds=large-small
    longest=max(float(v) for v in bounds)
    if not .00001<longest<1e6:raise RuntimeError("Unbounded/empty model geometry")
    target=(small+large)*.5
    cam=bpy.data.cameras.new("FMPL | object 45 fixed")
    cam.type="ORTHO"
    cam.ortho_scale=max(1.2,longest*1.75)
    obj=bpy.data.objects.new("FMPL | model gallery one fixed camera",cam)
    scene.collection.objects.link(obj)
    distance=max(4.0,longest*3.0)
    obj.location=target+Vector((0,-distance,distance))
    obj.rotation_euler=(target-obj.location).to_track_quat("-Z","Y").to_euler()
    scene.camera=obj
    for name,where,intensity in [
        ("warm",target+Vector((-distance*.4,-distance*.3,distance*.8)),1200),
        ("cool",target+Vector((distance*.3,distance*.2,distance*.8)),800)]:
        light=bpy.data.lights.new("FMPL | "+name,"AREA")
        light.energy=intensity
        light.size=max(2.0,longest*1.5)
        lamp=bpy.data.objects.new("FMPL | "+name,light)
        scene.collection.objects.link(lamp)
        lamp.location=where
        lamp.rotation_euler=(target-lamp.location).to_track_quat("-Z","Y").to_euler()
    scene.render.engine="CYCLES"
    scene.cycles.samples=12
    scene.cycles.device="CPU"
    scene.render.resolution_x=512
    scene.render.resolution_y=512
    scene.render.resolution_percentage=100
    scene.render.film_transparent=True
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.threads_mode="FIXED"
    scene.render.threads=4
    scene.world=bpy.data.worlds.new("FMPL | model preview world")
    scene.world.use_nodes=True
    bg=scene.world.node_tree.nodes.get("Background")
    if bg:bg.inputs["Strength"].default_value=.58
    direct=(obj.location-target).normalized()
    if abs(math.degrees(math.asin(direct.z))-45)>.001 or abs(direct.x)>.001:
        raise RuntimeError("Model gallery camera not fixed 45 degree")
    return {"dimensions":[round(float(x),6) for x in bounds],
            "mesh_count":sum(o.type=="MESH" for o in objects),
            "ortho_scale":cam.ortho_scale}

def render_one(bpy,rec,root,max_bytes):
    source=rec["path"]
    suffix=Path(source).suffix.lower()
    tag=re.sub("[^a-z0-9_-]","-",rec["repository"].split("/")[-1].lower()+"-"+Path(source).stem.lower())
    tag=tag[:82]+"-"+rec["git_blob_sha"][:9]
    scratch=root/"scratch"/tag
    scratch.mkdir(parents=True,exist_ok=False)
    src=scratch/("model"+suffix)
    try:
        manifest=download_verified(rec,src,max_bytes)
        if suffix==".obj" and rec["repository"].endswith("/Tanks-for-bob-Fork"):
            donor=dict(rec)
            donor["path"]="models/island-survival/obj/survival-materials.mtl"
            # The accompanying MTL is a dependency, but its immutable source
            # hash is checked independently against the selected Git tree.
            if rec.get("mtl_blob_sha"):
                donor["git_blob_sha"]=rec["mtl_blob_sha"]
                download_verified(donor,scratch/"survival-materials.mtl",max_bytes)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        objects=import_model(bpy,src)
        scene=bpy.context.scene
        measurements=set_scene(bpy,scene,objects)
        scene.frame_set(1)
        dest=root/"renders"/(tag+".png")
        dest.parent.mkdir(parents=True,exist_ok=True)
        if dest.exists():raise FileExistsError("Refusing to replace previous model proof")
        scene.render.filepath=str(dest)
        bpy.ops.render.render(write_still=True)
        if not dest.is_file() or dest.stat().st_size<1200:
            raise RuntimeError("Blender model preview missing/empty")
        return {"status":"rendered","source":rec,"file":str(dest.relative_to(root)).replace("\\","/"),
                "render_sha256":sha(dest),"rendered_with":"Blender Cycles",
                "blender":bpy.app.version_string,"source_sha256":manifest["source_sha256"],
                "source_bytes":manifest["bytes"],"measurements":measurements,
                "not_game_or_owner_approved":True}
    finally:
        shutil.rmtree(scratch,ignore_errors=True)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--queue",required=True)
    ap.add_argument("--out",required=True)
    ap.add_argument("--max-models",type=int,default=36)
    ap.add_argument("--max-source-bytes",type=int,default=15000000)
    a=ap.parse_args(sys.argv[sys.argv.index("--")+1:])
    if not 1<=a.max_models<=100 or not 10000<=a.max_source_bytes<=60000000:
        raise ValueError("Bounded model render budget invalid")
    output=Path(a.out).resolve()
    if output.exists() and any(output.iterdir()):raise FileExistsError("Refusing to overwrite model gallery")
    output.mkdir(parents=True,exist_ok=True)
    queue=json.loads(Path(a.queue).read_text(encoding="utf-8"))
    if queue.get("schema")!="fmpl.gallery-render-queue.v1":
        raise ValueError("Unknown queued-model provenance")
    if a.max_source_bytes>25000000:
        # One exception for the eight size-blocked sources of Dens Mortis
        # run 42887345055; the Windows worker separately verifies its original
        # report SHA and size-limited retry request. This never enables 60MB
        # downloads for arbitrary user-supplied queues.
        eligible={
            "559c91f3133be15c2b1810634153ef63a5aaa0a2",
            "4b5062005cb52f30c711af3b62a5ff1413ac0eea",
            "38c0e56531fd4929658206daeffd7a21a945a873",
            "d520336340fbfe241a4bc270ccfc674eaaf03776",
            "e7f584e7e9e09631998d47287931b934313d6469",
            "b047531d6c5408b1f6ca4e21a3ca9b515befe3c9",
            "712c28ab67bf8bc8cd0173bbc6885f9f3b67ebdb",
            "7be4d5ad196d51aef030833a1bd95d9e1290e5df",
        }
        sources=queue.get("models",[])
        if (a.max_source_bytes!=60000000 or a.max_models!=8 or
            queue.get("initial_model_cap")!=8 or queue.get("batch_index")!=1 or
            queue.get("status")!="retry-only-measured-size-blockers-no-prior-rerenders" or
            len(sources)!=8 or {rec.get("git_blob_sha") for rec in sources}!=eligible):
            raise ValueError("Oversize exception denied: exact eight verified model blobs required")
    inputs=queue["models"][:a.max_models]
    import bpy
    rows=[]
    for i,source in enumerate(inputs,1):
        print("FMPL_GALLERY_MODEL_START",i,len(inputs),source["repository"],source["path"],flush=True)
        try:
            row=render_one(bpy,source,output,a.max_source_bytes)
        except Exception as exc:
            row={"status":"blocked","source":source,"error":str(exc)[:400]}
        rows.append(row)
        # Atomic, progressive after every model: recover earlier render evidence
        # even when a later remote download or Blender import is interrupted.
        temporary=output/"models_report.json.tmp"
        report={"schema":"fmpl.gallery-models.v1","requested":len(inputs),
                "rendered":sum(r["status"]=="rendered" for r in rows),
                "blocked":sum(r["status"]=="blocked" for r in rows),"total_catalog_model_files":queue["all_model_files"],
                "complete":len(rows)==len(inputs),"rows":rows,"sources_are_readonly":True}
        temporary.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
        temporary.replace(output/"models_report.json")
        print("FMPL_GALLERY_MODEL_RESULT",i,row["status"],flush=True)
    shutil.rmtree(output/"scratch",ignore_errors=True)
    print("FMPL_GALLERY_MODELS_PASS",report["rendered"],"rendered",report["blocked"],"blocked",flush=True)

if __name__=="__main__":
    main()
