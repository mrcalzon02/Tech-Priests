-- scripts/core/construction_planner.lua
-- Tech Priests 0.1.359 station-bound construction planner + spiral site planning.
--
-- This module is intentionally conservative.  It gives Tech-Priests an actual
-- construction task surface for placeable objects found in priest/station
-- inventories without yet trying to solve belts, pipes, poles, or full factory
-- bus planning.  Machines are placed physically: the priest returns to the
-- station to receive the station-bound build order, walks to the target, and
-- places the entity there.
--
-- First-pass doctrine:
--   * Mining drills prefer resource patches, one drill per local patch region.
--   * Furnaces/assemblers/labs use circular station-relative placement scans.
--   * Assemblers require extra clearance on at least one side.
--   * Belts/pipes/poles/inserters are detected but deferred to later submodules.
--   * No direct player inventory access.  Priest inventory is transit only; the station inventory and station-owned stashes are the real source.

local Build = {}
Build.version = "0.1.359"
Build.storage_key = "construction_planner_0359"
Build.legacy_storage_key = "construction_planner_0343"
Build.service_period = 1
Build.max_per_pulse = 24
Build.move_refresh_ticks = 6
Build.close_distance_sq = 1.96
Build.station_close_distance_sq = 4.0
Build.default_radius = 36
Build.max_ring_radius = 36


local function debug_chat_allowed_0626(root)
  if not (root and root.debug_chat) then return false end
  if _G and _G.tech_priests_runtime_debug_enabled_0626 then
    local ok, enabled = pcall(_G.tech_priests_runtime_debug_enabled_0626, "verbose")
    if ok then return enabled == true end
  end
  return root.debug_chat == true
end
local function valid(e) return e and e.valid end
local function now() return game and game.tick or 0 end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function dist_sq(a,b) local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end

local function routed_find(surface, filters, category, negative_key, ttl)
  local Scan = rawget(_G, "TechPriestsScanRouting0610")
  if not Scan then local okS, mod = pcall(require, "scripts.core.scan_routing_0610"); if okS then Scan = mod end end
  if Scan and type(Scan.find_entities) == "function" then
    local ents = select(1, Scan.find_entities(surface, filters, { category = category or "construction", negative_key = negative_key, negative_ttl = ttl or 60 * 4 }))
    return ents or {}
  end
  local ok, ents = pcall(function() return surface.find_entities_filtered(filters) end)
  return (ok and ents) or {}
end
local SitePlanner = nil
local ok_site_planner, loaded_site_planner = pcall(require, "scripts.core.construction_site_planner")
if ok_site_planner and loaded_site_planner then SitePlanner = loaded_site_planner end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  local legacy = storage.tech_priests[Build.legacy_storage_key]
  storage.tech_priests[Build.storage_key] = storage.tech_priests[Build.storage_key] or {
    version = Build.version,
    enabled = true,
    debug_chat = true,
    stats = legacy and legacy.stats or {},
    skipped = legacy and legacy.skipped or {}
  }
  local root = storage.tech_priests[Build.storage_key]
  root.version = Build.version
  root.stats = root.stats or {}
  root.skipped = root.skipped or {}
  if root.enabled == nil then root.enabled = true end
  return root
end

local function proto_item(name)
  if not name then return nil end
  if prototypes and prototypes.item then
    local ok, proto = pcall(function() return prototypes.item[name] end)
    if ok then return proto end
  end
  return nil
end

local function proto_entity(name)
  if not name then return nil end
  if prototypes and prototypes.entity then
    local ok, proto = pcall(function() return prototypes.entity[name] end)
    if ok then return proto end
  end
  return nil
end

local function place_result_name(item_name)
  local ip = proto_item(item_name)
  if not ip then return nil end
  local ok, result = pcall(function() return ip.place_result end)
  if not ok or not result then return nil end
  if type(result) == "string" then return result end
  if type(result) == "table" and result.name then return result.name end
  return nil
end

local function entity_type(entity_name)
  local ep = proto_entity(entity_name)
  if not ep then return nil end
  local ok, t = pcall(function() return ep.type end)
  if ok then return t end
  return nil
