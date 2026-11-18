-- Tech Priests: owner-accepted Martian power pylons and spinning vox arrays.
-- Model-space wire anchors and exact 1x1 / 2x2 / 3x3 footprints.
local models = {{["name"]="tech-priests-martian-power-1",["family"]="power",["tier"]=1,["pixels"]=230,["body_scale"]=0.5008695652173913,["shift"]={0.0,-0.7544813632965088},["height"]=2.424999713897705,["wires"]={["red"]={-0.2736000180244446,-1.7076627016067505},["copper"]={0.0,-1.7076627016067505},["green"]={0.2736001253128052,-1.7076627016067505}},["shadow"]={["red"]={0.8131499999999998,-1.1099808697675828},["copper"]={1.0867499999999999,-1.1099808697675828},["green"]={1.36035,-1.1099808697675828}},["shadow_pixels"]=256,["rotating"]=false},{["name"]="tech-priests-martian-power-2",["family"]="power",["tier"]=2,["pixels"]=358,["body_scale"]=0.500558659217877,["shift"]={0.0,-1.1698360204696654},["height"]=3.7599997520446777,["wires"]={["red"]={-0.5939999103546142,-2.651650309562683},["copper"]={0.0,-2.651650309562683},["green"]={0.5939999103546142,-2.651650309562683}},["shadow"]={["red"]={1.0935000000000001,-1.7235727791422097},["copper"]={1.6875,-1.7235727791422097},["green"]={2.2815,-1.7235727791422097}},["shadow_pixels"]=448,["rotating"]=false},{["name"]="tech-priests-martian-power-3",["family"]="power",["tier"]=3,["pixels"]=474,["body_scale"]=0.49957805907173,["shift"]={0.0,-1.5851908564567567},["height"]=5.09499979019165,["wires"]={["red"]={-0.8999999046325684,-3.595637834072113},["copper"]={0.0,-3.595637834072113},["green"]={0.8999999046325684,-3.595637834072113}},["shadow"]={["red"]={1.3882500000000007,-2.337164688516837},["copper"]={2.2882500000000006,-2.337164688516837},["green"]={3.1882500000000005,-2.337164688516837}},["shadow_pixels"]=640,["rotating"]=false},{["name"]="tech-priests-martian-comms-1",["family"]="comms",["tier"]=1,["pixels"]=230,["body_scale"]=0.5008695652173913,["shift"]={0.0,-0.7413330674171448},["height"]=2.3827402591705322,["wires"]={["red"]={-0.2591999888420105,-0.7389264822006226},["copper"]={0.0,-0.7389264822006226},["green"]={0.2592000961303711,-0.7389264822006226}},["shadow"]={["red"]={0.31455,-0.42338018523544535},["copper"]={0.57375,-0.42338018523544535},["green"]={0.83295,-0.42338018523544535}},["shadow_pixels"]=256,["rotating"]=false},{["name"]="tech-priests-martian-comms-2",["family"]="comms",["tier"]=2,["pixels"]=358,["body_scale"]=0.500558659217877,["shift"]={0.0,-1.2114783287048339},["height"]=3.8938446044921875,["wires"]={["red"]={-0.5184000492095947,-1.1172285079956055},["copper"]={0.0,-1.1172285079956055},["green"]={0.5184000492095947,-1.1172285079956055}},["shadow"]={["red"]={0.39960000000000007,-0.6123544725075503},["copper"]={0.918,-0.6123544725075503},["green"]={1.4364,-0.6123544725075503}},["shadow_pixels"]=448,["rotating"]=true},{["name"]="tech-priests-martian-comms-3",["family"]="comms",["tier"]=3,["pixels"]=474,["body_scale"]=0.49957805907173,["shift"]={0.0,-1.6501675069332125},["height"]=5.303844451904297,["wires"]={["red"]={-0.7776000022888184,-1.3823934614658355},["copper"]={0.0,-1.3823934614658355},["green"]={0.7776000022888184,-1.3823934614658355}},["shadow"]={["red"]={0.41264999999999996,-0.7277896545362542},["copper"]={1.19025,-0.7277896545362542},["green"]={1.96785,-0.7277896545362542}},["shadow_pixels"]=640,["rotating"]=true}}
local tuning={["power-1"]={["health"]=250,["technology"]="electronics",["seconds"]=2,["ingredients"]={{["type"]="item",["name"]="iron-plate",["amount"]=4},{["type"]="item",["name"]="copper-cable",["amount"]=8},{["type"]="item",["name"]="stone-brick",["amount"]=4}}},["power-2"]={["health"]=500,["technology"]="electric-energy-distribution-1",["seconds"]=4,["ingredients"]={{["type"]="item",["name"]="tech-priests-martian-power-1",["amount"]=1},{["type"]="item",["name"]="steel-plate",["amount"]=8},{["type"]="item",["name"]="copper-cable",["amount"]=16},{["type"]="item",["name"]="stone-brick",["amount"]=8}}},["power-3"]={["health"]=1000,["technology"]="electric-energy-distribution-2",["seconds"]=8,["ingredients"]={{["type"]="item",["name"]="tech-priests-martian-power-2",["amount"]=1},{["type"]="item",["name"]="steel-plate",["amount"]=16},{["type"]="item",["name"]="copper-cable",["amount"]=32},{["type"]="item",["name"]="concrete",["amount"]=12}}},["comms-1"]={["health"]=300,["technology"]="radar",["seconds"]=4,["ingredients"]={{["type"]="item",["name"]="tech-priests-martian-power-1",["amount"]=1},{["type"]="item",["name"]="electronic-circuit",["amount"]=10},{["type"]="item",["name"]="iron-gear-wheel",["amount"]=4},{["type"]="item",["name"]="copper-cable",["amount"]=12}}},["comms-2"]={["health"]=600,["technology"]="advanced-circuit",["seconds"]=8,["ingredients"]={{["type"]="item",["name"]="tech-priests-martian-comms-1",["amount"]=1},{["type"]="item",["name"]="tech-priests-martian-power-2",["amount"]=1},{["type"]="item",["name"]="advanced-circuit",["amount"]=8},{["type"]="item",["name"]="steel-plate",["amount"]=8}}},["comms-3"]={["health"]=1200,["technology"]="processing-unit",["seconds"]=12,["ingredients"]={{["type"]="item",["name"]="tech-priests-martian-comms-2",["amount"]=1},{["type"]="item",["name"]="tech-priests-martian-power-3",["amount"]=1},{["type"]="item",["name"]="processing-unit",["amount"]=8},{["type"]="item",["name"]="advanced-circuit",["amount"]=16}}}}
local reaches={9,18,30}
local areas={2.5,4.5,6.5}
local energy={75,150,300}
data:extend{{type='item-subgroup',name='tech-priest-martian-infrastructure',group='tech-priests',order='d-b[infrastructure]'}}
for _,m in ipairs(models) do
  local entry=tuning[m.family..'-'..m.tier]
  local pole=table.deepcopy(data.raw['electric-pole']['medium-electric-pole'])
  pole.name=m.name;pole.icon="__tech-priests__/graphics/entity/martian-infrastructure/"..m.family..'-'..m.tier..'-icon.png';pole.icon_size=64
  pole.minable={mining_time=.2,result=m.name};pole.max_health=entry.health
  pole.collision_box={{-m.tier/2+.08,-m.tier/2+.08},{m.tier/2-.08,m.tier/2-.08}}
  pole.selection_box={{-m.tier/2,-m.tier/2},{m.tier/2,m.tier/2}}
  pole.tile_width=m.tier;pole.tile_height=m.tier
  pole.maximum_wire_distance=reaches[m.tier];pole.supply_area_distance=areas[m.tier]
  pole.fast_replaceable_group=nil;pole.next_upgrade=nil;pole.water_reflection=nil
  pole.drawing_box_vertical_extension=m.height
  pole.pictures={layers={{filename="__tech-priests__/graphics/entity/martian-infrastructure/"..m.family..'-'..m.tier..'.png',width=m.pixels,height=m.pixels,direction_count=1,scale=m.body_scale,shift=m.shift},{filename="__tech-priests__/graphics/entity/martian-infrastructure/"..m.family..'-'..m.tier..'-shadow.png',width=m.shadow_pixels,height=m.shadow_pixels,direction_count=1,scale=.5,shift={0,0},draw_as_shadow=true}}}
  pole.connection_points={{wire=m.wires,shadow=m.shadow}}
  pole.radius_visualisation_picture=table.deepcopy(data.raw['electric-pole']['medium-electric-pole'].radius_visualisation_picture)
  pole.localised_name={'entity-name.'..m.name}
  pole.localised_description={'entity-description.'..m.name}
  local item={type='item',name=m.name,icon=pole.icon,icon_size=64,localised_name={'entity-name.'..m.name},subgroup='tech-priest-martian-infrastructure',order='z[martian]-'..m.family..m.tier,place_result=m.name,stack_size=50}
  local recipe={type='recipe',name=m.name,localised_name={'entity-name.'..m.name},enabled=false,energy_required=entry.seconds,ingredients=entry.ingredients,results={{type='item',name=m.name,amount=1}}}
  data:extend{pole,item,recipe}
  local tech=assert(data.raw.technology[entry.technology],entry.technology)
  tech.effects[#tech.effects+1]={type='unlock-recipe',recipe=m.name}
  if m.family=='comms' then
    local radar=table.deepcopy(data.raw.radar.radar)
    radar.name=m.name..'-vision';radar.minable=nil;radar.fast_replaceable_group=nil;radar.next_upgrade=nil
    radar.hidden=true;radar.hidden_in_factoriopedia=true;radar.selectable_in_game=false
    radar.flags={'placeable-off-grid','not-on-map','not-blueprintable','not-deconstructable','not-flammable','not-in-kill-statistics'}
    radar.collision_mask={layers={}};radar.collision_box={{0,0},{0,0}};radar.selection_box={{0,0},{0,0}}
    radar.pictures={filename='__core__/graphics/empty.png',width=1,height=1,direction_count=1}
    if m.rotating then
      radar.pictures={layers={{filename="__tech-priests__/graphics/entity/martian-infrastructure/"..m.family..'-'..m.tier..'-dish-beauty.png',width=m.pixels,height=m.pixels,direction_count=64,line_length=8,apply_projection=false,scale=m.body_scale,shift=m.shift},{filename="__tech-priests__/graphics/entity/martian-infrastructure/"..m.family..'-'..m.tier..'-dish-shadow.png',width=m.shadow_pixels,height=m.shadow_pixels,direction_count=64,line_length=8,apply_projection=false,scale=.5,shift={0,0},draw_as_shadow=true}}}
    end
    radar.integration_patch=nil;radar.water_reflection=nil;radar.working_sound=nil;radar.corpse=nil;radar.dying_explosion=nil
    radar.circuit_connector=nil;radar.circuit_wire_max_distance=0;radar.connects_to_other_radars=false
    radar.draw_copper_wires=false;radar.draw_circuit_wires=false
    radar.energy_usage=energy[m.tier]..'kW';radar.energy_per_nearby_scan=(energy[m.tier]*2)..'kJ'
    radar.energy_per_sector='10GJ';radar.max_distance_of_sector_revealed=m.tier;radar.max_distance_of_nearby_sector_revealed=m.tier
    radar.rotation_speed=m.rotating and 1/600 or 0;radar.radius_minimap_visualisation_color={r=0,g=0,b=0,a=0}
    data:extend{radar}
  end
end
