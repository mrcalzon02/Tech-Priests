#!/usr/bin/env python3
"""FMPL account-wide read-only GitHub asset census.

Scans the exact public repository allowlist, pins full source commits, and
indexes EVERY image/model path including historical duplicates. Never treats a
sprite frame or a Blender backup as a new approved material/model.
No Blender, PIL, workflow creation, source mutation, or third-party downloads.
"""
from __future__ import annotations
import argparse
import collections
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

MODEL_EXT={".blend",".blend1",".fbx",".glb",".gltf",".obj",".stl",".ply"}
IMAGE_EXT={".png",".jpg",".jpeg",".webp",".tga",".tif",".tiff",".dds",".exr",".hdr",".bmp",".ktx",".ktx2"}
MAP_MARKERS=("albedo","diffuse","roughness","metallic","metalness","normal","_orm","-orm","_ao","-ao",
             "ambient-occlusion","heightmap","displacement","emissive","emission","specular","_bump","-bump")
SPRITE_MARKERS=("graphics/","sprites/","/icons/","/frames/","/atlases/","/textures/gui/",
                "/textures/ui/","/textures/icons/")
PROOF_MARKERS=("proof","preview","contact-sheet","gallery","screenshot","render_","render-")
SCAN_EXT=MODEL_EXT|IMAGE_EXT|{".mtl"}
MAX_TREE_REQUESTS=160

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

class Fetch:
    def __init__(self,max_calls=MAX_TREE_REQUESTS):
        self.calls=0
        self.max_calls=max_calls
        self.token=os.environ.get("GITHUB_TOKEN","").strip()
        self.errors=[]
    def get(self,url):
        if self.calls>=self.max_calls:
            raise RuntimeError("GitHub inventory bounded request budget exhausted")
        self.calls+=1
        headers={"Accept":"application/vnd.github+json","User-Agent":"FMPL-gallery-source-census/1.0",
                 "X-GitHub-Api-Version":"2022-11-28"}
        if self.token: headers["Authorization"]="Bearer "+self.token
        for attempt,delay in enumerate((0,2,6)):
            if delay:time.sleep(delay)
            try:
                with urlopen(Request(url,headers=headers),timeout=40) as response:
                    data=response.read(40_000_000)
                    if len(data)>=40_000_000:raise RuntimeError("Oversized GitHub tree; refuse truncation")
                    return json.loads(data)
            except HTTPError as e:
                if e.code in (404,409):
                    raise
                if e.code not in (429,500,502,503,504):raise
                if attempt==2:raise
            except (URLError,TimeoutError):
                if attempt==2:raise
        raise RuntimeError("Unreachable GitHub source: "+url)

def role(path):
    name=path.lower().replace("\\","/")
    suffix=Path(name).suffix
    if suffix==".mtl":return "material-definition"
    if suffix in MODEL_EXT:
        if suffix==".blend1":return "model-backup"
        if suffix==".blend":return "native-model"
        return "interchange-model"
    if any(token in Path(name).stem for token in MAP_MARKERS):
        return "material-map"
    if "/textures/" in "/"+name or "/materials/" in "/"+name or name.startswith("textures/"):
        if "/textures/gui/" not in name and "/textures/ui/" not in name:
            return "texture-image"
    if any(s in name for s in PROOF_MARKERS):return "render-proof"
    if any(s in name for s in SPRITE_MARKERS):return "sprite-or-atlas"
    return "other-image"

def collect_tree(fetcher,repository,commit):
    root=f"https://api.github.com/repos/{repository}/git/trees/"
    first=fetcher.get(root+commit+"?recursive=1")
    if not first.get("truncated",False):
        return [x for x in first.get("tree",[]) if x.get("type")=="blob"],True,1
    blobs=[]
    complete=True
    scanned=0
    def walk(sha,prefix="",depth=0):
        nonlocal complete,scanned
        if depth>9 or fetcher.calls>=fetcher.max_calls:
            complete=False;return
        try:
            data=fetcher.get(root+sha+"?recursive=1")
        except Exception as e:
            complete=False;fetcher.errors.append({"repository":repository,"path":prefix,"error":str(e)[:250]});return
        scanned+=1
        if data.get("truncated"):
            try:
                direct=fetcher.get(root+sha)
            except Exception as e:
                complete=False;fetcher.errors.append({"repository":repository,"path":prefix,"error":str(e)[:250]});return
            scanned+=1
            for x in direct.get("tree",[]):
                if x.get("type")=="blob":
                    item=dict(x);item["path"]=prefix+x["path"];blobs.append(item)
                elif x.get("type")=="tree":walk(x["sha"],prefix+x["path"]+"/",depth+1)
        else:
            for x in data.get("tree",[]):
                if x.get("type")=="blob":
                    item=dict(x);item["path"]=prefix+x["path"];blobs.append(item)
    walk(commit)
    return blobs,complete,scanned

