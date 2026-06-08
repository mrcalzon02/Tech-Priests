-- scripts/core/station_catalog.lua
-- Tech Priests 0.1.330 station radar catalog / known-resource map.
--
-- 0.1.327 changes the catalog from a loose polling scan into a radar-sweep
-- owned snapshot system.  Stations keep a current local picture of resources,
-- mineable products, nearby entities, storage contents, and subordinate station
-- trees.  Resource/mineable entities are claimed by one station at a time so
-- overlapping stations do not double-count the same rock, tree, or ore patch.

local Catalog = {}

Catalog.version = "0.1.579"
Catalog.storage_key = "station_catalog_0327"
Catalog.legacy_storage_key = "station_catalog_0326"
Catalog.scan_period = 60
Catalog.scan_limit = 768
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
  if not valid(entity) then return nil end
  if entity.unit_number then return "u:" .. tostring(entity.unit_number) end
  local p = entity.position or { x = 0, y = 0 }
  local surface = entity.surface and entity.surface.name or "?"
  return tostring(surface) .. ":" .. tostring(entity.name or entity.type) .. ":" .. tostring(math.floor((p.x or 0) * 10)) .. ":" .. tostring(math.floor((p.y or 0) * 10))
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
  root.owned_resources[key] = nil
  release_render_tag(root, key)
end

local function claim_entity(root, pair, entity, kind)
  if not (root and pair and pair.station and pair.station.valid and valid(entity)) then return false end
  local unit = station_unit(pair)
  local key = entity_key(entity)
  if not (unit and key) then return false end
  local owner = root.owned_resources[key]
  if owner and owner ~= unit and station_owner_valid(root, owner) then return false end
  root.owned_resources[key] = unit
  local old = pair.catalog_owned_resource_keys_0327 or {}
  old[key] = true
  pair.catalog_owned_resource_keys_0327 = old
  Catalog.draw_tag(pair, entity, key, kind)
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

local function prototype_cache_key(entity)
  if not valid(entity) then return "invalid" end
  return tostring(entity.type or "?") .. ":" .. tostring(entity.name or "?")
end

local inventory_probe_ids_0578 = {
  defines.inventory.chest,
  defines.inventory.furnace_result,
  defines.inventory.assembling_machine_output,
  defines.inventory.assembling_machine_input,
  defines.inventory.car_trunk,
  defines.inventory.spider_trunk,
  defines.inventory.cargo_wagon,
  defines.inventory.rocket_silo_result,
  defines.inventory.character_corpse,
}

