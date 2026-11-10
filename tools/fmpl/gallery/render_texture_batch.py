#!/usr/bin/env python3
"""Incremental REAL Blender render of source-verified raw texture maps.

Unlike canonical FMPL PBR/FX materials, these are *texture-data previews*;
normal/ORM channels are displayed as sourced, never claimed physically shaded.
One bounded batch, no automatic loop or unapproved texture redistribution.
"""
from __future__ import annotations
import argparse
import gzip
import hashlib
import html
import json
from pathlib import Path
import re
import shutil
import sys
import time
from urllib.parse import quote
from urllib.request import urlopen,Request

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def git_blob(data):
    return hashlib.sha1(("blob "+str(len(data))+"\0").encode()+data).hexdigest()

def candidates(inventory):
    picks=[]
    seen=set()
    for file in sorted(Path(inventory).glob("*.jsonl.gz")):
        with gzip.open(file,"rt",encoding="utf-8") as fp:
            for line in fp:
                row=json.loads(line)
                if row["role"] not in ("material-map","texture-image"):continue
                blob=row.get("git_blob_sha")
                if not blob or blob in seen:continue
                seen.add(blob)
                picks.append(row)
    def ranking(row):
        role=0 if row["role"]=="material-map" else 1
        path=row["path"].lower()
        group=0 if "/textures/" in "/"+path else 1
        old=1 if "/dist/" in "/"+path or "/generated/" in "/"+path else 0
        return (role,old,group,row["repository"],path)
    return sorted(picks,key=ranking)

def download(record,filepath,max_bytes):
    if not re.fullmatch(r"mrcalzon02/[A-Za-z0-9_.-]+",record["repository"]) or not re.fullmatch(r"[a-f0-9]{40}",record["commit"]):
        raise ValueError("Unpinned/unauthorized source")
    if (record.get("size_bytes") or 0)>max_bytes:raise RuntimeError("Oversize source texture")
    url="https://raw.githubusercontent.com/"+record["repository"]+"/"+record["commit"]+"/"+quote(record["path"],safe="/")
    error=None
    for delay in (0,4,9):
        if delay:time.sleep(delay)
        try:
            with urlopen(Request(url,headers={"User-Agent":"FMPL-texture-map-proof/1.0"}),timeout=50) as res:
                data=res.read(max_bytes+1)
            if len(data)>max_bytes:raise ValueError("Downloaded texture over size cap")
            if git_blob(data)!=record["git_blob_sha"]:raise RuntimeError("Wrong raw texture blob")
            if data.startswith(b"version https://git-lfs.github.com/"):raise RuntimeError("LFS pointer is not real image data")
            filepath.write_bytes(data)
            return sha(filepath)
        except Exception as e:
            error=e
    raise RuntimeError(str(error)[:180])

