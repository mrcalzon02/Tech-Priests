-- Isolated native proof. Production boiler, recipe, power, fuel and surface rules stay unchanged.
local loaded=false
script.on_load(function() loaded=true end)
local function check(v,m) if not v then error('STERLING_PROOF: '..m) end end
local function status(e) for n,v in pairs(defines.entity_status) do if e.status==v then return n end end end
local function contents(i) local r={};if i then for _,x in ipairs(i.get_contents()) do r[x.name..'/'..x.quality]=x.count end end;return r end
local function same(a,b,tolerance)
 if type(a)~=type(b) then return false end
 if type(a)=='number' then return math.abs(a-b)<=(tolerance or .01) end
 if type(a)~='table' then return a==b end
 for k,v in pairs(a) do if not same(v,b[k],tolerance) then return false end end
 for k,v in pairs(b) do if a[k]==nil then return false end end;return true
end
local function fluid(e) local d={};for box=1,e.fluids_count do d[box]=e.get_fluid(box) or false end;return d end
local function snap(u)
 local e=u.machine;local pipes={};for _,p in ipairs(u.ordinary) do pipes[#pipes+1]=fluid(p) end
 return {direction=e.direction,position=e.position,disabled=e.disabled_by_script,fuel=contents(e.get_fuel_inventory()),remaining_fuel=e.burner.remaining_burning_fuel,burning=e.burner.currently_burning and e.burner.currently_burning.name or false,energy=e.energy,fluid=fluid(e),pipes=pipes}
end
local function fuel_used(u) return u.coal_added*prototypes.item.coal.fuel_value-u.machine.get_fuel_inventory().get_item_count('coal')*prototypes.item.coal.fuel_value-u.machine.burner.remaining_burning_fuel end
local function ground(s,pos,tile)
 s.request_to_generate_chunks(pos,1);s.force_generate_chunk_requests();for _,e in pairs(s.find_entities_filtered{area={{pos.x-6,pos.y-6},{pos.x+6,pos.y+6}}}) do if e.type~='space-platform-hub' then e.destroy() end end
 local tiles={};for x=-6,6 do for y=-6,6 do tiles[#tiles+1]={name=tile,position={pos.x+x,pos.y+y}} end end;s.set_tiles(tiles,true)
end
local function supply_water(u) u.source.set_infinity_pipe_filter{name='water',percentage=1,temperature=15,mode='at-least'} end
local function open_sink(u)
 if not u.sink then local p=u.sink_position;check(storage.surface.can_place_entity{name='infinity-pipe',position=p,force='player'},'sink ordinary grid placement');u.sink=storage.surface.create_entity{name='infinity-pipe',position=p,force='player'} end
 u.sink.set_infinity_pipe_filter{name='steam',percentage=0,temperature=165,mode='at-most'}
end
local function freeze() for _,u in ipairs(storage.units) do u.machine.disabled_by_script=true end;storage.builder.disabled_by_script=true;storage.frozen=true end
local function save_snapshot()
 storage.snapshots={};for _,u in ipairs(storage.units) do storage.snapshots[#storage.snapshots+1]=snap(u) end
 storage.builder_snapshot={input=contents(storage.builder.get_inventory(defines.inventory.crafter_input)),output=contents(storage.builder.get_output_inventory()),placed=storage.placed and storage.placed.valid,unlocked=game.forces.player.recipes['sterling-steam-catalyzer'].enabled}
end
script.on_init(function()
 if remote.interfaces.freeplay and remote.interfaces.freeplay.set_skip_intro then remote.call('freeplay','set_skip_intro',true);log('STERLING_PROOF_FREEPLAY_INTRO_SKIPPED') end
 local p=prototypes.entity['sterling-steam-catalyzer'];check(p and p.type=='boiler','actual boiler');check(p.tile_width==4 and p.tile_height==2,'actual4x2');check(math.abs(p.get_max_energy_usage()*60-600000)<.01 and p.target_temperature==165,'actual600kW165C');check(p.burner_prototype.effectivity==1 and p.burner_prototype.fuel_inventory_size==1 and p.burner_prototype.fuel_categories.chemical,'actual chemical burner');check(prototypes.fluid.water.heat_capacity/prototypes.fluid.steam.heat_capacity==10,'actual10to1 thermal volume ratio')
 local force=game.forces.player;check(not force.recipes['sterling-steam-catalyzer'].enabled,'actual building recipe gated');force.technologies['hydrogen-thruster-propulsion'].researched=true;check(force.recipes['sterling-steam-catalyzer'].enabled,'actual technology unlock effect')
 local platform=force.create_space_platform{name='Sterling final actual platform proof',planet='nauvis',starter_pack='space-platform-starter-pack'};platform.apply_starter_pack(true);storage.surface=platform.surface;local s=storage.surface;s.daytime=0;s.freeze_daytime=true;storage.units={};storage.samples={}
 local states={'working','no-fuel','no-water','full-output','disabled','stop-restart'}
 for j,d in ipairs({0,4,8,12}) do for i,state in ipairs(states) do
  local pos={x=18+i*14,y=20+j*16};ground(s,pos,'space-platform-foundation');check(s.can_place_entity{name=p.name,position=pos,direction=d,force='player'},'ordinary platform placement '..d..' '..state)
  local e=s.create_entity{name=p.name,position=pos,direction=d,force='player'};check(e and e.direction==d,'actual facing');local u={machine=e,state=state,direction=d,ordinary={},coal_added=0,uid=#storage.units+1}
  for box=1,2 do local port=e.get_fluid_box_pipe_connections(box)[1];check(port,'actual pipe socket');local target=port.target_position;check(math.abs(target.x-math.floor(target.x)-.5)<1e-6 and math.abs(target.y-math.floor(target.y)-.5)<1e-6,'normal grid target')
   local dx,dy=target.x-pos.x,target.y-pos.y;local step=math.abs(dx)>math.abs(dy) and {x=dx<0 and -1 or 1,y=0} or {x=0,y=dy<0 and -1 or 1};local pp={}
   for k=0,1 do local pt={x=target.x+step.x*k,y=target.y+step.y*k};check(s.can_place_entity{name='pipe',position=pt,force='player'},'ordinary pipe placement');pp[#pp+1]=s.create_entity{name='pipe',position=pt,force='player'};u.ordinary[#u.ordinary+1]=pp[#pp] end
   check(e.get_fluid_box_pipe_connections(box)[1].target==pp[1],'ordinary pipe directly attached')
   local endpos={x=target.x+step.x*2,y=target.y+step.y*2}
   if port.flow_direction=='input' then u.input=pp[1];u.source=s.create_entity{name='infinity-pipe',position=endpos,force='player'};check(u.source,'isolated fixture water source');if state~='no-water' then supply_water(u) end
   else u.output=pp[1];u.sink_position=endpos;if state~='full-output' then open_sink(u) end end
  end
  if state~='no-fuel' then check(e.get_fuel_inventory().insert{name='coal',count=20}==20,'coal supplied');u.coal_added=20 end
  if state=='disabled' then e.disabled_by_script=true end
  if state=='working' then
   u.pole=s.create_entity{name='medium-electric-pole',position={pos.x+3.5,pos.y-3.5},force='player'};check(u.pole,'native circuit pole');e.get_or_create_control_behavior().read_fuel=true
   for _,color in ipairs({defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}) do check(e.get_wire_connector(color,true).connect_to(u.pole.get_wire_connector(color,true)),'ordinary circuit wire within native reach') end
  end
  storage.units[#storage.units+1]=u
 end end
 -- The real building recipe is crafted by an unmodified electric assembler.
 local ground_surface=game.surfaces[1];local bp={x=20.5,y=20.5};ground(ground_surface,bp,'grass-1');storage.builder=ground_surface.create_entity{name='assembling-machine-1',position=bp,force='player'};check(storage.builder.set_recipe('sterling-steam-catalyzer'),'real building recipe accepted');local ingredients={};for _,v in ipairs(prototypes.recipe['sterling-steam-catalyzer'].ingredients) do check(v.type=='item','item building ingredient');ingredients[#ingredients+1]={name=v.name,count=v.amount};check(storage.builder.get_inventory(defines.inventory.crafter_input).insert{name=v.name,count=v.amount}==v.amount,'actual building ingredient '..v.name) end
 local power=ground_surface.create_entity{name='sterling-proof-power',position={25,23},force='player'};local pole=ground_surface.create_entity{name='medium-electric-pole',position={23.5,23.5},force='player'};check(power and pole,'isolated normal electric supply for building craft')
 local t=prototypes.technology['hydrogen-thruster-propulsion'];local prereq={};for n in pairs(t.prerequisites) do prereq[#prereq+1]=n end
 helpers.write_file('sterling-v1/contract.json',helpers.table_to_json{prototype={name=p.name,type=p.type,footprint={p.tile_width,p.tile_height},collision_box=p.collision_box,selection_box=p.selection_box,watts=p.get_max_energy_usage()*60,target_temperature=p.target_temperature,burner_effectivity=p.burner_prototype.effectivity,fuel_slots=p.burner_prototype.fuel_inventory_size,fuel_categories=p.burner_prototype.fuel_categories,surface_conditions=p.surface_conditions,wire_reach=p.get_max_circuit_wire_distance()},placeable_item=prototypes.item[p.name].place_result.name,building_recipe={ingredients=ingredients,products=prototypes.recipe[p.name].products,seconds=prototypes.recipe[p.name].energy,categories=prototypes.recipe[p.name].categories},technology={name=t.name,prerequisites=prereq,ingredients=t.research_unit_ingredients,count=t.research_unit_count,ticks=t.research_unit_energy},native_processing='Boiler thermal fluid conversion; no assembler processing category or invented generator',thermal_ratio=10,actual_surface={platform=true,gravity=s.get_property('gravity'),pressure=s.get_property('pressure')},fixture='Water sources, steam sinks and builder electric supply are isolated test fixtures; no target production overrides.'},false)
 log('STERLING_V1_FIXTURE_READY machines=24 directions=4')
end)
script.on_event(defines.events.on_tick,function(event)
 if loaded then
  loaded=false
  if storage.snapshots then
   check(storage.complete and storage.frozen,'operated frozen save');for i,u in ipairs(storage.units) do check(u.machine.valid and same(snap(u),storage.snapshots[i]),'operated snapshot reload '..i);for box=1,2 do check(u.machine.get_fluid_box_pipe_connections(box)[1].target==(box==1 and u.input or u.output),'pipe retained reload') end end
   for _,u in ipairs(storage.units) do if u.pole then for _,color in ipairs({defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}) do check(u.machine.get_circuit_network(color).network_id==u.pole.get_circuit_network(color).network_id,'native wire retained reload') end end end
   check(storage.placed and storage.placed.valid and game.forces.player.recipes['sterling-steam-catalyzer'].enabled,'crafted placed building and unlock preserved');check(same(contents(storage.builder.get_output_inventory()),storage.builder_snapshot.output),'builder reload output');storage.reload_checked=true;helpers.write_file('sterling-v1/reload.json',helpers.table_to_json{passed=true,machines=24,fuel_fluid_energy_direction_and_disable_state=true,ordinary_pipe_connections=true,crafted_item_placement_and_unlock=true,operated_save=true},false);log('STERLING_V1_OPERATED_RELOAD_PASS machines=24')
  end
 end
 if storage.complete then
  if storage.frozen and not storage.snapshots and event.tick>=4260 then save_snapshot();game.auto_save('sterling-v1-operated');log('STERLING_V1_OPERATED_SAVE_REQUESTED') end
  return
 end
 if event.tick==600 then
  for _,u in ipairs(storage.units) do
   if u.state=='working' then
    for _,color in ipairs({defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}) do local network=u.machine.get_circuit_network(color);check(network and network.get_signal{type='item',name='coal',quality='normal'}>0,'actual fuel read on red/green network') end
   elseif u.state=='no-fuel' then check(fuel_used(u)==0 and u.machine.status==defines.entity_status.no_fuel,'actual no fuel')
   elseif u.state=='no-water' then check(fuel_used(u)==0 and u.machine.status==defines.entity_status.no_input_fluid,'actual no water')
   elseif u.state=='disabled' then check(fuel_used(u)==0 and u.machine.disabled_by_script,'disabled remains idle')
   else check(fuel_used(u)>1000000,'real native chemical fuel used') end
   if u.state=='stop-restart' then u.machine.disabled_by_script=true end
  end;log('STERLING_V1_INITIAL_STATES_PASS')
 elseif event.tick==660 then for _,u in ipairs(storage.units) do if u.state=='stop-restart' then u.stopped=snap(u) end end
 elseif event.tick==900 then for _,u in ipairs(storage.units) do if u.state=='stop-restart' then check(same(snap(u),u.stopped),'stopped inventory/fuel/energy holds');u.machine.disabled_by_script=false end end;log('STERLING_V1_STOP_HOLD_PASS')
 elseif event.tick==1200 then for _,u in ipairs(storage.units) do if u.state=='stop-restart' then check(fuel_used(u)>u.coal_added*prototypes.item.coal.fuel_value-(function()local n=0;for _,v in pairs(u.stopped.fuel) do n=n+v end;return n end)()*prototypes.item.coal.fuel_value-u.stopped.remaining_fuel+1000000,'restart consumes native fuel') end end;log('STERLING_V1_RESTART_PASS')
 elseif event.tick==2400 then for _,u in ipairs(storage.units) do if u.state=='full-output' then check(u.machine.status==defines.entity_status.full_output,'natural full output');u.blocked_fuel=fuel_used(u);local total=u.machine.get_fluid_count('steam');for _,p in ipairs(u.ordinary) do total=total+p.get_fluid_count('steam') end;check(math.abs(total-400)<.01,'natural400 steam capacity');local fluid=u.machine.get_fluid(2);check(fluid and fluid.name=='steam' and math.abs(fluid.temperature-165)<.01,'real165C output');u.blocked_steam=total end end;log('STERLING_V1_FULL_OUTPUT_PASS')
 elseif event.tick==3000 then
  for _,u in ipairs(storage.units) do
   if u.state=='full-output' then check(u.machine.status==defines.entity_status.full_output and math.abs(fuel_used(u)-u.blocked_fuel)<.01,'full output stops fuel use');open_sink(u)
   elseif u.state=='no-fuel' then check(fuel_used(u)==0,'unfueled remained cold');check(u.machine.get_fuel_inventory().insert{name='coal',count=20}==20,'actual coal resupply');u.coal_added=20
   elseif u.state=='no-water' then check(fuel_used(u)==0,'dry boiler did not burn fuel');supply_water(u) end
  end;log('STERLING_V1_BLOCK_AND_STARVATION_RELEASED')
 elseif event.tick==3600 then for _,u in ipairs(storage.units) do if u.state~='disabled' then check(fuel_used(u)>1000000 and u.machine.status==defines.entity_status.working,'actual resumed operation '..u.state);if u.state=='full-output' then check(fuel_used(u)>u.blocked_fuel+1000000,'draining output restarts burner') end end end;log('STERLING_V1_ALL_RECOVERY_PASS')
 elseif event.tick==4200 then
  local out=storage.builder.get_output_inventory();check(out.get_item_count('sterling-steam-catalyzer')==1 and storage.builder.get_inventory(defines.inventory.crafter_input).is_empty(),'actual building recipe crafted from all ingredients');local pos={x=124,y=20};ground(storage.surface,pos,'space-platform-foundation');check(storage.surface.can_place_entity{name='sterling-steam-catalyzer',position=pos,direction=4,force='player'},'actual crafted item legal platform placement');storage.placed=storage.surface.create_entity{name=prototypes.item['sterling-steam-catalyzer'].place_result.name,position=pos,direction=4,force='player'};check(storage.placed and out.remove{name='sterling-steam-catalyzer',count=1}==1,'actual crafted item consumed by scripted placement');storage.placed.disabled_by_script=true
  local cases={};for _,u in ipairs(storage.units) do cases[#cases+1]={state=u.state,direction=u.direction,status=status(u.machine),fuel_used=fuel_used(u),snapshot=snap(u)} end
  storage.complete=true;helpers.write_file('sterling-v1/native-runtime.json',helpers.table_to_json{passed=true,machines=24,directions=4,ordinary_machine_pipe_joints=48,ordinary_pipe_entities=96,platform_placement=true,building_unlock_and_real_native_recipe=true,scripted_actual_crafted_item_placement=true,full_output_capacity=400,full_output_fuel_stop_and_real_network_drain_recovery=true,no_fuel_no_water_resupply=true,script_stop_restart=true,native_red_green_fuel_read_four_directions=true,real600kW165C=true,thermal_volume_ratio=10,target_gameplay_overrides=false,cases=cases},false);freeze();log('STERLING_V1_NATIVE_PASS machines=24 directions=4')
 end
end)
remote.add_interface('sterling_proof',{layout=function() local r={surface=storage.surface.index,units={}};for _,u in ipairs(storage.units) do r.units[#r.units+1]={state=u.state,direction=u.direction,position=u.machine.position,uid=u.uid} end;return r end,freeze=freeze,snapshot=function()save_snapshot();return #storage.units end})