def source_url(repo,commit,path):
    return f"https://github.com/{repo}/blob/{commit}/{quote(path,safe='/')}"

def rank_model(item):
    repo=item["repository"]
    path=item["path"]
    ext=Path(path).suffix.lower()
    prefix=0 if repo.endswith("/Tanks-for-bob-Fork") and path.startswith("models/island-survival/obj/") and ext==".obj" else 1
    pri={"Tech-Priests":2,"The-Beckenburg-Project":3,"HB-TTRPG-tools":4,
         "Magenheim":5,"The-Malefic-Veil":6,"ReverieVR":7}
    group=pri.get(repo.rsplit("/",1)[-1],10)
    if ext==".blend1":return (90,group,path)
    if prefix==0:return (0,0,path)
    if ext==".blend":return (12,group,path)
    return (group,0 if ext==".glb" else 1,path)

def select_models(model_list,cap):
    selected=[];selected_keys=set()
    def add(item):
        if len(selected)>=cap:return False
        key=(item["repository"],item["path"])
        if key in selected_keys:return False
        selected_keys.add(key);selected.append(item);return True
    # Complete Tanks blockout cohort first: 21 authored 3D meshes, not sprites.
    for item in sorted(model_list,key=rank_model):
        if item["repository"]=="mrcalzon02/Tanks-for-bob-Fork" and item["path"].startswith("models/island-survival/obj/") and item["path"].endswith(".obj"):
            if (item.get("size_bytes") or 0)<3_000_000:add(item)
    # Diverse verified repository sample. Favor GLB/OBJ over costlier native scenes.
    counts=collections.Counter()
    for item in sorted(model_list,key=rank_model):
        if len(selected)>=cap:break
        repo=item["repository"].split("/")[-1]
        if counts[repo]>=3:continue
        size=item.get("size_bytes") or 0
        if not 1024<=size<=5_000_000:continue
        if Path(item["path"]).suffix.lower() not in (".glb",".obj",".fbx",".gltf"):continue
        if repo=="Tanks-for-bob-Fork":continue
        if add(item):counts[repo]+=1
    return selected

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--sources",required=True)
    parser.add_argument("--out",required=True)
    parser.add_argument("--max-models",type=int,default=36)
    parser.add_argument("--max-calls",type=int,default=160)
    opts=parser.parse_args()
    if not 1<=opts.max_models<=100 or not 25<=opts.max_calls<=350:
        raise ValueError("FMPL census budget outside bounded range")
    source=Path(opts.sources).resolve()
    seeds=json.loads(source.read_text(encoding="utf-8"))
    if seeds.get("schema")!="fmpl.account-gallery.sources.v1":
        raise ValueError("Unknown source allowlist")
    root=Path(opts.out).resolve()
    if root.exists() and any(root.iterdir()):
        raise FileExistsError("Refusing to overwrite census output")
    root.mkdir(parents=True,exist_ok=True)
    fetcher=Fetch(opts.max_calls)
    totals=collections.Counter()
    sha_occurrences=collections.Counter()
    dependency_mtls={}
    summaries=[]
    renderable=[]
    for n,source_spec in enumerate(seeds["sources"],1):
        repo=source_spec["repo"]
        ref=source_spec["ref"]
        if not re.fullmatch(r"mrcalzon02/[A-Za-z0-9_.-]+",repo) or ref not in ("main","master"):
            raise ValueError("Untrusted repository/ref in account allowlist")
        info={"repository":repo,"ref":ref,"status":"started","source_commit":None,
              "complete":False,"tree_calls":0,"indexed_assets":0,"roles":{}}
        try:
            if source_spec.get("status")=="empty-repository":
                info["status"]="empty";info["complete"]=True
                summaries.append(info);continue
            metadata=fetcher.get(f"https://api.github.com/repos/{repo}/commits/{ref}")
            commit=metadata.get("sha")
            if not isinstance(commit,str) or not re.fullmatch("[a-f0-9]{40}",commit):
                raise RuntimeError("No exact source commit for "+repo)
            info["source_commit"]=commit
            before=fetcher.calls
            tree,complete,tree_calls=collect_tree(fetcher,repo,commit)
            info["complete"]=complete;info["tree_calls"]=fetcher.calls-before
            rows=[]
            seen=set()
            for item in tree:
                path=item.get("path","")
                extension=Path(path).suffix.lower()
                if extension not in SCAN_EXT:continue
                key=(path,item.get("sha"))
                if key in seen:continue
                seen.add(key)
                item_role=role(path)
                if path=="models/island-survival/obj/survival-materials.mtl":
                    dependency_mtls[repo]=item.get("sha")
                entry={"repository":repo,"commit":commit,"path":path,"git_blob_sha":item.get("sha"),
                       "size_bytes":item.get("size",0),"role":item_role,
                       "render_status":"not-rendered","source_url":source_url(repo,commit,path)}
                rows.append(entry)
                totals[item_role]+=1
                info["roles"][item_role]=info["roles"].get(item_role,0)+1
                if item.get("sha"):sha_occurrences[item["sha"]]+=1
                if item_role in ("native-model","interchange-model","model-backup"):renderable.append(entry)
            rows.sort(key=lambda x:x["path"])
            safe=repo.replace("/","__")
            path=root/(safe+".jsonl.gz")
            with gzip.open(path,"wt",encoding="utf-8",compresslevel=6) as fp:
                for row in rows:fp.write(json.dumps(row,separators=(",",":"))+"\n")
            info.update({"status":"scanned" if complete else "partial-tree","indexed_assets":len(rows),
                         "index_file":path.name,"index_sha256":digest(path),"tree_entries":len(tree)})
        except Exception as e:
            info["status"]="blocked";info["error"]=str(e)[:250]
            fetcher.errors.append({"repository":repo,"error":str(e)[:250]})
        summaries.append(info)
        # Durable checkpoint after every repository; a subsequent explicit job
        # may inspect the last successful census even if later network calls fail.
        (root/"progress.json").write_text(json.dumps({
            "schema":"fmpl.account-gallery.progress.v1","repositories_scanned":n,
            "requests":fetcher.calls,"completed":sum(s["status"]=="scanned" for s in summaries),
            "partial":sum(s["status"]=="partial-tree" for s in summaries)},indent=2)+"\n",encoding="utf-8")
        print("FMPL_GALLERY_REPO_SCAN",n,len(seeds["sources"]),repo,info["status"],
              info.get("indexed_assets",0),flush=True)
    selections=select_models(renderable,opts.max_models)
    for rec in selections:
        if rec["repository"] in dependency_mtls and rec["path"].endswith(".obj"):
            rec["mtl_blob_sha"]=dependency_mtls[rec["repository"]]
    render_queue={"schema":"fmpl.gallery-render-queue.v1","initial_model_cap":opts.max_models,
                  "models":selections,"all_model_files":len(renderable)}
    (root/"render_queue.json").write_text(json.dumps(render_queue,indent=2)+"\n",encoding="utf-8")
    summary={"schema":"fmpl.account-gallery.inventory.v1",
             "source_manifest_sha256":digest(source),"repository_count":len(summaries),
             "fully_scanned_repositories":sum(x["status"]=="scanned" for x in summaries),
             "partial_repositories":sum(x["status"]=="partial-tree" for x in summaries),
             "blocked_repositories":sum(x["status"]=="blocked" for x in summaries),
             "empty_repositories":sum(x["status"]=="empty" for x in summaries),
             "github_api_requests":fetcher.calls,
             "roles":dict(sorted(totals.items())),
             "indexed_assets":sum(x.get("indexed_assets",0) for x in summaries),
             "duplicate_git_blob_paths":sum(n-1 for n in sha_occurrences.values() if n>1),
             "distinct_git_blobs":len(sha_occurrences),
             "queued_initial_models":len(selections),
             "model_source_total":len(renderable),
             "repositories":summaries,
             "errors":fetcher.errors,"render_is_complete_for_every_source":False}
    (root/"summary.json").write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
    print("FMPL_GALLERY_ACCOUNT_CENSUS",summary["indexed_assets"],"assets",
          summary["model_source_total"],"model files",summary["queued_initial_models"],
          "queued",summary["blocked_repositories"],"blocked",flush=True)
    if summary["fully_scanned_repositories"]+summary["partial_repositories"]<3:
        raise RuntimeError("Too few source repositories scanned for a meaningful gallery")

if __name__=="__main__":main()
