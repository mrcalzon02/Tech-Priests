-- scripts/core/station_catalog.lua
-- Tech Priests 0.1.330 station radar catalog / known-resource map.
--
-- 0.1.327 changes the catalog from a loose polling scan into a radar-sweep
-- owned snapshot system.  Stations keep a current local picture of resources,
-- mineable products, nearby entities, storage contents, and subordinate station
-- trees.  Resource/mineable entities are claimed by one station at a time so
-- overlapping stations do not double-count the same rock, tree, or ore patch.

local Catalog = {}
local DenseScan1478 = require("scripts.core.catalog_dense_scan_1478")
local EntityIdentity1481 = require("scripts.core.entity_identity_1481")
local AuspexLayout1483 = require("scripts.core.catalog_gui_layout_1483")
local CatalogReuseGuard1484 = require("scripts.core.station_catalog_reuse_guard_1484")
local OwnerIndex1496 = require("scripts.core.catalog_owner_index_1496")

Catalog.version = "0.1.579"
Catalog.storage_key = "station_catalog_0327"
Catalog.legacy_storage_key = "station_catalog_0326"
Catalog.scan_period = 60
Catalog.continuation_period_1498 = 4
Catalog.query_budget_per_pulse_1498 = 1
Catalog.work_budget_per_pulse_1498 = 256
Catalog.scan_limit = 768
Catalog.max_dense_scan_queries_1478 = 13
Catalog.max_dense_scan_entities_1478 = 3072
-- Exactly the entity types should_catalog_entity rejects; keep all other
-- prototype families, including resources, machines and modded structures.
Catalog.noise_prefilter_types_1482 = {
  "transport-belt", "underground-belt", "splitter", "loader",
  "loader-1x1", "linked-belt", "character"
}
Catalog.clean_reuse_ticks_0570 = 60 * 10
Catalog.max_instances_per_item = 256
Catalog.gui_name = "tech_priests_known_resources_0326"
Catalog.max_gui_rows = 12
Catalog.tag_ttl = 60 * 60 * 10

local function valid(e) return e and e.valid end
local function now() return game and game.tick or 0 end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Catalog.storage_key] = storage.tech_priests[Catalog.storage_key] or {
    version = Catalog.version,
    stations = {},
    next_scan = {},
    owned_resources = {},
    render_tags = {},
    stats = {}
  }
  local root = storage.tech_priests[Catalog.storage_key]
  root.version = Catalog.version
  root.stations = root.stations or {}
  root.next_scan = root.next_scan or {}
  root.owned_resources = root.owned_resources or {}
  root.render_tags = root.render_tags or {}
  root.stats = root.stats or {}
  root.scan_jobs_1498 = root.scan_jobs_1498 or {}
  return root
end

local function pairs_table()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function station_unit(pair)
  return pair and (pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number)) or nil
end

local function pair_rank(pair)
  if _G.tech_priests_get_pair_tier_rank then
    local ok, rank = pcall(_G.tech_priests_get_pair_tier_rank, pair)
    if ok and tonumber(rank) then return tonumber(rank) end
  end
  local name = pair and pair.station and pair.station.valid and pair.station.name or tostring(pair and pair.tier or "")
  if name:find("void", 1, true) then return 5 end
  if name:find("planetary", 1, true) or name:find("magos", 1, true) then return 4 end
  if name:find("senior", 1, true) then return 3 end
  if name:find("intermediate", 1, true) then return 2 end
  return 1
end

local function distance_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or a[1] or 0) - (b.x or b[1] or 0)
  local dy = (a.y or a[2] or 0) - (b.y or b[2] or 0)
  return dx * dx + dy * dy
end

local function radius_for(pair)
  if pair and pair.station and pair.station.valid and _G.get_station_operating_radius then
    local ok, r = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(r) then return math.max(8, tonumber(r)) end
  end
  return tonumber(pair and pair.radius) or 24
end

local function sweep_ticks_for(pair)
  if _G.tech_priests_radar_sweep_ticks_for_pair_0279 then
    local ok, ticks = pcall(_G.tech_priests_radar_sweep_ticks_for_pair_0279, pair)
    if ok and tonumber(ticks) then return math.max(60, tonumber(ticks)) end
  end
  local rank = pair_rank(pair)
  return math.max(60, (70 - (rank * 10)) * 60)
end

local function entity_key(entity)
  return EntityIdentity1481.key(entity)
end

-- Read legacy ownership without using its coarse key for any new claim.
-- Old unitless resources can be reindexed incrementally by complete sweeps.
local function legacy_entity_key(entity)
  if not valid(entity) then return nil end
  if entity.unit_number then return "u:" .. tostring(entity.unit_number) end
  local p = entity.position or { x = 0, y = 0 }
  local surface = entity.surface and entity.surface.name or "?"
  return tostring(surface) .. ":" .. tostring(entity.name or entity.type)
    .. ":" .. tostring(math.floor((p.x or 0) * 10))
    .. ":" .. tostring(math.floor((p.y or 0) * 10))
end

local function is_station_entity(entity)
  if not valid(entity) then return false end
  if _G.is_station then local ok, result = pcall(_G.is_station, entity); if ok and result then return true end end
  return tostring(entity.name or ""):find("cogitator%-station") ~= nil
end

local function is_transient_belt_entity(entity)
  if not valid(entity) then return false end
  local t = entity.type
  return t == "transport-belt"
    or t == "underground-belt"
    or t == "splitter"
    or t == "loader"
    or t == "loader-1x1"
    or t == "linked-belt"
end

local function should_catalog_entity(entity)
  if not valid(entity) then return false end
  -- Normal radar catalog memory must remain stable. Belt lane contents are
  -- transient logistics events, not local resources. Desperation-mode belt
  -- sampling belongs in the doctrine resolver, not the station catalog/tag map.
  if is_transient_belt_entity(entity) then return false end
  if entity.type == "character" or entity.type == "player" then return false end
  return true
end

local function station_owner_valid(root, unit)
  local pair = unit and pairs_table()[unit] or nil
  return pair and pair.station and pair.station.valid
end

local function tag_destroy(object)
  if not object then return end
  pcall(function() if object.valid then object.destroy() end end)
end

local function release_render_tag(root, key)
  local tag = root.render_tags and root.render_tags[key]
  if not tag then return end
  tag_destroy(tag.object)
  tag_destroy(tag.text)
  root.render_tags[key] = nil
end

local function release_entity_ownership(root, key)
  if not key then return end
  -- Keep one module-local reverse index synchronized with the canonical
  -- persisted owner map; no extra keys are stored in Factorio saves.
  OwnerIndex1496.release(root, key)
  release_render_tag(root, key)
end

local function claim_entity(root, pair, entity, kind, known_key, scan_job)
  if not (root and pair and pair.station and pair.station.valid and valid(entity)) then return false end
  local unit = station_unit(pair)
  local key = known_key or entity_key(entity)
  if not (unit and key) then return false end
  local owner = root.owned_resources[key]
  if not owner then
    -- Compatibility for old saves: a previously claimed unitless resource
    -- should not switch owners during the identity upgrade. New claims always
    -- use the precise key, while complete scans retire old claim keys.
    owner = root.owned_resources[legacy_entity_key(entity)]
  end
  if owner and owner ~= unit and station_owner_valid(root, owner) then return false end
  OwnerIndex1496.assign(root, key, unit)
  local old = pair.catalog_owned_resource_keys_0327 or {}
  old[key] = true
  pair.catalog_owned_resource_keys_0327 = old
  local pending = root.scan_jobs_1498 and root.scan_jobs_1498[unit]
  if pending and pending ~= scan_job then
    pending.external_claims[key] = true
    local current = pairs_table()[unit]
    if current and current ~= pair then
      current.catalog_owned_resource_keys_0327 = current.catalog_owned_resource_keys_0327 or {}
      current.catalog_owned_resource_keys_0327[key] = true
    end
  end
  -- 0.1.328 rendered world tags are obsolete. Keep cleaning old saved
  -- tag objects, but avoid normalizing the entire catalog root for every
  -- claimed ore tile or mineable in a hot Auspex sweep.
  if root.render_tags and root.render_tags[key] then
    release_render_tag(root, key)
  end
  return true
end

function Catalog.draw_tag(pair, entity, key, kind)
  -- 0.1.328: catalog ownership is still recorded here, but the old always-on
  -- rectangle/text world tag is no longer drawn.  Known-resource presentation
  -- moved to scripts/core/network_visuals.lua, where it is player-local,
  -- alt-mode-only, circular, and icon-based.  This prevents the catalog from
  -- cluttering normal play or fighting machine recipe alt-mode displays.
  if not (pair and pair.station and pair.station.valid and valid(entity) and key) then return end
  local root = ensure_root()
  release_render_tag(root, key)
  root.render_tags[key] = nil
end

-- 0.1.339: immediate ownership hook used by Tech-Priest construction.  This
-- prevents a just-placed emergency facility from being stolen by an overlapping
-- station before the next radar sweep catches up.
function Catalog.claim_built_entity(pair, entity, kind)
  if not (pair and pair.station and pair.station.valid and valid(entity)) then return false end
  local root = ensure_root()
  return claim_entity(root, pair, entity, kind or "built")
end

function Catalog.entity_key(entity)
  return entity_key(entity)
end

local function add_count(tbl, key, count)
  if not key then return end
  local rec = tbl[key] or { count = 0, sources = 0 }
  rec.count = (rec.count or 0) + (tonumber(count) or 1)
  rec.sources = (rec.sources or 0) + 1
  tbl[key] = rec
end

local function add_source(tbl, key, source)
  if type(key) ~= "string" or key == "" then return end
  source = source or {}
  local rec = tbl[key] or { count = 0, sources = 0, instances = {} }
  rec.name = rec.name or key
  rec.item_name = rec.item_name or key
  rec.count = (rec.count or 0) + (tonumber(source.count) or 1)
  rec.sources = (rec.sources or 0) + 1
  rec.instances = rec.instances or {}

  -- Keep every concrete entity instance for overlays/acquisition, but retain a
  -- nearest/primary entity on rec.entity so older call sites still work.
  if source.entity and source.entity.valid then
    local inst = {
      entity = source.entity,
      inventory_id = source.inventory_id,
      kind = source.kind,
      distance_sq = source.distance_sq,
      owner_unit = source.owner_unit,
      count = tonumber(source.count) or 1
    }
    if #rec.instances < Catalog.max_instances_per_item then rec.instances[#rec.instances + 1] = inst end
    if (not rec.entity) or (not rec.entity.valid) or ((source.distance_sq or 999999999) < (rec.distance_sq or 999999999)) then
      rec.entity = source.entity
      rec.inventory_id = source.inventory_id
      rec.kind = source.kind
      rec.distance_sq = source.distance_sq
      rec.owner_unit = source.owner_unit
    end
  else
    if source.inventory_id then rec.inventory_id = source.inventory_id end
    if source.kind then rec.kind = source.kind end
    if source.distance_sq then rec.distance_sq = source.distance_sq end
    if source.owner_unit then rec.owner_unit = source.owner_unit end
  end
  tbl[key] = rec
