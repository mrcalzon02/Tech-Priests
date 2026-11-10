#!/usr/bin/env python3
"""Verify one independent, bounded batch of real source-pinned Blender model renders.

No fake previews: every successful card must have an actual RGBA PNG with a
matching SHA-256, and every unrendered item must keep its explicit blocker.
Does not require Blender, PIL, credentials, network, or original source edits.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
from pathlib import Path
import re

def sha(p: Path) -> str:
    h=hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024), b""):
            h.update(chunk)
    return h.hexdigest()

def source_key(item: dict) -> tuple:
    return item.get("repository"),item.get("commit"),item.get("path"),item.get("git_blob_sha")

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--queue",required=True)
    p.add_argument("--out",required=True)
    p.add_argument("--minimum",type=int,default=1)
    args=p.parse_args()
    root=Path(args.out).resolve()
    queue=json.loads(Path(args.queue).read_text(encoding="utf-8"))
    report=json.loads((root/"models_report.json").read_text(encoding="utf-8"))
    if queue.get("schema")!="fmpl.gallery-render-queue.v1" or report.get("schema")!="fmpl.gallery-models.v1":
        raise RuntimeError("Unknown queue/report contract")
    selected=queue["models"]
    rows=report["rows"]
    if report.get("complete") is not True or len(rows)!=len(selected):
        raise RuntimeError("Partial batch: all model source statuses required")
    if not 0<=args.minimum<=len(rows)<=100:
        raise RuntimeError("Invalid proof threshold")
    seen=set()
    passed=blocked=0
    cards=[]
    for selected_source, row in zip(selected,rows):
        source=row.get("source",{})
        if source_key(source)!=source_key(selected_source):
            raise RuntimeError("Rendered row does not match pinned queued model")
        key=source["git_blob_sha"]
        if not re.fullmatch(r"[0-9a-f]{40}",key) or not re.fullmatch(r"[0-9a-f]{40}",source["commit"]):
            raise RuntimeError("Model lacks pinned commit and original Git blob identity")
        if key in seen:
            raise RuntimeError("Duplicate source blob within batch")
        seen.add(key)
        title=html.escape(Path(source["path"]).name)
        repo=html.escape(source["repository"])
        page="https://github.com/"+source["repository"]+"/blob/"+source["commit"]+"/"+source["path"]
        url=html.escape(page,quote=True)
        if row["status"]=="rendered":
            rel=row.get("file","")
            image=root/rel
            if (not rel.startswith("renders/") or not image.is_file() or
                image.suffix.lower()!=".png" or sha(image)!=row.get("render_sha256")):
                raise RuntimeError("Missing/altered actual Blender frame: "+str(rel))
            with image.open("rb") as f:
                if f.read(8)!=b"\\x89PNG\\r\\n\\x1a\\n":
                    raise RuntimeError("Non-PNG despite report: "+rel)
            if row.get("rendered_with")!="Blender Cycles" or not row.get("source_sha256"):
                raise RuntimeError("Model is not an authenticated Blender proof")
            passed+=1
            preview='<img loading="lazy" src="'+html.escape(rel,quote=True)+'" alt="'+title+'">'
            tag="rendered"
        elif row["status"]=="blocked":
            if not row.get("error"):
                raise RuntimeError("Unrendered model has no blocker")
            blocked+=1
            preview='<div class="pending">BLOCKED — no fabricated image</div>'
            tag="blocked"
        else:
            raise RuntimeError("Unknown render outcome")
        reason=html.escape(str(row.get("error",""))[:160])
        cards.append('<article>'+preview+'<h2>'+title+'</h2><small>'+repo+' | '+tag+'</small>'+
                     ('<p>'+reason+'</p>' if reason else '')+
                     '<p><a href="'+url+'" target="_blank" rel="noopener noreferrer">Pinned source</a></p></article>')
    if passed!=report.get("rendered") or blocked!=report.get("blocked") or passed<args.minimum:
        raise RuntimeError("Render counts do not match source report or minimum")
    style="""<style>body{background:#111821;color:#f1f2ed;font-family:system-ui, sans-serif;margin:2rem}
    .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:16px}
    article{background:#202b37;padding:12px;border-radius:10px;overflow-wrap:anywhere}
    img{display:block;width:100%;object-fit:contain;aspect-ratio:1;background:#2b3540}
    .pending{padding:70px 10px;background:#3c302b;text-align:center}
    h2{font-size:15px}small{color:#adb5c2}a{color:#9ee6f1}</style>"""
    body='<!doctype html><html lang="en"><head><meta charset="UTF-8"><title>FMPL verified model batch</title>'+style+'</head><body>'
    body+='<h1>FMPL — source-pinned models</h1><p>'+str(passed)+' Blender previews; '+str(blocked)+' explicitly blocked. Original sources unchanged.</p><section class="grid">'
    body+="".join(cards)+"</section></body></html>"
    index=root/"index.html"
    if index.exists():raise FileExistsError("Refusing to overwrite batch index")
    index.write_text(body,encoding="utf-8")
    summary={"schema":"fmpl.model-batch-verify.v1","passed":True,"source_queue_sha256":sha(Path(args.queue)),
             "requested":len(selected),"rendered_proofs":passed,"blocked_with_reasons":blocked,
             "source_commit_pinned":True,"source_blob_ids_verified":True,
             "images_sha256_verified":True,"gallery_index":"index.html","gallery_index_sha256":sha(index),
             "owner_approved":False,"game_integrated":False}
    receipt=root/"model_batch_verify.json"
    if receipt.exists():raise FileExistsError("Verification receipt already exists")
    receipt.write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
    print("FMPL_MODEL_BATCH_PROOF_PASS",passed,"rendered",blocked,"blocked")
if __name__=="__main__":
    main()
