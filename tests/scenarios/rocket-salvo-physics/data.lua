local rocket=require('prototypes.bunker_rocket_salvo')
rocket.register('tech-priests-rocket-probe',{headless=true});rocket.finalize()
local target=table.deepcopy(data.raw['ammo-turret']['gun-turret'])
target.name='tp-rocket-test-target';target.max_health=10000000;target.resistances={};target.healing_per_tick=0;target.minable=nil
target.collision_box={{-.25,-.25},{.25,.25}};target.selection_box={{-.5,-.5},{.5,.5}}
local control=table.deepcopy(data.raw['ammo-turret']['tech-priests-bunker-rocket-salvo'])
control.name='tp-rocket-stock-control';control.minable=nil
control.attack_parameters=table.deepcopy(data.raw.gun['rocket-launcher'].attack_parameters)
control.attack_parameters.min_range=8
data:extend({target,control})
log('[ROCKET PILOT] PHYSICS ONLY; placeholder art, not graphical acceptance')
