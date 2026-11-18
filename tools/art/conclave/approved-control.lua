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
 s.create_entity{name=ID,position={0,6},force='player',raise_built=true}
 s.create_entity{name='entity-ghost',inner_name=ID,position={4,6},force='player'}
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
 if t==2010 then local surface=game.surfaces[1];surface.always_day=false;surface.daytime=0.5;surface.freeze_daytime=true end
 if t==2070 then local p=game.players[1];if p then game.take_screenshot{player=p,surface=game.surfaces[1],position={0,5.4413856428626275},resolution={640,640},zoom=4,path='conclave-center/native-night.png',show_gui=false,show_entity_info=false} end end
 if t==2090 then game.surfaces[1].always_day=true end
 if t==2120 then local p=game.players[1];if p then game.take_screenshot{player=p,surface=game.surfaces[1],position={2,5.4413856428626275},resolution={1000,640},zoom=3,path='conclave-center/native-ghost.png',show_gui=false,show_entity_info=false} end end
 if t>=1300 and t<=2000 and (t-1300)%20==0 then
  local p=game.players[1]
  if p then game.take_screenshot{player=p,surface=game.surfaces[1],position={0,5.4413856428626275},resolution={640,640},zoom=4,path=string.format('conclave-center/native-motion-%03d.png',(t-1300)/20),show_gui=false,show_entity_info=false,allow_in_replay=true} end
 end
end)
script.on_event(defines.events.on_player_created,function(event)
 local p=game.get_player(event.player_index);p.set_controller{type=defines.controllers.god};p.teleport({0,-3},game.surfaces[1]);p.zoom=2
end)

-- Private test observer: no synthetic GUI events or player.opened assignment.
local ID='tech-priests-conclave-center'
local function output(name,data) helpers.write_file('conclave-center/'..name..'.json',helpers.table_to_json(data),false) end
script.on_event(defines.events.on_gui_opened,function(event)
 if event.entity and event.entity.valid and event.entity.name==ID then
  storage.conclave_physical_input={tick=game.tick,player=event.player_index,entity_unit=event.entity.unit_number,entity_name=event.entity.name,gui_type=event.gui_type}
 end
end)
script.on_event(defines.events.on_gui_click,function(event)
 if event.element and event.element.valid and event.element.name=='tech_priests_conclave_center_open_overview_0558' then
  storage.conclave_overview_input={tick=game.tick,element=event.element.name,player=event.player_index}
 end
end)
script.on_nth_tick(15,function()
 local input=storage.conclave_physical_input
 if not input then return end
 local p=game.get_player(input.player);if not p then return end
 local frame=p.gui.screen.tech_priests_conclave_center_0558
 if frame and frame.valid and not storage.conclave_physical_receipt then
  local names={};for _,child in pairs(frame.children) do names[#names+1]=child.name end
  storage.conclave_physical_receipt={passed=true,physical_open_event=input,conclave_frame=frame.name,child_names=names,tick=game.tick,screen_names={}}
  for _,child in pairs(p.gui.screen.children) do storage.conclave_physical_receipt.screen_names[#storage.conclave_physical_receipt.screen_names+1]=child.name end
  output('physical-governance',storage.conclave_physical_receipt)
  game.take_screenshot{player=p,resolution={p.display_resolution.width,p.display_resolution.height},zoom=1.4,path='conclave-center/physical-governance.png',show_gui=true,show_entity_info=false}
 end
 if storage.conclave_overview_input and not storage.conclave_overview_receipt then
  local overview=p.gui.screen.tech_priests_command_overview_0189
  if overview and overview.valid then
   storage.conclave_overview_receipt={passed=true,input=storage.conclave_overview_input,overview_frame=overview.name,tick=game.tick}
   output('physical-overview',storage.conclave_overview_receipt)
   game.take_screenshot{player=p,resolution={p.display_resolution.width,p.display_resolution.height},zoom=1.4,path='conclave-center/physical-overview.png',show_gui=true,show_entity_info=false}
  end
 end
end)
script.on_nth_tick(17,function()
 local p=game.players[1];if not p then return end
 local frame=p.gui.screen.tech_priests_conclave_center_0558
 if not(frame and frame.valid) then return end
 local tabs=frame.tech_priests_conclave_tabs_0558
 local selected=tabs.selected_tab_index or 1
 local size=tostring(p.display_resolution.width)..'x'..tostring(p.display_resolution.height)
 local key=size..'-'..tostring(p.display_scale)..'-'..selected
 storage.layout_captures=storage.layout_captures or {}
 if storage.layout_captures[key] then return end
 local row={resolution=p.display_resolution,scale=p.display_scale,panel_width=frame.style.maximal_width,panel_height=frame.style.maximal_height,tab=selected,panes={}}
 for _,tab in pairs(tabs.tabs) do
  local pane=tab.content
  row.panes[#row.panes+1]={width=pane.style.maximal_width,height=pane.style.maximal_height,horizontal_scroll_policy=pane.horizontal_scroll_policy,vertical_scroll_policy=pane.vertical_scroll_policy}
 end
 storage.layout_captures[key]=true;output('layout-'..key,row)
 game.take_screenshot{player=p,resolution={p.display_resolution.width,p.display_resolution.height},zoom=1.4,path='conclave-center/layout-'..key..'.png',show_gui=true,show_entity_info=false}
end)
