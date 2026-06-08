-- scripts/core/emergency_supply_reserve_0497.lua
-- Tech Priests 0.1.497
--
-- Emergency reserve doctrine:
--   Emergency survival requests are single-use demands. A priest who needs ammo,
--   repair, or consecration should obtain one unit, use/hold it, then let the
--   current writ finish or promote. Bulk reserves are handled by a slower passive
--   balancing pass instead of by blocking the priest on a 10/49/stack-sized demand.

local M = {}
M.version = "0.1.497"
M.storage_key = "emergency_supply_reserve_0497"
M.tick_interval = 97
M.scan_radius = 28
M.max_pairs_per_tick = 16
M.critical_items = {
  ["firearm-magazine"] = true,
  ["piercing-rounds-magazine"] = true,
  ["uranium-rounds-magazine"] = true,
  ["repair-pack"] = true,
  ["sacred-machine-oil"] = true,
  ["machine-maintenance-litany"] = true,
  ["ritual-of-machine-appeasement"] = true,
}
M.reserve_floor = {
  ["firearm-magazine"] = 1,
  ["piercing-rounds-magazine"] = 1,
  ["uranium-rounds-magazine"] = 1,
  ["repair-pack"] = 1,
  ["sacred-machine-oil"] = 1,
  ["machine-maintenance-litany"] = 1,
  ["ritual-of-machine-appeasement"] = 1,
}

local previous = {}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function safe(v) local ok, s = pcall(function() return tostring(v) end); return ok and s or "?" end
local function lower(v) return string.lower(tostring(v or "")) end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
    recent = {},
  }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  if root.enabled == nil then root.enabled = true end
  root.stats = root.stats or {}
  root.recent = root.recent or {}
  return root
end

local function stat(name, delta)
  local r = ensure_root()
  r.stats[name] = (tonumber(r.stats[name]) or 0) + (delta or 1)
end

local function record(action, pair, detail)
  local r = ensure_root()
  r.recent[#r.recent + 1] = {
    tick = now(),
    action = action,
    station = pair and pair.station and pair.station.valid and pair.station.unit_number or "?",
    detail = detail or "",
  }
  while #r.recent > 20 do table.remove(r.recent, 1) end
  if log then log("[Tech-Priests 0.1.497] " .. tostring(action) .. " station=" .. tostring(pair and pair.station and pair.station.valid and pair.station.unit_number or "?") .. " " .. tostring(detail or "")) end
end

local function item_exists(name)
  return name and prototypes and prototypes.item and prototypes.item[name] ~= nil
end

local function is_critical(item)
  if not item then return false end
  return M.critical_items[item] == true
end

local function item_from(v)
  if type(v) == "string" then return v end
  if type(v) ~= "table" then return nil end
  if v.item_name then return v.item_name end
  if v.item then return v.item end
  if v.output_item then return v.output_item end
  if v.wanted_item then return v.wanted_item end
  if v.requested_item then return v.requested_item end
  if v.name then return v.name end
  if v.kind == "ammo" then return "firearm-magazine" end
  if v.kind == "repair" then return "repair-pack" end
  return nil
end

local function request_item(pair)
  if not pair then return nil end
  return item_from(pair.active_supply_request)
      or item_from(pair.supply_request)
      or item_from(pair.inventory_scan and pair.inventory_scan.request)
      or item_from(pair.scavenge)
      or item_from(pair.emergency_craft)
      or item_from(pair.direct_acquisition_task_0336)
      or pair.logistic_requested_item
      or item_from(pair.active_order_0469)
end

local function safe_inv(entity, inv_id)
  if not (valid(entity) and entity.get_inventory and inv_id) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inv_id) end)
  if ok and inv and inv.valid then return inv end
  return nil
end

