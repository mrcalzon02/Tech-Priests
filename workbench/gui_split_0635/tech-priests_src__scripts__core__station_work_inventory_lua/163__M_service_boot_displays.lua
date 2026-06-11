-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2722-2752
function M.service_boot_displays()
  local r = root()
  if not (r and r.open_by_player and game and game.players) then return end
  for pindex, rec in pairs(r.open_by_player) do
    local player = game.get_player and game.get_player(tonumber(pindex)) or game.players[tonumber(pindex)]
    if not (player and player.valid and player.gui and player.gui.screen) then
      r.open_by_player[pindex] = nil
    else
      local frame = player.gui.screen[M.gui_name]
      if not (frame and frame.valid) then
        r.open_by_player[pindex] = nil
      else
        local su = rec and rec.station_unit
        local pair = su and pair_map()[tonumber(su)] or su and pair_map()[su] or nil
        if pair and valid_pair(pair) then
          local updated, reason = update_boot_display(player, pair)
          if reason == "complete" then
            M.show_gui(player, pair, current_workstate_tab_index_0541(player) or 1)
          elseif not updated then
            -- Repair once if the boot label went missing, but do not rebuild every tick;
            -- repeated full redraws were causing the boot box to flutter open/closed.
            M.show_gui(player, pair, current_workstate_tab_index_0541(player) or 1)
          end
        else
          r.open_by_player[pindex] = nil
        end
      end
    end
  end
end

