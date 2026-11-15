-- Isolated art/pipe jig only. Never required by ordinary Tech-Priests data.lua.
local NAME='tp-mh7-review-purifier'
local ROOT='__tp-mh7-purifier-review__/graphics/'
local machine=table.deepcopy(data.raw['assembling-machine']['chemical-plant'])
machine.name=NAME
machine.localised_name='Purifier model / pipe review fixture'
machine.flags={'placeable-neutral','player-creation','not-rotatable'}
machine.minable={mining_time=.1,result=NAME}
machine.next_upgrade=nil
machine.collision_box={{-1.3,-1.3},{1.3,1.3}}
machine.selection_box={{-1.5,-1.5},{1.5,1.5}}
machine.crafting_categories={'tp-mh7-review-purifying'}
machine.crafting_speed=1
machine.module_slots=0
machine.allowed_effects={}
machine.energy_source={type='void'}
machine.energy_usage='1W'
machine.fluid_boxes={
  {production_type='input',volume=100,pipe_connections={
    {flow_direction='input',direction=defines.direction.west,position={-1,0}}}},
  {production_type='output',volume=100,pipe_connections={
    {flow_direction='output',direction=defines.direction.east,position={1,0}}}},
}
machine.fluid_boxes_off_when_no_fluid_recipe=false
local function view(state)
  return {north={filename=ROOT..state..'.png',width=256,height=256,
    frame_count=8,line_length=4,animation_speed=8/(60*4),run_mode='forward',
    scale=.725,shift={0,-1.1667261889578},allow_reducing_frames=false}}
end
machine.graphics_set={animation=view('working'),idle_animation=view('idle'),
  always_draw_idle_animation=false}
machine.graphics_set_flipped=nil
machine.working_visualisations=nil
machine.working_sound=nil
machine.water_reflection=nil
local item=table.deepcopy(data.raw.item['chemical-plant'])
item.name=NAME; item.place_result=NAME
local water=table.deepcopy(data.raw.fluid.water)
water.name='tp-mh7-review-purified-water'
water.localised_name='Purified water / review fixture only'
water.base_color={.1,.5,.7};water.flow_color={.2,.8,1.}
data:extend{machine,item,water,
  {type='recipe-category',name='tp-mh7-review-purifying'},
  {type='recipe',name='tp-mh7-review-purify',categories={'tp-mh7-review-purifying'},
    enabled=true,energy_required=4,
    ingredients={{type='fluid',name='water',amount=10}},
    results={{type='fluid',name=water.name,amount=10}}},
}
