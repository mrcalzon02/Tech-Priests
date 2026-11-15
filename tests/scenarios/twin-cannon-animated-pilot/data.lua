local mod='tech-priests-twin-cannon-pilot'
require('prototypes.bunker_autocannon').register(mod)
require('prototypes.bunker_twin_cannon').register(mod,{capture_headings={0,8}})
require('prototypes.bunker_autocannon').finalize()
require('prototypes.bunker_twin_cannon').finalize()
local target=table.deepcopy(data.raw['ammo-turret']['gun-turret'])
target.name='tp-cannon-pilot-target';target.max_health=1000000;target.minable=nil;target.resistances={};target.healing_per_tick=0
data:extend({target})
-- The pilot intentionally exercises only the two fully captured headings.
data.raw['ammo-turret']['tech-priests-bunker-twin-cannon'].rotation_speed=.004
log('[TWIN-CANNON] REAL_ANIMATED_ART_PILOT directions 0,8; no placeholder sprites')
