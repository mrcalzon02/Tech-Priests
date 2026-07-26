-- Tech Priests 0.1.534 - Stone-cache item filter steward.
-- Factorio's ordinary container prototype does not provide a per-entity item-only
-- inventory filter.  This steward enforces the named cache promise at runtime by
-- sweeping filtered cache inventories and physically rerouting wrong items through
-- the canonical storage authority.  It does not create logistics work, complete orders, or move priests.

local M = {}

M.tick_interval = 89
M.sweep_budget = 128

M.allowed_by_entity = {
  ["tech-priests-stone-cache-coal"] = "coal",
  ["tech-priests-stone-cache-stone"] = "stone",
  ["tech-priests-stone-cache-wood"] = "wood",
  ["tech-priests-stone-cache-iron-ore"] = "iron-ore",
  ["tech-priests-stone-cache-copper-ore"] = "copper-ore",
  ["tech-priests-stone-cache-iron-plate"] = "iron-plate",
  ["tech-priests-stone-cache-copper-plate"] = "copper-plate",
  ["tech-priests-stone-cache-copper-cable"] = "copper-cable",
  ["tech-priests-stone-cache-iron-gear-wheel"] = "iron-gear-wheel",
  ["tech-priests-stone-cache-iron-stick"] = "iron-stick"
}

local function valid(entity)
  return entity and entity.valid
end

local function safe(value)
  if value == nil then return "nil" end
  return tostring(value)
end

local function count_table(t)
  local n = 0
  for _ in pairs(t or {}) do n = n + 1 end
  return n
end

local function root()
  storage.tech_priests_stone_cache_filter_0534 = storage.tech_priests_stone_cache_filter_0534 or {
    caches = {},
    stats = { swept = 0, rerouted = 0, registered = 0 }, custody = {}
  }
  local r = storage.tech_priests_stone_cache_filter_0534
  r.caches = r.caches or {}
  r.stats = r.stats or { swept = 0, rerouted = 0, registered = 0 }
  r.custody = r.custody or {}
  return r
end

function M.register_entity(entity)
  if not valid(entity) then return false end
  local allowed = M.allowed_by_entity[entity.name]
  if not allowed then return false end
  local r = root()
  r.caches[entity.unit_number or (entity.name .. ":" .. safe(entity.position.x) .. ":" .. safe(entity.position.y))] = entity
  r.stats.registered = (r.stats.registered or 0) + 1
  return true
end

