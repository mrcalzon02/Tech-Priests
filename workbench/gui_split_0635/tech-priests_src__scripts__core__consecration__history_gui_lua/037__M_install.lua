-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 627-676
function M.install()
  ensure_root()
  local gui_bus = nil
  pcall(function() gui_bus = require("scripts.core.gui_bus") end)
  if gui_bus and gui_bus.register then
    gui_bus.register("opened", M.handle_gui_opened)
    gui_bus.register("closed", M.handle_gui_closed)
    gui_bus.register("click", M.handle_gui_click)
  elseif script and defines and defines.events and script.on_event then
    script.on_event(defines.events.on_gui_opened, M.handle_gui_opened)
    script.on_event(defines.events.on_gui_closed, M.handle_gui_closed)
    script.on_event(defines.events.on_gui_click, M.handle_gui_click)
  end
  -- 0.1.453: also register through the runtime event registry when available.
  -- This gives the machine history panel a second stable hook after the control.lua split.
  if TechPriestsRuntimeEventRegistry and TechPriestsRuntimeEventRegistry.on_event and defines and defines.events then
    pcall(function() TechPriestsRuntimeEventRegistry.on_event(defines.events.on_gui_opened, M.handle_gui_opened, nil, { owner = "consecration-history-gui", category = "gui" }) end)
    pcall(function() TechPriestsRuntimeEventRegistry.on_event(defines.events.on_gui_closed, M.handle_gui_closed, nil, { owner = "consecration-history-gui", category = "gui" }) end)
    pcall(function() TechPriestsRuntimeEventRegistry.on_event(defines.events.on_gui_click, M.handle_gui_click, nil, { owner = "consecration-history-gui", category = "gui" }) end)
  end

  if script and script.on_nth_tick then
    script.on_nth_tick(121, function() M.refresh_all_open() end)
  end

  if commands and commands.add_command then
    pcall(function() commands.remove_command("tp-consecration-history-0422") end)
    commands.add_command("tp-consecration-history-0422", "Tech Priests: open the Machine-Spirit State Ledger for the selected machine.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      if M.open_for_player(player, player.selected) then return end
      player.print("[tp-consecration-history-0422] Select a machine known to the Cult Mechanicus ledger.")
    end)

    pcall(function() commands.remove_command("tp-consecration-history-0453") end)
    commands.add_command("tp-consecration-history-0453", "Tech Priests: open the Machine-Spirit State Ledger and rite trace for the selected machine.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      local entity = player.selected
      if M.open_for_player(player, entity) then return end
      local root = ensure_root()
      local stats = root.stats or {}
      player.print("[tp-consecration-history-0453] The ledger found no awakened machine-spirit record. attempts=" .. tostring(stats.open_attempts or 0) .. " consecrated=" .. tostring(stats.open_success or 0) .. " unrecorded=" .. tostring(stats.open_no_record or 0) .. " last=" .. tostring(stats.last_open_attempt_entity or "nil"))
    end)
  end

  if log then log("[Tech-Priests 0.1.526] Machine-Spirit State Ledger GUI installed with named header and diegetic tabbed ledger") end
  return true
end

