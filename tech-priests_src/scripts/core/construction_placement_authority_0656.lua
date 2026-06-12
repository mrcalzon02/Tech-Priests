-- scripts/core/construction_placement_authority_0656.lua
-- Tech Priests 0.1.656
--
-- Commandless construction placement authority.
--
-- Once a Cogitator Station has a placeable structure item, construction becomes
-- the concrete leaf task.  This prevents priests from holding a built emergency
-- machine in the station inventory while continuing to mine, wander, consecrate,
-- or obey an old movement lease.  The existing construction_planner.lua still
-- owns site choice and entity creation; this authority makes sure that planner is
-- serviced aggressively and that its task owns movement/overhead until the entity
-- is physically placed.

local M = {}
M.version = "0.1.656"
M.storage_key = "construction_placement_authority_0656"
M.tick_interval = 5
M.max_pairs_per_pulse = 40
M.command_cooldown = 18
M.ttl = 60 * 8
M.station_sync_distance_sq = 4.0
M.build_close_distance_sq = 1.96
M.log_interval = 300

local Build = nil

local emergency_priority = {
  ["tech-priests-emergency-miner"] = 1,
  ["tech-priests-atmospheric-water-condenser"] = 2,
  ["tech-priests-emergency-boiler"] = 3,
  ["tech-priests-emergency-steam-engine"] = 4,
  ["tech-priests-emergency-power-grid"] = 5,
  ["tech-priests-emergency-smelter"] = 6,
  ["tech-priests-emergency-assembler"] = 7,
  ["tech-priests-emergency-laboratorium"] = 8,
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function pair_key(pair) local su = station_unit(pair); if su then return tostring(su) end local pu = priest_unit(pair); if pu then return "p" .. tostring(pu) end return nil end
local function dist_sq(a, b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function clean_item(name) name = tostring(name or ""); if name == "" or name == "nil" then return nil end return (name:gsub("%-", " ")) end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {}, last_log = {} }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}; r.recent = r.recent or {}; r.last_log = r.last_log or {}
  return r
end
local function stat(name, n) local r = root(); r.stats[name] = (tonumber(r.stats[name]) or 0) + (n or 1) end
local function record(action, pair, detail, force)
  local r = root(); stat(action)
  local ev = { tick = now(), action = tostring(action or "event"), station = safe(station_unit(pair)), priest = safe(priest_unit(pair)), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = ev
  while #r.recent > 120 do table.remove(r.recent, 1) end
  local key = ev.action .. ":" .. ev.station
  local last = tonumber(r.last_log[key] or -1000000) or -1000000
  if force or now() - last >= M.log_interval then
    r.last_log[key] = now()
    if log then log("[Tech-Priests 0.1.656] " .. ev.action .. " station=" .. ev.station .. " priest=" .. ev.priest .. " " .. safe(detail)) end
  end
end

local function construction_planner()
  if Build then return Build end
  local ok, mod = pcall(require, "scripts.core.construction_planner")
  if ok and mod then Build = mod end
  return Build
end
local function safe_inventory(entity, id)
  if not (valid(entity) and entity.get_inventory and id) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(id) end)
  if ok and inv and inv.valid then return inv end
  return nil
