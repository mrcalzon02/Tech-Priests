-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1424-1434
local function clear_gui(player)
  if player and player.valid and player.gui and player.gui.screen and player.gui.screen[M.gui_name] then player.gui.screen[M.gui_name].destroy() end
end

add_label = function(parent, caption, style)
  local label = parent.add({ type = "label", caption = dictator_green(caption) })
  style_terminal_label(label, M.label_wrap_width)
  if style and type(style) == "string" then pcall(function() label.style = style end) end
  return label
end

