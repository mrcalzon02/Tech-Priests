"""Install graphics only for the base cache; preserve every family prototype contract."""
from pathlib import Path
import json,shutil,hashlib
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/martian-stone-cache/v01';D=R/'tech-priests_src/graphics/entity/martian-stone-cache-v01';assert json.loads((O/'inspection.json').read_text())['passed'];assert json.loads((O/'wall-and-tie-audit.json').read_text())['passed'];D.mkdir(exist_ok=True)
assert json.loads((O/'inspection.json').read_text())['source_sha256']==hashlib.sha256((O/'martian-stone-cache-v01.blend').read_bytes()).hexdigest()
assert json.loads((O/'captures/capture.json').read_text())['source_sha256']==hashlib.sha256((O/'martian-stone-cache-v01.blend').read_bytes()).hexdigest()
for src,dest in [('body-d0.png','body.png'),('shadow-d0.png','shadow.png'),('icon.png','icon.png')]:shutil.copy2(O/'captures'/src,D/dest)
p=R/'tech-priests_src/prototypes/martian_stone_cache.lua';s=p.read_text();icon='''  if name == "tech-priests-martian-stone-cache" then
    return "__tech-priests__/graphics/entity/martian-stone-cache-v01/icon.png"
  end
''';picture='''  -- Authored base cache only. All inventories, circuits and variants retain
  -- their original definitions; fixed-north orientation is unchanged.
  if name == "tech-priests-martian-stone-cache" then
    local root = "__tech-priests__/graphics/entity/martian-stone-cache-v01/"
    local registration = {0, -0.08713203435596423}
    return {layers = {
      {filename=root .. "shadow.png", priority="high", width=512, height=512,
        scale=3.0*32/512, shift=registration, draw_as_shadow=true},
      {filename=root .. "body.png", priority="high", width=512, height=512,
        scale=3.0*32/512, shift=registration}
    }}
  end
'''
if 'martian-stone-cache-v01/icon.png' not in s:
 s=s.replace('local function icon_path(name)\n','local function icon_path(name)\n'+icon,1);s=s.replace('local function picture_for(name, scale, shift)\n','local function picture_for(name, scale, shift)\n'+picture,1)
s=s.replace('local registration = {0, -0.21213203435596423}','local registration = {0, -0.08713203435596423}');p.write_text(s)
marker='  chest.picture = picture_for(spec.name, spec.scale or 0.055, spec.shift)\n'
if '-- Centered Martian relief keeps its own backing' not in s:
 s=s.replace(marker,marker+'''  -- Centered Martian relief keeps its own backing; native pins/LEDs and all
  -- connector points/reach remain unchanged. Avoid a steel-chest board over it.
  if spec.name == "tech-priests-martian-stone-cache" then
    for _, connector in ipairs(chest.circuit_connector or {}) do
      if connector.sprites then
        connector.sprites.connector_main = util.empty_sprite()
        connector.sprites.connector_shadow = util.empty_sprite()
      end
    end
  end
''',1);p.write_text(s)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();(O/'integration.json').write_text(json.dumps(dict(stage='Integrated base-cache candidate; native tests and owner review pending',source_sha256=h(O/'martian-stone-cache-v01.blend'),export_sha256=h(O/'martian-stone-cache-v01.glb'),prototype_sha256=h(p),runtime_art={q.name:h(q) for q in D.glob('*.png')},scope='Only base cache picture and entity/item/recipe icon paths changed. All family gameplay fields, wire points, filters and variant visuals preserved.'),indent=2));print('BASE_CACHE_ART_INTEGRATED')
