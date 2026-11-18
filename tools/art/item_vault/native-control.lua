-- Private cache proof. Never copied into production.
local ID='tech-priests-stone-cache-item-vault'
local function write(name,data)helpers.write_file('item-vault/'..name..'.json',helpers.table_to_json(data),false)end
local reloaded=false
script.on_load(function()reloaded=storage.result and storage.result.passed or false end)
script.on_init(function()
 if remote.interfaces.freeplay then remote.call('freeplay','set_skip_intro',true);remote.call('freeplay','set_disable_crashsite',true) end
 local s=game.surfaces[1];s.request_to_generate_chunks({0,5},3);s.force_generate_chunk_requests();s.always_day=true
 local tiles={};for x=-8,38 do for y=-8,18 do tiles[#tiles+1]={name='refined-concrete',position={x,y}}end end;s.set_tiles(tiles)
 for _,e in pairs(s.find_entities_filtered{area={{-8,-8},{38,18}},type={'tree','simple-entity','cliff'}})do e.destroy()end
 storage.start=game.tick;storage.sites={};storage.result={};local r=storage.result
 local sides={{0,-1,defines.direction.north},{1,0,defines.direction.east},{0,1,defines.direction.south},{-1,0,defines.direction.west}}
 for i,v in ipairs(sides)do
  local x=(i-1)*8;local e=s.create_entity{name=ID,position={x,0},force='player',raise_built=true};local tx,ty=v[1]==0 and .5 or 0,v[2]==0 and .5 or 0
  local chest=s.create_entity{name='steel-chest',position={x+v[1]*2.5+tx,v[2]*2.5+ty},force='player'};chest.insert{name='iron-plate',count=4}
  local arm=s.create_entity{name='burner-inserter',position={x+v[1]*1.5+tx,v[2]*1.5+ty},direction=v[3],force='player'};arm.insert{name='coal',count=10};storage.sites[i]={entity=e,chest=chest,arm=arm,direction=v[3]}
 end
 r.inventory_size=#storage.sites[1].entity.get_inventory(defines.inventory.chest)==10;r.recipe_enabled=game.forces.player.recipes[ID].enabled;r.ingredients={}
 for _,v in pairs(prototypes.recipe[ID].ingredients)do r.ingredients[v.name]=v.amount end
 storage.mixed=s.create_entity{name=ID,position={0,6},force='player',raise_built=true};storage.receiver=s.create_entity{name=ID,position={3,6},force='player',raise_built=true};storage.far=s.create_entity{name=ID,position={16,6},force='player',raise_built=true}
 storage.items={['iron-plate']=7,['copper-ore']=9,wood=3,stone=11};r.unfiltered_mixed_storage=true
 for name,count in pairs(storage.items)do r.unfiltered_mixed_storage=storage.mixed.insert{name=name,count=count}==count and r.unfiltered_mixed_storage end
 r.wire_connections={}
 for _,wire in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}do
  local a=storage.mixed.get_wire_connector(wire,true);local b=storage.receiver.get_wire_connector(wire,true);r.wire_connections[#r.wire_connections+1]=a and b and a.connect_to(b)
 end
 r.far_wire_rejected=not storage.receiver.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(storage.far.get_wire_connector(defines.wire_connector_id.circuit_red,true))
 storage.blocked=s.create_entity{name=ID,position={12,6},force='player',raise_built=true};r.blocked_capacity=prototypes.item.stone.stack_size*10;storage.blocked.insert{name='stone',count=r.blocked_capacity}
 storage.block_source=s.create_entity{name='steel-chest',position={12.5,3.5},force='player'};storage.block_source.insert{name='iron-plate',count=4}
 local arm=s.create_entity{name='burner-inserter',position={12.5,4.5},direction=defines.direction.north,force='player'};arm.insert{name='coal',count=10}
 storage.showcase=s.create_entity{name=ID,position={0,14},force='player',raise_built=true};s.create_entity{name='entity-ghost',inner_name=ID,position={3,14},force='player'}
end)
script.on_event(defines.events.on_player_created,function(e)local p=game.get_player(e.player_index);p.set_controller{type=defines.controllers.god};p.teleport({0,10},game.surfaces[1])end)
script.on_event(defines.events.on_tick,function()
 local t=game.tick-storage.start;local r=storage.result
 if t==600 then
  r.inserter_input={};for i,row in ipairs(storage.sites)do r.inserter_input[i]=row.entity.get_item_count('iron-plate')==4;row.arm.direction=(row.direction+8)%16 end
  r.full_inventory_blocks_inserter=storage.blocked.get_item_count('stone')==r.blocked_capacity and storage.blocked.get_item_count('iron-plate')==0;storage.blocked.remove_item{name='stone',count=prototypes.item.stone.stack_size}
 elseif t==1200 then
  r.inserter_output={};for i,row in ipairs(storage.sites)do r.inserter_output[i]=row.entity.get_item_count('iron-plate')==0 and row.chest.get_item_count('iron-plate')==4 end
  r.unblocked_inserter=storage.blocked.get_item_count('iron-plate')==4;r.circuit_signals=true;r.mixed_contents_persist=true
  for name,count in pairs(storage.items)do
   r.mixed_contents_persist=storage.mixed.get_item_count(name)==count and r.mixed_contents_persist
   for _,wire in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}do r.circuit_signals=storage.receiver.get_signal({type='item',name=name},wire)==count and r.circuit_signals end
  end
  local e=game.surfaces[1].create_entity{name=ID,position={24,7},force='player'};e.insert{name='coal',count=13};e.insert{name='wood',count=5};local inv=game.create_inventory(10)
  r.mining_preserves_contents=e.mine{inventory=inv} and inv.get_item_count(ID)==1 and inv.get_item_count('coal')==13 and inv.get_item_count('wood')==5;inv.destroy()
  r.passed=r.inventory_size and r.recipe_enabled and r.unfiltered_mixed_storage and r.full_inventory_blocks_inserter and r.unblocked_inserter and r.circuit_signals and r.mixed_contents_persist and r.mining_preserves_contents and r.far_wire_rejected
  for _,key in ipairs{'inserter_input','inserter_output','wire_connections'}do for _,ok in pairs(r[key])do r.passed=r.passed and ok end end
  write('native-results',r);game.auto_save('item-vault-complete')
 elseif t==1250 and reloaded then
  r.reloaded=true;r.reload_preserved=true
  for name,count in pairs(storage.items)do r.reload_preserved=storage.mixed.get_item_count(name)==count and r.reload_preserved end
  r.reload_preserved=r.reload_preserved and storage.receiver.get_signal({type='item',name='iron-plate'},defines.wire_connector_id.circuit_red)==7;write('reload-results',r)
 end
 local p=game.players[1]
 if p and (t==1300 or t==1330 or t==1360)then
  local mode=t==1300 and 'native-plain.png' or t==1330 and 'native-wired.png' or 'native-ghost.png';local pos=t==1300 and {0,13.7878679656} or t==1330 and {1.5,5.7878679656} or {1.5,13.7878679656}
  game.take_screenshot{player=p,surface=game.surfaces[1],position=pos,resolution={1000,640},zoom=t==1300 and 5 or 3.5,path='item-vault/'..mode,show_gui=false,show_entity_info=false}
 end
end)
