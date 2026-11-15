"""Read final native weapon and ammo values from an isolated full-mod stage.

No balance values or user installations are changed. Area damage is recorded
separately from direct impact; totals over a battle are not per-shot damage.
"""
import json, subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
stage=ROOT/'build/twin-cannon/main-integration'
out=ROOT/'build/rocket-salvo/balance-audit';out.mkdir(parents=True,exist_ok=True)
final=stage/'mods/tech-priests/data-final-fixes.lua'
original=final.read_bytes()
lua=r'''
local function encode(v)
  if type(v)=='string' then return string.format('%q',v):gsub('\\\n','\\n') end
  if type(v)=='number' or type(v)=='boolean' then return tostring(v) end
  if type(v)~='table' then return 'null' end
  local fields={}
  for k,value in pairs(v) do fields[#fields+1]=encode(tostring(k))..':'..encode(value) end
  table.sort(fields);return '{'..table.concat(fields,',')..'}'
end
local report={weapons={},ammo={},projectiles={},beams={}}
for _,kind in ipairs({'ammo-turret','electric-turret','gun'}) do
  for name,weapon in pairs(data.raw[kind]) do
    if name:find('tech-priests-bunker-',1,true)==1 or name=='gun-turret' or name=='laser-turret' or name=='submachine-gun' or name=='tank-cannon' or name=='rocket-launcher' then
      local a=weapon.attack_parameters
      report.weapons[name]={kind=kind,cooldown=a.cooldown,range=a.range,min_range=a.min_range or 0,
        damage_modifier=a.damage_modifier or 1,ammo_consumption_modifier=a.ammo_consumption_modifier or 1,
        ammo_category=a.ammo_category,ammo_type=a.ammo_type}
    end
  end
end
for _,name in ipairs({'firearm-magazine','piercing-rounds-magazine','uranium-rounds-magazine','cannon-shell','explosive-cannon-shell','uranium-cannon-shell','explosive-uranium-cannon-shell','rocket','explosive-rocket','tech-priests-autocannon-magazine','tech-priests-lobber-grenade-magazine'})do
  local a=data.raw.ammo[name]
  report.ammo[name]={magazine_size=a.magazine_size or 1,reload_time=a.reload_time or 0,ammo_type=a.ammo_type}
end
for _,name in ipairs({'cannon-projectile','explosive-cannon-projectile','uranium-cannon-projectile','explosive-uranium-cannon-projectile','rocket','explosive-rocket','grenade','tech-priests-autocannon-projectile'})do
  local p=data.raw.projectile[name]
  report.projectiles[name]={action=p.action,final_action=p.final_action,piercing_damage=p.piercing_damage}
end
for _,name in ipairs({'laser-beam','tech-priests-dish-zap'})do
  local b=data.raw.beam[name]
  report.beams[name]={action=b.action,damage_interval=b.damage_interval}
end
log('[BUNKER_BALANCE_JSON]'..encode(report))
'''
try:
    final.write_bytes(original+b'\n'+lua.encode())
    exe=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/Factorio.exe')
    config=ROOT/'build/rocket-salvo/main-physics/config.ini'
    command=[str(exe),'--config',str(config),'--mod-directory',str(stage/'mods'),'--create',str(out/'audit.zip')]
    with (out/'audit.log').open('w') as stream:
        subprocess.run(command,cwd=out,stdout=stream,stderr=subprocess.STDOUT,check=True)
finally:
    final.write_bytes(original)
line=next(x for x in (out/'audit.log').read_text(errors='replace').splitlines() if '[BUNKER_BALANCE_JSON]' in x)
report=json.loads(line.split('[BUNKER_BALANCE_JSON]',1)[1])
(out/'final-prototypes.json').write_text(json.dumps(report,indent=2)+'\n')
for name,w in report['weapons'].items():
    print(name,'cooldown',w['cooldown'],'damage x',w['damage_modifier'],'ammo x',w['ammo_consumption_modifier'])
