"""Native four-way Advanced cargo, with matching projected circuit fittings."""
from pathlib import Path
import json,hashlib,shutil,math
import numpy as np
from PIL import Image
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/space-cargo-inventories/v01/advanced';D=R/'tech-priests_src/graphics/entity/advanced-space-cargo-v01';D.mkdir(exist_ok=True);h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();sha=h(O/'advanced-space-cargo-v01.blend');ID='tech-priests-advanced-space-cargo-inventory'
for name in ('inspection.json','captures/capture.json'):
 d=json.loads((O/name).read_text());assert d['source_sha256']==sha
 if name=='inspection.json':assert d['passed']
for name in ['icon.png']+['%s-d%d.png'%(k,i) for k in ('body','shadow') for i in range(4)]:shutil.copy2(O/'captures'/name,D/name)
meta=json.loads((O/'construction.json').read_text());cfg=json.loads((O/'contract.json').read_text());vec=lambda p:'{'+','.join(repr(float(v)) for v in p)+'}';base=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/data/base');registration=[]
for i in range(4):
 def project(p):
  x,y,z=p;a=-i*math.pi/2;x,y=x*math.cos(a)-y*math.sin(a),x*math.sin(a)+y*math.cos(a);return [x,-y-z/math.sqrt(2)]
 points={k:project(v) for k,v in meta['terminals'].items()};target=project(meta['status_led']);leds={}
 for key in ('led_blue','led_blue_off','led_green','led_red'):
  spr=cfg['prototype']['circuit_connector'][0]['sprites'][key];im=Image.open(base/spr['filename'].replace('__base__/','')).convert('RGBA').crop((spr['x'],spr['y'],spr['x']+spr['width'],spr['y']+spr['height']));a=np.asarray(im)[:,:,3].astype(float);Y,X=np.mgrid[0:spr['height'],0:spr['width']];offset=[((X*a).sum()/a.sum()-spr['width']/2)*spr['scale']/32,((Y*a).sum()/a.sum()-spr['height']/2)*spr['scale']/32];leds[key]=[target[j]-offset[j] for j in range(2)]
 registration.append(dict(direction=i*4,source_yaw=-90*i,points=points,led_target=target,led_shifts=leds))
p=R/'tech-priests_src/prototypes/martian_stone_cache.lua';s=p.read_text()
s=s.replace('local ADV_SPACE_CARGO_SELECTION_BOX = {{-2.50, -2.20}, {2.50, 2.20}}','local ADV_SPACE_CARGO_SELECTION_BOX = {{-2.50, -2.50}, {2.50, 2.50}}').replace('local ADV_SPACE_CARGO_COLLISION_BOX = {{-2.20, -1.90}, {2.20, 1.90}}','local ADV_SPACE_CARGO_COLLISION_BOX = {{-2.20, -2.20}, {2.20, 2.20}}')
if 'advanced-space-cargo-v01/icon.png' not in s:s=s.replace('local function icon_path(name)\n','local function icon_path(name)\n  if name == "'+ID+'" then return "__tech-priests__/graphics/entity/advanced-space-cargo-v01/icon.png" end\n',1)
marker='  if name == "'+ID+'"'
a=s.find(marker,s.index('local function picture_for'))
if a<0:a=s.index('  if name == "tech-priests-basic-space-cargo-inventory"',s.index('local function picture_for'));b=a
else:b=s.index('  if name == "tech-priests-basic-space-cargo-inventory"',a)
block='  if name == "'+ID+'" then return {\n'
for i,direction in enumerate(('north','east','south','west')):
 block+='    '+direction+'={layers={\n'
 for kind in ('shadow','body'):block+='      {filename="__tech-priests__/graphics/entity/advanced-space-cargo-v01/'+kind+'-d%d.png",width=1024,height=1024,scale=6.5*32/1024,shift={0,-0.21213203435596423}'%i+(',draw_as_shadow=true' if kind=='shadow' else '')+'},\n'
 block+='    }},\n'
block+='  } end\n';s=s[:a]+block+s[b:]
a=s.find('  -- Authored Advanced cargo contact registration')
if a<0:a=s.index('  if spec.space_platform_only then');b=a
else:b=s.index('  if spec.space_platform_only then',a)
block='''  -- Authored Advanced cargo contact registration. Owner requested native rotation.
  -- Four-way sprites/contacts rotate with the owner-corrected square footprint;
  -- inventory, research, recipe, platform restrictions and wire reach are unchanged.
  if spec.name == "tech-priests-advanced-space-cargo-inventory" then
    chest.direction_count = 4
    local original = table.deepcopy(chest.circuit_connector[1])
    chest.circuit_connector = {}
    local draw = {
'''
for rec in registration:block+='      {red='+vec(rec['points']['red'])+',green='+vec(rec['points']['green'])+',led='+vec(rec['led_target'])+',shifts={'+','.join(k+'='+vec(v) for k,v in rec['led_shifts'].items())+'}},\n'
block+='''    }
    for i = 1,4 do
      local c = table.deepcopy(original)
      c.points.wire.red = draw[i].red
      c.points.wire.green = draw[i].green
      c.points.shadow.red = {draw[i].red[1]+0.05,draw[i].red[2]+0.05}
      c.points.shadow.green = {draw[i].green[1]+0.05,draw[i].green[2]+0.05}
      for _, key in ipairs({"connector_main","connector_shadow","wire_pins","wire_pins_shadow"}) do c.sprites[key]=util.empty_sprite() end
      for key, shift in pairs(draw[i].shifts) do c.sprites[key].shift=shift end
      c.sprites.blue_led_light_offset=draw[i].led
      c.sprites.red_green_led_light_offset=draw[i].led
      chest.circuit_connector[i]=c
    end
  end
''';s=s[:a]+block+s[b:];p.write_text(s)
(O/'integration.json').write_text(json.dumps(dict(source_sha256=sha,export_sha256=h(O/'advanced-space-cargo-v01.glb'),prototype_sha256=h(p),runtime_art={q.name:h(q) for q in D.glob('*.png')},directional_contacts=registration,scope='Owner-authorized four native directions, directional pictures and matching graphical connector/LED points; inventory/recipes/research/reach/surface conditions unchanged',footprint_change='Owner explicitly corrected reference footprint to SQUARE. Advanced alone becomes5x5: selection±2.5/collision±2.2 on both axes;50slots/recipe/research/health unchanged.',native='pending current four-direction verification'),indent=2)+'\n');print('ADVANCED_CARGO_FOUR_NATIVE_DIRECTIONS_INTEGRATED')