end

local function safe_inventory(entity, inv_id)
  if not (entity and entity.valid and inv_id) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inv_id) end)
  if ok and inv and inv.valid then return inv end
  return nil
end

local function for_each_inventory_item(contents, callback)
  if type(contents) ~= "table" or type(callback) ~= "function" then return end
  for key, value in pairs(contents) do
    local name = nil
    local count = nil
    if type(key) == "string" then
      name = key
      if type(value) == "table" then count = tonumber(value.count or value.amount or value[2]) else count = tonumber(value) end
    elseif type(value) == "table" then
      name = value.name or value.item or value[1]
      count = tonumber(value.count or value.amount or value[2])
    end
    if type(name) == "string" and name ~= "" and (tonumber(count) or 0) > 0 then
      callback(name, tonumber(count) or 1)
    end
  end
end


-- 0.1.578: prototype-level economy caches. Catalog scans used to probe every
-- candidate entity with the full list of possible inventories and recompute
-- mineable products repeatedly. In a base with many identical assemblers,
-- furnaces, miners, rocks, and trees this is pure churn. Cache those stable
-- prototype facts by entity name/type so each prototype is discovered once and
-- reused thereafter.
local prototype_inventory_cache_0578 = prototype_inventory_cache_0578 or {}
local prototype_mineable_cache_0578 = prototype_mineable_cache_0578 or {}
local broad_inventory_probe_ids_cache_0742 = nil
local conservative_inventory_probe_ids_cache_0742 = nil
local inventory_type_names_1497, inventory_type_set_1497
-- These inventories are supplied by a live target, deceased character or
-- cargo unit, so LuaEntityPrototype.get_inventory_size cannot describe them.
local runtime_inventory_types_1497 = {
  ["character-corpse"] = true, ["cargo-pod"] = true,
  ["proxy-container"] = true, ["rocket-silo"] = true,
}

local function prototype_cache_key(entity)
  if not valid(entity) then return "invalid" end
  return tostring(entity.type or "?") .. ":" .. tostring(entity.name or "?")
end

local function read_bool_setting_0741(name, fallback)
  if type(_G.tech_priests_runtime_setting_bool_0626) == "function" then
    local ok, value = pcall(_G.tech_priests_runtime_setting_bool_0626, name, fallback)
    if ok then return value == true end
  end
  local s = settings and settings.global and settings.global[name]
  if s and s.value ~= nil then return s.value == true end
  return fallback == true
end

local function universal_inventory_scavenging_enabled_0741()
  return read_bool_setting_0741("tech-priests-universal-inventory-scavenging", true)
end

local function skip_wired_inventory_sources_enabled_0741()
  return read_bool_setting_0741("tech-priests-skip-wired-inventory-sources", true)
end

local function connector_has_connections_0741(connector)
  if not connector then return false, true end
  local ok_count, count = pcall(function() return connector.connection_count end)
  -- The native count already answers the empty case. Materializing the
  -- connection array after a successful zero repeats work for every machine.
  if ok_count and tonumber(count) then return tonumber(count) > 0, true end
  local ok_connections, connections = pcall(function() return connector.connections end)
  if ok_connections and type(connections) == "table" then
    return next(connections) ~= nil, true
  end
  return false, false
end

