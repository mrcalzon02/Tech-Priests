local spec=require('spec')
local function check(ok,message) if not ok then error(spec.mod_id..' FAIL '..message,0) end end
local function write(name,value) helpers.write_file(spec.mod_id..'/'..name..'.json',helpers.table_to_json(value),false) end
local function rotate(v,r)
 local x,y=v[1],v[2];for _=1,r do x,y=-y,x end;return {x=x,y=y}
end
local directions={defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west}
local labels={'north','east','south','west'}
local masks=2^#spec.ports
script.on_event(defines.events.on_player_joined_game,function(event)
 game.tick_paused=false;game.speed=1
 local player=game.get_player(event.player_index)
 if player then player.set_controller{type=defines.controllers.god};player.teleport({30,14.5},game.surfaces[1]);player.zoom=2 end
 log(spec.mod_id..' REAL_PLAYER_JOINED tick='..game.tick..' paused='..tostring(game.tick_paused))
end)
script.on_init(function()
 local s=game.surfaces[1];s.peaceful_mode=true;s.always_day=true
 s.request_to_generate_chunks({16,21},4);s.force_generate_chunk_requests()
 for _,e in pairs(s.find_entities_filtered{area={{-8,-8},{42,52}}}) do if e.valid then e.destroy() end end
 local tiles={};for x=-8,42 do for y=-8,52 do tiles[#tiles+1]={name='concrete',position={x,y}} end end;s.set_tiles(tiles,true)
 storage.machine_review={sites={},complete=false,shots={}};local rows={}
 for r=0,3 do for mask=0,masks-1 do
  local center={x=mask*10+(r%2==0 and .5 or 0),y=r*14+(r%2==1 and .5 or 0)}
  local m=assert(s.create_entity{name=spec.entity,position=center,direction=directions[r+1],force=game.forces.player});m.set_recipe(spec.recipe)
  check(m.direction==directions[r+1] and m.get_recipe().name==spec.recipe,'native direction/recipe')
  local site={machine=m,pipes={},mask=mask,direction=labels[r+1],observed={}};local row={mask=mask,direction=site.direction,center=m.position,ports={}}
  for index,port in ipairs(spec.ports) do
   local delta=rotate(port.target,r);local desired={x=m.position.x+delta.x,y=m.position.y+delta.y};local links=m.get_fluid_box_pipe_connections(index)
   check(#links==1 and links[1].target_position,'one socket per box')
   check(math.abs(links[1].target_position.x-desired.x)<.00001 and math.abs(links[1].target_position.y-desired.y)<.00001,'rotated native target '..port.id)
   local connected=bit32.band(mask,2^(index-1))~=0
   if connected then
    local pipe=assert(s.create_entity{name='pipe',position=desired,force=game.forces.player});site.pipes[index]=pipe
    check(m.get_fluid_box_pipe_connections(index)[1].target==pipe,'actual connected pipe')
    local found=false;for _,record in pairs(m.get_fluid_box_neighbours(index) or {}) do if record.entity==pipe then found=true end end
    check(found,'actual fluidbox neighbor')
   end
   row.ports[index]={id=port.id,fluid=port.fluid,connected=connected,target=desired,native_fluidbox_index=index,
    flow_direction=links[1].flow_direction,effective_plane_relative=rotate(port.plane,r),graphical_seating_verified=false}
  end
  storage.machine_review.sites[#storage.machine_review.sites+1]=site;rows[#rows+1]=row
 end end
 write('physical-ports',{passed=true,sites=rows,orientations=4,connection_masks=masks,entity=spec.entity,
  scope='Actual isolated prototype connection cases; no graphical or ordinary economy acceptance inferred'})
 log(spec.mod_id..' PHYSICAL_PORTS_PASS sites='..#rows)
end)
script.on_event(defines.events.on_tick,function(event)
 local state=storage.machine_review;if not state then return end
 if event.tick==1 then
  local s=game.surfaces[1]
  for _,e in pairs(s.find_entities_filtered{area={{-8,-8},{42,52}}}) do
   if e.valid and e.name~=spec.entity and e.name~='pipe' and e.type~='character' then e.destroy() end
  end
  s.destroy_decoratives{area={{-8,-8},{42,52}}}
  for _,player in pairs(game.players) do
   local character=player.character;player.set_controller{type=defines.controllers.god};if character and character.valid then character.destroy() end
   player.teleport({-6,-6},s)
  end
 end
 if event.tick%30==0 and not state.complete then
  for _,site in ipairs(state.sites) do if site.mask==masks-1 then
   for index,port in ipairs(spec.ports) do
    if port.production_type=='input' then site.pipes[index].set_fluid(1,{name=port.fluid,amount=100})
    else
     for fluid,amount in pairs(site.pipes[index].get_fluid_contents()) do
      check(fluid==port.fluid,'unexpected output fluid');site.observed[index]=(site.observed[index] or 0)+amount
     end
     site.pipes[index].remove_fluid(1,1000000)
    end
   end
  end end
 end
 local cycle_ticks=spec.cycle_seconds*60
 if event.tick>=120 and event.tick<=120+cycle_ticks and (event.tick-120)%(cycle_ticks/8)==0 then
  local frame=math.floor((event.tick-120)/(cycle_ticks/8))
  for _,site in ipairs(state.sites) do if site.mask==masks-1 or (site.mask==0 and (frame==0 or frame==8)) then
   local path=spec.mod_id..'/'..site.direction..'-'..(site.mask==0 and (frame==0 and 'idle' or 'idle-end') or 'working-'..frame)..'.png'
   game.take_screenshot{player=game.players[1],surface=site.machine.surface,position=site.machine.position,
    resolution={800,800},zoom=3,daytime=0,show_gui=false,force_render=true,path=path}
   state.shots[#state.shots+1]={path=path,tick=event.tick,direction=site.direction,mask=site.mask,
    crafting=site.machine.is_crafting(),crafting_progress=site.machine.crafting_progress,
    status=site.machine.status,products_finished=site.machine.products_finished}
  end end
 end
 if event.tick>=math.max(600,120+cycle_ticks) and not state.complete then
  local flows={}
  for _,site in ipairs(state.sites) do if site.mask==masks-1 then
   check(site.machine.products_finished>0,'no finished compression recipe')
   for index,port in ipairs(spec.ports) do if port.production_type=='output' then check((site.observed[index] or 0)>0,'no actual delivered output '..port.id) end end
   flows[#flows+1]={direction=site.direction,products_finished=site.machine.products_finished,actual_output_seen=site.observed}
  end end
  write('flow',{passed=true,orientations=flows,tick=event.tick,source_cycle_seconds=spec.cycle_seconds,animation_speed=8/(60*spec.cycle_seconds),production_balancing=false})
  write('screenshots',{requested=state.shots,decoded=false,native_animation_clock_verified=false,graphical_seating_verified=false})
  state.complete=true;log(spec.mod_id..' REAL_FLUID_FLOW_PASS orientations=4')
 end
end)
