-- scripts/core/inventory_steward.lua
-- Tech Priests 0.1.674-dev recovery.
-- Canonical station-bound inventory and priest-cargo custody authority.
-- Priest cargo is removed before station credit. Any blocked deposit is restored
-- to the exact source inventory when possible; a restore shortfall remains in
-- serializable pair custody until a later broker-owned service pass resolves it.

local Steward = {
  version = "0.1.674-dev",
  storage_key = "inventory_steward_0357",
  legacy_storage_key = "inventory_steward_0356",
  tick_interval = 43,
  pulse_max_pairs = 12,
}

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end
local function station_unit(pair)
  return pair and (pair.station_unit
    or (valid(pair.station) and pair.station.unit_number)) or nil
end
local function pair_map()
  return storage and storage.tech_priests
    and storage.tech_priests.pairs_by_station or {}
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local legacy = storage.tech_priests[Steward.legacy_storage_key]
  local state = storage.tech_priests[Steward.storage_key] or {
    version = Steward.version,
    enabled = true,
    exact_remove_before_credit = true,
    persistent_restore_custody = true,
    stashes_by_station = legacy and legacy.stashes_by_station or {},
    stats = {},
    recent = {},
  }
  storage.tech_priests[Steward.storage_key] = state
  state.version = Steward.version
  if state.enabled == nil then state.enabled = true end
  if state.exact_remove_before_credit == nil then state.exact_remove_before_credit = true end
  if state.persistent_restore_custody == nil then state.persistent_restore_custody = true end
  state.stashes_by_station = state.stashes_by_station or {}
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  return state
end
Steward.root = root

local function stat(name, amount)
  local state = root()
  state.stats[name] = (tonumber(state.stats[name]) or 0) + (tonumber(amount) or 1)
end
local function record(pair, action, detail)
  local state = root()
  stat(action)
  state.recent[#state.recent + 1] = {
    tick = now(),
    station = safe(station_unit(pair)),
    action = safe(action),
    detail = safe(detail),
  }
  while #state.recent > 120 do table.remove(state.recent, 1) end
end

local function draw_status(pair, text, ttl)
  local emit = rawget(_G, "tech_priests_emit_overhead_status_0473")
  if type(emit) == "function" then
    pcall(emit, pair, text, { r = 1, g = 0.82, b = 0.22, a = 0.95 },
      ttl or 90, 0.62, "inventory-steward")
  end
end

local function inventory(entity, inventory_id)
  if not (valid(entity) and inventory_id and entity.get_inventory) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inventory_id) end)
  return ok and inv and inv.valid and inv or nil
