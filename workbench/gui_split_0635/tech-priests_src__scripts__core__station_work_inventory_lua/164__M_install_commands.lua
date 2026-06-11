-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2753-2820
function M.install_commands()
  if not commands then return end
  pcall(function() commands.remove_command("tp-workstate-0358") end)
  commands.add_command("tp-workstate-0358", "Tech Priests 0.1.358 station-bound work state audit/status panel.", function(event)
    local player = event and event.player_index and game.players[event.player_index] or nil
    if not player then return end
    local pair = selected_pair(player)
    if not pair then player.print("[tp-workstate-0358] select a Cogitator Station or Tech-Priest."); return end
    local lines = M.describe_pair(pair)
    for _, line in ipairs(lines) do player.print("[tp-workstate-0358] " .. line) end
    M.show_gui(player, pair)
  end)

  pcall(function() commands.remove_command("tp-bios-boot-speed-0473") end)
  pcall(function()
    commands.add_command("tp-bios-boot-speed-0473", "Tech Priests: report the Cogitator BIOS boot speed setting.", function(event)
      local player = event and event.player_index and game.players[event.player_index] or nil
      if player and player.valid then
        player.print("[tp-bios-boot-speed-0473] speed=" .. tostring(boot_speed_percent()) .. "/100 phase_ticks=" .. tostring(boot_stage_ticks()) .. " hold_ticks=" .. tostring(boot_hold_ticks()))
      end
    end)
  end)

  pcall(function() commands.remove_command("tp-workstate-tabs-0521") end)
  pcall(function()
    commands.add_command("tp-workstate-tabs-0521", "Tech Priests 0.1.522: inspect diegetic-polished Work-State Reliquary tab captions and structured slate data.", function(event)
      local player = event and event.player_index and game.players[event.player_index] or nil
      if not (player and player.valid) then return end
      local pair = selected_pair(player)
      if not pair then player.print("[tp-workstate-tabs-0521] select a Cogitator Station or Tech-Priest."); return end
      local q = pair.order_queue_0469 or {}
      local pq = pair.magos_planning_queue_0471 or {}
      local H = rawget(_G, "TECH_PRIESTS_COMMAND_HIERARCHY_0480")
      local h = H and H.hierarchy and H.hierarchy(pair) or nil
      player.print("[tp-workstate-tabs-0521] station=" .. station_label(pair) .. " rank=" .. tostring(station_rank(pair)))
      player.print("[tp-workstate-tabs-0521] writ-current=" .. tostring(q.current and (q.current.key or q.current.id) or "none") .. " pending=" .. tostring(#(q.pending or {})) .. " history=" .. tostring(#(q.history or {})))
      player.print("[tp-workstate-tabs-0521] forge-current=" .. tostring(pq.current and (pq.current.key or pq.current.id) or pair.magos_current_plan_0471 and pair.magos_current_plan_0471.key or "none") .. " pending=" .. tostring(#(pq.pending or {})) .. " history=" .. tostring(#(pq.history or {})))
      player.print("[tp-workstate-tabs-0521] command-direct=" .. tostring(h and #(h.direct_subordinate_units or {}) or 0) .. "/" .. tostring(h and h.direct_limit or 0) .. " peer=" .. tostring(h and #(h.peer_units or {}) or 0) .. "/" .. tostring(h and h.peer_limit or 0))
      M.show_gui(player, pair, 6)
    end)
  end)


  pcall(function() commands.remove_command("tp-ui-logistics-polish-0526") end)
  pcall(function()
    commands.add_command("tp-ui-logistics-polish-0526", "Tech Priests 0.1.526: open selected Work-State Reliquary to inspect wrapped Identity, structured Auspex, and Doctrine Web polish.", function(event)
      local player = event and event.player_index and game.players[event.player_index] or nil
      if not (player and player.valid) then return end
      local pair = selected_pair(player)
      if not pair then player.print("[tp-ui-logistics-polish-0526] select a Cogitator Station or Tech-Priest."); return end
      player.print("[tp-ui-logistics-polish-0526] opening UI-polished Work-State Reliquary for " .. station_label(pair))
      M.show_gui(player, pair, 1)
    end)
  end)

  pcall(function() commands.remove_command("tp-workstate-polish-0522") end)
  pcall(function()
    commands.add_command("tp-workstate-polish-0522", "Tech Priests 0.1.522: open selected Cogitator Work-State Reliquary and inspect polished slate captions.", function(event)
      local player = event and event.player_index and game.players[event.player_index] or nil
      if not (player and player.valid) then return end
      local pair = selected_pair(player)
      if not pair then player.print("[tp-workstate-polish-0522] select a Cogitator Station or Tech-Priest."); return end
      player.print("[tp-workstate-polish-0522] opening polished Work-State Reliquary for " .. station_label(pair))
      M.show_gui(player, pair, 1)
    end)
  end)
end

