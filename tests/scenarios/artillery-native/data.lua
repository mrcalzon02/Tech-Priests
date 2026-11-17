require('prototypes.bunker_autocannon').register('tech-priests-artillery-probe')
local artillery=require('prototypes.bunker_artillery')
artillery.register('tech-priests-artillery-probe',{animation_pilot=true});artillery.finalize()
local t=data.raw['artillery-turret'][artillery.name]
assert(t.base_picture.layers[2].filename:find('bunker%-autocannon/'),'Actual bunker base required')
assert(t.base_picture.layers[3].apply_runtime_tint and t.base_picture.layers[3].filename:find('team%-mask'),'Force-coloured corner stanchions required')
assert(t.cannon_base_pictures.filename=='__core__/graphics/empty.png','A static cap must not paint over the animated reload cage')
local visuals=require('scripts.artillery_barrage_visuals')
for key in pairs(visuals.headings)do
  local animation=assert(data.raw.animation[string.format('tp-artillery-body-%02d',tonumber(key))])
  assert(animation.filename:find('bunker%-artillery/'),'Actual modeled animated cap required')
end
local target=table.deepcopy(data.raw['unit-spawner']['biter-spawner'])
target.name='tp-artillery-test-target';target.max_health=10000000;target.resistances={};target.healing_per_tick=0
target.autoplace=nil;target.minable=nil
local stock=table.deepcopy(t);stock.name='tp-artillery-stock-control';stock.minable=nil;stock.gun='artillery-wagon-cannon'
data:extend({target,stock})
local captured=0;for _ in pairs(visuals.headings)do captured=captured+1 end
log('[ARTILLERY TEST] Actual bunker foundation and '..captured..' source-pose headings; native artillery combat')
