-- scripts/core/ammo_scavenge_priority_0740.lua
-- Tech Priests 0.1.674-dev
--
-- Ammunition scavenge-first authority.
--
-- One visible Tech-Priest has one hidden proxy weapon. The proxy may hold one
-- physical ammunition magazine, never a concealed reserve stack. When the pair
-- needs ammunition, already-produced ammunition in a nearby station/container
-- outranks raw mining, emergency crafting, and renewed combat assignment.

local M = {}
M.version = "0.1.674-dev"
M.storage_key = "ammo_scavenge_priority_0740"
M.tick_interval = 5
M.max_pairs_per_pulse = 64
M.fetch_priority = 1010
M.safety_priority = 2000
M.ammo_order = {
  "uranium-rounds-magazine",
  "piercing-rounds-magazine",
  "firearm-magazine",
}

local DIRECT_KINDS = {
  ["direct-mine-0273"] = true,
  ["direct-dirt-0273"] = true,
  ["direct-mine-0336"] = true,
  dirt = true,
}

local previous_combat_tick = nil

local function now()
  return game and game.tick or 0
end

local function valid(entity)
  return entity and entity.valid
end

local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end

local function lower(value)
  return string.lower(tostring(value or ""))
end

local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(function() return tostring(value) end)
  return ok and text or "?"
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

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
    recent = {},
    last_log = {},
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  state.last_log = state.last_log or {}
  return state
end

local function stat(name, amount)
  local state = root()
  state.stats[name] = (tonumber(state.stats[name]) or 0) + (amount or 1)
end

