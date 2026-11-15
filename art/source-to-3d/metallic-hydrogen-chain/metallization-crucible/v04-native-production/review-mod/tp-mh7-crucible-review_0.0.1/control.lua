local spec=require('spec')
local function check(ok,message) if not ok then error('CRUCIBLE_NATIVE_FAIL '..message,0) end end
local function write(name,value) helpers.write_file(spec.mod_id..'/'..name..'.json',helpers.table_to_json(value),false) end
local function rotate(v,r) local x,y=v[1],v[2];for _=1,r do x,y=-y,x end;return {x=x,y=y} end
local dirs={defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west}
local labels={'north','east','south','west'}
local function offset(center,v,r)local d=rotate(v,r);return {x=center.x+d.x,y=center.y+d.y} end
local function snapshot(stack)
 if not stack or not stack.valid_for_read then return {empty=true} end
 return {name=stack.name,count=stack.count,quality=stack.quality.name,health=stack.health,spoil_tick=stack.spoil_tick,tags=stack.is_item_with_tags and stack.tags or nil}
end
local function chest(surface,position)return assert(surface.create_entity{name='steel-chest',position=position,force='player'}) end
local function producer(surface,position,direction)
 local machine=assert(surface.create_entity{name=spec.entity,position=position,direction=direction,force='player'})
 machine.set_recipe(spec.recipe,'legendary')
 remote.call('tp-mh7-pellet-decay','register_producer',machine)
 return machine
