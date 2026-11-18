"""Install the ten actual filtered-cache sprites without altering their behavior."""
from pathlib import Path
import json,hashlib,shutil
R=Path(__file__).resolve().parents[3];B=R/'art/source-to-3d/filtered-stone-caches/v01';rows=json.loads((B/'catalog.json').read_text())['rows'];D=R/'tech-priests_src/graphics/entity/filtered-stone-caches-v01';h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();D.mkdir(exist_ok=True);records=[]
for row in rows:
 O=R/row['path'];sha=h(O/(row['stem']+'.blend'))
 for n in ('inspection.json','captures/capture.json'):
  r=json.loads((O/n).read_text());assert r['source_sha256']==sha
  if n=='inspection.json':assert r['passed']
 for src,kind in [('body-d0.png','body'),('shadow-d0.png','shadow'),('icon.png','icon')]:shutil.copy2(O/'captures'/src,D/(row['key']+'-'+kind+'.png'))
 records.append(dict(key=row['key'],source_sha256=sha,export_sha256=h(O/(row['stem']+'.glb'))))
p=R/'tech-priests_src/prototypes/martian_stone_cache.lua';s=p.read_text()
if 'local AUTHORED_FILTERED_CACHE_KEYS' not in s:
 table='local AUTHORED_FILTERED_CACHE_KEYS = {\n'+''.join('  ["'+r['id']+'"]="'+r['key']+'",\n' for r in rows)+'}\n\n';s=s.replace('local function icon_path(name)',table+'local function icon_path(name)',1)
 s=s.replace('local function icon_path(name)\n','local function icon_path(name)\n  if AUTHORED_FILTERED_CACHE_KEYS[name] then return "__tech-priests__/graphics/entity/filtered-stone-caches-v01/" .. AUTHORED_FILTERED_CACHE_KEYS[name] .. "-icon.png" end\n',1)
 s=s.replace('local function picture_for(name, scale, shift)\n','''local function picture_for(name, scale, shift)
  if AUTHORED_FILTERED_CACHE_KEYS[name] then
    local root = "__tech-priests__/graphics/entity/filtered-stone-caches-v01/" .. AUTHORED_FILTERED_CACHE_KEYS[name]
    local registration = {0,-0.08713203435596423}
    return {layers={
      {filename=root .. "-shadow.png",width=512,height=512,scale=3*32/512,shift=registration,draw_as_shadow=true},
      {filename=root .. "-body.png",width=512,height=512,scale=3*32/512,shift=registration}
    }}
  end
''',1)
 s=s.replace('if spec.name == "tech-priests-martian-stone-cache" or spec.name == "tech-priests-stone-cache-item-vault" then','if spec.name == "tech-priests-martian-stone-cache" or spec.name == "tech-priests-stone-cache-item-vault" or AUTHORED_FILTERED_CACHE_KEYS[spec.name] then',1)
p.write_text(s)
for row,rec in zip(rows,records):
 O=R/row['path'];rec.update(prototype_sha256=h(p),runtime_art={q.name:h(q) for q in D.glob(row['key']+'-*.png')},scope='Only this filtered cache picture/icon/backing art; inventory6, recipes, filter steward, circuits, fixed direction and ordinary inserters unchanged');(O/'integration.json').write_text(json.dumps(rec,indent=2)+'\n')
print('TEN_FILTERED_CACHE_PRODUCTION_GRAPHICS_INTEGRATED')
