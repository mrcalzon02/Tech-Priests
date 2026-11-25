-- Native multiplayer-load parity for the existing catalog continuation.
-- Stage the real Catalog/0587/Registry/helper modules with this control, create
-- a save, then benchmark it for 120 ticks. Creation records the uninterrupted
-- host's remaining map-phase trace and restores that exact saved checkpoint.
-- Loading must produce the same trace without any module-local warm state.
local Registry = require("scripts.core.runtime_event_registry")
local Economy = require("scripts.core.efficiency_economy_0587")
local Catalog = require("scripts.core.station_catalog")
TechPriestsRuntimeEventRegistry = Registry
tech_priests_get_pair_tier_rank = function() return 4 end
tech_priests_radar_sweep_ticks_for_pair_0279 = function() return 600 end
Catalog.work_budget_per_pulse_1498 = 16

local function check(value, message) assert(value, "[CATALOG MAP RELOAD] " .. message) end
local function size(map)local count=0;for _ in pairs(map)do count=count+1 end;return count end
local function key_order(map)
  local keys={};for key in pairs(map)do keys[#keys+1]=key end;return keys
end
local function same_order(map, expected)
  local index=1
  for key in pairs(map)do
    check(key==expected[index], "native table order changed at key "..index)
    index=index+1
  end
  check(index==#expected+1,"native table key count changed")
end
local function clone_saved(value, copied)
  if type(value)~="table" or value.object_name then return value end
  copied=copied or {}
  if copied[value] then return copied[value] end
  local out={};copied[value]=out
  -- Factorio next()/pairs() is insertion ordered, unlike stock Lua. Preserve
  -- that native order and every saved alias while making the checkpoint.
  for key,entry in pairs(value)do
    out[clone_saved(key,copied)]=clone_saved(entry,copied)
  end
  return out
end
local function state(root, unit)
  local job=root.scan_jobs_1498[unit]
  if job then
    return {phase=job.phase,cursor=job.map_cursor,seen=size(job.map_seen or {}),
      work=job.work,pulses=job.pulses,queries=job.queries,
      slice_work=root.stats.continuation_last_work_1498,
      slice_queries=root.stats.continuation_last_queries_1498,published=false}
  end
  local catalog=root.stations[unit]
  return {phase="published",work=catalog.scan_work_1498,
    pulses=catalog.scan_slices_1498,queries=catalog.scan_queries_1478,
    owned=catalog.owned_resource_count,sources=catalog.resources["iron-ore"].sources,
    slice_work=root.stats.continuation_last_work_1498,
    slice_queries=root.stats.continuation_last_queries_1498,published=true}
end
local function same_state(actual, expected)
  for key,value in pairs(expected)do
    check(actual[key]==value,"host/load divergence in "..key..": expected "
      ..tostring(value)..", got "..tostring(actual[key]))
  end
  for key,value in pairs(actual)do
    check(expected[key]==value,"unexpected resumed field "..key)
  end
end

script.on_init(function()
  storage.tech_priests={pairs_by_station={}}
  local surface=game.create_surface("catalog-map-reload-native", {water=0,
    default_enable_all_autoplace_controls=false,
    autoplace_settings={entity={treat_missing_as_default=false,settings={}},
      decorative={treat_missing_as_default=false,settings={}}}})
  surface.request_to_generate_chunks({0,0},2)
  surface.force_generate_chunk_requests()
  local station=assert(surface.create_entity{name="steel-chest",position={0,0},
    force=game.forces.player})
  local priest=assert(surface.create_entity{name="character",position={0,-2},
    force=game.forces.player})
  local pair={station=station,station_unit=station.unit_number,priest=priest,radius=30}
  storage.tech_priests.pairs_by_station[station.unit_number]=pair
  for y=1,20 do for x=1,20 do
    assert(surface.create_entity{name="iron-ore",amount=100,position={x-11,y-11}})
  end end
  check(Economy.install(),"retained inventory owner did not install")
  local previous=assert(Catalog.scan_pair(pair))
  check(previous.resources["iron-ore"].sources==400,"native reference coverage")
  local root=storage.tech_priests.station_catalog_0327
  root.next_scan[pair.station_unit]=0
  previous.dirty_0634=true
  local job
  for _=1,200 do
    Catalog.scan_due(1)
    job=root.scan_jobs_1498[pair.station_unit]
    if job and job.phase=="retire" and job.map_cursor
        and size(job.map_seen)>=16 then break end
  end
  check(job and job.phase=="retire" and job.map_cursor,"no native mid-map checkpoint")
  local fixture={unit=pair.station_unit,order=key_order(job.old_keys),
    cursor=job.map_cursor,seen=size(job.map_seen),queries=job.queries,
    previous=previous,step=0}
  storage.catalog_map_reload_native=fixture
  local checkpoint=clone_saved(storage)
  same_order(checkpoint.tech_priests.station_catalog_0327.scan_jobs_1498[pair.station_unit].old_keys,
    fixture.order)
  local trace={}
  for _=1,100 do
    Catalog.scan_due(1)
    trace[#trace+1]=state(root,pair.station_unit)
    if not root.scan_jobs_1498[pair.station_unit] then break end
  end
  check(trace[#trace].published,"uninterrupted native host did not complete")
  check(trace[1].seen==fixture.seen+16,"host did not advance 16 fresh map keys")
  -- Restore the pre-resume native state, including its maps, cursors, owners,
  -- and published snapshot. The warm trace itself is observation only.
  for key in pairs(storage)do storage[key]=nil end
  for key,value in pairs(checkpoint)do storage[key]=value end
  storage.catalog_map_reload_native.trace=trace
  log("[TP-CATALOG-MAP-CREATE] "..helpers.table_to_json{passed=true,
    keys=#fixture.order,saved_seen=fixture.seen,saved_cursor=fixture.cursor,
    host_first_seen=trace[1].seen,host_completion_pulses=#trace,
    saved_query_count=fixture.queries})
end)

script.on_event(defines.events.on_tick,function(event)
  local fixture=storage.catalog_map_reload_native
  if not fixture or fixture.finished then return end
  local root=storage.tech_priests.station_catalog_0327
  if fixture.step==0 then
    local job=root.scan_jobs_1498[fixture.unit]
    check(job and job.phase=="retire" and job.map_cursor==fixture.cursor,
      "native save did not preserve the map phase/cursor")
    same_order(job.old_keys,fixture.order)
    check(size(job.map_seen)==fixture.seen and job.queries==fixture.queries,
      "native save did not preserve bounded progress")
    log("[TP-CATALOG-MAP-ORDER] "..helpers.table_to_json{passed=true,
      keys=#fixture.order,cursor=job.map_cursor,seen=fixture.seen})
  end
  Catalog.scan_due(1)
  fixture.step=fixture.step+1
  local actual=state(root,fixture.unit)
  same_state(actual,assert(fixture.trace[fixture.step],"load took extra pulses"))
  check(actual.slice_work<=16 and actual.slice_queries<=1,"bounded slice limit changed")
  if actual.published then
    check(fixture.step==#fixture.trace,"publication pulse differs from warm host")
    check(actual.owned==400 and actual.sources==400,"native ownership/totals changed")
    fixture.finished=true
    log("[TP-CATALOG-MAP-PASS] "..helpers.table_to_json{passed=true,
      tick=event.tick,exact_host_trace=true,native_order_preserved=true,
      completion_pulses=fixture.step,max_work=16,max_queries=1,
      owned=actual.owned,sources=actual.sources})
  else
    check(root.stations[fixture.unit]==fixture.previous,"pending snapshot changed")
  end
end)
