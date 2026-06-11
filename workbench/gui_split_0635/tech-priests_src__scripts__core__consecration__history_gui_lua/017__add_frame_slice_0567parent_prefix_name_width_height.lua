-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 191-194
local function add_frame_slice_0567(parent, prefix, name, width, height)
  return add_gui_sprite_0567(parent, gui_frame_sprite_0567(prefix, name), math.max(1, math.floor(width or 1)), math.max(1, math.floor(height or 1)))
end

