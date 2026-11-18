"""Two true native tank facings, with precisely registered physical contacts."""
from pathlib import Path
import json,hashlib,shutil,math
import numpy as np
from PIL import Image
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/pressurized-fluid-vault/v01';D=R/'tech-priests_src/graphics/entity/pressurized-fluid-vault-v01';h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();source=h(O/'pressurized-fluid-vault-v01.blend');cfg=json.loads((O/'contract.json').read_text());meta=json.loads((O/'construction.json').read_text())
for n in ('inspection.json','port-audit.json','captures/capture.json'):
 d=json.loads((O/n).read_text());assert d['source_sha256']==source
 if n!='captures/capture.json':assert d['passed']
D.mkdir(exist_ok=True)
for src,dst in [('body-d0.png','north.png'),('body-d1.png','east.png'),('shadow-d0.png','north-shadow.png'),('shadow-d1.png','east-shadow.png'),('icon.png','icon.png')]:shutil.copy2(O/'captures'/src,D/dst)
def project(p,east):
 x,y,z=p
 if east:x,y=y,-x
 return [x,-y-z/math.sqrt(2)+.44/math.sqrt(2)-.046875]
connectors=cfg['prototype']['circuit_connector'];registration=[]
base=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/data/base')
for i,c in enumerate(connectors):
 east=i%2==1;points={name:project(p,east) for name,p in meta['terminals'].items()};sprites={}
 for key in ('led_blue','led_blue_off','led_green','led_red'):
  spr=c['sprites'][key];im=Image.open(base/spr['filename'].replace('__base__/','')).convert('RGBA').crop((spr['x'],spr['y'],spr['x']+spr['width'],spr['y']+spr['height']));a=np.asarray(im)[:,:,3].astype(float);Y,X=np.mgrid[0:spr['height'],0:spr['width']];offset=[((X*a).sum()/a.sum()-spr['width']/2)*spr['scale']/32,((Y*a).sum()/a.sum()-spr['height']/2)*spr['scale']/32];target=project(meta['leds']['blue' if key in ('led_blue','led_blue_off') else 'red-green'],east);sprites[key]=[target[j]-offset[j] for j in range(2)]
 registration.append(dict(points=points,led_shifts=sprites,blue_light=project(meta['leds']['blue'],east),red_green_light=project(meta['leds']['red-green'],east)))
p=R/'tech-priests_src/prototypes/martian_stone_cache.lua';s=p.read_text();ID=cfg['id'];shift=cfg['registration']['shift'][1]
if 'pressurized-fluid-vault-v01/icon.png' not in s:s=s.replace('local function icon_path(name)\n','local function icon_path(name)\n  if name == "'+ID+'" then return "__tech-priests__/graphics/entity/pressurized-fluid-vault-v01/icon.png" end\n',1)
if 'local function authored_fluid_vault_picture' not in s:
 block='''local function authored_fluid_vault_picture(facing)
  local root = "__tech-priests__/graphics/entity/pressurized-fluid-vault-v01/"
  local registration = {0, %s}
  return {layers = {
    {filename=root .. facing .. "-shadow.png", width=512, height=512, scale=0.25, shift=registration, draw_as_shadow=true},
    {filename=root .. facing .. ".png", width=512, height=512, scale=0.25, shift=registration}
  }}
end

'''%repr(shift)
 s=s.replace('local function make_fluid_vault()',block+'local function make_fluid_vault()',1)
old='  tank.pictures = {\n    picture = picture_for(name, 0.068)\n  }'
new='''  tank.pictures = {picture = {
    north=authored_fluid_vault_picture("north"), east=authored_fluid_vault_picture("east"),
    south=authored_fluid_vault_picture("north"), west=authored_fluid_vault_picture("east")
  }}'''
s=s.replace(old,new,1)
if '-- Authored fluid-vault contact draw registration' not in s:
 lines=['  -- Authored fluid-vault contact draw registration: original large-tank pixel','  -- anchors do not fit this compact vessel. Only graphics/points change; native','  -- amount/temperature controls, wire reach, fluid ports and capacity stay fixed.','  local contact_draw = {']
 for rec in registration:
  vec=lambda p:'{%s,%s}'%(repr(float(p[0])),repr(float(p[1])))
  lines.append('    {red='+vec(rec['points']['red'])+', green='+vec(rec['points']['green'])+', blue_light='+vec(rec['blue_light'])+', red_green_light='+vec(rec['red_green_light'])+', leds={'+','.join(k+'='+vec(v) for k,v in rec['led_shifts'].items())+'}},')
 lines+=['  }','  for i, connector in ipairs(tank.circuit_connector or {}) do','    local draw = contact_draw[i]','    if draw then','      connector.points.wire.red = draw.red','      connector.points.wire.green = draw.green','      connector.points.shadow.red = {draw.red[1]+0.08,draw.red[2]+0.08}','      connector.points.shadow.green = {draw.green[1]+0.08,draw.green[2]+0.08}','      local sprites = connector.sprites','      for _, key in ipairs({"connector_main","connector_shadow","wire_pins","wire_pins_shadow"}) do sprites[key]=util.empty_sprite() end','      for key, shift in pairs(draw.leds) do sprites[key].shift = shift end','      sprites.blue_led_light_offset=draw.blue_light','      sprites.red_green_led_light_offset=draw.red_green_light','    end','  end','']
 s=s.replace('  tank.water_reflection = nil','\n'.join(lines)+'  tank.water_reflection = nil',1)
p.write_text(s);(O/'integration.json').write_text(json.dumps(dict(source_sha256=source,export_sha256=h(O/'pressurized-fluid-vault-v01.glb'),prototype_sha256=h(p),runtime_art={q.name:h(q) for q in D.glob('*.png')},contact_registration=registration,scope='Only tank pictures/icon and graphical circuit contacts/backing/LED positions; all fluid, placement, direction, circuit behavior, research and recipe fields preserved',native_verification='pending current exact-source test'),indent=2)+'\n');print('FLUID_VAULT_DIRECTIONAL_PRODUCTION_GRAPHICS_INTEGRATED')
