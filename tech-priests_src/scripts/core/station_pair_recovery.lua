-- scripts/core/station_pair_recovery.lua
-- Tech Priests 0.1.363 Station Pair State / Inventory Recovery Failsafe.
--
-- Purpose:
--   Keep the per-station/priest dossier and station-bound inventory doctrine from
--   becoming a stale or invalid state sink.  This module validates pair records,
--   reinitializes their ledger and station-bound supporting state, and reports
--   recovery actions in chat/diagnostics.
--
-- Doctrine boundary:
--   This module repairs and reports state only.  It does not choose work,
--   execute acquisition, place entities, or mutate consecration logic.

local M = {}
M.version = "0.1.363"
M.storage_key = "station_pair_recovery_0363"
M.audit_interval_ticks = 601
M.chat_throttle_ticks = 1800
M.max_report_lines = 16

local function valid(e) return e and e.valid end
local function tick() return game and game.tick or 0 end
local function safe_tostring(v)
  local ok, out = pcall(function() return tostring(v) end)
  if ok then return out end
  return "?"
end

local function ensure_tp_root()
  storage.tech_priests = storage.tech_priests or {}
  return storage.tech_priests
end

function M.root()
  local tp = ensure_tp_root()
  tp[M.storage_key] = tp[M.storage_key] or {
    version = M.version,
    enabled = true,
    last_audit_tick = 0,
    last_chat_by_station = {},
    recovery_counts = {},
    last_recoveries = {},
  }
  local root = tp[M.storage_key]
  root.version = M.version
  root.last_chat_by_station = root.last_chat_by_station or {}
  root.recovery_counts = root.recovery_counts or {}
  root.last_recoveries = root.last_recoveries or {}
  return root
end

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end

local function priest_unit(pair)
  return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil
end

local function pair_label(pair)
  if not pair then return "no pair" end
  local station = pair.station
  local priest = pair.priest
  local station_name = valid(station) and (station.backer_name or station.name) or ("station#" .. safe_tostring(pair.station_unit or "?"))
  local priest_name = valid(priest) and (priest.backer_name or priest.name) or ("priest#" .. safe_tostring(pair.priest_unit or "missing"))
  return safe_tostring(station_name) .. " / " .. safe_tostring(priest_name)
end

local function station_inventory(pair)
  if not valid(pair and pair.station) then return nil end
  if _G.get_station_inventory then
    local ok, inv = pcall(_G.get_station_inventory, pair.station)
    if ok and inv and inv.valid then return inv end
  end
  if pair.station.get_inventory then
    local ok, inv = pcall(function() return pair.station.get_inventory(defines.inventory.chest) end)
    if ok and inv and inv.valid then return inv end
  end
  return nil
end

local function get_pair_state_module()
  if _G.TECH_PRIESTS_STATION_PAIR_STATE_0362 then return _G.TECH_PRIESTS_STATION_PAIR_STATE_0362 end
  local ok, mod = pcall(require, "scripts.core.station_pair_state")
  if ok then return mod end
  return nil
end

local function ensure_pair_state(pair, source)
  local mod = get_pair_state_module()
  if not mod then return false, "station_pair_state module unavailable" end
  local ok, ledger = pcall(function()
    if mod.ensure_pair then mod.ensure_pair(pair) end
    if mod.refresh_pair then return mod.refresh_pair(pair, source or "recovery") end
    return nil
  end)
  if ok and ledger then return true, nil end
  return false, safe_tostring(ledger or "ledger refresh failed")
end

local function clear_pair_state(pair)
  local key = station_unit(pair)
  local tp = storage and storage.tech_priests
  if not (key and tp) then return end
  local roots = {
    tp.station_pair_state_0362,
  }
  for _, root in ipairs(roots) do
    if root and root.ledgers then root.ledgers[key] = nil end
  end
end

