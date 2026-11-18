-- Isolated validation addon. Never shipped in the Tech-Priests mod.
local ID='tech-priests-conclave-center'
local restored_completed_save=false
script.on_load(function() restored_completed_save=storage.checks and storage.checks.passed==true or false end)
local function write(name,data) helpers.write_file('conclave-center/'..name..'.json',helpers.table_to_json(data),false) end
script.on_init(function()
 if remote.interfaces.freeplay then
  remote.call('freeplay','set_skip_intro',true)
  remote.call('freeplay','set_disable_crashsite',true)
 end
 storage.sites={};storage.checks={};storage.base_tick=game.tick
 local s=game.surfaces[1];s.request_to_generate_chunks({0,0},2);s.force_generate_chunk_requests();s.always_day=true
 local tiles={};for x=-8,44 do for y=-8,8 do tiles[#tiles+1]={name='refined-concrete',position={x,y}} end end;s.set_tiles(tiles)
 for _,e in pairs(s.find_entities_filtered{area={{-8,-8},{44,8}},type={'tree','simple-entity','cliff'}}) do e.destroy() end
 local sides={{0,-1,defines.direction.north},{1,0,defines.direction.east},{0,1,defines.direction.south},{-1,0,defines.direction.west}}
 for i,v in ipairs(sides) do
  local p={x=(i-1)*10,y=0};local e=s.create_entity{name=ID,position=p,force='player',raise_built=true}
  local tang=(v[1]==0) and {x=.5,y=0} or {x=0,y=.5}
  local ip={x=p.x+v[1]*1.5+tang.x,y=p.y+v[2]*1.5+tang.y}
  local cp={x=p.x+v[1]*2.5+tang.x,y=p.y+v[2]*2.5+tang.y}
  local c=s.create_entity{name='steel-chest',position=cp,force='player'};c.insert{name='iron-plate',count=4}
  local arm=s.create_entity{name='burner-inserter',position=ip,direction=v[3],force='player'};arm.insert{name='coal',count=10}
  storage.sites[i]={entity=e,source=c,inserter=arm,original_direction=v[3],position=p}
 end
 local e=storage.sites[1].entity
 local inv=e.get_inventory(defines.inventory.chest)
 storage.checks.inventory_size=#inv==1
 storage.checks.start_recipe=game.forces.player.recipes[ID].enabled
 storage.checks.recipe_ingredients={};for _,v in pairs(prototypes.recipe[ID].ingredients) do storage.checks.recipe_ingredients[v.name]=v.amount end
 storage.checks.no_fluids=not pcall(function() return e.fluidbox end)
 storage.checks.bounds={collision=prototypes.entity[ID].collision_box,selection=prototypes.entity[ID].selection_box}
 local p=game.players[1]
 if p then p.set_controller{type=defines.controllers.god};p.teleport({0,-3},s);storage.review_player=p.index end
end)
local function check_gui()
 local p=game.players[1];local e=storage.sites[1].entity
 if p then
  storage.review_player=p.index
  -- Assign the real native GUI; on_gui_opened cannot be manually raised.
  -- Physical input opens the console in the graphical client; do not synthesize it.
  storage.checks.governance_gui= p.gui.screen.tech_priests_conclave_center_0558~=nil
  if p.gui.screen.tech_priests_conclave_center_0558 then
   local f=p.gui.screen.tech_priests_conclave_center_0558
   local function find(e,name) if e.name==name then return e end;for _,c in pairs(e.children) do local v=find(c,name);if v then return v end end end
   local status=find(f,'tech_priests_conclave_status_0559')
   storage.checks.governance_anchor_caption=status and status.caption or nil
   storage.checks.center_registered=status and string.find((type(status.caption)=='table' and helpers.table_to_json(status.caption) or tostring(status.caption)),'ANCHORS: 4',1,true)~=nil or false
   storage.checks.gui_present_during_automation=true
  end
 end
end
script.on_event(defines.events.on_tick,function()
 local t=game.tick-storage.base_tick
 if t%30==0 and game.players[1] then check_gui();if storage.checks.governance_gui then write('graphical-governance',storage.checks) end end
 if t==600 then
  storage.checks.inserter_input={}
  for i,row in ipairs(storage.sites) do
   storage.checks.inserter_input[i]=row.entity.get_item_count('iron-plate')==4
   row.inserter.direction=(row.original_direction+8)%16
  end
  check_gui()
 elseif t==1200 then
  storage.checks.inserter_output={}
  for i,row in ipairs(storage.sites) do storage.checks.inserter_output[i]=row.entity.get_item_count('iron-plate')==0 and row.source.get_item_count('iron-plate')==4 end
  storage.checks.passed=storage.checks.inventory_size and storage.checks.start_recipe and storage.checks.no_fluids
  for _,key in ipairs{'inserter_input','inserter_output'} do for _,ok in pairs(storage.checks[key]) do storage.checks.passed=storage.checks.passed and ok end end
  storage.completed_at_tick=game.tick
  write('native-results',storage.checks);game.auto_save('conclave-complete')
 elseif t==1250 then
  if restored_completed_save then
   storage.checks.reloaded=true;storage.checks.reload_inventory_preserved=true
   for _,row in ipairs(storage.sites) do storage.checks.reload_inventory_preserved=storage.checks.reload_inventory_preserved and row.entity.valid and row.entity.get_item_count('iron-plate')==0 and row.source.get_item_count('iron-plate')==4 end
   write('reload-results',storage.checks)
  end
 end
 -- Real graphical-client screenshots from the exact integrated mod.
 if t==1300 or t==1330 then
  check_gui();write('graphical-governance',storage.checks)
  local p=game.players[1];p.set_controller{type=defines.controllers.god};p.teleport({0,-3},game.surfaces[1])
  p.opened=nil
  game.take_screenshot{player=p,surface=game.surfaces[1],position={0,0},resolution={1000,800},zoom=t==1300 and 3 or 1.25,path='conclave-center/'..(t==1300 and 'native-close.png' or 'native-gameplay.png'),show_gui=false,show_entity_info=false,allow_in_replay=true}
 end
 if t>=1300 and t<=2000 and (t-1300)%20==0 then
  local p=game.players[1]
  if p then game.take_screenshot{player=p,surface=game.surfaces[1],position={0,-0.5586143571373725},resolution={640,640},zoom=4,path=string.format('conclave-center/native-motion-%03d.png',(t-1300)/20),show_gui=false,show_entity_info=false,allow_in_replay=true} end
 end
end)
script.on_event(defines.events.on_player_created,function(event)
 local p=game.get_player(event.player_index);p.set_controller{type=defines.controllers.god};p.teleport({0,-3},game.surfaces[1]);p.zoom=2
end)
