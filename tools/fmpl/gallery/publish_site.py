#!/usr/bin/env python3
"""Publish a lean, source-pinned FMPL visual review site from independently verified archives.

No invented images, no remote writes, no CI workflow creation, no source mutation.
Requires Pillow. A preview is a review proof, never a claim of owner approval.
"""
from __future__ import annotations
import argparse
import hashlib
import io
import json
import re
from pathlib import Path
from zipfile import ZipFile
from PIL import Image, ImageDraw, ImageFont

OUT_SETS = (
    ('materials', 'Canonical FMPL materials', 12),
    ('models', '3D source model renders', 9),
    ('textures', 'Raw texture-map sphere previews', 8),
)
TILE = 214
IMAGE_ZONE = 189


def digest(data:bytes)->str:
    return hashlib.sha256(data).hexdigest()


def get_name_index(archive:ZipFile)->dict:
    return {name.replace('\\','/'):name for name in archive.namelist()}


def check_one(z, blobname, expected):
    raw=z.read(blobname)
    if digest(raw)!=expected:
        raise ValueError('Invalid verified render hash: '+blobname)
    with Image.open(io.BytesIO(raw)) as opened:
        if opened.format!='PNG':
            raise ValueError('Verified render must be PNG '+blobname)
        opened.load()
        return opened.convert('RGB')


def locate_prefix(z, suffix):
    matches=[n[:-len(suffix)] for n in z.namelist() if n.endswith(suffix)]
    if len(matches)!=1:raise ValueError('Expected one '+suffix+' in archive, found '+str(len(matches)))
    return matches[0]


def basename_for(row):
    source=row.get('source',{})
    if isinstance(source,dict):return Path(source.get('path') or row['file']).stem
    return row['id']


def add_materials(path, records, provenance):
    with ZipFile(path) as z:
        prefix=locate_prefix(z, 'gallery/gallery_verify.json')
        receipt=json.loads(z.read(prefix+'gallery/gallery_verify.json'))
        mats=json.loads(z.read(prefix+'gallery/materials/materials_report.json'))
        cat=json.loads(z.read(prefix+'gallery/catalog.json'))
        if not receipt.get('passed') or not mats.get('passed') or len(mats['individuals'])!=76:
            raise ValueError('Original 76-material proof is not independently verified')
        if cat.get('source_fmpl_commit','')=='':raise ValueError('No source commit pin for FMPL')
        for r in mats['individuals']:
            n=prefix+'gallery/materials/'+r['native_render']
            image=check_one(z,n,r['render_sha256'])
            source='https://github.com/mrcalzon02/Tech-Priests/blob/'+cat['source_fmpl_commit']+'/'+r['source']
            records.append({'type':'materials','name':r['id'],'family':r['family'], 'subtype':r['kind'],'source':source,
                            'source_path':r['source'], 'source_commit':cat['source_fmpl_commit'],
                            'render_sha256':r['render_sha256'],'image':image})
        models=json.loads(z.read(prefix+'gallery/models/models_report.json'))
        if models['rendered']!=36 or models.get('blocked')!=0:
            raise ValueError('Original model cohort is not independently verified')
        for r in models['rows']:
            if r['status']!='rendered':raise ValueError('Initial model proof missing')
            src=r['source']
            url=src.get('source_url')
            if not url or not url.startswith('https://github.com/'):
                raise ValueError('No pinned GitHub source for original model')
            image=check_one(z,prefix+'gallery/models/'+r['file'],r['render_sha256'])
            records.append({'type':'models','name':Path(src['path']).stem,'family':src['repository'].split('/')[-1],
                            'subtype':'Native Blender' if src['path'].lower().endswith('.blend') else '3D model',
                            'source':url,'source_path':src['path'],'source_commit':src['commit'],
                            'render_sha256':r['render_sha256'],'image':image})
        provenance.append({'kind':'canonical','github_run':42758624374,'render_count':len(mats['individuals'])+models['rendered'],
                           'archive_sha256':digest(Path(path).read_bytes())})


