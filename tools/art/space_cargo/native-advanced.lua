local ID='tech-priests-advanced-space-cargo-inventory'
local function write(n,v)helpers.write_file('advanced-cargo/'..n..'.json',helpers.table_to_json(v),false)end
local reloaded=false
script.on_load(function()reloaded=storage.done or false end)
local function rotation_setup(surface)
 storage.rotation_rows={};storage.result.rotations={}
 local sides={{0,-1,defines.direction.north},{1,0,defines.direction.east},{0,1,defines.direction.south},{-1,0,defines.direction.west}}
 for d=0,3 do
  local odd=d%2==1;local w=5;local h=5;local rr={direction=d*4,sites={}};local result={inputs={},outputs={},grid=true,signals=true};storage.result.rotations[d+1]=result
  for side,v in ipairs(sides)do
   local x=70+(side-1)*14+.5;local y=40+d*12+.5
   local e=surface.create_entity{name=ID,position={x,y},direction=d*4,force='player'}
   result.grid=result.grid and e.direction==d*4 and surface.can_place_entity{name=ID,position={x+7,y},direction=d*4,force='player',build_check_type=defines.build_check_type.manual}
   local dx=v[1]*(w/2+.5)+(v[1]==0 and w%2==0 and .5 or 0);local dy=v[2]*(h/2+.5)+(v[2]==0 and h%2==0 and .5 or 0)
   local arm=surface.create_entity{name='inserter',position={x+dx,y+dy},direction=v[3],force='player'};local chest=surface.create_entity{name='steel-chest',position={x+dx+v[1],y+dy+v[2]},force='player'};chest.insert{name='iron-plate',count=4}
   rr.sites[side]={entity=e,arm=arm,chest=chest,direction=v[3]}
  end
  local x=65+d*11+.5;local y=-20+.5
  rr.signal=surface.create_entity{name=ID,position={x,y},direction=d*4,force='player'};rr.signal.insert{name='copper-plate',count=7}
  rr.receiver=surface.create_entity{name='constant-combinator',position={math.floor(x)+4.5,math.floor(y)+4.5},force='player'}
  for _,wire in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}do result.signals=result.signals and rr.signal.get_wire_connector(wire,true).connect_to(rr.receiver.get_wire_connector(wire,true))end
  local bb=rr.signal.bounding_box;result.rotated_bounds=math.abs((bb.right_bottom.x-bb.left_top.x)-4.4)<.01 and math.abs((bb.right_bottom.y-bb.left_top.y)-4.4)<.01
  storage.rotation_rows[d+1]=rr
 end
 local e=surface.create_entity{name=ID,position={125.5,.5},force='player'};e.insert{name='stone',count=13};local ok=true
 storage.result.rotate_steps={}
 for n=1,4 do local previous=e.direction;local rotated=e.rotate();storage.result.rotate_steps[n]={previous=previous,current=e.direction,rotated=rotated,position=e.position,contents=e.get_item_count('stone')};ok=rotated and e.direction==(previous+4)%16 and e.get_item_count('stone')==13 and ok end
 storage.rotation_loaded=e;storage.result.normal_rotate=ok;storage.result.placed_rotation_behavior='Native5x5 square grid: normal placed R rotates through all4quarter-turn facings; inventory preserved.'
end
local function rotation_inputs()
 for d,row in ipairs(storage.rotation_rows)do local r=storage.result.rotations[d];for i,v in ipairs(row.sites)do r.inputs[i]=v.entity.get_item_count('iron-plate')==4;v.arm.direction=(v.direction+8)%16 end end
end
local function rotation_finish()
 local ok=true
 for d,row in ipairs(storage.rotation_rows)do
  local r=storage.result.rotations[d];for i,v in ipairs(row.sites)do r.outputs[i]=v.entity.get_item_count('iron-plate')==0 and v.chest.get_item_count('iron-plate')==4 end
  for _,wire in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}do r.signals=r.signals and row.receiver.get_signal({type='item',name='copper-plate'},wire)==7 end
  r.passed=r.grid and r.rotated_bounds and r.signals
  for _,l in ipairs{r.inputs,r.outputs}do for _,value in ipairs(l)do r.passed=r.passed and value end end;ok=ok and r.passed
 end
 return ok and storage.result.normal_rotate
