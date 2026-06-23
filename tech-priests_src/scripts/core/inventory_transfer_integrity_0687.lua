-- Tech Priests 0.1.665 inventory transfer integrity.
-- Accidental priest cargo must be removed from the priest before it is credited to
-- station storage. Exact deposit failure restores the same item to the same
-- physical inventory, preventing deposit-first duplication.

local M = {
  version = "0.1.665",
  storage_key = "inventory_transfer_integrity_0687",
}

local previous_steward_install

local function now()
  return game and game.tick or 0
end

local function valid(entity)
  return entity and entity.valid
end

local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end

local function valid_pair(pair)
  return pair and valid(pair.station) and valid(pair.priest)
end

local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
    recent = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(name, amount)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (amount or 1)
end

local function record(pair, action, detail)
  local r = root()
  stat(action)
  r.recent[#r.recent + 1] = {
    tick = now(),
    action = tostring(action or "event"),
    station = safe(station_unit(pair)),
    detail = tostring(detail or ""),
  }
  while #r.recent > 120 do table.remove(r.recent, 1) end
end

local function inventory(entity, inventory_id)
  if not (valid(entity) and inventory_id and entity.get_inventory) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inventory_id) end)
  return ok and inv and inv.valid and inv or nil
end

local function priest_inventories(pair)
  local out, seen = {}, {}
  if not valid_pair(pair) then return out end
  local function add(inv)
    if not (inv and inv.valid) then return end
    local key = safe(inv)
    if seen[key] then return end
    seen[key] = true
    out[#out + 1] = inv
  end
  if pair.priest.get_main_inventory then
    local ok, inv = pcall(function() return pair.priest.get_main_inventory() end)
    if ok then add(inv) end
  end
  local d = defines and defines.inventory
  if d then
    add(inventory(pair.priest, d.character_main))
    add(inventory(pair.priest, d.chest))
    add(inventory(pair.priest, d.spider_trunk))
    add(inventory(pair.priest, d.car_trunk))
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

local function deposit_exact(pair, item, count, reason)
  local authority = rawget(_G, "TechPriestsStorageRoleAuthority0686")
  if not authority then
    local ok, module = pcall(require, "scripts.core.storage_role_authority_0686")
    if ok then authority = module end
  end
  if authority and type(authority.deposit_exact) == "function" then
    return authority.deposit_exact(pair, item, count, reason or "priest-cargo-evacuation", {})
  end
  local fn = rawget(_G, "tech_priests_safe_deposit_item")
  if type(fn) == "function" then
    local ok, why, inserted = fn(pair, item, count, reason or "priest-cargo-evacuation")
    return ok, why, tonumber(inserted) or (ok and count or 0)
  end
  return false, "no-deposit-authority", 0
end

local function patch_steward(steward)
  if not steward or steward.inventory_transfer_integrity_0687_active then return false end
  steward.inventory_transfer_integrity_0687_active = true

  steward.flush_priest_inventory_to_station = function(pair, reason)
    if root().enabled == false then return 0, "disabled" end
    if not valid_pair(pair) then return 0, "invalid-pair" end
    local moved = 0

    for _, inv in ipairs(priest_inventories(pair)) do
      for index = 1, #inv do
        local stack = inv[index]
        if stack and stack.valid_for_read then
          local item = stack.name
          local count = math.max(1, tonumber(stack.count) or 1)
          local removed = remove_item(inv, item, count)
          if removed <= 0 then
            record(pair, "priest-cargo-remove-failed", item .. " x" .. safe(count))
            return moved, "priest-remove-failed"
          end

          local deposited, why, inserted = deposit_exact(
            pair,
            item,
            removed,
            reason or "priest-inventory-evacuation-0687"
          )
          if deposited and inserted == removed then
            moved = moved + removed
            stat("priest_items_evacuated", removed)
            record(pair, "priest-cargo-evacuated", item .. " x" .. safe(removed))
          else
            local restored = insert_item(inv, item, removed)
            stat("priest_cargo_rollbacks")
            record(pair, "priest-cargo-rollback",
              item .. " removed=" .. safe(removed)
                .. " deposited=" .. safe(inserted)
                .. " restored=" .. safe(restored)
                .. " reason=" .. safe(why))
            if restored < removed then
              stat("critical_restore_shortfall", removed - restored)
              if log then
                log("[Tech-Priests 0.1.665] CRITICAL priest cargo restore shortfall station="
                  .. safe(station_unit(pair)) .. " item=" .. safe(item)
                  .. " missing=" .. safe(removed - restored))
              end
            end
            return moved, why or "deposit-blocked"
          end
        end
      end
    end
    return moved, "ok"
  end

  steward.unload_nonessential_priest_inventory = function(pair, reason)
    return steward.flush_priest_inventory_to_station(pair, reason or "compat-unload-0687")
  end

  _G.tech_priests_inventory_steward_unload = steward.flush_priest_inventory_to_station
  if commands and commands.remove_command then
    pcall(commands.remove_command, "tp-inventory-steward-0356")
    pcall(commands.remove_command, "tp-inventory-steward-0357")
  end
  return true
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.inventory_transfer_integrity_0687_wrapped
  then
    return false
  end
  diagnostics.inventory_transfer_integrity_0687_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local r = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 INVENTORY-TRANSFER-0687 enabled="
      .. safe(r.enabled)
      .. " evacuated=" .. safe(r.stats.priest_items_evacuated or 0)
      .. " rollbacks=" .. safe(r.stats.priest_cargo_rollbacks or 0)
      .. " remove_failed=" .. safe(r.stats["priest-cargo-remove-failed"] or 0)
      .. " restore_shortfall=" .. safe(r.stats.critical_restore_shortfall or 0)
    for index = math.max(1, #r.recent - 8), #r.recent do
      local event = r.recent[index]
      if event then
        lines[#lines + 1] = "PAIR-DUMP-0468 inventory-transfer.recent[" .. safe(index) .. "]"
          .. " tick=" .. safe(event.tick)
          .. " action=" .. safe(event.action)
          .. " station=" .. safe(event.station)
          .. " " .. safe(event.detail)
      end
    end
    return lines
  end
  return true
end

local function activate(steward)
  patch_steward(steward)
  patch_diagnostics()
  _G.TechPriestsInventoryTransferIntegrity0687 = M
end

function M.install()
  root()
  local ok, steward = pcall(require, "scripts.core.inventory_steward")
  if not (ok and steward) then return false end

  if not steward.inventory_transfer_integrity_0687_install_wrapped then
    steward.inventory_transfer_integrity_0687_install_wrapped = true
    previous_steward_install = steward.install
    steward.install = function(...)
      local result = type(previous_steward_install) == "function" and previous_steward_install(...) or true
      activate(steward)
      return result
    end
  end
  if rawget(_G, "TECH_PRIESTS_STATION_BOUND_INVENTORY_0357") then activate(steward) end
  _G.TechPriestsInventoryTransferIntegrity0687 = M
  return true
end

return M
