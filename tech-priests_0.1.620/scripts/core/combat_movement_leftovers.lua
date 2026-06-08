-- scripts/core/combat_movement_leftovers.lua
-- Tech Priests 0.1.429 combat/movement leftover audit and runtime diagnostics.
--
-- This module does not take movement authority.  It reports the remaining
-- command/teleport touchpoints and confirms that ground-priest go/attack/stop
-- intents have the 0.1.429 routing helper available.

local M = {}
M.version = "0.1.429"

local SUMMARY = {
  version = M.version,
  doctrine = "Ground-priest go/attack/stop commands must route through scripts.core.movement_controller. Space-platform hover/tether and hidden proxy teleports are documented exceptions.",
  allowed = {
    "scripts/core/movement_controller.lua owns direct ground go/stop command emission.",
    "proxy.teleport(priest.position) keeps hidden turret aligned and is not visible priest movement.",
    "space-platform hover/tether code may use teleport or direct commands because normal ground pathing is unsafe there."
  },
  remaining_categories = {
    routed_legacy_helpers = {
      "issue_priest_command",
      "move_priest_to",
      "return_to_station",
      "conversation approach helper",
      "mining stop helper"
    },
    fallback_only = {
      "acquisition_executor direct set_command fallback when movement controller is absent",
      "construction_planner direct set_command fallback when movement controller is absent",
      "crafting_executor direct set_command fallback when movement controller is absent"
    },
    excluded_space_platform = {
      "space platform tether/exact-safe-tile hover and patrol handlers",
      "void platform recall/hover glide"
    },
    excluded_proxy = {
      "hidden proxy turret teleport-to-priest alignment"
    }
  }
}

local function selected_pair(player)
  if _G.tech_priests_get_selected_pair_0247 then local ok, pair = pcall(_G.tech_priests_get_selected_pair_0247, player); if ok and pair then return pair end end
  if _G.selected_pair_for_player then local ok, pair = pcall(_G.selected_pair_for_player, player); if ok and pair then return pair end end
  local selected = player and player.selected
  if not (selected and selected.valid and storage and storage.tech_priests) then return nil end
  if storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[selected.unit_number] then return storage.tech_priests.pairs_by_station[selected.unit_number] end
  if storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[selected.unit_number] then return storage.tech_priests.pairs_by_priest[selected.unit_number] end
  return nil
end

local function print_summary(player)
  player.print("[tp-combat-movement-0429] " .. SUMMARY.doctrine)
  player.print("  route_helper=" .. tostring(_G.tech_priests_route_ground_command_0429 ~= nil) .. " request_helper=" .. tostring(_G.tech_priests_request_movement_0418 ~= nil) .. " controller=" .. tostring(_G.TECH_PRIESTS_MOVEMENT_CONTROLLER_0418 ~= nil))
  player.print("  allowed exceptions: proxy alignment, space-platform tether/hover, respawn/spawn-locus placement")
  local pair = selected_pair(player)
  if pair then
    local req = pair.movement_request_0418
    player.print("  selected pair station=" .. tostring(pair.station and pair.station.unit_number) .. " priest=" .. tostring(pair.priest and pair.priest.valid and pair.priest.unit_number) .. " mode=" .. tostring(pair.mode))
    if req then
      player.print("  movement request owner=" .. tostring(req.owner) .. " reason=" .. tostring(req.reason) .. " target=" .. tostring(req.x) .. "," .. tostring(req.y) .. " radius=" .. tostring(req.radius))
    else
      player.print("  movement request=nil")
    end
    player.print("  clamp=" .. tostring(pair.movement_controller_clamp_0418 or "none") .. " last_snap=" .. tostring(pair.last_ground_snap_0418 and pair.last_ground_snap_0418.dist or "none"))
  else
    player.print("  select a Cogitator Station or Tech-Priest for pair-specific movement state")
  end
end

function M.get_summary()
  return SUMMARY
end

function M.install()
  _G.TECH_PRIESTS_COMBAT_MOVEMENT_LEFTOVERS_0429 = M
  local registry = rawget(_G, "TechPriestsDebugCommandRegistry")
  if registry and registry.add then
    registry.add("tp-combat-movement-0429", "Tech Priests: print combat/movement leftover authority diagnostic.", function(command)
      local player = command and command.player_index and game.get_player(command.player_index) or nil
      if player then print_summary(player) end
    end)
  elseif commands and commands.add_command then
    pcall(function() commands.remove_command("tp-combat-movement-0429") end)
    commands.add_command("tp-combat-movement-0429", "Tech Priests: print combat/movement leftover authority diagnostic.", function(command)
      local player = command and command.player_index and game.get_player(command.player_index) or nil
      if player then print_summary(player) end
    end)
  end
  if log then log("[Tech-Priests 0.1.429] combat/movement leftover diagnostic installed") end
  return true
end

return M
