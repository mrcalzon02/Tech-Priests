-- Tech Priests 0.1.674-dev physical artillery ammunition logistics.
--
-- Services only 0712 manual-ammo-service-eligible reports. Fixed artillery uses
-- artillery_turret_ammo; wagons use artillery_wagon_ammo and must remain stationary
-- in explicit manual train control throughout the task. Ammunition is removed only
-- after a physical source visit, held in persistent custody, inserted only after a
-- fresh target recheck, and returned when the target becomes unsafe or full.
-- Train speed, state, schedule, manual mode, targeting, and firing are never changed.

local M = {
  version = "0.1.674-dev",
  storage_key = "artillery_logistics_0713",
  pickup_reach_sq = 2.56,
  target_reach_sq = 3.24,
  station_reach_sq = 2.56,
  move_priority = 974,
  move_ttl = 60 * 10,
  reservation_ttl = 60 * 15,
  request_timeout = 60 * 14,
  max_transfer = 10,
}

local previous_leaf_truth
local AMMO_PREFERENCE = { "artillery-shell" }

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function lower(value) return string.lower(tostring(value or "")) end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function dist_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
    recent = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(name, amount)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (amount or 1)
end

local function record(pair, action, detail, force_log)
  local r = root()
  stat(action)
  local event = {
    tick = now(),
    action = tostring(action or "event"),
    station = safe(station_unit(pair)),
    priest = safe(priest_unit(pair)),
    detail = tostring(detail or ""),
  }
  r.recent[#r.recent + 1] = event
  while #r.recent > 160 do table.remove(r.recent, 1) end
  pair.artillery_logistics_last_0713 = event
  if force_log and log then
    log("[Tech-Priests 0.1.674-dev] " .. event.action
      .. " station=" .. event.station
      .. " priest=" .. event.priest .. " " .. event.detail)
  end
end

local function inventory(entity)
  if not (valid(entity) and defines and defines.inventory) then return nil end
  local id = entity.type == "artillery-wagon"
    and defines.inventory.artillery_wagon_ammo
    or defines.inventory.artillery_turret_ammo
  if not id then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(id) end)
  return ok and inv and inv.valid and inv or nil
end

