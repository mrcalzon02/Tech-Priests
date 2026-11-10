#!/usr/bin/env python3
"""Bundle independently VERIFIED FMPL gallery ZIPs into one offline library.

No external downloads, no rerendering, no fake assets, no source mutation.
Input: portable base 76-material/36-model ZIP, any number of verified raw
texture/model continuation ZIPs. Output: one portable cross-batch HTML index.
"""
from __future__ import annotations
import argparse
import hashlib
import html
import json
from pathlib import Path, PurePosixPath
import re
import zipfile

def sha(data):return hashlib.sha256(data).hexdigest()
def load(zipobj):
    files={}
    for item in zipobj.infolist():
        if item.is_dir():continue
        norm=item.filename.replace("\\","/")
        parts=PurePosixPath(norm).parts
        if not norm or norm.startswith("/") or ".." in parts or any(":" in x for x in parts):
            raise ValueError("Unsafe archive member: "+item.filename)
        if norm in files:raise ValueError("Archive path collision: "+norm)
        files[norm]=zipobj.read(item.filename)
    # Dens Mortis packages model runs with a one-folder base name. Normalize it
    # without changing source bytes or allowing arbitrary path traversal.
    if "models/models_report.json" not in files:
        roots={name.split("/",1)[0] for name in files if "/" in name}
        if len(roots)==1 and next(iter(roots)).startswith("fmpl-models-batch-"):
            root=next(iter(roots))+"/"
            if all(name.startswith(root) for name in files):
                files={name[len(root):]:blob for name,blob in files.items()}
    return files
def read_json(blob):
    return json.loads(blob.decode("utf-8"))
def require(files,key):
    if key not in files:raise ValueError("Expected verified asset missing: "+key)
    return files[key]
def verify_base(files):
    proof=read_json(require(files,"gallery/gallery_verify.json"))
    if not proof.get("passed") or proof.get("registered_materials_reopened")!=76 or proof.get("model_proofs_hash_verified")!=36:
        raise RuntimeError("First gallery lacks independently validated 76+36 source proofs")
    if "gallery/index.html" not in files:raise RuntimeError("Offline HTML gallery index missing")
    return {"materials":76,"models":36,"sha256":sha(files["gallery/gallery_verify.json"])}
def verify_textures(files,seen):
    receipt=read_json(require(files,"texture_batch_verify.json"))
    report=read_json(require(files,"texture_batch_report.json"))
    if not receipt.get("passed") or report.get("rendered")!=receipt.get("verified_blender_images"):
        raise RuntimeError("Raw texture batch has no passing independent PNG proof")
    for row in report["images"]:
        if row["status"]!="rendered":continue
        name=row["file"]
        if name not in files or sha(files[name])!=row["render_sha256"]:
            raise RuntimeError("Altered source texture Blender preview: "+name)
        blob=row["source"]["git_blob_sha"]
        if blob in seen:raise RuntimeError("Raw source texture rendered twice across batches")
        seen.add(blob)
    if "index.html" not in files:raise RuntimeError("No texture browser index")
    return {"batch":receipt["batch_index"],"rendered":receipt["verified_blender_images"],
            "remaining":receipt["remaining_unique_source_textures"]}
def verify_models(files,seen):
    report=read_json(require(files,"models/models_report.json"))
    receipt=read_json(require(files,"models/model_batch_verify.json"))
    if not receipt.get("passed") or report.get("rendered")!=receipt.get("rendered_proofs"):
        raise RuntimeError("Model continuation not independently verified")
    if report.get("blocked")!=receipt.get("blocked_with_reasons") or not report.get("complete"):
        raise RuntimeError("Model batch hides incomplete/blocked models")
    for row in report["rows"]:
        blob=row["source"]["git_blob_sha"]
        prior=seen.get(blob)
        if prior=="rendered":
            raise RuntimeError("Model source already had a genuine rendered preview")
        if prior=="blocked" and row["status"]!="rendered":
            raise RuntimeError("Repeated blocked source without a verified recovery render")
        if prior is None or row["status"]=="rendered":
            seen[blob]=row["status"]
        if row["status"]=="rendered":
            rel="models/"+row["file"]
            if rel not in files or sha(files[rel])!=row["render_sha256"]:
                raise RuntimeError("Missing genuine Blender model preview "+rel)
        elif not row.get("error"):
            raise RuntimeError("Unrendered source lacks a real blocker")
    if "models/index.html" not in files:raise RuntimeError("No model batch browser index")
    return {"rendered":receipt["rendered_proofs"],"blocked":receipt["blocked_with_reasons"]}
