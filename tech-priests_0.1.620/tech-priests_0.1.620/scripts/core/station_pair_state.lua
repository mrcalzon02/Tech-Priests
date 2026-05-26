-- scripts/core/station_pair_state.lua
-- Tech Priests 0.1.362 Station Pair State Ledger.
--
-- Purpose:
--   Create one canonical per Cogitator Station / Tech-Priest runtime dossier.
--   This module stores and reports state; it does not become a new executor.
--
-- Doctrine:
--   Cogitator Station = inventory, memory, command authority, task owner.
--   Tech-Priest = mobile actuator and temporary carrier only.

local M = {}
M.version = "0.1.362"
M.storage_key = "station_pair_state_0362"
M.max_items = 12

local function valid(e) return e and e.valid end
local function now() return game and game.tick or 0 end
local function safe_tostring(v)
  local ok, out = pcall(function() return tostring(v) end)
  if ok then return out end
  return "?"
end

local function ensure_tp_root()
  storage.tech_priests = storage.tech_priests or {}
  return storage.tech_priests
end

function M.ensure_root()
  local root = ensure_tp_root()
  root[M.storage_key] = root[M.storage_key] or {
    version = M.version,
    ledgers = {},
    enabled = true,
    last_full_refresh = 0,
  }
  root[M.storage_key].version = M.version
  return root[M.storage_key]
end

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function station_unit(pair)
  if not pair then return nil end
  return pair.station_unit or (valid(pair.station) and pair.station.unit_number) or nil
end

local function priest_unit(pair)
  if not pair then return nil end
  return pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number) or nil
end

local function entity_label(entity)
  if not valid(entity) then return "invalid" end
  return safe_tostring(entity.backer_name or entity.name or "entity") .. "#" .. safe_tostring(entity.unit_number or "?")
end

local function station_label(pair)
  if not pair then return "no station" end
  if valid(pair.station) then return entity_label(pair.station) end
  return "station#" .. safe_tostring(pair.station_unit or "?")
end

local function priest_label(pair)
  if not pair then return "no priest" end
  if valid(pair.priest) then return entity_label(pair.priest) end
  return "priest#" .. safe_tostring(pair.priest_unit or "?")
end

local function station_rank(pair)
  if not pair then return 1 end
  if tonumber(pair.rank) then return tonumber(pair.rank) end
  if tonumber(pair.station_rank) then return tonumber(pair.station_rank) end
  local name = valid(pair.station) and pair.station.name or ""
  if name:find("void", 1, true) or name:find("planetary%-magos") then return 4 end
  if name:find("senior", 1, true) then return 3 end
  if name:find("intermediate", 1, true) then return 2 end
  return 1
end

local function safe_inv(entity, inv_id)
  if not (valid(entity) and entity.get_inventory and inv_id) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inv_id) end)
  if ok and inv and inv.valid then return inv end
  return nil
end

local function main_inv(entity)
  if not valid(entity) then return nil end
  if entity.get_main_inventory then
    local ok, inv = pcall(function() return entity.get_main_inventory() end)
    if ok and inv and inv.valid then return inv end
  end
  return nil
end

