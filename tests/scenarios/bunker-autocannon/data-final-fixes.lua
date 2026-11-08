local m=require('prototypes.bunker_autocannon');m.finalize()
local t=data.raw['ammo-turret']['tech-priests-bunker-autocannon']
assert(t.attack_parameters.cooldown==11)
assert(math.abs(t.attacking_speed-1/11)<1e-9)
assert(t.tile_width==3 and t.tile_height==3)
assert(t.attacking_animation.direction_count==64 and t.attacking_animation.frame_count==32)
assert(#t.attacking_animation.stripes==64)
local ammo=data.raw.ammo['tech-priests-autocannon-magazine']
assert(ammo.magazine_size==20 and ammo.reload_time==5)
local donor=data.raw.recipe['firearm-magazine']
local original=table.deepcopy(donor.ingredients)
donor.ingredients={{type='item',name='iron-plate',amount=3},{type='item',name='copper-plate',amount=2}}
m.finalize()
local recipe=data.raw.recipe['tech-priests-autocannon-magazine']
assert(recipe.ingredients[1].amount==12 and recipe.ingredients[2].amount==8)
donor.ingredients=original;m.finalize()
assert(recipe.ingredients[1].name=='iron-plate' and recipe.ingredients[1].amount==16)
local target=table.deepcopy(data.raw['ammo-turret']['gun-turret'])
target.name='tp-bunker-test-target';target.max_health=1000000;target.resistances={};target.healing_per_tick=0
target.minable=nil
data:extend({target})
log('[BUNKER-CANNON-DATA] PASS native_shot_ticks=11 native_reload_ticks=5 average_ticks=11.25 damage=552.5 magazine=20 recipe=2*rifle_resources_per_round')