local function record(action, pair, detail, force)
  local state = root()
  stat(action)
  local event = {
    tick = now(),
    action = tostring(action or "event"),
    station = station_unit(pair),
    priest = priest_unit(pair),
    detail = tostring(detail or ""),
  }
  state.recent[#state.recent + 1] = event
  while #state.recent > 160 do table.remove(state.recent, 1) end
  local key = event.action .. ":" .. safe(event.station)
  local last = tonumber(state.last_log[key] or -1000000) or -1000000
  if force or now() - last >= 300 then
    state.last_log[key] = now()
    if log then
      log("[Tech-Priests 0.1.674-dev] " .. event.action
        .. " station=" .. safe(event.station)
        .. " priest=" .. safe(event.priest)
        .. " " .. safe(detail))
    end
  end
end

local function item_from(value)
  if type(value) == "string" then
    local name = lower(value)
    if name == "ammo" or name == "ammunition" or name == "magazine" then
      return "firearm-magazine"
    end
    return value
  end
  if type(value) ~= "table" then return nil end
  local current = value.current or value.request or value.task or value
  return item_from(current.item or current.item_name or current.output_item
    or current.requested_item or current.wanted_item or current.target_item
    or current.name or current.resource or current.kind)
end

local function item_is_ammo(item_name)
  if not item_name then return false end
  for _, preferred in ipairs(M.ammo_order) do
    if item_name == preferred then return true end
  end
  if prototypes and prototypes.item then
    local ok, prototype = pcall(function() return prototypes.item[item_name] end)
    if ok and prototype then
      local ok_type, prototype_type = pcall(function() return prototype.type end)
      if ok_type and prototype_type == "ammo" then return true end
    end
  end
  return false
end

local function inventory(entity, inventory_id)
  if not (valid(entity) and entity.get_inventory and inventory_id) then return nil end
  local ok, result = pcall(function() return entity.get_inventory(inventory_id) end)
  if ok and result and result.valid then return result end
  return nil
end

local function station_inventory(pair)
  if not (valid_pair(pair) and defines and defines.inventory) then return nil end
  return inventory(pair.station, defines.inventory.chest)
end

local function inventory_item_count(inv, item_name)
  if not (inv and inv.valid and item_name) then return 0 end
  local ok, count = pcall(function() return inv.get_item_count(item_name) end)
  return ok and (tonumber(count) or 0) or 0
end

local function station_ammo(pair)
  local hardener = rawget(_G, "TechPriestsProxyAmmoHardener0649")
  if hardener and type(hardener.station_ammo) == "function" then
    local ok, item_name, count = pcall(hardener.station_ammo, pair)
    if ok and item_name and tonumber(count or 0) > 0 then
      return item_name, tonumber(count) or 0
    end
  end
  local inv = station_inventory(pair)
  if not inv then return nil, 0 end
  for _, item_name in ipairs(M.ammo_order) do
    local count = inventory_item_count(inv, item_name)
    if count > 0 then return item_name, count end
  end
  if prototypes and prototypes.item then
    for item_name, prototype in pairs(prototypes.item) do
      local prototype_type = nil
      pcall(function() prototype_type = prototype.type end)
      if prototype_type == "ammo" then
        local count = inventory_item_count(inv, item_name)
        if count > 0 then return item_name, count end
      end
    end
  end
  return nil, 0
end

local function proxy_inventory(pair)
  local hardener = rawget(_G, "TechPriestsProxyAmmoHardener0649")
  if hardener and type(hardener.proxy_ammo_inventory) == "function" then
    local ok, inv, proxy = pcall(hardener.proxy_ammo_inventory, pair)
    if ok then return inv, proxy end
  end
  return nil, nil
end

local function proxy_ammo(pair)
  local inv = proxy_inventory(pair)
  if not (inv and inv.valid) then return nil, 0 end
  for index = 1, #inv do
    local stack = inv[index]
    if stack and stack.valid_for_read and item_is_ammo(stack.name) then
      return stack.name, tonumber(stack.count) or 0
    end
  end
  return nil, 0
end

local function ammo_ready(pair)
  local station_item, station_count = station_ammo(pair)
  local proxy_item, proxy_count = proxy_ammo(pair)
  return station_count > 0 or proxy_count > 0,
    station_item or proxy_item,
    station_count,
    proxy_count
end

local function stack_spec(stack, count)
  local spec = { name = stack.name, count = count }
  local quality = nil
  pcall(function() quality = stack.quality end)
  if type(quality) == "table" and quality.name then spec.quality = quality.name
  elseif type(quality) == "string" then spec.quality = quality end
  return spec
end

local function enforce_one_proxy_magazine(pair)
  local inv = proxy_inventory(pair)
  if not (inv and inv.valid) then return false end
  local destination = station_inventory(pair)
  local kept = false
  local changed = false

  for index = 1, #inv do
    local stack = inv[index]
    if stack and stack.valid_for_read and item_is_ammo(stack.name) then
      local current = tonumber(stack.count) or 0
      local allowed = kept and 0 or 1
      kept = true
      local excess = math.max(0, current - allowed)
      if excess > 0 then
        if not (destination and destination.valid) then
          record("proxy-surplus-return-blocked-0740", pair,
            "item=" .. safe(stack.name) .. " excess=" .. safe(excess) .. " reason=no-station-inventory")
        else
          local spec = stack_spec(stack, excess)
          local insertable = 0
          local ok_insertable, amount = pcall(function()
            return destination.get_insertable_count({ name = spec.name, quality = spec.quality })
          end)
          if ok_insertable then insertable = tonumber(amount) or 0 end
          local transfer = math.min(excess, insertable)
          if transfer > 0 then
            spec.count = transfer
            local removed = 0
            pcall(function() removed = inv.remove(spec) end)
            removed = tonumber(removed) or 0
            if removed > 0 then
              spec.count = removed
              local inserted = 0
              pcall(function() inserted = destination.insert(spec) end)
              inserted = tonumber(inserted) or 0
              if inserted < removed then
                spec.count = removed - inserted
                pcall(function() inv.insert(spec) end)
              end
              if inserted > 0 then
                changed = true
                record("proxy-surplus-returned-0740", pair,
                  "item=" .. safe(stack.name) .. " count=" .. safe(inserted), true)
              end
            end
          else
            record("proxy-surplus-return-blocked-0740", pair,
              "item=" .. safe(stack.name) .. " excess=" .. safe(excess) .. " reason=station-full")
          end
        end
      end
    end
  end
  return changed
end

local function ammo_text(value)
  local text = lower(value)
  return text:find("firearm%-magazine") ~= nil
    or text:find("piercing%-rounds%-magazine") ~= nil
    or text:find("uranium%-rounds%-magazine") ~= nil
    or text:find("missing%-ammo") ~= nil
    or text:find("survival%-ammo") ~= nil
    or text:find("no%-ammo") ~= nil
end

local function ammo_intent(pair)
  if not pair then return false end
  local fetch = pair.logistics_fetch_0527 or pair.logistics_fetch_0526
  if type(fetch) == "table" and item_is_ammo(item_from(fetch)) then return true end
  if pair.need_ammunition or pair.no_ammo_0295 or pair.pinned_no_ammo_0295 then return true end
  if ammo_text(pair.mode) or ammo_text(pair.blocker) or ammo_text(pair.last_blocker)
    or ammo_text(pair.emergency_blocker) or ammo_text(pair.priority_blocker) then return true end
  for _, value in ipairs({
    pair.logistic_requested_item,
    pair.requested_item,
    pair.active_supply_request,
    pair.supply_request,
    pair.inventory_scan,
    pair.scavenge,
    pair.emergency_craft,
    pair.direct_acquisition_task_0336,
    pair.active_acquisition_0333,
  }) do
    if item_is_ammo(item_from(value)) then return true end
  end
  local operation = pair.independent_emergency_operation_0184
    or pair.independent_emergency_operation
    or pair.emergency_operation
  if type(operation) == "table" then
    if item_is_ammo(item_from(operation.last_item or operation.requested_item or operation.item))
      or ammo_text(operation.phase)
      or ammo_text(operation.last_blocker_0264)
      or ammo_text(operation.last_blocker_0266)
      or ammo_text(operation.last_blocker_0267) then return true end
  end
  return false
end

local function fetch_state(pair)
  local fetch = pair and (pair.logistics_fetch_0527 or pair.logistics_fetch_0526) or nil
  if type(fetch) ~= "table" or not item_is_ammo(item_from(fetch)) then return nil end
  if fetch.phase == "moving-to-source" and valid(fetch.source) then return fetch end
  return nil
end

local function hard_return_active(pair)
  if not valid_pair(pair) then return false end
  local request = pair.movement_request_0418
  local owner = lower(request and request.owner or pair.movement_controller_owner_0418)
  local reason = lower(request and request.reason or pair.movement_controller_reason_0418)
  return lower(pair.mode):find("returning%-overleash") ~= nil
    or owner == "movement-bounds-0511"
    or reason:find("overleash%-return%-0511") ~= nil
end

local function clear_direct_current(pair, reason)
  if not pair then return false end
  local changed = false
  for _, key in ipairs({ "emergency_craft", "direct_acquisition_task_0336", "active_acquisition_0333" }) do
    local task = pair[key]
    local current = type(task) == "table" and (task.current or task) or nil
    if current and DIRECT_KINDS[tostring(current.kind or "")] then
      if task.current then task.current = nil end
      task.direct_due_tick_0273 = nil
      task.direct_due_tick_0312 = nil
      task.direct_due_tick_0315 = nil
      task.direct_due_tick_0336 = nil
      task.direct_due_tick_0513 = nil
      task.scan_due_tick = nil
      changed = true
    end
  end
  if pair.direct_acquisition_target_lock_0650 then
    pair.direct_acquisition_target_lock_0650 = nil
    changed = true
  end
  local request = pair.movement_request_0418
  if request and (lower(request.owner):find("direct", 1, true)
      or lower(request.reason):find("direct", 1, true)
      or lower(request.reason):find("acquisition", 1, true)) then
    pair.movement_request_0418 = nil
    changed = true
  end
  if changed then
    record("direct-acquisition-preempted-0740", pair, reason or "ammo-scavenge-first", true)
  end
  return changed
end

local function clear_if_ammo_field(pair, field)
  if item_is_ammo(item_from(pair[field])) then
    pair[field] = nil
    return true
  end
  return false
end

local function clear_ammo_warning_state(pair, reason)
  if not pair then return false end
  local changed = false
  for _, field in ipairs({
    "logistic_requested_item",
    "requested_item",
    "active_supply_request",
    "supply_request",
    "inventory_scan",
    "scavenge",
    "emergency_craft",
    "direct_acquisition_task_0336",
    "active_acquisition_0333",
  }) do
    changed = clear_if_ammo_field(pair, field) or changed
  end
  pair.logistic_requested_count = nil
  pair.need_ammunition = nil
  pair.no_ammo_0295 = nil
  pair.pinned_no_ammo_0295 = nil
  pair.last_combat_fail_0293 = nil
  pair.last_combat_fail_0295 = nil
  pair.last_combat_fail_tick_0293 = nil
  pair.last_combat_fail_tick_0295 = nil
  pair.next_ammo_supply_retry_tick_0295 = 0

  for _, field in ipairs({ "blocker", "last_blocker", "emergency_blocker", "priority_blocker" }) do
    if ammo_text(pair[field]) then pair[field] = nil; changed = true end
  end
  if item_is_ammo(item_from(pair.last_item)) then pair.last_item = nil; changed = true end

  local operation = pair.independent_emergency_operation_0184
    or pair.independent_emergency_operation
    or pair.emergency_operation
  if type(operation) == "table" then
    if item_is_ammo(item_from(operation.last_item)) or ammo_text(operation.phase) then
      operation.last_item = nil
      operation.last_blocker_0264 = nil
      operation.last_blocker_0266 = nil
      operation.last_blocker_0267 = nil
      operation.satisfied_item_0740 = "ammunition"
      operation.satisfied_tick_0740 = now()
      if ammo_text(operation.phase) then operation.phase = "survival-satisfied" end
      changed = true
    end
  end

  local fetch = pair.logistics_fetch_0527 or pair.logistics_fetch_0526
  if type(fetch) == "table" and item_is_ammo(item_from(fetch)) then
    fetch.phase = "satisfied"
    fetch.satisfied_tick = now()
    changed = true
  end

  local deferred = pair.ammo_scavenge_deferred_combat_0740
  if valid(deferred) then
    pair.combat_target = deferred
  end
  pair.ammo_scavenge_deferred_combat_0740 = nil

  local mode = lower(pair.mode)
  if mode:find("missing%-ammo") or mode:find("pinned%-no%-ammo") or mode:find("survival%-ammo") then
    pair.mode = valid(pair.combat_target) and "defending" or "idle"
    changed = true
  end

  if pair.active_leaf_task_0655 and item_is_ammo(item_from(pair.active_leaf_task_0655)) then
    pair.active_leaf_task_0655 = nil
    pair.actual_task_status_0655 = nil
    pair.current_work_target_0655 = nil
    changed = true
  end

  if changed then
    pair.last_ammo_satisfied_0740 = { tick = now(), reason = tostring(reason or "ammo-present") }
    record("ammo-warning-cleared-0740", pair, "reason=" .. safe(reason), true)
  end
  return changed
end

local function defer_combat(pair)
  if valid(pair and pair.combat_target) then
    pair.ammo_scavenge_deferred_combat_0740 = pair.combat_target
    pair.combat_target = nil
    stat("combat-deferred")
  end
end

local function fetch_truth(pair)
  local fetch = fetch_state(pair)
  if not (fetch and valid(fetch.source)) then return nil end
  local position = fetch.source.position
  local item = item_from(fetch) or "firearm-magazine"
  return {
    family = "logistics",
    phase = "fetch-ammunition",
    entity = fetch.source,
    position = { x = position.x, y = position.y },
    item = item,
    parent_item = item,
    label = "Scavenging " .. tostring(item):gsub("%-", " ") .. " first",
    owner = "ammo-scavenge-priority-0740",
    priority = M.fetch_priority,
    radius = 1.15,
    can_move = true,
    source = "ammo-scavenge-priority-0740",
  }
end

local function safety_truth(pair)
  if not hard_return_active(pair) then return nil end
  local position = pair.station.position
  return {
    family = "safety",
    phase = "return-overleash",
    entity = pair.station,
    position = { x = position.x, y = position.y },
    item = nil,
    parent_item = nil,
    label = "Returning inside Cogitator range",
    owner = "movement-bounds-0511",
    priority = M.safety_priority,
    radius = 1.0,
    can_move = true,
    source = "overleash-return-0511",
  }
end

local function patch_leaf_truth()
  local ok, leaf = pcall(require, "scripts.core.active_leaf_task_truth_0655")
  if not (ok and leaf and type(leaf.truth) == "function") or leaf.ammo_scavenge_0740_wrapped then return false end
  leaf.ammo_scavenge_0740_wrapped = true
  leaf.TECH_PRIESTS_0740_PRE_TRUTH = leaf.truth
  leaf.truth = function(pair)
    return safety_truth(pair) or fetch_truth(pair) or leaf.TECH_PRIESTS_0740_PRE_TRUTH(pair)
  end
  return true
end

local function patch_direct_executor()
  local ok, executor = pcall(require, "scripts.core.direct_acquisition_executor_0513")
  if not (ok and executor and type(executor.service_pair) == "function") or executor.ammo_scavenge_0740_wrapped then return false end
  executor.ammo_scavenge_0740_wrapped = true
  executor.TECH_PRIESTS_0740_PRE_SERVICE_PAIR = executor.service_pair
  executor.service_pair = function(pair, reason, ...)
    if hard_return_active(pair) then
      clear_direct_current(pair, "hard-leash-return")
      return false, "hard-leash-return-0740"
    end
    if fetch_state(pair) then
      clear_direct_current(pair, "active-ammo-fetch")
      return false, "ammo-fetch-has-priority-0740"
    end
    if ammo_intent(pair) then
      local ready = ammo_ready(pair)
      if not ready then
        local acted, why = M.service_pair(pair, reason or "direct-executor-preempt")
        if acted or fetch_state(pair) then
          return false, why or "ammo-scavenge-first-0740"
        end
      end
    end
    return executor.TECH_PRIESTS_0740_PRE_SERVICE_PAIR(pair, reason, ...)
  end
  return true
end

local function patch_combat_tick()
  if type(rawget(_G, "tech_priests_0293_force_combat_tick")) ~= "function" or previous_combat_tick then return false end
  previous_combat_tick = rawget(_G, "tech_priests_0293_force_combat_tick")
  _G.TECH_PRIESTS_0740_PRE_FORCE_COMBAT_TICK = previous_combat_tick
  _G.tech_priests_0293_force_combat_tick = function(pair, reason, force)
    if valid_pair(pair) and ammo_intent(pair) then
      local ready = ammo_ready(pair)
      if not ready then
        local acted = M.service_pair(pair, reason or "combat-preempt")
        if acted or fetch_state(pair) then return true end
      end
    end
    return previous_combat_tick(pair, reason, force)
  end
  _G.tech_priests_0292_force_combat_tick = _G.tech_priests_0293_force_combat_tick
  return true
end

local function handler_source(entry)
  local source = tostring(entry and entry.source or "")
  local first_line = tonumber(entry and entry.line or 0) or 0
  if entry and type(entry.handler) == "function" and debug and debug.getinfo then
    local ok, info = pcall(debug.getinfo, entry.handler, "S")
    if ok and info then
      source = source .. " " .. tostring(info.source or info.short_src or "")
      first_line = tonumber(info.linedefined or first_line) or first_line
    end
  end
  return source, first_line
end

local function decommission_legacy_direct_guard()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  local route = registry and registry.nth_tick_routes and registry.nth_tick_routes["61"]
  if type(route) ~= "table" then return false end
  local kept, removed = {}, 0
  for _, entry in ipairs(route) do
    local source, first_line = handler_source(entry)
    local legacy_direct = source:find("control_legacy_part_016.lua", 1, true)
      and first_line >= 800 and first_line <= 900
    if legacy_direct then
      removed = removed + 1
    else
      kept[#kept + 1] = entry
    end
  end
  if removed > 0 then
    registry.nth_tick_routes["61"] = kept
    local bounds = rawget(_G, "TechPriestsMovementBounds0511")
    if bounds and type(bounds.root) == "function" then
      local ok, state = pcall(bounds.root)
      if ok and state then
        state.removed_routes = (tonumber(state.removed_routes) or 0) + removed
        state.route_decommissioned = true
      end
    end
    record("legacy-direct-pulse-disabled-0740", nil, "removed=" .. tostring(removed), true)
  end
  return removed > 0
end

local function configure_proxy_hardener()
  local hardener = rawget(_G, "TechPriestsProxyAmmoHardener0649")
  if not hardener then
    local ok, module = pcall(require, "scripts.core.proxy_ammo_hardener_0649")
    if ok then hardener = module end
  end
  if hardener then
    hardener.load_batch = 1
    hardener.max_internal_magazines_0740 = 1
  end
  return hardener ~= nil
end

function M.service_pair(pair, reason)
  if root().enabled == false or not valid_pair(pair) then return false, "disabled-or-invalid" end
  configure_proxy_hardener()
  enforce_one_proxy_magazine(pair)

  local ready, item_name = ammo_ready(pair)
  if ready then
    local hardener = rawget(_G, "TechPriestsProxyAmmoHardener0649")
    if hardener and type(hardener.load_proxy_from_station) == "function" then
      pcall(hardener.load_proxy_from_station, pair, "single-magazine-0740")
      enforce_one_proxy_magazine(pair)
    end
    clear_ammo_warning_state(pair, reason or "ammo-present")
    return false, "ammo-ready"
  end

  if not ammo_intent(pair) then return false, "no-ammo-intent" end
  if hard_return_active(pair) then
    clear_direct_current(pair, "hard-leash-return")
    return true, "hard-leash-return"
  end

  pair.logistic_requested_item = "firearm-magazine"
  pair.logistic_requested_count = 1
  pair.need_ammunition = true
  defer_combat(pair)

  local ok, logistics = pcall(require, "scripts.core.logistics_fetch_executor_0527")
  if not (ok and logistics and type(logistics.service_pair) == "function") then
    local deferred = pair.ammo_scavenge_deferred_combat_0740
    if valid(deferred) then pair.combat_target = deferred end
    pair.ammo_scavenge_deferred_combat_0740 = nil
    return false, "logistics-fetch-unavailable"
  end

  local acted, why = logistics.service_pair(pair, reason or "ammo-scavenge-first-0740")
  if acted or fetch_state(pair) then
    clear_direct_current(pair, "ammo-scavenge-first")
    pair.mode = fetch_state(pair) and "moving-to-known-ammo-source" or pair.mode
    record("ammo-scavenge-first-0740", pair,
      "result=" .. safe(why) .. " source=" .. safe(fetch_state(pair) and fetch_state(pair).source_name), true)
    return true, why or "ammo-scavenge-first"
  end

  local deferred = pair.ammo_scavenge_deferred_combat_0740
  if valid(deferred) then pair.combat_target = deferred end
  pair.ammo_scavenge_deferred_combat_0740 = nil
  return false, why or "no-known-ammo-source"
end

function M.service_all(reason)
  if root().enabled == false then return false end
  configure_proxy_hardener()
  decommission_legacy_direct_guard()
  patch_leaf_truth()
  patch_direct_executor()
  patch_combat_tick()
  local processed = 0
  for _, pair in pairs(pair_map()) do
    if processed >= M.max_pairs_per_pulse then break end
    if valid_pair(pair) then
      M.service_pair(pair, reason or "pulse")
      processed = processed + 1
    end
  end
  return true
end

function M.install()
  root()
  configure_proxy_hardener()
  decommission_legacy_direct_guard()
  patch_leaf_truth()
  patch_direct_executor()
  patch_combat_tick()
  _G.TechPriestsAmmoScavengePriority0740 = M

  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({
      name = "ammo_scavenge_priority_0740",
      category = "logistics",
      interval = M.tick_interval,
      priority = 2,
      budget = 8,
      fn = function()
        M.service_all("broker")
        return true
      end,
      note = "one-magazine proxy and physical ammo scavenge before mining/crafting/combat retry",
    })
  else
    local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if registry and type(registry.on_nth_tick) == "function" then
      registry.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end, {
        owner = "ammo_scavenge_priority_0740",
        category = "logistics",
        priority = "first",
      })
    end
  end

  if log then
    log("[Tech-Priests 0.1.674-dev] ammo scavenge-first authority installed; proxy capacity=1 magazine")
  end
  return true
end

return M