def add_external(path,records,provenance):
    with ZipFile(path) as z:
        models=[n for n in z.namelist() if n.endswith('models/models_report.json')]
        textures=[n for n in z.namelist() if n.endswith('texture_batch_report.json')]
        if len(models)+len(textures)!=1:raise ValueError('Expected exactly one models or textures report')
        if models:
            reportpath=models[0];prefix=reportpath[:-len('models/models_report.json')]
            report=json.loads(z.read(reportpath));verify=json.loads(z.read(prefix+'models/model_batch_verify.json'))
            if not verify.get('passed') or report['rendered']!=verify['rendered_proofs']:
                raise ValueError('Model batch lacks independent verification')
            rows=report['rows'];kind='models';folder=prefix+'models/'
        else:
            reportpath=textures[0];prefix=reportpath[:-len('texture_batch_report.json')]
            report=json.loads(z.read(reportpath));verify=json.loads(z.read(prefix+'texture_batch_verify.json'))
            if not verify.get('passed') or report['rendered']!=verify['verified_blender_images']:
                raise ValueError('Texture batch lacks independent verification')
            rows=report['images'];kind='textures';folder=prefix
        added=0
        for r in rows:
            if r['status']!='rendered':continue
            source=r['source'];url=source.get('source_url')
            if not url or not url.startswith('https://github.com/'):
                raise ValueError('Non-GitHub or missing pinned source: '+str(source))
            image=check_one(z,folder+r['file'],r['render_sha256'])
            records.append({'type':kind,'name':basename_for(r),'family':source['repository'].split('/')[-1],
                            'subtype': 'Raw map · not approved PBR' if kind=='textures' else ('Native Blender' if source['path'].lower().endswith('.blend') else '3D model'),
                            'source':url,'source_path':source['path'],'source_commit':source['commit'],
                            'render_sha256':r['render_sha256'],'image':image})
            added+=1
        if added!=report['rendered']:raise ValueError('A preview was silently omitted')
        provenance.append({'kind':kind,'render_count':added, 'archive_sha256':digest(Path(path).read_bytes())})


