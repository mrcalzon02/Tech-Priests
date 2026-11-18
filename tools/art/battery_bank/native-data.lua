-- Private electrical proof fixtures. Never copied to the production mod.
local util=require('util')
data:extend({{
 type='electric-energy-interface',name='bank-proof-source',icon='__base__/graphics/icons/accumulator.png',icon_size=64,flags={'placeable-off-grid'},max_health=100,
 collision_box={{-.1,-.1},{.1,.1}},selection_box={{-.1,-.1},{.1,.1}},picture=util.empty_sprite(),
 energy_source={type='electric',buffer_capacity='500kJ',usage_priority='primary-output',input_flow_limit='0W',output_flow_limit='1MW'},energy_production='1MW',energy_usage='0W'
},{
 type='electric-energy-interface',name='bank-proof-load',icon='__base__/graphics/icons/accumulator.png',icon_size=64,flags={'placeable-off-grid'},max_health=100,
 collision_box={{-.1,-.1},{.1,.1}},selection_box={{-.1,-.1},{.1,.1}},picture=util.empty_sprite(),
 energy_source={type='electric',buffer_capacity='50kJ',usage_priority='secondary-input',input_flow_limit='1MW',output_flow_limit='0W'},energy_production='0W',energy_usage='1MW'
}})
