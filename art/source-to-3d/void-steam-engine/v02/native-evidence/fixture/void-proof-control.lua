-- Isolated operational proof: actual current generator, finite steam, normal pipes.
-- Each direction has its OWN real platform/grid. No generator/accumulator energy assignments.
local loaded=false
script.on_load(function()loaded=true end)
local function check(x,m)if not x then error('VOID_PROOF: '..m)end end
local function status(e)for n,v in pairs(defines.entity_status)do if e.status==v then return n end end end
local function same(a,b)
 if type(a)~=type(b)then return false end
 if type(a)=='number'then return math.abs(a-b)<.01 end
 if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function ground(s,p,tile)
 s.request_to_generate_chunks(p,1);s.force_generate_chunk_requests();local tiles={}
 for x=-12,12 do for y=-12,12 do tiles[#tiles+1]={name=tile,position={p.x+x,p.y+y}}end end;s.set_tiles(tiles,true)
end
local function steam(u)local total=u.machine.get_fluid_count('steam');for _,p in ipairs(u.pipes)do total=total+p.get_fluid_count('steam')end;return total end
local function snapshot(u)
 local pipes={};for _,p in ipairs(u.pipes)do pipes[#pipes+1]=p.get_fluid(1)or false end
 return {direction=u.machine.direction,position=u.machine.position,disabled=u.machine.disabled_by_script,fluid=u.machine.get_fluid(1)or false,pipes=pipes,energy=u.machine.energy,accumulator_joules=u.accumulator.energy,radar_disabled=u.radar and u.radar.disabled_by_script or false}
end
local function feed(u,temperature,amount)
 u.pipes[#u.pipes].set_fluid_segment_fluid(1,{name='steam',amount=amount or 1000,temperature=temperature});check(steam(u)>299,'steam placed only in ordinary input network')
end
local function record(label)
 local r={tick=game.tick,label=label,units={}}
 for _,u in ipairs(storage.units)do r.units[#r.units+1]={direction=u.machine.direction,surface=u.surface.index,network=u.machine.electric_network_id,status=status(u.machine),steam=steam(u),snapshot=snapshot(u)}end
 storage.samples[#storage.samples+1]=r;helpers.write_file('void-v1/samples.json',helpers.table_to_json(storage.samples),false)
end
script.on_init(function()
 if remote.interfaces.freeplay and remote.interfaces.freeplay.set_skip_intro then remote.call('freeplay','set_skip_intro',true)end
 local p=prototypes.entity['void-steam-engine'];check(p.type=='generator'and p.tile_width==2 and p.tile_height==2,'actual compact generator')
 check(p.get_max_energy_production()*60==300000 and p.maximum_temperature==165 and p.get_fluid_usage_per_tick()==.5 and not p.scale_fluid_usage and not p.burner_prototype,'preserved actual steam power contract')
 check(p.get_max_circuit_wire_distance()==0 and p.get_max_wire_distance()==0,'no invented connector')
 storage.units={};storage.samples={};local force=game.forces.player
 check(not force.recipes[p.name].enabled,'actual locked recipe');force.technologies['hydrogen-thruster-propulsion'].researched=true;check(force.recipes[p.name].enabled,'actual technology unlock')
 for _,d in ipairs({0,4})do
  local platform=force.create_space_platform{name='Void independent native direction '..d,planet='nauvis',starter_pack='space-platform-starter-pack'};platform.apply_starter_pack(true);local s=platform.surface;local pos={x=18,y=20};ground(s,pos,'space-platform-foundation');s.daytime=0;s.freeze_daytime=true
  check(s.can_place_entity{name=p.name,position=pos,direction=d,force='player'},'ordinary platform placement');local e=s.create_entity{name=p.name,position=pos,direction=d,force='player'};check(e.direction==d,'real native facing')
  local u={machine=e,surface=s,pipes={}};local port=e.get_fluid_box_pipe_connections(1)[1];check(port and port.flow_direction=='input','only actual steam inlet');local target=port.target_position
  check(math.abs(target.x-math.floor(target.x)-.5)<1e-6 and math.abs(target.y-math.floor(target.y)-.5)<1e-6,'player grid pipe target')
  local step=d==0 and {x=-1,y=0}or{x=0,y=-1}
  for k=0,7 do local pt={x=target.x+k*step.x,y=target.y+k*step.y};check(s.can_place_entity{name='pipe',position=pt,force='player'},'normal pipe placeability');u.pipes[#u.pipes+1]=s.create_entity{name='pipe',position=pt,force='player'}end
  check(e.get_fluid_box_pipe_connections(1)[1].target==u.pipes[1],'ordinary direct pipe attachment')
  u.accumulator=s.create_entity{name='accumulator',position={pos.x+3,pos.y+3},force='player'};u.pole=s.create_entity{name='medium-electric-pole',position={pos.x+1.5,pos.y+2.5},force='player'}
  check(u.accumulator and u.pole and u.accumulator.energy==0,'fresh native empty load');storage.units[#storage.units+1]=u
 end
 check(storage.units[1].surface.index~=storage.units[2].surface.index,'independent platform surfaces')
 -- A third surface powers only the real building assembler, never either generator grid.
 local s=game.surfaces[1];local pos={x=24.5,y=24.5};ground(s,pos,'grass-1')
 for _,e in pairs(s.find_entities_filtered{area={{12,12},{38,38}}})do if e.type~='character'then e.destroy()end end
 storage.builder=s.create_entity{name='assembling-machine-1',position=pos,force='player'};check(storage.builder.set_recipe(p.name),'actual recipe accepted')
 for _,v in ipairs(prototypes.recipe[p.name].ingredients)do check(v.type=='item','real item ingredient');check(storage.builder.get_inventory(defines.inventory.crafter_input).insert{name=v.name,count=v.amount}==v.amount,'actual recipe ingredient '..v.name)end
 check(s.create_entity{name='void-proof-power',position={29,27},force='player'},'builder-only fixture power');check(s.create_entity{name='medium-electric-pole',position={27.5,27.5},force='player'},'normal builder supply')
 log('VOID_V1_NATIVE_FIXTURE_READY independent_platforms=2 directions=2');record('initial-cold')
end)
script.on_event(defines.events.on_tick,function(ev)
 if loaded then
  loaded=false
  if storage.complete then
   check(storage.frozen and storage.saved,'actual operated save')
   for i,u in ipairs(storage.units)do check(same(snapshot(u),storage.saved[i]),'operated snapshot reload '..i);check(u.machine.get_fluid_box_pipe_connections(1)[1].target==u.pipes[1],'normal pipe reload')end
   check(storage.placed.valid and game.forces.player.recipes['void-steam-engine'].enabled,'crafted placement and unlock reload')
   helpers.write_file('void-v1/reload.json',helpers.table_to_json{passed=true,actual_operated_save=true,independent_platforms=2,machines=2,directions=2,fluids_energy_pipes_disabled_accumulators_and_crafted_placement_preserved=true},false);log('VOID_V1_OPERATED_RELOAD_PASS')
  end
 end
 if storage.complete then
  if not storage.saved and ev.tick>=4260 then storage.saved={};for _,u in ipairs(storage.units)do storage.saved[#storage.saved+1]=snapshot(u)end;game.auto_save('void-v1-operated');log('VOID_V1_OPERATED_SAVE_REQUESTED')end
  return
 end
 local t=ev.tick
 if t==120 then
  for _,u in ipairs(storage.units)do check(steam(u)==0 and u.accumulator.energy==0,'cold empty engine produces no power');feed(u,165);u.initial_steam=steam(u)end;record('finite-steam-supplied')
 elseif t==600 then
  for _,u in ipairs(storage.units)do check(u.accumulator.energy>2300000 and u.accumulator.energy<2500000 and steam(u)<800,'real finite steam charged empty native accumulator');check(u.machine.electric_network_id==u.accumulator.electric_network_id,'real electrical grid');u.machine.disabled_by_script=true end;record('script-stop')
 elseif t==660 then for _,u in ipairs(storage.units)do u.stopped=snapshot(u)end;record('stopped-settled')
 elseif t==840 then for _,u in ipairs(storage.units)do check(same(snapshot(u),u.stopped),'script stop holds actual fluids and energy');u.machine.disabled_by_script=false end;record('script-restart')
 elseif t==1200 then for _,u in ipairs(storage.units)do check(u.accumulator.energy>u.stopped.accumulator_joules+1700000,'restart supplies real power')end;record('restarted-working')
 elseif t==1500 then record('full-output-observation');for _,u in ipairs(storage.units)do check(u.accumulator.energy>4999000 and math.abs(steam(u)-(u.initial_steam-(u.accumulator.energy+u.machine.energy)/10000))<.01,'natural full electrical output including native generator buffer');u.full=snapshot(u)end;record('full-load-capacity')
 elseif t==1800 then
  for _,u in ipairs(storage.units)do check(same(snapshot(u),u.full),'naturally full output holds steam and energy');u.blocked_steam=steam(u);u.radar=u.surface.create_entity{name='radar',position={21.5,18.5},force='player'};check(u.radar,'real new electrical demand');check(u.radar.electric_network_id==u.machine.electric_network_id,'demand joins actual isolated platform grid')end;record('real-load-release')
 elseif t==2100 then for _,u in ipairs(storage.units)do check(steam(u)<u.blocked_steam-100,'actual demand restarts steam consumption')end;record('new-demand-working')
 elseif t==3000 then for _,u in ipairs(storage.units)do check(steam(u)<.01,'finite steam naturally exhausted');u.starved=snapshot(u)end;record('steam-starved')
 elseif t==3120 then for _,u in ipairs(storage.units)do check(steam(u)<.01 and u.accumulator.energy<u.starved.accumulator_joules-500000,'real load drains stored power while steam-starved');feed(u,165,300);u.resupplied=steam(u)end;record('steam-resupplied')
 elseif t==3600 then for _,u in ipairs(storage.units)do check(steam(u)<u.resupplied-200,'hot resupply resumes real generation');feed(u,15);u.cold_amount=steam(u)end;record('below-minimum-temperature')
 elseif t==3660 then for _,u in ipairs(storage.units)do u.cold=snapshot(u);u.cold_amount=steam(u)end;record('cold-steam-settled')
 elseif t==3900 then for _,u in ipairs(storage.units)do
  check(math.abs(steam(u)-u.cold_amount)<.01,'cold steam cannot generate');check(u.accumulator.energy<u.cold.accumulator_joules-1000000,'native load draws battery while cold')
  -- An input-only cold buffer cannot flush itself. Exercise the normal manual
  -- fluid-removal operation, then resupply hot steam through ordinary pipes.
  local amount=u.machine.get_fluid_count('steam');local removed=u.machine.remove_fluid(1,amount);check(removed and math.abs(removed.amount-amount)<.01,'manual cold-buffer fluid flush');u.manual_cold_buffer_removed=removed.amount
  feed(u,165,300);u.hot_restart_steam=steam(u)
 end;record('cold-buffer-manually-flushed-hot-steam-restored')
 elseif t==4200 then
  for _,u in ipairs(storage.units)do check(steam(u)<u.hot_restart_steam-100,'restored hot steam generates again')end
  local out=storage.builder.get_output_inventory();check(out.get_item_count('void-steam-engine')==1 and storage.builder.get_inventory(defines.inventory.crafter_input).is_empty(),'real recipe crafted from exact actual ingredients')
  local s=storage.units[1].surface;local pos={x=36,y=20};ground(s,pos,'space-platform-foundation');check(s.can_place_entity{name='void-steam-engine',position=pos,direction=4,force='player'},'crafted item ordinary platform placement');storage.placed=s.create_entity{name=prototypes.item['void-steam-engine'].place_result.name,position=pos,direction=4,force='player'};check(storage.placed and out.remove{name='void-steam-engine',count=1}==1,'actual crafted item consumed by scripted placement');storage.placed.disabled_by_script=true
  record('final-hot-working');for _,u in ipairs(storage.units)do u.machine.disabled_by_script=true;u.radar.disabled_by_script=true end;storage.builder.disabled_by_script=true;storage.frozen=true;storage.complete=true
  helpers.write_file('void-v1/native-runtime.json',helpers.table_to_json{passed=true,independent_actual_platforms=2,real_orientations={0,4},ordinary_direct_pipe_joints=2,ordinary_pipe_entities=16,normal_player_grid_placement=true,cold_empty_idle=true,finite_steam_real_accumulator_charge=true,no_energy_assignments=true,script_stop_hold_restart=true,natural_full_electrical_output_stops_steam=true,real_new_load_restarts_generation=true,natural_starvation_resupply=true,minimum_temperature_rejection_and_manual_cold_buffer_flush_hot_recovery=true,actual_technology_unlock_and_native_crafting=true,scripted_consumed_actual_crafted_item_placement=true,target_gameplay_overrides=false,operated_save_and_reload_pending=true},false);log('VOID_V1_NATIVE_PASS independent_platforms=2 directions=2')
 end
end)
remote.add_interface('void_proof',{layout=function()local r={units={}};for _,u in ipairs(storage.units)do r.units[#r.units+1]={surface=u.surface.index,position=u.machine.position,direction=u.machine.direction}end;return r end})