def image_atlas(rows,typ,cols,target):
    part=[r for r in rows if r['type']==typ]
    if not part:return 0
    height=((len(part)+cols-1)//cols)*TILE
    sheet=Image.new('RGB',(cols*TILE,height),'#111921')
    d=ImageDraw.Draw(sheet)
    try:font=ImageFont.truetype('DejaVuSans.ttf',16)
    except OSError:font=ImageFont.load_default()
    for i,r in enumerate(part):
        x=(i%cols)*TILE;y=(i//cols)*TILE
        d.rounded_rectangle((x+4,y+4,x+TILE-4,y+TILE-4), radius=9,fill='#202b35',outline='#485765',width=2)
        im=r.pop('image')
        im.thumbnail((TILE-20,IMAGE_ZONE-10),Image.Resampling.LANCZOS)
        sheet.paste(im,(x+(TILE-im.width)//2,y+5+(IMAGE_ZONE-im.height)//2))
        name=r['name'].replace('_',' ').replace('-',' ')
        if len(name)>24:name=name[:22]+'…'
        d.text((x+8,y+191),name,fill='#f0f5f8',font=font)
        r.update({'column':i%cols, 'row':i//cols, 'atlas':typ,'index':i})
    target.parent.mkdir(parents=True,exist_ok=True)
    sheet.save(target,'WEBP',quality=68,method=6)
    return len(part)


def web_document():
    return '''<!doctype html><html lang="en"><head><meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<meta name="description" content="Verified Blender renders from FMPL, with pinned source links and explicit approval state."/>
<title>FMPL — Verified Blender Render Gallery</title>
<style>
:root{color-scheme:dark;font-family:system-ui,-apple-system,'Segoe UI',sans-serif;--bg:#0d151b;--ink:#e8edf2;--muted:#acbfcb;--border:#384d5b;--accent:#a9dce0}
*{box-sizing:border-box}body{background:var(--bg);color:var(--ink);margin:0}main{max-width:1560px;margin:0 auto;padding:24px}
a{color:var(--accent)}header{display:flex;gap:24px;align-items:center;justify-content:space-between;flex-wrap:wrap;border-bottom:1px solid var(--border);padding-bottom:18px}
h1{margin:0 0 8px;font-size:clamp(24px,4vw,38px)}p{line-height:1.5}.muted{color:var(--muted)}.eyebrow{letter-spacing:.13em;color:var(--accent);text-transform:uppercase;font-size:11px;font-weight:700}
.summary{display:flex;gap:18px;flex-wrap:wrap;margin:12px 0}.summary b{font-size:20px;color:white}.summary span{display:block;color:var(--muted);font-size:12px}
.controls{position:sticky;top:0;z-index:5;background:#111c24ef;backdrop-filter:blur(12px);border:1px solid var(--border);border-radius:12px;padding:12px;display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin:22px 0}
input,select{border:1px solid #546b78;border-radius:8px;padding:11px 13px;background:#20303b;color:white;font:inherit;min-height:43px}
input{flex:2;min-width:220px}select{flex:1;min-width:195px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(168px,1fr));gap:13px}
.card{background:#18232d;border:1px solid #354957;border-radius:10px;overflow:hidden;cursor:pointer;text-align:left;color:inherit;min-width:0;padding:0}
.card:hover,.card:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.art{width:100%;aspect-ratio:1;background-repeat:no-repeat;background-color:#111c22}
.data{padding:10px}.data strong{display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-size:13px}.data small{display:block;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-size:11px;margin-top:4px}
.pill{border:1px solid #4c7280;color:#a9dce0;border-radius:99px;padding:3px 7px;font-size:10px;display:inline-block;margin-top:8px}
section h2{font-size:20px;margin:30px 0 12px}#none{display:none;color:var(--muted);padding:28px}
dialog{background:#17242d;color:white;border:1px solid #7592a0;border-radius:14px;padding:0;max-width:860px;width:calc(100vw - 32px)}dialog::backdrop{background:#030608e0}
.modal{display:grid;grid-template-columns:minmax(0,1fr) minmax(200px,1fr);gap:20px;padding:18px}.modal-art{aspect-ratio:1;background-repeat:no-repeat;background-color:#202b35;border-radius:8px;align-self:start}.meta{min-width:0}.meta h2{font-size:21px;overflow-wrap:anywhere;margin:8px 0}.meta p{font-size:13px;color:#c3d0d8;overflow-wrap:anywhere}
.close{float:right;background:#354855;color:white;border:1px solid #6e8793;border-radius:8px;cursor:pointer;font-size:22px;padding:3px 12px}.source{display:inline-block;margin-top:12px}
footer{font-size:12px;color:#aebdc7;margin:36px 0;border-top:1px solid #34434a;padding-top:20px}
@media(max-width:650px){main{padding:12px}.modal{grid-template-columns:1fr}.controls{position:static}.grid{grid-template-columns:repeat(auto-fill,minmax(130px,1fr));gap:8px}}
</style></head><body><main><header><div><div class="eyebrow">Factorio Modeling Production Library</div>
<h1>FMPL / Rendered asset gallery</h1><p class="muted">Real, independently verified Blender render previews — linked to pinned GitHub source revisions. Rendered does not mean production approved.</p></div>
<a href="https://github.com/mrcalzon02/Tech-Priests/tree/main/tools/fmpl/gallery">FMPL tooling &amp; standards</a></header>
<div class="summary" id="summary"></div>
<div class="controls"><input id="q" type="search" aria-label="Search rendered assets" placeholder="Search material, model, project, path…"/>
<select id="type" aria-label="Filter by family"><option value="">All verified previews</option><option value="materials">Canonical materials</option><option value="models">3D models</option><option value="textures">Raw texture maps</option></select>
<span class="muted" id="match" aria-live="polite"></span></div>
<section class="grid" id="gallery" aria-label="Verified render previews"></section><div id="none">Nothing matches your filters.</div>
<dialog id="preview" aria-label="Asset details"><div class="modal"><div class="modal-art" id="detail-art"></div><div class="meta"><button class="close" id="close" aria-label="Close preview">×</button><div class="eyebrow" id="detail-kind"></div><h2 id="detail-name"></h2><p id="detail-family"></p><p id="detail-path"></p><p id="detail-hash"></p><p>Source is pinned. The render is verification evidence only; PBR approval, model signoff, and Factorio installation are separate.</p><a class="source" id="detail-source" target="_blank" rel="noopener noreferrer">View source at pinned GitHub revision</a></div></div></dialog>
<footer>Thumbnails are cropped from verified Blender PNG proofs and compressed into WEBP atlases for immediate browser viewing. Raw maps shown on spheres are not complete, approved PBR presets. No private donor geometry is published. <a href="manifest.json">Provenance &amp; image hashes</a> · <a href="README.md">GitHub-rendered contact sheets</a>.</footer>
</main><script>
(async()=>{
 const result=await fetch('manifest.json'); if(!result.ok)throw Error('Gallery manifest missing');
 const m=await result.json(),records=m.entries; const atlas=m.atlas;
 const q=document.querySelector('#q'), type=document.querySelector('#type'), gallery=document.querySelector('#gallery'), match=document.querySelector('#match');
 const dialog=document.querySelector('#preview');
 function art(node,item){const a=atlas[item.atlas];
  node.style.backgroundImage=`url(assets/${item.atlas}.webp)`;
  node.style.backgroundSize=`${a.columns*100}% ${a.rows*100}%`;
  node.style.backgroundPosition=`${a.columns===1?0:item.column/(a.columns-1)*100}% ${a.rows===1?0:item.row/(a.rows-1)*100}%`;
 }
 const names={materials:'Canonical material',models:'3D source model',textures:'Raw texture map'};
 document.querySelector('#summary').replaceChildren(...Object.entries(names).map(([k,v])=>{
 const root=document.createElement('div'),b=document.createElement('b'),s=document.createElement('span');
 b.textContent=records.filter(x=>x.type===k).length;s.textContent=v+' previews';root.append(b,s);return root;}));
 function show(item){art(document.querySelector('#detail-art'),item);
  for(const [id,value] of [['detail-kind',names[item.type]],['detail-name',item.name],['detail-family',item.family+' · '+item.subtype],['detail-path',item.source_path],['detail-hash','Render SHA-256 '+item.render_sha256]])document.getElementById(id).textContent=value;
  const link=document.querySelector('#detail-source');link.href=item.source;dialog.showModal();}
 function render(){const needle=q.value.toLowerCase().trim();const which=type.value;
  const visible=records.filter(r=>(!which||r.type===which)&&(!needle||[r.name,r.family,r.subtype,r.source_path].join(' ').toLowerCase().includes(needle)));
  const frag=document.createDocumentFragment();for(const item of visible){const btn=document.createElement('button');btn.className='card';btn.type='button';btn.title='Inspect '+item.name;
   const pic=document.createElement('div');pic.className='art';art(pic,item);
   const block=document.createElement('div');block.className='data'; const strong=document.createElement('strong');strong.textContent=item.name;
   const small=document.createElement('small');small.textContent=item.family;const pill=document.createElement('span');pill.className='pill';pill.textContent=names[item.type];
   block.append(strong,small,pill);btn.append(pic,block);btn.addEventListener('click',()=>show(item));frag.append(btn);}
  gallery.replaceChildren(frag); match.textContent=visible.length+' verified previews';document.querySelector('#none').style.display=visible.length?'none':'block';}
 q.addEventListener('input',render);type.addEventListener('change',render);document.querySelector('#close').addEventListener('click',()=>dialog.close());render();
})().catch(err=>{document.querySelector('#match').textContent='Gallery manifest could not load: '+err.message;});
</script></body></html>'''


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--baseline',type=Path,required=True)
    p.add_argument('--textures',action='append',type=Path,default=[])
    p.add_argument('--models',action='append',type=Path,default=[])
    p.add_argument('--output',type=Path,required=True)
    args=p.parse_args()
    output=args.output
    if output.exists() and any(output.iterdir()):
        raise FileExistsError('Choose a fresh output directory; publishing never silently replaces a prior site')
    output.mkdir(parents=True,exist_ok=True)
    (output/'assets').mkdir(exist_ok=True)
    records=[];provenance=[]
    add_materials(args.baseline,records,provenance)
    for src in args.models+args.textures:add_external(src,records,provenance)
    atlas={}
    for typ,_,cols in OUT_SETS:
        nr=image_atlas(records,typ,cols,output/'assets'/f'{typ}.webp')
        if nr: atlas[typ]={'columns':cols,'rows':(nr+cols-1)//cols,'count':nr,'tile_px':TILE}
    assert all('image' not in r for r in records)
    counts={key:len([r for r in records if r['type']==key]) for key in ('materials','models','textures')}
    manifest={'schema':'fmpl.live-gallery.v1','source_verification':'Each PNG rehashed against independently verified receipt prior to contact-sheet assembly',
              'review_only':True,'user_approved':False,'game_integrated':False,'counts':counts,'atlas':atlas,'provenance':provenance,'entries':records}
    (output/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (output/'index.html').write_text(web_document(),encoding='utf-8')
    content=['# FMPL — Verified Blender render gallery','','Browse previews **directly on GitHub** below, or open the searchable [GitHub Pages gallery](https://mrcalzon02.github.io/Tech-Priests/fmpl-gallery/) once Pages has been enabled on the `main` branch `/docs` folder.','','The images are genuine render previews verified against source receipts; **not** proof of modeling approval, finalized PBR status, or game integration.','','| Family | Verified previews |','|---|---:|']
    for kind,descr,_ in OUT_SETS:
        if kind not in atlas:continue
        content.append('| '+descr+' | '+str(counts[kind])+' |')
    for kind,descr,_ in OUT_SETS:
        if kind not in atlas:continue
        content.extend(['','## '+descr,'',f'![{descr} contact sheet](assets/{kind}.webp)','','Find exact names, pinned commits, material classes and original source links in [the manifest](manifest.json).'])
    content+=['','## Source & provenance','', 'Proofs originate from verified FMPL renderer artifacts, never generated placeholders. Full-resolution `.blend` source and PNG render packages remain separate from the lightweight inline review gallery. No new GitHub Actions workflow is required.','']
    (output/'README.md').write_text('\n'.join(content),encoding='utf-8')
    (output/'PUBLICATION.md').write_text('# FMPL GitHub Pages publishing\n\nThe gallery is a static site. Configure the public `mrcalzon02/Tech-Priests` repository under **Settings → Pages → Build and deployment → Deploy from a branch → main → /docs**. No custom workflow is required.\n\nThe repository README links the [GitHub-native Markdown contact sheets](README.md) even before Pages is enabled. Static site entry: `docs/index.html` redirects into `docs/fmpl-gallery/index.html`.\n\nFuture publication: merge independently verified render artifacts, rerun `tools/fmpl/gallery/publish_site.py` into a clean temporary output directory, inspect the diff and copy `assets/*.webp`, `manifest.json`, `index.html` and `README.md` into `docs/fmpl-gallery/` using the already-authorized runner checkout. Commit to `main` with ordinary fast-forward semantics and read back; do not create additional Actions workflows.\n\nMaintain source commit pins and SHA-256 receipts. Never label raw map sphere previews as approved PBR. Do not publish unlicensed private donor binaries.\n',encoding='utf-8')
    print('FMPL_STATIC_SITE_VERIFIED',counts, {x:p.stat().st_size for x,p in [(p.name,p) for p in (output/'assets').iterdir()]})

if __name__=='__main__':main()
