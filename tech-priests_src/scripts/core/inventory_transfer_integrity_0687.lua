-- scripts/core/inventory_transfer_integrity_0687.lua
-- Tech Priests 0.1.674-dev recovery.
-- Priest cargo is removed before crediting storage. A blocked exact deposit is
-- restored to the same physical inventory when possible; any restore shortfall
-- remains in persistent custody until it can be deposited or restored exactly.

local M = {
  version = "0.1.674-dev",
  storage_key = "inventory_transfer_integrity_0687",
}

local previous_steward_install

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

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    exact_remove_before_credit = true,
    persistent_restore_custody = true,
    stats = {},
    recent = {},
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  if state.exact_remove_before_credit == nil then
    state.exact_remove_before_credit = true
  end
  if state.persistent_restore_custody == nil then
    state.persistent_restore_custody = true
  end
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  return state
end
local function stat(name, amount)
  local state = M.root()
  state.stats[name] = (tonumber(state.stats[name]) or 0)
    + (tonumber(amount) or 1)
end
local function record(pair, action, detail)
  local state = M.root()
  stat(action)
  state.recent[#state.recent + 1] = {
    tick = now(),
    action = safe(action),
    station = safe(station_unit(pair)),
    detail = safe(detail),
  }
  while #state.recent > 120 do table.remove(state.recent, 1) end
end

local function inventory(entity, inventory_id)
  if not (valid(entity) and inventory_id and entity.get_inventory) then
    return nil
  end
  local ok, inv = pcall(function()
    return entity.get_inventory(inventory_id)
  end)
  return ok and inv and inv.valid and inv or nil