-- These Factorio connector IDs do not change while a game is running.
-- Keep one resolved list per defines table instead of creating two arrays
-- for every potentially wired inventory entity on every station sweep.
local CONNECTOR_NAMES_1493 = {
  "circuit_red", "circuit_green", "combinator_input_red",
  "combinator_input_green", "combinator_output_red", "combinator_output_green",
}
local connector_defs_1493 = nil
local connector_ids_1493 = {}
local function circuit_ids_1493()
  local defs = defines and defines.wire_connector_id or nil
  if defs ~= connector_defs_1493 then
    connector_defs_1493 = defs
    connector_ids_1493 = {}
    if defs then
      for _, name in ipairs(CONNECTOR_NAMES_1493) do
        local id = defs[name]
        if id then connector_ids_1493[#connector_ids_1493 + 1] = id end
      end
    end
  end
  return connector_ids_1493
end

local function entity_has_circuit_wire_0741(entity)
  if not valid(entity) then return false end
  local ids = circuit_ids_1493()
  if #ids > 0 and entity.get_wire_connector then
    local complete = true
    for _, id in ipairs(ids) do
      local ok, connector = pcall(function() return entity.get_wire_connector(id, false) end)
      if ok then
        local connected, known = connector_has_connections_0741(connector)
        if connected then return true end
        if not known then complete = false end
      else
        complete = false
      end
    end
    -- Successful modern connector queries are authoritative, including nil
    -- connectors. Do not probe removed legacy fields on every native entity.
    if complete then return false end
  end
  local ok_connected, connected = pcall(function() return entity.circuit_connected_entities end)
  if ok_connected and type(connected) == "table" then
    for _, list in pairs(connected) do
      if valid(list) then return true end
      if type(list) == "table" and next(list) ~= nil then return true end
    end
  end
  local wire_type = defines and defines.wire_type or nil
  if wire_type and entity.get_circuit_network then
    for i=1,2 do
      local wire = i == 1 and wire_type.red or wire_type.green
      if wire then
        local ok, network = pcall(function() return entity.get_circuit_network(wire) end)
        if ok and network then return true end
      end
    end
  end
  return false
end

local function entity_inventory_blocked_by_wire_0741(entity)
  return skip_wired_inventory_sources_enabled_0741() and entity_has_circuit_wire_0741(entity)
end

local function broad_inventory_probe_ids_0741()
  if broad_inventory_probe_ids_cache_0742 then return broad_inventory_probe_ids_cache_0742 end
  local out, seen = {}, {}
  for _, id in pairs(defines and defines.inventory or {}) do
    if type(id) == "number" and not seen[id] then out[#out + 1] = id; seen[id] = true end
  end
  table.sort(out)
  broad_inventory_probe_ids_cache_0742 = out
  return out
end

local function conservative_inventory_probe_ids_0741()
  if conservative_inventory_probe_ids_cache_0742 then return conservative_inventory_probe_ids_cache_0742 end
  local d = defines and defines.inventory or {}
  conservative_inventory_probe_ids_cache_0742 = {
    d.chest,
    d.furnace_result,
    d.furnace_source,
    d.assembling_machine_output,
    d.assembling_machine_input,
    d.fuel,
    d.burnt_result,
    d.lab_input,
    d.car_trunk,
    d.spider_trunk,
    d.cargo_wagon,
    d.rocket_silo_result,
    d.rocket_silo_output,
    d.character_corpse,
    d.roboport_material,
    d.roboport_robot,
    d.turret_ammo,
    d.artillery_turret_ammo,
  }
  return conservative_inventory_probe_ids_cache_0742
end

local function inventory_probe_ids_0578()
  return universal_inventory_scavenging_enabled_0741() and broad_inventory_probe_ids_0741() or conservative_inventory_probe_ids_0741()
end

local function inventory_scan_context_1493(station)
  -- These are runtime settings; a single scan executes synchronously, so
  -- reading them once preserves immediate config updates between sweeps.
  local universal = universal_inventory_scavenging_enabled_0741()
  return {
    universal = universal,
    skip_wired = skip_wired_inventory_sources_enabled_0741(),
    inventory_ids = universal and broad_inventory_probe_ids_0741()
      or conservative_inventory_probe_ids_0741(),
    station_position = station and station.position,
  }
end

local function inventory_ids_for_entity_0578(entity, context)
  if not valid(entity) then return {} end
  if runtime_inventory_types_1497[entity.type] then
    return context and context.inventory_ids or inventory_probe_ids_0578()
  end
  local mode = context
    and (context.universal and "universal" or "conservative")
    or (universal_inventory_scavenging_enabled_0741()
      and "universal" or "conservative")
  local key = prototype_cache_key(entity) .. ":inventory-mode=" .. mode
  local cached = prototype_inventory_cache_0578[key]
  if cached ~= nil then return cached end
  local out = {}
  for _, inv_id in ipairs(context and context.inventory_ids or inventory_probe_ids_0578()) do
    local ok, inv = pcall(function() return entity.get_inventory(inv_id) end)
    if ok and inv and inv.valid then out[#out + 1] = inv_id end
  end
  prototype_inventory_cache_0578[key] = out
  local root = ensure_root()
  root.stats.inventory_prototype_cache_misses_0578 = (root.stats.inventory_prototype_cache_misses_0578 or 0) + 1
  return out
end

local function inventory_types_1497()
  if inventory_type_names_1497 then
    return inventory_type_names_1497, inventory_type_set_1497
  end
  local entity_prototypes = prototypes and prototypes.entity
  if not entity_prototypes then return nil end
  local selected, names = {}, {}
  local ignored = {}
  for _, kind in ipairs(Catalog.noise_prefilter_types_1482) do ignored[kind] = true end
  local ids = broad_inventory_probe_ids_0741()
  for _, prototype in pairs(entity_prototypes) do
    local kind = prototype.type
    if kind and not ignored[kind] and not selected[kind] then
      if runtime_inventory_types_1497[kind] then
        selected[kind] = true
      else
        for _, id in ipairs(ids) do
          local ok, size = pcall(function() return prototype.get_inventory_size(id) end)
          -- A failed metadata read cannot certify a partial set of types.
          if not ok then return nil end
          if size ~= nil then selected[kind] = true; break end
        end
      end
    end
  end
  for kind in pairs(selected) do names[#names + 1] = kind end
  table.sort(names)
  inventory_type_names_1497, inventory_type_set_1497 = names, selected
  local root = ensure_root()
  root.stats.inventory_type_builds_1497 = (root.stats.inventory_type_builds_1497 or 0) + 1
  return names, selected
end

-- Expose immutable prototype membership for diagnostics; quantities and
-- inventory eligibility are deliberately absent from this retained metadata.
function Catalog.inventory_types()
  return inventory_types_1497()
end

local append_engine_candidates_1497
function Catalog.inventory_candidates(pair, requested_radius, requested_types)
  if not (pair and valid(pair.station)) then return nil end
  local station = pair.station
  local radius = tonumber(requested_radius) or radius_for(pair)
  local names = inventory_types_1497()
  local function discover()
    local position = station.position
    local query = { area = {
      {position.x - radius, position.y - radius},
      {position.x + radius, position.y + radius}
    } }
    if names then
      if #names == 0 then return {} end
      query.type = names
    end
    -- No item filter or result cap: empty sources and overflow membership
    -- must remain known when their contents change without an entity event.
    local ok, found = pcall(station.surface.find_entities_filtered, query)
    if not (ok and type(found) == "table") then return nil end
    local root = ensure_root()
    root.stats.inventory_initial_queries_1497 =
      (root.stats.inventory_initial_queries_1497 or 0) + 1
    return found
  end
  local economy = rawget(_G, "TechPriestsEfficiencyEconomy0587")
  if not economy then
    local ok, found = pcall(require, "scripts.core.efficiency_economy_0587")
    if ok then economy = found end
  end
  local candidates
  if names and economy and type(economy.source_candidates) == "function" then
    candidates = economy.source_candidates(pair, radius, "catalog-inventory-0327",
      names, "any-force", discover)
  else
    -- Compatibility runtimes lacking metadata/event ownership cannot claim a
    -- complete retained domain. They still receive a complete live result.
    candidates = discover()
  end
  if type(candidates) ~= "table" then return nil end
  local view, observed = append_engine_candidates_1497(pair, radius, candidates, requested_types)
  if names and #observed > 0 and economy
      and type(economy.observe_source_candidates) == "function" then
    economy.observe_source_candidates(pair, radius, "catalog-inventory-0327",
      names, "any-force", observed)
  end
  return view
end

local function inside_inventory_area_1497(entity, station, radius)
  if not (valid(entity) and entity.surface == station.surface) then return false end
  local position, origin = entity.position, station.position
  return position.x >= origin.x - radius and position.x <= origin.x + radius
    and position.y >= origin.y - radius and position.y <= origin.y + radius
end

local vehicle_types_1497 = {
  car = true, ["spider-vehicle"] = true, locomotive = true,
  ["cargo-wagon"] = true, ["fluid-wagon"] = true,
  ["artillery-wagon"] = true, ["infinity-cargo-wagon"] = true,
}
append_engine_candidates_1497 = function(pair, radius, candidates, requested_types)
  local _, all_types = inventory_types_1497()
  local accepted_types = all_types
  if requested_types then
    accepted_types = {}
    for _, kind in ipairs(requested_types) do accepted_types[kind] = true end
  end
  local station, out, units, observed = pair.station, {}, {}, {}
  local function append(entity, from_engine)
    if not valid(entity) or (accepted_types and not accepted_types[entity.type])
        or not inside_inventory_area_1497(entity, station, radius) then return end
    local unit = entity.unit_number
    if unit then
      if units[unit] then return end
      units[unit] = true
    else
      for _, present in ipairs(out) do if present == entity then return end end
    end
    out[#out + 1] = entity
    if from_engine then observed[#observed + 1] = entity end
  end
  for _, entity in ipairs(candidates) do append(entity) end
  local wants_vehicles = false
  for kind in pairs(vehicle_types_1497) do
    if not accepted_types or accepted_types[kind] then wants_vehicles = true; break end
  end
  -- These are engine-maintained identity lists, not spatial rediscovery.
  -- In particular, autonomous vehicle arrivals have no general move event.
  if wants_vehicles and game and type(game.get_vehicles) == "function" then
    local ok, vehicles = pcall(game.get_vehicles, {surface = station.surface})
    if ok and type(vehicles) == "table" then
      for _, entity in ipairs(vehicles) do append(entity, true) end
      local stats = ensure_root().stats
      stats.inventory_vehicle_list_reads_1497 = (stats.inventory_vehicle_list_reads_1497 or 0) + 1
    end
  end
  local wants_robots = not accepted_types or accepted_types["logistic-robot"]
    or accepted_types["construction-robot"]
  if wants_robots then
    -- The engine omits orphan robots from these lists. The initial local
    -- seed and 0587's pre-cell-removal batch retain known orphans. A never
    -- observed orphan outside that seed, or an unraised scripted creation,
    -- has no complete arrival API; do not hide that gap with a polling scan.
    for _, force in pairs(game and game.forces or {}) do
      if force.valid then
        local networks = (force.logistic_networks or {})[station.surface.name] or {}
        for _, network in pairs(networks) do
          if network.valid then
            for _, robot in ipairs(network.robots) do append(robot, true) end
          end
        end
      end
    end
  end
  if not accepted_types or accepted_types["cargo-pod"] then
    for _, entity in ipairs(candidates) do
      if valid(entity) and entity.type == "rocket-silo" then
        -- A filled awaiting-launch pod exists before the ascent events.
        local ok, pod = pcall(function() return entity.cargo_pod end)
        if ok then append(pod, true) end
        local rocket_ok, rocket = pcall(function() return entity.rocket end)
        if rocket_ok and valid(rocket) then
          local pod_ok, attached = pcall(function() return rocket.attached_cargo_pod end)
          if pod_ok then append(attached, true) end
        end
      end
    end
  end
  return out, observed
end

function Catalog.find_inventory_source(pair, item_name, options)
  if not (pair and valid(pair.station) and item_name) then return nil end
  options = options or {}
  local station = pair.station
  local radius = tonumber(options.radius) or radius_for(pair)
  local context = inventory_scan_context_1493(station)
  if options.skip_wired ~= nil then context.skip_wired = options.skip_wired end
  local best
  local function consider(entity, id, inventory)
    if not (inventory and inventory.valid) then return end
    local ok, count = pcall(function() return inventory.get_item_count(item_name) end)
    if not (ok and (tonumber(count) or 0) > 0) then return end
    local distance = distance_sq(entity.position, station.position)
    if not best or distance < best.station_distance_sq then
      best = { kind = options.kind or "known-storage-0327", source = entity,
        inventory_id = id, item_name = item_name, count = 1,
        station_distance_sq = distance }
    end
  end
  if not options.exclude_station then
    local inventory = _G.get_station_inventory and _G.get_station_inventory(station)
      or safe_inventory(station, defines and defines.inventory and defines.inventory.chest)
    consider(station, defines and defines.inventory and defines.inventory.chest, inventory)
  end
  for _, entity in ipairs(Catalog.inventory_candidates(pair, radius) or {}) do
    if entity ~= station and should_catalog_entity(entity)
        and inside_inventory_area_1497(entity, station, radius)
        and not (context.skip_wired and entity_has_circuit_wire_0741(entity)) then
      for _, id in ipairs(options.inventory_ids or inventory_ids_for_entity_0578(entity, context)) do
        consider(entity, id, safe_inventory(entity, id))
      end
    end
  end
  return best
end

local function collect_inventory(catalog, entity, station, scan_context)
  if not valid(entity) or not should_catalog_entity(entity) then return end
  local context = scan_context or inventory_scan_context_1493(station)
  -- Machines with no supported inventory need no wire-connector probes.
  -- Connected inventories remain excluded exactly as before.
  local inv_ids = inventory_ids_for_entity_0578(entity, context)
  if #inv_ids == 0 then return end
  if context.skip_wired and entity_has_circuit_wire_0741(entity) then
    catalog.wired_sources_skipped_1495 =
      (catalog.wired_sources_skipped_1495 or 0) + 1
    local root = ensure_root()
    root.stats.wired_inventory_sources_skipped_0741 =
      (root.stats.wired_inventory_sources_skipped_0741 or 0) + 1
    return
  end
  local source_distance = distance_sq(entity.position,
    context.station_position or station.position)
  for _, inv_id in ipairs(inv_ids) do
    local inv = safe_inventory(entity, inv_id)
    if inv then
      local ok, contents = pcall(function() return inv.get_contents() end)
      if ok and contents then
        for_each_inventory_item(contents, function(item, count)
          add_source(catalog.storage_items, item, {
            entity = entity, inventory_id = inv_id,
            count = count, kind = "inventory",
            distance_sq = source_distance,
          })
        end)
      end
    end
  end
end

local function mineable_products(entity)
  if not valid(entity) then return {} end
  local key = prototype_cache_key(entity)
  local cached = prototype_mineable_cache_0578[key]
  -- This private helper's consumers only read names/amounts. Reuse the
  -- existing immutable prototype facts instead of cloning them per ore tile.
  if cached ~= nil then return cached end
  local out = {}
  local ok, props = pcall(function() return entity.prototype and entity.prototype.mineable_properties end)
  if ok and props and props.products then
    for _, product in pairs(props.products) do
      local name = product.name or product[1]
      if name then out[#out + 1] = { name = name, amount = product.amount or product.amount_min or 1 } end
    end
  end
  if #out == 0 and entity.type == "resource" and entity.name then out[#out + 1] = { name = entity.name, amount = 1 } end
  prototype_mineable_cache_0578[key] = out
  local root = ensure_root()
  root.stats.mineable_prototype_cache_misses_0578 = (root.stats.mineable_prototype_cache_misses_0578 or 0) + 1
  return out
end

local function is_mineable_candidate(entity)
  if not valid(entity) then return false end
  if entity.type == "resource" or entity.type == "tree" then
    return true, mineable_products(entity)
  end
  if entity.type == "simple-entity" or entity.type == "simple-entity-with-owner" then
    local products = mineable_products(entity)
    return #products > 0, products
  end
  return false
end

local function empty_catalog(pair, radius)
  local station = pair.station
  local geometry = CatalogReuseGuard1484.snapshot(pair, radius)
  return {
    version = Catalog.version,
    station_surface_1484 = geometry and geometry.station_surface_1484 or nil,
    station_force_1484 = geometry and geometry.station_force_1484 or nil,
    station_position_1484 = geometry and geometry.station_position_1484 or nil,
    tick = now(),
    station_unit = station_unit(pair),
    station_name = station.name,
    station_backer_name = station.backer_name,
    surface = station.surface and station.surface.name or nil,
    radius = radius,
    rank = pair_rank(pair),
    resources = {},
    mineable_products = {},
    entities = {},
    storage_items = {},
    subordinate_stations = {},
    owned_keys = {},
    active_resource_count = 0,
    entity_count = 0,
    stored_item_kinds = 0,
    owned_resource_count = 0,
    wired_sources_skipped_1495 = 0,
    sweep_ticks = sweep_ticks_for(pair),
    source = "radar-sweep-snapshot-0327"
  }
end


local function clean_reuse_allowed_0570(pair, catalog, radius)
  if not (pair and pair.station and pair.station.valid and catalog) then return false end
  if catalog.dirty_0634 then return false end
  -- No old or relocated snapshot may hide a different physical station area.
  if not CatalogReuseGuard1484.matches(pair, catalog, radius) then return false end
  -- A truncated snapshot must never receive the clean-reuse extension.
  if catalog.scan_limit_reached_1477 then return false end
  local age = now() - (tonumber(catalog.tick or 0) or 0)
  if age < 0 or age > Catalog.clean_reuse_ticks_0570 then return false end
  local dirty_check = rawget(_G, "tech_priests_efficiency_0570_dirty_near_pair")
  if type(dirty_check) == "function" then
    local ok, dirty = pcall(dirty_check, pair, radius or catalog.radius or 32, catalog.tick or 0)
    if ok and dirty then return false end
  end
  return true
end

local function note_catalog_owned(root, pair, catalog, key, scan_job)
  local pending = root.scan_jobs_1498 and root.scan_jobs_1498[station_unit(pair)]
  -- Radar events may update the published snapshot during a continuation.
  -- Protect their claims without mutating an aliased frozen retirement set.
  if pending and pending ~= scan_job and catalog.owned_keys == pending.old_keys then return end
  if not catalog.owned_keys[key] then
    catalog.owned_keys[key] = true
    catalog.owned_resource_count = catalog.owned_resource_count + 1
  end
end

local function add_entity_to_catalog(root, pair, catalog, entity, station, scan_job, known_key)
  if not valid(entity) then return end
  if entity == station or not should_catalog_entity(entity) then return end
  local name = entity.name or entity.type
  if not catalog.entities[name] then catalog.entity_count = catalog.entity_count + 1 end
  add_count(catalog.entities, name, 1)
  if entity.type == "resource" then
    local key = known_key or entity_key(entity)
    if claim_entity(root, pair, entity, "resource", key, scan_job) then
      note_catalog_owned(root, pair, catalog, key, scan_job)
      if not catalog.resources[entity.name] then
        catalog.active_resource_count = catalog.active_resource_count + 1
      end
      add_source(catalog.resources, entity.name, { entity = entity, count = entity.amount or 1, kind = "resource", distance_sq = distance_sq(entity.position, station.position), owner_unit = station_unit(pair) })
      for _, product in ipairs(mineable_products(entity)) do
        add_source(catalog.mineable_products, product.name, { entity = entity, count = product.amount or 1, kind = "resource-product", distance_sq = distance_sq(entity.position, station.position), owner_unit = station_unit(pair) })
      end
    end
  else
    local mineable, products = is_mineable_candidate(entity)
    local key = mineable and (known_key or entity_key(entity)) or nil
    if mineable and claim_entity(root, pair, entity, "mineable", key, scan_job) then
      note_catalog_owned(root, pair, catalog, key, scan_job)
      for _, product in ipairs(products) do
        add_source(catalog.mineable_products, product.name, { entity = entity, count = product.amount or 1, kind = "mineable-entity", distance_sq = distance_sq(entity.position, station.position), owner_unit = station_unit(pair) })
      end
    end
  end
end

local function release_absent_owned_keys(root, pair, new_keys)
  local old = pair.catalog_owned_resource_keys_0327 or {}
  for key in pairs(old) do
    if not new_keys[key] and root.owned_resources[key] == station_unit(pair) then
      release_entity_ownership(root, key)
    end
  end
  pair.catalog_owned_resource_keys_0327 = new_keys
end

function Catalog.cleanup_station(unit, reason)
  local root = ensure_root()
  if not unit then return end
  root.stations[unit] = nil
  root.next_scan[unit] = nil
  root.scan_jobs_1498[unit] = nil
  -- O(claims owned by this station), rather than O(all claimed resources).
  -- The reverse index is rebuilt once after load from canonical saved claims.
  local removed = OwnerIndex1496.release_station(root, unit, function(key)
    release_render_tag(root, key)
  end)
  root.stats.owner_index_cleanup_keys_1496 =
    (root.stats.owner_index_cleanup_keys_1496 or 0) + removed
  root.stats.station_cleanups = (root.stats.station_cleanups or 0) + 1
  root.stats.last_cleanup_reason = reason
  root.stats.last_cleanup_tick = now()
end

function Catalog.prune_invalid()
  local root = ensure_root()
  for unit in pairs(root.stations or {}) do
    if not station_owner_valid(root, unit) then
      Catalog.cleanup_station(unit, "invalid-station")
    end
  end
  -- Check one entry per *owning station*, not one per rock/ore/tree claim.
  -- Also detects orphan claims from old saves without catalog snapshots.
  local owners_checked = 0
  for unit in pairs(OwnerIndex1496.for_root(root)) do
    owners_checked = owners_checked + 1
    if not station_owner_valid(root, unit) then
      Catalog.cleanup_station(unit, "orphan-ownership")
    end
  end
  root.stats.owner_index_owner_checks_1496 =
    (root.stats.owner_index_owner_checks_1496 or 0) + owners_checked
end

-- Scheduled surveys keep their partial work in this existing catalog owner.
-- Published catalogs are replaced only after all bounded phases complete.
local resumed_jobs_1498 = setmetatable({}, {__mode = "k"})

local function job_dirty(root, job)
  if job.inventory_changed or root.next_scan[job.unit] ~= job.next_due then return true end
  if job.inventory_record then
    local economy = rawget(_G, "TechPriestsEfficiencyEconomy0587")
      or package.loaded["scripts.core.efficiency_economy_0587"]
    local record = economy and economy.borrow_source_candidates
      and economy.borrow_source_candidates(job.pair, job.radius, "catalog-inventory-0327",
        job.inventory_types, "any-force")
    if record ~= job.inventory_record or record.list ~= job.inventory_list
        or (record.identity_revision_1498 or 0) ~= job.inventory_revision then return true end
  end
  return false
end

local function begin_job(root, pair, roster)
  local unit, radius = station_unit(pair), radius_for(pair)
  if not unit then return nil end
  local existing = root.stations[unit]
  if clean_reuse_allowed_0570(pair, existing, radius) then
    root.next_scan[unit] = now() + math.min(sweep_ticks_for(pair), Catalog.clean_reuse_ticks_0570)
      + (unit % 60)
    root.stats.clean_reuse_skips_0570 = (root.stats.clean_reuse_skips_0570 or 0) + 1
    return nil
  end
  local station = pair.station
  local job = {version = 1, unit = unit, pair = pair, station = station,
    surface = station.surface, radius = radius, started_tick = now(),
    next_due = now() + sweep_ticks_for(pair), phase = "inventory-prepare",
    catalog = empty_catalog(pair, radius), roster = roster, subordinate_cursor = 1,
    old_keys = pair.catalog_owned_resource_keys_0327 or {}, external_claims = {},
    area = {{station.position.x - radius, station.position.y - radius},
      {station.position.x + radius, station.position.y + radius}},
    pulses = 0, work = 0, queries = 0,
  }
  -- Freeze the old set for bounded retirement. Later ordinary/radar/build
  -- claims enter the new set and are protected even if absent from this scan.
  pair.catalog_owned_resource_keys_0327 = {}
  root.scan_jobs_1498[unit] = job
  root.next_scan[unit] = job.next_due
  root.stats.continuation_started_1498 = (root.stats.continuation_started_1498 or 0) + 1
  resumed_jobs_1498[job] = true
  return job
end

local function reset_map_phase(job, phase)
  job.phase, job.map_cursor, job.map_seen = phase, nil, {}
end

local function next_map_key(job, map)
  local key = next(map, job.map_cursor)
  job.map_cursor = key
  if key == nil then return nil end
  if job.map_seen[key] then return key, false end
  job.map_seen[key] = true
  return key, true
end

local function subordinate_before(a, b)
  if (a.rank or 0) ~= (b.rank or 0) then return (a.rank or 0) > (b.rank or 0) end
  return (a.distance_sq or 999999) < (b.distance_sq or 999999)
end

-- One merge output/comparison is one work unit; no whole-list table.sort at
-- publication. Arrays and numeric cursors survive an actual save/reload.
local function sort_subordinate_step(job)
  local list = job.catalog.subordinate_stations
  local count = #list
  if count < 2 then return true end
  local sort = job.sort
  if not sort then
    sort = {width = 1, start = 1, output = {}}
    job.sort = sort
  end
  if sort.width >= count then return true end
  if not sort.left then
    if sort.start > count then
      job.catalog.subordinate_stations = sort.output
      sort.output, sort.start, sort.width = {}, 1, sort.width * 2
      if sort.width >= count then return true end
      list = job.catalog.subordinate_stations
    end
    sort.left = sort.start
    sort.left_end = math.min(count, sort.start + sort.width - 1)
    sort.right = sort.left_end + 1
    sort.right_end = math.min(count, sort.start + sort.width * 2 - 1)
  end
  local use_left = sort.left <= sort.left_end and
    (sort.right > sort.right_end or not subordinate_before(list[sort.right], list[sort.left]))
  if use_left then
    sort.output[#sort.output + 1] = list[sort.left]
    sort.left = sort.left + 1
  else
    sort.output[#sort.output + 1] = list[sort.right]
    sort.right = sort.right + 1
  end
  if sort.left > sort.left_end and sort.right > sort.right_end then
    sort.start, sort.left = sort.start + sort.width * 2, nil
  end
  return false
end

local function note_scan_info(root, job)
  local catalog, info = job.catalog, job.dense.info
  catalog.scan_source_1478 = "direct-continuation"
  catalog.scan_queries_1478 = info.queries
  catalog.scan_reason_1478 = info.reason
  catalog.scan_identity_collisions_1481 = info.identity_collisions
  catalog.scan_filtered_queries_1482 = info.filtered_queries
  catalog.scan_prefilter_fallbacks_1482 = info.prefilter_fallbacks
  catalog.scan_entities_1478 = info.unique
  catalog.scan_incomplete_1478 = not info.complete
  catalog.scan_limit_reached_1477 = not info.complete
  root.stats.scan_queries_1478 = (root.stats.scan_queries_1478 or 0) + info.queries
  root.stats.scan_prefilter_filtered_queries_1482 =
    (root.stats.scan_prefilter_filtered_queries_1482 or 0) + info.filtered_queries
  root.stats.scan_prefilter_fallbacks_1482 =
    (root.stats.scan_prefilter_fallbacks_1482 or 0) + info.prefilter_fallbacks
  root.stats.scan_identity_collisions_1481 =
    (root.stats.scan_identity_collisions_1481 or 0) + info.identity_collisions
  if not info.complete then
    root.stats.scan_limit_reached_1477 = (root.stats.scan_limit_reached_1477 or 0) + 1
    root.stats.dense_scans_incomplete_1478 = (root.stats.dense_scans_incomplete_1478 or 0) + 1
  elseif info.queries > 1 then
    root.stats.dense_scans_completed_1478 = (root.stats.dense_scans_completed_1478 or 0) + 1
  end
end

local function prepare_inventory(root, job, query_budget)
  local names, types = inventory_types_1497()
  job.inventory_types, job.inventory_set = names, types
  local economy = rawget(_G, "TechPriestsEfficiencyEconomy0587")
    or package.loaded["scripts.core.efficiency_economy_0587"]
  local record, queried
  if names and economy and type(economy.borrow_source_candidates) == "function" then
    record = economy.borrow_source_candidates(job.pair, job.radius, "catalog-inventory-0327",
      names, "any-force")
    if not record then
      if query_budget <= 0 then return false, 0 end
      record, queried = economy.borrow_source_candidates(job.pair, job.radius,
        "catalog-inventory-0327", names, "any-force", function()
          local ok, found = pcall(job.surface.find_entities_filtered,
            {area = job.area, type = names})
          if ok and type(found) == "table" then
            root.stats.inventory_initial_queries_1497 =
              (root.stats.inventory_initial_queries_1497 or 0) + 1
            return found
          end
        end)
    end
  end
  job.split_inventory = record ~= nil
  if record then
    -- This is the existing event/engine-observed identity snapshot. Scheduled
    -- visual work does not refresh global vehicle/robot arrays; item and UI
    -- requests still do so through inventory_candidates. Revision checks make
    -- concurrent membership compaction/addition explicit rather than silent.
    job.inventory_record, job.inventory_list = record, record.list
    job.inventory_revision = record.identity_revision_1498 or 0
    job.inventory_limit, job.inventory_cursor = #record.list, 1
  end
  local excluded = {}
  for _, kind in ipairs(Catalog.noise_prefilter_types_1482) do excluded[#excluded + 1] = kind end
  if record then for _, kind in ipairs(names) do excluded[#excluded + 1] = kind end end
  job.dense = assert(DenseScan1478.begin(job.area, {limit = Catalog.scan_limit,
    max_queries = Catalog.max_dense_scan_queries_1478,
    max_entities = Catalog.max_dense_scan_entities_1478, exclude_types = excluded}))
  job.phase = "world"
  return true, queried and 1 or 0
end

local function publish_job(root, job)
  local catalog, pair = job.catalog, job.pair
  local previous = root.stations[job.unit]
  catalog.storage_items = previous and previous.storage_items or {}
  catalog.inventory_tick_1497 = previous and previous.inventory_tick_1497 or nil
  catalog.stored_item_kinds = previous and previous.stored_item_kinds or 0
  -- Reuse age starts with this survey's admission, not its later publication;
  -- otherwise continuation latency would extend the existing clean-reuse TTL.
  catalog.tick = job.started_tick
  catalog.scan_started_tick_1498 = job.started_tick
  catalog.scan_finished_tick_1498 = now()
  catalog.scan_slices_1498 = job.pulses
  catalog.scan_work_1498 = job.work
  catalog.inventory_members_1497 = job.inventory_members or 0
  if job_dirty(root, job) then
    catalog.dirty_0634 = true
    root.next_scan[job.unit] = 0
  else
    -- Preserve the original start-to-start sweep deadline; completion latency
    -- must not quietly become an extra delay on every survey.
    root.next_scan[job.unit] = job.next_due
  end
  root.stations[job.unit] = catalog
  pair.known_resources_0326, pair.known_resources_0327 = catalog, catalog
  root.scan_jobs_1498[job.unit] = nil
  root.stats.scans = (root.stats.scans or 0) + 1
  root.stats.last_scan_tick = now()
  root.stats.inventory_members_reused_1497 =
    (root.stats.inventory_members_reused_1497 or 0) + (job.inventory_members or 0)
  root.stats.continuation_completed_1498 = (root.stats.continuation_completed_1498 or 0) + 1
  local latency = now() - job.started_tick
  root.stats.continuation_last_latency_ticks_1498 = latency
  root.stats.continuation_max_latency_ticks_1498 =
    math.max(root.stats.continuation_max_latency_ticks_1498 or 0, latency)
  root.stats.continuation_total_latency_ticks_1498 =
    (root.stats.continuation_total_latency_ticks_1498 or 0) + latency
end

local function resume_job(root, job, work_budget, query_budget)
  local used, queries = 0, 0
  if not resumed_jobs_1498[job] then
    -- Lua tables can be rehashed when loaded. Restart map traversal, skipping
    -- saved processed keys, instead of trusting the previous hash-order cursor.
    job.map_cursor = nil
    resumed_jobs_1498[job] = true
  end
  local current = pairs_table()[job.unit]
  if not job.cancelled and (current ~= job.pair or not valid(job.station)
      or current.station ~= job.station
      or not CatalogReuseGuard1484.matches(current, job.catalog, radius_for(current))) then
    job.cancelled = true
    reset_map_phase(job, "cancel-claims")
  end
  if not job.cancelled and job_dirty(root, job) then job.dirtied = true end
  job.pulses = job.pulses + 1
  while used < work_budget and root.scan_jobs_1498[job.unit] == job do
    if job.phase == "inventory-prepare" then
      local ready, calls = prepare_inventory(root, job, query_budget - queries)
      queries = queries + calls
      if not ready then break end
      used = used + 1
    elseif job.phase == "world" then
      -- Every distinct result may require one classification too; reserve that
      -- work before advancing the resumable native-result/dedup cursor.
      local allowance = math.floor((work_budget - used) / 2)
      if allowance < 1 then break end
      local batch, _, done, spent = DenseScan1478.step(job.surface, job.dense,
        {query_budget = query_budget - queries, entity_budget = allowance, key_of = entity_key})
      used, queries = used + spent.entities, queries + spent.queries
      for index, entity in ipairs(batch) do
        used = used + 1
        -- Native area queries include collision boxes overlapping the square,
        -- even when the entity center is outside it. Preserve that world-scan
        -- selection; retained inventory keeps its separate center policy.
        if valid(entity) and entity.surface == job.surface
            and not (job.split_inventory and job.inventory_set[entity.type]) then
          add_entity_to_catalog(root, job.pair, job.catalog, entity, job.station, job, spent.keys[index])
        end
      end
      if done then
        note_scan_info(root, job)
        job.phase = "inventory"
      elseif spent.entities == 0 and spent.queries == 0 then break end
    elseif job.phase == "inventory" then
      local index = job.inventory_cursor or 1
      if job.split_inventory and index <= job.inventory_limit then
        local entity = job.inventory_list[index]
        job.inventory_cursor = index + 1
        used = used + 1
        if valid(entity) and job.inventory_set[entity.type]
            and inside_inventory_area_1497(entity, job.station, job.radius) then
          add_entity_to_catalog(root, job.pair, job.catalog, entity, job.station, job)
          job.inventory_members = (job.inventory_members or 0) + 1
        end
      else
        if job_dirty(root, job) then job.inventory_changed, job.dirtied = true, true end
        job.phase = "subordinates"
      end
    elseif job.phase == "subordinates" then
      local unit = job.roster[job.subordinate_cursor]
      if unit == nil then job.phase = "subordinate-sort"
      else
        job.subordinate_cursor = job.subordinate_cursor + 1
        used = used + 1
        local other = pairs_table()[unit]
        if unit ~= job.unit and other and valid(other.station)
            and other.station.force == job.station.force and other.station.surface == job.surface then
          local distance = distance_sq(other.station.position, job.station.position)
          local rank = pair_rank(other)
          if rank < job.catalog.rank and distance <= (job.radius * 3) ^ 2 then
            local rows = job.catalog.subordinate_stations
            rows[#rows + 1] = {unit = station_unit(other), name = other.station.name,
              backer_name = other.station.backer_name, rank = rank, distance_sq = distance,
              mode = other.mode, emergency = other.independent_emergency_operation_0184 ~= nil}
          end
        end
      end
    elseif job.phase == "subordinate-sort" then
      used = used + 1
      if sort_subordinate_step(job) then reset_map_phase(job, "retire") end
    elseif job.phase == "retire" then
      local key, fresh = next_map_key(job, job.old_keys)
      if key == nil then job.phase = "publish"
      else
        used = used + 1
        if fresh and root.owned_resources[key] == job.unit
            and not job.pair.catalog_owned_resource_keys_0327[key] then
          if not job.dense.info.complete or job.dirtied then
            job.pair.catalog_owned_resource_keys_0327[key] = true
          else release_entity_ownership(root, key) end
        end
      end
    elseif job.phase == "cancel-claims" then
      local key, fresh = next_map_key(job, job.catalog.owned_keys)
      if key == nil then reset_map_phase(job, "cancel-old")
      else
        used = used + 1
        if fresh and not job.old_keys[key] and not job.external_claims[key]
            and root.owned_resources[key] == job.unit then
          release_entity_ownership(root, key)
          job.pair.catalog_owned_resource_keys_0327[key] = nil
        end
      end
    elseif job.phase == "cancel-old" then
      local key, fresh = next_map_key(job, job.old_keys)
      if key == nil then
        job.cancel_target = current
        reset_map_phase(job, "cancel-transfer")
      else
        used = used + 1
        if fresh and root.owned_resources[key] == job.unit then
          job.pair.catalog_owned_resource_keys_0327[key] = true
        end
      end
    elseif job.phase == "cancel-transfer" then
      -- A repair may replace the pair table while keeping the same live
      -- station. Its canonical claims must remain available for retirement
      -- by the replacement pair's next complete survey.
      if job.cancel_target ~= current then
        job.cancel_target = current
        reset_map_phase(job, "cancel-transfer")
      end
      local key, fresh = next_map_key(job, job.pair.catalog_owned_resource_keys_0327)
      if key == nil then
        root.scan_jobs_1498[job.unit] = nil
        if current and valid(current.station) then root.next_scan[job.unit] = 0 end
        root.stats.continuation_cancelled_1498 = (root.stats.continuation_cancelled_1498 or 0) + 1
        used = used + 1
      else
        used = used + 1
        if fresh and current and valid(current.station) and root.owned_resources[key] == job.unit then
          current.catalog_owned_resource_keys_0327 = current.catalog_owned_resource_keys_0327 or {}
          current.catalog_owned_resource_keys_0327[key] = true
        end
      end
    elseif job.phase == "publish" then
      used = used + 1
      job.work, job.queries = job.work + used, job.queries + queries
      publish_job(root, job)
      return used, queries
    else error("Unknown catalog continuation phase: " .. tostring(job.phase)) end
  end
  job.work, job.queries = job.work + used, job.queries + queries
  return used, queries
end

local function supersede_job(root, pair, unit)
  local job = root.scan_jobs_1498[unit]
  if not job then return end
  -- Explicit synchronous compatibility is allowed to finish its own full work;
  -- include every old/new claim in its existing complete-scan retirement set.
  local keys = pair.catalog_owned_resource_keys_0327 or {}
  for key in pairs(job.old_keys) do
    if root.owned_resources[key] == unit then keys[key] = true end
  end
  pair.catalog_owned_resource_keys_0327 = keys
  root.scan_jobs_1498[unit] = nil
  root.stats.continuation_superseded_1498 = (root.stats.continuation_superseded_1498 or 0) + 1
end

function Catalog.scan_pair(pair)
  if not (pair and pair.station and pair.station.valid) then return nil end
  local station = pair.station
  local unit = station_unit(pair)
  if not unit then return nil end
  local root = ensure_root()
  supersede_job(root, pair, unit)
  local radius = radius_for(pair)
  local existing = root.stations[unit]
  if clean_reuse_allowed_0570(pair, existing, radius) then
    local ticks = sweep_ticks_for(pair)
    root.next_scan[unit] = now() + math.min(ticks, Catalog.clean_reuse_ticks_0570) + ((unit or 0) % 60)
    root.stats.clean_reuse_skips_0570 = (root.stats.clean_reuse_skips_0570 or 0) + 1
    pair.known_resources_0326 = existing
    pair.known_resources_0327 = existing
    return existing
  end
  local area = { { station.position.x - radius, station.position.y - radius }, { station.position.x + radius, station.position.y + radius } }
  local catalog = empty_catalog(pair, radius)
  local inventory_types, inventory_set = inventory_types_1497()
  local retained = inventory_types and Catalog.inventory_candidates(pair, radius) or nil
  local split_inventory = type(retained) == "table"
  local excluded = Catalog.noise_prefilter_types_1482
  if split_inventory then
    excluded = {}
    for _, kind in ipairs(Catalog.noise_prefilter_types_1482) do excluded[#excluded + 1] = kind end
    for _, kind in ipairs(inventory_types) do excluded[#excluded + 1] = kind end
  end

  local ok_ents, entities, scan_complete = false, nil, false
  local indexed_provider = rawget(_G, "tech_priests_efficiency_0579_entities_for_area")
  if type(indexed_provider) == "function" then
    local ok_idx, idx_entities = pcall(indexed_provider, station.surface, area, Catalog.scan_limit, true)
    if ok_idx and type(idx_entities) == "table" then
      entities = {}
      for _, entity in ipairs(idx_entities) do
        if not (split_inventory and inventory_set[entity.type]) then
          entities[#entities + 1] = entity
        end
      end
      ok_ents, scan_complete = true, true
      catalog.scan_source_1478 = "indexed-cache"
      catalog.scan_queries_1478 = 0
      root.stats.indexed_area_reuse_0579 = (root.stats.indexed_area_reuse_0579 or 0) + 1
    end
  end
  if not ok_ents then
    -- A saturated root query is subdivided into deterministic quadrants.
    -- Hard call/result/depth ceilings bound the work on crowded planets.
    local scan_info
    entities, scan_info = DenseScan1478.scan(station.surface, area, {
      limit = Catalog.scan_limit,
      max_queries = Catalog.max_dense_scan_queries_1478,
      max_entities = Catalog.max_dense_scan_entities_1478,
      key_of = entity_key,
      exclude_types = excluded
    })
    ok_ents = type(entities) == "table"
    scan_complete = scan_info ~= nil and scan_info.complete == true
    catalog.scan_source_1478 = "direct"
    catalog.scan_queries_1478 = scan_info and scan_info.queries or 0
    catalog.scan_reason_1478 = scan_info and scan_info.reason or "unknown"
    catalog.scan_identity_collisions_1481 = scan_info and scan_info.identity_collisions or 0
    catalog.scan_filtered_queries_1482 = scan_info and scan_info.filtered_queries or 0
    catalog.scan_prefilter_fallbacks_1482 = scan_info and scan_info.prefilter_fallbacks or 0
    root.stats.scan_prefilter_filtered_queries_1482 =
      (root.stats.scan_prefilter_filtered_queries_1482 or 0) +
      catalog.scan_filtered_queries_1482
    root.stats.scan_prefilter_fallbacks_1482 =
      (root.stats.scan_prefilter_fallbacks_1482 or 0) +
      catalog.scan_prefilter_fallbacks_1482
    if catalog.scan_identity_collisions_1481 > 0 then
      root.stats.scan_identity_collisions_1481 =
        (root.stats.scan_identity_collisions_1481 or 0) + catalog.scan_identity_collisions_1481
    end
    root.stats.scan_queries_1478 = (root.stats.scan_queries_1478 or 0)
      + catalog.scan_queries_1478
    if catalog.scan_queries_1478 > 1 and scan_complete then
      root.stats.dense_scans_completed_1478 =
        (root.stats.dense_scans_completed_1478 or 0) + 1
    end
    local note_scan = rawget(_G, "tech_priests_efficiency_0579_note_area_scan")
    -- The filtered visual survey says nothing about complete world cells.
    -- Its retained inventory domain has a different membership authority.
    if ok_ents and not split_inventory and type(note_scan) == "function" then
      local noted, accepted = pcall(note_scan, station.surface, area, entities,
        Catalog.scan_limit, scan_complete)
      if noted and accepted ~= false then
        root.stats.indexed_area_learning_scans_0579 =
          (root.stats.indexed_area_learning_scans_0579 or 0) + 1
      end
    end
  end
  catalog.scan_entities_1478 = ok_ents and #entities or 0
  catalog.scan_incomplete_1478 = not scan_complete
  -- Retain the old flag for existing UI/clean-reuse callers.
  catalog.scan_limit_reached_1477 = catalog.scan_incomplete_1478
  if catalog.scan_incomplete_1478 then
    root.stats.scan_limit_reached_1477 =
      (root.stats.scan_limit_reached_1477 or 0) + 1
    root.stats.dense_scans_incomplete_1478 =
      (root.stats.dense_scans_incomplete_1478 or 0) + 1
  end
  if ok_ents and entities then
    for _, e in ipairs(entities) do
      -- A compatibility engine can reject DenseScan's inverse type filter.
      -- Avoid double-counting retained identities if its fallback is broad.
      if not (split_inventory and inventory_set[e.type]) then
        add_entity_to_catalog(root, pair, catalog, e, station)
      end
    end
  end
  if split_inventory then
    for _, entity in ipairs(retained) do
      add_entity_to_catalog(root, pair, catalog, entity, station)
    end
    catalog.inventory_members_1497 = #retained
    root.stats.inventory_members_reused_1497 =
      (root.stats.inventory_members_reused_1497 or 0) + #retained
  end
  -- Inventory quantities are obtained only by an item question or an
  -- explicit UI snapshot, independently of scheduled resource surveys.
  catalog.storage_items = existing and existing.storage_items or {}
  catalog.inventory_tick_1497 = existing and existing.inventory_tick_1497 or nil

  for other_unit, other in pairs(pairs_table()) do
    if other_unit ~= unit and other and other.station and other.station.valid and other.station.force == station.force and other.station.surface == station.surface then
      local d = distance_sq(other.station.position, station.position)
      if pair_rank(other) < catalog.rank and d <= (radius * 3) * (radius * 3) then
        catalog.subordinate_stations[#catalog.subordinate_stations + 1] = {
          unit = station_unit(other), name = other.station.name, backer_name = other.station.backer_name,
          rank = pair_rank(other), distance_sq = d, mode = other.mode,
          emergency = other.independent_emergency_operation_0184 ~= nil
        }
      end
    end
  end
  table.sort(catalog.subordinate_stations, function(a, b)
    if (a.rank or 0) ~= (b.rank or 0) then return (a.rank or 0) > (b.rank or 0) end
    return (a.distance_sq or 999999) < (b.distance_sq or 999999)
  end)

  for _ in pairs(catalog.storage_items) do catalog.stored_item_kinds = catalog.stored_item_kinds + 1 end

  -- Truncated scans cannot prove a previously claimed resource vanished.
  -- Preserve existing ownership until a complete scan or actual death event.
  if scan_complete then
    release_absent_owned_keys(root, pair, catalog.owned_keys)
  end
  root.stations[unit] = catalog
  pair.known_resources_0326 = catalog
  pair.known_resources_0327 = catalog
  local ticks = sweep_ticks_for(pair)
  root.next_scan[unit] = now() + ticks
  root.stats.scans = (root.stats.scans or 0) + 1
  root.stats.last_scan_tick = now()
  return catalog
end

function Catalog.scan_due(max_count)
  local root, tick = ensure_root(), now()
  local limit = math.max(0, math.floor(tonumber(max_count) or 4))
  if limit == 0 then return end
  -- Admission remains on the original cadence. The same registry owner also
  -- resumes pending work between admissions; it never starts another sweep
  -- solely because a partial slice completed.
  if root.last_admission_tick_1498 == nil
      or tick < root.last_admission_tick_1498
      or tick - root.last_admission_tick_1498 >= Catalog.scan_period then
    root.last_admission_tick_1498 = tick
    Catalog.prune_invalid()
    local due, roster = {}, {}
    for _, pair in pairs(pairs_table()) do
      if pair and valid(pair.station) then
        local unit = station_unit(pair)
        if unit then
          roster[#roster + 1] = unit
          local when = root.next_scan[unit]
          if when == nil then root.next_scan[unit] = tick + (unit % 90) + 30
          elseif tick >= when and not root.scan_jobs_1498[unit] then
            due[#due + 1] = {unit = unit, pair = pair}
          end
        end
      end
    end
    table.sort(roster)
    table.sort(due, function(a, b) return a.unit < b.unit end)
    if #due > 0 then
      local cursor, first = tonumber(root.scan_cursor_0634) or 0, 1
      for index, entry in ipairs(due) do
        if entry.unit > cursor then first = index; break end
      end
      for offset = 0, math.min(limit, #due) - 1 do
        local entry = due[((first + offset - 1) % #due) + 1]
        begin_job(root, entry.pair, roster)
        root.scan_cursor_0634 = entry.unit
      end
    end
  end
  local units = {}
  for unit in pairs(root.scan_jobs_1498) do units[#units + 1] = unit end
  table.sort(units)
  local cursor, first = tonumber(root.scan_work_cursor_1498) or 0, 1
  for index, unit in ipairs(units) do
    if unit > cursor then first = index; break end
  end
  local work_limit = math.max(1, math.floor(tonumber(Catalog.work_budget_per_pulse_1498) or 256))
  local query_limit = math.max(0, math.floor(tonumber(Catalog.query_budget_per_pulse_1498) or 1))
  local work, queries = 0, 0
  for offset = 0, #units - 1 do
    if work >= work_limit then break end
    local unit = units[((first + offset - 1) % #units) + 1]
    local job = root.scan_jobs_1498[unit]
    if job then
      local ok, used, calls = pcall(resume_job, root, job,
        work_limit - work, query_limit - queries)
      if not ok then
        -- The native buffer may already have advanced when classification
        -- fails. Never resume that partly applied batch as a complete survey.
        -- Existing cancellation retires its staged-only claims in later
        -- bounded slices; the error still reaches the registry/diagnostics.
        if root.scan_jobs_1498[unit] == job then
          job.cancelled = true
          reset_map_phase(job, "cancel-claims")
          root.next_scan[unit] = 0
        end
        root.stats.continuation_errors_1498 = (root.stats.continuation_errors_1498 or 0) + 1
        error(used, 0)
      end
      work, queries = work + used, queries + calls
      -- An unserved second job must not advance the cursor past itself when
      -- the preceding station consumed the shared budget.
      if used > 0 or calls > 0 then root.scan_work_cursor_1498 = unit end
    end
  end
  root.stats.continuation_last_work_1498 = work
  root.stats.continuation_last_queries_1498 = queries
  root.stats.continuation_max_work_1498 = math.max(root.stats.continuation_max_work_1498 or 0, work)
  root.stats.continuation_max_queries_1498 = math.max(root.stats.continuation_max_queries_1498 or 0, queries)
  if work > 0 or queries > 0 then
    root.stats.continuation_pulses_1498 = (root.stats.continuation_pulses_1498 or 0) + 1
  end
end

function Catalog.scan_some(max_count)
  local count = 0
  for _, pair in pairs(pairs_table()) do
    if pair and pair.station and pair.station.valid then
      Catalog.scan_pair(pair)
      count = count + 1
      if count >= (max_count or 8) then break end
    end
  end
end

function Catalog.get_for_pair(pair)
  if not (pair and pair.station and pair.station.valid) then return nil end
  local unit = station_unit(pair)
  local root = ensure_root()
  local cat = unit and root.stations[unit] or nil
  local radius = radius_for(pair)
  local replace_domain = false
  if cat and not CatalogReuseGuard1484.matches(pair, cat, radius) then
    -- A saved snapshot belongs to its original station domain. Its claim
    -- retirement set remains with the pair/job, but its obsolete public view
    -- cannot supply targets after relocation, force/surface or radius changes.
    cat, replace_domain = nil, true
  end
  if not cat and unit then
    -- Ordinary readers do not turn first access into a synchronous full scan.
    -- Inventory questions remain live through their separate retained API.
    cat = empty_catalog(pair, radius)
    cat.pending_snapshot_1498, cat.scan_incomplete_1478 = true, true
    cat.scan_limit_reached_1477 = true
    root.stations[unit] = cat
    local job = root.scan_jobs_1498[unit]
    if not (replace_domain and job and not job.cancelled and job.pair == pair
        and CatalogReuseGuard1484.matches(pair, job.catalog, radius)) then
      root.next_scan[unit] = 0
    end
  end
  return cat
end

function Catalog.snapshot_inventory(pair, catalog)
  if not (pair and valid(pair.station)) then return nil end
  catalog = catalog or Catalog.get_for_pair(pair)
  if not catalog then return nil end
  local station = pair.station
  local radius = radius_for(pair)
  local context = inventory_scan_context_1493(station)
  catalog.storage_items, catalog.stored_item_kinds = {}, 0
  catalog.wired_sources_skipped_1495 = 0
  for _, entity in ipairs(Catalog.inventory_candidates(pair, radius) or {}) do
    if entity ~= station and inside_inventory_area_1497(entity, station, radius) then
      collect_inventory(catalog, entity, station, context)
    end
  end
  local inventory = _G.get_station_inventory and _G.get_station_inventory(station)
    or safe_inventory(station, defines and defines.inventory and defines.inventory.chest)
  if inventory then
    local ok, contents = pcall(function() return inventory.get_contents() end)
    if ok and contents then
      for_each_inventory_item(contents, function(item, count)
        add_source(catalog.storage_items, item, { entity = station,
          inventory_id = defines and defines.inventory and defines.inventory.chest,
          count = count, kind = "station-inventory", distance_sq = 0 })
      end)
    end
  end
  for _ in pairs(catalog.storage_items) do catalog.stored_item_kinds = catalog.stored_item_kinds + 1 end
  catalog.inventory_tick_1497 = now()
  local root = ensure_root()
  root.stats.inventory_ui_snapshots_1497 = (root.stats.inventory_ui_snapshots_1497 or 0) + 1
  return catalog
end

function Catalog.find_known_source(pair, item_name)
  if not (item_name and pair and valid(pair.station)) then return nil end
  local stored = Catalog.find_inventory_source(pair, item_name)
  if stored then return stored end
  local cat = Catalog.get_for_pair(pair)
  if not cat then return nil end
  local root = ensure_root()
  local station, unit = pair.station, station_unit(pair)
  local radius, center = cat.radius, station.position
  local function live_source(record)
    if not record then return nil end
    local function eligible(source)
      local entity = source and source.entity
      if not (valid(entity) and entity.surface == station.surface) then return nil end
      -- The world survey uses native area/collision-box semantics. Inventory
      -- identities deliberately retain their separate center-based policy.
      local box, position = entity.bounding_box, entity.position
      if box then
        local left, right = box.left_top or box[1], box.right_bottom or box[2]
        if not (left and right and (left.x or left[1]) <= center.x + radius
            and (right.x or right[1]) >= center.x - radius
            and (left.y or left[2]) <= center.y + radius
            and (right.y or right[2]) >= center.y - radius) then return nil end
      elseif not (position and math.abs(position.x - center.x) <= radius
          and math.abs(position.y - center.y) <= radius) then return nil end
      local key = entity_key(entity)
      local owner = key and root.owned_resources[key]
      if owner == nil then owner = root.owned_resources[legacy_entity_key(entity)] end
      if owner ~= unit then return nil end
      return entity
    end
    local entity = eligible(record)
    if entity then return entity end
    for _, instance in ipairs(record.instances or {}) do
      entity = eligible(instance)
      if entity then return entity end
    end
  end
  local res = live_source(cat.resources and cat.resources[item_name])
  if res then
    return { kind = "known-resource-0327", entity = res, item_name = item_name, output_item = item_name, count = 1, value = 1100, station_distance_sq = distance_sq(res.position, center) }
  end
  local mined = live_source(cat.mineable_products and cat.mineable_products[item_name])
  if mined then
    return { kind = "known-mineable-product-0327", entity = mined, item_name = item_name, output_item = item_name, count = 1, value = 900, station_distance_sq = distance_sq(mined.position, center) }
  end
  return nil
end

function Catalog.note_radar_detection(pair, entity, info)
  if not (pair and pair.station and pair.station.valid and valid(entity)) then return false end
  if not should_catalog_entity(entity) then return false end
  if not (info and (info.kind == "resource" or info.kind == "mineable" or entity.type == "resource" or entity.type == "tree" or entity.type == "simple-entity")) then return false end
  local root = ensure_root()
  local cat = Catalog.get_for_pair(pair) or empty_catalog(pair, radius_for(pair))
  add_entity_to_catalog(root, pair, cat, entity, pair.station)
  root.stations[station_unit(pair)] = cat
  root.stats.radar_detections = (root.stats.radar_detections or 0) + 1
  return true
end

local function clear_gui(player)
  if player and player.valid and player.gui and player.gui.screen and player.gui.screen[Catalog.gui_name] then
    player.gui.screen[Catalog.gui_name].destroy()
  end
end

local function top_keys(tbl, limit)
  local rows = {}
  for name, rec in pairs(tbl or {}) do rows[#rows + 1] = { name = name, count = rec.count or rec.sources or 0, sources = rec.sources or 0, owner = rec.owner_unit } end
  table.sort(rows, function(a, b)
    if (a.count or 0) ~= (b.count or 0) then return (a.count or 0) > (b.count or 0) end
    return tostring(a.name) < tostring(b.name)
  end)
  local out = {}
  for i = 1, math.min(limit or Catalog.max_gui_rows, #rows) do out[#out + 1] = rows[i] end
  return out
end

local function add_section(frame, title, tbl, limit, width)
  AuspexLayout1483.add_label(frame, title, width)
  local rows = top_keys(tbl, limit)
  if #rows == 0 then
    AuspexLayout1483.add_label(frame, "  none sealed into the ledger", width)
    return
  end
  for _, row in ipairs(rows) do
    local owner = row.owner and (" | owner station#" .. tostring(row.owner)) or ""
    AuspexLayout1483.add_label(frame,
      "  " .. tostring(row.name) .. " x" .. tostring(row.count) ..
      " (sources " .. tostring(row.sources) .. ")" .. owner, width)
  end
end

function Catalog.show_gui(player, pair)
  if not (player and player.valid and pair and pair.station and pair.station.valid) then return end
  clear_gui(player)
  local cat = Catalog.get_for_pair(pair)
  if not cat then return end
  Catalog.snapshot_inventory(pair, cat)
  local root = ensure_root()
  local unit = station_unit(pair)
  local layout = AuspexLayout1483.for_player(player)
  local frame = player.gui.screen.add({ type = "frame", name = Catalog.gui_name, direction = "vertical", caption = "Cogitator Auspex Ledger" })
  frame.auto_center = false
  frame.location = layout.position
  frame.style.minimal_width = layout.frame_width
  frame.style.maximal_width = layout.frame_width
  frame.style.maximal_height = layout.frame_height
  frame.tags = { station_unit = unit }
  local header_width = math.max(1, layout.frame_width - 24)
  AuspexLayout1483.add_label(frame,
    "Station seal: " .. tostring(cat.station_backer_name or cat.station_name or cat.station_unit),
    header_width)
  AuspexLayout1483.add_label(frame,
    "Sweep radius: " .. tostring(math.floor(cat.radius or 0)) ..
    " | last rite tick: " .. tostring(cat.tick or 0) ..
    " | next auspex sweep: " .. tostring((root.next_scan[unit] or 0) - now()) .. " ticks",
    header_width)
  AuspexLayout1483.add_label(frame,
    "Spatial evidence: " .. tostring(cat.scan_entities_1478 or "?") ..
    " entities | " .. tostring(cat.scan_queries_1478 or 0) ..
    " queries | " .. tostring(cat.scan_source_1478 or "legacy") ..
    " | ambiguous IDs " .. tostring(cat.scan_identity_collisions_1481 or 0) ..
    " | prefilter retries " .. tostring(cat.scan_prefilter_fallbacks_1482 or 0),
    header_width)
  if cat.scan_limit_reached_1477 then
    AuspexLayout1483.add_label(frame,
      "Auspex INCOMPLETE (" .. tostring(cat.scan_reason_1478 or "bounded scan") ..
      "). Some resources or machines may be omitted; no absent claims released.",
      header_width)
  end
  if (tonumber(cat.wired_sources_skipped_1495) or 0) > 0 then
    AuspexLayout1483.add_label(frame,
      tostring(cat.wired_sources_skipped_1495) ..
      " wired inventory source(s) omitted. To include them, change " ..
      "'Skip wired inventory sources' in mod settings.",
      header_width)
  end
  frame.add({ type = "button", name = "tech_priests_known_resources_refresh_0326", caption = "Recast Auspex Ledger" })
  -- Keep station identity, freshness and manual refresh visible while the
  -- ledger's potentially long resource/command lists scroll independently.
  local details = frame.add({ type = "scroll-pane", name = "tech_priests_catalog_details_1477" })
  details.style.minimal_width = layout.details_width
  details.style.maximal_width = layout.details_width
  details.style.maximal_height = layout.details_height
  local details_text_width = math.max(1, layout.details_width - 24)
  add_section(details, "Active resources", cat.resources, 8, details_text_width)
  add_section(details, "Mineable products", cat.mineable_products, 8, details_text_width)
  add_section(details, "Items in storage", cat.storage_items, 10, details_text_width)
  AuspexLayout1483.add_label(details, "Subordinate command lattice", details_text_width)
  if #(cat.subordinate_stations or {}) == 0 then
    AuspexLayout1483.add_label(details,
      "  no lower-rank subordinate stations sealed into the lattice", details_text_width)
  else
    for i, sub in ipairs(cat.subordinate_stations) do
      if i > 10 then break end
      AuspexLayout1483.add_label(details,
        "  rank " .. tostring(sub.rank) ..
        " | " .. tostring(sub.backer_name or sub.name or sub.unit) ..
        " | mode " .. tostring(sub.mode or "idle") ..
        " | emergency " .. tostring(sub.emergency), details_text_width)
    end
  end
end

function Catalog.handle_gui_opened(event)
  if _G.tech_priests_0313_on_gui_opened then pcall(_G.tech_priests_0313_on_gui_opened, event) end
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  local entity = event and event.entity
  if not (player and player.valid and entity and entity.valid and _G.is_station and _G.is_station(entity)) then return end
  local pair = nil
  if _G.find_pair_for_entity then local ok, found = pcall(_G.find_pair_for_entity, entity); if ok then pair = found end end
  if pair then Catalog.show_gui(player, pair) end
end

function Catalog.handle_gui_closed(event)
  if _G.tech_priests_0313_on_gui_closed then pcall(_G.tech_priests_0313_on_gui_closed, event) end
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  clear_gui(player)
end

function Catalog.handle_gui_click(event)
  if _G.tech_priests_0313_on_gui_click then pcall(_G.tech_priests_0313_on_gui_click, event) end
  local element = event and event.element
  if not (element and element.valid and element.name == "tech_priests_known_resources_refresh_0326") then return end
  local player = event.player_index and game.get_player(event.player_index) or nil
  if not (player and player.valid) then return end
  local frame = player.gui.screen[Catalog.gui_name]
  local unit = frame and frame.valid and frame.tags and frame.tags.station_unit or nil
  local pair = unit and pairs_table()[unit] or nil
  if pair then Catalog.scan_pair(pair); Catalog.show_gui(player, pair) end
end

function Catalog.handle_destroyed_entity(entity, reason)
  if not valid(entity) then return end
  local unit = entity.unit_number
  if is_station_entity(entity) and unit then Catalog.cleanup_station(unit, reason or "station-destroyed") end
  local root = ensure_root()
  local key = entity_key(entity)
  if key and root.owned_resources[key] then release_entity_ownership(root, key) end
  local legacy_key = legacy_entity_key(entity)
  if legacy_key and legacy_key ~= key and root.owned_resources[legacy_key] then
    release_entity_ownership(root, legacy_key)
  end
end

local function run_catalog_command(event, compact)
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  if not player then return end
  local pair = nil
  if _G.selected_pair_for_player then
    local ok, found = pcall(_G.selected_pair_for_player, player)
    if ok then pair = found end
  end
  if not pair and player.selected and _G.find_pair_for_entity then
    local ok, found = pcall(_G.find_pair_for_entity, player.selected)
    if ok then pair = found end
  end
  if not pair then
    player.print("[Tech Priests 0.1.674-dev] select a Cogitator Station or Tech-Priest.")
    return
  end
  local cat = Catalog.scan_pair(pair)
  if not compact then
    local root = ensure_root()
    local mineable_kinds = 0
    if cat and cat.mineable_products then for _ in pairs(cat.mineable_products) do mineable_kinds = mineable_kinds + 1 end end
    player.print("[Tech Priests 0.1.674-dev] catalog resources=" .. tostring(cat and cat.active_resource_count or 0)
      .. " mineables=" .. tostring(mineable_kinds)
      .. " storage-items=" .. tostring(cat and cat.stored_item_kinds or 0)
      .. " owned=" .. tostring(cat and cat.owned_resource_count or 0)
      .. " next-sweep=" .. tostring((root.next_scan[station_unit(pair)] or 0) - now()) .. " ticks"
      .. " scan-complete=" .. tostring(cat and cat.scan_incomplete_1478 == false)
      .. " queries=" .. tostring(cat and cat.scan_queries_1478 or 0)
      .. " entities=" .. tostring(cat and cat.scan_entities_1478 or 0)
      .. " ambiguous-ids=" .. tostring(cat and cat.scan_identity_collisions_1481 or 0)
      .. " native-filtered=" .. tostring(cat and cat.scan_filtered_queries_1482 or 0)
      .. " prefilter-retries=" .. tostring(cat and cat.scan_prefilter_fallbacks_1482 or 0)
      .. " wired-inventories-omitted=" .. tostring(cat and cat.wired_sources_skipped_1495 or 0)
      .. " owner-index-rebuilds=" .. tostring(root.stats.owner_index_rebuilds_1496 or 0)
      .. " owner-groups-checked=" .. tostring(root.stats.owner_index_owner_checks_1496 or 0)
      .. " owner-claims-cleaned=" .. tostring(root.stats.owner_index_cleanup_keys_1496 or 0)
      .. " reason=" .. tostring(cat and cat.scan_reason_1478 or "-"))
  end
  Catalog.show_gui(player, pair)
end

function Catalog.register_commands()
  if not (commands and commands.add_command) then return end
  for _, spec in ipairs({
    { name = "tp-catalog-0327", compact = false },
    { name = "tp-catalog-0330", compact = true },
  }) do
    pcall(function() if commands.remove_command then commands.remove_command(spec.name) end end)
    pcall(function()
      commands.add_command(spec.name, "Tech Priests: inspect or refresh the selected station catalog.", function(event)
        run_catalog_command(event, spec.compact)
      end)
    end)
  end
end

function Catalog.install()
  if Catalog._installed then return true end
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  if not (registry and registry.on_nth_tick and registry.on_event and defines and defines.events) then
    return false
  end
  local destroy_events = {}
  local events = defines.events
  if events.on_entity_died then destroy_events[#destroy_events + 1] = events.on_entity_died end
  if events.on_player_mined_entity then destroy_events[#destroy_events + 1] = events.on_player_mined_entity end
  if events.on_robot_mined_entity then destroy_events[#destroy_events + 1] = events.on_robot_mined_entity end
  if events.script_raised_destroy then destroy_events[#destroy_events + 1] = events.script_raised_destroy end
  if #destroy_events == 0 then return false end
  local scan = registry.on_nth_tick(Catalog.continuation_period_1498, function()
    Catalog.scan_due(2)
  end, {
    owner = "station_catalog_0327",
    route = "station-catalog-scan",
    category = "catalog"
  })
  local destroyed = registry.on_event(destroy_events, function(event)
    local entity = event and event.entity
    if entity then Catalog.handle_destroyed_entity(entity, "destroy/mined") end
  end, nil, {
    owner = "station_catalog_0327",
    route = "station-catalog-destroyed-entity",
    category = "catalog"
  })
  if not (scan and destroyed) then return false end
  ensure_root()
  _G.tech_priests_0326_get_station_catalog = Catalog.get_for_pair
  _G.tech_priests_0326_find_known_source = Catalog.find_known_source
  _G.tech_priests_0326_scan_station_catalog = Catalog.scan_pair
  _G.tech_priests_0327_get_station_catalog = Catalog.get_for_pair
  _G.tech_priests_0327_find_known_source = Catalog.find_known_source
  _G.tech_priests_0327_scan_station_catalog = Catalog.scan_pair
  _G.tech_priests_0327_inventory_candidates = Catalog.inventory_candidates
  _G.tech_priests_0327_find_inventory_source = Catalog.find_inventory_source
  _G.tech_priests_0327_snapshot_inventory = Catalog.snapshot_inventory
  _G.tech_priests_0327_note_radar_detection = Catalog.note_radar_detection
  _G.tech_priests_0327_catalog_gui_opened = Catalog.handle_gui_opened
  _G.tech_priests_0327_catalog_gui_closed = Catalog.handle_gui_closed
  _G.tech_priests_0327_catalog_gui_click = Catalog.handle_gui_click
  _G.TechPriestsStationCatalog = Catalog
  _G.tech_priests_0578_station_catalog_cache_counts = function()
    local inv = 0
    for _ in pairs(prototype_inventory_cache_0578) do inv = inv + 1 end
    local mine = 0
    for _ in pairs(prototype_mineable_cache_0578) do mine = mine + 1 end
    return inv, mine
  end
  if _G.tech_priests_radar_remember_detection_0278 and not _G.TECH_PRIESTS_0327_PRE_RADAR_REMEMBER_DETECTION then
    _G.TECH_PRIESTS_0327_PRE_RADAR_REMEMBER_DETECTION = _G.tech_priests_radar_remember_detection_0278
    _G.tech_priests_radar_remember_detection_0278 = function(pair, entity, info)
      local result = _G.TECH_PRIESTS_0327_PRE_RADAR_REMEMBER_DETECTION(pair, entity, info)
      pcall(Catalog.note_radar_detection, pair, entity, info)
      return result
    end
  end
  Catalog.register_commands()
  Catalog._installed = true
  if log then log("[Tech-Priests 0.1.674-dev] station catalog installed with registry-owned scanning and destruction cleanup; Work State owns GUI routing") end
  return true
end

return Catalog
