-- Private real-grid accumulator proof. No bank energy is written by the test.
local ID='tech-priests-stone-cache-primitive-acclimator-battery-bank'
local reloaded=false
local function write(n,v)helpers.write_file('battery-bank/'..n..'.json',helpers.table_to_json(v),false)end
local function create(n,p)return game.surfaces[1].create_entity{name=n,position=p,force='player'}end
local function source()storage.source=create('bank-proof-source',{3.5,.5})end
local function pole()storage.pole=create('small-electric-pole',{1.5,.5})end
script.on_load(function()reloaded=storage.done or false end)
script.on_init(function()
 if remote.interfaces.freeplay then remote.call('freeplay','set_skip_intro',true);remote.call('freeplay','set_disable_crashsite',true)end
 local s=game.surfaces[1];s.request_to_generate_chunks({0,0},3);s.force_generate_chunk_requests();s.always_day=true
 local tiles={};for x=-10,20 do for y=-10,14 do tiles[#tiles+1]={name='refined-concrete',position={x,y}}end end;s.set_tiles(tiles)
 for _,e in pairs(s.find_entities_filtered{area={{-10,-10},{20,14}},type={'tree','simple-entity','cliff'}})do e.destroy()end
 storage.start=game.tick;storage.bank=create(ID,{0,0});pole();source();storage.receiver=create('constant-combinator',{0,3});storage.far=create('constant-combinator',{14,0});local b=storage.bank
 storage.result={energy_trace={},peak_input_j_per_tick=0,peak_output_j_per_tick=0,no_item_inventory=b.get_inventory(defines.inventory.chest)==nil,recipe_initially_locked=not game.forces.player.recipes[ID].enabled,wire_connections={}}
 game.forces.player.technologies['electric-energy-accumulators'].researched=true;storage.result.research_unlock=game.forces.player.recipes[ID].enabled
 for _,wire in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}do storage.result.wire_connections[#storage.result.wire_connections+1]=b.get_wire_connector(wire,true).connect_to(storage.receiver.get_wire_connector(wire,true))end
 storage.result.far_wire_rejected=not b.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(storage.far.get_wire_connector(defines.wire_connector_id.circuit_red,true))
 storage.last=b.energy
end)
script.on_event(defines.events.on_player_created,function(e)local p=game.get_player(e.player_index);p.set_controller{type=defines.controllers.god};p.teleport({0,0},game.surfaces[1])end)
script.on_event(defines.events.on_tick,function()
 local t=game.tick-storage.start;local b=storage.bank;local r=storage.result;local energy=b.energy;local delta=energy-storage.last;storage.last=energy
 if not storage.done then
  r.peak_input_j_per_tick=math.max(r.peak_input_j_per_tick,delta);r.peak_output_j_per_tick=math.max(r.peak_output_j_per_tick,-delta)
  if t%10==0 then r.energy_trace[#r.energy_trace+1]={tick=t,joules=energy}end
 end
 local function signals(v)
  local ok=true
  for _,wire in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}do ok=ok and storage.receiver.get_signal({type='virtual',name='signal-A'},wire)==v end
  return ok
 end
 if t==190 then r.full_charge=math.abs(energy-1000000)<1;r.full_signal=signals(100)
 elseif t==220 then storage.source.destroy();storage.load=create('bank-proof-load',{3.5,-1.5})
 elseif t==400 then r.empty_discharge=energy<1;r.empty_signal=signals(0);storage.load.destroy();source()
 elseif t==600 then r.recharge=math.abs(energy-1000000)<1;storage.pole.destroy();storage.source.destroy();storage.islanded=energy
 elseif t==680 then r.isolated_holds=math.abs(energy-storage.islanded)<1;pole();storage.load=create('bank-proof-load',{3.5,-1.5})
 elseif t==720 then r.reconnection_discharges=energy<storage.islanded-100000;storage.load.destroy();source()
 elseif t==910 then r.restart_full=math.abs(energy-1000000)<1;storage.source.destroy();storage.pole.destroy()
 elseif t==960 then
  r.capacity_1MJ=b.electric_buffer_size==1000000;r.flow_limits=r.peak_input_j_per_tick<=500000/60+.1 and r.peak_output_j_per_tick<=500000/60+.1 and r.peak_input_j_per_tick>8000 and r.peak_output_j_per_tick>8000
  local e=create(ID,{8,7});local inv=game.create_inventory(2);r.mining=e.mine{inventory=inv} and inv.get_item_count(ID)==1;inv.destroy()
  r.passed=r.no_item_inventory and r.recipe_initially_locked and r.research_unlock and r.full_charge and r.full_signal and r.empty_discharge and r.empty_signal and r.recharge and r.isolated_holds and r.reconnection_discharges and r.restart_full and r.capacity_1MJ and r.flow_limits and r.mining and r.far_wire_rejected
  for _,ok in ipairs(r.wire_connections)do r.passed=r.passed and ok end
  storage.saved_energy=energy;storage.done=true;write('native-results',r);game.auto_save('battery-bank-complete')
 elseif t==1000 and reloaded then write('reload-results',{passed=r.passed,reload_preserved=math.abs(energy-storage.saved_energy)<1 and signals(100),energy=energy})
 elseif t==1020 then
  pole();storage.load=create('bank-proof-load',{3.5,-1.5})
 elseif t==1190 then storage.load.destroy();source()
 end
 local p=game.players[1]
 if p and (t==980 or t==1060 or t==1230)then
  local name=t==980 and 'native-plain.png' or t==1060 and 'native-discharge.png' or 'native-charge.png'
  game.take_screenshot{player=p,surface=game.surfaces[1],position={0,-.0121320344},resolution={1000,640},zoom=5,path='battery-bank/'..name,show_gui=false,show_entity_info=false}
 end
end)