end
script.on_init(function()
 if remote.interfaces.freeplay then remote.call('freeplay','set_skip_intro',true);remote.call('freeplay','set_disable_crashsite',true)end
 storage.start=game.tick
 storage.platform=game.forces.player.create_space_platform{name='Advanced cargo authored proof',planet='nauvis',starter_pack='space-platform-starter-pack'}
 storage.platform.apply_starter_pack(true)
end)
script.on_event(defines.events.on_player_created,function(ev)local p=game.get_player(ev.player_index);p.set_controller{type=defines.controllers.god}end)
script.on_event(defines.events.on_tick,function()
 local t=game.tick-storage.start
 if t==30 then
  local s=storage.platform.surface;storage.surface=s;local tiles={};for x=-10,150 do for y=-40,90 do tiles[#tiles+1]={name='space-platform-foundation',position={x,y}}end end;s.set_tiles(tiles);s.always_day=true
  local r={genuine_platform=s.platform~=nil,inventory=true,inputs={},outputs={},recipe_initially_disabled=not game.forces.player.recipes[ID].enabled};storage.result=r
  local proto=prototypes.entity[ID];r.tile_width=proto.tile_width;r.tile_height=proto.tile_height
  r.platform_place=s.can_place_entity{name=ID,position={80.5,.5},force='player',build_check_type=defines.build_check_type.manual}
  local ground=game.surfaces.nauvis;ground.request_to_generate_chunks({80,0},1);ground.force_generate_chunk_requests();local gt={};for x=75,85 do for y=-5,5 do gt[#gt+1]={name='refined-concrete',position={x,y}}end end;ground.set_tiles(gt);for _,e in pairs(ground.find_entities_filtered{area={{75,-5},{85,5}},type={'tree','simple-entity','cliff'}})do e.destroy()end
  r.no_foundation_reject=not s.can_place_entity{name=ID,position={160.5,.5},force='player',build_check_type=defines.build_check_type.manual}
  r.nauvis_reject=not game.surfaces.nauvis.can_place_entity{name=ID,position={80.5,.5},force='player',build_check_type=defines.build_check_type.manual}
  game.forces.player.technologies['void-cogitator-stations'].researched=true;r.research_unlock=game.forces.player.recipes[ID].enabled
  local function create(q)q.position={q.position[1]+80,q.position[2]};return s.create_entity(q)end
  storage.sites={};local offsets={{0,-1,defines.direction.north},{1,0,defines.direction.east},{0,1,defines.direction.south},{-1,0,defines.direction.west}}
  for i,v in ipairs(offsets)do
   local x=(i-1)*10+.5;local y=.5;local e=create{name=ID,position={x,y},force='player'};local dx=v[1]*3;local dy=v[2]*3
   local arm=create{name='inserter',position={x+dx,y+dy},direction=v[3],force='player'};local chest=create{name='steel-chest',position={x+dx+v[1],y+dy+v[2]},force='player'};chest.insert{name='iron-plate',count=4}
   storage.sites[i]={entity=e,arm=arm,chest=chest,direction=v[3]};r.inventory=r.inventory and #e.get_inventory(defines.inventory.chest)==50
  end
  -- Private electric source powers ordinary inserters through a normal pole grid.
  for x=-10,40,10 do for y=-10,10,10 do s.create_entity{name='cargo-proof-power',position={x+5,y+5},force='player'};s.create_entity{name='substation',position={x+6,y+6},force='player'}end end
  storage.signal=create{name=ID,position={.5,10.5},force='player'};storage.signal.insert{name='copper-plate',count=7};storage.receiver=create{name='constant-combinator',position={4.5,10.5},force='player'};r.wires={}
  for _,w in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}do r.wires[#r.wires+1]=storage.signal.get_wire_connector(w,true).connect_to(storage.receiver.get_wire_connector(w,true))end
  local far=create{name='constant-combinator',position={20.5,10.5},force='player'};r.far_reject=not storage.signal.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(far.get_wire_connector(defines.wire_connector_id.circuit_red,true))
  storage.blocked=create{name=ID,position={10.5,10.5},force='player'};storage.blocked.insert{name='iron-plate',count=5000};storage.bs=create{name='steel-chest',position={10.5,6.5},force='player'};storage.bs.insert{name='iron-plate',count=4};storage.ba=create{name='inserter',position={10.5,7.5},direction=defines.direction.north,force='player'}
  r.mixed_items=storage.signal.insert{name='stone',count=3}==3;storage.signal.remove_item{name='stone',count=3}
  rotation_setup(s)
  storage.show=create{name=ID,position={.5,-10.5},force='player'}
 elseif t==630 then
  rotation_inputs()
  local r=storage.result;for i,v in ipairs(storage.sites)do r.inputs[i]=v.entity.get_item_count('iron-plate')==4;v.arm.direction=(v.direction+8)%16 end;r.blocked=storage.blocked.get_item_count('iron-plate')==5000;storage.blocked.remove_item{name='iron-plate',count=100}
 elseif t==1230 then
  local r=storage.result;for i,v in ipairs(storage.sites)do r.outputs[i]=v.entity.get_item_count('iron-plate')==0 and v.chest.get_item_count('iron-plate')==4 end;r.recovered=storage.blocked.get_item_count('iron-plate')==4904;r.signals=true
  for _,w in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}do r.signals=r.signals and storage.receiver.get_signal({type='item',name='copper-plate'},w)==7 end
  local e=storage.surface.create_entity{name=ID,position={100.5,20.5},force='player'};e.insert{name='stone',count=13};local inv=game.create_inventory(4);r.mining=e.mine{inventory=inv} and inv.get_item_count(ID)==1 and inv.get_item_count('stone')==13;inv.destroy()
  r.rotations_passed=rotation_finish()
  r.passed=r.rotations_passed and r.mixed_items and r.no_foundation_reject and r.genuine_platform and r.inventory and r.platform_place and r.nauvis_reject and r.recipe_initially_disabled and r.research_unlock and r.far_reject and r.blocked and r.recovered and r.signals and r.mining
  for _,list in ipairs{r.inputs,r.outputs,r.wires}do for _,ok in ipairs(list)do r.passed=r.passed and ok end end
  storage.done=true;write('native-results',r);game.auto_save('advanced-cargo-complete')
 elseif t==1280 and reloaded then
  local ok=storage.result.passed and storage.signal.get_item_count('copper-plate')==7 and storage.blocked.get_item_count('iron-plate')==4904 and storage.rotation_loaded.get_item_count('stone')==13 and storage.rotation_loaded.direction==0
  for d,row in ipairs(storage.rotation_rows)do
   ok=ok and row.signal.direction==(d-1)*4 and row.signal.get_item_count('copper-plate')==7
   for _,wire in ipairs{defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}do ok=ok and row.receiver.get_signal({type='item',name='copper-plate'},wire)==7 end
  end
  write('reload-results',{passed=ok,four_directions_preserved=ok})
 end
 if t==1320 and game.players[1] then
  local p=game.players[1];p.teleport(storage.show.position,storage.surface)
  game.take_screenshot{player=p,surface=storage.surface,position=storage.show.position,resolution={1200,1000},zoom=4,path='advanced-cargo/native-platform.png',show_gui=false,show_entity_info=false}
  for d,row in ipairs(storage.rotation_rows)do game.take_screenshot{player=p,surface=storage.surface,position=row.signal.position,resolution={1000,900},zoom=3,path='advanced-cargo/native-direction-'..((d-1)*4)..'.png',show_gui=false,show_entity_info=false}end
  game.take_screenshot{player=p,surface=storage.surface,position={82,-20},resolution={1500,700},zoom=1,path='advanced-cargo/native-rotations.png',show_gui=false,show_entity_info=false}
  game.take_screenshot{player=p,surface=storage.surface,position={82,10.5},resolution={1200,700},zoom=3,path='advanced-cargo/native-circuits.png',show_gui=false,show_entity_info=false}
 end
end)
