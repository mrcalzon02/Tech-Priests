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
-- Keep the radar deadlines; spend a small share of a scan on each admission.
-- Explicit scan_pair/commands remain synchronous compatibility APIs.
Catalog.scan_step_period = 5
Catalog.scan_step_queries = 1
Catalog.scan_step_entities = 128
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
  root.pending_scans = root.pending_scans or {}
  root.partial_stations = root.partial_stations or {}
  root.station_revisions = root.station_revisions or {}
  return root
end

local function revise_station(root, unit)
  if unit then
    root.station_revisions[unit] = (root.station_revisions[unit] or 0) + 1
  end
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

local function claim_entity(root, pair, entity, kind, known_key, deferred)
  if not (root and pair and pair.station and pair.station.valid and valid(entity)) then return false end
  local unit = station_unit(pair)
  local key = known_key or entity_key(entity)
  if not (unit and key) then return false end
  local owner = root.owned_resources[key]
  local legacy_key
  if not owner then
    -- Compatibility for old saves: a previously claimed unitless resource
    -- should not switch owners during the identity upgrade. New claims always
    -- use the precise key, while complete scans retire old claim keys.
    legacy_key = legacy_entity_key(entity)
    owner = root.owned_resources[legacy_key]
  end
  if owner and owner ~= unit and station_owner_valid(root, owner) then return false end
  if deferred then
    legacy_key = legacy_key or legacy_entity_key(entity)
    local previous = deferred.by_key[key]
    if previous then return previous.entity == entity end
    local claim = { key = key, entity = entity, legacy_key = legacy_key }
    deferred.by_key[key] = claim
    deferred.list[#deferred.list + 1] = claim
    return true
  end
  OwnerIndex1496.assign(root, key, unit)
  local old = pair.catalog_owned_resource_keys_0327 or {}
  old[key] = true
  pair.catalog_owned_resource_keys_0327 = old
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
  local claimed = claim_entity(root, pair, entity, kind or "built")
  if claimed then revise_station(root, station_unit(pair)) end
  return claimed
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
  -- Incremental continuations recheck these settings before each admission.
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

local function add_claim_sources(pair, catalog, entity, key, kind, products)
  local fresh = not catalog.owned_keys[key]
  catalog.owned_keys[key] = true
  if catalog.incremental_scan and fresh then
    catalog.owned_resource_count = catalog.owned_resource_count + 1
  end
  local distance = distance_sq(entity.position, pair.station.position)
  if kind == "resource" then
    if catalog.incremental_scan and not catalog.resources[entity.name] then
      catalog.active_resource_count = catalog.active_resource_count + 1
    end
    add_source(catalog.resources, entity.name, {entity = entity,
      count = entity.amount or 1, kind = "resource", distance_sq = distance,
      owner_unit = station_unit(pair)})
  end
  for _, product in ipairs(products or {}) do
    add_source(catalog.mineable_products, product.name, {entity = entity,
      count = product.amount or 1,
      kind = kind == "resource" and "resource-product" or "mineable-entity",
      distance_sq = distance, owner_unit = station_unit(pair)})
  end
end

local function add_entity_to_catalog(root, pair, catalog, entity, station, scan_context)
  if not valid(entity) then return end
  if entity == station or not should_catalog_entity(entity) then return end
  local name = entity.name or entity.type
  if catalog.incremental_scan and not catalog.entities[name] then
    catalog.entity_count = catalog.entity_count + 1
  end
  add_count(catalog.entities, name, 1)
  local deferred = scan_context and scan_context.deferred_claims
  if entity.type == "resource" then
    local key = entity_key(entity)
    if claim_entity(root, pair, entity, "resource", key, deferred) then
      local products = mineable_products(entity)
      if deferred then
        deferred.by_key[key].kind, deferred.by_key[key].products = "resource", products
      else
        add_claim_sources(pair, catalog, entity, key, "resource", products)
      end
    end
  else
    local mineable, products = is_mineable_candidate(entity)
    local key = mineable and entity_key(entity) or nil
    if mineable and claim_entity(root, pair, entity, "mineable", key, deferred) then
      if deferred then
        deferred.by_key[key].kind, deferred.by_key[key].products = "mineable", products
      else
        add_claim_sources(pair, catalog, entity, key, "mineable", products)
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
  root.pending_scans[unit] = nil
  root.partial_stations[unit] = nil
  root.station_revisions[unit] = nil
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
  for unit in pairs(root.pending_scans) do
    if not station_owner_valid(root, unit) then
      Catalog.cleanup_station(unit, "invalid-pending-station")
    end
  end
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

function Catalog.scan_pair(pair)
  if not (pair and pair.station and pair.station.valid) then return nil end
  local station = pair.station
  local unit = station_unit(pair)
  if not unit then return nil end
  local root = ensure_root()
  -- An explicitly requested synchronous result supersedes older continuations.
  root.pending_scans[unit] = nil
  root.partial_stations[unit] = nil
  revise_station(root, unit)
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

  for _ in pairs(catalog.resources) do catalog.active_resource_count = catalog.active_resource_count + 1 end
  for _ in pairs(catalog.entities) do catalog.entity_count = catalog.entity_count + 1 end
  for _ in pairs(catalog.storage_items) do catalog.stored_item_kinds = catalog.stored_item_kinds + 1 end
  for _ in pairs(catalog.owned_keys) do catalog.owned_resource_count = catalog.owned_resource_count + 1 end

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

local function in_pending_area(pending, entity, station)
  if not valid(entity) or entity.surface ~= station.surface then return false end
  local position, center = entity.position, pending.catalog.station_position_1484
  local radius = pending.catalog.radius
  return position and center and math.abs(position.x - center.x) <= radius
    and math.abs(position.y - center.y) <= radius
end

local function pending_complete(pending)
  return pending.scan_info and pending.scan_info.complete == true
    and not pending.invalidated and not pending.invalid_entity
    and not pending.ownership_conflict
end

local function reset_pending_claims(pending)
  local catalog = pending.catalog
  catalog.resources, catalog.mineable_products, catalog.owned_keys = {}, {}, {}
  catalog.active_resource_count, catalog.owned_resource_count = 0, 0
end

local function pending_changed(root, pair, pending)
  local marker = pair.station_area_dirty_0634
  local revision = root.station_revisions[pending.unit] or 0
  local revision_changed = revision ~= pending.station_revision
  if marker ~= pending.dirty_marker or revision ~= pending.station_revision then
    -- Keep useful observed additions, but this traversal can no longer prove
    -- absence or clear an event which arrived after it began. Table identity
    -- also detects two invalidations occurring in the same game tick.
    pending.invalidated = true
    pending.dirty_marker, pending.station_revision = marker, revision
    if pending.phase == "release" or pending.phase == "publish"
        or (pending.phase == "validate" and revision_changed) then
      pending.phase, pending.validation_cursor = "validate", 1
      reset_pending_claims(pending)
    end
  end
end

local function begin_pending(root, pair, unit, radius)
  local catalog = empty_catalog(pair, radius)
  catalog.incremental_scan = true
  catalog.scan_source_1478 = "incremental-direct"
  catalog.scan_started_tick = now()
  -- Inventory stock has its own live-question/UI authority. Physical surveys
  -- only stage resource claims; they never call inventory get_contents.
  local context = {deferred_claims = {list = {}, by_key = {}}}
  local position = catalog.station_position_1484
  local area = {{position.x - radius, position.y - radius},
    {position.x + radius, position.y + radius}}
  local pending = {
    schema = 1, unit = unit, catalog = catalog, context = context,
    dirty_marker = pair.station_area_dirty_0634,
    station_revision = root.station_revisions[unit] or 0,
    started_tick = now(), deadline = now() + sweep_ticks_for(pair),
    phase = "scan", processed = 0,
    dense = DenseScan1478.begin(area, {
      limit = Catalog.scan_limit,
      max_queries = Catalog.max_dense_scan_queries_1478,
      max_entities = Catalog.max_dense_scan_entities_1478,
      exclude_types = Catalog.noise_prefilter_types_1482,
    }),
  }
  root.pending_scans[unit] = pending
  root.stats.incremental_started = (root.stats.incremental_started or 0) + 1
  return pending
end

local function note_scan_metadata(root, pending)
  local cat, info = pending.catalog, pending.scan_info or {}
  cat.scan_queries_1478 = info.queries or 0
  cat.scan_entities_1478 = pending.dense and #pending.dense.out or 0
  cat.scan_identity_collisions_1481 = info.identity_collisions or 0
  cat.scan_filtered_queries_1482 = info.filtered_queries or 0
  cat.scan_prefilter_fallbacks_1482 = info.prefilter_fallbacks or 0
  cat.scan_incomplete_1478 = not pending_complete(pending)
  cat.scan_limit_reached_1477 = cat.scan_incomplete_1478
  cat.scan_reason_1478 = pending.invalidated and "invalidated-during-scan"
    or pending.ownership_conflict and "ownership-changed-during-scan"
    or pending.invalid_entity and "entity-changed-during-scan"
    or info.reason or "unknown"
  cat.scan_completed_tick = now()
  cat.dirty_0634 = cat.scan_incomplete_1478 or nil
  for field, amount in pairs({
    scan_queries_1478 = cat.scan_queries_1478,
    scan_identity_collisions_1481 = cat.scan_identity_collisions_1481,
    scan_prefilter_filtered_queries_1482 = cat.scan_filtered_queries_1482,
    scan_prefilter_fallbacks_1482 = cat.scan_prefilter_fallbacks_1482,
  }) do root.stats[field] = (root.stats[field] or 0) + amount end
  if cat.scan_incomplete_1478 then
    root.stats.scan_limit_reached_1477 = (root.stats.scan_limit_reached_1477 or 0) + 1
    root.stats.dense_scans_incomplete_1478 = (root.stats.dense_scans_incomplete_1478 or 0) + 1
  elseif cat.scan_queries_1478 > 1 then
    root.stats.dense_scans_completed_1478 = (root.stats.dense_scans_completed_1478 or 0) + 1
  end
end

-- Traceable final transaction. Entity validity/ownership and legacy tag cleanup
-- are checked in bounded preceding slices. The commit itself only changes Lua
-- tables through the existing reverse-index owner; it never re-scans the world.
-- Its maximum new-key work is the existing dense result cap (3,072 by default).
function Catalog.publish_pending(pair, pending)
  local root = ensure_root()
  local unit = station_unit(pair)
  if not (pending and unit and root.pending_scans[unit] == pending
      and CatalogReuseGuard1484.matches(pair, pending.catalog, radius_for(pair))) then
    return false, "superseded-domain"
  end
  pending_changed(root, pair, pending)
  if pending.phase ~= "publish" then return false, "needs-validation" end
  for _, claim in ipairs(pending.context.deferred_claims.list) do
    if claim.accepted and (root.owned_resources[claim.key] ~= claim.expected_owner
        or (claim.legacy_key and root.owned_resources[claim.legacy_key]
          ~= claim.expected_legacy_owner)) then
      -- Another station may have published between our validation slices.
      -- Revalidate the bounded claim list, not the discovery traversal.
      pending.phase, pending.validation_cursor = "validate", 1
      reset_pending_claims(pending)
      return false, "ownership-changed"
    end
  end
  local complete = pending_complete(pending)
  local kept = complete and pending.catalog.owned_keys
    or (pair.catalog_owned_resource_keys_0327 or {})
  for _, claim in ipairs(pending.context.deferred_claims.list) do
    if claim.accepted then
      OwnerIndex1496.assign(root, claim.key, unit)
      kept[claim.key] = true
    end
  end
  if complete then
    for _, key in ipairs(pending.release_keys or {}) do
      if root.owned_resources[key] == unit then OwnerIndex1496.release(root, key) end
    end
  end
  pair.catalog_owned_resource_keys_0327 = kept
  note_scan_metadata(root, pending)
  local catalog = pending.catalog
  local previous = root.stations[unit]
  catalog.storage_items = previous and previous.storage_items or {}
  catalog.inventory_tick_1497 = previous and previous.inventory_tick_1497 or nil
  catalog.stored_item_kinds = previous and previous.stored_item_kinds or 0
  catalog.wired_sources_skipped_1495 = previous and previous.wired_sources_skipped_1495 or 0
  if complete then
    root.stations[unit], root.partial_stations[unit] = catalog, nil
    pair.known_resources_0326, pair.known_resources_0327 = catalog, catalog
    root.stats.incremental_completed = (root.stats.incremental_completed or 0) + 1
  else
    -- A cap, failed query or later event cannot establish absence. Retain the
    -- last snapshot and claims, while exposing safe additions through the
    -- existing known-source lookup. Cold stations can still use a flagged
    -- partial catalog until a complete sweep is possible.
    root.partial_stations[unit] = catalog
    if not root.stations[unit] then
      root.stations[unit] = catalog
      pair.known_resources_0326, pair.known_resources_0327 = catalog, catalog
    else
      root.stations[unit].dirty_0634 = true
    end
    root.stats.incremental_partial = (root.stats.incremental_partial or 0) + 1
  end
  root.next_scan[unit] = math.max(now() + Catalog.scan_step_period, pending.deadline)
  if pending.invalidated then
    root.next_scan[unit] = math.min(root.next_scan[unit], now() + Catalog.scan_period)
  end
  root.pending_scans[unit] = nil
  root.stats.scans = (root.stats.scans or 0) + 1
  root.stats.last_scan_tick = now()
  root.stats.last_incremental_duration_ticks = now() - pending.started_tick
  root.stats.max_incremental_duration_ticks = math.max(
    root.stats.max_incremental_duration_ticks or 0, now() - pending.started_tick)
  return true, complete and "complete" or "partial"
end

local function advance_pending(root, pair, pending, budget, used)
  local station, catalog = pair.station, pending.catalog
  local transitions = 0
  while transitions < 8 do
    transitions = transitions + 1
    local remaining = budget.entities - used.entities
    if pending.phase == "scan" then
      if remaining <= 0 then break end
      local before = #pending.dense.out
      local done, out, info, spent = DenseScan1478.step(pending.dense, station.surface,
        {queries = budget.queries - used.queries, entities = remaining}, entity_key)
      used.queries = used.queries + (spent.queries or 0)
      used.entities = used.entities + (spent.entities or 0)
      -- Each newly discovered entity is classified in the same bounded slice.
      -- Duplicate/invalid query results still consume the traversal budget.
      for index = before + 1, #(out or {}) do
        local entity = out[index]
        if in_pending_area(pending, entity, station) then
          add_entity_to_catalog(root, pair, catalog, entity, station, pending.context)
        else pending.invalid_entity = true end
        pending.processed = pending.processed + 1
      end
      pending.scan_info = info
      if not done then break end
      pending.phase = "subordinate-seed"
    elseif pending.phase == "subordinate-seed" then
      pending.subordinate_ids = {}
      for id in pairs(pairs_table()) do pending.subordinate_ids[#pending.subordinate_ids + 1] = id end
      table.sort(pending.subordinate_ids)
      pending.subordinate_cursor, pending.phase = 1, "subordinates"
    elseif pending.phase == "subordinates" then
      if remaining <= 0 then break end
      local ids = pending.subordinate_ids
      for _ = 1, remaining do
        local id = ids[pending.subordinate_cursor]
        if not id then break end
        pending.subordinate_cursor = pending.subordinate_cursor + 1
        used.entities = used.entities + 1
        local other = pairs_table()[id]
        if id ~= pending.unit and other and valid(other.station)
            and other.station.force == station.force and other.station.surface == station.surface then
          local distance = distance_sq(other.station.position, station.position)
          if pair_rank(other) < catalog.rank and distance <= (catalog.radius * 3)^2 then
            catalog.subordinate_stations[#catalog.subordinate_stations + 1] = {
              unit = station_unit(other), name = other.station.name,
              backer_name = other.station.backer_name, rank = pair_rank(other),
              distance_sq = distance, mode = other.mode,
              emergency = other.independent_emergency_operation_0184 ~= nil,
            }
          end
        end
      end
      if pending.subordinate_cursor <= #ids then break end
      table.sort(catalog.subordinate_stations, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.distance_sq < b.distance_sq
      end)
      pending.subordinate_ids = nil
      pending.validation_cursor, pending.phase = 1, "validate"
      reset_pending_claims(pending)
    elseif pending.phase == "validate" then
      if remaining <= 0 then break end
      local claims = pending.context.deferred_claims.list
      for _ = 1, remaining do
        local claim = claims[pending.validation_cursor]
        if not claim then break end
        pending.validation_cursor = pending.validation_cursor + 1
        used.entities = used.entities + 1
        claim.expected_owner = root.owned_resources[claim.key]
        claim.expected_legacy_owner = claim.legacy_key and root.owned_resources[claim.legacy_key]
        local owner = claim.expected_owner or claim.expected_legacy_owner
        local eligible = in_pending_area(pending, claim.entity, station)
        local conflict = owner and owner ~= pending.unit and station_owner_valid(root, owner)
        claim.accepted = eligible and not conflict
        if claim.accepted then
          add_claim_sources(pair, catalog, claim.entity, claim.key, claim.kind, claim.products)
          release_render_tag(root, claim.key)
        else
          if not eligible then pending.invalid_entity = true end
          if conflict then pending.ownership_conflict = true end
        end
      end
      if pending.validation_cursor <= #claims then break end
      pending.old_keys, pending.release_keys = {}, {}
      if pending_complete(pending) then
        for key in pairs(pair.catalog_owned_resource_keys_0327 or {}) do
          pending.old_keys[#pending.old_keys + 1] = key
        end
        table.sort(pending.old_keys)
      end
      pending.release_cursor, pending.phase = 1, "release"
    elseif pending.phase == "release" then
      if remaining <= 0 then break end
      for _ = 1, remaining do
        local key = pending.old_keys[pending.release_cursor]
        if not key then break end
        pending.release_cursor = pending.release_cursor + 1
        used.entities = used.entities + 1
        if not catalog.owned_keys[key] and root.owned_resources[key] == pending.unit then
          pending.release_keys[#pending.release_keys + 1] = key
          release_render_tag(root, key)
        end
      end
      if pending.release_cursor <= #pending.old_keys then break end
      pending.old_keys, pending.phase = nil, "publish"
    elseif pending.phase == "publish" then
      local published, reason = Catalog.publish_pending(pair, pending)
      used.published, used.reason = published, reason
      break
    else
      error("unknown catalog continuation phase: " .. tostring(pending.phase))
    end
  end
  used.phase = pending.phase
end

-- One measurable admission. Saved continuation state contains plain tables,
-- numeric cursors and supported LuaEntity references; no closures/coroutines.
function Catalog.step_pair(pair, budgets)
  local used = {queries = 0, entities = 0, published = false}
  if not (pair and valid(pair.station)) then return used end
  local root, unit = ensure_root(), station_unit(pair)
  if not unit then return used end
  local radius, pending = radius_for(pair), root.pending_scans[unit]
  budgets = budgets or {}
  local budget = {
    queries = math.max(0, math.floor(tonumber(budgets.queries) or Catalog.scan_step_queries)),
    entities = math.max(0, math.floor(tonumber(budgets.entities) or Catalog.scan_step_entities)),
  }
  if pending and (pending.schema ~= 1
      or not CatalogReuseGuard1484.matches(pair, pending.catalog, radius)) then
    root.pending_scans[unit], root.partial_stations[unit] = nil, nil
    root.next_scan[unit] = now() + Catalog.scan_step_period
    if root.stations[unit] then root.stations[unit].dirty_0634 = true end
    root.stats.incremental_abandoned = (root.stats.incremental_abandoned or 0) + 1
    used.reason = "domain-or-settings-changed"
    return used
  end
  if not pending then
    local existing = root.stations[unit]
    if clean_reuse_allowed_0570(pair, existing, radius) then
      root.next_scan[unit] = now() + math.min(sweep_ticks_for(pair),
        Catalog.clean_reuse_ticks_0570) + (unit % 60)
      root.stats.clean_reuse_skips_0570 = (root.stats.clean_reuse_skips_0570 or 0) + 1
      pair.known_resources_0326, pair.known_resources_0327 = existing, existing
      used.reason = "clean-reuse"
      return used
    end
    if budget.queries == 0 or budget.entities == 0 then return used end
    pending = begin_pending(root, pair, unit, radius)
  end
  pending_changed(root, pair, pending)
  local ok, err = pcall(advance_pending, root, pair, pending, budget, used)
  root.stats.incremental_steps = (root.stats.incremental_steps or 0) + 1
  root.stats.incremental_queries = (root.stats.incremental_queries or 0) + used.queries
  root.stats.incremental_inspected = (root.stats.incremental_inspected or 0) + used.entities
  root.stats.max_incremental_step_entities = math.max(
    root.stats.max_incremental_step_entities or 0, used.entities)
  root.stats.max_incremental_step_queries = math.max(
    root.stats.max_incremental_step_queries or 0, used.queries)
  if not ok then
    root.pending_scans[unit] = nil
    root.next_scan[unit] = now() + Catalog.scan_period
    root.stats.incremental_errors = (root.stats.incremental_errors or 0) + 1
    root.stats.last_incremental_error = tostring(err)
    error(err)
  end
  return used
end

function Catalog.scan_due(max_count)
  local root, tick = ensure_root(), now()
  local limit = math.max(0, math.floor(tonumber(max_count) or 2))
  if limit == 0 then return end
  if tick >= (root.roster_due or 0) then
    Catalog.prune_invalid()
    local ids, members = {}, {}
    for _, pair in pairs(pairs_table()) do
      if pair and valid(pair.station) then
        local unit = station_unit(pair)
        if unit then
          ids[#ids + 1] = unit
          members[unit] = true
          if root.next_scan[unit] == nil then
            root.next_scan[unit] = tick + (unit % 90) + 30
          end
        end
      end
    end
    table.sort(ids)
    root.scan_roster, root.scan_roster_members = ids, members
    root.roster_due = tick + Catalog.scan_period
  end
  local ids = root.scan_roster or {}
  if #ids == 0 then return end
  local cursor, first = tonumber(root.scan_cursor_0634) or 0, 1
  for index, unit in ipairs(ids) do if unit > cursor then first = index; break end end
  local left = {queries = Catalog.scan_step_queries, entities = Catalog.scan_step_entities}
  local admitted = 0
  for offset = 0, #ids - 1 do
    local unit = ids[((first + offset - 1) % #ids) + 1]
    local pair = pairs_table()[unit]
    if pair and valid(pair.station) and (root.pending_scans[unit]
        or tick >= (root.next_scan[unit] or math.huge)) then
      local used = Catalog.step_pair(pair, left)
      left.queries, left.entities = left.queries - used.queries, left.entities - used.entities
      if used.queries == 0 and used.entities == 0 and not used.reason and not used.published then
        -- No query allowance remains for this station. Leave the cursor at
        -- the previous admission so it gets the first allowance next pulse.
        break
      end
      root.scan_cursor_0634 = unit
      admitted = admitted + 1
      if admitted >= limit or left.entities <= 0 then break end
    end
  end
  return admitted
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
  if cat and not CatalogReuseGuard1484.matches(pair, cat, radius_for(pair)) then cat = nil end
  if not cat then
    local partial = unit and root.partial_stations[unit] or nil
    if partial and CatalogReuseGuard1484.matches(pair, partial, radius_for(pair)) then cat = partial end
  end
  if not cat and unit and not root.pending_scans[unit] then
    -- Reading an empty ledger must not bypass the scheduled work budget.
    root.next_scan[unit] = 0
    if not (root.scan_roster_members and root.scan_roster_members[unit]) then
      root.roster_due = 0
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
  if not item_name then return nil end
  local stored = Catalog.find_inventory_source(pair, item_name)
  if stored then return stored end
  local cat = Catalog.get_for_pair(pair)
  if not (pair and valid(pair.station)) then return nil end
  local root, unit = ensure_root(), station_unit(pair)
  local partial = unit and root.partial_stations[unit] or nil
  if partial and not CatalogReuseGuard1484.matches(pair, partial, radius_for(pair)) then partial = nil end
  local function from_catalog(known)
    if not known then return nil end
    local function live_record(record, require_owner)
      if not record then return nil end
      local function eligible(source)
        local entity = source and source.entity
        if not (valid(entity) and entity.surface == pair.station.surface) then return false end
        local center, position = pair.station.position, entity.position
        if not (position and math.abs(position.x - center.x) <= known.radius
            and math.abs(position.y - center.y) <= known.radius) then return false end
        if require_owner then
          local key = entity_key(entity)
          local owner = key and root.owned_resources[key]
          if owner == nil then owner = root.owned_resources[legacy_entity_key(entity)] end
          if owner ~= unit then return false end
        end
        return true
      end
      if eligible(record) then return record end
      for _, instance in ipairs(record.instances or {}) do
        if eligible(instance) then return instance end
      end
    end
    local resource = live_record(known.resources and known.resources[item_name], true)
    if resource then
      return {kind = "known-resource-0327", entity = resource.entity,
        item_name = item_name, output_item = item_name, count = 1, value = 1100,
        station_distance_sq = resource.distance_sq or 0}
    end
    local mined = live_record(known.mineable_products and known.mineable_products[item_name], true)
    if mined then
      return {kind = "known-mineable-product-0327", entity = mined.entity,
        item_name = item_name, output_item = item_name, count = 1, value = 900,
        station_distance_sq = mined.distance_sq or 0}
    end
  end
  return from_catalog(cat) or (partial ~= cat and from_catalog(partial) or nil)
end

function Catalog.note_radar_detection(pair, entity, info)
  if not (pair and pair.station and pair.station.valid and valid(entity)) then return false end
  if not should_catalog_entity(entity) then return false end
  if not (info and (info.kind == "resource" or info.kind == "mineable" or entity.type == "resource" or entity.type == "tree" or entity.type == "simple-entity")) then return false end
  local root = ensure_root()
  local cat = Catalog.get_for_pair(pair)
  if not cat then
    cat = empty_catalog(pair, radius_for(pair))
    cat.scan_incomplete_1478, cat.scan_limit_reached_1477, cat.dirty_0634 = true, true, true
    cat.scan_reason_1478 = "radar-observation-before-sweep"
  end
  add_entity_to_catalog(root, pair, cat, entity, pair.station)
  local unit = station_unit(pair)
  root.stations[unit] = cat
  pair.known_resources_0326, pair.known_resources_0327 = cat, cat
  revise_station(root, unit)
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
  for station_id, pending in pairs(root.pending_scans) do
    local pair = pairs_table()[station_id]
    if pair and valid(pair.station) and in_pending_area(pending, entity, pair.station) then
      -- Even an unclaimed entity can invalidate a previously checked staged
      -- reference. Do not let a later publication resurrect its claim.
      revise_station(root, station_id)
    end
  end
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
  local scan = registry.on_nth_tick(Catalog.scan_step_period, function()
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