end
local function station_sources(pair)
  local out, seen = {}, {}
  local function add(inv, label, entity, id)
    if inv and inv.valid and not seen[tostring(inv)] then out[#out + 1] = { inv = inv, source = label, entity = entity or pair.station, inventory_id = id }; seen[tostring(inv)] = true end
  end
  if not valid_pair(pair) then return out end
  if type(_G.tech_priests_0358_station_sources_for_pair) == "function" then
    local ok, sources = pcall(_G.tech_priests_0358_station_sources_for_pair, pair)
    if ok and type(sources) == "table" then for _, src in ipairs(sources) do if src and src.inv and src.inv.valid then add(src.inv, src.source or src.kind or "work-inventory", src.entity or src.owner or pair.station, src.inventory_id or src.inv_id or src.id) end end end
  end
  if type(_G.tech_priests_inventory_steward_sources_for_pair) == "function" then
    local ok, sources = pcall(_G.tech_priests_inventory_steward_sources_for_pair, pair)
    if ok and type(sources) == "table" then for _, src in ipairs(sources) do if src and src.inv and src.inv.valid then add(src.inv, src.source or src.kind or "steward", src.entity or src.owner or pair.station, src.inventory_id or src.inv_id or src.id) end end end
  end
  if defines and defines.inventory then add(safe_inventory(pair.station, defines.inventory.chest), "station-chest", pair.station, defines.inventory.chest) end
  return out
end
local function inv_count(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, n = pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(n) or 0) or 0
end
local function station_count(pair, item)
  local total = 0
  for _, src in ipairs(station_sources(pair)) do total = total + inv_count(src.inv, item) end
  return total
end
local function iter_contents(inv)
  local out = {}
  if not (inv and inv.valid) then return out end
  local ok, contents = pcall(function() return inv.get_contents() end)
  if not (ok and contents) then return out end
  for k, v in pairs(contents) do
    if type(k) == "string" and type(v) == "number" then out[#out + 1] = { name = k, count = v }
    elseif type(v) == "table" then local name = v.name or v[1] or (type(k) == "string" and k or nil); local count = v.count or v[2] or 1; if name then out[#out + 1] = { name = name, count = count } end end
  end
  return out
end
local function place_result_name(item_name)
  if not (item_name and prototypes and prototypes.item and prototypes.item[item_name]) then return nil end
  local ok, result = pcall(function() return prototypes.item[item_name].place_result end)
  if not ok or not result then return nil end
  if type(result) == "string" then return result end
  if type(result) == "table" and result.name then return result.name end
  return nil
end
local function any_placeable_stock(pair)
  local best = nil
  for _, src in ipairs(station_sources(pair)) do
    for _, stack in ipairs(iter_contents(src.inv)) do
      if (tonumber(stack.count) or 0) > 0 then
        local entity = place_result_name(stack.name)
        if entity then
          local score = emergency_priority[entity] or emergency_priority[stack.name] or 1000
          if not best or score < best.score then best = { item = stack.name, entity = entity, count = stack.count, source = src.source, score = score } end
        end
      end
    end
  end
  return best
end
local function planned_item_ready(pair)
  local task = pair and pair.construction_task_0338
  if task and task.item_name and station_count(pair, task.item_name) > 0 then return task.item_name, task.entity_name or place_result_name(task.item_name), "active-construction-task" end
  local ghost = pair and pair.construction_bootstrap_ghost_0645
  if ghost and ghost.item and station_count(pair, ghost.item) > 0 then return ghost.item, ghost.entity_name or place_result_name(ghost.item), "bootstrap-ghost" end
  local plan = pair and pair.master_infrastructure_plan_0644
  local target = plan and plan.target or nil
  if target and target.preferred_item and station_count(pair, target.preferred_item) > 0 then return target.preferred_item, place_result_name(target.preferred_item), "master-plan" end
  local any = any_placeable_stock(pair)
  if any then return any.item, any.entity, "station-placeable-stock" end
  return nil, nil, "no-placeable-stock"
end

local function clear_competing_work(pair, item, entity, reason)
  if not pair then return end
  pair.build_preempts_acquisition_until_0656 = now() + 60 * 8
  pair.direct_acquisition_task_0336 = nil
  pair.active_acquisition_0333 = nil
  pair.acquisition_repair_task_0333 = nil
  pair.resource_doctrine_task_0325 = nil
  pair.scavenge = nil
  pair.inventory_scan = nil
  pair.direct_acquisition_target_lock_0650 = nil
  pair.dispatcher_direct_0513 = nil
  pair.local_infrastructure_gate_0640 = nil
  pair.construction_priority_0656 = { tick = now(), item = item, entity = entity, reason = reason or "construction-ready" }
end
local function movement_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.movement_controller_0419 = storage.tech_priests.movement_controller_0419 or { requests = {}, active_request_ids = {}, stats = {} }
  local r = storage.tech_priests.movement_controller_0419
  r.requests = r.requests or {}; r.active_request_ids = r.active_request_ids or {}; r.stats = r.stats or {}
  return r
end
local function publish_leaf(pair, task, destination, label, phase)
  if not (valid_pair(pair) and task and destination) then return end
  pair.active_leaf_task_0655 = { version = M.version, tick = now(), family = "construction", phase = phase or task.phase or "construction", item = task.item_name, parent_item = task.item_name, label = label, target_name = task.entity_name, x = destination.x, y = destination.y, source = "construction_placement_authority_0656" }
  pair.actual_task_status_0655 = pair.active_leaf_task_0655
end
local function install_request(pair, task, destination, label, phase)
  if not (valid_pair(pair) and task and destination and destination.x and destination.y) then return nil end
  local key = pair_key(pair); if not key then return nil end
  local mr = movement_root()
  local req = { x = destination.x, y = destination.y, radius = phase == "station-sync" and 1.25 or 0.65, reason = "construction-placement-0656", owner = "construction-placement-0656", priority = 995, distraction = defines and defines.distraction and defines.distraction.none or nil, issued_tick = now(), updated_tick = now(), expires_tick = now() + M.ttl, item = task.item_name, target_name = task.entity_name, construction_task_0656 = true }
  mr.requests[key] = req; mr.active_request_ids[key] = true
  pair.movement_request_0418 = req; pair.movement_controller_owner_0418 = req.owner; pair.movement_controller_reason_0418 = req.reason; pair.movement_controller_clamp_0418 = nil; pair.movement_controller_state_0418 = "construction-placement-authoritative-0656"
  publish_leaf(pair, task, destination, label, phase)
  return req
end
local function issue_command(pair, req)
  if not (valid_pair(pair) and req and req.x and req.y and defines and defines.command) then return false end
  local last = pair.construction_placement_0656_last_command
  if last and now() - (tonumber(last.tick) or 0) < M.command_cooldown then return false end
  local command = { type = defines.command.go_to_location, destination = { x = req.x, y = req.y }, radius = req.radius or 0.65, distraction = req.distraction or (defines.distraction and defines.distraction.none) }
  local ok = false
  pcall(function() if pair.priest.commandable and pair.priest.commandable.valid then pair.priest.commandable.set_command(command); ok = true end end)
  pcall(function() if not ok and pair.priest.set_command then pair.priest.set_command(command); ok = true end end)
  if ok then pair.construction_placement_0656_last_command = { tick = now(), x = req.x, y = req.y } end
  return ok
end
local function construction_destination(pair, task)
  if not (valid_pair(pair) and task) then return nil, nil, nil end
  if task.target_position and dist_sq(pair.priest.position, task.target_position) <= M.build_close_distance_sq then
    return task.target_position, "Placing " .. (clean_item(task.entity_name) or "structure"), "placing"
  end
  if task.phase ~= "moving-to-site" and dist_sq(pair.priest.position, pair.station.position) > M.station_sync_distance_sq then
    return pair.station.position, "Retrieving " .. (clean_item(task.item_name) or "structure") .. " for construction", "station-sync"
  end
  if task.target_position then return task.target_position, "Walking to build " .. (clean_item(task.entity_name) or clean_item(task.item_name) or "structure"), "moving-to-site" end
  return nil, nil, nil
end

function M.service_pair(pair, reason)
  local r = root(); if r.enabled == false or not valid_pair(pair) then return false, "disabled-or-invalid" end
  if valid(pair.combat_target) then return false, "combat-has-priority" end
  local item, entity, why_ready = planned_item_ready(pair)
  if not item then return false, why_ready end
  clear_competing_work(pair, item, entity, why_ready)
  local B = construction_planner()
  if not (B and type(B.service_pair) == "function") then return false, "construction-planner-unavailable" end
  local ok, why = pcall(B.service_pair, pair, "construction-placement-authority-0656")
  local task = pair.construction_task_0338
  if task then
    local dest, label, phase = construction_destination(pair, task)
    if dest then
      local req = install_request(pair, task, dest, label, phase)
      if req and dist_sq(pair.priest.position, dest) > (phase == "station-sync" and M.station_sync_distance_sq or M.build_close_distance_sq) then issue_command(pair, req) end
      record("construction-placement-active-0656", pair, "item=" .. safe(task.item_name) .. " entity=" .. safe(task.entity_name) .. " phase=" .. safe(phase) .. " dest=" .. string.format("%.1f,%.1f", dest.x, dest.y), false)
    end
    return true, "construction-active"
  end
  if ok and why == true then stat("planner-serviced") end
  if pair.last_construction_success_0338 and now() - (tonumber(pair.last_construction_success_0338.tick) or 0) < 30 then
    pair.active_leaf_task_0655 = { version = M.version, tick = now(), family = "construction", phase = "placed", item = pair.last_construction_success_0338.item, label = "Placed " .. safe(pair.last_construction_success_0338.entity), source = "construction_placement_authority_0656" }
    record("construction-placed-0656", pair, "entity=" .. safe(pair.last_construction_success_0338.entity) .. " item=" .. safe(pair.last_construction_success_0338.item), true)
    return true, "placed"
  end
  return ok == true, safe(why)
end

function M.service_all(reason)
  local n = 0
  for _, pair in pairs(pair_map()) do
    if n >= M.max_pairs_per_pulse then break end
    if valid_pair(pair) then local ok, acted = pcall(M.service_pair, pair, reason or "pulse"); if ok and acted then n = n + 1 end end
  end
  return n
end

function M.install()
  root(); _G.TechPriestsConstructionPlacementAuthority0656 = M
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then broker.register_service({ name = "construction_placement_authority_0656", category = "construction", interval = M.tick_interval, priority = 30, budget = 10, fn = function(event, budget) M.service_all("broker"); return true end, note = "place station-held structure items before further acquisition" })
  else local R = rawget(_G, "TechPriestsRuntimeEventRegistry"); if R and type(R.on_nth_tick) == "function" then R.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end, { owner = "construction_placement_authority_0656", category = "construction", priority = "early" }) elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end) end end
  if log then log("[Tech-Priests 0.1.656] construction placement authority installed; station-held structure items preempt acquisition and drive placement") end
  return true
end

return M
