-- The installed 0587 source cache must serve current 0686 storage callers.
-- Initial spatial population is retained; events maintain membership and
-- quantities/permissions remain live across any number of radar/TTL periods.
package.path = "tech-priests_src/?.lua;tech-priests_src/?/init.lua;" .. package.path
local baseline = os.getenv("TP_EXPECT_UNCACHED_STORAGE") == "1"
local module_file = os.getenv("TP_STORAGE_AUTHORITY_FILE")
game = { tick = 12000 }
storage = { tech_priests = { pairs_by_station = {} } }
defines = { inventory = { chest = 1, car_trunk = 2, spider_trunk = 3 }, events = {} }
local event_names = { "on_built_entity", "on_robot_built_entity",
  "script_raised_built", "script_raised_revive", "on_entity_cloned",
  "on_player_mined_entity", "on_robot_mined_entity", "on_entity_died",
  "script_raised_destroy", "script_raised_teleported",
  "on_surface_cleared", "on_surface_deleted", "on_player_driving_changed_state",
  "on_player_changed_position", "on_player_changed_surface", "on_spider_command_completed",
  "on_train_changed_state", "on_train_created", "on_post_entity_died",
  "on_character_corpse_expired" }
for id, name in ipairs(event_names) do defines.events[name] = id end
local handlers = {}
_G.TechPriestsRuntimeEventRegistry = { on_event = function(id, handler, _, opts)
  assert(opts.priority < -100000, "storage invalidation must precede consumers")
  handlers[id] = handler
  return { id = id }
end }
package.loaded["scripts.core.runtime_event_registry"] = _G.TechPriestsRuntimeEventRegistry
_G.TechPriestsRuntimeTickBroker0600 = { register_service = function(spec) return spec end }
package.loaded["scripts.core.machine_logistics_final_authority_0684"] = {}

local force = { index = 1, name = "player" }
local other_force = { index = 2, name = "enemy" }
local surface = { index = 1, valid = true }
local other_surface = { index = 2, valid = true }
local entities, scans, fail_next_scan = {}, 0, false
local function inventory(items)
  local inv = { valid = true, items = items or {} }
  function inv.get_item_count(item)
    local name = type(item) == "table" and item.name or item
    local quality = type(item) == "table" and item.quality or nil
    return inv.items[name .. (quality and ":" .. quality or "")] or 0
  end
  function inv.remove(stack)
    local key = stack.name .. (stack.quality and ":" .. stack.quality or "")
    local n = math.min(stack.count, inv.items[key] or 0)
    inv.items[key] = (inv.items[key] or 0) - n
    return n
  end
  return inv
end
local function chest(id, x, items)
  local entity = { valid = true, name = "steel-chest", type = "container",
    unit_number = id, position = { x = x, y = 0 }, force = force, surface = surface,
    inv = inventory(items) }
  function entity.get_inventory(id) return id == defines.inventory.chest and entity.inv or nil end
  return entity
