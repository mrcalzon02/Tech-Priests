-- Spec-driven isolated native art fixture. No ordinary mod/economy edits.
local spec=require('spec')
local machine=table.deepcopy(data.raw['assembling-machine']['chemical-plant'])
machine.name=spec.entity;machine.localised_name=spec.title
machine.flags={'placeable-neutral','player-creation'};machine.minable={mining_time=.1,result=spec.entity};machine.next_upgrade=nil
machine.collision_box=spec.collision_box;machine.selection_box=spec.selection_box
machine.crafting_categories={spec.category};machine.crafting_speed=1;machine.module_slots=0;machine.allowed_effects={}
machine.energy_source={type='void'};machine.energy_usage='1W';machine.fluid_boxes={}
for _,port in ipairs(spec.ports) do
 machine.fluid_boxes[#machine.fluid_boxes+1]={production_type=port.production_type,filter=port.fluid,volume=100,
  pipe_covers=pipecoverspictures(),pipe_connections={{flow_direction=port.production_type,
    direction=defines.direction[port.direction],position=port.position}}}
end
machine.fluid_boxes_off_when_no_fluid_recipe=false
local function visual(state)
 local result={name=state,always_draw=true,draw_in_states={state},draw_when_state_filter_matches=true,render_layer=spec.body_render_layer or 'lower-object',
  secondary_draw_order=state=='working' and 1 or 0,constant_speed=state=='working'}
 for _,direction in ipairs{'north','east','south','west'} do
  result[direction..'_animation']={filename='__'..spec.mod_id..'__/graphics/'..state..'-'..direction..'.png',
   width=256,height=256,frame_count=8,line_length=4,animation_speed=8/(60*spec.cycle_seconds),scale=spec.sprite_scale,
   shift={0,spec.sprite_shift_y},allow_reducing_frames=false}
 end
 return result
end
machine.graphics_set={animation_progress=8/(60*spec.cycle_seconds),states={{name='idle',duration=1,next_active='working',next_inactive='idle'},
 {name='working',duration=8,next_active='working',next_inactive='idle'}},working_visualisations={visual('idle'),visual('working')}}
if spec.primary_animation_clock then
 -- State-filtered secondary layers need a primary animated clock. The clock
 -- pixels are transparent; all visible geometry remains the real source art.
 machine.graphics_set.animation={}
 for _,direction in ipairs{'north','east','south','west'} do
  machine.graphics_set.animation[direction]={filename='__'..spec.mod_id..'__/graphics/animation-clock.png',width=1,height=1,
   frame_count=8,line_length=1,animation_speed=8/(60*spec.cycle_seconds),allow_reducing_frames=false}
 end
end
if spec.rear_collar_layer then
 local layer={name='rear-connection-collar',always_draw=true,render_layer='object',secondary_draw_order=2,
  animation={filename='__core__/graphics/empty.png',width=1,height=1}}
 for _,direction in ipairs{'east','west'} do
  layer[direction..'_animation']={filename='__'..spec.mod_id..'__/graphics/rear-collar-'..direction..'.png',
   width=256,height=256,frame_count=1,scale=spec.sprite_scale,shift={0,spec.sprite_shift_y}}
 end
 machine.graphics_set.working_visualisations[#machine.graphics_set.working_visualisations+1]=layer
end
machine.graphics_set_flipped=nil;machine.working_visualisations=nil;machine.working_sound=nil;machine.water_reflection=nil
local item=table.deepcopy(data.raw.item['chemical-plant']);item.name=spec.entity;item.place_result=spec.entity
local fluids={};local known={}
for _,port in ipairs(spec.ports) do if not known[port.fluid] then
 local fluid=table.deepcopy(data.raw.fluid.water);fluid.name=port.fluid;fluid.localised_name=port.fluid..' / fixture only'
 fluid.base_color=port.color;fluid.flow_color=port.color;fluids[#fluids+1]=fluid;known[port.fluid]=true
end end
data:extend(fluids)
local recipe={type='recipe',name=spec.recipe,categories={spec.category},enabled=true,energy_required=spec.recipe_seconds or 4,ingredients={},results={}}
for _,port in ipairs(spec.ports) do
 local product={type='fluid',name=port.fluid,amount=20}
 if port.production_type=='input' then recipe.ingredients[#recipe.ingredients+1]=product
 else recipe.results[#recipe.results+1]=product;recipe.main_product=port.fluid end
end
if spec.item_product then
 recipe.results[#recipe.results+1]={type='item',name=spec.item_product,amount=1,
  quality_min=spec.fixture_product_quality,quality_max=spec.fixture_product_quality}
 recipe.main_product=spec.item_product
 recipe.preserve_products_in_machine_output=false
end
data:extend{machine,item,{type='recipe-category',name=spec.category},recipe}
if spec.item_product then
 local picker=table.deepcopy(data.raw.inserter.inserter)
 picker.name='tp-mh7-review-pellet-picker';picker.localised_name='Isolated pellet pickup fixture'
 picker.minable=nil;picker.next_upgrade=nil;picker.energy_source={type='void'}
 data:extend{picker}
end
