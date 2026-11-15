-- ISOLATED FRESH-WORLD FIXTURE ONLY. Never ship as the ordinary prototype control.
local spec=require('spec')
local dirs={defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west}
local labels={'north','east','south','west'}
local function check(ok,why) if not ok then error('FABRICATOR_NATIVE_FAIL '..why,0) end end
local function write(name,value) helpers.write_file(spec.mod_id..'/'..name..'.json',helpers.table_to_json(value),false) end
local function rotate(v,r) local x,y=v[1],v[2];for _=1,r do x,y=-y,x end;return {x=x,y=y} end
local function at(center,v,r)local q=rotate(v,r);return {x=center.x+q.x,y=center.y+q.y} end
local function snapshot(stack)if not stack.valid_for_read then return {empty=true} end;return {name=stack.name,count=stack.count,quality=stack.quality.name,health=stack.health} end
script.on_event(defines.events.on_player_joined_game,function(event)
 game.tick_paused=false;game.speed=1;local p=game.get_player(event.player_index)
 if p then p.set_controller{type=defines.controllers.god};p.teleport({12,21},game.surfaces[1]);p.zoom=1 end
end)
script.on_init(function()
 local surface=game.surfaces[1];surface.peaceful_mode=true;surface.always_day=true
 surface.request_to_generate_chunks({24,22},5);surface.force_generate_chunk_requests()
 for _,e in pairs(surface.find_entities_filtered{area={{-8,-8},{62,56}}}) do e.destroy() end
 local tiles={};for x=-8,62 do for y=-8,56 do tiles[#tiles+1]={name='concrete',position={x,y}} end end;surface.set_tiles(tiles,true)
 local state={sites={},shots={},complete=false};storage.fabricator_review=state;local ports={}
 for r=0,3 do for case=0,4 do
  local quality=case==4 and 'rare' or 'normal';local center={x=case*12,y=r*14}
  local machine=assert(surface.create_entity{name=spec.entity,position=center,direction=dirs[r+1],force='player'})
  machine.set_recipe(spec.recipe,quality)
  check(machine.direction==dirs[r+1],'actual entity direction retained')
  check(machine.fluids_count==1,'exactly one forming-fluid inlet')
  local links=machine.get_fluid_box_pipe_connections(1);local target=at(center,{-2.5,-.5},r)
  check(#links==1 and links[1].target_position and math.abs(links[1].target_position.x-target.x)<1e-6 and math.abs(links[1].target_position.y-target.y)<1e-6,'rotated pipe target')
  local pipe=case>0 and assert(surface.create_entity{name='pipe',position=target,force='player'}) or nil
  if pipe then check(machine.get_fluid_box_pipe_connections(1)[1].target==pipe,'actual pipe neighbor') end
  local input=assert(surface.create_entity{name='steel-chest',position=at(center,{.5,3.5},r),force='player'})
  local output=assert(surface.create_entity{name='steel-chest',position=at(center,{3.5,.5},r),force='player'})
  local feeder=assert(surface.create_entity{name='tp-mh7-review-pellet-picker',position=at(center,{.5,2.5},r),direction=dirs[(r+2)%4+1],force='player'})
  local picker=assert(surface.create_entity{name='tp-mh7-review-pellet-picker',position=at(center,{2.5,.5},r),direction=dirs[(r+3)%4+1],force='player'})
  if case~=2 then input.insert{name='steel-plate',count=16,quality=quality} end
  local site={machine=machine,pipe=pipe,input=input,output=output,feeder=feeder,picker=picker,r=r,case=case,quality=quality,history={},label=labels[r+1]}
  state.sites[#state.sites+1]=site
  ports[#ports+1]={direction=site.label,case=case,center=machine.position,pipe_target=target,connected=pipe~=nil,quality=quality,actual_direction=machine.direction}
 end end
 write('physical-ports',{passed=true,sites=ports,orientations=4,footprint={4,4},fluid_boxes=1,scope='Actual rotated 4x4 native prototype and pipe targets; visual seating is separate.'})
end)
script.on_event(defines.events.on_tick,function(event)
 local state=storage.fabricator_review;if not state then return end
 if event.tick==1 then
  local s=game.surfaces[1];s.destroy_decoratives{area={{-8,-8},{62,56}}}
  for _,e in pairs(s.find_entities_filtered{area={{-8,-8},{62,56}}}) do
   if e.name~=spec.entity and e.name~='pipe' and e.name~='steel-chest' and e.name~='tp-mh7-review-pellet-picker' and e.type~='character' then e.destroy() end
  end
 end
 if event.tick%30==0 then
  for _,site in ipairs(state.sites) do
   if site.pipe and site.case~=3 then site.pipe.set_fluid(1,{name='water',amount=100}) end
  end
 end
 -- Half-second images over two full cycles: prove traversal and an actual wrap.
 if event.tick>=180 and event.tick<=1620 and (event.tick-180)%30==0 then
  local index=(event.tick-180)/30
  for _,site in ipairs(state.sites) do if site.case==1 or index==0 or index==48 then
   local path=spec.mod_id..'/'..site.label..'-case'..site.case..'-frame'..index..'.png'
   game.take_screenshot{player=game.players[1],surface=site.machine.surface,position=site.machine.position,resolution={900,900},zoom=3,daytime=0,show_gui=false,force_render=true,path=path}
   state.shots[#state.shots+1]={path=path,tick=event.tick,direction=site.label,case=site.case,crafting=site.machine.is_crafting(),progress=site.machine.crafting_progress,products_finished=site.machine.products_finished}
  end end
 end
 if event.tick%60==0 then
  for _,site in ipairs(state.sites) do
   site.history[#site.history+1]={tick=event.tick,crafting=site.machine.is_crafting(),products_finished=site.machine.products_finished,progress=site.machine.crafting_progress,output=site.output.get_inventory(defines.inventory.chest).get_contents()}
  end
 end
 if event.tick==3000 then
  local diagnostic={}
  for _,site in ipairs(state.sites) do diagnostic[#diagnostic+1]={direction=site.label,case=site.case,status=site.machine.status,products_finished=site.machine.products_finished,progress=site.machine.crafting_progress,
   fluids=site.machine.get_fluid_contents(),input=site.machine.get_inventory(defines.inventory.crafter_input).get_contents(),machine_output=site.machine.get_output_inventory().get_contents(),
   collected=site.output.get_inventory(defines.inventory.chest).get_contents(),source=site.input.get_inventory(defines.inventory.chest).get_contents(),
   feeder={held=snapshot(site.feeder.held_stack),pickup=site.feeder.pickup_position,drop=site.feeder.drop_position,target=site.feeder.drop_target and site.feeder.drop_target.name},
   picker={held=snapshot(site.picker.held_stack),pickup=site.picker.pickup_position,drop=site.picker.drop_position,target=site.picker.pickup_target and site.picker.pickup_target.name}} end
  write('production-diagnostic',{sites=diagnostic})
  local rows={}
  for _,site in ipairs(state.sites) do
   check(site.machine.direction==dirs[site.r+1],'orientation changed during production')
   local good=site.case==1 or site.case==4;local amount=site.output.get_item_count{name=spec.item_product,quality=site.quality}
   if good then
    check(site.machine.products_finished>=3 and amount>=3,'real shell output absent '..site.label..' case'..site.case)
    check(site.feeder.drop_target==site.machine and site.picker.pickup_target==site.machine and site.picker.drop_target==site.output,'actual inserter targets')
   else check(site.machine.products_finished==0 and amount==0,'produced without required plate/fluid/connection') end
   rows[#rows+1]={direction=site.label,case=site.case,quality=site.quality,products_finished=site.machine.products_finished,actual_collected_shells=amount,history=site.history}
  end
  write('production',{passed=true,rows=rows,actual_plate_inserter_input=true,actual_shell_inserter_output=true,normal_and_rare_quality=true,missing_ingredient_cases=true,recipe_seconds=12,recipe_balance=false})
  write('screenshots',{requested=state.shots,decoded=false,graphical_seating_verified=false,native_animation_clock_verified=false})
  state.complete=true
 end
end)