local function add_inv(out, seen, inv, owner, label)
  if inv and inv.valid and not seen[tostring(inv)] then
    out[#out + 1] = { inv = inv, owner = owner, label = label or "inventory" }
    seen[tostring(inv)] = true
  end
end

local function station_inventories(pair)
  local out, seen = {}, {}
  if not (pair and valid(pair.station) and defines and defines.inventory) then return out end
  local ids = {
    defines.inventory.chest,
    defines.inventory.assembling_machine_input,
    defines.inventory.assembling_machine_output,
    defines.inventory.furnace_source,
    defines.inventory.furnace_result,
  }
  for _, id in ipairs(ids) do add_inv(out, seen, safe_inv(pair.station, id), pair.station, "station") end
  return out
end

local function priest_inventories(pair)
  local out, seen = {}, {}
  if not (pair and valid(pair.priest) and defines and defines.inventory) then return out end
  if pair.priest.get_main_inventory then
    local ok, inv = pcall(function() return pair.priest.get_main_inventory() end)
    if ok then add_inv(out, seen, inv, pair.priest, "priest-main") end
  end
  add_inv(out, seen, safe_inv(pair.priest, defines.inventory.character_main), pair.priest, "priest-main")
  add_inv(out, seen, safe_inv(pair.priest, defines.inventory.chest), pair.priest, "priest-chest")
  add_inv(out, seen, safe_inv(pair.priest, defines.inventory.spider_trunk), pair.priest, "priest-spider")
  add_inv(out, seen, safe_inv(pair.priest, defines.inventory.car_trunk), pair.priest, "priest-vehicle")
  return out
end

local function entity_inventory(entity)
  if not (valid(entity) and defines and defines.inventory) then return nil end
  return safe_inv(entity, defines.inventory.chest)
      or safe_inv(entity, defines.inventory.assembling_machine_output)
      or safe_inv(entity, defines.inventory.assembling_machine_input)
      or safe_inv(entity, defines.inventory.furnace_result)
      or safe_inv(entity, defines.inventory.furnace_source)
end

local function nearby_station_containers(pair)
  local out, seen = {}, {}
  if not (pair and valid(pair.station) and pair.station.surface and defines and defines.inventory) then return out end
  local ents = {}
  pcall(function()
    ents = pair.station.surface.find_entities_filtered({
      position = pair.station.position,
      radius = M.scan_radius,
      force = pair.station.force,
      type = { "container", "logistic-container" },
    }) or {}
  end)
  for _, e in pairs(ents) do
    if valid(e) then add_inv(out, seen, entity_inventory(e), e, "station-container") end
  end
  return out
end

local function inv_count(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, count = pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(count) or 0) or 0
end

local function inv_insert(inv, item, count)
  if not (inv and inv.valid and item and count and count > 0) then return 0 end
  local ok, inserted = pcall(function() return inv.insert({ name = item, count = count }) end)
  return ok and (tonumber(inserted) or 0) or 0
end

local function inv_remove(inv, item, count)
  if not (inv and inv.valid and item and count and count > 0) then return 0 end
  local ok, removed = pcall(function() return inv.remove({ name = item, count = count }) end)
  return ok and (tonumber(removed) or 0) or 0
end

local function station_count(pair, item)
  local total = 0
  for _, s in ipairs(station_inventories(pair)) do total = total + inv_count(s.inv, item) end
  return total
end

local function deposit_to_station(pair, item, count)
  if not (pair and item and count and count > 0) then return false, "invalid" end
  if type(rawget(_G, "tech_priests_safe_deposit_item")) == "function" then
    local ok, did, why = pcall(rawget(_G, "tech_priests_safe_deposit_item"), pair, item, count, "emergency-reserve-balance-0497")
    if ok and did then return true, why or "steward" end
  end
  for _, s in ipairs(station_inventories(pair)) do
    local inserted = inv_insert(s.inv, item, count)
    if inserted >= count then return true, "station" end
    if inserted > 0 then count = count - inserted end
  end
  return false, "no-space"
end

local function clamp_table_request(t)
  if type(t) ~= "table" then return false end
  local item = item_from(t)
  if not is_critical(item) then return false end
  local changed = false
  for _, key in ipairs({ "count", "amount", "required_count", "requested_count", "target_count", "needed", "minimum" }) do
    if tonumber(t[key]) and tonumber(t[key]) ~= 1 then
      t[key] = 1
      changed = true
    end
  end
  if t.request and type(t.request) == "table" then changed = clamp_table_request(t.request) or changed end
  if t.current and type(t.current) == "table" then changed = clamp_table_request(t.current) or changed end
  return changed
end

local function clamp_pair(pair)
  if not pair then return false end
  local changed = false
  if is_critical(pair.logistic_requested_item) and tonumber(pair.logistic_requested_count or 1) ~= 1 then
    pair.logistic_requested_count = 1
    changed = true
  end
  for _, t in ipairs({
    pair.active_supply_request,
    pair.supply_request,
    pair.inventory_scan,
    pair.inventory_scan and pair.inventory_scan.request,
    pair.scavenge,
    pair.emergency_craft,
    pair.direct_acquisition_task_0336,
    pair.active_acquisition_0333,
    pair.active_task,
    pair.active_task_0285,
  }) do
    changed = clamp_table_request(t) or changed
  end
  local q = pair.order_queue_0469
  if q then
    if q.current and is_critical(q.current.item) and tonumber(q.current.count or 1) ~= 1 then q.current.count = 1; changed = true end
    for _, order in ipairs(q.pending or {}) do
      if order and is_critical(order.item) and tonumber(order.count or 1) ~= 1 then order.count = 1; changed = true end
    end
  end
  if changed then stat("clamped_requests"); record("clamped-emergency-request", pair, "item=" .. tostring(request_item(pair))) end
  return changed
end

local function item_matches(v, item)
  if not item then return false end
  local found = item_from(v)
  return found == item or (found == "ammo" and item == "firearm-magazine") or (found == "repair" and item == "repair-pack")
end

local function clear_supply_state(pair, item, reason)
  if not pair or not item then return false end
  local changed = false
  if pair.logistic_requested_item == item then pair.logistic_requested_item = nil; pair.logistic_requested_count = nil; changed = true end
  if item_matches(pair.active_supply_request, item) then pair.active_supply_request = nil; changed = true end
  if item_matches(pair.supply_request, item) then pair.supply_request = nil; changed = true end
  if pair.inventory_scan and (item_matches(pair.inventory_scan, item) or item_matches(pair.inventory_scan.request, item)) then pair.inventory_scan = nil; changed = true end
  if item_matches(pair.scavenge, item) then pair.scavenge = nil; changed = true end
  if item_matches(pair.emergency_craft, item) then pair.emergency_craft = nil; changed = true end
  if item_matches(pair.direct_acquisition_task_0336, item) then pair.direct_acquisition_task_0336 = nil; changed = true end
  if item_matches(pair.active_acquisition_0333, item) then pair.active_acquisition_0333 = nil; changed = true end

  local q = pair.order_queue_0469
  if q then
    if q.current and q.current.item == item then
      q.history = q.history or {}
      q.history[#q.history + 1] = { key = q.current.key, kind = q.current.kind, item = q.current.item, status = "complete", reason = reason or "emergency-satisfied-0497", tick = now() }
      while #q.history > 12 do table.remove(q.history, 1) end
      q.current.status = "complete"
      q.current.finished_tick = now()
      q.current.finish_reason = reason or "emergency-satisfied-0497"
      q.current = nil
      pair.active_order_0469 = nil
      changed = true
    end
    local keep = {}
    q.pending_keys = {}
    for _, order in ipairs(q.pending or {}) do
      if order and order.item == item then
        q.history = q.history or {}
        q.history[#q.history + 1] = { key = order.key, kind = order.kind, item = order.item, status = "complete", reason = reason or "emergency-satisfied-0497", tick = now() }
        changed = true
      elseif order and order.key then
        keep[#keep + 1] = order
        q.pending_keys[order.key] = true
      end
    end
    q.pending = keep
  end

  local op = pair.independent_emergency_operation_0184
  if type(op) == "table" and op.last_item == item then
    op.last_blocker_0264 = nil
    op.last_blocker_0266 = nil
    op.last_blocker_0267 = nil
    op.satisfied_item_0497 = item
    op.satisfied_tick_0497 = now()
    if lower(op.phase):find("survival", 1, true) then op.phase = "survival-satisfied" end
    changed = true
  end

  if changed then
    stat("satisfied_requests")
    pair.last_emergency_supply_satisfied_0497 = { tick = now(), item = item, reason = reason }
    if pair.mode and lower(pair.mode):find("emergency", 1, true) then pair.mode = "returning" end
    record("satisfied-emergency-request", pair, "item=" .. tostring(item) .. " reason=" .. tostring(reason))
  end
  return changed
end

local function compatible_pair(source, target)
  return source and target and source ~= target and valid(source.station) and valid(target.station) and source.station.force == target.station.force and source.station.surface == target.station.surface
end

local function all_source_inventories(source_pair, include_station_floor)
  local out = {}
  for _, s in ipairs(priest_inventories(source_pair)) do out[#out + 1] = s end
  for _, s in ipairs(station_inventories(source_pair)) do out[#out + 1] = s end
  -- 0.1.526: do not directly reserve-balance from loose nearby containers.
  -- Those are now known-storage fetch sources and require a visible priest trip
  -- through logistics_fetch_executor_0526 before the item may enter station stock.
  if include_station_floor and false then
    for _, s in ipairs(nearby_station_containers(source_pair)) do out[#out + 1] = s end
  end
  return out
end

local function transfer_from_network(target_pair, item, count)
  if not (valid_pair(target_pair) and is_critical(item)) then return 0 end
  count = math.max(1, tonumber(count) or 1)
  local needed = math.max(0, count - station_count(target_pair, item))
  if needed <= 0 then return 0 end
  local moved = 0
  for _, source_pair in pairs(pair_map()) do
    if needed <= 0 then break end
    if compatible_pair(source_pair, target_pair) then
      local floor = M.reserve_floor[item] or 1
      for _, src in ipairs(all_source_inventories(source_pair, true)) do
        if needed <= 0 then break end
        local have = inv_count(src.inv, item)
        local is_priest = src.label and tostring(src.label):find("priest", 1, true)
        local surplus = is_priest and have or math.max(0, have - floor)
        if surplus > 0 then
          local take = math.min(needed, surplus)
          local removed = inv_remove(src.inv, item, take)
          if removed > 0 then
            local ok = deposit_to_station(target_pair, item, removed)
            if ok then
              needed = needed - removed
              moved = moved + removed
              stat("balanced_items", removed)
              record("balanced-emergency-reserve", target_pair, "item=" .. tostring(item) .. " count=" .. tostring(removed) .. " from=" .. tostring(source_pair.station and source_pair.station.unit_number))
            else
              inv_insert(src.inv, item, removed)
              return moved
            end
          end
        end
      end
    end
  end
  return moved
end

local function satisfy_if_possible(pair, item, reason)
  if not (valid_pair(pair) and is_critical(item)) then return false end
  if station_count(pair, item) < 1 then transfer_from_network(pair, item, 1) end
  if station_count(pair, item) >= 1 then
    clear_supply_state(pair, item, reason or "station-already-has-critical-item")
    return true
  end
  return false
end

function M.service_pair(pair)
  if not valid_pair(pair) then return false end
  if type(rawget(_G, "tech_priests_inventory_steward_unload")) == "function" then
    pcall(rawget(_G, "tech_priests_inventory_steward_unload"), pair, "emergency-reserve-0497")
  end
  clamp_pair(pair)
  local item = request_item(pair)
  if is_critical(item) then
    if satisfy_if_possible(pair, item, "emergency-supply-present-0497") then return true end
  end
  -- Passive reserve balancing: give every paired station one unit of each critical
  -- reserve item when another same-surface station/priest cargo has surplus.
  for item_name in pairs(M.critical_items) do
    if station_count(pair, item_name) < 1 then transfer_from_network(pair, item_name, 1) end
  end
  return false
end

function M.service_all()
  local root = ensure_root()
  if root.enabled == false then return end
  local n = 0
  for _, pair in pairs(pair_map()) do
    if n >= M.max_pairs_per_tick then break end
    if valid_pair(pair) then M.service_pair(pair); n = n + 1 end
  end
  root.last_service_tick = now()
end

local function clamp_survival_list(list)
  if type(list) ~= "table" then return list end
  for _, req in pairs(list) do
    if type(req) == "table" and is_critical(req.item) then req.count = 1 end
  end
  return list
end

function M.install_wrappers()
  TECH_PRIESTS_SURVIVAL_AMMO_COUNT_0266 = 1
  TECH_PRIESTS_SURVIVAL_REPAIR_COUNT_0266 = 1
  TECH_PRIESTS_SURVIVAL_OIL_COUNT_0266 = 1

  if type(rawget(_G, "tech_priests_0266_required_survival_items")) == "function" and not previous.required_survival then
    previous.required_survival = rawget(_G, "tech_priests_0266_required_survival_items")
    _G.TECH_PRIESTS_0497_PRE_REQUIRED_SURVIVAL = previous.required_survival
    _G.tech_priests_0266_required_survival_items = function(...)
      local list = previous.required_survival(...)
      return clamp_survival_list(list)
    end
  end

  if type(rawget(_G, "tech_priests_emergency_operation_acquire_item_0185")) == "function" and not previous.emergency_acquire then
    previous.emergency_acquire = rawget(_G, "tech_priests_emergency_operation_acquire_item_0185")
    _G.TECH_PRIESTS_0497_PRE_EMERGENCY_ACQUIRE = previous.emergency_acquire
    _G.tech_priests_emergency_operation_acquire_item_0185 = function(pair, item_name, op, count, depth)
      if is_critical(item_name) then
        clamp_pair(pair)
        if satisfy_if_possible(pair, item_name, "pre-acquire-critical-present-0497") then return true end
        count = 1
      end
      return previous.emergency_acquire(pair, item_name, op, count, depth)
    end
  end

  if type(rawget(_G, "build_supply_request")) == "function" and not previous.build_supply_request then
    previous.build_supply_request = rawget(_G, "build_supply_request")
    _G.TECH_PRIESTS_0497_PRE_BUILD_SUPPLY_REQUEST = previous.build_supply_request
    _G.build_supply_request = function(pair, kind, target)
      local req = previous.build_supply_request(pair, kind, target)
      clamp_table_request(req)
      return req
    end
  end

  if type(rawget(_G, "issue_station_logistic_request")) == "function" and not previous.issue_station_logistic_request then
    previous.issue_station_logistic_request = rawget(_G, "issue_station_logistic_request")
    _G.TECH_PRIESTS_0497_PRE_ISSUE_LOGISTIC_REQUEST = previous.issue_station_logistic_request
    _G.issue_station_logistic_request = function(pair, request)
      clamp_table_request(request)
      local item = item_from(request)
      if is_critical(item) and satisfy_if_possible(pair, item, "pre-logistic-critical-present-0497") then return true end
      return previous.issue_station_logistic_request(pair, request)
    end
  end

  if type(rawget(_G, "maybe_start_supply_scavenge")) == "function" and not previous.maybe_supply_scavenge then
    previous.maybe_supply_scavenge = rawget(_G, "maybe_start_supply_scavenge")
    _G.TECH_PRIESTS_0497_PRE_MAYBE_SUPPLY_SCAVENGE = previous.maybe_supply_scavenge
    _G.maybe_start_supply_scavenge = function(pair, kind, target)
      local item = (pair and pair.active_supply_request and item_from(pair.active_supply_request)) or kind
      if item == "ammo" then item = "firearm-magazine" end
      if item == "repair" then item = "repair-pack" end
      if is_critical(item) and satisfy_if_possible(pair, item, "pre-scavenge-critical-present-0497") then return true end
      return previous.maybe_supply_scavenge(pair, kind, target)
    end
  end

  if type(rawget(_G, "tech_priests_0285_assign_task")) == "function" and not previous.assign_task then
    previous.assign_task = rawget(_G, "tech_priests_0285_assign_task")
    _G.TECH_PRIESTS_0497_PRE_ASSIGN_TASK = previous.assign_task
    _G.tech_priests_0285_assign_task = function(pair, task, reason)
      clamp_table_request(task)
      local item = item_from(task)
      if is_critical(item) and satisfy_if_possible(pair, item, "pre-assign-critical-present-0497") then return true end
      return previous.assign_task(pair, task, reason)
    end
  end
end

function M.wrap_diagnostics()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics") or rawget(_G, "TECH_PRIESTS_EMERGENCY_DIAGNOSTICS")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.emergency_reserve_wrapped_0497 then return false end
  local old = diag.pair_dump_lines
  diag.emergency_reserve_wrapped_0497 = true
  diag.pair_dump_lines = function(...)
    local lines = old(...)
    lines = type(lines) == "table" and lines or {}
    local root = ensure_root()
    lines[#lines+1] = "PAIR-DUMP-0468 EMERGENCY-RESERVE-0497 BEGIN enabled=" .. tostring(root.enabled) .. " clamped=" .. tostring(root.stats.clamped_requests or 0) .. " satisfied=" .. tostring(root.stats.satisfied_requests or 0) .. " balanced=" .. tostring(root.stats.balanced_items or 0)
    for i = math.max(1, #root.recent - 8), #root.recent do
      local r = root.recent[i]
      if r then lines[#lines+1] = "PAIR-DUMP-0468 reserve0497[" .. tostring(i) .. "] tick=" .. tostring(r.tick) .. " action=" .. tostring(r.action) .. " station=" .. tostring(r.station) .. " " .. tostring(r.detail) end
    end
    lines[#lines+1] = "PAIR-DUMP-0468 EMERGENCY-RESERVE-0497 END"
    return lines
  end
  return true
end

function M.commands()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-emergency-reserve-0497") end end)
  commands.add_command("tp-emergency-reserve-0497", "Tech Priests: emergency single-item reserve balancer. Usage: status|all|on|off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local root = ensure_root()
    local p = tostring(event.parameter or "status")
    if p == "on" then root.enabled = true end
    if p == "off" then root.enabled = false end
    if p == "all" then M.service_all() end
    if player then
      player.print("[tp-emergency-reserve-0497] enabled=" .. tostring(root.enabled)
        .. " clamped=" .. tostring(root.stats.clamped_requests or 0)
        .. " satisfied=" .. tostring(root.stats.satisfied_requests or 0)
        .. " balanced=" .. tostring(root.stats.balanced_items or 0))
    end
  end)
end

function M.install()
  ensure_root()
  M.install_wrappers()
  M.wrap_diagnostics()
  M.commands()
  _G.TECH_PRIESTS_EMERGENCY_RESERVE_0497 = M
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if R and type(R.on_nth_tick) == "function" then
    R.on_nth_tick(M.tick_interval, function() M.service_all() end, { owner = "emergency_supply_reserve_0497", category = "inventory", priority = "late" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.tick_interval, function() M.service_all() end)
  end
  if log then log("[Tech-Priests 0.1.497] emergency supply reserve installed; survival ammo/repair/consecration demands are single-item and passive reserve balancing is active") end
  return true
end

return M