end
local function scan(query)
  scans = scans + 1
  if fail_next_scan then fail_next_scan = false; error("disposable native scan failure") end
  local found = {}
  for _, entity in ipairs(entities) do
    local p, area = entity.position, query.area
    if entity.valid and entity.surface == surface
        and (not query.force or entity.force == query.force)
        and p.x >= area[1][1] and p.x <= area[2][1]
        and p.y >= area[1][2] and p.y <= area[2][2] then
      found[#found + 1] = entity
      if #found == query.limit then break end
    end
  end
  return found
end
surface.find_entities_filtered = scan
other_surface.find_entities_filtered = function() scans = scans + 1; return {} end
local priests = {}
for n = 1, 4 do
  local station = chest(n, (n - 1) * 240, {})
  local pair = { station = station, station_unit = n, radius = 32,
    priest = { valid = true, position = { x = station.position.x, y = 1 } } }
  priests[n] = pair
  storage.tech_priests.pairs_by_station[n] = pair
  entities[#entities + 1] = chest(100 + n, station.position.x + 8,
    { coal = 7, ["iron-plate"] = 10, ["copper-plate"] = 3,
      ["electronic-circuit:rare"] = 2 })
end
local Authority = module_file and assert(loadfile(module_file))()
  or require("scripts.core.storage_role_authority_0686")
assert(Authority.install(), "storage authority did not install")
local Economy = require("scripts.core.efficiency_economy_0587")
assert(Economy.install(), "existing source cache did not install")
local function changed(name, entity)
  local handler = handlers[defines.events[name]]
  if handler then handler({ entity = entity, destination = entity }) end
end
local function check(actual, expected, reason)
  assert(actual == expected, reason .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

-- A machine-discovery pass can consider 96 candidates, five fuel choices
-- and several recipe ingredients per priest. Count native spatial calls,
-- not wall time or simulated UPS.
local queries = 0
local items = { "coal", "wood", "solid-fuel", "rocket-fuel", "nuclear-fuel",
  "iron-plate", "copper-plate", "electronic-circuit" }
for _, pair in ipairs(priests) do
  for _ = 1, 96 do
    for _, item in ipairs(items) do
      Authority.generic_item_count(pair, item)
      queries = queries + 1
    end
  end
end
check(queries, 3072, "demand fixture size")
check(scans, baseline and 3072 or 4, "repeated spatial scans for four priests")
print("[storage-discovery-cache-0587] spatial_queries=" .. scans
  .. " item_queries=" .. queries .. " priests=4 mode=" .. (baseline and "before" or "after"))

local pair, source = priests[1], entities[1]
source.inv.items.coal = 11
check(Authority.generic_item_count(pair, "coal"), 11, "same-tick deposit was stale")
check(Authority.remove_generic_item(pair, "coal", 4), 4, "physical removal failed")
check(Authority.generic_item_count(pair, "coal"), 7, "same-tick withdrawal was stale")
check(Authority.generic_item_count(pair, "electronic-circuit", "rare"), 2,
  "quality-specific stock was lost")
Authority.remember_role(pair, source, "waste", "test-role")
check(Authority.generic_item_count(pair, "coal"), 0, "same-tick role change was stale")
check(Authority.remember_role(pair, source, "general", "test-role"), false,
  "specialized storage role unexpectedly became general")
Authority.root().roles["unit:" .. source.unit_number] = nil
check(Authority.generic_item_count(pair, "coal"), 7, "same-tick role restoration was stale")

source.inv = inventory({ coal = 13 })
check(Authority.generic_item_count(pair, "coal"), 13, "inventory handle was cached")
source.position.x = 80
check(Authority.generic_item_count(pair, "coal"), 0, "moved chest remained in range")
pair.radius = 96
check(Authority.generic_item_count(pair, "coal"), 13, "radius growth did not rediscover")
source.force = other_force
check(Authority.generic_item_count(pair, "coal"), 0, "foreign chest stayed spendable")
source.force = force
check(Authority.generic_item_count(pair, "coal"), 13, "force change was not visible")
source.surface = other_surface
check(Authority.generic_item_count(pair, "coal"), 0, "other-surface chest stayed spendable")
source.surface = surface
changed("script_raised_teleported", source)
check(Authority.generic_item_count(pair, "coal"), 13, "teleport was not visible")

local added = chest(500, 4, { coal = 5 })
local topology_scans = scans
entities[#entities + 1] = added
changed("script_raised_built", added)
check(Authority.generic_item_count(pair, "coal"), 18, "same-tick new chest was hidden")
local cloned = chest(501, 6, { coal = 2 })
entities[#entities + 1] = cloned
changed("on_entity_cloned", cloned)
check(Authority.generic_item_count(pair, "coal"), 20, "same-tick clone was hidden")
added.valid = false
check(Authority.generic_item_count(pair, "coal"), 15, "invalid chest was still counted")
cloned.valid = false
changed("script_raised_destroy", cloned)
check(Authority.generic_item_count(pair, "coal"), 13, "destroyed chest was still counted")
check(scans, topology_scans + (baseline and 4 or 0),
  "topology events or invalid entities caused rediscovery")

-- Movement of the station changes the query center in the same tick.
pair.station.position.x = 500
check(Authority.generic_item_count(pair, "coal"), 7, "moved station reused old candidates")
pair.station.surface = other_surface
check(Authority.generic_item_count(pair, "coal"), 0, "station surface changed unnoticed")
pair.station.surface, pair.station.position.x = surface, 0
pair.radius = 32
source.position.x = 8
changed("script_raised_teleported", source)
check(Authority.generic_item_count(pair, "coal"), 13, "reset station candidates wrong")
local before_tick, discovery_tick = scans, game.tick
local seen_cache = false
for _, record in pairs(Economy.root().source_cache) do
  if record.retained_candidates == 1 then seen_cache = true end
end
check(seen_cache, not baseline, "current storage bypassed existing source_cache")
game.tick = discovery_tick + 1
check(Authority.generic_item_count(pair, "coal"), 13, "next tick changed live inventory")
check(scans, before_tick + (baseline and 1 or 0), "next tick repeated spatial discovery")
game.tick = discovery_tick + 1799
check(Authority.generic_item_count(pair, "coal"), 13, "live stock before refresh")
check(scans, before_tick + (baseline and 2 or 0), "discovery repeated without a domain change")
local before_expiry = scans
game.tick = discovery_tick + 1800
check(Authority.generic_item_count(pair, "coal"), 13, "refresh changed stock")
check(scans, before_expiry + (baseline and 1 or 0), "30-second boundary rediscovered membership")

local before_periods = scans
for period = 2, 20 do
  game.tick = discovery_tick + 1800 * period
  Economy.cleanup()
  check(Authority.generic_item_count(pair, "coal"), 13, "retained stock changed at a time boundary")
end
check(scans, before_periods + (baseline and 19 or 0),
  "cleanup or elapsed time forced spatial rediscovery")

-- Reload reconstructs module functions/event routes, not physical membership.
local before_reload = scans
Economy = assert(loadfile("tech-priests_src/scripts/core/efficiency_economy_0587.lua"))()
assert(Economy.install(), "source-cache reinstall failed")
check(Authority.generic_item_count(pair, "coal"), 13, "reload lost live stock")
check(scans, before_reload + (baseline and 1 or 0), "reload rediscovered retained membership")

-- Unrelated builds/deaths must not turn retained membership into a search
-- on every combat/build event elsewhere on the map.
local before_unrelated = scans
changed("on_built_entity", { valid = true, type = "transport-belt",
  position = {x = 5, y = 0}, force = force, surface = surface })
check(Authority.generic_item_count(pair, "coal"), 13, "belt build changed stock")
changed("on_built_entity", chest(5500, 5000, {coal = 9}))
check(Authority.generic_item_count(pair, "coal"), 13, "remote chest changed stock")
local enemy_chest = chest(5501, 5, {coal = 9})
enemy_chest.force = other_force
changed("on_entity_died", enemy_chest)
check(Authority.generic_item_count(pair, "coal"), 13, "foreign death changed stock")
check(scans, before_unrelated + (baseline and 3 or 0), "unrelated event discarded source membership")

-- If the first 256 results lose one entity, the 257th must become visible.
entities = {}
for n = 1, 257 do entities[n] = chest(1000 + n, 4, { coal = 1 }) end
Economy.invalidate_all("new-world-fixture")
check(Authority.generic_item_count(pair, "coal"), 256, "scan cap changed")
if not baseline then
  local complete = false
  for _, record in pairs(Economy.root().source_cache) do
    if record.domain == "generic-storage-0686" and record.station == pair.station then
      complete = record.complete == true and #record.list == 257
    end
  end
  assert(complete, "256-entry view was mistaken for complete initial membership")
end
local before_promotion = scans
entities[1].valid = false
check(Authority.generic_item_count(pair, "coal"), 256, "capped list did not refill after removal")
check(scans, before_promotion + (baseline and 1 or 0), "overflow promotion rescanned the world")

-- A force change has no dedicated Factorio event. Retaining nearby physical
-- membership independently of force policy makes newly friendly stock live.
local foreign = chest(9000, 4, {coal=5})
foreign.force = other_force
entities = {foreign}
Economy.invalidate_all("force-policy-fixture")
check(Authority.generic_item_count(pair, "coal"), 0, "foreign stock became spendable")
local before_force = scans
foreign.force = force
check(Authority.generic_item_count(pair, "coal"), 5, "new friendly stock required a nonexistent force event")
check(scans, before_force + (baseline and 1 or 0), "live force change caused rediscovery")

-- Surface clearing empties retained membership. A later ordinary build
-- repopulates that empty list directly rather than triggering an area search.
foreign.valid = false
handlers[defines.events.on_surface_cleared]({surface_index=surface.index})
local before_clear = scans
check(Authority.generic_item_count(pair, "coal"), 0, "surface clear retained destroyed stock")
local arrived = chest(9001, 5, {coal=9})
entities[#entities+1] = arrived
changed("on_built_entity", arrived)
check(Authority.generic_item_count(pair, "coal"), 9, "new arrival did not update an empty retained list")
check(scans, before_clear + (baseline and 2 or 0), "surface clear/build caused rediscovery")

if not baseline then
  -- Empty membership persists through time boundaries. A driver's actual
  -- movement event admits a newly arriving car without rediscovering the area.
  for _, entity in ipairs(entities) do
    changed("script_raised_destroy", entity)
    entity.valid = false
  end
  entities = {}
  Economy.invalidate_all("new-independent-empty-area-fixture")
  local empty_tick = game.tick
  check(Authority.generic_item_count(pair, "coal"), 0, "empty source discovery")
  local empty_scans = scans
  local vehicle = chest(6000, 96, { coal = 17 })
  vehicle.type = "car"
  vehicle.get_inventory = function(id)
    return id == defines.inventory.car_trunk and vehicle.inv or nil
  end
  entities[1] = vehicle
  vehicle.position.x = 4
  game.tick = empty_tick + 1799
  for _ = 1, 100 do
    check(Authority.generic_item_count(pair, "coal"), 0, "empty membership before movement event")
  end
  check(scans, empty_scans, "empty membership repeatedly searched")
  game.tick = empty_tick + 1800
  check(Authority.generic_item_count(pair, "coal"), 0, "elapsed time replaced empty membership")
  check(scans, empty_scans, "time boundary rediscovered an empty area")
  game.get_player = function() return {valid=true,vehicle=vehicle} end
  handlers[defines.events.on_player_changed_position]({player_index=1})
  check(Authority.generic_item_count(pair, "coal"), 17, "movement event did not admit arriving vehicle")
  check(scans, empty_scans, "movement event rediscovered the area")
  vehicle.inv.items.coal = 21
  check(Authority.generic_item_count(pair, "coal"), 21, "vehicle stock was cached")
  -- Known moving sources remain members even while ineligible. Returning
  -- inside the same station domain becomes visible without rediscovery.
  vehicle.position.x = 96
  check(Authority.generic_item_count(pair, "coal"), 0, "out-of-range vehicle remained spendable")
  vehicle.position.x = 4
  local before_return = scans
  check(Authority.generic_item_count(pair, "coal"), 21, "returning known vehicle stayed excluded")
  check(scans, before_return, "known vehicle return rediscovered the world")
  game.tick = empty_tick + 3600
  check(Authority.generic_item_count(pair, "coal"), 21, "returning vehicle lost stock at time boundary")
  check(scans, before_return, "next 1800-tick boundary rediscovered membership")
  Economy.invalidate_all("failed-discovery-fixture")
  fail_next_scan = true
  check(Authority.generic_item_count(pair, "coal"), 0, "failed discovery invented inventory")
  check(Authority.generic_item_count(pair, "coal"), 21, "failed discovery poisoned a complete negative cache")
end

-- Missing world-change routing must retain fresh discovery, including a
-- creation between two reads of the same tick.
_G.TechPriestsRuntimeEventRegistry = nil
package.loaded["scripts.core.runtime_event_registry"] = nil
defines.events = {}
local no_events = assert(loadfile("tech-priests_src/scripts/core/efficiency_economy_0587.lua"))()
assert(no_events.install(), "cache fallback installation failed")
local uncached = assert(loadfile(module_file
  or "tech-priests_src/scripts/core/storage_role_authority_0686.lua"))()
assert(uncached.install(), "uncached compatibility installation failed")
entities = { chest(5000, 4, { coal = 1 }) }
local before_fallback = scans
check(uncached.generic_item_count(pair, "coal"), 1, "uncached first read")
entities[#entities + 1] = chest(5001, 6, { coal = 2 })
check(uncached.generic_item_count(pair, "coal"), 3, "missing events hid a new chest")
check(scans, before_fallback + 2, "missing events incorrectly enabled reuse")
print("[storage-discovery-cache-0587] PASS live-counts qualities roles domain movement events complete-cap-overflow retained-periods reload live-force surface-clear empty-area moving-vehicle failure-retry canonical-cache fallback")
