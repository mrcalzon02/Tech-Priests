require('prototypes.bunker_autocannon').finalize()
-- An external-style third grenade proves discovery preserves a non-vanilla
-- projectile and damage type. These fixture prototypes never ship.
local capsule=table.deepcopy(data.raw.capsule.grenade)
capsule.name='tp-fixture-cryogenic-grenade'
local cryo=table.deepcopy(data.raw.projectile.grenade)
cryo.name='tp-fixture-cryogenic-grenade-projectile'
local function freeze(node)
  if type(node)~='table' then return end
  if node.type=='damage' then node.damage.type='tp-fixture-cryo' end
  for _,child in pairs(node) do if type(child)=='table' then freeze(child) end end
end
freeze(cryo.action)
local function use_cryo(node)
  if type(node)~='table' then return end
  if node.type=='projectile' then node.projectile=cryo.name end
  for _,child in pairs(node) do if type(child)=='table' then use_cryo(child) end end
end
use_cryo(capsule.capsule_action.attack_parameters.ammo_type)
data:extend({{type='damage-type',name='tp-fixture-cryo'},capsule,cryo})
require('prototypes.bunker_family').finalize_grenades()
assert(data.raw.ammo['tech-priests-lobber-cluster-grenade-magazine'])
assert(data.raw.ammo['tech-priests-lobber-tp-fixture-cryogenic-grenade-magazine'])
for _,grenade in ipairs({'grenade','cluster-grenade','tp-fixture-cryogenic-grenade'}) do
  local name=grenade=='grenade' and 'tech-priests-lobber-grenade-magazine' or 'tech-priests-lobber-'..grenade..'-magazine'
  local recipe=data.raw.recipe[name]
  assert(recipe.ingredients[1].name==grenade and recipe.ingredients[1].amount==6)
  assert(recipe.ingredients[2].name=='steel-plate' and recipe.ingredients[2].amount==2)
  assert(recipe.results[1].amount==1 and data.raw.ammo[name].magazine_size==6)
end
local target=table.deepcopy(data.raw['ammo-turret']['gun-turret'])
target.name='tp-family-target';target.max_health=1000000;target.resistances={}
target.healing_per_tick=0;target.minable=nil
data:extend({target})
local cannon=data.raw['ammo-turret']['tech-priests-bunker-autocannon']
local lobber=data.raw['ammo-turret']['tech-priests-bunker-lobber']
local dish=data.raw['electric-turret']['tech-priests-bunker-energy-dish']
assert(cannon and lobber and dish)
assert(data.raw.animation['tp-lobber-cycle-beauty-00'].frame_count==192)
assert(data.raw.animation['tp-lobber-entry-beauty-00'].frame_count==15)
assert(data.raw.animation['tp-lobber-settle-beauty-00'].frame_count==15)
assert(lobber.attack_parameters.cooldown==80 and lobber.attacking_speed>1/80)
for _,state in ipairs({'folded_animation','preparing_animation','prepared_animation','folding_animation','attacking_animation'}) do
  assert(lobber[state].direction_count==64 and lobber[state].width==256,'Native preview missing cap in '..state)
end
assert(data.raw.ammo['tech-priests-lobber-grenade-magazine'].magazine_size==6)
for _,turret in ipairs({cannon,lobber,dish}) do
  assert(turret.tile_width==3 and turret.tile_height==3)
end
log('[BUNKER-FAMILY] DATA_PASS three native weapons; all lobber frames retained')
