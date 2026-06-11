-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2491-2596
function M.show_gui(player, pair, selected_tab_index)
  if not (player and player.valid and valid_pair(pair)) then return end
  clear_gui(player)
  local panel_w, panel_h, panel_top, tabs_h, scroll_h = panel_dimensions(player)
  local frame = player.gui.screen.add({ type = "frame", name = M.gui_name, direction = "vertical", caption = "Cogitator Work-State Reliquary" })
  apply_gui_style_0532(frame, "tech_priests_cogitator_outer_frame_0532")
  frame.auto_center = false
  frame.location = { x = panel_location_x_0536(player, panel_w), y = panel_top }
  frame.style.minimal_width = panel_w
  frame.style.maximal_width = panel_w
  frame.style.minimal_height = panel_h
  frame.style.maximal_height = panel_h
  frame.tags = { station_unit = unit(pair), gui_shell = "diegetic-0482" }
  remember_recent_pair_for_player_0461(player, pair, "workstate-show")

  local shell = frame.add({ type = "flow", name = "tech_priests_workstate_diegetic_shell_0482", direction = "vertical" })
  shell.style.horizontally_stretchable = true
  shell.style.vertically_stretchable = true
  local body, content_w_0536, content_h_0536 = add_diegetic_workstate_body_0482(shell, panel_w, panel_h)
  local content_w_for_scroll_0536 = tonumber(content_w_0536) or (panel_w - 116)
  if content_h_0536 then
    tabs_h = math.max(430, math.floor(content_h_0536 - 54))
    scroll_h = math.max(340, tabs_h - 58)
  end
  add_diegetic_workstate_controls_0482(body, pair)

  local tabs = body.add({ type = "tabbed-pane", name = "tech_priests_workstate_tabs_0410" })
  apply_gui_style_0532(tabs, "tech_priests_cogitator_tabbed_pane_0532")
  tabs.style.vertically_stretchable = true
  tabs.style.horizontally_stretchable = true
  tabs.style.height = tabs_h

  local work_tab = tabs.add({ type = "tab", caption = "Boot Rite" })
  apply_gui_style_0532(work_tab, "tech_priests_cogitator_tab_0541")
  local work_page = tabs.add({ type = "flow", direction = "vertical" })
  work_page.style.vertically_stretchable = true
  work_page.style.horizontally_stretchable = true
  tabs.add_tab(work_tab, work_page)

  local resources_tab = tabs.add({ type = "tab", caption = "Auspex Ledger" })
  apply_gui_style_0532(resources_tab, "tech_priests_cogitator_tab_0541")
  local resources_page = tabs.add({ type = "flow", direction = "vertical" })
  resources_page.style.vertically_stretchable = true
  resources_page.style.horizontally_stretchable = true
  tabs.add_tab(resources_tab, resources_page)

  local doctrine_tab = tabs.add({ type = "tab", caption = "Doctrine Web" })
  apply_gui_style_0532(doctrine_tab, "tech_priests_cogitator_tab_0541")
  local doctrine_page = tabs.add({ type = "flow", direction = "vertical" })
  doctrine_page.style.vertically_stretchable = true
  doctrine_page.style.horizontally_stretchable = true
  tabs.add_tab(doctrine_tab, doctrine_page)

  local hierarchy_tab = tabs.add({ type = "tab", caption = "Command Lattice" })
  apply_gui_style_0532(hierarchy_tab, "tech_priests_cogitator_tab_0541")
  local hierarchy_page = tabs.add({ type = "flow", direction = "vertical" })
  hierarchy_page.style.vertically_stretchable = true
  hierarchy_page.style.horizontally_stretchable = true
  tabs.add_tab(hierarchy_tab, hierarchy_page)

  local conversations_tab = tabs.add({ type = "tab", caption = "Vox Reliquary" })
  apply_gui_style_0532(conversations_tab, "tech_priests_cogitator_tab_0541")
  local conversations_page = tabs.add({ type = "flow", direction = "vertical" })
  conversations_page.style.vertically_stretchable = true
  conversations_page.style.horizontally_stretchable = true
  tabs.add_tab(conversations_tab, conversations_page)

  local orders_tab = tabs.add({ type = "tab", caption = "Writ Reliquary" })
  apply_gui_style_0532(orders_tab, "tech_priests_cogitator_tab_0541")
  local orders_page = tabs.add({ type = "flow", direction = "vertical" })
  orders_page.style.vertically_stretchable = true
  orders_page.style.horizontally_stretchable = true
  tabs.add_tab(orders_tab, orders_page)

  local construction_tab = tabs.add({ type = "tab", caption = "Forge Slate" })
  apply_gui_style_0532(construction_tab, "tech_priests_cogitator_tab_0541")
  local construction_page = tabs.add({ type = "flow", direction = "vertical" })
  construction_page.style.vertically_stretchable = true
  construction_page.style.horizontally_stretchable = true
  tabs.add_tab(construction_tab, construction_page)

  local scroll = add_inner_screen_page_0565(work_page, "tech_priests_workstate_scroll_0358", scroll_h, math.max(560, content_w_for_scroll_0536 - 26))

  local resource_scroll = add_inner_screen_page_0565(resources_page, "tech_priests_workstate_known_resources_scroll_0410", scroll_h, math.max(560, content_w_for_scroll_0536 - 26))

  local doctrine_scroll = add_inner_screen_page_0565(doctrine_page, "tech_priests_workstate_doctrine_relations_scroll_0414", scroll_h, math.max(560, content_w_for_scroll_0536 - 26))

  local hierarchy_scroll = add_inner_screen_page_0565(hierarchy_page, "tech_priests_workstate_command_tree_scroll_0480", scroll_h, math.max(560, content_w_for_scroll_0536 - 26))

  local conversations_scroll = add_inner_screen_page_0565(conversations_page, "tech_priests_workstate_conversations_scroll_0478", scroll_h, math.max(560, content_w_for_scroll_0536 - 26))

  local orders_scroll = add_inner_screen_page_0565(orders_page, "tech_priests_workstate_orders_scroll_0478", scroll_h, math.max(560, content_w_for_scroll_0536 - 26))

  local construction_scroll = add_inner_screen_page_0565(construction_page, "tech_priests_workstate_construction_scroll_0478", scroll_h, math.max(560, content_w_for_scroll_0536 - 26))

  add_workstate_display(scroll, player, pair)
  add_known_resources_display(resource_scroll, pair)
  add_doctrine_relationship_web_0414(doctrine_scroll, pair)
  add_subordinate_command_tree_display(hierarchy_scroll, pair)
  add_conversations_display(conversations_scroll, pair)
  add_orders_display(orders_scroll, pair)
  add_construction_planning_display(construction_scroll, pair)

  pcall(function() tabs.selected_tab_index = math.max(1, math.min(7, tonumber(selected_tab_index) or 1)) end)
end

