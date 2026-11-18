-- Private, exact-source fluid proof. No production controls or test fixtures ship.
local ID='tech-priests-stone-cache-pressurized-fluid-vault'
local reloaded=false
local function write(n,v)helpers.write_file('fluid-vault/'..n..'.json',helpers.table_to_json(v),false)end
local function fluid(e)local f=e.get_fluid(1);return f and {name=f.name,amount=f.amount,temperature=f.temperature} or {amount=0,temperature=0}end
local function connected(row)return row.tank.get_fluid_segment_id(1)==row.pipes[1].get_fluid_segment_id(1) and row.tank.get_fluid_segment_id(1)==row.pipes[2].get_fluid_segment_id(1)end
local function snapshot()
 local v={}
 for i,row in ipairs(storage.rows)do v[i]={tank=fluid(row.tank),a=fluid(row.pipes[1]),b=fluid(row.pipes[2]),direction=row.tank.direction,connected=connected(row)}end
 return v
end
script.on_load(function()reloaded=storage.done or false end)
script.on_init(function()
 if remote.interfaces.freeplay then remote.call('freeplay','set_skip_intro',true);remote.call('freeplay','set_disable_crashsite',true)end
 local s=game.surfaces[1];s.request_to_generate_chunks({12,5},4);s.force_generate_chunk_requests();s.always_day=true
 local tiles={};for x=-6,47 do for y=-6,16 do tiles[#tiles+1]={name='refined-concrete',position={x,y}}end end;s.set_tiles(tiles)
 for _,e in pairs(s.find_entities_filtered{area={{-6,-6},{47,16}},type={'tree','simple-entity','cliff'}})do e.destroy()end
 storage.start=game.tick;storage.rows={};storage.r={rows={},initially_locked=not game.forces.player.recipes[ID].enabled}
 game.forces.player.technologies['fluid-handling'].researched=true;storage.r.research_unlock=game.forces.player.recipes[ID].enabled
 for i,spec in ipairs{{direction=0,reverse=false,name='water',temperature=35},{direction=0,reverse=true,name='steam',temperature=165},{direction=4,reverse=false,name='water',temperature=35},{direction=4,reverse=true,name='steam',temperature=165}}do
  local p={x=(i-1)*8+.5,y=.5};local e=s.create_entity{name=ID,position=p,direction=spec.direction,force='player'};local axis=spec.direction==0 and {0,1} or {1,0};local pipes={};local build=true
  for _,sign in ipairs{-1,1}do local q={p.x+axis[1]*2*sign,p.y+axis[2]*2*sign};build=build and s.can_place_entity{name='pipe',position=q,force='player'};pipes[#pipes+1]=s.create_entity{name='pipe',position=q,force='player'}end
  local receiver=s.create_entity{name='constant-combinator',position={p.x+3,p.y+3},force='player'};local wires={}
  for _,wire in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}do wires[#wires+1]=e.get_wire_connector(wire,true).connect_to(receiver.get_wire_connector(wire,true))end
  local control=e.get_or_create_control_behavior();control.read_temperature=true;control.temperature_signal={type='virtual',name='signal-T'}
  local r={direction=e.direction,pipe_build=build,wire_connections=wires,capacity=e.get_fluid_capacity(1),no_item_inventory=e.get_inventory(defines.inventory.chest)==nil,inserted=0,removed=0,fluid=spec.name,temperature=spec.temperature}
  storage.r.rows[i]=r;storage.rows[i]={tank=e,pipes=pipes,receiver=receiver,spec=spec,input=spec.reverse and 2 or 1,output=spec.reverse and 1 or 2}
 end
 storage.solo=s.create_entity{name=ID,position={24.5,9.5},force='player'};local solo=storage.solo;storage.r.capacity_clamps=solo.insert_fluid{name='water',amount=2500,temperature=35}==1000 and solo.insert_fluid{name='water',amount=50,temperature=35}==0;solo.remove_fluid(1,250);storage.r.unblocked=solo.insert_fluid{name='water',amount=200,temperature=35}==200
 storage.rotated=s.create_entity{name=ID,position={16.5,9.5},force='player'};storage.rotated.insert_fluid{name='steam',amount=800,temperature=165}
 storage.alias_s=s.create_entity{name=ID,position={.5,9.5},direction=8,force='player'};storage.alias_w=s.create_entity{name=ID,position={8.5,9.5},direction=12,force='player'};storage.r.aliases=storage.alias_s.direction==0 and storage.alias_w.direction==4
 storage.far=s.create_entity{name='constant-combinator',position={44.5,10.5},force='player'};storage.r.far_wire_rejected=not storage.rows[1].tank.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(storage.far.get_wire_connector(defines.wire_connector_id.circuit_red,true))
end)
script.on_event(defines.events.on_player_created,function(e)local p=game.get_player(e.player_index);p.set_controller{type=defines.controllers.god};p.teleport({3,4},game.surfaces[1])end)
script.on_event(defines.events.on_tick,function()
 local t=game.tick-storage.start;local r=storage.r
 if t<=80 then
  for i,row in ipairs(storage.rows)do r.rows[i].inserted=r.rows[i].inserted+row.pipes[row.input].insert_fluid{name=row.spec.name,amount=100,temperature=row.spec.temperature}end
 elseif t==100 then
  for i,row in ipairs(storage.rows)do
   local v=r.rows[i];local a=fluid(row.tank);local b=fluid(row.pipes[row.output]);v.connected=connected(row);v.far_end_received=b.amount>0 and b.name==row.spec.name and math.abs(b.temperature-row.spec.temperature)<.01;v.stored=a.amount>0 and a.name==row.spec.name
   v.conservation=math.abs(a.amount+fluid(row.pipes[1]).amount+fluid(row.pipes[2]).amount-v.inserted)<.01;v.signals=true
   for _,wire in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}do
    local amount=row.receiver.get_signal({type='fluid',name=row.spec.name},wire);local temp=row.receiver.get_signal({type='virtual',name='signal-T'},wire);v.signals=v.signals and amount==math.floor(a.amount) and temp==math.floor(row.spec.temperature);v.signal_observed={amount=amount,temperature=temp,expected_amount=math.floor(a.amount)}
   end
  end
 elseif t>=110 and t<=200 then
  for i,row in ipairs(storage.rows)do local f=row.pipes[row.output].remove_fluid(1,100);if f then r.rows[i].removed=r.rows[i].removed+f.amount end end
 elseif t==220 then
  local e=storage.rotated;local before=fluid(e);r.loaded_rotation=e.rotate{} and e.direction==4 and math.abs(fluid(e).amount-before.amount)<.01 and math.abs(fluid(e).temperature-before.temperature)<.01
  storage.rotated_pipes={};for _,dx in ipairs{-2,2}do storage.rotated_pipes[#storage.rotated_pipes+1]=game.surfaces[1].create_entity{name='pipe',position={e.position.x+dx,e.position.y},force='player'}end
 elseif t==270 then
  local e=storage.rotated;local f=fluid(e);r.rotated_reconnect=math.abs(f.amount+fluid(storage.rotated_pipes[1]).amount+fluid(storage.rotated_pipes[2]).amount-800)<.01 and f.temperature==165
  for _,p in ipairs(storage.rotated_pipes)do r.rotated_reconnect=r.rotated_reconnect and p.get_fluid_segment_id(1)==e.get_fluid_segment_id(1)end
 elseif t==300 then
  r.passed=r.initially_locked and r.research_unlock and r.capacity_clamps and r.unblocked and r.aliases and r.far_wire_rejected and r.loaded_rotation and r.rotated_reconnect
  for _,v in ipairs(r.rows)do
   v.drawdown=v.removed>100;v.passed=v.pipe_build and v.connected and v.capacity==1000 and v.no_item_inventory and v.far_end_received and v.stored and v.conservation and v.signals and v.drawdown
   for _,ok in ipairs(v.wire_connections)do v.passed=v.passed and ok end;r.passed=r.passed and v.passed
  end
  local inv=game.create_inventory(2);r.mining=storage.solo.mine{inventory=inv} and inv.get_item_count(ID)==1;inv.destroy();r.passed=r.passed and r.mining
  storage.saved=snapshot();storage.done=true;write('native-results',r);game.auto_save('fluid-vault-complete')
 elseif t==340 and reloaded then
  local now=snapshot();local ok=true
  for i,v in ipairs(now)do local old=storage.saved[i];ok=ok and v.direction==old.direction and v.connected==old.connected;for _,k in ipairs{'tank','a','b'}do ok=ok and v[k].name==old[k].name and math.abs(v[k].amount-old[k].amount)<.01 and math.abs(v[k].temperature-old[k].temperature)<.01 end end
  write('reload-results',{passed=r.passed,reload_preserved=ok,snapshot=now})
 end
 local p=game.players[1]
 if p and (t==320 or t==360 or t==400)then
  local pos=t==320 and {.5,.5} or t==360 and {16.5,.5} or {16.5,9.5};local name=t==320 and 'native-north.png' or t==360 and 'native-east.png' or 'native-rotated.png'
  game.take_screenshot{player=p,surface=game.surfaces[1],position=pos,resolution={1000,640},zoom=5,path='fluid-vault/'..name,show_gui=false,show_entity_info=false}
 end
end)
