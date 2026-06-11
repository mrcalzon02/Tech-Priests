-- scripts/core/inventory_deposit_safety_0638.lua
-- Tech Priests 0.1.638
--
-- Crash-safety containment for the 0.1.637 fresh-world hard crash.
--
-- Doctrine:
--   Generic reserve/deposit paths may only insert into the Cogitator Station's
--   true chest inventory or nearby chest/container storage. They must not insert
--   arbitrary items into furnace source/result/fuel inventories, assembling
--   machine outputs, or any other machine result inventory. Machine service must
--   stay in machine-specific logistics executors.

local M = {}
M.version = "0.1.638"
M.storage_key = "inventory_deposit_safety_0638"
M.scan_radius = 28

local function valid(e) return e and e.valid end
local function now() return game and game.tick or 0 end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {} }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(name, n)
  local r = root()
  r.stats[name] = (tonumber(r.stats[name]) or 0) + (n or 1)
end

local function record(action, pair, detail)
  local r = root()
  r.recent[#r.recent + 1] = {
    tick = now(),
    action = tostring(action or "event"),
    station = pair and pair.station and pair.station.valid and pair.station.unit_number or "?",
    detail = tostring(detail or ""),
  }
  while #r.recent > 60 do table.remove(r.recent, 1) end
end

local function item_exists(name)
  return name and prototypes and prototypes.item and prototypes.item[name] ~= nil
end

local function safe_get_chest_inventory(entity)
  if not (valid(entity) and entity.get_inventory and defines and defines.inventory and defines.inventory.chest) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(defines.inventory.chest) end)
  if ok and inv and inv.valid then return inv end
  return nil
end

local function container_like(entity)
  return valid(entity) and (entity.type == "container" or entity.type == "logistic-container")
end

local function can_insert(inv, stack)
  if not (inv and inv.valid and stack and stack.name and stack.count and stack.count > 0) then return false end
  local ok, yes = pcall(function() return inv.can_insert(stack) end)
  return ok and yes == true
end

local function insert_checked(inv, stack)
  if not can_insert(inv, stack) then return 0 end
  local ok, inserted = pcall(function() return inv.insert(stack) end)
  if ok then return tonumber(inserted) or 0 end
  return 0
end

local function try_station_chest(pair, stack)
  local inv = safe_get_chest_inventory(pair and pair.station)
  local inserted = insert_checked(inv, stack)
  if inserted > 0 then return inserted, "station-chest" end
  return 0, "station-chest-full-or-missing"
end

local function try_known_stashes(pair, stack)
  local steward = storage and storage.tech_priests and storage.tech_priests.inventory_steward_0357 or nil
  local key = pair and (pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number)) or nil
  local bucket = key and steward and steward.stashes_by_station and steward.stashes_by_station[key] or nil
  if not bucket then return 0, "no-known-stashes" end
  for id, rec in pairs(bucket) do
    local e = rec and rec.entity
    if not valid(e) then
      bucket[id] = nil
    elseif container_like(e) then
      local inserted = insert_checked(safe_get_chest_inventory(e), stack)
      if inserted > 0 then return inserted, "known-stash" end
    else
      bucket[id] = nil
    end
  end
  return 0, "known-stashes-full"
end

local function try_nearby_containers(pair, stack)
  if not (valid_pair(pair) and pair.station.surface) then return 0, "invalid" end
  local ents = {}
  pcall(function()
    ents = pair.station.surface.find_entities_filtered({
      position = pair.station.position,
      radius = M.scan_radius,
      force = pair.station.force,
      type = { "container", "logistic-container" },
    }) or {}
  end)
  for _, e in pairs(ents) do
    if container_like(e) then
      local inserted = insert_checked(safe_get_chest_inventory(e), stack)
      if inserted > 0 then return inserted, "nearby-container" end
    end
  end
  return 0, "nearby-containers-full"
end

function M.safe_deposit_item(pair, item, count, reason)
  local r = root()
  if r.enabled == false then return false, "deposit-safety-disabled" end
  if not (valid_pair(pair) and item_exists(item)) then return false, "invalid" end
  count = math.max(1, tonumber(count) or 1)
  local remaining = count
  local stack = { name = item, count = remaining }

  local inserted, where = try_station_chest(pair, stack)
  remaining = remaining - inserted
  if remaining <= 0 then stat("deposited_station_chest", inserted); return true, where end

  stack.count = remaining
  inserted, where = try_known_stashes(pair, stack)
  remaining = remaining - inserted
  if remaining <= 0 then stat("deposited_known_stash", inserted); return true, where end

  stack.count = remaining
  inserted, where = try_nearby_containers(pair, stack)
  remaining = remaining - inserted
  if remaining <= 0 then stat("deposited_nearby_container", inserted); return true, where end

  stat("blocked")
  record("generic-deposit-blocked-0638", pair, "item=" .. safe(item) .. " count=" .. safe(count) .. " reason=" .. safe(reason) .. " remaining=" .. safe(remaining))
  return false, "no-safe-container-space"
end

function M.status()
  local r = root()
  return "enabled=" .. safe(r.enabled)
    .. " station=" .. safe(r.stats.deposited_station_chest or 0)
    .. " stash=" .. safe((r.stats.deposited_known_stash or 0) + (r.stats.deposited_nearby_container or 0))
    .. " blocked=" .. safe(r.stats.blocked or 0)
end

local function install_command()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-inventory-safety-0638") end end)
  commands.add_command("tp-inventory-safety-0638", "Tech Priests 0.1.638: generic inventory deposit safety status. Params: status/on/off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = tostring(event and event.parameter or "status")
    local r = root()
    if p == "on" then r.enabled = true elseif p == "off" then r.enabled = false end
    local msg = "[tp-inventory-safety-0638] " .. M.status()
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  root()
  if rawget(_G, "TECH_PRIESTS_0638_PRE_SAFE_DEPOSIT_ITEM") == nil then
    _G.TECH_PRIESTS_0638_PRE_SAFE_DEPOSIT_ITEM = rawget(_G, "tech_priests_safe_deposit_item")
  end
  _G.tech_priests_safe_deposit_item = M.safe_deposit_item
  _G.TechPriestsInventoryDepositSafety0638 = M
  install_command()
  if log then log("[Tech-Priests 0.1.638] generic inventory deposit safety installed; arbitrary deposits are chest/container-only") end
  return true
end

return M