def write_entries(output,archive,files,prefix):
    for name,data in files.items():
        dest=prefix+name
        if dest in output:raise RuntimeError("Two verified bundles have colliding paths")
        output[dest]=data
def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--base",required=True)
    ap.add_argument("--textures",action="append",default=[])
    ap.add_argument("--models",action="append",default=[])
    ap.add_argument("--out",required=True)
    args=ap.parse_args()
    out=Path(args.out).resolve()
    if out.exists():raise FileExistsError("Never overwrite consolidated library")
    if len(args.models)>100 or len(args.textures)>100:raise ValueError("Unbounded bundle merge")
    bundled={}
    provenance=[]
    seen_texture=set()
    seen_models={}
    with zipfile.ZipFile(args.base) as zipped:
        files=load(zipped)
    baseline=verify_base(files)
    write_entries(bundled,args.base,files,"canonical/")
    provenance.append({"kind":"canonical","source":Path(args.base).name,"sha256":sha(Path(args.base).read_bytes()),"result":baseline})
    links=[("Canonical FMPL material/model gallery","canonical/gallery/index.html","76 materials; 36 original 3D model proofs")]
    ntex=nmod=nblocked=0
    for i,entry in enumerate(args.textures):
        with zipfile.ZipFile(entry) as z:items=load(z)
        proof=verify_textures(items,seen_texture)
        write_entries(bundled,entry,items,f"raw-textures/batch-{proof['batch']:04d}/")
        links.append((f"Raw source texture batch {proof['batch']} ",f"raw-textures/batch-{proof['batch']:04d}/index.html",
                      f"{proof['rendered']} real Blender previews, 0 invented PBR approvals"))
        provenance.append({"kind":"raw-texture","source":Path(entry).name,"sha256":sha(Path(entry).read_bytes()),"result":proof})
        ntex+=proof["rendered"]
    for i,entry in enumerate(args.models):
        with zipfile.ZipFile(entry) as z:items=load(z)
        proof=verify_models(items,seen_models)
        write_entries(bundled,entry,items,f"model-batches/batch-{i:04d}/")
        links.append((f"Additional 3D model batch {i}",f"model-batches/batch-{i:04d}/models/index.html",
                      f"{proof['rendered']} real Blender previews; {proof['blocked']} documented blockers"))
        provenance.append({"kind":"model-continuation","source":Path(entry).name,"sha256":sha(Path(entry).read_bytes()),"result":proof})
        nmod+=proof["rendered"];nblocked+=proof["blocked"]
    # A verified targeted retry can resolve prior documented size blockers.
    nblocked=sum(1 for status in seen_models.values() if status=="blocked")
    parts=["<!doctype html><html lang='en'><head><meta charset='utf-8'>",
           "<title>FMPL complete verified render gallery</title>",
           "<style>body{background:#131b22;color:#f4f4ef;font-family:system-ui;margin:4% auto;max-width:920px;padding:20px}a{color:#92dfe4}article{padding:18px;margin:12px 0;background:#263442;border-radius:12px}small{color:#bcc9d0}</style>",
           "</head><body><h1>FMPL — Rendered Library</h1>",
           f"<p><b>{76+ntex}</b> canonical/raw texture previews; <b>{36+nmod}</b> distinct source model previews; <b>{nblocked}</b> additional explicit source blockers.</p>",
           "<p>This index links only to independently verified Blender images. The full GitHub census also records unrendered files and source histories; it is not approval for game use.</p>"]
    for title,link,detail in links:
        parts.append("<article><h2><a href='"+html.escape(link,quote=True)+"'>"+html.escape(title)+"</a></h2><small>"+html.escape(detail)+"</small></article>")
    parts.append("</body></html>")
    bundled["index.html"]="\n".join(parts).encode("utf-8")
    manifest={"schema":"fmpl.gallery-combined.v1","base_verified":baseline,"supplemental_model_renders":nmod,
              "supplemental_texture_previews":ntex,"supplemental_blocked_models":nblocked,
              "all_source_models_rendered":False,"all_source_textures_rendered":False,
              "owner_approved":False,"factorio_integrated":False,"sources":provenance}
    bundled["combined_manifest.json"]=(json.dumps(manifest,indent=2)+"\n").encode("utf-8")
    out.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(out,"w",zipfile.ZIP_DEFLATED,compresslevel=6) as target:
        for name in sorted(bundled):
            target.writestr(name,bundled[name])
    print("FMPL_COMBINED_GALLERY_VERIFIED",76+ntex,36+nmod,len(bundled),sha(out.read_bytes()))
if __name__=="__main__":
    main()