def make_scene(bpy):
    from mathutils import Vector
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,radius=.47)
    sphere=bpy.context.object
    sphere.name="FMPL | original texture on neutral test sphere"
    sphere.location=(0,0,.5)
    for f in sphere.data.polygons:f.use_smooth=True
    mat=bpy.data.materials.new("FMPL | source texture visualizer")
    mat.use_nodes=True
    nodes=mat.node_tree.nodes
    node=nodes.new("ShaderNodeTexImage")
    shader=nodes.get("Principled BSDF")
    mat.node_tree.links.new(node.outputs["Color"],shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value=.53
    sphere.data.materials.append(mat)
    bpy.ops.mesh.primitive_cube_add(size=1,location=(0,0,-.14))
    ground=bpy.context.object
    ground.name="FMPL | neutral physical pedestal"
    ground.scale=(1.4,1.4,.12)
    backdrop=bpy.data.materials.new("FMPL | neutral pedestal")
    backdrop.diffuse_color=(.27,.30,.32,1)
    backdrop.use_nodes=True
    backdrop.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(.27,.30,.32,1)
    ground.data.materials.append(backdrop)
    cam=bpy.data.cameras.new("FMPL | 45 degree lens")
    cam.type="ORTHO";cam.ortho_scale=2.1
    obj=bpy.data.objects.new("FMPL | canonical fixed 45 camera",cam)
    scene.collection.objects.link(obj)
    target=Vector((0,0,.3))
    obj.location=target+Vector((0,-5,5))
    obj.rotation_euler=(target-obj.location).to_track_quat("-Z","Y").to_euler()
    scene.camera=obj
    for pos,energy in (((-4,-5,7),850),((4,2,8),600)):
        light=bpy.data.lights.new("FMPL | fixed sample light","AREA")
        light.energy=energy;light.size=5
        o=bpy.data.objects.new("FMPL | fixed sample light",light)
        scene.collection.objects.link(o)
        o.location=pos
        o.rotation_euler=(target-o.location).to_track_quat("-Z","Y").to_euler()
    scene.render.engine="CYCLES"
    scene.cycles.samples=12
    scene.cycles.device="CPU"
    scene.render.resolution_x=scene.render.resolution_y=384
    scene.render.resolution_percentage=100
    scene.render.film_transparent=False
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.threads_mode="FIXED";scene.render.threads=4
    return scene,node

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--inventory",required=True)
    ap.add_argument("--out",required=True)
    ap.add_argument("--batch-index",type=int,default=0)
    ap.add_argument("--batch-size",type=int,default=64)
    ap.add_argument("--max-source-bytes",type=int,default=12000000)
    args=ap.parse_args(sys.argv[sys.argv.index("--")+1:])
    if not 0<=args.batch_index<=10000 or not 1<=args.batch_size<=128:
        raise ValueError("Bounded FX source-map batch indices only")
    out=Path(args.out).resolve()
    if out.exists() and any(out.iterdir()):
        raise FileExistsError("Never overwrite raw texture gallery outputs")
    out.mkdir(parents=True,exist_ok=True)
    src=candidates(args.inventory)
    lo=args.batch_index*args.batch_size
    work=src[lo:lo+args.batch_size]
    import bpy
    scene,node=make_scene(bpy)
    logs=[]
    thumbs=out/"previews"
    thumbs.mkdir()
    for i,item in enumerate(work,1):
        filename=re.sub(r"[^a-z0-9-]","-",item["repository"].split("/")[-1].lower())+"-"+item["git_blob_sha"][:12]+".png"
        target=thumbs/filename
        tmp=out/("temporary-source"+Path(item["path"]).suffix.lower())
        try:
            original_sha=download(item,tmp,args.max_source_bytes)
            image=bpy.data.images.load(str(tmp),check_existing=False)
            if image.size[0]<=0 or image.size[1]<=0:raise RuntimeError("Invalid or empty original image")
            if node.image is not None and node.image!=image:
                bpy.data.images.remove(node.image,do_unlink=True)
            node.image=image
            scene.render.filepath=str(target)
            scene.frame_set(1)
            bpy.ops.render.render(write_still=True)
            if not target.is_file() or target.stat().st_size<1000:
                raise RuntimeError("No genuine 3D source-map proof")
            record={"source":item,"status":"rendered","file":str(target.relative_to(out)).replace("\\","/"),
                    "render_sha256":sha(target),"original_sha256":original_sha,
                    "render_engine":"Blender Cycles","preview_class":"raw-map-on-sphere-not-PBR",
                    "source_resolution":list(image.size),"user_approval":False}
        except Exception as exc:
            record={"source":item,"status":"blocked","error":str(exc)[:240]}
        finally:
            if tmp.exists():tmp.unlink()
            if node.image is not None:
                bpy.data.images.remove(node.image,do_unlink=True)
                node.image=None
        logs.append(record)
        temp=out/"texture_batch_report.tmp"
        report={"schema":"fmpl.raw-texture-batch.v1","batch_index":args.batch_index,
             "batch_size":args.batch_size,"unique_texture_candidates":len(src),
             "offset":lo,"rendered":sum(x["status"]=="rendered" for x in logs),
             "blocked":sum(x["status"]=="blocked" for x in logs),
             "processed":len(logs),"complete":len(logs)==len(work),"next_offset":lo+len(logs),
             "source_indexes_immutable":True,"not_approved_as_PBR":True,"images":logs}
        temp.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
        temp.replace(out/"texture_batch_report.json")
        print("FMPL_RAW_TEXTURE_PROGRESS",i,len(work),record["status"],item["path"],flush=True)
    cards=[]
    for row in logs:
        srcrow=row["source"]
        label=html.escape(srcrow["path"])
        url=html.escape(srcrow["source_url"],quote=True)
        if row["status"]=="rendered":
            card='<img src="'+html.escape(row["file"],quote=True)+'" alt="'+label+'" loading="lazy">'
        else:card='<p>Blocked: '+html.escape(row["error"])+'</p>'
        cards.append('<article>'+card+'<strong>'+label+'</strong><p>'+html.escape(srcrow["repository"])+'</p><a href="'+url+'">Pinned source</a></article>')
    style="body{background:#11181d;color:#eee;font:13px system-ui;margin:24px}section{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:13px}article{background:#243039;padding:12px;border-radius:8px;overflow-wrap:anywhere}img{width:100%}a{color:#8dd4ed}strong{display:block}"
    (out/"index.html").write_text('<!doctype html><meta charset="utf-8"><title>FMPL Raw Texture Proof Batch</title><style>'+style+'</style><h1>FMPL source texture previews · batch '+str(args.batch_index)+'</h1><p>Authentic Blender renders of source-verified texture maps. Original normal/ORM channel colors are not PBR shading.</p><section>'+"\n".join(cards)+'</section>',encoding="utf-8")
    print("FMPL_RAW_TEXTURE_BATCH_DONE",len(logs),"of",len(src),"unique source textures",flush=True)
if __name__=="__main__":main()
