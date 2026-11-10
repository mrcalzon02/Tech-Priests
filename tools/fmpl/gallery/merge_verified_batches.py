#!/usr/bin/env python3
"""Merge independently checked FMPL GitHub asset-gallery batches into one offline index.

All input ZIPs are immutable. Every purported Blender render is verified against
its report's SHA-256, and 3D sources are deduplicated by pinned Git blob SHA.
No third-party assets are downloaded, executed or installed. No original files
are overwritten. Source files and progress reports are preserved verbatim.
"""
from __future__ import annotations
import argparse
import hashlib
import html
import json
import re
from collections import Counter
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def asjson(z: ZipFile, name: str):
    return json.loads(z.read(name))


def clean_path(p: str) -> str:
    return p.replace('\\','/').lstrip('/')


def find_one(z: ZipFile, suffix: str, *, forbidden: tuple[str,...] = ()) -> str:
    names = [n for n in z.namelist() if clean_path(n).endswith(suffix)
             and not any(f in clean_path(n) for f in forbidden)]
    if len(names) != 1:
        raise ValueError(f'Expected one {suffix}; found {len(names)}: {names[:5]}')
    return names[0]


def verify_image(z: ZipFile, entry: str, expected: str) -> bytes:
    raw = z.read(entry)
    if sha256(raw) != expected:
        raise ValueError(f'Image checksum mismatch {entry}')
    if not raw.startswith(b'\x89PNG\r\n\x1a\n'):
        raise ValueError(f'Not a PNG: {entry}')
    return raw


def h(x) -> str:
    return html.escape(str(x), quote=True)


def stage_for_model(source: dict) -> str:
    """Conservative source-stage classification; never infer user approval."""
    p = source.get('path', '').lower().replace('\\', '/')
    if '/obj/' in p and p.endswith('.obj'):
        return 'rough OBJ blockout'
    if 'generated-v' in p or '/alternatives/' in p:
        return 'historical editable/iteration source'
    if '/production-' in p or '/production-source' in p:
        return 'production source candidate'
    if p.endswith('.blend'):
        return 'native Blender source'
    return 'interchange 3D source'


