-- Executable review prototype, independent of ordinary mod/economy decisions.
local NAME='tp-mh7-review-electrolyzer'
local ROOT='__tp-mh7-electrolyzer-review__/graphics/'
local machine=table.deepcopy(data.raw['assembling-machine']['chemical-plant'])
machine.name=NAME;machine.localised_name='Electrolyzer / isolated model review'
machine.flags={'placeable-neutral','player-creation'}
machine.minable={mining_time=.1,result=NAME};machine.next_upgrade=nil
machine.collision_box={{-1.3,-1.8},{1.3,1.8}}
machine.selection_box={{-1.5,-2},{1.5,2}}
machine.crafting_categories={'tp-mh7-review-electrolysis'}
machine.crafting_speed=1;machine.module_slots=0;machine.allowed_effects={}
machine.energy_source={type='void'};machine.energy_usage='1W'
machine.fluid_boxes={
 {production_type='input',filter='tp-mh7-review-purified-water',volume=100,
  pipe_covers=pipecoverspictures(),pipe_connections={{flow_direction='input',direction=defines.direction.south,position={0,1.5}}}},
 {production_type='output',filter='tp-mh7-review-hydrogen-gas',volume=100,
  pipe_covers=pipecoverspictures(),pipe_connections={{flow_direction='output',direction=defines.direction.west,position={-1,-.5}}}},
 {production_type='output',filter='tp-mh7-review-oxygen-gas',volume=100,
  pipe_covers=pipecoverspictures(),pipe_connections={{flow_direction='output',direction=defines.direction.east,position={1,-.5}}}},
}
machine.fluid_boxes_off_when_no_fluid_recipe=false
local function view(state)
 local rows={}
 for _,direction in ipairs{'north','east','south','west'} do
  rows[direction]={filename=ROOT..state..'-'..direction..'.png',width=256,height=256,
   frame_count=8,line_length=4,animation_speed=8/(60*4),scale=.79375,
   shift={0,-1.3*math.sqrt(.5)+4/32},allow_reducing_frames=false}
 end
 return rows
end
-- Use the pipe/object depth layer rather than putting the complete machine
-- above every neighbouring pipe. Named states retain the genuine idle art.
local idle,working=view('idle'),view('working')
local function state_picture(name,pictures)
 return {name=name,always_draw=true,draw_in_states={name},draw_when_state_filter_matches=true,
  render_layer='lower-object',north_animation=pictures.north,east_animation=pictures.east,
  south_animation=pictures.south,west_animation=pictures.west}
end
machine.graphics_set={
 states={{name='idle',duration=1,next_active='working',next_inactive='idle'},
         {name='working',duration=1,next_active='working',next_inactive='idle'}},
 working_visualisations={state_picture('idle',idle),state_picture('working',working)},
}
machine.graphics_set_flipped=nil;machine.working_visualisations=nil
machine.working_sound=nil;machine.water_reflection=nil
local item=table.deepcopy(data.raw.item['chemical-plant']);item.name=NAME;item.place_result=NAME
local fluids={}
for _,row in ipairs{
 {'tp-mh7-review-purified-water',{.1,.5,.7}},
 {'tp-mh7-review-hydrogen-gas',{.4,.7,.8}},
 {'tp-mh7-review-oxygen-gas',{.6,.7,.9}},
} do
 local f=table.deepcopy(data.raw.fluid.water);f.name=row[1]
 f.localised_name=row[1]..' / fixture only';f.base_color=row[2];f.flow_color=row[2]
 fluids[#fluids+1]=f
end
data:extend(fluids)
data:extend{machine,item,{type='recipe-category',name='tp-mh7-review-electrolysis'},
 {type='recipe',name='tp-mh7-review-electrolyze',categories={'tp-mh7-review-electrolysis'},enabled=true,
  main_product='tp-mh7-review-hydrogen-gas',
  energy_required=4,ingredients={{type='fluid',name='tp-mh7-review-purified-water',amount=10}},
  results={{type='fluid',name='tp-mh7-review-hydrogen-gas',amount=20},
           {type='fluid',name='tp-mh7-review-oxygen-gas',amount=10}}}}
