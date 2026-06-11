-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 292-301
local function destroy_frame(player)
  if player and player.valid and player.gui and player.gui.screen then
    local frame = player.gui.screen[FRAME_NAME]
    if frame and frame.valid then frame.destroy() end
  end
  if storage and storage.tech_priests and storage.tech_priests.consecration_history_gui_0422 then
    storage.tech_priests.consecration_history_gui_0422.open[player.index] = nil
  end
end

