-- scripts/core/action_stack_contract_0507.lua
-- Tech Priests 0.1.507
--
-- First legacy cleanup pass for the behavior stack.
--
-- This module does not attempt to delete the historical generated fragments in
-- one dangerous sweep.  Instead it gives the runtime an explicit authority map
-- and installs diagnostics for the first functions that were actually moved out
-- of duplicate ownership in this pass:
--   * direct acquisition pulsing belongs to acquisition_executor.lua;
--   * Work State GUI recovery no longer pulses acquisition;
--   * acquisition repair/unstick/crafting executors are single-install registry
--     services rather than repeatedly replacing script.on_nth_tick handlers.

local M = {}
M.version = "0.1.507"
M.storage_key = "action_stack_contract_0507"

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function tp_root() storage.tech_priests = storage.tech_priests or {}; return storage.tech_priests end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end

M.stack = {
  { key = "lifecycle", owner = "pair_lifecycle + 0499/0500/0501/0503/0506", role = "validate identity, rebind invalid priests, respawn only real missing/cross-surface cases" },
  { key = "scheduler", owner = "order_queue_0469 + task_scheduler vocabulary", role = "decide what job exists next; never perform physical work directly" },
  { key = "arbiter", owner = "action_state_arbiter_0488 + behavior mutex", role = "choose the single visible action family allowed this tick" },
  { key = "movement", owner = "movement_controller + mobility_recovery_contract_0506", role = "move the priest to the target; no recall unless recovery is real" },
  { key = "executor", owner = "family executor modules", role = "perform one claimed action: combat, repair, scavenge, facility, craft, construction, direct mine" },
  { key = "visuals", owner = "overhead/text/sound/visual lease authorities", role = "show claimed action without mutating work state" },
  { key = "diagnostics", owner = "diagnostics_behavior_authority_0468 + this module", role = "explain the active claim and duplicate owners" },
}

M.owned_services = {
  direct_acquisition = "scripts/core/acquisition_executor.lua",
  acquisition_repair_watchdog = "scripts/core/acquisition_repair.lua",
  acquisition_unstick_watchdog = "scripts/core/acquisition_unstick.lua",
  timed_station_crafting = "scripts/core/crafting_executor.lua",
  workstate_gui_refresh = "scripts/core/workstate_gui_radar_recovery_0465.lua",
}