end
script.on_event(defines.events.on_player_joined_game,function(event)
 game.tick_paused=false;game.speed=1;local player=game.get_player(event.player_index)
 if player then player.set_controller{type=defines.controllers.god};player.teleport({12.5,15.5},game.surfaces[1]);player.zoom=1 end
end)
script.on_init(function()
 local surface=game.surfaces[1];surface.peaceful_mode=true;surface.always_day=true
 surface.request_to_generate_chunks({20,30},4);surface.force_generate_chunk_requests()
 for _,e in pairs(surface.find_entities_filtered{area={{-8,-8},{42,72}}}) do e.destroy() end
 local tiles={};for x=-8,42 do for y=-8,72 do tiles[#tiles+1]={name='concrete',position={x,y}} end end;surface.set_tiles(tiles,true)
 local state={sites={},shots={},histories={},complete=false};storage.crucible_review=state;local rows={}
 for r=0,3 do for mask=0,1 do
  local machine=producer(surface,{x=mask*12+.5,y=r*15+.5},dirs[r+1]);local center=machine.position
  check(machine.fluids_count==1,'exactly one native fluid box')
  local links=machine.get_fluid_box_pipe_connections(1);local target=offset(center,{-3,0},r)
  check(#links==1 and links[1].target_position,'one input connection')
  check(math.abs(links[1].target_position.x-target.x)<1e-6 and math.abs(links[1].target_position.y-target.y)<1e-6,'rotated input target')
  local pipe=mask==1 and assert(surface.create_entity{name='pipe',position=target,force='player'}) or nil
  if pipe then check(machine.get_fluid_box_pipe_connections(1)[1].target==pipe,'real input pipe neighbor') end
  local probe=assert(surface.create_entity{name='pipe',position=offset(center,{3,0},r),force='player'})
  for _,connection in pairs(probe.get_fluid_box_pipe_connections(1)) do check(connection.target~=machine,'item egress incorrectly accepts a fluid pipe') end;probe.destroy()
  local pickup=assert(surface.create_entity{name='tp-mh7-review-pellet-picker',position=offset(center,{3,0},r),direction=dirs[(r+3)%4+1],force='player'})
  local output=chest(surface,offset(center,{4,0},r));local sample=chest(surface,offset(center,{4,3},r));local sealed=chest(surface,offset(center,{4,5},r))
  local site={machine=machine,pipe=pipe,pickup=pickup,output=output,sample=sample,sealed=sealed,r=r,mask=mask,label=labels[r+1],seen={},observed=0,history={}}
  state.sites[#state.sites+1]=site
  rows[#rows+1]={direction=site.label,connected=mask==1,center=center,native_input_cell=rotate({-2,0},r),effective_input_plane=rotate({-2.5,0},r),native_target=target,
   fluid_boxes=machine.fluids_count,item_egress_rejects_fluid_pipe=true,pickup_position=pickup.pickup_position,drop_position=pickup.drop_position}
 end end
 local blocked=producer(surface,{x=30.5,y=60.5},dirs[1]);local pipe=assert(surface.create_entity{name='pipe',position=offset(blocked.position,{-3,0},0),force='player'})
 state.blocked={machine=blocked,pipe=pipe,history={}}
 write('physical-ports',{passed=true,sites=rows,orientations=4,connection_masks=2,scope='Actual 5x5 one-fluid-input prototype; native pipe rejected at solid item output. Visual seating is separate.'})
end)
script.on_event(defines.events.on_tick,function(event)
 local state=storage.crucible_review;if not state then return end
 if event.tick==1 then
  local surface=game.surfaces[1];surface.destroy_decoratives{area={{-8,-8},{42,72}}}
  for _,e in pairs(surface.find_entities_filtered{area={{-8,-8},{42,72}}}) do
   if e.name~=spec.entity and e.name~='pipe' and e.name~='tp-mh7-review-pellet-picker' and e.name~='steel-chest' and e.type~='character' then e.destroy() end
  end
 end
 if event.tick%30==0 then
  for _,site in ipairs(state.sites) do if site.pipe then site.pipe.set_fluid(1,{name=spec.ports[1].fluid,amount=100}) end end
  state.blocked.pipe.set_fluid(1,{name=spec.ports[1].fluid,amount=100})
 end
 if event.tick%15==0 then
  for _,site in ipairs(state.sites) do if site.mask==1 then
   local inv=site.output.get_inventory(defines.inventory.chest)
   for i=1,#inv do if inv[i].valid_for_read and inv[i].name==spec.item_product then
    local tags=inv[i].tags or {};check(tags.mh7_decay_phase==spec.item_product,'fresh picked pellet has no initialized random timer')
    check(tags.mh7_rolled_interval>=900 and tags.mh7_rolled_interval<=1800,'wrong normal decay interval')
    if not site.seen[inv[i].item_number] then site.seen[inv[i].item_number]=true;site.observed=site.observed+1 end
    if not site.sample_created then
     local dest=site.sample.get_inventory(defines.inventory.chest)[1];local deadline=inv[i].spoil_tick
     check(dest.transfer_stack(inv[i]),'sample transfer failed');check(dest.spoil_tick==deadline,'pickup transfer refreshed timer')
     site.sample_created=true;site.initial_sample=snapshot(dest)
    elseif not site.sealed_created then
     local sealinv=site.sealed.get_inventory(defines.inventory.chest);sealinv[1].set_stack{name='tp-mh7-empty-pressure-shell',count=1,quality='rare',health=.9}
     site.before_seal=snapshot(inv[i]);check(remote.call('tp-mh7-pellet-decay','seal',inv[i],sealinv[1],sealinv[2]),'actual produced pellet containment failed')
     site.sealed_created=true
    end
   end end
  end end
 end
 local cycle_ticks=spec.cycle_seconds*60
 if event.tick>=120 and event.tick<=120+cycle_ticks and (event.tick-120)%(cycle_ticks/8)==0 then
  local frame=math.floor((event.tick-120)/(cycle_ticks/8))
  for _,site in ipairs(state.sites) do if site.mask==1 or frame==0 or frame==8 then
   local path=spec.mod_id..'/'..site.label..'-'..(site.mask==0 and (frame==0 and 'idle' or 'idle-end') or 'working-'..frame)..'.png'
   game.take_screenshot{player=game.players[1],surface=site.machine.surface,position=site.machine.position,resolution={900,900},zoom=3,daytime=0,show_gui=false,force_render=true,path=path}
   state.shots[#state.shots+1]={path=path,tick=event.tick,direction=site.label,mask=site.mask,crafting=site.machine.is_crafting(),products_finished=site.machine.products_finished,progress=site.machine.crafting_progress}
  end end
 end
 if event.tick==660 then
  local rows={}
  for _,site in ipairs(state.sites) do
   if site.mask==0 then check(site.machine.products_finished==0,'disconnected machine produced pellets')
   else
    if site.observed<2 or not site.sample_created or not site.sealed_created then
     write('production-failure',{direction=site.label,products_finished=site.machine.products_finished,status=site.machine.status,fluids=site.machine.get_fluid_contents(),output=snapshot(site.machine.get_output_inventory()[1]),
      pickup_position=site.pickup.pickup_position,drop_position=site.pickup.drop_position,pickup_target=site.pickup.pickup_target and site.pickup.pickup_target.name,drop_target=site.pickup.drop_target and site.pickup.drop_target.name,
      held=snapshot(site.pickup.held_stack),target_contents=site.output.get_inventory(defines.inventory.chest).get_contents(),observed=site.observed})
     check(false,'no actual picked/contained production '..site.label)
    end
    check(site.pickup.pickup_target==site.machine and site.pickup.drop_target==site.output,'inserter pickup/drop targets differ')
    rows[#rows+1]={direction=site.label,actual_picked_pellets=site.observed,products_finished=site.machine.products_finished,initial_sample=site.initial_sample,before_seal=site.before_seal}
   end
  end
  write('production',{passed=true,rows=rows,tick=event.tick,recipe_balancing=false,actual_item_pickup=true,actual_containment=true})
  write('screenshots',{requested=state.shots,decoded=false,graphical_seating_verified=false,native_animation_clock_verified=false})
 end
 if event.tick%60==0 then
  for _,site in ipairs(state.sites) do if site.mask==1 and site.sample_created then site.history[#site.history+1]={tick=event.tick,sample=snapshot(site.sample.get_inventory(defines.inventory.chest)[1])} end end
  state.blocked.history[#state.blocked.history+1]={tick=event.tick,item=snapshot(state.blocked.machine.get_output_inventory()[1])}
 end
 if event.tick==8400 then
  local rows={}
  for _,site in ipairs(state.sites) do if site.mask==1 then
   local raw=snapshot(site.sample.get_inventory(defines.inventory.chest)[1]);local sealed=snapshot(site.sealed.get_inventory(defines.inventory.chest)[2])
   check(raw.name=='tp-mh7-inert-pellet' and raw.health==0 and raw.quality=='normal','produced raw pellet did not decay to inert '..site.label)
   check(sealed.name=='tp-mh7-contained-metallicized-pellet' and sealed.health==site.before_seal.health and sealed.quality==site.before_seal.quality,'produced contained pellet decayed or healed')
   local lost=false;for _,row in ipairs(site.history) do if row.sample.health and row.sample.health>0 and row.sample.health<1 and row.sample.quality~=site.initial_sample.quality then lost=true end end
   check(lost,'actual produced pellet had no HP and quality loss')
   rows[#rows+1]={direction=site.label,history=site.history,inert=raw,contained=sealed}
  end end
  local blocked=snapshot(state.blocked.machine.get_output_inventory()[1]);check(blocked.name=='tp-mh7-inert-pellet' and blocked.health==0,'machine output secretly preserves uncontained pellets')
  write('decay-integration',{passed=true,rows=rows,blocked_output={item=blocked,products_finished=state.blocked.machine.products_finished,history=state.blocked.history},tick=event.tick,
    scope='Actual crucible-produced solid pellets, real inserter transport, native HP/quality decay and shell containment. Uncontained machine output also decays.'})
  state.complete=true;log('CRUCIBLE_NATIVE_PRODUCTION_AND_DECAY_PASS')
 end
end)
