-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2679-2721
local function update_boot_display(player, pair)
  if not (player and player.valid and valid_pair(pair)) then return false end
  local stage, total, elapsed = boot_stage(player, pair)
  if not stage then return false end
  local frame = player.gui and player.gui.screen and player.gui.screen[M.gui_name] or nil
  if not (frame and frame.valid) then return false end
  local boot_label = nil
  local function find_child_by_name(element, wanted)
    if not (element and element.valid) then return nil end
    local ok_name, name = pcall(function() return element.name end)
    if ok_name and name == wanted then return element end
    local ok_children, children = pcall(function() return element.children end)
    if ok_children and children then
      for _, child in pairs(children) do
        local found = find_child_by_name(child, wanted)
        if found then return found end
      end
    end
    return nil
  end
  pcall(function() boot_label = find_child_by_name(frame, "tech_priests_dictator_boot_text_0364") end)
  if not (boot_label and boot_label.valid) then return false end
  local lines = boot_lines_for(pair, player, stage, elapsed)
  boot_label.caption = table.concat(lines, "\n")
  local spinner = nil
  pcall(function() spinner = find_child_by_name(frame, "tech_priests_dictator_boot_spinner_0526") end)
  if spinner and spinner.valid then pcall(function() spinner.sprite = boot_spinner_sprite_0526(elapsed) end) end
  local phase_label = nil
  pcall(function() phase_label = find_child_by_name(frame, "tech_priests_dictator_boot_spinner_phase_0526") end)
  if phase_label and phase_label.valid then phase_label.caption = dictator_green("rite phase " .. tostring(stage) .. "/" .. tostring(total)) end
  pcall(function()
    local boot_scroll = boot_label.parent
    if boot_scroll and boot_scroll.valid and boot_scroll.scroll_to_top then boot_scroll.scroll_to_top() end
  end)
  play_boot_sound(player, pair, stage)
  if stage >= total and elapsed >= (total * boot_stage_ticks() + boot_hold_ticks()) then
    mark_boot_seen(pair, player)
    clear_active_boot(player)
    return false, "complete"
  end
  return true
end

