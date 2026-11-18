-- Private batch proof of ten real filtered containers and their installed steward.
local keys={'coal','copper-ore','copper-plate','copper-cable','iron-gear-wheel','iron-ore','iron-plate','iron-stick','stone','wood'}
local function write(n,v)helpers.write_file('filtered-caches/'..n..'.json',helpers.table_to_json(v),false)end
local reloaded=false
script.on_load(function()reloaded=storage.done or false end)
script.on_init(function()
 if remote.interfaces.freeplay then remote.call('freeplay','set_skip_intro',true);remote.call('freeplay','set_disable_crashsite',true)end
 local s=game.surfaces[1];s.request_to_generate_chunks({24,72},5);s.force_generate_chunk_requests();s.always_day=true
 local tiles={};for x=-8,75 do for y=-8,170 do tiles[#tiles+1]={name='refined-concrete',position={x,y}}end end;s.set_tiles(tiles)
 for _,e in pairs(s.find_entities_filtered{area={{-8,-8},{75,170}},type={'tree','simple-entity','cliff'}})do e.destroy()end
 storage.start=game.tick;storage.rows={};storage.result={rows={}}
 local sides={{0,-1,defines.direction.north},{1,0,defines.direction.east},{0,1,defines.direction.south},{-1,0,defines.direction.west}}
 for index,key in ipairs(keys)do
  local ID='tech-priests-stone-cache-'..key;local y=(index-1)*14;local row={key=key,sites={}};local r={inventory_size=true,recipe_enabled=game.forces.player.recipes[ID].enabled,inputs={},outputs={}};storage.result.rows[key]=r
  for i,v in ipairs(sides)do
   local x=(i-1)*8;local e=s.create_entity{name=ID,position={x,y},force='player',raise_built=true};local tx,ty=v[1]==0 and .5 or 0,v[2]==0 and .5 or 0
   local chest=s.create_entity{name='steel-chest',position={x+v[1]*2.5+tx,y+v[2]*2.5+ty},force='player'};chest.insert{name=key,count=4}
   local arm=s.create_entity{name='burner-inserter',position={x+v[1]*1.5+tx,y+v[2]*1.5+ty},direction=v[3],force='player'};arm.insert{name='coal',count=10};row.sites[i]={entity=e,chest=chest,arm=arm,direction=v[3]};r.inventory_size=r.inventory_size and #e.get_inventory(defines.inventory.chest)==6
  end
  row.signal=s.create_entity{name=ID,position={0,y+6},force='player',raise_built=true};row.signal.insert{name=key,count=7};row.receiver=s.create_entity{name='constant-combinator',position={3.5,y+6.5},force='player'};row.far=s.create_entity{name='constant-combinator',position={40.5,y+6.5},force='player'};r.wires={}
  for _,wire in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}do r.wires[#r.wires+1]=row.signal.get_wire_connector(wire,true).connect_to(row.receiver.get_wire_connector(wire,true))end
  r.far_wire_rejected=not row.signal.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(row.far.get_wire_connector(defines.wire_connector_id.circuit_red,true))
  row.blocked=s.create_entity{name=ID,position={12,y+6},force='player',raise_built=true};r.capacity=prototypes.item[key].stack_size*6;row.blocked.insert{name=key,count=r.capacity}
  row.block_source=s.create_entity{name='steel-chest',position={12.5,y+3.5},force='player'};row.block_source.insert{name=key,count=4};row.block_arm=s.create_entity{name='burner-inserter',position={12.5,y+4.5},direction=defines.direction.north,force='player'};row.block_arm.insert{name='coal',count=10}
  row.showcase=s.create_entity{name=ID,position={50+((index-1)%5)*4,155+math.floor((index-1)/5)*5},force='player'};storage.rows[index]=row
 end
end)
script.on_event(defines.events.on_player_created,function(e)local p=game.get_player(e.player_index);p.set_controller{type=defines.controllers.god};p.teleport({46,152},game.surfaces[1])end)
script.on_event(defines.events.on_tick,function()
 local t=game.tick-storage.start;local result=storage.result
 if t==600 then
  for _,row in ipairs(storage.rows)do local r=result.rows[row.key];for i,v in ipairs(row.sites)do r.inputs[i]=v.entity.get_item_count(row.key)==4;v.arm.direction=(v.direction+8)%16 end;r.full_blocks=row.blocked.get_item_count(row.key)==r.capacity;row.blocked.remove_item{name=row.key,count=prototypes.item[row.key].stack_size}end
 elseif t==1200 then
  for _,row in ipairs(storage.rows)do
   local r=result.rows[row.key];for i,v in ipairs(row.sites)do r.outputs[i]=v.entity.get_item_count(row.key)==0 and v.chest.get_item_count(row.key)==4 end
   r.unblocked=row.blocked.get_item_count(row.key)==r.capacity-prototypes.item[row.key].stack_size+4;r.signals=true
   for _,wire in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}do r.signals=r.signals and row.receiver.get_signal({type='item',name=row.key},wire)==7 end
   local ID='tech-priests-stone-cache-'..row.key;local e=game.surfaces[1].create_entity{name=ID,position={30,(table_size(result.rows)+1)*14},force='player'};e.insert{name=row.key,count=13};local inv=game.create_inventory(4);r.mining=e.mine{inventory=inv} and inv.get_item_count(ID)==1 and inv.get_item_count(row.key)==13;inv.destroy()
  end
 elseif t==1205 then
  for i,row in ipairs(storage.rows)do result.rows[row.key].filter=remote.call('filtered_cache_native_proof','test',row.key,i)end
 elseif t==1250 then
  result.passed=true
  for _,row in ipairs(storage.rows)do
   local r=result.rows[row.key];r.passed=r.inventory_size and r.recipe_enabled and r.far_wire_rejected and r.full_blocks and r.unblocked and r.signals and r.mining and r.filter.passed
   for _,list in ipairs{r.inputs,r.outputs,r.wires}do for _,ok in ipairs(list)do r.passed=r.passed and ok end end;result.passed=result.passed and r.passed
  end
  storage.done=true;write('native-results',result);game.auto_save('filtered-caches-complete')
 elseif t==1300 and reloaded then
  local ok=true;for _,row in ipairs(storage.rows)do ok=ok and row.signal.get_item_count(row.key)==7 and row.blocked.get_item_count(row.key)==result.rows[row.key].capacity-prototypes.item[row.key].stack_size+4;for _,wire in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}do ok=ok and row.receiver.get_signal({type='item',name=row.key},wire)==7 end end;write('reload-results',{passed=result.passed,reload_preserved=ok})
 end
 local p=game.players[1]
 if p then
  for i,row in ipairs(storage.rows)do if t==1350+(i-1)*8 then game.take_screenshot{player=p,surface=game.surfaces[1],position=row.showcase.position,resolution={1000,640},zoom=5,path='filtered-caches/native-'..row.key..'.png',show_gui=false,show_entity_info=false}end end
  if t==1450 then game.take_screenshot{player=p,surface=game.surfaces[1],position={58,157.5},resolution={1600,900},zoom=2.4,path='filtered-caches/native-gallery.png',show_gui=false,show_entity_info=false}end
 end
end)
