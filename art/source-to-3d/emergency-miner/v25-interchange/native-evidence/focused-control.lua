local NAME='tech-priests-emergency-miner'
local function check(v,m)if not v then error('MINER FOCUSED: '..m)end end
script.on_init(function()
 game.speed=16;local s=game.surfaces[1];local f=game.forces.player;s.request_to_generate_chunks({20,20},2);s.force_generate_chunk_requests();for _,e in pairs(s.find_entities_filtered{area={{5,5},{40,40}}})do if e.type~='character'then e.destroy()end end
 local ts={};for x=5,40 do for y=5,40 do ts[#ts+1]={name='grass-1',position={x,y}}end end;s.set_tiles(ts,true)
 local e=s.create_entity{name=NAME,position={20.5,20.5},force=f,raise_built=true};e.set_recipe('tech-priests-emergency-mine-wood');storage.e=e
 local sig=s.create_entity{name='constant-combinator',position={22.5,20.5},force=f};storage.section=sig.get_or_create_control_behavior().add_section();storage.section.set_slot(1,{value={type='virtual',name='signal-A',quality='normal'},min=1})
 for _,id in ipairs({defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green})do check(e.get_wire_connector(id,true).connect_to(sig.get_wire_connector(id,true),true,defines.wire_origin.player),'normal circuit attachment')end
 local b=e.get_or_create_control_behavior();b.circuit_enable_disable=true;b.circuit_condition={first_signal={type='virtual',name='signal-A'},comparator='>',constant=0}
 s.create_entity{name='substation',position={15,15},force=f};s.create_entity{name='miner-proof-power',position={14,14},force=f};storage.builder=s.create_entity{name='assembling-machine-3',position={12,12},force=f};storage.builder.set_recipe(NAME);check(storage.builder.insert{name='stone',count=1}==1 and storage.builder.insert{name='iron-plate',count=1}==1,'real building ingredients');storage.hold=s.create_entity{name='steel-chest',position={25.5,25.5},force=f}
end)
script.on_event(defines.events.on_tick,function(ev)
 local t=ev.tick;local e=storage.e
 if t==120 then e.set_recipe('tech-priests-emergency-mine-wood')
 elseif t==1500 then
  helpers.write_file('miner-focused/diagnostic.json',helpers.table_to_json{status=e.status,progress=e.crafting_progress,products=e.products_finished,recipe=e.get_recipe()and e.get_recipe().name,condition=e.get_control_behavior().circuit_condition,signal=e.get_circuit_network(defines.wire_connector_id.circuit_red).get_signal{type='virtual',name='signal-A',quality='normal'}},false);check(e.products_finished>0,'native enabled production');for _,id in ipairs({defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green})do check(e.get_circuit_network(id).get_signal{type='virtual',name='signal-A',quality='normal'}==1,'correct red green connector signal')end;storage.section.set_slot(1,{value={type='virtual',name='signal-A',quality='normal'},min=0})
 elseif t==1560 then check(e.status==defines.entity_status.disabled_by_control_behavior,'circuit disabled');storage.progress=e.crafting_progress;storage.products=e.products_finished
 elseif t==1860 then check(e.crafting_progress==storage.progress and e.products_finished==storage.products,'circuit stopped progress');storage.section.set_slot(1,{value={type='virtual',name='signal-A',quality='normal'},min=1})
 elseif t==3300 then
  check(e.products_finished>storage.products,'real circuit restart');local inv=storage.builder.get_output_inventory();check(inv.remove{name=NAME,count=1}==1,'real building recipe crafted');local s=e.surface;local pos={27.5,27.5};check(s.can_place_entity{name=NAME,position=pos,force='player'},'ordinary player grid placement');local built=s.create_entity{name=NAME,position=pos,force='player',raise_built=true};check(built.mine{inventory=storage.hold.get_inventory(defines.inventory.chest),raise_destroyed=true},'native mine');check(storage.hold.get_inventory(defines.inventory.chest).get_item_count(NAME)==1,'mined item returned');helpers.write_file('miner-focused/operation.json',helpers.table_to_json{passed=true,actual_building_recipe_place_mine=true,real_red_green_connections=true,real_signal_driven_stop_restart=true,no_prototype_overrides=true,no_progress_energy_product_assignments=true},false);log('MINER_FOCUSED_PASS')
 end
end)
