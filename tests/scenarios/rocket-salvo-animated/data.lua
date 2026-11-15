require('prototypes.bunker_autocannon').register('tech-priests-rocket-animation-pilot')
require('prototypes.bunker_rocket_salvo').register('tech-priests-rocket-animation-pilot',{capture_headings={0,16,32,48}})
require('prototypes.bunker_rocket_salvo').finalize()
local target=table.deepcopy(data.raw['ammo-turret']['gun-turret'])
target.name='tp-rocket-animation-target';target.max_health=1000000;target.resistances={};target.healing_per_tick=0;target.minable=nil
data:extend({target})