local function contents(inv)
  local out = {}
  if not (inv and inv.valid) then return out end
  local ok, raw = pcall(function() return inv.get_contents() end)
  if not (ok and type(raw) == "table") then return out end
  for key, value in pairs(raw) do
    local name, count
    if type(key) == "string" then
      name = key
      count = type(value) == "table" and tonumber(value.count or value.amount or value[2]) or tonumber(value)
    elseif type(value) == "table" then
      name = value.name or value.item or value[1]
      count = tonumber(value.count or value.amount or value[2])
    end
    if type(name) == "string" and (tonumber(count) or 0) > 0 then
      out[#out + 1] = { name = name, count = tonumber(count) or 1 }
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

local function item_count(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, count = pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(count) or 0) or 0
end

local function inv_remove(inv, item, count)
  if not (inv and inv.valid and item and count and count > 0) then return 0 end
  local ok, removed = pcall(function() return inv.remove({ name = item, count = count }) end)
  return ok and (tonumber(removed) or 0) or 0
end

local function inv_insert(inv, item, count)
  if not (inv and inv.valid and item and count and count > 0) then return 0 end
  local ok, inserted = pcall(function() return inv.insert({ name = item, count = count }) end)
  return ok and (tonumber(inserted) or 0) or 0
end

local function inv_can_insert(inv, item)
  if not (inv and inv.valid and item) then return false end
  local ok, yes = pcall(function() return inv.can_insert({ name = item, count = 1 }) end)
  return ok and yes == true
end

local function readiness()
  return rawget(_G, "TechPriestsArtilleryReadiness0712")
    or package.loaded["scripts.core.artillery_readiness_0712"]
end

local function storage_authority()
  return rawget(_G, "TechPriestsStorageRoleAuthority0686")
    or package.loaded["scripts.core.storage_role_authority_0686"]
end

local function service_radius(pair)
  local radius = tonumber(pair and pair.radius) or 28
  if valid_pair(pair) and type(_G.get_station_operating_radius) == "function" then
    local ok, value = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(value) then radius = tonumber(value) end
  end
  return math.max(8, radius)
end

local function home_sources(pair)
  local out, seen = {}, {}
  if not valid_pair(pair) then return out end
  local radius = service_radius(pair)
  local home = station_unit(pair)
  local function add(source)
    local inv = source and source.inv
    local entity = source and source.entity
    if not (inv and inv.valid and valid(entity)) then return end
    if entity.surface ~= pair.station.surface or entity.force ~= pair.station.force then return end
    if source.authority_source_station_0573
      and tostring(source.authority_source_station_0573) ~= tostring(home)
    then
      return
    end
    if dist_sq(entity.position, pair.station.position) > radius * radius then return end
    local key = safe(inv)
    if seen[key] then return end
    seen[key] = true
    out[#out + 1] = {
      inv = inv,
      entity = entity,
      label = source.source or source.inventory_id or "home-source",
    }
  end
  if type(_G.tech_priests_inventory_steward_sources_for_pair) == "function" then
    local ok, sources = pcall(_G.tech_priests_inventory_steward_sources_for_pair, pair)
    if ok and type(sources) == "table" then
      for _, source in ipairs(sources) do add(source) end
    end
  end
  return out
end

local function source_for_item(pair, item, target_inv)
  local best
  for _, source in ipairs(home_sources(pair)) do
    local count = item_count(source.inv, item)
    if count > 0 and inv_can_insert(target_inv, item) then
      local score = dist_sq(pair.priest.position, source.entity.position) - math.min(count, 100)
      if not best or score < best.score then
        best = {
          item = item,
          count = count,
          inv = source.inv,
          entity = source.entity,
          label = source.label,
          score = score,
        }
      end
    end
  end
  return best
end

local function choose_ammo(pair, report)
  local inv = report and report.ammo_inventory
  if not (inv and inv.valid) then return nil, nil end
  for _, entry in ipairs(report.ammo_contents or {}) do
    if inv_can_insert(inv, entry.name) then
      local source = source_for_item(pair, entry.name, inv)
      if source then return source, entry.name end
    end
  end
  for _, name in ipairs(AMMO_PREFERENCE) do
    if inv_can_insert(inv, name) then
      local source = source_for_item(pair, name, inv)
      if source then return source, name end
    end
  end
  for _, name in ipairs(report.compatible_ammo or {}) do
    local source = source_for_item(pair, name, inv)
    if source then return source, name end
  end
  local request = AMMO_PREFERENCE[1]
  if not inv_can_insert(inv, request) then request = (report.compatible_ammo or {})[1] end
  return nil, request
end

local function reservation_authority()
  local reservations = rawget(_G, "TechPriestsWorkReservations0601")
    or package.loaded["scripts.core.work_reservations"]
  if not reservations then return nil end
  local found = false
  for _, category in ipairs(reservations.categories or {}) do
    if category == "machine-logistics" then found = true break end
  end
  if not found then
    reservations.categories = reservations.categories or {}
    reservations.categories[#reservations.categories + 1] = "machine-logistics"
    local r = type(reservations.root) == "function" and reservations.root() or nil
    if r then
      r.reservations = r.reservations or {}
      r.reservations["machine-logistics"] = r.reservations["machine-logistics"] or {}
    end
  end
  return reservations
end

local function claim_target(pair, task)
  local reservations = reservation_authority()
  if not (reservations and type(reservations.claim) == "function" and valid(task.target)) then
    return false, "reservation-unavailable"
  end
  return reservations.claim("machine-logistics", task.target, pair, M.reservation_ttl, {
    surface_index = pair.station.surface.index,
    force_index = pair.station.force.index,
    family = "artillery-ammo",
    item = task.item,
    source = "artillery-logistics-0713",
  })
end

local function release_target(pair, task)
  local reservations = reservation_authority()
  if reservations and type(reservations.release) == "function" and task and valid(task.target) then
    pcall(reservations.release, "machine-logistics", task.target, pair)
  end
end

local function refresh_reports(pair)
  local doctrine = readiness()
  if doctrine and type(doctrine.scan_pair) == "function" then
    pcall(doctrine.scan_pair, pair, true)
  end
  return pair.artillery_reports_0712 or {}
end

local function candidate(pair)
  local reports = pair.artillery_reports_0712
  if type(reports) ~= "table" then reports = refresh_reports(pair) end
  local best
  for _, report in ipairs(reports or {}) do
    if report.state == "manual-ammo-service-eligible"
      and valid(report.entity)
      and report.ammo_inventory and report.ammo_inventory.valid
    then
      local source, item = choose_ammo(pair, report)
      if item then
        local score = dist_sq(pair.priest.position, report.entity.position)
        if not best or score < best.score then
          best = {
            target = report.entity,
            target_name = report.entity_name,
            target_unit = report.entity_unit,
            item = item,
            count = math.min(math.max(1, report.missing_ammo_count or 1), M.max_transfer),
            source = source,
            report = report,
            score = score,
          }
        end
      end
    end
  end
  return best
end

local function wagon_safe(entity)
  if not (valid(entity) and entity.type == "artillery-wagon") then return true end
  local train
  pcall(function() train = entity.train end)
  if not (train and train.valid) then return true end
  local speed, manual
  pcall(function() speed = tonumber(train.speed) or 0 end)
  pcall(function() manual = train.manual_mode == true end)
  return math.abs(speed or 0) < 0.001 and manual == true
end

local function request_move(pair, target, reason)
  if not (valid_pair(pair) and valid(target)) then return false end
  pair.target = target
  if type(_G.tech_priests_request_movement_0418) == "function" then
    local ok, result = pcall(_G.tech_priests_request_movement_0418, pair, target.position,
      reason or "artillery-logistics-0713", {
        owner = "artillery-logistics-0713",
        priority = M.move_priority,
        ttl = M.move_ttl,
        radius = 1.5,
        distraction = defines and defines.distraction and defines.distraction.none or nil,
      })
    return ok and result ~= false
  end
  return false
end

local function clear_requests(pair, task)
  for _, field in ipairs({ "active_supply_request", "logistic_requested_item" }) do
    local request = pair[field]
    if type(request) == "table" and request.source == "artillery-logistics-0713"
      and (not task or not request.target_unit or request.target_unit == task.target_unit)
    then
      pair[field] = nil
    end
  end
end

local function create_request(pair, task)
  pair.active_supply_request = {
    item = task.item,
    count = task.count,
    source = "artillery-logistics-0713",
    purpose = "artillery-ammo",
    target_unit = task.target_unit,
    target_name = task.target_name,
    tick = now(),
  }
  pair.logistic_requested_item = {
    item = task.item,
    count = task.count,
    source = "artillery-logistics-0713",
    purpose = "artillery-ammo",
    target_unit = task.target_unit,
  }
  task.phase = "waiting-source"
  task.request_tick = task.request_tick or now()
  stat("ammo-item-requests")
end

local function sync_custody(pair, task, reason)
  if task and task.carried and task.carried.item and (tonumber(task.carried.count) or 0) > 0 then
    pair.artillery_custody_0713 = {
      version = M.version,
      tick = now(),
      item = task.carried.item,
      count = task.carried.count,
      target_unit = task.target_unit,
      target_name = task.target_name,
      reason = reason or task.phase,
    }
    return true
  end
  pair.artillery_custody_0713 = nil
  return false
end

local function finish(pair, task, reason)
  release_target(pair, task)
  clear_requests(pair, task)
  pair.artillery_custody_0713 = nil
  task.phase = "complete"
  task.completed_tick = now()
  task.result = reason or "complete"
  pair.artillery_logistics_last_task_0713 = task
  pair.artillery_logistics_0713 = nil
  local leaf = pair.active_leaf_task_0655
  if type(leaf) == "table" and leaf.source == "artillery_logistics_0713" then
    pair.active_leaf_task_0655 = nil
    pair.actual_task_status_0655 = nil
    pair.current_work_target_0655 = nil
  end
  record(pair, "artillery-task-finished", safe(reason))
  return true, reason or "complete"
end

local function abort(pair, task, reason)
  release_target(pair, task)
  clear_requests(pair, task)
  task.phase = "aborted"
  task.completed_tick = now()
  task.result = reason
  pair.artillery_logistics_last_task_0713 = task
  pair.artillery_logistics_0713 = nil
  record(pair, "artillery-task-aborted", safe(reason))
  return false, reason
end

local function restore_orphan(pair)
  local custody = pair.artillery_custody_0713
  if pair.artillery_logistics_0713
    or type(custody) ~= "table"
    or not custody.item
    or (tonumber(custody.count) or 0) <= 0
  then
    return false
  end
  pair.artillery_logistics_0713 = {
    version = M.version,
    phase = "return-custody",
    item = custody.item,
    count = custody.count,
    carried = { item = custody.item, count = custody.count },
    started_tick = now(),
    custody_recovery = true,
  }
  record(pair, "artillery-orphan-custody-restored", custody.item .. " x" .. safe(custody.count), true)
  return true
end

local function return_to_station(pair, task)
  local carried = task.carried
  if not (carried and carried.item and (tonumber(carried.count) or 0) > 0) then
    return finish(pair, task, "empty-custody")
  end
  if dist_sq(pair.priest.position, pair.station.position) > M.station_reach_sq then
    task.phase = "return-custody"
    sync_custody(pair, task, "returning-station")
    request_move(pair, pair.station, "artillery-custody-return-0713")
    return true, "returning-station"
  end
  local authority = storage_authority()
  local ok, why, inserted = false, "storage-authority-unavailable", 0
  if authority and type(authority.deposit_exact) == "function" then
    ok, why, inserted = authority.deposit_exact(pair, carried.item, carried.count,
      "artillery-ammo-return", {})
  end
  inserted = tonumber(inserted) or 0
  if ok and inserted > 0 then carried.count = carried.count - inserted end
  if carried.count <= 0 then return finish(pair, task, "custody-stored") end
  sync_custody(pair, task, "station-storage-blocked")
  record(pair, "artillery-custody-storage-blocked",
    carried.item .. " remaining=" .. safe(carried.count) .. " reason=" .. safe(why))
  return true, "storage-blocked"
end

local function source_current(pair, task)
  if task.source_inv and task.source_inv.valid and valid(task.source_entity)
    and item_count(task.source_inv, task.item) > 0
  then
    return {
      inv = task.source_inv,
      entity = task.source_entity,
      count = item_count(task.source_inv, task.item),
      label = task.source_label,
    }
  end
  if not valid(task.target) then return nil end
  return source_for_item(pair, task.item, inventory(task.target))
end

local function revalidate_target(pair, task)
  if not valid(task.target) then return nil, "target-invalid" end
  if not wagon_safe(task.target) then return nil, "wagon-became-mobile-or-automatic" end
  local doctrine = readiness()
  if not (doctrine and type(doctrine.inspect_entity) == "function") then
    return nil, "readiness-unavailable"
  end
  local report = doctrine.inspect_entity(pair, task.target, true)
  task.report = report
  if not report then return nil, "readiness-failed" end
  if report.state ~= "manual-ammo-service-eligible" then
    return report, "target-not-eligible:" .. safe(report.state)
  end
  if not inv_can_insert(report.ammo_inventory, task.item) then
    return report, "ammo-inventory-rejects-item"
  end
  return report, "ready"
end

local function begin(pair, selected, reason)
  local task = {
    version = M.version,
    phase = "new",
    target = selected.target,
    target_name = selected.target_name,
    target_unit = selected.target_unit,
    item = selected.item,
    count = math.max(1, tonumber(selected.count) or 1),
    source_inv = selected.source and selected.source.inv or nil,
    source_entity = selected.source and selected.source.entity or nil,
    source_label = selected.source and selected.source.label or nil,
    report = selected.report,
    started_tick = now(),
    reason = reason,
  }
  local claimed, why = claim_target(pair, task)
  if not claimed then return false, "target-reserved:" .. safe(why) end
  pair.artillery_logistics_0713 = task
  if not valid(task.source_entity) then
    create_request(pair, task)
    record(pair, "artillery-waiting-source", task.item .. " -> " .. safe(task.target_name))
    return false, "waiting-source"
  end
  task.phase = "move-to-source"
  request_move(pair, task.source_entity, "artillery-ammo-source-0713")
  record(pair, "artillery-task-began",
    task.item .. " x" .. safe(task.count) .. " -> " .. safe(task.target_name))
  return true, "moving-to-source"
end

local function continue_task(pair, task)
  if valid(pair.combat_target) then
    if task.carried then
      sync_custody(pair, task, "combat-suspended")
      return false, "combat-suspended"
    end
    return abort(pair, task, "combat-priority")
  end
  if task.phase == "return-custody" then return return_to_station(pair, task) end
  if not valid(task.target) then
    if task.carried then
      task.phase = "return-custody"
      return return_to_station(pair, task)
    end
    return abort(pair, task, "target-invalid")
  end
  if task.target.type == "artillery-wagon" and not wagon_safe(task.target) then
    if task.carried then
      task.phase = "return-custody"
      record(pair, "wagon-moved-custody-return", safe(task.target_name))
      return return_to_station(pair, task)
    end
    return abort(pair, task, "wagon-became-mobile-or-automatic")
  end

  if task.phase == "waiting-source" then
    if now() - (tonumber(task.request_tick) or now()) >= M.request_timeout then
      return abort(pair, task, "ammo-source-timeout")
    end
    local source = source_current(pair, task)
    if not source then
      create_request(pair, task)
      return false, "waiting-source"
    end
    task.source_inv = source.inv
    task.source_entity = source.entity
    task.source_label = source.label
    task.phase = "move-to-source"
    request_move(pair, source.entity, "artillery-ammo-source-ready-0713")
    return true, "source-ready"
  end

  if task.phase == "move-to-source" then
    local source = source_current(pair, task)
    if not source then
      task.phase = "waiting-source"
      task.request_tick = now()
      create_request(pair, task)
      return false, "source-lost"
    end
    if dist_sq(pair.priest.position, source.entity.position) > M.pickup_reach_sq then
      request_move(pair, source.entity, "artillery-ammo-source-0713")
      return true, "moving-to-source"
    end
    local want = math.max(1, math.min(task.count, source.count, M.max_transfer))
    local removed = inv_remove(source.inv, task.item, want)
    if removed <= 0 then return abort(pair, task, "source-remove-failed") end
    task.carried = { item = task.item, count = removed }
    clear_requests(pair, task)
    sync_custody(pair, task, "picked-up")
    record(pair, "artillery-ammo-picked-up", task.item .. " x" .. safe(removed))
    if task.target.type == "artillery-wagon" and not wagon_safe(task.target) then
      task.phase = "return-custody"
      return return_to_station(pair, task)
    end
    task.phase = "move-to-target"
    request_move(pair, task.target, "artillery-ammo-delivery-0713")
    return true, "delivering-ammo"
  end

  if task.phase == "move-to-target" then
    if task.target.type == "artillery-wagon" and not wagon_safe(task.target) then
      task.phase = "return-custody"
      record(pair, "wagon-moved-custody-return", safe(task.target_name))
      return return_to_station(pair, task)
    end
    if dist_sq(pair.priest.position, task.target.position) > M.target_reach_sq then
      request_move(pair, task.target, "artillery-ammo-delivery-0713")
      sync_custody(pair, task, "moving-to-target")
      return true, "moving-to-target"
    end
    local report, why = revalidate_target(pair, task)
    if not report or why ~= "ready" then
      task.phase = "return-custody"
      record(pair, "artillery-target-became-ineligible", safe(why))
      return return_to_station(pair, task)
    end
    local carried = task.carried
    if not carried then return abort(pair, task, "custody-missing") end
    local inserted = inv_insert(report.ammo_inventory, carried.item, carried.count)
    if inserted > 0 then
      carried.count = carried.count - inserted
      stat("ammo-items-delivered", inserted)
      record(pair, "artillery-ammo-delivered",
        carried.item .. " x" .. safe(inserted) .. " -> " .. safe(task.target_name))
    end
    if carried.count <= 0 then return finish(pair, task, "ammo-delivered") end
    task.phase = "return-custody"
    sync_custody(pair, task, "ammo-partial")
    request_move(pair, pair.station, "artillery-ammo-leftover-return-0713")
    return true, inserted > 0 and "partial-ammo-delivery" or "ammo-insert-blocked"
  end

  return false, "unknown-phase:" .. safe(task.phase)
end

local function blocker(pair)
  if valid(pair.combat_target) then return "combat" end
  if pair.rocket_silo_logistics_0710 or pair.rocket_silo_custody_0710 then return "rocket-silo" end
  if pair.energy_family_logistics_0707 or pair.energy_family_custody_0707 then return "energy-family" end
  if pair.item_family_logistics_0702 or pair.item_family_custody_0702 then return "item-family" end
  if pair.machine_logistics_0528 or pair.machine_logistics_custody_0682 then return "machine-logistics" end
  if pair.construction_task_0338 or pair.fluid_pipe_plan_0691 or pair.fluid_output_pipe_plan_0696 then
    return "construction"
  end
  if pair.direct_acquisition_target_lock_0650 then return "direct-acquisition" end
  for _, field in ipairs({ "repair_0516", "combat_repair_0517", "consecration_0515" }) do
    local state = pair[field]
    local phase = lower(type(state) == "table" and state.phase or "")
    if phase ~= "" and phase ~= "complete" and phase ~= "completed" and phase ~= "done" then
      return field
    end
  end
  local leaf = pair.active_leaf_task_0655
  if type(leaf) == "table" and leaf.source ~= "artillery_logistics_0713"
    and now() - (tonumber(leaf.tick) or -1000000) < 60 * 8
  then
    return "leaf:" .. safe(leaf.source)
  end
  return nil
end

function M.service_pair(pair, reason)
  if root().enabled == false or not valid_pair(pair) then return false, "disabled-or-invalid" end
  restore_orphan(pair)
  local task = pair.artillery_logistics_0713
  if task then return continue_task(pair, task) end
  local blocked = blocker(pair)
  if blocked then return false, "blocked:" .. blocked end
  local selected = candidate(pair)
  if not selected then return false, "no-artillery-task" end
  return begin(pair, selected, reason or "service")
end

local function artillery_truth(pair)
  local task = pair and pair.artillery_logistics_0713
  if not (type(task) == "table" and valid_pair(pair)) then return nil end
  local target, phase, label
  if task.phase == "move-to-source" and valid(task.source_entity) then
    target = task.source_entity
    phase = "collect-artillery-ammo"
    label = "Collecting " .. safe(task.item) .. " for " .. safe(task.target_name)
  elseif task.phase == "move-to-target" and valid(task.target) then
    target = task.target
    phase = "deliver-artillery-ammo"
    label = "Delivering " .. safe(task.item) .. " to " .. safe(task.target_name)
  elseif task.phase == "return-custody" then
    target = pair.station
    phase = "return-artillery-custody"
    label = "Returning " .. safe(task.item) .. " to Cogitator"
  else
    return nil
  end
  return {
    family = "logistics",
    phase = phase,
    entity = target,
    position = { x = target.position.x, y = target.position.y },
    item = task.item,
    label = label,
    owner = "artillery-logistics-0713",
    priority = M.move_priority,
    radius = 1.5,
    color = { r = 0.95, g = 0.28, b = 0.12, a = 0.95 },
    can_move = true,
    source = "artillery_logistics_0713",
  }
end

local function patch_leaf_truth()
  local ok, truth = pcall(require, "scripts.core.active_leaf_task_truth_0655")
  if not (ok and truth and type(truth.truth) == "function")
    or truth.artillery_logistics_0713_wrapped
  then
    return false
  end
  truth.artillery_logistics_0713_wrapped = true
  previous_leaf_truth = truth.truth
  truth.truth = function(pair)
    return previous_leaf_truth(pair) or artillery_truth(pair)
  end
  return true
end

function M.service_all(reason, budget)
  local acted = 0
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) then
      local ok, did = pcall(M.service_pair, pair, reason or "pulse")
      if ok and did then acted = acted + 1 end
      if acted >= (tonumber(budget) or 6) then break end
    end
  end
  return acted
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.artillery_logistics_0713_wrapped
  then
    return false
  end
  diagnostics.artillery_logistics_0713_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local r = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 ARTILLERY-LOGISTICS-0713 enabled="
      .. safe(r.enabled)
      .. " requests=" .. safe(r.stats["ammo-item-requests"] or 0)
      .. " pickups=" .. safe(r.stats["artillery-ammo-picked-up"] or 0)
      .. " delivered=" .. safe(r.stats["ammo-items-delivered"] or 0)
      .. " wagon_returns=" .. safe(r.stats["wagon-moved-custody-return"] or 0)
      .. " custody_restored=" .. safe(r.stats["artillery-orphan-custody-restored"] or 0)
      .. " train_mutations=0 target_mutations=0 firing_mutations=0"
    for _, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local task = pair.artillery_logistics_0713 or {}
        local custody = pair.artillery_custody_0713 or {}
        lines[#lines + 1] = "PAIR-DUMP-0468 artillery-logistics[" .. safe(station_unit(pair)) .. "]"
          .. " phase=" .. safe(task.phase or "none")
          .. " item=" .. safe(task.item or custody.item or "none")
          .. " target=" .. safe(task.target_name or custody.target_name or "none")
          .. " custody=" .. safe(custody.count or 0)
      end
    end
    return lines
  end
  return true
end

local function register_service()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({
      name = "artillery_logistics_0713",
      category = "machine-logistics",
      interval = 37,
      priority = 55,
      budget = 6,
      note = "physical fixed artillery and stationary manual wagon ammunition logistics",
      fn = function(_, budget)
        local count = M.service_all("broker", budget)
        return count > 0, "acted=" .. safe(count)
      end,
    })
  end
end

function M.install()
  root()
  patch_leaf_truth()
  patch_diagnostics()
  register_service()
  _G.TechPriestsArtilleryLogistics0713 = M
  if log then log("[Tech-Priests 0.1.674-dev] physical artillery turret and manual stationary wagon logistics armed") end
  return true
end

return M