local function inventory_ids_for_entity_0578(entity)
  if not valid(entity) then return {} end
  local key = prototype_cache_key(entity)
  local cached = prototype_inventory_cache_0578[key]
  if cached ~= nil then return cached end
  local out = {}
  for _, inv_id in ipairs(inventory_probe_ids_0578) do
    local ok, inv = pcall(function() return entity.get_inventory(inv_id) end)
    if ok and inv and inv.valid then out[#out + 1] = inv_id end
  end
  prototype_inventory_cache_0578[key] = out
  local root = ensure_root()
  root.stats.inventory_prototype_cache_misses_0578 = (root.stats.inventory_prototype_cache_misses_0578 or 0) + 1
  return out
end

local function collect_inventory(catalog, entity, station)
  if not valid(entity) then return end
  if not should_catalog_entity(entity) then return end
  local inv_ids = inventory_ids_for_entity_0578(entity)
  if #inv_ids == 0 then return end
  for _, inv_id in ipairs(inv_ids) do
    local inv = safe_inventory(entity, inv_id)
    if inv then
      local ok, contents = pcall(function() return inv.get_contents() end)
      if ok and contents then
        for_each_inventory_item(contents, function(item, count)
          add_source(catalog.storage_items, item, { entity = entity, inventory_id = inv_id, count = count, kind = "inventory", distance_sq = distance_sq(entity.position, station.position) })
        end)
      end
    end
  end
end

local function mineable_products(entity)
  local out = {}
  if not valid(entity) then return out end
  local key = prototype_cache_key(entity)
  local cached = prototype_mineable_cache_0578[key]
  if cached ~= nil then
    for i = 1, #cached do
      local product = cached[i]
      out[#out + 1] = { name = product.name, amount = product.amount or 1 }
    end
    return out
  end
  local ok, props = pcall(function() return entity.prototype and entity.prototype.mineable_properties end)
  if ok and props and props.products then
    for _, product in pairs(props.products) do
      local name = product.name or product[1]
      if name then out[#out + 1] = { name = name, amount = product.amount or product.amount_min or 1 } end
    end
  end
  if #out == 0 and entity.type == "resource" and entity.name then out[#out + 1] = { name = entity.name, amount = 1 } end
  local stored = {}
  for i = 1, #out do stored[i] = { name = out[i].name, amount = out[i].amount or 1 } end
  prototype_mineable_cache_0578[key] = stored
  local root = ensure_root()
  root.stats.mineable_prototype_cache_misses_0578 = (root.stats.mineable_prototype_cache_misses_0578 or 0) + 1
  return out
end

local function is_mineable_candidate(entity)
  if not valid(entity) then return false end
  if entity.type == "resource" or entity.type == "tree" then return true end
  if entity.type == "simple-entity" or entity.type == "simple-entity-with-owner" then return #mineable_products(entity) > 0 end
  return false
end

local function empty_catalog(pair, radius)
  local station = pair.station
  return {
    version = Catalog.version,
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
    sweep_ticks = sweep_ticks_for(pair),
    source = "radar-sweep-snapshot-0327"
  }
end


local function clean_reuse_allowed_0570(pair, catalog, radius)
  if not (pair and pair.station and pair.station.valid and catalog) then return false end
  local age = now() - (tonumber(catalog.tick or 0) or 0)
  if age < 0 or age > Catalog.clean_reuse_ticks_0570 then return false end
  local dirty_check = rawget(_G, "tech_priests_efficiency_0570_dirty_near_pair")
  if type(dirty_check) == "function" then
    local ok, dirty = pcall(dirty_check, pair, radius or catalog.radius or 32, catalog.tick or 0)
    if ok and dirty then return false end
  end
  return true
end

local function add_entity_to_catalog(root, pair, catalog, entity, station)
  if not valid(entity) then return end
  if entity == station or not should_catalog_entity(entity) then return end
  add_count(catalog.entities, entity.name or entity.type, 1)
  collect_inventory(catalog, entity, station)
  if entity.type == "resource" then
    if claim_entity(root, pair, entity, "resource") then
      local key = entity_key(entity)
      catalog.owned_keys[key] = true
      add_source(catalog.resources, entity.name, { entity = entity, count = entity.amount or 1, kind = "resource", distance_sq = distance_sq(entity.position, station.position), owner_unit = station_unit(pair) })
      for _, product in ipairs(mineable_products(entity)) do
        add_source(catalog.mineable_products, product.name, { entity = entity, count = product.amount or 1, kind = "resource-product", distance_sq = distance_sq(entity.position, station.position), owner_unit = station_unit(pair) })
      end
    end
  elseif is_mineable_candidate(entity) then
    if claim_entity(root, pair, entity, "mineable") then
      local key = entity_key(entity)
      catalog.owned_keys[key] = true
      for _, product in ipairs(mineable_products(entity)) do
        add_source(catalog.mineable_products, product.name, { entity = entity, count = product.amount or 1, kind = "mineable-entity", distance_sq = distance_sq(entity.position, station.position), owner_unit = station_unit(pair) })
      end
    end
  end
end

local function release_absent_owned_keys(root, pair, new_keys)
  local old = pair.catalog_owned_resource_keys_0327 or {}
  for key in pairs(old) do
    if not new_keys[key] then release_entity_ownership(root, key) end
  end
  pair.catalog_owned_resource_keys_0327 = new_keys
end

function Catalog.cleanup_station(unit, reason)
  local root = ensure_root()
  if not unit then return end
  root.stations[unit] = nil
  root.next_scan[unit] = nil
  for key, owner in pairs(root.owned_resources or {}) do
    if owner == unit then release_entity_ownership(root, key) end
  end
  root.stats.station_cleanups = (root.stats.station_cleanups or 0) + 1
  root.stats.last_cleanup_reason = reason
  root.stats.last_cleanup_tick = now()
end

function Catalog.prune_invalid()
  local root = ensure_root()
  for unit in pairs(root.stations or {}) do
    if not station_owner_valid(root, unit) then Catalog.cleanup_station(unit, "invalid-station") end
  end
  for key, unit in pairs(root.owned_resources or {}) do
    if not station_owner_valid(root, unit) then release_entity_ownership(root, key) end
  end
end

function Catalog.scan_pair(pair)
  if not (pair and pair.station and pair.station.valid) then return nil end
  local station = pair.station
  local unit = station_unit(pair)
  if not unit then return nil end
  local root = ensure_root()
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

  local ok_ents, entities = false, nil
  local indexed_provider = rawget(_G, "tech_priests_efficiency_0579_entities_for_area")
  if type(indexed_provider) == "function" then
    local ok_idx, idx_entities = pcall(indexed_provider, station.surface, area)
    if ok_idx and type(idx_entities) == "table" then
      ok_ents, entities = true, idx_entities
      root.stats.indexed_area_reuse_0579 = (root.stats.indexed_area_reuse_0579 or 0) + 1
    end
  end
  if not ok_ents then
    ok_ents, entities = pcall(function()
      return station.surface.find_entities_filtered({ area = area, limit = Catalog.scan_limit })
    end)
    local note_scan = rawget(_G, "tech_priests_efficiency_0579_note_area_scan")
    if ok_ents and entities and type(note_scan) == "function" then
      pcall(note_scan, station.surface, area, entities)
      root.stats.indexed_area_learning_scans_0579 = (root.stats.indexed_area_learning_scans_0579 or 0) + 1
    end
  end
  if ok_ents and entities then
    for _, e in pairs(entities) do add_entity_to_catalog(root, pair, catalog, e, station) end
  end

  local station_inv = _G.get_station_inventory and _G.get_station_inventory(station) or safe_inventory(station, defines.inventory.chest)
  if station_inv then
    local ok, contents = pcall(function() return station_inv.get_contents() end)
    if ok and contents then
      for_each_inventory_item(contents, function(item, count)
        add_source(catalog.storage_items, item, { entity = station, inventory_id = defines.inventory.chest, count = count, kind = "station-inventory", distance_sq = 0 })
      end)
    end
  end

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

  release_absent_owned_keys(root, pair, catalog.owned_keys)
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
  local root = ensure_root()
  Catalog.prune_invalid()
  local count = 0
  local tick = now()
  for _, pair in pairs(pairs_table()) do
    if pair and pair.station and pair.station.valid then
      local unit = station_unit(pair)
      local due = unit and root.next_scan[unit] or nil
      if not due then
        root.next_scan[unit] = tick + ((unit or 1) % 90) + 30
      elseif tick >= due then
        Catalog.scan_pair(pair)
        count = count + 1
        if count >= (max_count or 4) then break end
      end
    end
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
  if not cat then cat = Catalog.scan_pair(pair) end
  return cat
end

function Catalog.find_known_source(pair, item_name)
  if not item_name then return nil end
  local cat = Catalog.get_for_pair(pair)
  if not cat then return nil end
  local stored = cat.storage_items and cat.storage_items[item_name]
  if stored and stored.entity and stored.entity.valid then
    return { kind = "known-storage-0327", source = stored.entity, inventory_id = stored.inventory_id, item_name = item_name, count = 1, station_distance_sq = stored.distance_sq or 0 }
  end
  local res = cat.resources and cat.resources[item_name]
  if res and res.entity and res.entity.valid then
    return { kind = "known-resource-0327", entity = res.entity, item_name = item_name, output_item = item_name, count = 1, value = 1100, station_distance_sq = res.distance_sq or 0 }
  end
  local mined = cat.mineable_products and cat.mineable_products[item_name]
  if mined and mined.entity and mined.entity.valid then
    return { kind = "known-mineable-product-0327", entity = mined.entity, item_name = item_name, output_item = item_name, count = 1, value = 900, station_distance_sq = mined.distance_sq or 0 }
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

local function add_section(frame, title, tbl, limit)
  frame.add({ type = "label", caption = title })
  local rows = top_keys(tbl, limit)
  if #rows == 0 then frame.add({ type = "label", caption = "  none sealed into the ledger" }); return end
  for _, row in ipairs(rows) do
    local owner = row.owner and (" | owner station#" .. tostring(row.owner)) or ""
    frame.add({ type = "label", caption = "  " .. tostring(row.name) .. " x" .. tostring(row.count) .. " (sources " .. tostring(row.sources) .. ")" .. owner })
  end
end

function Catalog.show_gui(player, pair)
  if not (player and player.valid and pair and pair.station and pair.station.valid) then return end
  clear_gui(player)
  local cat = Catalog.get_for_pair(pair)
  if not cat then return end
  local root = ensure_root()
  local unit = station_unit(pair)
  local frame = player.gui.screen.add({ type = "frame", name = Catalog.gui_name, direction = "vertical", caption = "Cogitator Auspex Ledger" })
  frame.auto_center = false
  frame.location = { x = 24, y = 96 }
  frame.style.minimal_width = 440
  frame.style.maximal_height = 720
  frame.tags = { station_unit = unit }
  frame.add({ type = "label", caption = "Station seal: " .. tostring(cat.station_backer_name or cat.station_name or cat.station_unit) })
  frame.add({ type = "label", caption = "Sweep radius: " .. tostring(math.floor(cat.radius or 0)) .. " | last rite tick: " .. tostring(cat.tick or 0) .. " | next auspex sweep: " .. tostring((root.next_scan[unit] or 0) - now()) .. " ticks" })
  frame.add({ type = "button", name = "tech_priests_known_resources_refresh_0326", caption = "Recast Auspex Ledger" })
  add_section(frame, "Active resources", cat.resources, 8)
  add_section(frame, "Mineable products", cat.mineable_products, 8)
  add_section(frame, "Items in storage", cat.storage_items, 10)
  frame.add({ type = "label", caption = "Subordinate command lattice" })
  if #(cat.subordinate_stations or {}) == 0 then
    frame.add({ type = "label", caption = "  no lower-rank subordinate stations sealed into the lattice" })
  else
    for i, sub in ipairs(cat.subordinate_stations) do
      if i > 10 then break end
      frame.add({ type = "label", caption = "  rank " .. tostring(sub.rank) .. " | " .. tostring(sub.backer_name or sub.name or sub.unit) .. " | mode " .. tostring(sub.mode or "idle") .. " | emergency " .. tostring(sub.emergency) })
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
end

function Catalog.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function()
    commands.add_command("tp-catalog-0327", "Tech Priests: inspect/refresh selected station radar-sweep catalog and tag ownership.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local pair = nil
      if _G.selected_pair_for_player then local ok, found = pcall(_G.selected_pair_for_player, player); if ok then pair = found end end
      if not pair and player.selected and _G.find_pair_for_entity then local ok, found = pcall(_G.find_pair_for_entity, player.selected); if ok then pair = found end end
      if not pair then player.print("[Tech Priests 0.1.330] select a Cogitator Station or Tech-Priest."); return end
      local cat = Catalog.scan_pair(pair)
      local root = ensure_root()
      local mineable_kinds = 0
      if cat and cat.mineable_products then for _ in pairs(cat.mineable_products) do mineable_kinds = mineable_kinds + 1 end end
      local owned = cat and cat.owned_resource_count or 0
      local next_due = ((root.next_scan[station_unit(pair)] or 0) - now())
      player.print("[Tech Priests 0.1.330] catalog: resources=" .. tostring(cat and cat.active_resource_count or 0) .. " mineables=" .. tostring(mineable_kinds) .. " storage-items=" .. tostring(cat and cat.stored_item_kinds or 0) .. " owned-tags=" .. tostring(owned) .. " subordinates=" .. tostring(cat and #(cat.subordinate_stations or {}) or 0) .. " next-sweep=" .. tostring(next_due) .. " ticks")
      Catalog.show_gui(player, pair)
    end)
  end)
end

  pcall(function()
    commands.add_command("tp-catalog-0330", "Tech Priests: inspect/refresh selected station radar-sweep catalog and tag ownership.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local pair = nil
      if _G.selected_pair_for_player then local ok, found = pcall(_G.selected_pair_for_player, player); if ok then pair = found end end
      if not pair and player.selected and _G.find_pair_for_entity then local ok, found = pcall(_G.find_pair_for_entity, player.selected); if ok then pair = found end end
      if not pair then player.print("[Tech Priests 0.1.330] select a Cogitator Station or Tech-Priest."); return end
      local cat = Catalog.scan_pair(pair)
      Catalog.show_gui(player, pair)
      player.print("[Tech Priests 0.1.330] catalog refreshed. owned-tags=" .. tostring(cat and cat.owned_resource_count or 0) .. " note: world tags now render only in Alt mode via /tp-network-visuals-0330.")
    end)
  end)

function Catalog.install()
  if Catalog._installed then return true end
  Catalog._installed = true
  ensure_root()
  _G.tech_priests_0326_get_station_catalog = Catalog.get_for_pair
  _G.tech_priests_0326_find_known_source = Catalog.find_known_source
  _G.tech_priests_0326_scan_station_catalog = Catalog.scan_pair
  _G.tech_priests_0327_get_station_catalog = Catalog.get_for_pair
  _G.tech_priests_0327_find_known_source = Catalog.find_known_source
  _G.tech_priests_0327_scan_station_catalog = Catalog.scan_pair
  _G.tech_priests_0327_note_radar_detection = Catalog.note_radar_detection
  _G.tech_priests_0327_catalog_gui_opened = Catalog.handle_gui_opened
  _G.tech_priests_0327_catalog_gui_closed = Catalog.handle_gui_closed
  _G.tech_priests_0327_catalog_gui_click = Catalog.handle_gui_click
  _G.TechPriestsStationCatalog = Catalog
  _G.tech_priests_0578_station_catalog_cache_counts = function() local inv=0; for _ in pairs(prototype_inventory_cache_0578) do inv=inv+1 end; local mine=0; for _ in pairs(prototype_mineable_cache_0578) do mine=mine+1 end; return inv, mine end

  if _G.tech_priests_radar_remember_detection_0278 and not _G.TECH_PRIESTS_0327_PRE_RADAR_REMEMBER_DETECTION then
    _G.TECH_PRIESTS_0327_PRE_RADAR_REMEMBER_DETECTION = _G.tech_priests_radar_remember_detection_0278
    _G.tech_priests_radar_remember_detection_0278 = function(pair, entity, info)
      local result = _G.TECH_PRIESTS_0327_PRE_RADAR_REMEMBER_DETECTION(pair, entity, info)
      pcall(Catalog.note_radar_detection, pair, entity, info)
      return result
    end
  end

  if script and script.on_nth_tick then script.on_nth_tick(Catalog.scan_period, function() Catalog.scan_due(2) end) end
  if script and defines and defines.events then
    script.on_event(defines.events.on_gui_opened, Catalog.handle_gui_opened)
    script.on_event(defines.events.on_gui_closed, Catalog.handle_gui_closed)
    script.on_event(defines.events.on_gui_click, Catalog.handle_gui_click)
    local destroy_events = {}
    if defines.events.on_entity_died then destroy_events[#destroy_events + 1] = defines.events.on_entity_died end
    if defines.events.on_player_mined_entity then destroy_events[#destroy_events + 1] = defines.events.on_player_mined_entity end
    if defines.events.on_robot_mined_entity then destroy_events[#destroy_events + 1] = defines.events.on_robot_mined_entity end
    if defines.events.script_raised_destroy then destroy_events[#destroy_events + 1] = defines.events.script_raised_destroy end
    if #destroy_events > 0 then
      script.on_event(destroy_events, function(event)
        local entity = event and event.entity
        if entity then Catalog.handle_destroyed_entity(entity, "destroy/mined") end
      end)
    end
  end
  Catalog.register_commands()
  if log then log("[Tech-Priests 0.1.330] station radar-sweep catalog snapshots + 0.1.578 prototype cache economy installed") end
  return true
end

return Catalog
