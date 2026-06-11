-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2257-2260
local function add_frame_slice_0536(parent, name, width, height, tooltip)
  return add_gui_sprite_0482(parent, gui_frame_sprite_0536(name), math.max(1, math.floor(width or 1)), math.max(1, math.floor(height or 1)), tooltip)
end