end

local deferred_types = {
  ["transport-belt"] = true,
  ["underground-belt"] = true,
  ["splitter"] = true,
  ["loader"] = true,
  ["loader-1x1"] = true,
  ["linked-belt"] = true,
  ["pipe"] = true,
  ["pipe-to-ground"] = true,
  ["electric-pole"] = true,
  ["power-switch"] = true,
  ["inserter"] = true,
}

local function category_for_entity(entity_name)
  if entity_name == "tech-priests-emergency-miner" then return "emergency-miner" end
  if entity_name == "tech-priests-emergency-power-grid" then return "emergency-power-pole" end
  if entity_name == "tech-priests-emergency-smelter" then return "emergency-smelter" end
  if entity_name == "tech-priests-emergency-boiler" or entity_name == "tech-priests-atmospheric-water-condenser" or entity_name == "tech-priests-emergency-steam-engine" then return "emergency-powertrain" end
  local t = entity_type(entity_name)
  if not t then return "unknown" end
  if t == "mining-drill" then return "miner" end
  if t == "furnace" then return "furnace" end
  if t == "assembling-machine" then return "assembler" end
  if t == "lab" then return "lab" end
  if t == "boiler" or t == "generator" or t == "burner-generator" then return "power-machine" end
  if deferred_types[t] then return "deferred-network" end
  return "generic"
end

local emergency_build_priority = {
  ["tech-priests-emergency-miner"] = 1,
  ["tech-priests-atmospheric-water-condenser"] = 2,
  ["tech-priests-emergency-boiler"] = 3,
  ["tech-priests-emergency-steam-engine"] = 4,
  ["tech-priests-emergency-power-grid"] = 5,
  ["tech-priests-emergency-smelter"] = 6,
  ["tech-priests-emergency-assembler"] = 7,
  ["tech-priests-emergency-laboratorium"] = 8,
}


local function is_emergency_build_item_or_entity(name)
  return emergency_build_priority[name] ~= nil
end

local function task_is_emergency(task)
  return task and (is_emergency_build_item_or_entity(task.item_name) or is_emergency_build_item_or_entity(task.entity_name) or tostring(task.category or ""):find("emergency", 1, true) ~= nil)
end

local function preempt_conflicting_work_for_build(pair, task)
  -- 0.1.342: if a Tech-Priest is literally carrying an emergency machine or its
  -- station has one ready, placing that machine is more important than continuing
  -- to shout "need iron" at the snow.  Acquisition can resume after the facility
  -- exists; until then, movement/mining tasks fight the build order and make the
  -- priest look idle/wandering.
  if not (pair and task_is_emergency(task)) then return end
  local until_tick = now() + 300
  pair.build_preempts_acquisition_until_0342 = until_tick
  pair.direct_acquisition_task_0336 = nil
  pair.active_acquisition_0333 = nil
  pair.acquisition_repair_task_0333 = nil
  pair.resource_doctrine_task_0325 = nil
  pair.station_crafting_task_0337 = nil
  pair.emergency_operation = nil
  pair.independent_emergency_operation = nil
  pair.mode = "construction-priority"
  pair.status = "construction-priority"
end

local function safe_inventory(entity, inv_id)
  if not (valid(entity) and entity.get_inventory and inv_id) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inv_id) end)
  if ok and inv and inv.valid then return inv end
  return nil
end

