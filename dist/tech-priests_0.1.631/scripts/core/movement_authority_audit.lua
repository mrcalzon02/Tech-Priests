-- scripts/core/movement_authority_audit.lua
-- Tech Priests 0.1.429 movement sovereignty / task authority diagnostics.
--
-- This module deliberately does not move priests.  It reports ownership and
-- clears stale legacy hammer state so the unified movement controller can remain
-- the sole ground-priest movement authority.

local Audit = {}

Audit.version = "0.1.419"
Audit.storage_key = "movement_authority_audit_0419"

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function pairs_by_station() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end

local STATIC_MOVEMENT_WRITER_AUDIT = {
  { area = "control.lua legacy helpers", status = "wrapped", note = "issue_priest_command / move_priest_to / return_to_station are routed through movement_controller for ground priests" },
  { area = "combat proxy handlers 0292/0293", status = "wrapped", note = "attack commands are converted to combat intent; proxy turret owns damage" },
  { area = "acquisition_executor.lua", status = "routed", note = "set_command_to uses tech_priests_request_movement_0418 when present" },
  { area = "crafting_executor.lua", status = "routed", note = "station return movement uses tech_priests_request_movement_0418 when present" },
  { area = "construction_planner.lua", status = "routed", note = "build-site movement uses tech_priests_request_movement_0418 when present" },
  { area = "movement_hammer.lua", status = "demoted", note = "not actively installed in 0.1.419; historical reference/diagnostic only" },
  { area = "space-platform tether / hover-glide", status = "excluded", note = "space handling may teleport on purpose; this pass governs ground priests only" },
  { area = "proxy turret teleport", status = "allowed", note = "hidden proxy follows priest; this is not visible priest movement" },
  { area = "combat_movement_leftovers.lua", status = "diagnostic", note = "0.1.429 audit command reports remaining movement/combat command touchpoints" }
}

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Audit.storage_key] = storage.tech_priests[Audit.storage_key] or { version = Audit.version, stats = {} }
  local root = storage.tech_priests[Audit.storage_key]
  root.version = Audit.version
  root.stats = root.stats or {}
  return root
end

local function selected_pair(player)
  if not player then return nil end
  if _G.tech_priests_get_selected_pair_0247 then local ok, pair = pcall(_G.tech_priests_get_selected_pair_0247, player); if ok and pair then return pair end end
  if _G.selected_pair_for_player then local ok, pair = pcall(_G.selected_pair_for_player, player); if ok and pair then return pair end end
  local selected = player.selected
  if not (selected and selected.valid and storage and storage.tech_priests) then return nil end
  if storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[selected.unit_number] then return storage.tech_priests.pairs_by_station[selected.unit_number] end
  if storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[selected.unit_number] then return storage.tech_priests.pairs_by_priest[selected.unit_number] end
  if _G.find_pair_for_entity then local ok, pair = pcall(_G.find_pair_for_entity, selected); if ok and pair then return pair end end
  return nil
end

local function task_summary(pair)
  local task = pair and (pair.current_task or pair.active_task or pair.active_task_0285) or nil
  if not task then return "nil" end
  return "kind=" .. tostring(task.kind or task.type) ..
         " phase=" .. tostring(task.phase or task.key) ..
         " owner=" .. tostring(task.owner_system or task.owner or pair.task_owner_0276) ..
         " target=" .. tostring(task.target and task.target.valid and task.target.name or task.target or "nil")
end

local function clear_stale_hammer_state(pair)
  if not pair then return false end
  local changed = false
  if pair.movement_lockdown_until_0416 then pair.movement_lockdown_until_0416 = nil; changed = true end
  if pair.movement_lockdown_reason_0416 then pair.movement_lockdown_reason_0416 = nil; changed = true end
  if pair.movement_lockdown_release_cooldown_until_0416 then pair.movement_lockdown_release_cooldown_until_0416 = nil; changed = true end
  if pair.mode == "movement-lockdown" or pair.mode == "movement-stabilizing" then pair.mode = "idle"; changed = true end
  return changed
end

function Audit.clear_stale_legacy_hammer_state()
  local root = ensure_root()
  local n = 0
  for _, pair in pairs(pairs_by_station()) do
    if clear_stale_hammer_state(pair) then n = n + 1 end
  end
  if n > 0 then root.stats.cleared_legacy_hammer_pairs = (root.stats.cleared_legacy_hammer_pairs or 0) + n end
  return n
end

local function movement_state(pair)
  local req = pair and pair.movement_request_0418 or nil
  if not req then return "request=nil" end
  return "owner=" .. tostring(req.owner) ..
         " reason=" .. tostring(req.reason) ..
         " target=" .. string.format("%.2f,%.2f", tonumber(req.x) or 0, tonumber(req.y) or 0) ..
         " radius=" .. tostring(req.radius) ..
         " last_cmd=" .. tostring(req.last_command_tick or "nil")
end

function Audit.register_commands()
  if not (commands and commands.add_command) then return end

  pcall(function() commands.remove_command("tp-audit-movement-writers") end)
  commands.add_command("tp-audit-movement-writers", "Tech Priests 0.1.429 movement-writer authority audit.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    if not (player and player.valid) then return end
    local root = ensure_root()
    local cleared = Audit.clear_stale_legacy_hammer_state()
    player.print("[tp-audit-movement-writers] movement_controller=sole ground authority; legacy_hammer=not installed; stale_hammer_cleared=" .. tostring(cleared))
    for _, item in ipairs(STATIC_MOVEMENT_WRITER_AUDIT) do
      player.print("  " .. item.status .. " :: " .. item.area .. " :: " .. item.note)
    end
    player.print("  stats cleared_total=" .. tostring(root.stats.cleared_legacy_hammer_pairs or 0))
  end)

  pcall(function() commands.remove_command("tp-task-authority") end)
  commands.add_command("tp-task-authority", "Tech Priests 0.1.429 selected-pair task/movement authority report.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    if not (player and player.valid) then return end
    local pair = selected_pair(player)
    if not pair then player.print("[tp-task-authority] Select a Cogitator Station or Tech-Priest."); return end
    clear_stale_hammer_state(pair)
    player.print("[tp-task-authority] station=" .. tostring(pair.station and pair.station.valid and pair.station.unit_number) .. " priest=" .. tostring(pair.priest and pair.priest.valid and pair.priest.unit_number) .. " mode=" .. tostring(pair.mode))
    player.print("  task=" .. task_summary(pair))
    player.print("  scheduler_kind=" .. tostring(pair.task_kind_0276 or pair.task_kind) .. " phase=" .. tostring(pair.task_phase_0276 or "nil") .. " visual=" .. tostring(pair.visual_state_0276 or pair.mode))
    player.print("  movement=" .. movement_state(pair))
    player.print("  clamp=" .. tostring(pair.movement_controller_clamp_0418 or "none") .. " controller_state=" .. tostring(pair.movement_controller_state_0418 or "nil"))
    if pair.last_ground_snap_0418 then
      local snap = pair.last_ground_snap_0418
      player.print("  last_snap tick=" .. tostring(snap.tick) .. " dist=" .. tostring(snap.dist) .. " dt=" .. tostring(snap.dt) .. " mode=" .. tostring(snap.mode))
    end
  end)
end

function Audit.install()
  ensure_root()
  Audit.clear_stale_legacy_hammer_state()
  Audit.register_commands()
  if log then log("[Tech-Priests 0.1.419] movement authority audit installed; stale legacy hammer state cleared if present") end
  return true
end

return Audit
