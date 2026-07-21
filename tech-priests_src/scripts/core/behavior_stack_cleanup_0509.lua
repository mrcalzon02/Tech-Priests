-- scripts/core/behavior_stack_cleanup_0509.lua
-- Tech Priests 0.1.674-dev broker-owned passive behavior-stack maintenance.
-- Direct acquisition and movement execution are not owned here. This module
-- only repairs pair reverse maps and debounces passive order/cascade refreshes.

local M = {
  version = "0.1.674-dev",
  storage_key = "behavior_stack_cleanup_0509",
  service_interval = 53,
  service_budget = 32,
  refresh_debounce_ticks = 90,
  cascade_debounce_ticks = 180,
  broker_required = true,
  direct_acquisition_retired = true,
  movement_ownership_retired = true,
}

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value) if value == nil then return "nil" end local ok, out = pcall(tostring, value); return ok and out or "?" end
local function lower(value) return string.lower(tostring(value or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version, enabled = true, refresh_debounce = true,
    cascade_debounce = true, stats = {}, recent = {}, last_refresh = {}, last_cascade = {},
  }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  if root.enabled == nil then root.enabled = true end
  if root.refresh_debounce == nil then root.refresh_debounce = true end
  if root.cascade_debounce == nil then root.cascade_debounce = true end
  root.stats = root.stats or {}
  root.recent = root.recent or {}
  root.last_refresh = root.last_refresh or {}
  root.last_cascade = root.last_cascade or {}
  root.decommission_0502_executor = nil
  root.physical_direct = nil
  root.last_travel = nil
  return root
end

local function stat(name, amount)
  local root = M.root()
  root.stats[name] = (root.stats[name] or 0) + (amount or 1)
end

local function record(action, pair, detail)
  local root = M.root()
  stat(action)
  root.recent[#root.recent + 1] = {
    tick = now(), action = tostring(action), station = safe(station_unit(pair)),
    priest = safe(priest_unit(pair)), detail = tostring(detail or ""),
  }
  while #root.recent > 120 do table.remove(root.recent, 1) end
end

local function repair_reverse_maps(pair, reason)
  if not valid_pair(pair) then return false end
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.pairs_by_station = storage.tech_priests.pairs_by_station or {}
  storage.tech_priests.pairs_by_priest = storage.tech_priests.pairs_by_priest or {}
  local changed = false
  if pair.station.unit_number and storage.tech_priests.pairs_by_station[pair.station.unit_number] ~= pair then
    storage.tech_priests.pairs_by_station[pair.station.unit_number] = pair
    changed = true
  end
  if pair.priest.unit_number and storage.tech_priests.pairs_by_priest[pair.priest.unit_number] ~= pair then
    storage.tech_priests.pairs_by_priest[pair.priest.unit_number] = pair
    changed = true
  end
  pair.station_unit = pair.station.unit_number
  pair.priest_unit = pair.priest.unit_number
  if changed then record("reverse-map-repaired-0509", pair, reason or "repair") end
  return changed
end

local function active_work(pair)
  if not pair then return false end
  local canonical = pair.canonical_action_0744
  if type(canonical) == "table" and canonical.phase and canonical.phase ~= "none" and canonical.phase ~= "complete" and canonical.phase ~= "aborted" then return true end
  local direct = pair.dispatcher_direct_0513
  if type(direct) == "table" and direct.phase and direct.phase ~= "none" and direct.phase ~= "complete" and direct.phase ~= "aborted" then return true end
  local queue = pair.order_queue_0469
  if queue and queue.current and queue.current.status == "active" then return true end
  if pair.emergency_craft and (pair.emergency_craft.station_craft_pending_0337 or pair.emergency_craft.craft_due_tick or pair.emergency_craft.current) then return true end
  local mode = lower(pair.mode)
  return mode:find("moving", 1, true) ~= nil or mode:find("travelling", 1, true) ~= nil or mode:find("craft", 1, true) ~= nil or mode:find("repair", 1, true) ~= nil or mode:find("combat", 1, true) ~= nil
end

local function wrap_order_refresh()
  if type(_G.tech_priests_0270_refresh_orders_for_pair) ~= "function" or rawget(_G, "TECH_PRIESTS_0509_PRE_REFRESH_ORDERS") then return true end
  local previous = _G.tech_priests_0270_refresh_orders_for_pair
  _G.TECH_PRIESTS_0509_PRE_REFRESH_ORDERS = previous
  _G.tech_priests_0270_refresh_orders_for_pair = function(pair, source, ...)
    local root = M.root()
    source = tostring(source or "unknown")
    local passive = source == "mouse-over" or source == "radar-priest-scan" or source == "overview-ui" or source:find("overview", 1, true)
    if root.enabled ~= false and root.refresh_debounce ~= false and passive and valid_pair(pair) and active_work(pair) then
      local key = tostring(station_unit(pair) or "nil") .. ":" .. source
      local last = root.last_refresh[key] or -1000000
      if now() - last < M.refresh_debounce_ticks then
        stat("order-refresh-suppressed-0509")
        return false
      end
      root.last_refresh[key] = now()
    end
    return previous(pair, source, ...)
  end
  return true
end

local function wrap_cascade()
  local ok, cascade = pcall(require, "scripts.core.emergency_cascade")
  if not (ok and cascade and type(cascade.cascade_from) == "function") or cascade.behavior_stack_cleanup_0509_wrapped then return true end
  cascade.behavior_stack_cleanup_0509_wrapped = true
  cascade.TECH_PRIESTS_0509_PRE_CASCADE_FROM = cascade.cascade_from
  cascade.cascade_from = function(leader, reason)
    local root = M.root()
    if root.enabled ~= false and root.cascade_debounce ~= false and leader and valid(leader.station) then
      local key = tostring(station_unit(leader) or "nil") .. ":" .. tostring(reason or "")
      local last = root.last_cascade[key] or -1000000
      if now() - last < M.cascade_debounce_ticks then
        record("cascade-suppressed-0509", leader, "reason=" .. safe(reason))
        return 0
      end
      root.last_cascade[key] = now()
    end
    return cascade.TECH_PRIESTS_0509_PRE_CASCADE_FROM(leader, reason)
  end
  return true
end

local function wrap_pair_dump()
  local diagnostics = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") or diagnostics.behavior_stack_cleanup_0509_wrapped then return true end
  local previous = diagnostics.pair_dump_lines
  diagnostics.behavior_stack_cleanup_0509_wrapped = true
  diagnostics.pair_dump_lines = function()
    local lines = previous()
    local root = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 BEHAVIOR-STACK-CLEANUP-0509 enabled=" .. safe(root.enabled)
      .. " reverse_repairs=" .. safe(root.stats["reverse-map-repaired-0509"] or 0)
      .. " refresh_suppressed=" .. safe(root.stats["order-refresh-suppressed-0509"] or 0)
      .. " cascade_suppressed=" .. safe(root.stats["cascade-suppressed-0509"] or 0)
    return lines
  end
  return true
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok, pair = pcall(_G.selected_pair_for_player, player); if ok and pair then return pair end end
  local selected = player and player.selected
  local root = storage and storage.tech_priests or nil
  if selected and selected.valid and root then
    if root.pairs_by_station and root.pairs_by_station[selected.unit_number] then return root.pairs_by_station[selected.unit_number] end
    if root.pairs_by_priest and root.pairs_by_priest[selected.unit_number] then return root.pairs_by_priest[selected.unit_number] end
  end
  return nil
end

local function install_command()
  if not (commands and commands.add_command) then return true end
  pcall(function() if commands.remove_command then commands.remove_command("tp-behavior-cleanup-0509") end end)
  commands.add_command("tp-behavior-cleanup-0509", "Tech Priests: inspect passive behavior-stack maintenance.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local parameter = lower(event and event.parameter or "status")
    local root = M.root()
    if parameter == "on" then root.enabled = true elseif parameter == "off" then root.enabled = false end
    if parameter == "refresh-on" then root.refresh_debounce = true elseif parameter == "refresh-off" then root.refresh_debounce = false end
    if parameter == "cascade-on" then root.cascade_debounce = true elseif parameter == "cascade-off" then root.cascade_debounce = false end
    if parameter == "all" then M.service(nil, M.service_budget) end
    local pair = selected_pair(player)
    local message = "[tp-behavior-cleanup-0509] enabled=" .. safe(root.enabled)
      .. " refresh=" .. safe(root.refresh_debounce) .. " cascade=" .. safe(root.cascade_debounce)
      .. " reverse_repairs=" .. safe(root.stats["reverse-map-repaired-0509"] or 0)
      .. " selected=" .. safe(pair and station_unit(pair) or "nil")
    if player and player.valid then player.print(message) elseif game and game.print then game.print(message) end
  end)
  return true
end

function M.service(_, budget)
  local root = M.root()
  if root.enabled == false then return { processed = 0, acted = 0, detail = "disabled" } end
  local limit = math.max(1, math.min(128, math.floor(tonumber(budget) or M.service_budget)))
  local processed, acted = 0, 0
  for _, pair in pairs(pair_map()) do
    if processed >= limit then break end
    if valid_pair(pair) then
      processed = processed + 1
      if repair_reverse_maps(pair, "broker-service-0509") then acted = acted + 1 end
    end
  end
  root.stats.service_processed = (root.stats.service_processed or 0) + processed
  root.stats.service_acted = (root.stats.service_acted or 0) + acted
  return { processed = processed, acted = acted, exhausted = processed >= limit, detail = "passive-reverse-map-maintenance" }
end

function M.install()
  if M._installed then return true end
  M.root()
  wrap_order_refresh()
  wrap_cascade()
  wrap_pair_dump()
  install_command()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not (broker and type(broker.register_service) == "function") then return false end
  local registered = broker.register_service({
    name = "behavior_stack_cleanup_0509", category = "maintenance",
    interval = M.service_interval, priority = 82, budget = M.service_budget,
    fn = M.service, note = "passive reverse-map repair and UI/cascade debounce only",
  })
  if not registered then return false end
  _G.TECH_PRIESTS_BEHAVIOR_STACK_CLEANUP_0509 = M
  M._installed = true
  if log then log("[Tech-Priests 0.1.674-dev] broker-owned passive behavior-stack maintenance installed") end
  return true
end

return M