local function inventories_for(entity)
  local out = {}
  if not valid(entity) then return out end
  -- 0.1.357: active construction inventory is station-bound. Priest
  -- inventories are accidental cargo and are evacuated by inventory_steward.
  -- Do not deliberately scan priest main inventories for work stock here.
  local ids = {
    defines.inventory.chest,
    defines.inventory.car_trunk,
    defines.inventory.spider_trunk,
    defines.inventory.assembling_machine_input,
    defines.inventory.assembling_machine_output,
    defines.inventory.furnace_source,
    defines.inventory.furnace_result,
  }
  local seen = {}
  for _, rec in ipairs(out) do seen[tostring(rec.inv)] = true end
  for _, id in pairs(ids) do
    local inv = safe_inventory(entity, id)
    if inv and not seen[tostring(inv)] then out[#out+1] = { inv = inv, id = id }; seen[tostring(inv)] = true end
  end
  return out
end

local function iter_contents(inv)
  local out = {}
  if not (inv and inv.valid) then return out end
  local ok, contents = pcall(function() return inv.get_contents() end)
  if not ok or not contents then return out end
  for k, v in pairs(contents) do
    if type(k) == "string" and type(v) == "number" then
      out[#out+1] = { name = k, count = v }
    elseif type(v) == "table" then
      local name = v.name or v[1] or (type(k) == "string" and k or nil)
      local count = v.count or v[2] or 1
      if name then out[#out+1] = { name = name, count = count, quality = v.quality } end
    end
  end
  return out
end

local function inventory_count(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, n = pcall(function() return inv.get_item_count(item) end)
  if ok then return tonumber(n) or 0 end
  return 0
end

local function remove_one(inv, item)
  if not (inv and inv.valid and item) then return false end
  if inventory_count(inv, item) <= 0 then return false end
  local ok, removed = pcall(function() return inv.remove({ name = item, count = 1 }) end)
  return ok and (removed or 0) > 0
end

local function station_bound_sources(pair)
  if not valid_pair(pair) then return {} end
  -- 0.1.359: use the canonical station-bound work inventory API first. This
  -- makes construction source from station/stash/personal Martian facility
  -- inventories instead of asking the priest what it happens to be carrying.
  if _G.tech_priests_0358_station_sources_for_pair then
    local ok, sources = pcall(_G.tech_priests_0358_station_sources_for_pair, pair)
    if ok and type(sources) == "table" and #sources > 0 then
      local out = {}
      for _, source in ipairs(sources) do
        if source and source.inv and source.inv.valid then
          out[#out+1] = {
            inv = source.inv,
            inventory_id = source.inventory_id or source.inv_id or source.id,
            source = source.source or source.kind or "station-work-inventory",
            entity = source.entity or source.owner or pair.station,
          }
        end
      end
      if #out > 0 then return out end
    end
  end

  -- Compatibility fallback for saves before the work-inventory API has loaded.
  if _G.tech_priests_inventory_steward_sources_for_pair then
    local ok, sources = pcall(_G.tech_priests_inventory_steward_sources_for_pair, pair)
    if ok and type(sources) == "table" then return sources end
  elseif _G.tech_priests_inventory_steward_unload then
    pcall(_G.tech_priests_inventory_steward_unload, pair, "construction-source-scan")
  end
  local out = {}
  for _, slot in ipairs(inventories_for(pair.station)) do
    out[#out+1] = { inv = slot.inv, inventory_id = slot.id, source = "station", entity = pair.station }
  end
  return out
end

local function find_item_source(pair, item_name)
  if not valid_pair(pair) then return nil end
  for _, source in ipairs(station_bound_sources(pair)) do
    if inventory_count(source.inv, item_name) > 0 then
      return { inv = source.inv, inventory_id = source.inventory_id or source.id, source = source.source or "station", entity = source.entity or pair.station }
    end
  end
  return nil
end

local function list_placeables(pair)
  local found = {}
  if not valid_pair(pair) then return found end
  local seen = {}
  for _, source in ipairs(station_bound_sources(pair)) do
    for _, st in ipairs(iter_contents(source.inv)) do
      if (st.count or 0) > 0 and not seen[st.name] then
        local ename = place_result_name(st.name)
        if ename then
          seen[st.name] = true
          found[#found+1] = {
            item_name = st.name,
            count = st.count,
            entity_name = ename,
            entity_type = entity_type(ename),
            category = category_for_entity(ename),
            source = source.source or "station",
            inventory_id = source.inventory_id or source.id
          }
        end
      end
    end
  end
  return found
end

local function radius_for(pair)
  if not valid_pair(pair) then return Build.default_radius end
  if _G.refresh_pair_radius then
    local ok, r = pcall(_G.refresh_pair_radius, pair)
    if ok and tonumber(r) then return math.max(8, math.min(96, tonumber(r))) end
  end
  if _G.get_station_operating_radius then
    local ok, r = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(r) then return math.max(8, math.min(96, tonumber(r))) end
  end
  return Build.default_radius
end

local function area_clear(surface, pos, clearance, ignore_resources)
  clearance = clearance or 1
  if not surface then return false end
  local area = { { pos.x - clearance, pos.y - clearance }, { pos.x + clearance, pos.y + clearance } }
  local ents = routed_find(surface, { area = area }, "construction-clearance", nil, 60 * 2)
  if not ents then return false end
  for _, e in pairs(ents) do
    if valid(e) then
      local t = e.type
      if not (ignore_resources and t == "resource") then
        if t ~= "corpse" and t ~= "particle-source" and t ~= "highlight-box" and t ~= "simple-entity-with-owner" then
          return false
        end
      end
    end
  end
  return true
end

local function can_place(surface, force, name, pos)
  if not (surface and name and pos) then return false end
  local ok, result = pcall(function()
    return surface.can_place_entity({ name = name, position = pos, force = force, build_check_type = defines.build_check_type.manual })
  end)
  if ok then return result == true end
  ok, result = pcall(function()
    return surface.can_place_entity({ name = name, position = pos, force = force })
  end)
  return ok and result == true
end

local function resource_product_names(entity)
  local out = {}
  if not valid(entity) then return out end
  local ok, props = pcall(function() return entity.prototype and entity.prototype.mineable_properties end)
  if ok and props and props.products then
    for _, p in pairs(props.products) do
      local n = p.name or p[1]
      if n then out[n] = true end
    end
  end
  return out
end

local function has_existing_miner_near(surface, pos)
  local ents = routed_find(surface, { position = pos, radius = 4.25, type = "mining-drill" }, "construction-miner", nil, 60 * 3)
  return ents and #ents > 0
end

local function plan_miner(pair, entity_name)
  local station = pair.station
  local surface = station.surface
  local r = radius_for(pair)
  local resources = routed_find(surface, { position = station.position, radius = r, type = "resource" }, "construction-resource", "construction-resource:" .. tostring(station.surface.index) .. ":" .. tostring(station.force.index) .. ":" .. tostring(station.unit_number or "?"), 60 * 6)
  if not resources then return nil, "no-resource-list" end
  local best, best_d2
  for _, res in pairs(resources) do
    if valid(res) and res.amount and res.amount > 0 then
      local pos = res.position
      if dist_sq(pos, station.position) <= r * r and not has_existing_miner_near(surface, pos) and can_place(surface, station.force, entity_name, pos) then
        local d2 = dist_sq(pos, station.position)
        if not best_d2 or d2 < best_d2 then best = pos; best_d2 = d2 end
      end
    end
  end
  if best then return { x = best.x, y = best.y }, "resource-patch" end
  return nil, "no-miner-site"
end

local function assembler_side_clear(surface, pos)
  local checks = {
    { x = pos.x + 3, y = pos.y },
    { x = pos.x - 3, y = pos.y },
    { x = pos.x, y = pos.y + 3 },
    { x = pos.x, y = pos.y - 3 },
  }
  for _, p in pairs(checks) do
    if area_clear(surface, p, 1.0, true) then return true end
  end
  return false
end

local function plan_ring(pair, entity_name, category)
  local station = pair.station
  local surface = station.surface
  local force = station.force
  local clearance = category == "assembler" and 2.0 or 1.0
  local max_r = math.min(radius_for(pair), Build.max_ring_radius)
  local step = 2
  for r = 4, max_r, step do
    local samples = math.max(12, math.floor(r * 4))
    for i = 1, samples do
      local angle = (i / samples) * math.pi * 2
      local pos = { x = station.position.x + math.cos(angle) * r, y = station.position.y + math.sin(angle) * r }
      if can_place(surface, force, entity_name, pos) and area_clear(surface, pos, clearance, true) then
        if category ~= "assembler" or assembler_side_clear(surface, pos) then
          return pos, "station-ring"
        end
      end
    end
  end
  return nil, "no-ring-site"
end

local function plan_site(pair, placeable)
  if not (valid_pair(pair) and placeable and placeable.entity_name) then return nil, "invalid" end
  if SitePlanner and SitePlanner.plan_site then
    local ok, pos, reason = pcall(SitePlanner.plan_site, pair, placeable)
    if ok then return pos, reason or (pos and "station-spiral" or "no-site") end
  end

  -- Safety fallback if the separated planner fails to load. Keep the older
  -- behavior available, but normal 0.1.359 operation should use
  -- construction_site_planner.lua.
  local category = placeable.category or category_for_entity(placeable.entity_name)
  if category == "deferred-network" then return nil, "deferred-network-submodule" end
  if category == "emergency-miner" or category == "emergency-power-pole" then
    return plan_ring(pair, placeable.entity_name, "generic")
  end
  if category == "emergency-powertrain" then return plan_ring(pair, placeable.entity_name, "generic") end
  if category == "miner" then return plan_miner(pair, placeable.entity_name) end
  return plan_ring(pair, placeable.entity_name, category)
end

local function draw_status(pair, text, ttl)
  if _G.tech_priests_emit_overhead_status_0473 then
    return _G.tech_priests_emit_overhead_status_0473(pair, text, { r = 1.0, g = 0.78, b = 0.22, a = 0.95 }, ttl or 60, 0.62, "construction-planner")
  end
  if _G.tech_priests_draw_emergency_operation_status_0184 then pcall(_G.tech_priests_draw_emergency_operation_status_0184, pair, text) end
  if _G.TECH_PRIESTS_WORK_VISUALS and _G.TECH_PRIESTS_WORK_VISUALS.show then pcall(_G.TECH_PRIESTS_WORK_VISUALS.show, pair, text, ttl or 60) end
end

local function line_to(pair, pos)
  if not (valid_pair(pair) and pos and _G.draw_emergency_craft_scan_line) then return end
  -- draw_emergency_craft_scan_line wants an entity.  If no entity exists at the
  -- planned tile, skip rather than create a visual-only dummy.
end

local function set_move(pair, pos, reason)
  if not (valid_pair(pair) and pos) then return false end
  local ok = false
  if _G.tech_priests_request_movement_0418 then
    ok = _G.tech_priests_request_movement_0418(pair, pos, reason or "moving-to-build-site", { radius = 0.55, owner = "construction-planner", priority = 70, distraction = defines.distraction.none })
  else
    local command = { type = defines.command.go_to_location, destination = pos, radius = 0.55, distraction = defines.distraction.none }
    if _G.tech_priests_route_ground_command_0429 then
      local ok_route, res = pcall(_G.tech_priests_route_ground_command_0429, pair.priest, command, reason or "construction-planner-fallback-0616", { pair = pair, priority = 70, ttl = 600 })
      ok = ok_route and res ~= false
    else
      ok = pcall(function()
        local commandable = pair.priest.commandable
        if commandable and commandable.valid then commandable.set_command(command) else pair.priest.set_command(command) end
      end)
    end
  end
  if ok then
    pair.mode = reason or "moving-to-build-site"
    pair.last_build_move_command_0338 = { tick = now(), x = pos.x, y = pos.y, reason = reason }
  end
  return ok
end

local function entity_label(entity, fallback)
  if not valid(entity) then return fallback or "?" end
  local ok, backer = pcall(function() return entity.backer_name end)
  if ok and backer and backer ~= "" then return backer end
  return entity.name or fallback or "?"
end

local function print_msg(pair, msg)
  local root = ensure_root()
  if log then log(msg) end
  if debug_chat_allowed_0626(root) and game and pair and valid(pair.station) then
    for _, player in pairs(game.connected_players or {}) do
      if player and player.valid and player.force == pair.station.force then player.print(msg) end
    end
  end
end

local function current_task(pair)
  if not pair then return nil end
  return pair.construction_task_0338
end

local function choose_placeable(pair)
  local root = ensure_root()
  local list = list_placeables(pair)
  table.sort(list, function(a,b)
    local ap = emergency_build_priority[a.entity_name] or emergency_build_priority[a.item_name]
    local bp = emergency_build_priority[b.entity_name] or emergency_build_priority[b.item_name]
    if ap or bp then return (ap or 1000) < (bp or 1000) end
    local order = { ["emergency-miner"] = 1, ["emergency-smelter"] = 2, ["emergency-powertrain"] = 3, ["emergency-power-pole"] = 4, miner = 10, furnace = 20, assembler = 30, lab = 40, ["power-machine"] = 50, generic = 60, ["deferred-network"] = 99 }
    return (order[a.category] or 50) < (order[b.category] or 50)
  end)
  for _, p in ipairs(list) do
    if p.category == "deferred-network" then
      root.skipped[p.item_name] = "deferred-network-submodule"
    else
      local pos, reason = plan_site(pair, p)
      if pos then
        p.target_position = { x = pos.x, y = pos.y }
        p.plan_reason = reason
        return p
      else
        root.skipped[p.item_name] = reason or "no-site"
      end
    end
  end
  return nil
end

local function try_place(pair, task)
  if not (valid_pair(pair) and task and task.item_name and task.entity_name and task.target_position) then return false, "invalid" end
  local source = find_item_source(pair, task.item_name)
  if not source then return false, "missing-item" end
  if not can_place(pair.station.surface, pair.station.force, task.entity_name, task.target_position) then return false, "blocked" end
  if not remove_one(source.inv, task.item_name) then return false, "remove-failed" end
  local ok, ent = pcall(function()
    return pair.station.surface.create_entity({
      name = task.entity_name,
      position = task.target_position,
      force = pair.station.force,
      raise_built = true,
      create_build_effect_smoke = true
    })
  end)
  if ok and ent and ent.valid then
    if _G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0339 and _G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0339.tag_built_entity then
      pcall(_G.TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0339.tag_built_entity, pair, ent, "construction-planner")
    elseif _G.TECH_PRIESTS_STATION_CATALOG_0327 and _G.TECH_PRIESTS_STATION_CATALOG_0327.claim_built_entity then
      pcall(_G.TECH_PRIESTS_STATION_CATALOG_0327.claim_built_entity, pair, ent, "built")
    end
    pair.last_construction_success_0338 = { tick = now(), item = task.item_name, entity = task.entity_name, x = task.target_position.x, y = task.target_position.y }
    local root = ensure_root()
    root.stats.placed = (root.stats.placed or 0) + 1
    root.stats.last_entity = task.entity_name
    root.stats.last_tick = now()
    draw_status(pair, string.format("[item=%s] placed %s", task.item_name, task.entity_name), 120)
    print_msg(pair, string.format("[Tech Priests 0.1.359] %s placed %s from %s near %s", entity_label(pair.priest, "Tech-Priest"), tostring(task.entity_name), tostring(task.item_name), entity_label(pair.station, "Cogitator Station")))
    return true, "placed"
  end
  -- If create failed after removal, return the item to the source if possible.
  pcall(function() source.inv.insert({ name = task.item_name, count = 1 }) end)
  return false, "create-failed"
end

function Build.service_pair(pair, reason)
  local root = ensure_root(); if root.enabled == false then return false, "disabled" end
  if not valid_pair(pair) then return false, "invalid-pair" end

  local task = current_task(pair)
  if not task then
    local p = choose_placeable(pair)
    if not p then return false, "no-placeable-plan" end
    task = {
      item_name = p.item_name,
      entity_name = p.entity_name,
      entity_type = p.entity_type,
      category = p.category,
      target_position = p.target_position,
      plan_reason = p.plan_reason,
      phase = "planned",
      created_tick = now(),
      source = p.source,
    }
    pair.construction_task_0338 = task
    preempt_conflicting_work_for_build(pair, task)
    root.stats.planned = (root.stats.planned or 0) + 1
    draw_status(pair, string.format("[item=%s] construction planned: %s", task.item_name, task.entity_name), 90)
  else
    preempt_conflicting_work_for_build(pair, task)
  end

  -- Station-bound inventory doctrine: the priest visibly returns to the station
  -- before walking out to place the object. The item is consumed from the station
  -- inventory at placement time; priest inventories are not active stock.
  local source = find_item_source(pair, task.item_name)
  if not source then
    pair.construction_task_0338 = nil
    draw_status(pair, string.format("[item=%s] construction cancelled: item missing", tostring(task.item_name)), 90)
    return false, "missing-item"
  end

  if source.source ~= "priest" and dist_sq(pair.priest.position, pair.station.position) > Build.station_close_distance_sq and task.phase ~= "moving-to-site" then
    local stale = (not pair.last_build_move_command_0338) or now() - (pair.last_build_move_command_0338.tick or 0) >= Build.move_refresh_ticks
    if stale then set_move(pair, pair.station.position, "returning-to-station-for-build") end
    task.phase = "returning-to-station"
    draw_status(pair, string.format("[item=%s] synchronizing with station inventory", task.item_name), 45)
    return true, "returning-station"
  end

  local d2 = dist_sq(pair.priest.position, task.target_position)
  if d2 > Build.close_distance_sq then
    local stale = (not pair.last_build_move_command_0338) or now() - (pair.last_build_move_command_0338.tick or 0) >= Build.move_refresh_ticks
    if stale then set_move(pair, task.target_position, "moving-to-build-site") end
    task.phase = "moving-to-site"
    pair.mode = "construction-moving"
    draw_status(pair, string.format("[item=%s] moving to build %s %.1fm", task.item_name, task.entity_name, math.sqrt(d2)), 45)
    return true, "moving-site"
  end

  task.phase = "placing"
  pair.mode = "constructing"
  draw_status(pair, string.format("[item=%s] placing %s", task.item_name, task.entity_name), 45)
  local ok, why = try_place(pair, task)
  pair.construction_task_0338 = nil
  if not ok then
    root.stats.failed = (root.stats.failed or 0) + 1
    draw_status(pair, string.format("[item=%s] construction failed: %s", tostring(task.item_name), tostring(why)), 120)
  end
  return ok, why
end

function Build.service_all(reason)
  local root = ensure_root(); if root.enabled == false then return 0 end
  local n = 0
  for _, pair in pairs(pair_map()) do
    if n >= Build.max_per_pulse then break end
    if valid_pair(pair) then
      local ok = Build.service_pair(pair, reason or "pulse")
      if ok then n = n + 1 end
    end
  end
  return n
end

local function selected_pair(player)
  if not (player and player.valid and player.selected) then return nil end
  local sel = player.selected
  for _, pair in pairs(pair_map()) do
    if pair and ((valid(pair.station) and pair.station == sel) or (valid(pair.priest) and pair.priest == sel)) then return pair end
  end
  return nil
end

function Build.describe_pair(pair)
  if not valid_pair(pair) then return "invalid pair" end
  local t = current_task(pair)
  local placeables = list_placeables(pair)
  local chunks = {
    string.format("station=%s unit=%s", entity_label(pair.station, "station"), tostring(pair.station.unit_number)),
    string.format("placeables=%d", #placeables),
    string.format("task=%s", t and (t.phase .. " " .. tostring(t.item_name) .. "->" .. tostring(t.entity_name)) or "none")
  }
  for i, p in ipairs(placeables) do
    if i > 8 then break end
    chunks[#chunks+1] = string.format("%s:%s/%s", p.item_name, p.category, p.entity_name)
  end
  return table.concat(chunks, " | ")
end

function Build.install_commands()
  if not commands then return end
  pcall(function() commands.remove_command("tp-build-0338") end)
  local function handle_build_command(event, label)
    local player = game.players[event.player_index]
    local arg = tostring(event.parameter or "status")
    local root = ensure_root()
    if arg == "enable" then root.enabled = true; player.print("[" .. label .. "] enabled") return end
    if arg == "disable" then root.enabled = false; player.print("[" .. label .. "] disabled") return end
    if arg == "debug-on" then root.debug_chat = true; player.print("[" .. label .. "] debug chat on") return end
    if arg == "debug-off" then root.debug_chat = false; player.print("[" .. label .. "] debug chat off") return end
    if arg == "all" then player.print("[" .. label .. "] serviced " .. tostring(Build.service_all("command-all")) .. " construction pairs") return end
    local pair = selected_pair(player)
    if not pair then player.print("[" .. label .. "] select a Cogitator Station or Tech-Priest") return end
    if arg == "kick" then
      local ok, why = Build.service_pair(pair, "command-kick")
      player.print("[" .. label .. "] kick=" .. tostring(ok) .. " reason=" .. tostring(why) .. " :: " .. Build.describe_pair(pair))
      return
    end
    player.print("[" .. label .. "] enabled=" .. tostring(root.enabled) .. " placed=" .. tostring(root.stats.placed or 0) .. " planned=" .. tostring(root.stats.planned or 0) .. " failed=" .. tostring(root.stats.failed or 0))
    player.print("[" .. label .. "] " .. Build.describe_pair(pair))
  end
  commands.add_command("tp-build-0338", "Tech-Priests construction planner status/kick/all/enable/disable/debug-on/debug-off", function(event) handle_build_command(event, "tp-build-0338") end)
  pcall(function() commands.remove_command("tp-build-0340") end)
  commands.add_command("tp-build-0340", "Tech-Priests 0.1.340 construction planner status/kick/all/enable/disable/debug-on/debug-off", function(event) handle_build_command(event, "tp-build-0340") end)
  pcall(function() commands.remove_command("tp-build-0343") end)
  commands.add_command("tp-build-0343", "Tech-Priests 0.1.342 construction planner status/kick/all/enable/disable/debug-on/debug-off", function(event) handle_build_command(event, "tp-build-0343") end)
  pcall(function() commands.remove_command("tp-build-0348") end)
  commands.add_command("tp-build-0348", "Tech-Priests 0.1.348 construction planner status/kick/all/enable/disable/debug-on/debug-off", function(event) handle_build_command(event, "tp-build-0348") end)
  pcall(function() commands.remove_command("tp-build-0352") end)
  pcall(function() commands.remove_command("tp-build-0357") end)
  pcall(function() commands.remove_command("tp-build-0359") end)
  commands.add_command("tp-build-0357", "Tech-Priests 0.1.357 station-bound construction planner status/kick/all/enable/disable/debug-on/debug-off", function(event) handle_build_command(event, "tp-build-0357") end)
  commands.add_command("tp-build-0359", "Tech-Priests 0.1.359 station-bound spiral construction planner status/kick/all/enable/disable/debug-on/debug-off", function(event) handle_build_command(event, "tp-build-0359") end)
  commands.add_command("tp-build-0352", "Tech-Priests 0.1.352 construction planner status/kick/all/enable/disable/debug-on/debug-off", function(event) handle_build_command(event, "tp-build-0352") end)
end

function Build.install()
  ensure_root()
  Build.install_commands()
  _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0338 = Build
  _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0340 = Build
  _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0342 = Build
  _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0343 = Build
  _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0348 = Build
  _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0357 = Build
  _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0359 = Build
  _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0352 = Build
  _G.TECH_PRIESTS_CONSTRUCTION_SITE_PLANNER_0359 = SitePlanner
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({ name = "construction_planner_0359", category = "construction", interval = Build.service_period or 5, priority = 55, budget = Build.max_per_pulse or 8, fn = function(event, budget) return Build.service_all("broker-periodic") end, note = "station-bound construction planner migrated from direct nth-tick" })
  else
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if R and type(R.on_nth_tick) == "function" then
      R.on_nth_tick(Build.service_period, function() Build.service_all("registry-periodic") end, { owner = "construction_planner_0359", category = "construction", note = "fallback until runtime broker is available", priority = "normal" })
    elseif script and script.on_nth_tick then
      script.on_nth_tick(Build.service_period, function()
        Build.service_all("periodic")
      end)
    end
  end
  if log then log("[Tech-Priests 0.1.359] construction planner station-bound spiral placement loaded") end
end

return Build
