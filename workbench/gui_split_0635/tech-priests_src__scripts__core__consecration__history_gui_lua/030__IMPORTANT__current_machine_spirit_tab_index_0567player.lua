-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 460-481
local function current_machine_spirit_tab_index_0567(player)
  local frame = player and player.valid and player.gui and player.gui.screen and player.gui.screen[FRAME_NAME] or nil
  if not (frame and frame.valid) then return nil end
  local function find_tabs(element)
    if not (element and element.valid) then return nil end
    local ok_name, name = pcall(function() return element.name end)
    if ok_name and name == "tech_priests_machine_spirit_tabs_0526" then return element end
    local ok_children, children = pcall(function() return element.children end)
    if ok_children and children then
      for _, child in pairs(children) do
        local found = find_tabs(child)
        if found then return found end
      end
    end
    return nil
  end
  local tabs = find_tabs(frame)
  local idx = nil
  if tabs and tabs.valid then pcall(function() idx = tabs.selected_tab_index end) end
  return tonumber(idx)
end

