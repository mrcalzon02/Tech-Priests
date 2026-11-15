local target=table.deepcopy(data.raw['ammo-turret']['gun-turret'])
target.name='tp-cannon-acceptance-target';target.max_health=10000000;target.resistances={};target.healing_per_tick=0;target.minable=nil
target.collision_box={{-.25,-.25},{.25,.25}}
data:extend({target})