end
local function priest_inventories(pair)
  local out, seen = {}, {}
  if not valid_pair(pair) then return out end
  local function add(inv, source)
    if not (inv and inv.valid) then return end
    local key = safe(inv)
    if seen[key] then return end
    seen[key] = true
    out[#out + 1] = { inv = inv, source = source }
  end
  if pair.priest.get_main_inventory then
    local ok, inv = pcall(function()
      return pair.priest.get_main_inventory()
    end)
    if ok then add(inv, "priest-main") end
  end
  local ids = defines and defines.inventory
  if ids then
    add(inventory(pair.priest, ids.character_main), "character-main")
    add(inventory(pair.priest, ids.chest), "priest-chest")
    add(inventory(pair.priest, ids.spider_trunk), "priest-spider-trunk")
    add(inventory(pair.priest, ids.car_trunk), "priest-car-trunk")
  end
  return out
end
local function remove_item(inv, item, count)
  if not (inv and inv.valid and item and (tonumber(count) or 0) > 0) then
    return 0
  end
  local ok, removed = pcall(function()
    return inv.remove({ name = item, count = count })
  end)
  return ok and (tonumber(removed) or 0) or 0
end
local function insert_item(inv, item, count)
  if not (inv and inv.valid and item and (tonumber(count) or 0) > 0) then
    return 0
  end
  local ok, inserted = pcall(function()
    return inv.insert({ name = item, count = count })
  end)
  return ok and (tonumber(inserted) or 0) or 0
end
local function storage_authority()
  return rawget(_G, "TechPriestsStorageRoleAuthority0686")
    or package.loaded["scripts.core.storage_role_authority_0686"]
end
local function deposit_exact(pair, item, count, reason)
  local authority = storage_authority()
  if not (authority and type(authority.deposit_exact) == "function") then
    return false, "storage-authority-unavailable", 0
  end
  local ok, accepted, why, inserted = pcall(
    authority.deposit_exact,
    pair,
    item,
    count,
    reason or "priest-cargo-evacuation-0687",
    { role = "general" }
  )
  inserted = tonumber(inserted) or (accepted == true and count or 0)
  return ok and accepted == true and inserted == count,
    ok and why or accepted,
    inserted
end

local function clear_custody(pair)
  pair.inventory_transfer_custody_0687 = nil
end
local function retain_custody(pair, item, count, source_inventory, source, reason)
  pair.inventory_transfer_custody_0687 = {
    version = M.version,
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

function M.service_custody(pair, reason)
  if not valid_pair(pair) then return false, "invalid-pair", 0 end
  local custody = pair.inventory_transfer_custody_0687
  if type(custody) ~= "table" then return true, "no-custody", 0 end
  local count = math.max(0, math.floor(tonumber(custody.count) or 0))
  if count <= 0 or not custody.item then
    clear_custody(pair)
    return true, "empty-custody", 0
  end

  local deposited, why = deposit_exact(
    pair,
    custody.item,
    count,
    reason or "priest-cargo-custody-deposit-0687"
  )
  if deposited then
    clear_custody(pair)
    stat("custody-deposited", count)
    record(pair, "priest-cargo-custody-deposited",
      custody.item .. " x" .. safe(count))
    return true, "custody-deposited", count
  end

  local restored = insert_item(
    custody.source_inventory,
    custody.item,
    count
  )
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
      .. " restored=" .. safe(restored)
      .. " reason=" .. safe(why))
  return false, why or "custody-blocked", custody.count
end

local function transfer_stack(pair, inv, source, item, count, reason)
  local removed = remove_item(inv, item, count)
  if removed <= 0 then
    record(pair, "priest-cargo-remove-failed",
      item .. " x" .. safe(count))
    return false, "priest-remove-failed", 0
  end

  retain_custody(
    pair,
    item,
    removed,
    inv,
    source,
    reason or "priest-inventory-evacuation-0687"
  )
  local completed, why, remaining = M.service_custody(
    pair,
    reason or "priest-inventory-evacuation-0687"
  )
  if completed then
    if why == "custody-deposited" then
      stat("priest-items-evacuated", removed)
      record(pair, "priest-cargo-evacuated",
        item .. " x" .. safe(removed))
      return true, "deposited", removed
    end
    return false, why, 0
  end
  return false, why, remaining
end

function M.flush_priest_inventory_to_station(pair, reason)
  if M.root().enabled == false then return 0, "disabled" end
  if not valid_pair(pair) then return 0, "invalid-pair" end

  local custody_ok, custody_why = M.service_custody(
    pair,
    reason or "priest-cargo-custody-retry-0687"
  )
  if not custody_ok then return 0, custody_why end

  local moved = 0
  for _, source in ipairs(priest_inventories(pair)) do
    for index = 1, #source.inv do
      local stack = source.inv[index]
      if stack and stack.valid_for_read then
        local item = stack.name
        local count = math.max(1, tonumber(stack.count) or 1)
        local completed, why, transferred = transfer_stack(
          pair,
          source.inv,
          source.source,
          item,
          count,
          reason or "priest-inventory-evacuation-0687"
        )
        moved = moved + (tonumber(transferred) or 0)
        if not completed then return moved, why end
      end
    end
  end
  return moved, "ok"
end

local function patch_steward(steward)
  if not steward then return false end
  if steward.inventory_transfer_integrity_0687_active then return true end
  steward.inventory_transfer_integrity_0687_active = true
  steward.flush_priest_inventory_to_station = M.flush_priest_inventory_to_station
  steward.unload_nonessential_priest_inventory = function(pair, reason)
    return M.flush_priest_inventory_to_station(
      pair,
      reason or "compat-unload-0687"
    )
  end
  _G.tech_priests_inventory_steward_unload =
    steward.flush_priest_inventory_to_station
  if commands and commands.remove_command then
    pcall(commands.remove_command, "tp-inventory-steward-0356")
    pcall(commands.remove_command, "tp-inventory-steward-0357")
  end
  return true
end

local function patch_diagnostics()
  local diagnostics = rawget(_G,
    "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then
    return false
  end
  if diagnostics.inventory_transfer_integrity_0687_wrapped then return true end
  diagnostics.inventory_transfer_integrity_0687_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local state = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 INVENTORY-TRANSFER-0687 enabled="
      .. safe(state.enabled)
      .. " evacuated=" .. safe(state.stats["priest-items-evacuated"] or 0)
      .. " custody_retained=" .. safe(state.stats["custody-retained"] or 0)
      .. " custody_deposited=" .. safe(state.stats["custody-deposited"] or 0)
      .. " custody_restored=" .. safe(state.stats["custody-restored"] or 0)
      .. " custody_blocked=" .. safe(state.stats["custody-blocked"] or 0)
      .. " remove_failed=" .. safe(state.stats["priest-cargo-remove-failed"] or 0)
    for index = math.max(1, #state.recent - 8), #state.recent do
      local event = state.recent[index]
      if event then
        lines[#lines + 1] = "PAIR-DUMP-0468 inventory-transfer.recent["
          .. safe(index) .. "] tick=" .. safe(event.tick)
          .. " action=" .. safe(event.action)
          .. " station=" .. safe(event.station)
          .. " " .. safe(event.detail)
      end
    end
    return lines
  end
  return true
end

function M.install()
  M.root()
  local ok, steward = pcall(require, "scripts.core.inventory_steward")
  if not (ok and steward) then return false end

  if not steward.inventory_transfer_integrity_0687_install_wrapped then
    steward.inventory_transfer_integrity_0687_install_wrapped = true
    previous_steward_install = steward.install
    steward.install = function(...)
      local previous = type(previous_steward_install) == "function"
        and previous_steward_install(...) or true
      local patched = patch_steward(steward)
      return previous == true and patched == true
    end
  end

  local patched = patch_steward(steward)
  patch_diagnostics()
  _G.TechPriestsInventoryTransferIntegrity0687 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] persistent priest cargo transfer custody armed")
  end
  return patched == true
end

return M
