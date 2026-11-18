"""Integrate only Item Vault art, retaining every actual gameplay field."""
from pathlib import Path
import json,hashlib,shutil
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/item-vault/v01';D=R/'tech-priests_src/graphics/entity/item-vault-v01';h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name in ('inspection.json','seat-audit.json','captures/capture.json'):
 d=json.loads((O/name).read_text());assert d['source_sha256']==h(O/'item-vault-v01.blend')
 if name!='captures/capture.json':assert d['passed']
D.mkdir(exist_ok=True)
for src,dst in [('body-d0.png','body.png'),('shadow-d0.png','shadow.png'),('icon.png','icon.png')]:shutil.copy2(O/'captures'/src,D/dst)
p=R/'tech-priests_src/prototypes/martian_stone_cache.lua';s=p.read_text();ID='tech-priests-stone-cache-item-vault'
if 'item-vault-v01/icon.png' not in s:s=s.replace('local function icon_path(name)\n','local function icon_path(name)\n  if name == "'+ID+'" then return "__tech-priests__/graphics/entity/item-vault-v01/icon.png" end\n',1)
if 'item-vault-v01/body.png' not in s:
 block='''  -- Authored Item Vault: fixed-facing native ten-slot container unchanged.
  if name == "tech-priests-stone-cache-item-vault" then
    local registration = {0, -0.08713203435596423}
    return {layers = {
      {filename="__tech-priests__/graphics/entity/item-vault-v01/shadow.png", priority="high", width=512, height=512, scale=3.0*32/512, shift=registration, draw_as_shadow=true},
      {filename="__tech-priests__/graphics/entity/item-vault-v01/body.png", priority="high", width=512, height=512, scale=3.0*32/512, shift=registration}
    }}
  end
'''
 s=s.replace('local function picture_for(name, scale, shift)\n','local function picture_for(name, scale, shift)\n'+block,1)
s=s.replace('if spec.name == "tech-priests-martian-stone-cache" then','if spec.name == "tech-priests-martian-stone-cache" or spec.name == "'+ID+'" then',1);p.write_text(s)
(O/'integration.json').write_text(json.dumps(dict(stage='Production graphics integrated; native verification and owner review are separate',source_sha256=h(O/'item-vault-v01.blend'),export_sha256=h(O/'item-vault-v01.glb'),prototype_sha256=h(p),runtime_art={q.name:h(q) for q in D.glob('*.png')},scope='Item Vault picture, icon and connector backing artwork only; native connector points/reach, pins and LEDs retained'),indent=2)+'\n');print('ITEM_VAULT_PRODUCTION_ART_INTEGRATED')