function M.root()
  local tp = tp_root()
  local r = tp[M.storage_key] or { version = M.version, enabled = true, claims = {}, recent = {}, stats = {} }
  tp[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.claims = r.claims or {}
  r.recent = r.recent or {}
  r.stats = r.stats or {}
  return r
end

local function stat(k, n)
  local r = M.root()
  r.stats[k] = (r.stats[k] or 0) + (n or 1)
end

local function record(action, pair, detail)
  local r = M.root()
  local rec = { tick = now(), action = tostring(action or "event"), station = station_unit(pair), priest = priest_unit(pair), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = rec
  while #r.recent > 80 do table.remove(r.recent, 1) end
  stat(action)
  return rec
end

function M.claim(pair, family, owner, detail)
  if M.root().enabled == false or not pair then return true end
  local key = station_unit(pair) or priest_unit(pair)
  if not key then return true end
  local r = M.root()
  local tick = now()
  local claim = r.claims[key]
  family = tostring(family or "unknown")
  owner = tostring(owner or "unknown")
  if claim and claim.tick == tick and claim.family ~= family then
    r.stats.duplicate_family_claims = (r.stats.duplicate_family_claims or 0) + 1
    record("duplicate-claim-0507", pair, "old=" .. safe(claim.family) .. "/" .. safe(claim.owner) .. " new=" .. safe(family) .. "/" .. safe(owner) .. " " .. safe(detail))
    -- Do not hard-block yet. This is the first cleanup pass; diagnostics first.
  end
  r.claims[key] = { tick = tick, family = family, owner = owner, detail = detail }
  return true
end

function M.explain()
  local lines = {}
  lines[#lines + 1] = "Tech Priests 0.1.507 authoritative action stack:"
  lines[#lines + 1] = "Scheduler: owns intent. It decides which job/writ/order should exist next."
  lines[#lines + 1] = "Action arbiter: owns visible exclusivity. It decides what the priest may physically do right now."
  lines[#lines + 1] = "Executor: owns completion. It performs the chosen action and reports progress/completion."
  lines[#lines + 1] = "Visual/audio authorities: report state only; they must not create new work."
  lines[#lines + 1] = "First cleanup moved duplicate acquisition pulsing out of Work State GUI recovery and into acquisition_executor.lua."
  for _, row in ipairs(M.stack) do
    lines[#lines + 1] = " - " .. row.key .. ": " .. row.owner .. " :: " .. row.role
  end
  return lines
end

function M.pair_lines(pair)
  local r = M.root()
  local key = station_unit(pair) or priest_unit(pair)
  local c = key and r.claims[key] or nil
  return "stack_claim=" .. safe(c and c.family or "none")
    .. " owner=" .. safe(c and c.owner or "none")
    .. " tick=" .. safe(c and c.tick or "nil")
end

local function wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.action_stack_0507_wrapped then return false end
  local prev = diag.pair_dump_lines
  diag.action_stack_0507_wrapped = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 ACTION-STACK-0507 BEGIN enabled=" .. safe(r.enabled)
      .. " duplicate_claims=" .. safe(r.stats.duplicate_family_claims or 0)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then
        lines[#lines + 1] = "PAIR-DUMP-0468 ACTION-STACK-0507 pair[" .. safe(station_unit(pair)) .. "] " .. M.pair_lines(pair)
      end
    end
    lines[#lines + 1] = "PAIR-DUMP-0468 ACTION-STACK-0507 owned direct_acquisition=" .. M.owned_services.direct_acquisition
    lines[#lines + 1] = "PAIR-DUMP-0468 ACTION-STACK-0507 owned workstate_gui_refresh=" .. M.owned_services.workstate_gui_refresh
    lines[#lines + 1] = "PAIR-DUMP-0468 ACTION-STACK-0507 END"
    return lines
  end
  return true
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok, pair = pcall(_G.selected_pair_for_player, player); if ok then return pair end end
  local selected = player and player.selected
  local root = storage and storage.tech_priests or nil
  if selected and selected.valid and root then
    if root.pairs_by_station and root.pairs_by_station[selected.unit_number] then return root.pairs_by_station[selected.unit_number] end
    if root.pairs_by_priest and root.pairs_by_priest[selected.unit_number] then return root.pairs_by_priest[selected.unit_number] end
  end
  return nil
end

local function install_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() commands.remove_command("tp-action-stack-0507") end)
  commands.add_command("tp-action-stack-0507", "Tech Priests 0.1.507: inspect authoritative behavior stack and selected pair claim.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local param = tostring(event and event.parameter or "status")
    local r = M.root()
    if param == "enable" then r.enabled = true end
    if param == "disable" then r.enabled = false end
    local out = M.explain()
    local pair = player and selected_pair(player) or nil
    if pair then out[#out + 1] = "Selected: station=" .. safe(station_unit(pair)) .. " priest=" .. safe(priest_unit(pair)) .. " " .. M.pair_lines(pair) end
    out[#out + 1] = "enabled=" .. safe(r.enabled) .. " duplicate_claims=" .. safe(r.stats.duplicate_family_claims or 0)
    local text = table.concat(out, "\n")
    if player and player.valid then player.print(text) elseif game and game.print then game.print(text) end
  end)
end

function M.install()
  M.root()
  _G.TechPriestsActionStackContract0507 = M
  _G.tech_priests_0507_action_claim = M.claim
  _G.tech_priests_0507_action_stack_lines = M.explain
  wrap_pair_dump()
  install_commands()
  if log then log("[Tech-Priests 0.1.507] authoritative action stack contract installed; duplicate acquisition GUI pulse removed") end
  return true
end

return M
