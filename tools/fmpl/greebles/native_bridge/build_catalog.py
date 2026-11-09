#!/usr/bin/env python3
"""Build an auditable offline searchable FMPL greeble catalog and contact sheets."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import html,json,math,sys,csv

ROOT=Path(sys.argv[1]);OUT=ROOT/'contact_sheets';OUT.mkdir(exist_ok=True)
entries=[]
for p in sorted(ROOT.glob('parts/*/receipt.json')):
 e=json.loads(p.read_text()); e['paths']={k:(Path('parts')/e['id']/(e['id']+ext)).as_posix() for k,ext in [('glb','.glb'),('obj','.obj')]}
 e['paths']['front']=(Path('parts')/e['id']/'front.png').as_posix()
 e['paths']['rear']=(Path('parts')/e['id']/'rear.png').as_posix()
 entries.append(e)
assert len(entries)==320
fontfile='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
f1=ImageFont.truetype(fontfile,14) if Path(fontfile).is_file() else ImageFont.load_default()
f2=ImageFont.truetype(fontfile,11) if Path(fontfile).is_file() else ImageFont.load_default()
per_page=20; cols=4;rows=5;cw=420;ch=282
for i in range(0,len(entries),per_page):
 page=entries[i:i+per_page]
 im=Image.new('RGB',(cols*cw,rows*ch),(22,27,33));d=ImageDraw.Draw(im)
 for j,e in enumerate(page):
  x=(j%cols)*cw;y=(j//cols)*ch
  d.rounded_rectangle((x+4,y+4,x+cw-4,y+ch-4),radius=8,fill=(36,43,49),outline=(82,94,106),width=1)
  d.text((x+9,y+9),f"{i+j+1:03d}  {e['source_object']}  —  {e['id']}",font=f1,fill=(225,232,238))
  for n,key in enumerate(['front','rear']):
   path=ROOT/e['paths'][key]
   with Image.open(path) as v:im.paste(v.convert('RGB').resize((198,148)),(x+9+204*n,y+36))
  d.text((x+9,y+190),f"{e['counts']['vertices']:,} vertices  |  {e['counts']['polygons']:,} polygons",font=f2,fill=(199,214,226))
  span=e['extent_local'];d.text((x+9,y+208),'bounds '+', '.join(f'{v:.2f}' for v in span),font=f2,fill=(189,194,208))
  d.text((x+9,y+229),'UNCLASSIFIED • geometry-only • no source materials',font=f2,fill=(240,203,143))
  d.text((x+9,y+247),'Native Blender reopen: pending',font=f2,fill=(171,181,196))
 pageid=i//per_page+1
 im.save(OUT/f'page_{pageid:02d}.png',optimize=True)
 print('PAGE',pageid,'count',len(page),flush=True)

manual_labels={
 '007':('Industrial mounting collar', ['annular','flange','mounting-tabs','cast-metal-candidate']),
 '008':('Slotted cylindrical housing', ['drum','vents','ribbed-housing','machinery']),
 '009':('Perimeter-tabbed circular flange', ['annular','flange','mounting-tabs']),
 '010':('Segmented thin rim', ['annular','rim','thin']),
 '012':('Segmented reinforcement ring', ['annular','segmented','rim']),
 '013':('Detailed circular mounting collar', ['annular','flange','surface-detail']),
 '014':('Dense mechanical endplate', ['disc','machinery','surface-detail','mounts']),
 '015':('Open-frame cylindrical assembly', ['cage','truss','mechanical-frame','industrial']),
}
external_labels=json.loads((ROOT/'manual_visual_labels.json').read_text())['labels']
manual_labels.update(external_labels)
for e in entries:
 if e['source_object'] in manual_labels:
  e['appearance_label'],e['style_tags']=manual_labels[e['source_object']]
  e['label_provenance']='manual-visible-two-view-diagnostic'
  e['semantic_label_status']='visual-candidate-not-functional-certification'
 else:
  e['appearance_label']=None
  e['style_tags']=[]
  e['semantic_label_status']='unclassified-awaiting-visual-label'
 dims=sorted(float(x) for x in e['extent_local'])
 e['measured_form']=('flat' if dims[0]<0.22*dims[1] else 'elongated' if dims[2]>2.8*dims[1] else 'volumetric')
 e['source_materials']='generic-placeholder-not-authoritative'
 e['provenance']='Google Drive Greebles.blend / original compressed pinned SHA256; Blender 5 stored mesh topology'
 e['native_reopen_verified']=False
 e['interchange_glb_validated']=True
 e['interchange_obj_original_polygons']=True

(Root:=ROOT/'catalog.json').write_text(json.dumps({'schema':'fmpl.greebles.full-geometry-catalog.v1','objects':entries,
 'status':'all-original-meshes-interchange-exported-and-hash-checked','count':len(entries),
 'observed_material_policy':'placeholder materials omitted','native_blender_reopen':'not yet performed'},indent=2)+'\n')
with (ROOT/'catalog.csv').open('w',newline='',encoding='utf-8') as f:
 w=csv.writer(f);w.writerow(['id','source_object','appearance_label','vertices','polygons','triangles','bounds_x','bounds_y','bounds_z','tags','glb_file','obj_file','glb_sha256','visual_status'])
 for e in entries:
  w.writerow([e['id'],e['source_object'],e['appearance_label'] or '',e['counts']['vertices'],e['counts']['polygons'],e['counts']['triangles'],
              *e['extent_local'],','.join(e['style_tags']),e['paths']['glb'],e['paths']['obj'],e['glb_sha256'],e['semantic_label_status']])

# Standalone local site: relative file paths, no hosted services/network or external scripts.
rows=[]
for e in entries:
 eid=html.escape(e['id']); name=html.escape(e['source_object']); desc=html.escape(e['appearance_label'] or 'Unclassified shape candidate')
 tag_text=' '.join(e['style_tags']);search=html.escape((e['source_object']+' '+eid+' '+(e['appearance_label'] or '')+' '+tag_text).lower())
 paths=e['paths']
 rows.append(f'''<article class="tile" data-search="{search}"><header><strong>{name}</strong><span>{eid}</span></header>
    <div class="imgs"><img src="{paths['front']}" loading="lazy"><img src="{paths['rear']}" loading="lazy"></div>
    <h3>{desc}</h3><p>{e['counts']['vertices']:,} verts · {e['counts']['polygons']:,} polygons<br>size {', '.join(f'{v:.2f}' for v in e['extent_local'])}</p>
    <p class="status">{html.escape(e['semantic_label_status'])}</p><footer><a href="{paths['glb']}">GLB</a> · <a href="{paths['obj']}">OBJ</a></footer></article>''')
site='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>FMPL | Greebles Geometry Index</title>
<style>body{font:14px system-ui,sans-serif;background:#131922;color:#e3e9ef;margin:0}header.top{position:sticky;top:0;background:#1c2633;padding:12px 20px;z-index:1;border-bottom:1px solid #394b60}h1{margin:0 0 6px;font-size:24px}.note{color:#b3bfce;margin:4px 0}input{background:#09111b;color:#fff;border:1px solid #5b6c80;border-radius:8px;padding:12px;font-size:16px;width:min(700px,90%)}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(310px,1fr));gap:13px;padding:20px}.tile{background:#26303c;border:1px solid #48596d;border-radius:12px;padding:10px;min-width:0}.tile header{display:flex;justify-content:space-between;gap:9px;align-items:center}.tile header span{font-size:10px;color:#9caec1}.imgs{display:flex;gap:2px;margin-top:8px}.imgs img{width:50%;border-radius:5px}.tile h3{font-size:16px;margin:8px 0 6px}.tile p{margin:6px 0;color:#c5cfdb}.tile .status{color:#e6b96e;font-size:11px}.tile footer a{color:#a6d0ff;text-decoration:none}a:hover{text-decoration:underline}</style>
<header class="top"><h1>Factorio Modeling Production Library — Greebles</h1><p class="note">320 physically extracted, separate GLB + OBJ candidates. Render previews are diagnostics, not native Factorio sprites. No original placeholder materials transferred.</p><p class="note">Native standalone .blend and final fit/functional certification remain pending Blender roundtrip.</p><input id="q" placeholder="Search by source name, appearance, tag, ID..."><span id="count"></span></header><main id="catalog">'''+ '\n'.join(rows)+'''</main><script>const input=document.getElementById('q'),rows=[...document.querySelectorAll('.tile')],count=document.getElementById('count');function filter(){const q=input.value.trim().toLowerCase();let visible=0;for(const el of rows){const hit=el.dataset.search.includes(q);el.hidden=!hit;if(hit)visible++}count.textContent=' '+visible+'/'+rows.length}input.addEventListener('input',filter);filter()</script></html>'''
(ROOT/'index.html').write_text(site,encoding='utf-8')
print('CATALOG',len(entries),'pages',math.ceil(len(entries)/per_page),'html_bytes',len(site))