function M.scan_surface(surface)
  if not surface or not surface.valid or not surface.find_entities_filtered then return 0 end
  local names = {}
  for name in pairs(M.allowed_by_entity) do names[#names + 1] = name end
  local found = surface.find_entities_filtered({ name = names }) or {}
  local count = 0
  for _, entity in pairs(found) do
    if M.register_entity(entity) then count = count + 1 end
  end
  return count
end

function M.scan_all_surfaces()
  local count = 0
  if game and game.surfaces then
    for _, surface in pairs(game.surfaces) do
      count = count + M.scan_surface(surface)
    end
  end
  return count
end

local function pair_for_entity(entity)
  if not valid(entity) then return nil end
  local best, distance
  local pairs_by_station = storage and storage.tech_priests
    and storage.tech_priests.pairs_by_station or {}
  for _, pair in pairs(pairs_by_station) do
    if pair and valid(pair.station) and valid(pair.priest)
      and pair.station.surface == entity.surface and pair.station.force == entity.force
    then
      local dx = pair.station.position.x - entity.position.x
      local dy = pair.station.position.y - entity.position.y
      local candidate = dx * dx + dy * dy
      if not distance or candidate < distance then best, distance = pair, candidate end
    end
  end
  return best
end
local function storage_authority()
  return rawget(_G, "TechPriestsStorageRoleAuthority0686")
    or package.loaded["scripts.core.storage_role_authority_0686"]
end
local function inventory_insert(inv, item, count)
  local ok, inserted = pcall(function() return inv.insert({ name = item, count = count }) end)
  return ok and (tonumber(inserted) or 0) or 0
end
local function inventory_remove(inv, item, count)
  local ok, removed = pcall(function() return inv.remove({ name = item, count = count }) end)
  return ok and (tonumber(removed) or 0) or 0
end
local function custody_key(entity, item)
  return tostring(entity.unit_number or entity.name) .. ":" .. tostring(item)
end
local function reroute_wrong_stack(entity, inv, stack)
  local authority = storage_authority()
  local pair = pair_for_entity(entity)
  if not (authority and type(authority.deposit_exact) == "function" and pair) then return false end
  local item, count = stack.name, stack.count
  local removed = inventory_remove(inv, item, count)
  if removed <= 0 then return false end
  local key = custody_key(entity, item)
  local r = root()
  r.custody[key] = { entity = entity, source_inventory = inv, item = item, count = removed, tick = game and game.tick or 0 }
  local ok, accepted, why, inserted = pcall(authority.deposit_exact, pair, item, removed,
    "filtered-cache-recovery", { exclude_entity = entity, role = "general" })
  inserted = tonumber(inserted) or (accepted == true and removed or 0)
  if ok and accepted == true and inserted == removed then
    r.custody[key] = nil
    r.stats.rerouted = (r.stats.rerouted or 0) + removed
    return true
  end
  local restored = inventory_insert(inv, item, removed)
  r.custody[key].count = removed - restored
  r.custody[key].last_blocker = safe(why)
  if r.custody[key].count <= 0 then r.custody[key] = nil end
  r.stats.blocked = (r.stats.blocked or 0) + 1
  return false
end

function M.sweep_entity(entity)
  if not valid(entity) then return false end
  local allowed = M.allowed_by_entity[entity.name]
  if not allowed then return false end
  local inv = entity.get_inventory and entity.get_inventory(defines.inventory.chest)
  if not (inv and inv.valid) then return false end
  local r = root()
  local changed = false
  for i = 1, #inv do
    local stack = inv[i]
    if stack and stack.valid_for_read and stack.name ~= allowed then
      changed = reroute_wrong_stack(entity, inv, stack) or changed
    end
  end
  r.stats.swept = (r.stats.swept or 0) + 1
  return changed
end

function M.sweep_all(budget)
  local r = root()
  local stale = {}
  local processed = 0
  local max_count = tonumber(budget) or nil
  local after = r.sweep_cursor
  local active = after == nil
  for key, entity in pairs(r.caches or {}) do
    if active then
      if valid(entity) then
        M.sweep_entity(entity)
        processed = processed + 1
        if max_count and processed >= max_count then
          r.sweep_cursor = key
          r.stats.sweep_budget_exhausted = (r.stats.sweep_budget_exhausted or 0) + 1
          for _, stale_key in pairs(stale) do r.caches[stale_key] = nil end
          return processed
        end
      else
        stale[#stale + 1] = key
      end
    elseif key == after then
      active = true
    end
  end
  if after and not active then
    r.sweep_cursor = nil
  elseif not max_count or processed < max_count then
    r.sweep_cursor = nil
  end
  for _, key in pairs(stale) do r.caches[key] = nil end
  return processed
end

function M.service()
  return M.sweep_all(M.sweep_budget)
end

function M.full_rescan(reason)
  local r = root()
  local rescanned = M.scan_all_surfaces()
  r.stats.full_rescans = (r.stats.full_rescans or 0) + 1
  r.stats.last_full_rescan_reason = reason or "manual"
  return rescanned
end

function M.report_lines()
  local r = root()
  return {
    "[tp-runtime-report] stone-cache-filter-0534 tracked=" .. safe(count_table(r.caches)) ..
    " swept=" .. safe((r.stats or {}).swept or 0) ..
    " rerouted=" .. safe((r.stats or {}).rerouted or 0) ..
    " registered=" .. safe((r.stats or {}).registered or 0) ..
    " full_rescans=" .. safe((r.stats or {}).full_rescans or 0) ..
    " sweep_budget_exhausted=" .. safe((r.stats or {}).sweep_budget_exhausted or 0)
  }
end

function M.runtime_report()
  return M.report_lines()
end

function M.on_removed(event)
  local entity = event and event.entity
  if not valid(entity) then return false end
  local allowed = M.allowed_by_entity[entity.name]
  if not allowed then return false end
  local r = root()
  for key, cached in pairs(r.caches or {}) do
    if cached == entity then
      r.caches[key] = nil
      r.stats.removed = (r.stats.removed or 0) + 1
      return true
    else
      local unit = entity.unit_number
      if unit and tostring(key) == tostring(unit) then
        r.caches[key] = nil
        r.stats.removed = (r.stats.removed or 0) + 1
        return true
      end
    end
  end
  return false
end

function M.on_built(event)
  local entity = event and (event.created_entity or event.entity or event.destination)
  if entity then M.register_entity(entity) end
end

function M.install()
  if M.installed then return true end
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  if not (registry and type(registry.on_init) == "function"
    and type(registry.on_configuration_changed) == "function"
    and type(registry.on_event) == "function"
    and type(registry.on_nth_tick) == "function")
  then return false end

  local routes = {}
  routes[#routes + 1] = registry.on_init(function() root(); M.full_rescan("init") end,
    { owner = "stone_cache_filter_0534", route = "init-scan", category = "inventory" })
  routes[#routes + 1] = registry.on_configuration_changed(
    function() root(); M.full_rescan("configuration-changed") end,
    { owner = "stone_cache_filter_0534", route = "configuration-scan", category = "inventory" })
  routes[#routes + 1] = registry.on_nth_tick(M.tick_interval, function() M.service() end,
    { owner = "stone_cache_filter_0534", route = "filtered-cache-sweep", category = "inventory" })
  if defines and defines.events then
    local e = defines.events
    for _, spec in ipairs({
      { e.on_built_entity, "player-built", M.on_built },
      { e.on_robot_built_entity, "robot-built", M.on_built },
      { e.script_raised_built, "script-built", M.on_built },
      { e.script_raised_revive, "script-revived", M.on_built },
      { e.on_player_mined_entity, "player-mined", M.on_removed },
      { e.on_robot_mined_entity, "robot-mined", M.on_removed },
      { e.on_entity_died, "entity-died", M.on_removed },
      { e.script_raised_destroy, "script-destroyed", M.on_removed },
    }) do
      if spec[1] then
        routes[#routes + 1] = registry.on_event(spec[1], spec[3], nil,
          { owner = "stone_cache_filter_0534", route = spec[2], category = "inventory" })
      end
    end
  end
  for _, route in ipairs(routes) do if not route then return false end end
  root()
  _G.tech_priests_stone_cache_filter_0534 = M
  M.route_owner = "runtime-event-registry"
  M.installed = true
  if commands and commands.remove_command then pcall(commands.remove_command, "tp-cache-filters-0534") end
  if log then log("[Tech-Priests 0.1.674-dev] filtered cache steward installed with physical no-spill rerouting") end
  return true
end

return M
