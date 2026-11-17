local c=require('hydrogen.config')
for _,name in ipairs{'tp-mh7-assembler-cycle-token','tp-mh7-assembler-cycle-result','tp-mh7-assembler-accept-guard'} do
 local item=table.deepcopy(data.raw.item['iron-stick']);item.name=name;item.stack_size=1;item.flags={'not-stackable'};item.hidden=true;item.hidden_in_factoriopedia=true;item.auto_recycle=false;data:extend{item}
end

local ingredients={};for _,stage in ipairs(c.formed_stages) do ingredients[#ingredients+1]={type='item',name=stage.name,amount=3} end
ingredients[#ingredients+1]={type='item',name=c.shell,amount=3};ingredients[#ingredients+1]={type='item',name=c.inert,amount=1};ingredients[#ingredients+1]={type='item',name='tp-mh7-assembler-accept-guard',amount=1}
data:extend{{type='recipe',name='tp-mh7-assembler-accept',categories={'tp-mh7-review-assembly'},enabled=true,hidden=true,hidden_in_factoriopedia=true,auto_recycle=false,energy_required=16,ingredients=ingredients,results={{type='item',name='tp-mh7-assembler-cycle-result',amount=1,independent_probability=0}},preserve_products_in_machine_output=false}}
local work=data.raw.recipe['tp-mh7-assembler-work'];work.hidden=true;work.allow_productivity=false
for _,r in ipairs{{'contained',c.contained},{'inert',c.inert}} do data:extend{{type='recipe',name='tp-mh7-assembler-dispatch-'..r[1],categories={'tp-mh7-review-assembly'},enabled=true,hidden=true,hidden_in_factoriopedia=true,auto_recycle=false,energy_required=16,ingredients={{type='item',name='tp-mh7-assembler-accept-guard',amount=1}},results={{type='item',name=r[2],amount=1}},preserve_products_in_machine_output=false}} end
local machine=data.raw['assembling-machine']['tp-mh7-canister-assembler'];machine.use_mirroring=false;machine.vector_to_place_result={0,-1.5};machine.show_recipe_icon=false;machine.show_recipe_icon_on_map=false
machine.tile_width=4;machine.tile_height=4
machine.localised_name='Canister assembler'
machine.localised_description='Clamps and seals formed pellets in pressure shells. Unsealed pellets keep decaying; sealed contents retain their existing health, quality and remaining instability.'
local sound='__tech-priests__/hydrogen/sound/'
machine.working_sound={sound={filename=sound..'assembler-working.ogg',volume=.65,audible_distance_modifier=1.5,priority=25,preload=true},idle_sound={filename=sound..'assembler-idle.ogg',volume=.07,audible_distance_modifier=.65},activate_sound={filename=sound..'assembler-start.ogg',volume=.45,audible_distance_modifier=1.2},deactivate_sound={filename=sound..'assembler-stop.ogg',volume=.40,audible_distance_modifier=1.1},match_volume_to_activity=true,match_speed_to_activity=false,fade_in_ticks=12,fade_out_ticks=20,max_sounds_per_prototype=3}
