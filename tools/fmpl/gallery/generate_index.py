#!/usr/bin/env python3
"""Static, offline-browsable FMPL gallery from genuine Blender proof receipts.

The index never invents images and always exposes unrendered source coverage.
"""
from __future__ import annotations
import argparse
from collections import Counter
from datetime import datetime,timezone
import hashlib
import html
import json
from pathlib import Path
import sys
from urllib.parse import quote

def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def h(text):
    return html.escape(str(text),quote=True)

def card(title,description,tag,image=None,source=None,meta=None):
    parts=['<article class="entry" data-filter="'+h(" ".join((title,description,tag)))+'">']
    if image:parts.append('<img loading="lazy" src="'+h(image)+'" alt="'+h(title)+'">')
    else:parts.append('<div class="unrendered">NO VERIFIED RENDER</div>')
    parts.append('<div class="details"><strong>'+h(title)+'</strong><span class="pill">'+h(tag)+'</span>')
    if meta:parts.append('<small>'+h(meta)+'</small>')
    parts.append('<p>'+h(description)+'</p>')
    if source:parts.append('<a href="'+h(source)+'" target="_blank" rel="noopener noreferrer">Source at pinned GitHub commit</a>')
    parts.append('</div></article>')
    return "\n".join(parts)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--root",required=True)
    ap.add_argument("--fmpl",required=True)
    ap.add_argument("--fmpl-commit",required=True)
    args=ap.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else sys.argv[1:])
    root=Path(args.root).resolve()
    invent=read(root/"inventory/summary.json")
    mats=read(root/"materials/materials_report.json")
    models=read(root/"models/models_report.json")
    lib=read(Path(args.fmpl)/"tools/fmpl/FMPL.json")
    if invent["schema"]!="fmpl.account-gallery.inventory.v1" or mats["material_count"]!=76 or models["schema"]!="fmpl.gallery-models.v1":
        raise RuntimeError("Gallery cannot be built from incomplete or foreign receipts")
    if not mats["passed"] or not Path(root/"materials"/mats["contact_file"]).is_file():
        raise RuntimeError("Material contact render missing")
    if len(mats["individuals"])!=mats["individual_render_count"]:
        raise RuntimeError("Individual material proof manifest incomplete")
    for row in mats["individuals"]:
        path=root/"materials"/row["native_render"]
        if not path.is_file() or sha(path)!=row["render_sha256"]:
            raise RuntimeError("Unverified material render: "+row["id"])
    for row in models["rows"]:
        if row["status"]=="rendered":
            path=root/"models"/row["file"]
            if not path.is_file() or sha(path)!=row["render_sha256"]:
                raise RuntimeError("Unverified model image: "+str(path))
    if not len(args.fmpl_commit)==40:raise RuntimeError("Unpinned FMPL source")
    mats_html=[]
    material_data=[]
    for row in mats["individuals"]:
        source="https://github.com/mrcalzon02/Tech-Priests/blob/"+args.fmpl_commit+"/"+quote(row["source"],safe="/")
        mats_html.append(card(row["id"],row["family"],row["kind"],
                              "materials/"+row["native_render"],source,
                              "FMPL "+str(row.get("source_version") or "PBR")))
        material_data.append({k:v for k,v in row.items() if k!="material_datablock"})
    models_html=[]
    model_data=[]
    for row in models["rows"]:
        source=row["source"]
        status=row["status"]
        models_html.append(card(Path(source["path"]).name,
            source["repository"].split("/")[-1]+" / "+source["path"],
            "3D "+status,
            "models/"+row["file"] if status=="rendered" else None,
            source["source_url"],
            "Source Git blob "+str(source["git_blob_sha"])[:12]))
        model_data.append(row)
    inventory_html=[]
    for rec in invent["repositories"]:
        desc=rec.get("roles",{})
        counts=" / ".join("%s:%s"%(k,v) for k,v in sorted(desc.items()) if v)
        link='<a href="inventory/'+h(rec["index_file"])+'">Full indexed source paths (JSONL.gz)</a>' if rec.get("index_file") else "No source index"
        inventory_html.append('<tr><td>'+h(rec["repository"])+'</td><td>'+h(rec["status"])+'</td><td>'+
            h(rec.get("source_commit") or "—")[:13]+'</td><td>'+str(rec["indexed_assets"])+
            '</td><td>'+h(counts)+'</td><td>'+link+'</td></tr>')
    parts=lib["inventory"].get("component_candidates_total",0)
    private_greebles=lib["inventory"].get("greebles_unclassified_mesh_candidates",0)
    material_complete=(mats["individual_render_count"]==mats["material_count"])
    catalog={
       "schema":"fmpl.github-gallery.v1","generated_utc":datetime.now(timezone.utc).isoformat(),
       "source_fmpl_commit":args.fmpl_commit,"rendered_materials":len(material_data),
       "canonical_materials":mats["material_count"],"all_materials_rendered":material_complete,
       "rendered_models":models["rendered"],"initial_model_batch":models["requested"],
       "blocked_models":models["blocked"],"all_indexed_model_files":invent["model_source_total"],
       "source_image_files":sum(value for key,value in invent["roles"].items() if "image" in key or key in ("render-proof","sprite-or-atlas","material-map")),
       "model_render_complete":models["rendered"]==invent["model_source_total"],
       "parts_candidates_unapproved":parts,"private_greebles_unapproved":private_greebles,
       "repositories_indexed":invent["fully_scanned_repositories"],
       "partial_repository_inventories":invent["partial_repositories"],
       "blocked_repository_inventories":invent["blocked_repositories"],
       "exact_binary_duplicates_detected":invent["duplicate_git_blob_paths"],
       "inventories_in":"inventory/*.jsonl.gz","materials":material_data,"models":model_data,
       "source_repositories":invent["repositories"],"visual_approval":False,
       "live_factorio_graphics_modified":False,
       "note":"All materials in the canonical 76-entry registry can be rendered; unrendered image paths and models remain in separate source catalogs."}
    index=root/"catalog.json"
    if index.exists():raise FileExistsError("Refusing to replace catalog")
    index.write_text(json.dumps(catalog,indent=2)+"\n",encoding="utf-8")
    style="""
body{background:#10151a;color:#e7edf2;font:14px system-ui,sans-serif;margin:0;padding:22px}
h1{margin:0 0 6px;font-size:25px}h2{font-size:20px;margin:26px 0 12px}
a{color:#8ec9eb}small{color:#adbcca}.subtitle{color:#a8b6c0}
.statline{margin:14px 0;padding:10px 0;border-top:1px solid #384955;border-bottom:1px solid #384955}
.statline b{padding-right:18px}input{width:min(680px,95%);border-radius:9px;padding:11px;
background:#1d2932;color:white;border:1px solid #445968}
.gallery{display:grid;grid-template-columns:repeat(auto-fill,minmax(225px,1fr));gap:12px}
.entry{background:#1c252c;border:1px solid #394852;border-radius:10px;overflow:hidden}
.entry img{width:100%;aspect-ratio:1;object-fit:contain;background:#28313a}
.details{padding:12px}.details strong{display:block;word-break:break-word}
.details p{color:#adb6bf;overflow-wrap:anywhere}.details a{font-size:12px}
.pill{display:inline-block;margin:6px 0;color:#fff;background:#344d5c;border-radius:5px;padding:3px 7px}
.unrendered{height:115px;display:grid;place-items:center;color:#a8b7c3;background:#27313b}
table{width:100%;border-collapse:collapse;font-size:12px}td,th{border-bottom:1px solid #38434b;padding:7px;text-align:left}
table{display:block;overflow-x:auto}footer{margin-top:35px;color:#9baab5}
"""
    doc='<!doctype html>\n<html lang="en"><head><meta charset="UTF-8"><title>FMPL GitHub Rendered Asset Library</title>'
    doc+='<meta name="viewport" content="width=device-width,initial-scale=1"><style>'+style+'</style></head><body>'
    doc+='<h1>FMPL · GitHub rendered asset library</h1><p class="subtitle">Pinned, source-linked materials · models · parts. Missing proof is never replaced by a fictional render.</p>'
    doc+='<div class="statline"><b>Materials '+str(len(material_data))+'/76</b><b>Models '+str(models["rendered"])+'/'+str(invent["model_source_total"])+'</b>'
    doc+='<b>Unapproved parts '+str(parts)+'</b><b>Repositories scanned '+str(invent["fully_scanned_repositories"])+'/'+str(invent["repository_count"])+'</b></div>'
    doc+='<p><input id="search" placeholder="Search materials, models, families or repository paths" aria-label="Gallery search"></p>'
    doc+='<h2>Materials · genuine Blender samples</h2><p class="subtitle">76 canonical material definitions: 23 image PBR, 28 procedural effects, 25 procedural surfaces.</p>'
    doc+='<p><a href="materials/'+h(mats["contact_file"])+'">Full 76-material contact sheet</a> · <a href="catalog.json">Catalog JSON</a></p>'
    doc+='<section class="gallery">\n'+"\n".join(mats_html)+'</section>'
    doc+='<h2>Models · pinned source and independently rendered proof</h2><p class="subtitle">First bounded cohort is not the complete 3D collection. All remaining models retain a source inventory entry.</p>'
    doc+='<section class="gallery">\n'+"\n".join(models_html)+'</section>'
    doc+='<h2>Reusable parts · pending provenance</h2><p>FMPL indexes '+str(parts)+' candidate parts and '+str(private_greebles)+' unclassified private donor meshes. Those are <strong>not rendered or approved</strong> until native source and use rights are verified.</p>'
    doc+='<h2>Complete GitHub source inventory</h2><p>The following inventories include every recognized image and 3D source path, including historical sprites, atlases and duplicate files.</p>'
    doc+='<table><thead><tr><th>Repository</th><th>Scan status</th><th>Pinned commit</th><th>Assets</th><th>Classification</th><th>Full asset records</th></tr></thead><tbody>'
    doc+="\n".join(inventory_html)+'</tbody></table>'
    doc+='<footer>All user-approval, simulation, prototype linkage and unresolved source ownership gates remain open. Generated from verified local render manifests.</footer>'
    doc+="""<script>
const search=document.querySelector('#search');
search.addEventListener('input',()=>{
 const s=search.value.toLowerCase().trim();
 document.querySelectorAll('.entry').forEach(x=>{
  x.style.display=(!s||x.dataset.filter.toLowerCase().includes(s))?'':'none';
 });
});
</script></body></html>"""
    (root/"index.html").write_text(doc,encoding="utf-8")
    summary=("# FMPL Gallery — run receipt\n\n"
        +f"Cataloged {invent['indexed_assets']} asset paths across {invent['repository_count']} public repositories.\n\n"
        +f"Rendered {len(material_data)}/{mats['material_count']} material swatches and {models['rendered']} models (initial batch {models['requested']}; {models['blocked']} blocked).\n\n"
        +f"Source models indexed: {invent['model_source_total']}; exact duplicate source paths: {invent['duplicate_git_blob_paths']}.\n\n"
        +"Unrendered assets remain in inventory JSONL archives. No games or modeling source files were altered.\n")
    (root/"GALLERY_STATUS.md").write_text(summary,encoding="utf-8")
    print("FMPL_GALLERY_OFFLINE_INDEX_BUILT",len(material_data),models["rendered"],invent["indexed_assets"],flush=True)

if __name__=="__main__":main()
