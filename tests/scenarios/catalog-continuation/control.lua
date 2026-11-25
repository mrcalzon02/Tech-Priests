-- Stage this control with the actual catalog/cache/registry/helper modules.
-- Create a native save, then benchmark it for 1800 ticks. Creation saves four
-- real dense surveys while a native result is only partly consumed; reload
-- must continue those saved cursors without repeating the completed query.
local Registry = require("scripts.core.runtime_event_registry")
local Economy = require("scripts.core.efficiency_economy_0587")
local Catalog = require("scripts.core.station_catalog")
local Invalidation = require("scripts.core.station_area_change_invalidator_0634")
TechPriestsRuntimeEventRegistry = Registry
tech_priests_get_pair_tier_rank = function(pair) return pair.fixture_rank end
tech_priests_radar_sweep_ticks_for_pair_0279 = function(pair)
  return ({2400, 1800, 1200, 600})[pair.fixture_rank]
end
local installed = false
local function install()
  assert(Economy.install())
  assert(Catalog.install())
  assert(Invalidation.install())
  installed = true
end
local function check(value, message) assert(value, "[CONTINUATION NATIVE] " .. message) end

script.on_init(function()
  storage.tech_priests = {pairs_by_station = {}}
  local surface = game.create_surface("catalog-continuation-native", {water = 0,
    default_enable_all_autoplace_controls = false,
    autoplace_settings = {entity = {treat_missing_as_default = false, settings = {}},
      decorative = {treat_missing_as_default = false, settings = {}}}})
  for rank = 1, 4 do surface.request_to_generate_chunks({(rank - 1) * 180, 0}, 3) end
  surface.force_generate_chunk_requests()
  local fixture = {units = {}, previous = {}, expected = {}, completions = {}, phase = 0}
  storage.catalog_continuation_native = fixture
  install()
  for rank = 1, 4 do
    local center = (rank - 1) * 180
    local station = assert(surface.create_entity{name = "steel-chest",
      position = {center, 0}, force = game.forces.player})
    local priest = assert(surface.create_entity{name = "character",
      position = {center, -2}, force = game.forces.player})
    local pair = {station = station, station_unit = station.unit_number,
      priest = priest, radius = 40, fixture_rank = rank}
    storage.tech_priests.pairs_by_station[station.unit_number] = pair
    fixture.units[#fixture.units + 1] = station.unit_number
    for y = 1, 50 do
      for x = 1, 48 do
        assert(surface.create_entity{name = "iron-ore", amount = 100,
          position = {center - 24 + x, -25 + y}})
      end
    end
    local edge = assert(surface.create_entity{name = "big-rock",
      position = {station.position.x + pair.radius + 0.5, station.position.y}})
    check(edge.position.x > station.position.x + pair.radius
      and edge.bounding_box.left_top.x < station.position.x + pair.radius,
      "native collision-box overlap fixture")
    local old = assert(Catalog.scan_pair(pair))
    check(old.resources["iron-ore"].count == 240000, "synchronous native reference coverage")
    check(old.entities["big-rock"].count == 1,
      "native area query lost a collision box whose center is outside")
    fixture.previous[station.unit_number] = old
    fixture.expected[station.unit_number] = {resources = old.resources["iron-ore"].count,
      owned = old.owned_resource_count, entities = old.scan_entities_1478,
      queries = old.scan_queries_1478, incomplete = old.scan_incomplete_1478}
    old.dirty_0634 = true
    storage.tech_priests.station_catalog_0327.next_scan[station.unit_number] = 0
  end
  -- A small initial slice guarantees a saved partially consumed query result;
  -- normal production limits are restored automatically on module reload.
  Catalog.work_budget_per_pulse_1498 = 16
  Catalog.scan_due(4)
  local root = storage.tech_priests.station_catalog_0327
  for _, unit in ipairs(fixture.units) do
    local job = root.scan_jobs_1498[unit]
    if job and job.dense and job.dense.current
        and job.dense.current.cursor > 1
        and job.dense.current.cursor <= #job.dense.current.entities then
      fixture.saved_unit = unit
      fixture.saved_query_count = job.dense.info.queries
      fixture.saved_result_cursor = job.dense.current.cursor
      fixture.saved_result_size = #job.dense.current.entities
      break
    end
  end
  check(fixture.saved_unit ~= nil, "save was not created inside a native result")
  log("[TP-CATALOG-CONTINUATION-CREATE] " .. helpers.table_to_json{passed = true,
    stations = 4, resources_per_station = 2400, saved_unit = fixture.saved_unit,
    saved_query_count = fixture.saved_query_count, saved_result_cursor = fixture.saved_result_cursor,
    saved_result_size = fixture.saved_result_size})
end)

script.on_event(defines.events.on_tick, function(event)
  local fixture = storage.catalog_continuation_native
  if not fixture or fixture.phase == 1 then return end
  if not installed then install() end
  local root = storage.tech_priests.station_catalog_0327
  if not fixture.reload_verified then
    local job = root.scan_jobs_1498[fixture.saved_unit]
    check(job and job.dense.info.queries == fixture.saved_query_count
      and job.dense.current.cursor == fixture.saved_result_cursor,
      "native save/load did not preserve the pending query/result cursor")
    fixture.reload_verified = true
    log("[TP-CATALOG-CONTINUATION-RELOAD] " .. helpers.table_to_json{
      passed = true, tick = event.tick, saved_query_count = fixture.saved_query_count,
      saved_result_cursor = fixture.saved_result_cursor})
  end
  local saved_job = root.scan_jobs_1498[fixture.saved_unit]
  if not fixture.first_resume_verified and saved_job and saved_job.dense.current
      and saved_job.dense.current.cursor > fixture.saved_result_cursor then
    check(saved_job.dense.info.queries == fixture.saved_query_count,
      "native reload repeated a query instead of consuming its saved result")
    fixture.first_resume_verified = true
  end
  check((root.stats.continuation_max_work_1498 or 0) <= Catalog.work_budget_per_pulse_1498,
    "native pulse exceeded its global row/comparison/classification budget")
  check((root.stats.continuation_max_queries_1498 or 0) <= Catalog.query_budget_per_pulse_1498,
    "native pulse exceeded its global native-query budget")
  local complete, latencies = 0, {}
  for _, unit in ipairs(fixture.units) do
    local published, job = root.stations[unit], root.scan_jobs_1498[unit]
    if published ~= fixture.previous[unit] and not fixture.completions[unit] then
      local expected = fixture.expected[unit]
      check(published.scan_finished_tick_1498 ~= nil, "partial job was published")
      check(published.resources["iron-ore"].count == expected.resources
        and published.owned_resource_count == expected.owned
        and published.scan_entities_1478 == expected.entities
        and published.scan_queries_1478 == expected.queries
        and published.scan_incomplete_1478 == expected.incomplete
        and published.entities["big-rock"].count == 1,
        "continued native survey differs from the synchronous reference")
      for key in pairs(published.owned_keys) do
        check(root.owned_resources[key] == unit, "continued native claim ownership changed")
      end
      local pair = storage.tech_priests.pairs_by_station[unit]
      local edge_source = Catalog.find_known_source(pair, "stone")
      check(edge_source and edge_source.entity.name == "big-rock"
        and edge_source.entity.position.x > pair.station.position.x + pair.radius,
        "live source validation lost the native collision-box edge")
      fixture.completions[unit] = {tick = published.scan_finished_tick_1498,
        latency_ticks = published.scan_finished_tick_1498 - published.scan_started_tick_1498,
        slices = published.scan_slices_1498, work = published.scan_work_1498,
        queries = published.scan_queries_1478, owned = published.owned_resource_count}
    elseif not fixture.completions[unit] then
      check(published == fixture.previous[unit], "reader lost the previous published snapshot")
      check(job ~= nil, "pending dense station was starved or discarded")
    end
    if fixture.completions[unit] then
      complete = complete + 1
      latencies[#latencies + 1] = fixture.completions[unit]
    end
  end
  if complete == 4 then
    check(fixture.first_resume_verified, "saved native result never resumed")
    -- Exercise the installed native event route with real LuaEntity and
    -- LuaEntityPrototype handles during runtime, after the coverage check.
    -- Factorio rejects parse-only require() calls from inside this callback.
    local pair = storage.tech_priests.pairs_by_station[fixture.units[1]]
    local station = pair.station
    local depleted = assert(script.get_event_handler(defines.events.on_resource_depleted))
    local finite = assert(station.surface.create_entity{name = "iron-ore", amount = 1,
      position = {station.position.x - 37, station.position.y - 5}})
    check(not finite.prototype.infinite_resource, "finite native resource fixture")
    check(Catalog.claim_built_entity(pair, finite, "native-depletion"), "finite native claim")
    local finite_key = Catalog.entity_key(finite)
    depleted{name = defines.events.on_resource_depleted, tick = event.tick, entity = finite}
    check(root.owned_resources[finite_key] == nil, "native finite depletion route kept ownership")
    finite.destroy()
    local infinite = assert(station.surface.create_entity{name = "crude-oil", amount = 300000,
      position = {station.position.x - 37, station.position.y + 5}})
    check(infinite.prototype.infinite_resource, "infinite native resource fixture")
    check(Catalog.claim_built_entity(pair, infinite, "native-minimum-yield"), "infinite native claim")
    local infinite_key = Catalog.entity_key(infinite)
    local marker, deadline = pair.station_area_dirty_0634, root.next_scan[pair.station_unit]
    depleted{name = defines.events.on_resource_depleted, tick = event.tick, entity = infinite}
    check(infinite.valid and root.owned_resources[infinite_key] == pair.station_unit
      and pair.station_area_dirty_0634 == marker and root.next_scan[pair.station_unit] == deadline,
      "native minimum infinite yield changed membership or ownership")
    Catalog.handle_destroyed_entity(infinite, "fixture-cleanup")
    infinite.destroy()
    fixture.phase = 1
    log("[TP-CATALOG-CONTINUATION-PASS] " .. helpers.table_to_json{passed = true,
      tick = event.tick, four_completed = true, native_reload = true,
      query_not_repeated = true, published_snapshot_preserved = true,
      native_collision_box_edge_preserved = true,
      native_live_source_edge_preserved = true, native_depletion_route_preserved = true,
      max_queries_per_pulse = root.stats.continuation_max_queries_1498,
      max_work_per_pulse = root.stats.continuation_max_work_1498, completions = latencies})
  end
end)
