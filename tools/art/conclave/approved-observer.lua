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
