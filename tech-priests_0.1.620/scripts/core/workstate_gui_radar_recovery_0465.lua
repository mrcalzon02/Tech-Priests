-- scripts/core/workstate_gui_radar_recovery_0465.lua
-- Late recovery pass for 0.1.465.
--
-- 0.1.463/0.1.464 correctly chased the flashing-radius symptom but exposed two
-- different ownership problems:
--   * Work State / BIOS boot can disappear when late raw GUI handlers replace
--     the GUI router dispatcher.
--   * The radar-splash and RADARSweeper art were scoped out with the bad
--     full-radius station-light effect.
--
-- This module deliberately loads at the very end from control.lua and becomes a
-- small final GUI owner. It calls the router first, then explicitly calls the
-- Work State handlers so the Cogitator console and boot sequence survive even if
-- an older raw script.on_event path stole the dispatcher.

local M = {}
M.version = "0.1.465"

local function safe_require(name)
  local ok, result = pcall(require, name)
  if ok then return result end
  if log then log("[Tech-Priests 0.1.465 recovery] require failed " .. tostring(name) .. ": " .. tostring(result)) end
  return nil
end

local function call(fn, event)
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, event)
  if not ok and log then log("[Tech-Priests 0.1.465 recovery] handler failed: " .. tostring(result)) end
  return ok and result or nil
end

local function selected_pair(player)
  if not (player and player.valid) then return nil end
  local selected = player.selected
  if selected and selected.valid and _G.find_pair_for_entity then
    local ok, pair = pcall(_G.find_pair_for_entity, selected)
    if ok and pair then return pair end
  end
  local root = storage and storage.tech_priests or nil
  if selected and selected.valid and root then
    if root.pairs_by_station and root.pairs_by_station[selected.unit_number] then return root.pairs_by_station[selected.unit_number] end
    if root.pairs_by_priest and root.pairs_by_priest[selected.unit_number] then return root.pairs_by_priest[selected.unit_number] end
  end
  return nil
end

local function open_workstate_for_selected(event)
  local player = event and event.player_index and game and game.get_player and game.get_player(event.player_index) or nil
  if not (player and player.valid) then return end
  local Work = safe_require("scripts.core.station_work_inventory")
  local pair = selected_pair(player)
  if pair and Work and Work.show_gui then Work.show_gui(player, pair) end
end

function M.install()
  local Router = safe_require("scripts.gui.gui_router")
  local Work = safe_require("scripts.core.station_work_inventory")
  local Afterglow = safe_require("scripts.core.radar_afterglow")
  local R = safe_require("scripts.core.runtime_event_registry")

  if Afterglow and Afterglow.install then call(Afterglow.install) end

  if commands and commands.add_command then
    pcall(function() commands.remove_command("tp-workstate-gui-0465") end)
    pcall(function()
      commands.add_command("tp-workstate-gui-0465", "Tech Priests 0.1.465: force-open selected Cogitator Work State GUI.", open_workstate_for_selected)
    end)
  end

  if script and defines and defines.events and script.on_event then
    script.on_event(defines.events.on_gui_opened, function(event)
      if Router and Router.dispatch_opened then call(Router.dispatch_opened, event) end
      if Work and Work.handle_gui_opened then call(Work.handle_gui_opened, event) end
    end)
    script.on_event(defines.events.on_gui_closed, function(event)
      if Router and Router.dispatch_closed then call(Router.dispatch_closed, event) end
      if Work and Work.handle_gui_closed then call(Work.handle_gui_closed, event) end
    end)
    script.on_event(defines.events.on_gui_click, function(event)
      if Router and Router.dispatch_click then call(Router.dispatch_click, event) end
      if Work and Work.handle_gui_click then call(Work.handle_gui_click, event) end
    end)
  end

  -- 0.1.507: Work State owns GUI refresh only. Direct acquisition pulsing now
  -- belongs exclusively to acquisition_executor.lua through the runtime registry;
  -- the former Exec.pulse call here was a duplicate behavior owner.
  local function service_workstate_only()
    if Work and Work.service_boot_displays then call(Work.service_boot_displays) end
  end
  if R and type(R.on_nth_tick) == "function" then
    R.on_nth_tick(30, service_workstate_only, { owner = "workstate_gui_radar_recovery_0465", category = "gui", note = "GUI boot display service only; acquisition executor is separate", priority = "late" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(30, service_workstate_only)
  end

  if log then log("[Tech-Priests 0.1.507] Work State GUI/BIOS recovery owner installed without acquisition duplicate pulse") end
  return true
end

return M
