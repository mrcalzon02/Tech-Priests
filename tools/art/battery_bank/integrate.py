"""Pack rendered state lenses and integrate only accumulator graphics."""
from pathlib import Path
import json,hashlib,shutil,re
from PIL import Image
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/primitive-battery-bank/v01';D=R/'tech-priests_src/graphics/entity/primitive-battery-bank-v01';h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();source=h(O/'primitive-battery-bank-v01.blend')
for n in ('inspection.json','route-audit.json','captures/capture.json'):
 r=json.loads((O/n).read_text());assert r['source_sha256']==source
 if n!='captures/capture.json':assert r['passed']
D.mkdir(exist_ok=True)
for src,dst in [('body-d0.png','body.png'),('shadow-d0.png','shadow.png'),('icon.png','icon.png')]:shutil.copy2(O/'captures'/src,D/dst)
for state in ('charge','discharge'):
 atlas=Image.new('RGBA',(4096,512))
 for i in range(8):
  frame=Image.open(O/'captures'/(state+'-f%02d.png'%i)).convert('RGBA');assert frame.size==(512,512);assert frame.getbbox();atlas.paste(frame,(i*512,0))
 atlas.save(D/(state+'.png'))
p=R/'tech-priests_src/prototypes/martian_stone_cache.lua';s=p.read_text();ID='tech-priests-stone-cache-primitive-acclimator-battery-bank'
if 'primitive-battery-bank-v01/icon.png' not in s:s=s.replace('local function icon_path(name)\n','local function icon_path(name)\n  if name == "'+ID+'" then return "__tech-priests__/graphics/entity/primitive-battery-bank-v01/icon.png" end\n',1)
if 'primitive-battery-bank-v01/body.png' not in s:
 block='''  -- Authored primitive accumulator: native capacity, rates and ports unchanged.
  if name == "tech-priests-stone-cache-primitive-acclimator-battery-bank" then
    local registration = {0, -0.01213203435596423}
    return {layers = {
      {filename="__tech-priests__/graphics/entity/primitive-battery-bank-v01/shadow.png", priority="high", width=512, height=512, scale=3.0*32/512, shift=registration, draw_as_shadow=true},
      {filename="__tech-priests__/graphics/entity/primitive-battery-bank-v01/body.png", priority="high", width=512, height=512, scale=3.0*32/512, shift=registration}
    }}
  end
'''
 s=s.replace('local function picture_for(name, scale, shift)\n','local function picture_for(name, scale, shift)\n'+block,1)
state_function='''local function bank_state_animation(state)
  local root = "__tech-priests__/graphics/entity/primitive-battery-bank-v01/"
  local registration = {0, -0.01213203435596423}
  return {layers = {
    {filename=root .. "shadow.png", priority="high", width=512, height=512,
      repeat_count=8, animation_speed=0.20, scale=3.0*32/512, shift=registration, draw_as_shadow=true},
    {filename=root .. "body.png", priority="high", width=512, height=512,
      repeat_count=8, animation_speed=0.20, scale=3.0*32/512, shift=registration},
    {filename=root .. state .. ".png", priority="high", width=512, height=512,
      frame_count=8, line_length=8, animation_speed=0.20, scale=3.0*32/512, shift=registration, draw_as_glow=true}
  }}
end
'''
if 'local function bank_state_animation' not in s:s=s.replace('local function make_battery_bank()',state_function+'\nlocal function make_battery_bank()',1)
else:s=re.sub(r'local function bank_state_animation\(state\).*?\nend\n',lambda match:state_function,s,count=1,flags=re.S)
s=s.replace('charge_animation = animation_for(name, 0.068)','charge_animation = bank_state_animation("charge")',1).replace('discharge_animation = animation_for(name, 0.068)','discharge_animation = bank_state_animation("discharge")',1)
# The accumulator connector is a single definition, unlike the container list.
if '-- Authored cabinet provides the connector backing' not in s:s=s.replace('  bank.water_reflection = nil','''  -- Authored cabinet provides the connector backing; original wire pins,
  -- native LED states, points, signal and wire reach remain unchanged.
  if bank.circuit_connector and bank.circuit_connector.sprites then
    bank.circuit_connector.sprites.connector_main = util.empty_sprite()
    bank.circuit_connector.sprites.connector_shadow = util.empty_sprite()
  end
  bank.water_reflection = nil''',1)
if '-- Seat inherited LED pixels' not in s:
 s=s.replace('    bank.circuit_connector.sprites.connector_shadow = util.empty_sprite()\n','''    bank.circuit_connector.sprites.connector_shadow = util.empty_sprite()
    -- Seat inherited LED pixels on the authored cabinet, preserving native states.
    local sprites = bank.circuit_connector.sprites
    local dx, dy = 0.18087693924989555, -0.1448376449540326
    for _, key in ipairs({"led_blue", "led_blue_off", "led_green", "led_red"}) do
      if sprites[key] then
        local shift = sprites[key].shift or {0,0}
        sprites[key].shift = {(shift[1] or 0)+dx, (shift[2] or 0)+dy}
      end
    end
    for _, key in ipairs({"blue_led_light_offset", "red_green_led_light_offset"}) do
      if sprites[key] then sprites[key] = {sprites[key][1]+dx, sprites[key][2]+dy} end
    end
''',1)
p.write_text(s);(O/'integration.json').write_text(json.dumps(dict(source_sha256=source,export_sha256=h(O/'primitive-battery-bank-v01.glb'),prototype_sha256=h(p),runtime_art={q.name:h(q) for q in D.glob('*.png')},state='Production graphics candidate; native electrical verification and owner approval separate',working_layers='Eight genuine charge lens and eight discharge lens frames; static cells, busbars and guard; native cooldowns preserved',native_leds='Inherited artwork re-seated on measured cabinet bezels; original states, wire pins, points, signal and reach preserved'),indent=2)+'\n');print('PRIMITIVE_BANK_GRAPHICS_INTEGRATED')
