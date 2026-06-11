-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 482-568
function M.open_for_player(player, entity)
  local root = ensure_root()
  root.stats.open_attempts = (root.stats.open_attempts or 0) + 1
  root.stats.last_open_attempt_tick = game and game.tick or 0
  root.stats.last_open_attempt_entity = entity and entity.valid and entity.name or tostring(entity)
  if not (player and player.valid and entity and entity.valid) then
    root.stats.open_invalid_context = (root.stats.open_invalid_context or 0) + 1
    return false
  end
  local record = get_record(entity)
  if not record then
    root.stats.open_no_record = (root.stats.open_no_record or 0) + 1
    root.stats.last_no_record_entity = entity.name
    return false
  end
  local previous_location = nil
  local previous_tab_index = current_machine_spirit_tab_index_0567(player)
  local previous = player.gui.screen and player.gui.screen[FRAME_NAME] or nil
  if previous and previous.valid then
    pcall(function() previous_location = previous.location end)
  end
  destroy_frame(player)

  local frame = player.gui.screen.add{ type = "frame", name = FRAME_NAME, direction = "vertical", caption = "Machine-Spirit State Ledger :: " .. machine_spirit_header_text_0526(record, entity) }
  apply_style_0564(frame, "tech_priests_cogitator_outer_frame_0532")
  local ledger_panel_w = 940
  local ledger_panel_h = 900
  pcall(function() frame.style.minimal_width = ledger_panel_w end)
  pcall(function() frame.style.maximal_width = ledger_panel_w end)
  pcall(function() frame.style.minimal_height = ledger_panel_h end)
  pcall(function() frame.style.maximal_height = ledger_panel_h end)
  if previous_location then
    pcall(function() frame.location = previous_location end)
  else
    pcall(function() frame.auto_center = false end)
    pcall(function() frame.location = choose_ledger_location(player, entity) end)
  end

  local shell_body, shell_content_w, shell_content_h = add_machine_spirit_sliced_shell_0567(frame, ledger_panel_w, ledger_panel_h)
  local ledger_parent = shell_body or frame

  local header = ledger_parent.add{ type = "flow", direction = "horizontal" }
  header.add{ type = "label", caption = machine_spirit_header_text_0526(record, entity) .. " // " .. tostring(machine_display_name(entity)) }
  header.add{ type = "empty-widget" }.style.horizontally_stretchable = true
  local refresh_button = header.add{ type = "button", name = REFRESH_NAME, caption = "Recast Machine Auspex" }
  apply_style_0564(refresh_button, "tech_priests_cogitator_button_0532")
  local close_button = header.add{ type = "button", name = CLOSE_NAME, caption = "Seal Reliquary" }
  apply_style_0564(close_button, "tech_priests_cogitator_button_0532")

  local screen_body = ledger_parent.add{ type = "frame", name = "tech_priests_machine_spirit_inner_screen_0565", direction = "vertical" }
  set_display_frame_style_0565(screen_body)
  pcall(function() screen_body.style.minimal_width = math.max(680, (shell_content_w or 760) - 22) end)
  pcall(function() screen_body.style.maximal_width = math.max(680, (shell_content_w or 760) - 22) end)
  pcall(function() screen_body.style.minimal_height = math.max(620, (shell_content_h or 720) - 72) end)
  local tabs = screen_body.add{ type = "tabbed-pane", name = "tech_priests_machine_spirit_tabs_0526" }
  apply_style_0564(tabs, "tech_priests_cogitator_tabbed_pane_0532")
  local summary_tab = tabs.add{ type = "tab", caption = "Spirit Seal" }
  apply_style_0564(summary_tab, "tech_priests_cogitator_tab_0541")
  local summary_page = tabs.add{ type = "scroll-pane", name = "tech_priests_machine_spirit_summary_scroll_0526", direction = "vertical" }
  set_scroll_style_0564(summary_page)
  pcall(function() summary_page.style.maximal_height = 640 end)
  tabs.add_tab(summary_tab, summary_page)
  add_summary(summary_page, record)

  local marks_tab = tabs.add{ type = "tab", caption = "Traits / Flaws" }
  apply_style_0564(marks_tab, "tech_priests_cogitator_tab_0541")
  local marks_page = tabs.add{ type = "scroll-pane", name = "tech_priests_machine_spirit_marks_scroll_0526", direction = "vertical" }
  set_scroll_style_0564(marks_page)
  pcall(function() marks_page.style.maximal_height = 680 end)
  tabs.add_tab(marks_tab, marks_page)
  add_machine_spirit_ledger(marks_page, record)

  local history_tab = tabs.add{ type = "tab", caption = "Rite History" }
  apply_style_0564(history_tab, "tech_priests_cogitator_tab_0541")
  local history_page = tabs.add{ type = "flow", name = "tech_priests_machine_spirit_history_page_0526", direction = "vertical" }
  pcall(function() history_page.style.horizontally_stretchable = true end)
  pcall(function() history_page.style.vertically_stretchable = true end)
  tabs.add_tab(history_tab, history_page)
  add_history(history_page, record)

  pcall(function() tabs.selected_tab_index = math.max(1, math.min(3, tonumber(previous_tab_index) or tonumber((root.open[player.index] or {}).tab_index) or 1)) end)
  root.open[player.index] = { unit = entity.unit_number, tick = game and game.tick or 0, tab_index = current_machine_spirit_tab_index_0567(player) or previous_tab_index or 1 }
  root.stats.open_success = (root.stats.open_success or 0) + 1
  root.stats.last_open_success_machine = tech_priests_0446_format_machine_id and tech_priests_0446_format_machine_id(record) or tostring(record.unit_number)
  return true
end

