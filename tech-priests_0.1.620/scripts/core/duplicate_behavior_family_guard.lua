-- scripts/core/duplicate_behavior_family_guard.lua
-- Tech Priests 0.1.428 duplicate behavior family guard / diagnostic map.
--
-- This module does not delete wrapper-chain behavior at runtime. It records the
-- authority map for the dangerous duplicated function families and exposes a
-- diagnostic command. The actual deletion of old bodies must happen in small,
-- tested batches after the owning module has proven stable.

local M = {}
M.version = "0.1.428"

M.families = {
  movement = {
    authority = "scripts/core/movement_controller.lua",
    names = { "return_to_station", "move_priest_to", "issue_priest_command", "tech_priests_0215_direct_command_platform_walk", "tech_priests_platform_path_guard_0209" },
    rule = "ground priest movement must request movement_controller; space/platform exceptions must be explicit"
  },
  lifecycle = {
    authority = "scripts/core/pair_lifecycle.lua + pair_death_and_respawn.lua + pair_spawn_positions.lua + pair_naming.lua",
    names = { "ensure_pair_priest", "respawn_pair_priest", "create_pair", "find_spawn_position", "apply_pair_display_names", "remove_pair_for_entity" },
    rule = "priest death enters re-imprinting; station death owns permanent pair retirement"
  },
  scheduler = {
    authority = "scripts/core/task_scheduler.lua + scripts/core/scheduler_behavior_tree.lua",
    names = { "tick_pair", "handle_emergency_desperation_craft", "tech_priests_service_independent_emergency_operation_0184", "tech_priests_emergency_operation_acquire_item_0185" },
    rule = "scheduler chooses work; executors report done/blocked/failed"
  },
  acquisition = {
    authority = "scripts/core/acquisition_executor.lua + supply_resolver.lua + resource_doctrine.lua",
    names = { "maybe_start_supply_scavenge", "handle_logistic_inventory_scan", "start_logistic_scavenge_inventory_scan", "find_scavenge_source_for_request", "handle_priest_scavenge_task" },
    rule = "acquisition owns gather/search execution but not unrelated task choice"
  },
  gui = {
    authority = "scripts/gui/gui_router.lua",
    names = { "on_selected_entity_changed", "tech_priests_build_command_overview_0189", "tech_priests_0306_open_gui" },
    rule = "GUI handlers route through gui_router; panel bodies move out next"
  },
  consecration = {
    authority = "scripts/core/consecration/*",
    names = { "sanctify_target_with_priest", "find_consecration_target_for_station", "repair_target" },
    rule = "machine-spirit decay, detritus, history, and overlays belong to consecration modules"
  }
}

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.duplicate_behavior_guard_0428 = storage.tech_priests.duplicate_behavior_guard_0428 or {
    version = M.version,
    installed_tick = game and game.tick or 0,
    command_calls = 0
  }
  local root = storage.tech_priests.duplicate_behavior_guard_0428
  root.version = M.version
  return root
end

local function debug_registry()
  if _G.TechPriestsDebugCommandRegistry then return _G.TechPriestsDebugCommandRegistry end
  local ok, mod = pcall(require, "scripts.core.debug.debug_command_registry")
  if ok then return mod end
  return nil
end

local function function_status(name)
  local fn = rawget(_G, name)
  if type(fn) == "function" then return "function" end
  if fn ~= nil then return type(fn) end
  return "nil"
end

function M.print_report(player)
  if not (player and player.valid) then return end
  local root = ensure_root()
  root.command_calls = (root.command_calls or 0) + 1
  player.print("[tp-duplicate-families-0428] Duplicate behavior family authority map. This is a deletion guard, not a gameplay owner.")
  for family, def in pairs(M.families) do
    player.print("  " .. family .. " -> " .. tostring(def.authority))
    local shown = 0
    for _, name in ipairs(def.names or {}) do
      shown = shown + 1
      if shown <= 6 then player.print("    " .. name .. " = " .. function_status(name)) end
    end
    player.print("    rule: " .. tostring(def.rule))
  end
end

function M.install()
  ensure_root()
  _G.TechPriestsDuplicateBehaviorFamilyGuard = M
  local reg = debug_registry()
  if reg and reg.add then
    reg.add("tp-duplicate-families-0428", "Show duplicate behavior family authority map and live global function status.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      M.print_report(player)
    end)
  elseif commands and commands.add_command then
    pcall(function() commands.remove_command("tp-duplicate-families-0428") end)
    commands.add_command("tp-duplicate-families-0428", "Show duplicate behavior family authority map and live global function status.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      M.print_report(player)
    end)
  end
  if log then log("[Tech-Priests 0.1.428] duplicate behavior family guard installed; deletion is staged behind authority map") end
  return true
end

return M
