local c=require('prototypes.bunker_twin_cannon');c.register('tech-priests-twin-cannon-probe',{headless=true});c.finalize()
local armor=table.deepcopy(data.raw['ammo-turret']['gun-turret'])
armor.name='tp-cannon-armour-target';armor.max_health=10000;armor.minable=nil;armor.healing_per_tick=0
armor.resistances={{type='physical',decrease=12,percent=40}};armor.collision_box={{-.8,-.3},{.8,.3}}
local line=table.deepcopy(armor);line.name='tp-cannon-line-target';line.max_health=100;line.resistances={}
data:extend({armor,line})
