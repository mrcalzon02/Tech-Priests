local rocket=require('prototypes.bunker_rocket_salvo')
require('prototypes.bunker_autocannon').register('tech-priests-rocket-probe')
rocket.register('tech-priests-rocket-probe',{static_shadow_pilot=true,shadow_cell=256});rocket.finalize()
local actual=data.raw['ammo-turret']['tech-priests-bunker-rocket-salvo']
local foundation=actual.base_picture or (actual.graphics_set and actual.graphics_set.base_visualisation.animation)
assert(foundation and foundation.north.layers[2].filename:find('bunker%-autocannon/'),'Actual bunker base required')
assert(actual.prepared_animation.direction_count==64,'All modeled headings required')
for _,stripe in ipairs(actual.prepared_animation.stripes)do
  assert(stripe.filename:find('bunker%-rocket%-salvo/native%-'),'Modeled turret top required')
end
local target=table.deepcopy(data.raw.unit['big-biter'])
target.name='tp-rocket-test-target';target.max_health=10000000;target.resistances={};target.healing_per_tick=0;target.minable=nil
target.collision_box={{-.25,-.25},{.25,.25}};target.selection_box={{-.5,-.5},{.5,.5}}
local control=table.deepcopy(data.raw['ammo-turret']['tech-priests-bunker-rocket-salvo'])
control.name='tp-rocket-stock-control';control.minable=nil
control.attack_parameters=table.deepcopy(data.raw.gun['rocket-launcher'].attack_parameters)
control.attack_parameters.min_range=8
-- The control keeps stock launcher mechanics, with the same complete bunker
-- model as the tested weapon. Enemy targets are real biter models.
local function full_preview(node)
  if type(node)~='table' then return end
  if node.filename then node.filename=node.filename:gsub('native%-','preview-')end
  for _,v in pairs(node) do if type(v)=='table' then full_preview(v)end end
end
for _,state in ipairs({'folded_animation','preparing_animation','prepared_animation','folding_animation','attacking_animation'})do full_preview(control[state])end
data:extend({target,control})
log('[ROCKET COMBAT] Actual bunker foundation and 64 modeled turret headings; no weapon stand-ins')