end
local function add_inventory(out, seen, inv, source)
  if not (inv and inv.valid) then return end
  local key = safe(inv)
  if seen[key] then return end
  seen[key] = true
  out[#out + 1] = { inv = inv, source = source }
end
local function priest_inventories(pair)
  local out, seen = {}, {}
  if not valid_pair(pair) then return out end
  if pair.priest.get_main_inventory then
    local ok, inv = pcall(function() return pair.priest.get_main_inventory() end)
    if ok then add_inventory(out, seen, inv, "priest-main") end
  end
  local ids = defines and defines.inventory
  if ids then
    add_inventory(out, seen, inventory(pair.priest, ids.character_main), "character-main")
    add_inventory(out, seen, inventory(pair.priest, ids.chest), "priest-chest")
    add_inventory(out, seen, inventory(pair.priest, ids.spider_trunk), "priest-spider-trunk")
    add_inventory(out, seen, inventory(pair.priest, ids.car_trunk), "priest-car-trunk")
  end
  return out
end
local function remove_item(inv, item, count)
  if not (inv and inv.valid and item and (tonumber(count) or 0) > 0) then return 0 end
  local ok, removed = pcall(function()
    return inv.remove({ name = item, count = count })
  end)
  return ok and (tonumber(removed) or 0) or 0
end
local function insert_item(inv, item, count)
  if not (inv and inv.valid and item and (tonumber(count) or 0) > 0) then return 0 end
  local ok, inserted = pcall(function()
    return inv.insert({ name = item, count = count })
  end)
  return ok and (tonumber(inserted) or 0) or 0
end
local function inventory_item_count(inv)
  if not (inv and inv.valid) then return 0 end
  local ok, contents = pcall(function() return inv.get_contents() end)
  if not (ok and contents) then return 0 end
  local total = 0
  for _, value in pairs(contents) do
    if type(value) == "number" then total = total + value
    elseif type(value) == "table" then total = total + (tonumber(value.count) or 0) end
  end
  return total
end

local function storage_authority()
  return rawget(_G, "TechPriestsStorageRoleAuthority0686")
    or package.loaded["scripts.core.storage_role_authority_0686"]
end

function Steward.safe_deposit_item(pair, item, count, reason, options)
  if root().enabled == false then return false, "disabled", 0 end
  if not valid_pair(pair) then return false, "invalid-pair", 0 end
  count = math.max(1, math.floor(tonumber(count) or 1))
  local authority = storage_authority()
  if not (authority and type(authority.deposit_exact) == "function") then
    return false, "storage-authority-unavailable", 0
  end
  local ok, accepted, why, inserted = pcall(
    authority.deposit_exact, pair, item, count,
    reason or "inventory-steward-deposit", options or { role = "general" })
  inserted = tonumber(inserted) or (accepted == true and count or 0)
  local complete = ok and accepted == true and inserted == count
  if complete then stat("exact_items_deposited", inserted)
  else stat("exact_deposit_blocked") end
  return complete, ok and why or accepted, inserted
end

function Steward.create_stash(pair)
  local authority = storage_authority()
  if not (authority and type(authority.create_stash) == "function") then
    return nil, "storage-authority-unavailable"
  end
  return authority.create_stash(pair, "general")
end

local function clear_custody(pair)
  pair.inventory_transfer_custody_0687 = nil
end
local function retain_custody(pair, item, count, source_inventory, source, reason)
  pair.inventory_transfer_custody_0687 = {
    version = Steward.version,
    phase = "removed-not-credited",
    item = item,
    count = count,
    source_inventory = source_inventory,
    source = source,
    reason = safe(reason),
    created_tick = now(),
    updated_tick = now(),
  }
  stat("custody-retained", count)
  record(pair, "priest-cargo-custody-retained",
    item .. " x" .. safe(count) .. " reason=" .. safe(reason))
end

function Steward.service_custody(pair, reason)
  if not valid_pair(pair) then return false, "invalid-pair", 0 end
  local custody = pair.inventory_transfer_custody_0687
  if type(custody) ~= "table" then return true, "no-custody", 0 end
  local count = math.max(0, math.floor(tonumber(custody.count) or 0))
  if count <= 0 or not custody.item then
    clear_custody(pair)
    return true, "empty-custody", 0
  end

  local deposited, why, inserted = Steward.safe_deposit_item(
    pair, custody.item, count,
    reason or "priest-cargo-custody-deposit-0687", { role = "general" })
  if deposited and inserted == count then
    clear_custody(pair)
    stat("custody-deposited", count)
    record(pair, "priest-cargo-custody-deposited", custody.item .. " x" .. safe(count))
    return true, "custody-deposited", count
  end

  local restored = insert_item(custody.source_inventory, custody.item, count)
  custody.count = count - restored
  custody.updated_tick = now()
  custody.last_blocker = safe(why)
  if restored > 0 then stat("custody-restored", restored) end
  if custody.count <= 0 then
    clear_custody(pair)
    record(pair, "priest-cargo-custody-restored",
      custody.item .. " x" .. safe(restored))
    return true, "custody-restored", 0
  end

  stat("custody-blocked")
  record(pair, "priest-cargo-custody-blocked",
    custody.item .. " remaining=" .. safe(custody.count)
      .. " restored=" .. safe(restored) .. " reason=" .. safe(why))
  return false, why or "custody-blocked", custody.count
end

local function transfer_stack(pair, source, item, count, reason)
  local removed = remove_item(source.inv, item, count)
  if removed <= 0 then
    record(pair, "priest-cargo-remove-failed", item .. " x" .. safe(count))
    return false, "priest-remove-failed", 0
  end
  retain_custody(pair, item, removed, source.inv, source.source,
    reason or "priest-inventory-evacuation-0687")
  local completed, why, amount = Steward.service_custody(
    pair, reason or "priest-inventory-evacuation-0687")
  if completed and why == "custody-deposited" then
    stat("priest-items-evacuated", removed)
    record(pair, "priest-cargo-evacuated", item .. " x" .. safe(removed))
    return true, "deposited", amount
  end
  return false, why, tonumber(amount) or 0
end

function Steward.flush_priest_inventory_to_station(pair, reason)
  if root().enabled == false then return 0, "disabled" end
  if not valid_pair(pair) then return 0, "invalid-pair" end
  local custody_ok, custody_why = Steward.service_custody(
    pair, reason or "priest-cargo-custody-retry-0687")
  if not custody_ok then return 0, custody_why end

  local moved = 0
  for _, source in ipairs(priest_inventories(pair)) do
    for index = 1, #source.inv do
      local stack = source.inv[index]
      if stack and stack.valid_for_read then
        local item, count = stack.name, math.max(1, tonumber(stack.count) or 1)
        local completed, why, transferred = transfer_stack(
          pair, source, item, count,
          reason or "priest-inventory-evacuation-0687")
        moved = moved + (tonumber(transferred) or 0)
        if not completed then
          draw_status(pair, "station-bound inventory blocked: " .. safe(why), 120)
          return moved, why
        end
      end
    end
  end
  if moved > 0 then
    stat("evacuated_priest_items", moved)
    draw_status(pair, "station-bound inventory: moved " .. safe(moved) .. " items", 90)
  end
  return moved, "ok"
end

function Steward.unload_nonessential_priest_inventory(pair, reason)
  return Steward.flush_priest_inventory_to_station(pair, reason or "compat-unload")
end
function Steward.ensure_priest_room(pair, slots, reason)
  local moved, why = Steward.flush_priest_inventory_to_station(
    pair, reason or "station-bound-room")
  if why ~= "ok" then return false, why end
  local authority = storage_authority()
  local free = 0
  if authority and type(authority.generic_storage_sources) == "function" then
    for _, source in ipairs(authority.generic_storage_sources(pair)) do
      local ok, count = pcall(function() return source.inv.count_empty_stacks() end)
      if ok then free = free + (tonumber(count) or 0) end
    end
  end
  return free >= (tonumber(slots) or 1), free >= (tonumber(slots) or 1)
    and "station-space" or "station-full"
end

function Steward.sources_for_pair(pair)
  if not valid_pair(pair) then return {} end
  Steward.flush_priest_inventory_to_station(pair, "sources-for-pair")
  local authority = storage_authority()
  if authority and type(authority.generic_storage_sources) == "function" then
    return authority.generic_storage_sources(pair)
  end
  return {}
end

function Steward.pulse_pair(pair, reason)
  if not valid_pair(pair) then return false, "invalid-pair" end
  local moved, why = Steward.flush_priest_inventory_to_station(
    pair, reason or "periodic-station-bound-flush")
  return moved > 0, why
end

function Steward.pulse(event, budget)
  local state = root()
  if state.enabled == false then
    return { processed = 0, acted = 0, blocked = 0, failed = 0, exhausted = false }
  end
  local limit = math.max(1, math.min(Steward.pulse_max_pairs,
    math.floor(tonumber(budget) or Steward.pulse_max_pairs)))
  local processed, acted, blocked, failed = 0, 0, 0, 0
  for _, pair in pairs(pair_map()) do
    if processed >= limit then break end
    if valid_pair(pair) then
      processed = processed + 1
      local ok, did, why = pcall(Steward.pulse_pair, pair, "broker")
      if not ok then failed = failed + 1
      elseif did then acted = acted + 1
      elseif why ~= "ok" and why ~= "no-custody" then blocked = blocked + 1 end
    end
  end
  return {
    processed = processed,
    acted = acted,
    blocked = blocked,
    failed = failed,
    exhausted = processed >= limit,
  }
end

function Steward.status(pair)
  local state = root()
  local cargo = 0
  if valid_pair(pair) then
    for _, source in ipairs(priest_inventories(pair)) do
      cargo = cargo + inventory_item_count(source.inv)
    end
  end
  local custody = pair and pair.inventory_transfer_custody_0687
  return "enabled=" .. safe(state.enabled)
    .. " route_owner=" .. safe(Steward.route_owner)
    .. " accidental_priest_items=" .. safe(cargo)
    .. " custody_item=" .. safe(custody and custody.item)
    .. " custody_count=" .. safe(custody and custody.count)
    .. " evacuated=" .. safe(state.stats.evacuated_priest_items or 0)
    .. " blocked=" .. safe(state.stats["custody-blocked"] or 0)
end

function Steward.install()
  if Steward.installed then return true end
  local authority = storage_authority()
  if not (authority and type(authority.deposit_exact) == "function"
    and type(authority.generic_storage_sources) == "function")
  then
    if log then log("[Tech-Priests 0.1.674-dev] inventory steward not installed: canonical storage authority unavailable") end
    return false
  end
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not broker then
    local ok, found = pcall(require, "scripts.core.runtime_tick_broker")
    if ok then broker = found end
  end
  if not (broker and type(broker.register_service) == "function") then
    if log then log("[Tech-Priests 0.1.674-dev] inventory steward not installed: runtime broker unavailable") end
    return false
  end
  local ok, service = pcall(broker.register_service, {
    name = "inventory_steward_0357",
    category = "inventory",
    interval = Steward.tick_interval,
    priority = 65,
    budget = Steward.pulse_max_pairs,
    dynamic_budget = false,
    fn = Steward.pulse,
    note = "canonical remove-before-credit station inventory custody",
  })
  if not (ok and service) then
    if log then log("[Tech-Priests 0.1.674-dev] inventory steward not installed: broker registration rejected") end
    return false
  end

  root()
  _G.tech_priests_safe_deposit_item = Steward.safe_deposit_item
  _G.tech_priests_inventory_steward_unload = Steward.flush_priest_inventory_to_station
  _G.tech_priests_inventory_steward_create_stash = Steward.create_stash
  _G.tech_priests_inventory_steward_sources_for_pair = Steward.sources_for_pair
  _G.TECH_PRIESTS_STATION_BOUND_INVENTORY_0357 = Steward
  if commands and commands.remove_command then
    pcall(commands.remove_command, "tp-inventory-steward-0356")
    pcall(commands.remove_command, "tp-inventory-steward-0357")
  end
  Steward.route_owner = "runtime-tick-broker"
  Steward.installed = true
  if log then
    log("[Tech-Priests 0.1.674-dev] canonical station-bound inventory steward installed with persistent remove-before-credit custody")
  end
  return true
end

return Steward
