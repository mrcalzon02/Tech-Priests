-- Isolated accelerated native behavior proof; normal module is decay.lua.
local M=require('decay');local c=require('config')
local function check(ok,message) if not ok then error('PELLET_DECAY_FAIL '..message,0) end end
local function snap(stack)
 if not stack or not stack.valid_for_read then return {empty=true} end
 return {name=stack.name,count=stack.count,quality=stack.quality.name,health=stack.health,spoil_tick=stack.spoil_tick,tags=stack.is_item_with_tags and stack.tags or nil}
end
local function get_chest(x,y)
 return game.surfaces[1].create_entity{name='steel-chest',position={x,y},force='player'}.get_inventory(defines.inventory.chest)
end
script.on_init(function()
 local surface=game.surfaces[1];surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
 local clear=surface.find_entities_filtered{area={{-5,-5},{20,10}}};for _,e in pairs(clear) do e.destroy() end
 local tiles={};for x=-5,20 do for y=-5,10 do tiles[#tiles+1]={name='concrete',position={x,y}} end end;surface.set_tiles(tiles,true)
 local p={histories={},initial_timers={},checks={},chests={}};storage.decay_fixture=p
 for i=1,8 do
  local inv=get_chest(i*2,0);inv[1].set_stack{name=c.stages[1].name,count=1,quality=i==8 and 'normal' or 'legendary'};M.touch_stack(inv[1]);p.chests[i]=inv;p.initial_timers[i]=inv[1].spoil_tick
 end
 p.move_target=get_chest(2,3)
 p.ground=surface.create_entity{name='item-on-ground',position={4,3},stack={name=c.stages[1].name,count=1,quality='legendary'}};M.touch_stack(p.ground.stack)
 p.belts={surface.create_entity{name='transport-belt',position={6,3},direction=defines.direction.east,force='player'},surface.create_entity{name='transport-belt',position={7,3},direction=defines.direction.east,force='player'}}
 p.belts[1].get_transport_line(1).insert_at_back{name=c.stages[1].name,count=1,quality='legendary'};M.touch_entity(p.belts[1])
 p.inserter=surface.create_entity{name='inserter',position={10,3},force='player'};p.inserter.held_stack.set_stack{name=c.stages[1].name,count=1,quality='legendary'};M.touch_entity(p.inserter)
 p.script_inv=game.create_inventory(1);p.script_inv[1].set_stack{name=c.stages[1].name,count=1,quality='legendary'};M.register_inventory(p.script_inv)
 p.character=surface.create_entity{name='character',position={14,3},force='player'};p.character.get_inventory(defines.inventory.character_main)[1].set_stack{name=c.stages[1].name,count=1,quality='legendary'};M.touch_entity(p.character)
 p.seal_inv=get_chest(12,3);p.seal_inv[1].set_stack{name=c.stages[2].name,count=1,quality='rare',health=.65};M.touch_stack(p.seal_inv[1]);p.seal_inv[2].set_stack{name=c.shell,count=1,quality='uncommon',health=.9}
end)
script.on_event(defines.events.on_script_trigger_effect,M.on_script_trigger_effect)
script.on_event(defines.events.on_player_main_inventory_changed,M.on_player_inventory_changed)
script.on_event(defines.events.on_player_cursor_stack_changed,M.on_player_inventory_changed)
script.on_event(defines.events.on_tick,function(event)
 M.on_tick(event);local p=storage.decay_fixture;if not p then return end
 if event.tick==10 then
  p.seal_before=snap(p.seal_inv[1]);p.seal_remaining=p.seal_inv[1].spoil_tick-game.tick
  check(M.seal(p.seal_inv[1],p.seal_inv[2],p.seal_inv[3]),'seal failed');check(not p.seal_inv[1].valid_for_read and not p.seal_inv[2].valid_for_read,'seal did not consume raw and shell')
 end
 if event.tick==30 then
  local before=snap(p.chests[1][1]);check(p.move_target[1].transfer_stack(p.chests[1][1]),'move failed')
  local after=snap(p.move_target[1]);check(before.spoil_tick==after.spoil_tick and before.health==after.health and before.quality==after.quality,'movement reset condition/timer');p.checks.transfer_preserved=true
 end
 if event.tick==400 then
  local sealed=snap(p.seal_inv[3]);check(sealed.name==c.contained and sealed.quality==p.seal_before.quality and math.abs(sealed.health-p.seal_before.health)<1e-6,'containment healed or degraded contents')
  check(M.unseal(p.seal_inv[3],p.seal_inv[4],p.seal_inv[5]),'unseal failed')
  local raw=snap(p.seal_inv[4]);check(raw.spoil_tick-game.tick==p.seal_remaining and raw.quality==p.seal_before.quality and math.abs(raw.health-p.seal_before.health)<1e-6,'unseal reset timer or repaired pellet')
  check(p.seal_inv[5].name==c.shell and p.seal_inv[5].quality.name=='uncommon' and math.abs(p.seal_inv[5].health-.9)<1e-6,'shell state not conserved')
  p.checks.containment_preserved=true;p.checks.unseal_remaining_preserved=true;p.unsealed_deadline=raw.spoil_tick
 end
 if event.tick%15==0 then
  local belt={empty=true};for _,e in ipairs(p.belts) do for i=1,e.get_max_transport_line_index() do local line=e.get_transport_line(i);if #line>0 then belt=snap(line[1]) end end end
  local row={tick=event.tick,chest=snap(event.tick<30 and p.chests[1][1] or p.move_target[1]),normal=snap(p.chests[8][1]),ground=snap(p.ground.stack),belt=belt,inserter=snap(p.inserter.held_stack),script_inventory=snap(p.script_inv[1]),character_inventory=snap(p.character.get_inventory(defines.inventory.character_main)[1]),contained=snap(p.seal_inv[event.tick<400 and 3 or 4])}
  p.histories[#p.histories+1]=row
 end
 if event.tick==1000 then
  local unique={};for _,t in ipairs(p.initial_timers) do check(t>=c.interval_min_ticks and t<=c.interval_max_ticks,'random timer out of range');unique[t]=true end
  check(table_size(unique)>1,'all timers identical');p.checks.random_timers_differ=true
  local last=p.histories[#p.histories]
  for _,name in ipairs{'chest','normal','ground','belt','inserter','script_inventory','character_inventory','contained'} do
   local row=last[name];check(row.name==c.inert and row.quality=='normal' and row.health==0,'terminal inert state differs '..name)
   local damaged=false;for _,sample in ipairs(p.histories) do local r=sample[name];if r.name and r.name~=c.inert and r.health>0 and r.health<1 and r.quality~='legendary' then damaged=true end end
   if name~='normal' then check(damaged,'missing actual HP+quality degradation '..name) end
  end
  p.checks.all_physical_carriers_inert=true;p.checks.health_and_quality_decreased=true
  check(not M.seal(p.move_target[1],p.seal_inv[5],p.seal_inv[6]),'inert material was revived')
  p.checks.inert_cannot_be_revived=true
  helpers.write_file('pellet-decay/readback.json',helpers.table_to_json{passed=true,checks=p.checks,initial_timers=p.initial_timers,histories=p.histories,config={min_ticks=c.interval_min_ticks,max_ticks=c.interval_max_ticks},tick=game.tick},false)
  log('PELLET_DECAY_NATIVE_PASS')
 end
end)