def gallery_html(manifest):
    def card(r, kind):
        image = r['file']
        title = r.get('name') or r['id']
        subtitle = r.get('stage') or r.get('family', '')
        extra = f'<small>{h(r.get("repository", ""))}</small>'
        link = r.get('source_url')
        source = f'<a href="{h(link)}" target="_blank" rel="noopener">Source</a>' if link else ''
        return (f'<article data-kind="{kind}" data-text="{h(" ".join(map(str, (title, subtitle, r.get("repository", ""), r.get("status", ""),r.get("stage", "")))))}">'
                f'<a href="{h(image)}"><img loading="lazy" src="{h(image)}" alt="{h(title)}"></a>'
                f'<strong>{h(title)}</strong><small>{h(subtitle)}</small>{extra}{source}</article>')
    materials = ''.join(card(r, 'material') for r in manifest['materials'])
    models = ''.join(card(r, 'model') for r in manifest['models'])
    textures = ''.join(card(r, 'texture') for r in manifest['textures'])
    blocked = ''.join(f'<tr><td>{h(r["source"].get("repository"))}</td><td>{h(r["source"].get("path"))}</td><td>{h(r.get("error"))}</td></tr>' for r in manifest['blocked_models'])
    return f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>FMPL Verified Asset Library</title><style>body{{margin:0;background:#131820;color:#e3e9ee;font:15px/1.4 system-ui,sans-serif}}header{{position:sticky;top:0;background:#19212cf5;padding:17px 25px;z-index:4;border-bottom:1px solid #374252}}h1{{font-size:23px;margin:0 0 6px}}p{{margin:5px 0;color:#abb7c5}}input,button{{font:inherit;border:1px solid #4a5869;padding:9px 14px;border-radius:7px;background:#263244;color:#fff}}button.active{{background:#3a5878}}main{{padding:18px 25px}}#cards{{display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));gap:12px}}article{{min-width:0;background:#1d2632;border:1px solid #3a4654;border-radius:10px;padding:8px;display:flex;flex-direction:column;gap:5px;overflow:hidden}}article img{{width:100%;aspect-ratio:1;object-fit:contain;background:#343e4b}}strong{{overflow-wrap:anywhere}}small{{font-size:12px;color:#b6c6d6;overflow-wrap:anywhere}}article a{{color:#9acaff}}article[hidden]{{display:none}}table{{border-collapse:collapse;width:100%;overflow-wrap:anywhere}}td,th{{border-bottom:1px solid #445063;padding:7px;text-align:left}}.controls{{display:flex;gap:8px;flex-wrap:wrap;margin:12px 0}}.note{{margin:12px 0 24px}}footer{{padding:20px;color:#9cacbb}}a{{color:#9acaff}}</style></head><body>
<header><h1>FMPL · verified rendered asset library</h1><p>{len(manifest['materials'])} materials · {len(manifest['models'])} 3D models · {len(manifest['textures'])} source textures · {manifest['inventory']['indexed_assets']:,} GitHub asset paths indexed</p>
<div class="controls"><button class="active" data-tab="all">All</button><button data-tab="material">Materials</button><button data-tab="model">Models</button><button data-tab="texture">Textures</button><input id="search" type="search" placeholder="Search asset IDs, source repositories…" aria-label="Search"></div></header>
<main><p class="note">Every displayed picture is an existing Blender render whose SHA-256 was checked against its source report. Raw texture-map previews are <b>not</b> PBR approval. Model source variants may share geometry, and original GitHub assets remain unchanged.</p>
<div id="cards">{materials}{models}{textures}</div>
<section><h2>Model blockers — {len(manifest['blocked_models'])}</h2><p>Unavailable/oversized sources are recorded, not represented by artificial thumbnails.</p><table><thead><tr><th>Repository</th><th>Path</th><th>Reason</th></tr></thead><tbody>{blocked}</tbody></table></section>
<p><a href="manifest.json">Full machine-readable manifest</a> · <a href="inventory/summary.json">25-repository inventory receipt</a> · <a href="materials/materials_report.json">76-material verification receipt</a></p>
</main><footer>Technical render verification ≠ user visual approval, game integration or third-party redistributability. Original material catalog and source commits are retained in receipts.</footer>
<script>let tab='all';const q=document.querySelector('#search'),items=[...document.querySelectorAll('article[data-kind]')];function filter(){{let s=q.value.toLowerCase();for(let e of items)e.hidden=(tab!=='all'&&e.dataset.kind!==tab)||!e.dataset.text.toLowerCase().includes(s)}}for(let b of document.querySelectorAll('[data-tab]'))b.addEventListener('click',()=>{{tab=b.dataset.tab;for(let x of document.querySelectorAll('[data-tab]'))x.classList.toggle('active',x===b);filter()}});q.addEventListener('input',filter);</script></body></html>'''


def build(baseline: Path, additionals: list[Path], output: Path):
    if output.exists():
        raise FileExistsError('Cannot overwrite an existing gallery: ' + str(output))
    artifacts = [baseline] + additionals
    if any(not f.is_file() for f in artifacts):
        raise FileNotFoundError('Missing a requested verified source package')
    materials, models, textures, blocked = [], {}, {}, {}
    verification = []
    with ZipFile(output, 'w', compression=ZIP_DEFLATED, compresslevel=6) as out:
        written = set()
        def put(name, raw):
            if name in written: raise ValueError('Duplicate output path: '+name)
            out.writestr(name, raw)
            written.add(name)
        with ZipFile(baseline) as z:
            original = 'canonical/gallery/'
            inventory = asjson(z,original+'inventory/summary.json')
            mr = asjson(z,original+'materials/materials_report.json')
            if mr.get('material_count') != 76 or mr.get('individual_render_count') != 76 or not mr.get('passed'):
                raise ValueError('Baseline 76-material report incomplete')
            if inventory.get('schema')!='fmpl.account-gallery.inventory.v1':
                raise ValueError('Unknown source inventory')
            for item in z.namelist():
                if item.startswith(original+'inventory/') and not item.endswith('/'):
                    put(item[len(original):],z.read(item))
            put('materials/materials_report.json', z.read(original+'materials/materials_report.json'))
            # Actual material source is part of the verified gallery; retaining it makes the bundle editable.
            native_name=mr['master_file']
            native=z.read(original+'materials/'+native_name)
            if sha256(native)!=mr['master_sha256']:raise ValueError('Native .blend material hash mismatch')
            put('materials/'+native_name,native)
            contact=z.read(original+'materials/'+mr['contact_file'])
            if sha256(contact)!=mr['contact_sha256']:raise ValueError('Material contact sheet mismatch')
            put('materials/'+mr['contact_file'],contact)
            fmpl_catalog=asjson(z,original+'catalog.json')
            pin=fmpl_catalog.get('source_fmpl_commit')
            if not isinstance(pin,str) or not re.fullmatch(r'[0-9a-f]{40}',pin):
                raise ValueError('Missing immutable FMPL material source commit')
            for row in mr['individuals']:
                p=original+'materials/'+row['native_render']
                data=verify_image(z,p,row['render_sha256'])
                target='materials/'+row['native_render']
                put(target,data)
                materials.append({'id':row['id'],'name':row['id'],'family':row['family'],
                                  'status':'rendered-unapproved','kind':row['kind'], 'file':target,
                                  'sha256':row['render_sha256'],
                                  'source_path':row['source'],
                                  'source_url':'https://github.com/mrcalzon02/Tech-Priests/blob/'+pin+'/'+row['source']})
            # Preserve source model receipt; all thumbnails link to pinned GitHub source.
            base_report=asjson(z,original+'models/models_report.json')
            if base_report.get('rendered')!=36: raise ValueError('Original model proof report no longer matches verified baseline')
            put('models/initial_models_report.json',z.read(original+'models/models_report.json'))
            def collect_model(rep,read_img, origin_tag):
                for row in rep['rows']:
                    rec=row['source'];blob=rec['git_blob_sha']
                    if row['status']=='rendered':
                        data=read_img(row)
                        if sha256(data)!=row['render_sha256']:
                            raise ValueError('Model PNG mismatch: '+rec['path'])
                        if blob in models:
                            if row['render_sha256']!=models[blob]['sha256']:
                                raise ValueError('Conflicting renders of the same source binary '+blob)
                            continue
                        target='models/renders/'+blob+'.png'
                        put(target,data)
                        models[blob]={'id':blob,'name':Path(rec['path']).stem,'family':'3D model',
                                      'stage':stage_for_model(rec),
                                      'repository':rec['repository'],'status':'rendered-unapproved',
                                      'file':target,'sha256':row['render_sha256'],
                                      'source_url':rec.get('source_url'), 'source':rec,
                                      'batch':origin_tag}
                        blocked.pop(blob,None)
                    elif row['status']=='blocked' and blob not in models:
                        blocked[blob]={'source':rec,'error':row.get('error','unavailable source'),'batch':origin_tag}
            collect_model(base_report,lambda row:verify_image(z,original+'models/'+row['file'],row['render_sha256']),'initial')
            # Import the first model batch and raw-image textures from the existing combined baseline.
            model_report_path=find_one(z,'/models/models_report.json',forbidden=('canonical/',))
            batch_root=model_report_path[:-len('models/models_report.json')]
            report=asjson(z,model_report_path)
            check_path=batch_root+'models/model_batch_verify.json'
            check=asjson(z,check_path)
            if not check['passed'] or check['rendered_proofs']!=report['rendered']:
                raise ValueError('Baseline additional model proof receipt failed')
            collect_model(report,lambda row:verify_image(z,batch_root+'models/'+row['file'],row['render_sha256']),'models-batch-00')
            put('receipts/models-batch-00.json', z.read(model_report_path))
            put('receipts/models-batch-00-verify.json', z.read(check_path))
            texture_path=find_one(z,'/texture_batch_report.json')
            tb_root=texture_path[:-len('texture_batch_report.json')]
            tr=asjson(z,texture_path)
            verify=asjson(z,tb_root+'texture_batch_verify.json')
            if not verify['passed'] or tr['rendered']!=verify['verified_blender_images']:
                raise ValueError('Baseline raw texture receipts failed')
            for row in tr['images']:
                if row['status']!='rendered':continue
                rec=row['source'];blob=rec['git_blob_sha']
                data=verify_image(z,tb_root+row['file'],row['render_sha256'])
                if blob in textures: continue
                target='textures/'+blob+'.png'
                put(target,data)
                textures[blob]={'id':blob,'name':Path(rec['path']).stem,'family':'raw-map-not-PBR',
                                'repository':rec['repository'],'file':target,'source_url':rec.get('source_url'),
                                'status':'rendered-unapproved','sha256':row['render_sha256'],'source':rec,
                                'batch':'textures-batch-00'}
            put('receipts/textures-batch-00.json',z.read(texture_path))
            put('receipts/textures-batch-00-verify.json',z.read(tb_root+'texture_batch_verify.json'))
            verification.append({'package':baseline.name,'sha256':sha256(baseline.read_bytes()),'type':'baseline'})
        for addition in additionals:
            with ZipFile(addition) as z:
                model_reports=[n for n in z.namelist() if clean_path(n).endswith('/models/models_report.json')]
                texture_reports=[n for n in z.namelist() if clean_path(n).endswith('/texture_batch_report.json')]
                if len(model_reports)+len(texture_reports)!=1:
                    raise ValueError(f'Expected one report per batch: {addition}, found models={model_reports} textures={texture_reports}')
                tag=re.sub('[^a-z0-9-]','-',addition.stem.lower())[:70]
                if model_reports:
                    path=model_reports[0];root=clean_path(path)[:-len('models/models_report.json')]
                    report=asjson(z,path)
                    v=asjson(z,root+'models/model_batch_verify.json')
                    if not v['passed'] or v['rendered_proofs']!=report['rendered'] or v['blocked_with_reasons']!=report['blocked']:
                        raise ValueError('Failed model batch verification '+addition.name)
                    collect_model(report,lambda row:verify_image(z,root+'models/'+row['file'],row['render_sha256']),tag)
                    put('receipts/'+tag+'-models.json',z.read(path))
                    put('receipts/'+tag+'-verify.json',z.read(root+'models/model_batch_verify.json'))
                else:
                    path=texture_reports[0];root=clean_path(path)[:-len('texture_batch_report.json')]
                    report=asjson(z,path)
                    v=asjson(z,root+'texture_batch_verify.json')
                    if not v['passed'] or v['verified_blender_images']!=report['rendered']:
                        raise ValueError('Failed texture batch verification '+addition.name)
                    for row in report['images']:
                        if row['status']!='rendered':continue
                        rec=row['source'];blob=rec['git_blob_sha']
                        data=verify_image(z,root+row['file'],row['render_sha256'])
                        if blob in textures:
                            if textures[blob]['sha256']!=row['render_sha256']:
                                raise ValueError('Raw texture duplicate conflict '+blob)
                            continue
                        target='textures/'+blob+'.png'
                        put(target,data)
                        textures[blob]={'id':blob,'name':Path(rec['path']).stem,
                                        'family':'raw-map-not-PBR','repository':rec['repository'],
                                        'file':target,'source_url':rec.get('source_url'),
                                        'status':'rendered-unapproved','sha256':row['render_sha256'],
                                        'source':rec,'batch':tag}
                    put('receipts/'+tag+'-textures.json',z.read(path))
                    put('receipts/'+tag+'-verify.json',z.read(root+'texture_batch_verify.json'))
                verification.append({'package':addition.name,'sha256':sha256(addition.read_bytes()),'type':'additional'})
        manifest={'schema':'fmpl.gallery-cumulative.v1',
                  'material_count':len(materials),'model_count':len(models),
                  'texture_count':len(textures),'blocked_count':len(blocked),
                  'inventory':{'indexed_assets':inventory['indexed_assets'],
                               'model_source_total':inventory['model_source_total'],
                               'fully_scanned_repositories':inventory['fully_scanned_repositories']},
                  'materials':materials,'models':list(models.values()),
                  'textures':list(textures.values()),'blocked_models':list(blocked.values()),
                  'source_artifact_receipts':verification,
                  'coverage_note':'Only checks actual rendered proofs, not all indexed sources or game approval.'}
        put('manifest.json',(json.dumps(manifest,indent=2)+'\n').encode())
        put('index.html', gallery_html(manifest).encode('utf-8'))
        put('README.txt',(f"FMPL cumulative gallery: {len(materials)} materials, {len(models)} models, {len(textures)} raw texture proofs.\nOpen index.html after extraction.\nNo external dependencies or unapproved downloads.\n").encode())
    return manifest


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--baseline',type=Path,required=True)
    ap.add_argument('--batch',type=Path,action='append',default=[])
    ap.add_argument('--output',type=Path,required=True)
    a=ap.parse_args()
    result=build(a.baseline,a.batch,a.output)
    print('FMPL_CUMULATIVE_GALLERY_VERIFIED',result['material_count'],result['model_count'],result['texture_count'],result['blocked_count'])

if __name__=='__main__':
    main()