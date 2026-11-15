local cannon=require('prototypes.bunker_twin_cannon')
cannon.register('tech-priests-twin-cannon-probe',{headless=true});cannon.finalize()
local target=table.deepcopy(data.raw['ammo-turret']['gun-turret'])
target.name='tp-cannon-launch-target';target.max_health=10000000;target.resistances={};target.healing_per_tick=0;target.minable=nil
target.collision_box={{-.25,-.25},{.25,.25}};target.selection_box={{-.5,-.5},{.5,.5}}
local control=table.deepcopy(data.raw['ammo-turret']['tech-priests-bunker-twin-cannon'])
control.name='tp-cannon-stock-control';control.minable=nil
control.attack_parameters.cooldown=data.raw.gun['tank-cannon'].attack_parameters.cooldown
data:extend({target,control})
log('[TWIN-CANNON] PHYSICS_ONLY_PLACEHOLDER_ART; no graphical claim')