local function ensure_station_inventory_state(pair)
  local tp = ensure_tp_root()
  local key = station_unit(pair)
  local problems = {}

  if not station_inventory(pair) then
    problems[#problems + 1] = "station inventory unavailable"
  end

  tp.station_by_priest = tp.station_by_priest or {}
  if valid(pair and pair.priest) and key then
    tp.station_by_priest[pair.priest.unit_number] = key
  end

  if key then
    tp.pairs_by_station = tp.pairs_by_station or {}
    tp.pairs_by_station[key] = pair
  end

  if _G.ensure_pair_logistic_caches then
    local ok = pcall(_G.ensure_pair_logistic_caches, pair)
    if not ok then problems[#problems + 1] = "logistic cache reinit failed" end
  end

  local steward = tp.inventory_steward_0357 or tp.inventory_steward_0356
  if steward and key then
    steward.stashes_by_station = steward.stashes_by_station or {}
    steward.stashes_by_station[key] = steward.stashes_by_station[key] or {}
  end

  if _G.tech_priests_0357_evacuate_pair_transient_cargo then
    pcall(_G.tech_priests_0357_evacuate_pair_transient_cargo, pair, "pair-recovery")
  end

  return problems
end

local function normalize_pair(pair)
  if not (pair and valid(pair.station)) then return false, { "station invalid" } end
  local issues = {}
  local station = pair.station
  local key = station.unit_number

  if not key then issues[#issues + 1] = "station has no unit_number"; return false, issues end

  if pair.station_unit ~= key then issues[#issues + 1] = "station_unit mismatch" end
  pair.station_unit = key
  pair.force = station.force and station.force.name or pair.force
  pair.surface = station.surface and station.surface.index or pair.surface

  if _G.refresh_pair_radius then
    local ok, radius = pcall(_G.refresh_pair_radius, pair)
    if ok and radius then pair.radius = radius else issues[#issues + 1] = "radius refresh failed" end
  elseif not tonumber(pair.radius) then
    pair.radius = 36
    issues[#issues + 1] = "radius missing; defaulted"
  end

  if _G.apply_pair_display_names then
    local ok = pcall(_G.apply_pair_display_names, pair)
    if not ok then issues[#issues + 1] = "display-name refresh failed" end
  end

  if not valid(pair.priest) then
    issues[#issues + 1] = "priest invalid; respawn requested"
    if _G.ensure_pair_priest then pcall(_G.ensure_pair_priest, pair, false, true) end
  elseif pair.priest_unit ~= pair.priest.unit_number then
    issues[#issues + 1] = "priest_unit mismatch"
    pair.priest_unit = pair.priest.unit_number
  end

  if valid(pair.priest) then
    pair.priest_unit = pair.priest.unit_number
  end

  pair.mode = pair.mode or "idle"
  pair.target = valid(pair.target) and pair.target or nil
  pair.combat_target = valid(pair.combat_target) and pair.combat_target or nil

  local inventory_problems = ensure_station_inventory_state(pair)
  for _, problem in ipairs(inventory_problems or {}) do issues[#issues + 1] = problem end

  local ledger_ok, ledger_problem = ensure_pair_state(pair, "recovery-normalize")
  if not ledger_ok then issues[#issues + 1] = ledger_problem or "ledger reinit failed" end

  return true, issues
end

local function validate_ledger(pair)
  local issues = {}
  local key = station_unit(pair)
  local tp = storage and storage.tech_priests
  local root = tp and tp.station_pair_state_0362 or nil
  local ledger = root and root.ledgers and key and root.ledgers[key] or nil
  if not key then
    issues[#issues + 1] = "no station unit for ledger"
    return issues
  end
  if not ledger then
    issues[#issues + 1] = "missing pair ledger"
    return issues
  end
  if type(ledger) ~= "table" then
    issues[#issues + 1] = "pair ledger is not a table"
    return issues
  end
  if ledger.station_unit ~= key then issues[#issues + 1] = "ledger station_unit mismatch" end
  if valid(pair.priest) and ledger.priest_unit ~= pair.priest.unit_number then issues[#issues + 1] = "ledger priest_unit mismatch" end
  for _, name in ipairs({ "identity", "hierarchy", "logistics", "planning", "scheduler", "diagnostics" }) do
    if type(ledger[name]) ~= "table" then issues[#issues + 1] = "ledger." .. name .. " malformed" end
  end
  return issues
end

function M.audit_pair(pair)
  local issues = {}
  if not pair then return false, { "missing pair" } end
  if not valid(pair.station) then issues[#issues + 1] = "station invalid" end
  if valid(pair.station) and pair.station_unit ~= pair.station.unit_number then issues[#issues + 1] = "station_unit mismatch" end
  if not valid(pair.priest) then issues[#issues + 1] = "priest invalid" end
  if valid(pair.priest) and pair.priest_unit ~= pair.priest.unit_number then issues[#issues + 1] = "priest_unit mismatch" end
  if valid(pair.station) and valid(pair.priest) and pair.priest.force ~= pair.station.force then issues[#issues + 1] = "priest force mismatch" end
  if valid(pair.station) and valid(pair.priest) and pair.priest.surface ~= pair.station.surface then issues[#issues + 1] = "priest surface mismatch" end
  if not station_inventory(pair) then issues[#issues + 1] = "station inventory unavailable" end

  local tp = storage and storage.tech_priests
  if tp and valid(pair.priest) then
    local mapped = tp.station_by_priest and tp.station_by_priest[pair.priest.unit_number] or nil
    if mapped ~= station_unit(pair) then issues[#issues + 1] = "station_by_priest mapping mismatch" end
  end

  for _, issue in ipairs(validate_ledger(pair)) do issues[#issues + 1] = issue end
  return #issues == 0, issues
end

local function record_recovery(root, key, label, issues, source)
  local rec = {
    tick = tick(),
    station_unit = key,
    label = label,
    source = source or "unknown",
    issues = issues or {},
  }
  root.last_recoveries[#root.last_recoveries + 1] = rec
  while #root.last_recoveries > 20 do table.remove(root.last_recoveries, 1) end
  root.recovery_counts[key or "orphan"] = (root.recovery_counts[key or "orphan"] or 0) + 1
end

local function print_recovery(pair, issues, source, force_print)
  if not valid(pair and pair.station) then return end
  local root = M.root()
  local key = station_unit(pair)
  local last = root.last_chat_by_station[key] or 0
  if not force_print and tick() - last < M.chat_throttle_ticks then return end
  root.last_chat_by_station[key] = tick()
  local text = "[Tech-Priests 0.1.363] Pair/state recovery for " .. pair_label(pair) .. " via " .. safe_tostring(source or "audit") .. ": " .. table.concat(issues or {}, "; ")
  pcall(function() pair.station.force.print(text) end)
end

function M.recover_pair(pair, source, force_print)
  local key = station_unit(pair)
  local label = pair_label(pair)
  if not pair then return false, { "missing pair" } end
  if not valid(pair.station) then
    local tp = storage and storage.tech_priests
    if tp and key then
      if tp.pairs_by_station then tp.pairs_by_station[key] = nil end
      if tp.station_pair_state_0362 and tp.station_pair_state_0362.ledgers then tp.station_pair_state_0362.ledgers[key] = nil end
    end
    return false, { "orphan pair removed: station invalid" }
  end

  clear_pair_state(pair)
  local ok, issues = normalize_pair(pair)
  local audit_ok, audit_issues = M.audit_pair(pair)
  if audit_issues and #audit_issues > 0 then
    for _, issue in ipairs(audit_issues) do issues[#issues + 1] = issue end
  end
  if #issues == 0 then issues[#issues + 1] = "manual reinitialization" end
  local root = M.root()
  record_recovery(root, key, label, issues, source)
  print_recovery(pair, issues, source, force_print)
  return ok and audit_ok, issues
end

function M.audit_all(source, repair)
  local root = M.root()
  if not root.enabled then return 0, 0 end
  local checked, recovered = 0, 0
  for key, pair in pairs(pair_map()) do
    checked = checked + 1
    if not (pair and valid(pair.station)) then
      if storage and storage.tech_priests and storage.tech_priests.pairs_by_station then storage.tech_priests.pairs_by_station[key] = nil end
      if storage and storage.tech_priests and storage.tech_priests.station_pair_state_0362 and storage.tech_priests.station_pair_state_0362.ledgers then storage.tech_priests.station_pair_state_0362.ledgers[key] = nil end
      recovered = recovered + 1
    else
      local ok = M.audit_pair(pair)
      if not ok and repair then
        M.recover_pair(pair, source or "auto-audit", false)
        recovered = recovered + 1
      end
    end
  end
  root.last_audit_tick = tick()
  return checked, recovered
end

function M.describe_pair(pair)
  local ok, issues = M.audit_pair(pair)
  local lines = {}
  lines[#lines + 1] = "Recovery 0.1.363 | " .. pair_label(pair) .. " | status=" .. (ok and "ok" or "needs-recovery")
  lines[#lines + 1] = "Station inventory=" .. (station_inventory(pair) and "valid" or "invalid/unavailable") .. " | station_unit=" .. safe_tostring(station_unit(pair)) .. " | priest_unit=" .. safe_tostring(priest_unit(pair))
  if #issues == 0 then
    lines[#lines + 1] = "No pair-state or station-inventory doctrine issues detected."
  else
    for i, issue in ipairs(issues) do if i <= M.max_report_lines then lines[#lines + 1] = "Issue: " .. issue end end
  end
  return lines
end

local function selected_pair(player)
  if not (player and player.valid and valid(player.selected)) then return nil end
  if _G.tech_priests_0362_find_pair_for_entity then
    local ok, pair = pcall(_G.tech_priests_0362_find_pair_for_entity, player.selected)
    if ok and pair then return pair end
  end
  if _G.find_pair_for_entity then
    local ok, pair = pcall(_G.find_pair_for_entity, player.selected)
    if ok and pair then return pair end
  end
  return nil
end


local function safe_write_file_0462(filename, data, append, for_player)
  if helpers then
    local ok_get, writer = pcall(function() return helpers.write_file end)
    if ok_get and writer then
      local ok_write = pcall(function() writer(filename, data, append or false, for_player) end)
      if ok_write then return true end
    end
  end
  if game then
    local ok_get, writer = pcall(function() return game.write_file end)
    if ok_get and writer then
      local ok_write = pcall(function() writer(filename, data, append or false, for_player) end)
      if ok_write then return true end
    end
  end
  return false
end

local function write_report(player)
  local lines = { "Tech Priests 0.1.363 station pair recovery report", "tick=" .. safe_tostring(tick()) }
  local checked, recovered = M.audit_all("write-report", true)
  lines[#lines + 1] = "checked=" .. checked .. " recovered=" .. recovered
  for _, pair in pairs(pair_map()) do
    if pair and valid(pair.station) then
      for _, line in ipairs(M.describe_pair(pair)) do lines[#lines + 1] = line end
      lines[#lines + 1] = "---"
    end
  end
  local root = M.root()
  lines[#lines + 1] = "Recent recoveries:"
  for _, rec in ipairs(root.last_recoveries or {}) do
    lines[#lines + 1] = "tick=" .. safe_tostring(rec.tick) .. " station=" .. safe_tostring(rec.station_unit) .. " source=" .. safe_tostring(rec.source) .. " issues=" .. table.concat(rec.issues or {}, "; ")
  end
  local ok = safe_write_file_0462("tech-priests-pair-state-recovery-0363.txt", table.concat(lines, "\n"), false)
  if player and player.valid then
    if ok then player.print("[tp-pairstate-recover-0363] wrote script-output/tech-priests-pair-state-recovery-0363.txt")
    else player.print("[tp-pairstate-recover-0363] failed to write script-output/tech-priests-pair-state-recovery-0363.txt; file writer unavailable") end
  end
end

function M.install_commands()
  if not commands then return end
  pcall(function() commands.remove_command("tp-pairstate-recover-0363") end)
  commands.add_command("tp-pairstate-recover-0363", "Tech Priests 0.1.363 pair/state recovery. Usage: status|recover|all|write|enable|disable", function(event)
    local player = event and event.player_index and game.players[event.player_index] or nil
    local param = tostring(event and event.parameter or "status")
    local root = M.root()
    if param == "enable" then root.enabled = true; if player then player.print("[tp-pairstate-recover-0363] enabled") end; return end
    if param == "disable" then root.enabled = false; if player then player.print("[tp-pairstate-recover-0363] disabled") end; return end
    if param == "all" then local checked, recovered = M.audit_all("command-all", true); if player then player.print("[tp-pairstate-recover-0363] checked=" .. checked .. " recovered=" .. recovered) end; return end
    if param == "write" then write_report(player); return end
    local pair = selected_pair(player)
    if not pair then if player then player.print("[tp-pairstate-recover-0363] select a Cogitator Station or Tech-Priest.") end; return end
    if param == "recover" then
      local ok, issues = M.recover_pair(pair, "command-recover", true)
      if player then player.print("[tp-pairstate-recover-0363] recovered=" .. tostring(ok) .. " issues=" .. table.concat(issues or {}, "; ")) end
      return
    end
    for _, line in ipairs(M.describe_pair(pair)) do if player then player.print("[tp-pairstate-recover-0363] " .. line) end end
  end)
end

function M.install_wrappers()
  if _G.create_pair and not _G.TECH_PRIESTS_ORIGINAL_CREATE_PAIR_0363 then
    _G.TECH_PRIESTS_ORIGINAL_CREATE_PAIR_0363 = _G.create_pair
    _G.create_pair = function(station)
      local result = _G.TECH_PRIESTS_ORIGINAL_CREATE_PAIR_0363(station)
      if station and station.valid and storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
        local pair = storage.tech_priests.pairs_by_station[station.unit_number]
        if pair then M.recover_pair(pair, "pair-created-or-recreated", true) end
      end
      return result
    end
  end
  if _G.respawn_pair_priest and not _G.TECH_PRIESTS_ORIGINAL_RESPAWN_PAIR_PRIEST_0363 then
    _G.TECH_PRIESTS_ORIGINAL_RESPAWN_PAIR_PRIEST_0363 = _G.respawn_pair_priest
    _G.respawn_pair_priest = function(pair, reason)
      local result = _G.TECH_PRIESTS_ORIGINAL_RESPAWN_PAIR_PRIEST_0363(pair, reason)
      if result and pair then M.recover_pair(pair, "priest-respawn:" .. safe_tostring(reason), true) end
      return result
    end
  end
end

function M.install_tick_handler()
  if not script or not script.on_nth_tick then return end
  script.on_nth_tick(M.audit_interval_ticks, function()
    if storage and storage.tech_priests then M.audit_all("periodic-audit", true) end
  end)
end

function M.install()
  M.root()
  M.install_commands()
  M.install_wrappers()
  M.install_tick_handler()
  _G.TECH_PRIESTS_STATION_PAIR_RECOVERY_0363 = M
  _G.tech_priests_0363_audit_pair_state = M.audit_pair
  _G.tech_priests_0363_recover_pair_state = M.recover_pair
  _G.tech_priests_0363_recover_all_pair_states = function() return M.audit_all("global-call", true) end
  if log then log("[Tech-Priests 0.1.363] station pair state / station inventory recovery installed") end
  return true
end

return M
