require('prototypes.bunker_autocannon').finalize()
require('prototypes.bunker_family').finalize_grenades()
require('prototypes.bunker_bullet_weapons').finalize()
-- Make source effects observable without a connected graphical player.
local function expose_muzzles(node)
  if type(node)~='table' then return end
  if node.entity_name=='explosion-gunshot' and node.trigger_created_entity then node.only_when_visible=false end
  for _,child in pairs(node) do if type(child)=='table' then expose_muzzles(child) end end
end
for _,ammo in pairs(data.raw.ammo) do expose_muzzles(ammo.ammo_type) end
local stock=data.raw['ammo-turret']['gun-turret']
local piano=data.raw['ammo-turret']['tech-priests-bunker-chicago-piano']
local twin=data.raw['ammo-turret']['tech-priests-bunker-twin-minigun']
assert(piano.attack_parameters.cooldown==data.raw.gun['submachine-gun'].attack_parameters.cooldown)
assert(twin.attack_parameters.cooldown==stock.attack_parameters.cooldown)
assert(twin.attack_parameters.ammo_consumption_modifier==2*(stock.attack_parameters.ammo_consumption_modifier or 1))
assert(twin.attack_parameters.damage_modifier==2*(stock.attack_parameters.damage_modifier or 1))
local target=table.deepcopy(stock);target.name='tp-bullet-proof-target';target.max_health=1000000;target.resistances={};target.healing_per_tick=0;target.minable=nil
data:extend({target})
if HEADLESS_GRAPHICS then
  local function blank() return {filename='__core__/graphics/empty.png',width=1,height=1,frame_count=1,direction_count=1} end
  for _,t in ipairs({piano,twin}) do
    for _,state in ipairs({'folded_animation','preparing_animation','prepared_animation','folding_animation','attacking_animation'}) do t[state]=blank() end
    t.icon='__base__/graphics/icons/gun-turret.png';t.icon_size=64
    data.raw.item[t.name].icon=t.icon;data.raw.item[t.name].icon_size=64
    data.raw.technology[t.name].icon=t.icon;data.raw.technology[t.name].icon_size=64
  end
  for name,animation in pairs(data.raw.animation) do
    if name:find('tp-chicago-piano-',1,true)==1 or name:find('tp-twin-minigun-',1,true)==1 then
      animation.filename='__core__/graphics/empty.png';animation.width=1;animation.height=1;animation.frame_count=1;animation.line_length=1
    end
  end
  log('[BULLET-TURRETS] HEADLESS_PLACEHOLDERS_ONLY; no visual claim')
end
