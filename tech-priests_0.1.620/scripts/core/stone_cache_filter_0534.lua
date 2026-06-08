-- Tech Priests 0.1.534 - Stone-cache item filter steward.
-- Factorio's ordinary container prototype does not provide a per-entity item-only
-- inventory filter.  This steward enforces the named cache promise at runtime by
-- sweeping filtered cache inventories and ejecting any wrong item stack near the
-- cache.  It does not create logistics work, complete orders, or move priests.

local M = {}

M.tick_interval = 89

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
    stats = { swept = 0, ejected = 0, registered = 0 }
  }
  return storage.tech_priests_stone_cache_filter_0534
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

local function spill(entity, stack)
  if not (valid(entity) and stack and stack.valid_for_read and stack.count and stack.count > 0) then return 0 end
  local count = stack.count
  entity.surface.spill_item_stack({
    position = entity.position,
    stack = { name = stack.name, count = count },
    enable_looted = true,
    force = entity.force,
    allow_belts = false
  })
  return count
end

function M.sweep_entity(entity)
  if not valid(entity) then return false end
  local allowed = M.allowed_by_entity[entity.name]
  if not allowed then return false end
  local inv = entity.get_inventory and entity.get_inventory(defines.inventory.chest)
  if not (inv and inv.valid) then return false end
  local r = root()
  local ejected = 0
  for i = 1, #inv do
    local stack = inv[i]
    if stack and stack.valid_for_read and stack.name ~= allowed then
      ejected = ejected + spill(entity, stack)
      stack.clear()
    end
  end
  r.stats.swept = (r.stats.swept or 0) + 1
  r.stats.ejected = (r.stats.ejected or 0) + ejected
  return ejected > 0
end

function M.sweep_all()
  local r = root()
  local stale = {}
  for key, entity in pairs(r.caches or {}) do
    if valid(entity) then
      M.sweep_entity(entity)
    else
      stale[#stale + 1] = key
    end
  end
  for _, key in pairs(stale) do r.caches[key] = nil end
end

function M.on_built(event)
  local entity = event and (event.created_entity or event.entity or event.destination)
  if entity then M.register_entity(entity) end
end

function M.register_commands()
  if not commands or not commands.add_command then return end
  pcall(function()
    commands.add_command("tp-cache-filters-0534", "Tech Priests: inspect/rescan filtered stone cache enforcement.", function(event)
      local player = game and event and event.player_index and game.get_player(event.player_index) or nil
      local r = root()
      local rescanned = M.scan_all_surfaces()
      M.sweep_all()
      local msg = "[tp-cache-filters-0534] tracked=" .. safe(count_table(r.caches)) .. " rescanned=" .. safe(rescanned) .. " swept=" .. safe(r.stats.swept) .. " ejected=" .. safe(r.stats.ejected)
      if player then player.print(msg) elseif log then log(msg) end
    end)
  end)
end

function M.install()
  root()
  if M._installed then return true end
  M._installed = true
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  if R and R.on_init then R.on_init(function() root(); M.scan_all_surfaces() end, { owner = "stone_cache_filter_0534", category = "inventory" }) end
  if R and R.on_configuration_changed then R.on_configuration_changed(function() root(); M.scan_all_surfaces() end, { owner = "stone_cache_filter_0534", category = "inventory" }) end
  if R and R.on_nth_tick then
    R.on_nth_tick(M.tick_interval, function() M.scan_all_surfaces(); M.sweep_all() end, { owner = "stone_cache_filter_0534", category = "inventory" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.tick_interval, function() M.scan_all_surfaces(); M.sweep_all() end)
  end
  local function reg(ev, fn)
    if R and R.on_event then
      R.on_event(ev, fn, nil, { owner = "stone_cache_filter_0534", category = "inventory" })
    elseif script and script.on_event then
      script.on_event(ev, fn)
    end
  end
  if defines and defines.events then
    local e = defines.events
    if e.on_built_entity then reg(e.on_built_entity, M.on_built) end
    if e.on_robot_built_entity then reg(e.on_robot_built_entity, M.on_built) end
    if e.script_raised_built then reg(e.script_raised_built, M.on_built) end
    if e.script_raised_revive then reg(e.script_raised_revive, M.on_built) end
  end
  M.register_commands()
  _G.tech_priests_stone_cache_filter_0534 = M
  if log then log("[Tech-Priests 0.1.534] filtered stone cache steward installed") end
  return true
end

return M