local function add_inv(list, seen, inv, kind, owner)
  if not (inv and inv.valid) then return end
  local key = safe_tostring(inv)
  if seen[key] then return end
  seen[key] = true
  list[#list+1] = { inv = inv, kind = kind, owner = owner }
end

local function inventory_contents(inv)
  local ok, contents = pcall(function()
    if inv and inv.valid and inv.get_contents then return inv.get_contents() end
    return {}
  end)
  if not ok then return {} end
  local out = {}
  for k, v in pairs(contents or {}) do
    if type(v) == "table" and v.name then
      out[v.name] = (out[v.name] or 0) + (tonumber(v.count) or 0)
    elseif type(k) == "string" then
      out[k] = (out[k] or 0) + (tonumber(v) or 0)
    end
  end
  return out
end

local function merge_contents(slots)
  local out = {}
  for _, slot in ipairs(slots or {}) do
    for name, count in pairs(inventory_contents(slot.inv)) do
      out[name] = (out[name] or 0) + count
    end
  end
  return out
end

local function sorted_items(tbl, limit)
  local rows = {}
  for name, count in pairs(tbl or {}) do
    if (tonumber(count) or 0) > 0 then rows[#rows+1] = { name = name, count = count } end
  end
  table.sort(rows, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.name < b.name
  end)
  local out = {}
  for i = 1, math.min(limit or M.max_items, #rows) do out[#out+1] = rows[i] end
  return out, #rows
end

local function station_source_slots(pair)
  if _G.tech_priests_0358_station_sources_for_pair then
    local ok, slots = pcall(_G.tech_priests_0358_station_sources_for_pair, pair)
    if ok and type(slots) == "table" then return slots end
  end
  local list, seen = {}, {}
  if valid(pair and pair.station) then
    local ids = {
      defines.inventory.chest,
      defines.inventory.assembling_machine_input,
      defines.inventory.assembling_machine_output,
      defines.inventory.furnace_source,
      defines.inventory.furnace_result,
      defines.inventory.fuel,
      defines.inventory.burnt_result,
    }
    for _, id in ipairs(ids) do add_inv(list, seen, safe_inv(pair.station, id), "owning-station", pair.station) end
  end
  return list
end

local function priest_transient_slots(pair)
  local list, seen = {}, {}
  if valid(pair and pair.priest) then
    add_inv(list, seen, main_inv(pair.priest), "transient-priest-cargo", pair.priest)
    add_inv(list, seen, safe_inv(pair.priest, defines.inventory.character_main), "transient-priest-cargo", pair.priest)
    add_inv(list, seen, safe_inv(pair.priest, defines.inventory.chest), "transient-priest-cargo", pair.priest)
    add_inv(list, seen, safe_inv(pair.priest, defines.inventory.spider_trunk), "transient-priest-cargo", pair.priest)
    add_inv(list, seen, safe_inv(pair.priest, defines.inventory.car_trunk), "transient-priest-cargo", pair.priest)
  end
  return list
end

local function task_summary(pair)
  if not pair then return "none", nil end
  local candidates = {
    { "active_task", pair.active_task },
    { "active_request", pair.active_request },
    { "current_task", pair.current_task },
    { "task", pair.task },
    { "writ", pair.writ },
    { "emergency_operation", pair.emergency_operation },
    { "direct_gather", pair.direct_gather },
    { "craft", pair.craft },
    { "build_task", pair.build_task },
    { "construction_task", pair.construction_task },
    { "arterial_plan", pair.arterial_plan },
  }
  for _, rec in ipairs(candidates) do
    if rec[2] ~= nil then return rec[1], rec[2] end
  end
  return "none", nil
end

local function short_value(v, depth)
  depth = depth or 0
  if v == nil then return "nil" end
  if type(v) ~= "table" then return safe_tostring(v) end
  if v.valid and v.name then return tostring(v.name) .. "#" .. tostring(v.unit_number or "?") end
  if depth > 1 then return "..." end
  local parts = {}
  for _, k in ipairs({ "type", "kind", "item", "item_name", "recipe", "recipe_name", "mode", "state", "phase", "reason", "target", "amount", "count", "needed", "gathered" }) do
    local val = v[k]
    if val ~= nil then parts[#parts+1] = k .. "=" .. short_value(val, depth + 1) end
  end
  if #parts == 0 then
    local n = 0
    for k, val in pairs(v) do
      n = n + 1
      if n <= 4 then parts[#parts+1] = safe_tostring(k) .. "=" .. short_value(val, depth + 1) end
    end
  end
  return table.concat(parts, ", ")
end

local function relation_summary(pair)
  local out = { superior = nil, juniors = {}, peers = {} }
  if not (pair and valid(pair.station)) then return out end
  local rank = station_rank(pair)
  local radius = tonumber(pair.radius) or 36
  if _G.get_station_operating_radius then
    local ok, r = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(r) then radius = tonumber(r) end
  end
  local best_rank = -1
  for _, other in pairs(pair_map()) do
    if other ~= pair and valid(other and other.station) and other.station.surface == pair.station.surface then
      local dx = (other.station.position.x or 0) - (pair.station.position.x or 0)
      local dy = (other.station.position.y or 0) - (pair.station.position.y or 0)
      if dx * dx + dy * dy <= radius * radius * 4 then
        local orank = station_rank(other)
        if orank > rank and orank > best_rank then out.superior = other; best_rank = orank end
        if orank < rank then out.juniors[#out.juniors+1] = other end
        if orank == rank then out.peers[#out.peers+1] = other end
      end
    end
  end
  return out
end

local function emergency_facilities(pair)
  local root = storage and storage.tech_priests and storage.tech_priests.emergency_facility_doctrine_0343 or nil
  local key = station_unit(pair)
  local out = {}
  if not (root and key) then return out end
  local bucket = root.by_station and root.by_station[key] or nil
  if bucket and root.facilities then
    for rec_key in pairs(bucket) do
      local rec = root.facilities[rec_key]
      if rec and valid(rec.entity) then out[#out+1] = rec end
    end
  end
  table.sort(out, function(a, b) return safe_tostring(a.role or a.name) < safe_tostring(b.role or b.name) end)
  return out
end

function M.find_pair_for_entity(entity)
  if not valid(entity) then return nil end
  if _G.find_pair_for_entity then
    local ok, pair = pcall(_G.find_pair_for_entity, entity)
    if ok and pair then return pair end
  end
  for _, pair in pairs(pair_map()) do
    if pair and (pair.station == entity or pair.priest == entity) then return pair end
  end
  return nil
end

function M.ensure_pair(pair)
  local key = station_unit(pair)
  if not key then return nil end
  local root = M.ensure_root()
  local ledger = root.ledgers[key]
  if not ledger then
    ledger = {
      station_unit = key,
      created_tick = now(),
      identity = {},
      hierarchy = {},
      logistics = {},
      planning = {},
      scheduler = {},
      diagnostics = {},
    }
    root.ledgers[key] = ledger
  end
  ledger.station_unit = key
  ledger.priest_unit = priest_unit(pair)
  ledger.rank = station_rank(pair)
  ledger.updated_tick = now()
  return ledger
end

function M.refresh_pair(pair, source)
  local ledger = M.ensure_pair(pair)
  if not ledger then return nil end
  local relation = relation_summary(pair)
  local task_name, task = task_summary(pair)
  local station_items = merge_contents(station_source_slots(pair))
  local transient_items = merge_contents(priest_transient_slots(pair))
  local station_rows, station_total = sorted_items(station_items, M.max_items)
  local transient_rows, transient_total = sorted_items(transient_items, M.max_items)
  local facilities = emergency_facilities(pair)

  ledger.identity.station_label = station_label(pair)
  ledger.identity.priest_label = priest_label(pair)
  ledger.identity.station_name = valid(pair and pair.station) and safe_tostring(pair.station.backer_name or pair.station.name) or nil
  ledger.identity.priest_name = valid(pair and pair.priest) and safe_tostring(pair.priest.backer_name or pair.priest.name) or nil

  ledger.hierarchy.superior_station_unit = relation.superior and station_unit(relation.superior) or nil
  ledger.hierarchy.superior_label = relation.superior and station_label(relation.superior) or "none"
  ledger.hierarchy.junior_count = #relation.juniors
  ledger.hierarchy.peer_count = #relation.peers

  ledger.logistics.station_item_kinds = station_total
  ledger.logistics.station_items = station_rows
  ledger.logistics.transient_item_kinds = transient_total
  ledger.logistics.transient_cargo = transient_rows
  ledger.logistics.facility_count = #facilities
  ledger.logistics.facilities = {}
  for i, rec in ipairs(facilities) do
    if i <= M.max_items then
      ledger.logistics.facilities[#ledger.logistics.facilities+1] = {
        name = rec.name,
        role = rec.role,
        unit = valid(rec.entity) and rec.entity.unit_number or nil,
      }
    end
  end

  ledger.planning.active_task_name = task_name
  ledger.planning.active_task_summary = short_value(task)
  ledger.planning.active_behavior = pair and pair.mode or "idle"
  ledger.planning.source = source or ledger.planning.source or "refresh"

  ledger.diagnostics.last_refresh_source = source or "refresh"
  ledger.diagnostics.last_status = "ledger refreshed"
  ledger.diagnostics.last_tick = now()
  return ledger
end

function M.observe_scheduler(pair, lines)
  local ledger = M.refresh_pair(pair, "scheduler")
  if not ledger then return nil end
  ledger.scheduler.lines = {}
  for i, line in ipairs(lines or {}) do
    if i <= 12 then ledger.scheduler.lines[#ledger.scheduler.lines+1] = safe_tostring(line) end
  end
  ledger.scheduler.updated_tick = now()
  return ledger
end

function M.describe_pair(pair)
  local ledger = M.refresh_pair(pair, "describe")
  if not ledger then return { "No valid station/priest pair ledger available." } end
  local lines = {}
  lines[#lines+1] = "Ledger: station pair state 0.1.362 | station_unit=" .. safe_tostring(ledger.station_unit) .. " priest_unit=" .. safe_tostring(ledger.priest_unit or "missing")
  lines[#lines+1] = "Identity: " .. safe_tostring(ledger.identity.station_label) .. " -> " .. safe_tostring(ledger.identity.priest_label) .. " | rank " .. safe_tostring(ledger.rank)
  lines[#lines+1] = "Hierarchy: superior=" .. safe_tostring(ledger.hierarchy.superior_label or "none") .. " | juniors=" .. safe_tostring(ledger.hierarchy.junior_count or 0) .. " | peers=" .. safe_tostring(ledger.hierarchy.peer_count or 0)
  lines[#lines+1] = "Task: behavior=" .. safe_tostring(ledger.planning.active_behavior or "idle") .. " | " .. safe_tostring(ledger.planning.active_task_name or "none") .. " :: " .. safe_tostring(ledger.planning.active_task_summary or "nil")
  lines[#lines+1] = "Facilities: personal Martian machinery=" .. safe_tostring(ledger.logistics.facility_count or 0)
  for _, rec in ipairs(ledger.logistics.facilities or {}) do
    lines[#lines+1] = "  facility " .. safe_tostring(rec.role or "facility") .. ": " .. safe_tostring(rec.name) .. "#" .. safe_tostring(rec.unit or "?")
  end
  lines[#lines+1] = "Station stock: item kinds=" .. safe_tostring(ledger.logistics.station_item_kinds or 0)
  for _, row in ipairs(ledger.logistics.station_items or {}) do
    lines[#lines+1] = "  [item=" .. safe_tostring(row.name) .. "] " .. safe_tostring(row.name) .. " x" .. safe_tostring(row.count)
  end
  lines[#lines+1] = "Priest transient cargo: item kinds=" .. safe_tostring(ledger.logistics.transient_item_kinds or 0) .. " (evacuate; not active stock)"
  for _, row in ipairs(ledger.logistics.transient_cargo or {}) do
    lines[#lines+1] = "  transient [item=" .. safe_tostring(row.name) .. "] " .. safe_tostring(row.name) .. " x" .. safe_tostring(row.count)
  end
  if ledger.scheduler and ledger.scheduler.lines then
    for i, line in ipairs(ledger.scheduler.lines) do
      if i <= 6 then lines[#lines+1] = "Scheduler: " .. safe_tostring(line) end
    end
  end
  lines[#lines+1] = "Doctrine: ledger stores state only; scheduler decides; acquisition/construction/consecration execute."
  return lines
end

function M.refresh_all(source)
  local n = 0
  for _, pair in pairs(pair_map()) do
    if pair and valid(pair.station) then
      M.refresh_pair(pair, source or "refresh-all")
      n = n + 1
    end
  end
  M.ensure_root().last_full_refresh = now()
  return n
end

local function selected_pair(player)
  if player and player.valid and valid(player.selected) then return M.find_pair_for_entity(player.selected) end
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
  local lines = { "Tech Priests 0.1.362 station pair state ledger report", "tick=" .. safe_tostring(now()) }
  for _, pair in pairs(pair_map()) do
    if pair and valid(pair.station) then
      for _, line in ipairs(M.describe_pair(pair)) do lines[#lines+1] = line end
      lines[#lines+1] = "---"
    end
  end
  local text = table.concat(lines, "\n")
  local ok = safe_write_file_0462("tech-priests-pair-state-ledger-0362.txt", text, false)
  if player and player.valid then
    if ok then player.print("[tp-pairstate-0362] wrote script-output/tech-priests-pair-state-ledger-0362.txt")
    else player.print("[tp-pairstate-0362] failed to write script-output/tech-priests-pair-state-ledger-0362.txt; file writer unavailable") end
  end
end

function M.install_commands()
  if not commands then return end
  pcall(function() commands.remove_command("tp-pairstate-0362") end)
  commands.add_command("tp-pairstate-0362", "Tech Priests 0.1.362 station/priest pair state ledger. Usage: status|all|refresh|write", function(event)
    local player = event and event.player_index and game.players[event.player_index] or nil
    local param = tostring(event and event.parameter or "status")
    if param == "refresh" then
      local n = M.refresh_all("command-refresh")
      if player then player.print("[tp-pairstate-0362] refreshed " .. tostring(n) .. " pair ledgers.") end
      return
    end
    if param == "write" then write_report(player); return end
    if param == "all" then
      local n = M.refresh_all("command-all")
      if player then player.print("[tp-pairstate-0362] active ledgers=" .. tostring(n)) end
      return
    end
    local pair = selected_pair(player)
    if not pair then if player then player.print("[tp-pairstate-0362] select a Cogitator Station or Tech-Priest.") end; return end
    for _, line in ipairs(M.describe_pair(pair)) do if player then player.print("[tp-pairstate-0362] " .. line) end end
  end)
end

function M.install_scheduler_bridge()
  local ok, Scheduler = pcall(require, "scripts.core.task_scheduler")
  if not (ok and Scheduler) then return end
  if Scheduler.__tech_priests_0362_pair_state_wrapped then return end
  if type(Scheduler.behavior_ownership_report) == "function" then
    local previous = Scheduler.behavior_ownership_report
    Scheduler.behavior_ownership_report = function(pair)
      local lines = previous(pair)
      pcall(M.observe_scheduler, pair, lines)
      return lines
    end
    Scheduler.__tech_priests_0362_pair_state_wrapped = true
  end
end

function M.install_workstate_bridge()
  local ok, Work = pcall(require, "scripts.core.station_work_inventory")
  if not (ok and Work) then return end
  if Work.__tech_priests_0362_pair_state_wrapped then return end
  if type(Work.describe_pair) == "function" then
    local previous = Work.describe_pair
    Work.describe_pair = function(pair)
      local lines = previous(pair) or {}
      local ledger_lines = M.describe_pair(pair) or {}
      lines[#lines+1] = "--- Pair State Ledger 0.1.362 ---"
      for i, line in ipairs(ledger_lines) do
        if i <= 10 then lines[#lines+1] = line end
      end
      return lines
    end
    Work.__tech_priests_0362_pair_state_wrapped = true
  end
end

function M.install()
  M.ensure_root()
  _G.TECH_PRIESTS_STATION_PAIR_STATE_0362 = M
  _G.tech_priests_0362_find_pair_for_entity = M.find_pair_for_entity
  _G.tech_priests_0362_ensure_pair_state = M.ensure_pair
  _G.tech_priests_0362_refresh_pair_state = M.refresh_pair
  _G.tech_priests_0362_describe_pair_ledger = M.describe_pair
  M.install_commands()
  M.install_scheduler_bridge()
  M.install_workstate_bridge()
  if log then log("[Tech-Priests 0.1.362] station pair state ledger installed") end
  return true
end

return M
