-- Private native press clock and intake filters; neither recipe consumes stock.
local c=require('__tp-mh7-pellet-decay__/config')
for _,name in ipairs{'tp-mh7-forge-cycle-token','tp-mh7-forge-cycle-result','tp-mh7-forge-accept-guard'} do
 local item=table.deepcopy(data.raw.item['iron-stick']);item.name=name;item.stack_size=1;item.flags={'not-stackable'};item.hidden=true;data:extend{item}
end
require('native-data')
local ingredients={}
for _,stage in ipairs(c.stages) do ingredients[#ingredients+1]={type='item',name=stage.name,amount=1} end
ingredients[#ingredients+1]={type='item',name='tp-mh7-forge-accept-guard',amount=1}
data:extend{{type='recipe',name='tp-mh7-review-forge-accept',categories={'tp-mh7-review-forging'},enabled=true,hidden=true,
 energy_required=8,ingredients=ingredients,results={{type='item',name='tp-mh7-forge-cycle-result',amount=1,independent_probability=0}},preserve_products_in_machine_output=false}}
local work=data.raw.recipe['tp-mh7-review-forge-work'];work.hidden=true;work.allow_productivity=false
for i=1,5 do
 data:extend{{type='recipe',name='tp-mh7-review-forge-dispatch-'..i,categories={'tp-mh7-review-forging'},enabled=true,hidden=true,
  energy_required=8,ingredients={{type='item',name='tp-mh7-forge-accept-guard',amount=1}},
  results={{type='item',name=i==5 and c.inert or c.formed_stages[i].name,amount=1}},preserve_products_in_machine_output=false}}
end
local machine=data.raw['assembling-machine']['tp-mh7-review-forge'];machine.show_recipe_icon=false;machine.show_recipe_icon_on_map=false
machine.use_mirroring=false
-- Item-only crafting machines otherwise discard direction when no fluid
-- recipe is active. A real forward item-egress vector makes this press
-- directional without inventing a gameplay fluid connection.
machine.vector_to_place_result={0,-1.1}
machine.localised_description='Forms raw pellets without repairing integrity, improving quality or refreshing instability. Uncontained stock keeps decaying throughout the press cycle.'
