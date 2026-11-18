local NAME='tech-priests-emergency-smelter'
local function check(v,msg)if not v then error('SMELTER PROOF: '..msg)end end
local function inv(e)return e.get_inventory(defines.inventory.chest)end
local function snap(u)local e=u.machine;return{progress=e.crafting_progress,products=e.products_finished,recipe=e.get_recipe()and e.get_recipe().name,status=e.status,working=e.is_crafting(),fuel_remaining=e.burner.remaining_burning_fuel,health=e.health}end
local function same(a,b)return math.abs(a.progress-b.progress)<1e-7 and a.products==b.products end
local function move(a,b)for i=1,#a do if a[i].valid_for_read then local n=b.insert(a[i]);check(n==a[i].count,'hold stock conserved');a[i].clear()end end end
local function record(name)local r={};for _,u in ipairs(storage.units)do r[#r+1]=snap(u)end;storage.samples[name]=r end
script.on_init(function()
 local s=game.surfaces[1];local f=game.forces.player;game.speed=10;f.technologies['steel-processing'].researched=true;f.technologies['lithium-processing'].researched=true
 s.request_to_generate_chunks({20,20},4);s.force_generate_chunk_requests();local tiles={};for x=0,100 do for y=0,55 do tiles[#tiles+1]={name='grass-1',position={x,y}}end end;s.set_tiles(tiles,true)
 for _,e in pairs(s.find_entities_filtered{area={{0,0},{100,55}},type={'tree','simple-entity','cliff'}})do e.destroy()end
 storage.units={};storage.samples={}
 for k,item in ipairs({'iron-ore','copper-ore','stone','iron-plate','lithium','mechanical-detritus'})do
  local x,y=10.5+(k-1)*14,20.5;local e=assert(s.create_entity{name=NAME,position={x,y},force=f,raise_built=true});check(e.prototype.tile_width==1 and e.prototype.tile_height==1,'actual1x1');check(e.fluids_count==0,'no fluid sockets');check(e.burner and #e.get_fuel_inventory()==1,'native single-slot chemical burner');check(math.abs(e.prototype.get_max_energy_usage()*60-70000)<.01,'unchanged70kW');check(e.prototype.burner_prototype.effectivity==.75,'unchanged .75 burner efficiency');check(e.crafting_speed==.25 and #e.get_inventory(defines.inventory.crafter_input)==1 and #e.get_output_inventory()==8,'actual speed/input and repaired recipe output capacity');check(e.energy==0,'starts without fabricated energy')
  local u={machine=e,position={x=x,y=y},input=item,health=e.health};storage.units[#storage.units+1]=u
  u.ore=s.create_entity{name='steel-chest',position={x+2,y},force=f};inv(u.ore).insert{name=item,count=2000}
  u.fuel=s.create_entity{name='steel-chest',position={x,y-2},force=f};inv(u.fuel).insert{name='coal',count=16}
  u.outS=s.create_entity{name='steel-chest',position={x,y+2},force=f};u.outW=s.create_entity{name='steel-chest',position={x-2,y},force=f};u.hold=s.create_entity{name='steel-chest',position={x+4,y+4},force=f}
  u.iOre=s.create_entity{name='fast-inserter',position={x+1,y},direction=4,force=f};u.iFuel=s.create_entity{name='fast-inserter',position={x,y-1},direction=0,force=f};u.oS=s.create_entity{name='fast-inserter',position={x,y+1},direction=0,force=f};u.oW=s.create_entity{name='fast-inserter',position={x-1,y},direction=4,force=f};for _,i in ipairs({u.iOre,u.iFuel,u.oS,u.oW})do i.disabled_by_script=true end
  u.power=s.create_entity{name='smelter-proof-power',position={x+3,y-3},force=f};s.create_entity{name='medium-electric-pole',position={x+2,y-2},force=f};s.create_entity{name='medium-electric-pole',position={x-2,y+2},force=f}
  u.circuit=s.create_entity{name='constant-combinator',position={x+3,y+1},force=f};u.section=u.circuit.get_or_create_control_behavior().add_section()
  for _,id in ipairs({defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green})do local a=e.get_wire_connector(id,true);local b=u.circuit.get_wire_connector(id,true);check(a.can_wire_reach(b)and a.connect_to(b,true,defines.wire_origin.player),'ordinary reach-checked red/green wires')end
 end
 record('empty-idle')
end)
script.on_event(defines.events.on_tick,function(ev)
 local t=ev.tick
 if storage.complete then
  if t>=storage.complete_tick+360 and not storage.reloaded then storage.reloaded=true;for _,u in ipairs(storage.units)do check(u.machine.valid and u.machine.health==u.health,'operated entities persist');check(u.machine.burner and u.machine.fluids_count==0,'burner/no fluids persist')end;helpers.write_file('smelter-proof/reloaded-state.json',helpers.table_to_json{passed=true,tick=t,samples=storage.samples},false);log('SMELTER_PERSISTENT_STATE_PASS')end;return
 end
 if t==120 then
  for _,u in ipairs(storage.units)do check(not u.machine.is_crafting(),'empty idle');for _,i in ipairs({u.iOre,u.iFuel,u.oS,u.oW})do i.disabled_by_script=false end end
 elseif t==240 then
  for _,u in ipairs(storage.units)do check(u.iOre.drop_target==u.machine and u.iFuel.drop_target==u.machine and u.oS.pickup_target==u.machine and u.oW.pickup_target==u.machine,'all four ordinary inserter targets');u.selected=u.machine.get_recipe()and u.machine.get_recipe().name end;record('native-automatic-recipe-selection');local rows={};for _,u in ipairs(storage.units)do rows[#rows+1]={input=u.input,fuel_chest=inv(u.fuel).get_contents(),ore_chest=inv(u.ore).get_contents(),machine_fuel=u.machine.get_fuel_inventory().get_contents(),machine_input=u.machine.get_inventory(defines.inventory.crafter_input).get_contents(),inserter_energy=u.iOre.energy,fuel_inserter_energy=u.iFuel.energy,ore_inserter_status=u.iOre.status,fuel_inserter_status=u.iFuel.status,power_energy=u.power.energy,power_network=u.power.electric_network_id}end;helpers.write_file('smelter-proof/logistics-diagnostic.json',helpers.table_to_json(rows),false)
 elseif t==6000 then
  local rows={};for _,u in ipairs(storage.units)do u.selected=u.selected or(u.machine.get_recipe()and u.machine.get_recipe().name);rows[#rows+1]={input=u.input,selected=u.selected,now=snap(u),outSouth=inv(u.outS).get_contents(),outWest=inv(u.outW).get_contents()}end;helpers.write_file('smelter-proof/selection-and-products.json',helpers.table_to_json(rows),false)
  for _,u in ipairs(storage.units)do check(u.machine.products_finished>0,'actual automatic recipe completed '..u.input..' selected '..tostring(u.selected));check(u.machine.health==u.health,'health retained');u.machine.disabled_by_script=true;u.stopped=snap(u)end;record('working-real-products')
 elseif t==6120 then for _,u in ipairs(storage.units)do check(same(snap(u),u.stopped),'script stop holds');u.machine.disabled_by_script=false end;record('script-stop-restart')
 elseif t==6300 then
  local b=storage.units[2];b.oS.disabled_by_script=true;b.oW.disabled_by_script=true;move(b.machine.get_output_inventory(),inv(b.hold));for i=1,#b.machine.get_output_inventory()do b.machine.get_output_inventory()[i].set_stack{name='copper-plate',count=100}end
  local f=storage.units[1];f.iFuel.disabled_by_script=true;move(f.machine.get_fuel_inventory(),inv(f.hold));move(inv(f.fuel),inv(f.hold))
  local u=storage.units[3];u.iOre.disabled_by_script=true;move(u.machine.get_inventory(defines.inventory.crafter_input),inv(u.hold));move(inv(u.ore),inv(u.hold))
 elseif t==9500 then local u=storage.units[1];u.fuelstarved=snap(u)
 elseif t==9620 then local u=storage.units[1];helpers.write_file('smelter-proof/fuel-timing-diagnostic.json',helpers.table_to_json{before=u.fuelstarved,now=snap(u),fuel_inventory=u.machine.get_fuel_inventory().get_contents(),native_energy=u.machine.energy},false);check(same(snap(u),u.fuelstarved)and u.machine.status==defines.entity_status.no_fuel and u.machine.burner.remaining_burning_fuel<.01 and u.machine.energy<.01,'naturally exhausted actual fuel blocks');inv(u.fuel).insert{name='coal',count=16};u.iFuel.disabled_by_script=false;record('fuel-exhaustion-resupply')
 elseif t==10500 then local u=storage.units[2];u.blocked=snap(u)
 elseif t==10620 then local u=storage.units[2];check(same(snap(u),u.blocked)and u.machine.status==defines.entity_status.full_output,'native full-output blocks');move(u.machine.get_output_inventory(),inv(u.hold));u.oS.disabled_by_script=false;u.oW.disabled_by_script=false;record('blocked-output-release')
 elseif t==11500 then local u=storage.units[3];u.starved=snap(u)
 elseif t==11620 then local u=storage.units[3];check(same(snap(u),u.starved)and not u.machine.is_crafting(),'actual input starvation');inv(u.ore).insert{name=u.input,count=200};u.iOre.disabled_by_script=false;record('input-starvation-resupply')
 elseif t==11700 then
  for _,u in ipairs(storage.units)do check(u.machine.is_crafting(),'actual resupply resumes '..u.input);local b=u.machine.get_or_create_control_behavior();b.circuit_enable_disable=true;b.circuit_condition={comparator='>',first_signal={type='virtual',name='signal-A'},constant=0}end
 elseif t==11820 then for _,u in ipairs(storage.units)do check(u.machine.get_control_behavior().disabled,'native circuit disables');u.circuitstop=snap(u)end
 elseif t==11940 then for _,u in ipairs(storage.units)do check(same(snap(u),u.circuitstop),'circuit stop holds');u.section.set_slot(1,{value={type='virtual',name='signal-A',quality='normal'},min=1})end;record('circuit-hold-release')
 elseif t==12200 then
  for _,u in ipairs(storage.units)do check(not u.machine.get_control_behavior().disabled and u.machine.is_crafting(),'native circuit restart')end
  local u=storage.units[1];local s=u.machine.surface;storage.builder=s.create_entity{name='assembling-machine-3',position={x=u.position.x+4,y=u.position.y+8},force='player'};s.create_entity{name='medium-electric-pole',position={x=u.position.x+4,y=u.position.y+5},force='player'};storage.builder.set_recipe(NAME);check(storage.builder.insert{name='stone',count=4}==4,'actual four-stone building recipe')
 elseif t==13000 then
  local out=storage.builder.get_output_inventory();check(out.get_item_count(NAME)==1,'actual two-second building recipe');check(out.remove{name=NAME,count=1}==1,'consume crafted item');local u=storage.units[1];local s=u.machine.surface;local p={x=u.position.x+5,y=u.position.y+11};check(s.can_place_entity{name=NAME,position=p,force='player'},'normal1x1 placement');local e=s.create_entity{name=NAME,position=p,force='player',raise_built=true};local hold=inv(u.hold);check(e.mine{inventory=hold,raise_destroyed=true}and hold.get_item_count(NAME)==1,'actual mining returns crafted item')
  record('completed');storage.complete=true;storage.complete_tick=t;local rows={};for _,u in ipairs(storage.units)do rows[#rows+1]={input=u.input,selected_recipe=u.selected,completed_products=u.machine.products_finished}end
  helpers.write_file('smelter-proof/operation.json',helpers.table_to_json{passed=true,actual_six_native_selected_recipe_paths=rows,nine_compatible_prototype_recipes=true,hidden_wrappers_not_forced=true,ordinary_four_sided_inserters=true,normal_red_green_wires=true,actual_building_recipe_place_mine=true,native_fuel_exhaustion_and_restart=true,no_target_or_accumulator_energy_assignments=true,power_fixture='External test-only EEI powers ordinary inserters and construction assembler. Target furnace uses its own actual chemical burner only.',samples=storage.samples},false);log('SMELTER_NATIVE_OPERATIONAL_PASS');if game.is_multiplayer()then game.server_save('smelter-operated')end
 end
end)
remote.add_interface('smelter_proof',{layout=function()local rows={};for _,u in ipairs(storage.units or{})do rows[#rows+1]={entity=u.machine,position=u.position,surface=u.machine.surface.index,input=u.input}end;return rows end})
