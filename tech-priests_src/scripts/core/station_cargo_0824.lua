-- A priest is a Factorio unit, not a character with an inventory.  An
-- engine-owned LuaInventory is the persistent one-slot cargo hold for exactly
-- one physical station item while that priest walks to a station ghost.
-- No item is credited merely by setting a Lua count or a mission phase.
local M = { version = "0.1.674-dev.0824", reach_sq = 25 }
local function valid(e) return e and e.valid end
local function records()
  if not (storage and storage.tech_priests) then return nil end
  local tp = storage.tech_priests
  tp.station_cargo_0824 = tp.station_cargo_0824 or {}
  return tp.station_cargo_0824
end
local function near(a, b)
  if not (a and b) then return false end
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy <= M.reach_sq
end
local function owner(worker, rec, cargo)
  return valid(worker and worker.station) and valid(worker.priest)
    and rec and cargo and cargo.record_id == rec.id
    and cargo.station_unit == worker.station.unit_number
    and cargo.priest_unit == worker.priest.unit_number
    and cargo.item == rec.station_item
    and cargo.surface == worker.station.surface
    and cargo.force == worker.station.force
    and valid(cargo.inventory)
end
local function count(inv, item)
  if not (valid(inv) and type(inv.get_item_count) == "function") then return nil end
  local ok, n = pcall(function() return inv.get_item_count(item) end)
  return ok and type(n) == "number" and n or nil
end
local function discard_empty(inv)
  if valid(inv) and type(inv.destroy) == "function" then
    pcall(function() inv.destroy() end)
  end
end
function M.has_record(rec)
  local r = records()
  return r and rec and r[rec.id] ~= nil or false
end
function M.get(worker, rec)
  local r = records()
  local cargo = r and rec and r[rec.id] or nil
  if not cargo then return nil, "no-carried-item" end
  if not owner(worker, rec, cargo) then return nil, "cargo-owner-or-inventory-invalid" end
  return cargo
end
function M.pickup(worker, rec, source)
  local r = records()
  if not r then return false, "storage-unavailable" end
  if r[rec.id] then
    local cargo, reason = M.get(worker, rec)
    return cargo ~= nil and count(cargo.inventory, rec.station_item) == 1,
      cargo and "already-carried" or reason
  end
  if not (valid(worker and worker.station) and valid(worker.priest)
      and worker.priest.unit_number and near(worker.priest.position, worker.station.position)) then
    return false, "priest-not-at-physical-pickup"
  end
  if not (source and source.valid ~= false and type(source.remove) == "function"
      and type(source.insert) == "function" and type(source.get_item_count) == "function") then
    return false, "source-inventory-unavailable"
  end
  local before = source.get_item_count(rec.station_item)
  if before < 1 then return false, "source-item-missing" end
  if not (game and type(game.create_inventory) == "function") then
    return false, "engine-cargo-inventory-unavailable"
  end
  local ok, bag = pcall(function() return game.create_inventory(1) end)
  if not (ok and valid(bag) and type(bag.insert) == "function"
      and type(bag.remove) == "function" and count(bag, rec.station_item) == 0) then
    return false, "engine-cargo-allocation-failed"
  end
  local taken_ok, taken = pcall(function()
    return source.remove({name=rec.station_item,count=1})
  end)
  if not taken_ok or taken ~= 1 then
    discard_empty(bag)
    return false, "physical-source-debit-refused"
  end
  local inserted_ok, inserted = pcall(function()
    return bag.insert({name=rec.station_item,count=1})
  end)
  if not inserted_ok or inserted ~= 1
      or count(bag, rec.station_item) ~= 1
      or source.get_item_count(rec.station_item) ~= before - 1 then
    -- Preserve any engine item in its actual inventory on a custody fault;
    -- never destroy a nonempty hold or synthesize a replacement.
    local held = count(bag, rec.station_item)
    if held == 0 then
      local refunded_ok, refunded = pcall(function()
        return source.insert({name=rec.station_item,count=1})
      end)
      if refunded_ok and refunded == 1 then
        discard_empty(bag)
        return false, "carrier-debit-refunded"
      end
    end
    r[rec.id] = {
      record_id=rec.id, station_unit=worker.station.unit_number,
      priest_unit=worker.priest.unit_number, item=rec.station_item,
      surface=worker.station.surface, force=worker.station.force,
      inventory=bag, status="custody-error", started_tick=game.tick
    }
    return false, "carrier-item-custody-error"
  end
  r[rec.id] = {
    record_id=rec.id, station_unit=worker.station.unit_number,
    priest_unit=worker.priest.unit_number, item=rec.station_item,
    surface=worker.station.surface, force=worker.station.force,
    inventory=bag, status="carrying", started_tick=game.tick
  }
  return true, "physically-picked-up"
end
function M.begin_build(worker, rec)
  local cargo, reason = M.get(worker, rec)
  if not cargo then return false, reason end
  if cargo.status ~= "carrying" or not near(worker.priest.position, rec.ghost_position) then
    return false, "carrier-not-at-build-site"
  end
  if count(cargo.inventory, cargo.item) ~= 1 then
    return false, "carrier-item-count-invalid"
  end
  local ok, removed = pcall(function()
    return cargo.inventory.remove({name=cargo.item,count=1})
  end)
  if not ok or removed ~= 1 or count(cargo.inventory,cargo.item) ~= 0 then
    return false, "carrier-build-debit-refused"
  end
  cargo.status = "building"
  return true, "carrier-item-debited"
end
function M.build_failed(worker, rec)
  local cargo, reason = M.get(worker, rec)
  if not cargo then return false, reason end
  if cargo.status ~= "building" then return false, "not-building" end
  if count(cargo.inventory,cargo.item) ~= 0 then return false, "carrier-refund-precondition" end
  local ok, inserted = pcall(function()
    return cargo.inventory.insert({name=cargo.item,count=1})
  end)
  if not ok or inserted ~= 1 or count(cargo.inventory,cargo.item) ~= 1 then
    cargo.status = "custody-error"
    return false, "carrier-build-refund-failed"
  end
  cargo.status = "carrying"
  return true, "carrier-refunded"
end
function M.complete(worker, rec)
  local cargo, reason = M.get(worker, rec)
  if not cargo then return false, reason end
  if cargo.status ~= "building" or count(cargo.inventory,cargo.item) ~= 0 then
    return false, "carrier-not-consumed"
  end
  discard_empty(cargo.inventory)
  records()[rec.id] = nil
  return true, "real-item-consumed-by-build"
end
-- If the ghost is completed by somebody else, walk the item home and put it
-- back in the *real* source inventory. Never silently delete carried stock.
function M.return_unused(worker, rec, source)
  local cargo, reason = M.get(worker, rec)
  if not cargo then return false, reason end
  if cargo.status ~= "carrying" then return false, "carrier-not-returnable" end
  if not near(worker.priest.position, worker.station.position) then
    return false, "priest-not-at-physical-return"
  end
  if not (source and source.valid ~= false and type(source.insert) == "function"
      and type(source.get_item_count) == "function"
      and type(source.get_insertable_count) == "function") then
    return false, "return-inventory-unavailable"
  end
  if source.get_insertable_count(cargo.item) < 1 then return false, "return-inventory-full" end
  if count(cargo.inventory,cargo.item) ~= 1 then return false, "return-cargo-count-invalid" end
  local before = source.get_item_count(cargo.item)
  local removed = cargo.inventory.remove({name=cargo.item,count=1})
  if removed ~= 1 then return false, "return-cargo-debit-refused" end
  local ok, inserted = pcall(function() return source.insert({name=cargo.item,count=1}) end)
  -- An inventory callback may throw AFTER the real item has been inserted.
  -- Read back physical stock before considering a refund; never create two.
  local observed_ok, observed = pcall(function()
    return source.get_item_count(cargo.item)
  end)
  if not observed_ok or observed ~= before+1 then
    if observed_ok and observed == before then
      local refund_ok, refund = pcall(function()
        return cargo.inventory.insert({name=cargo.item,count=1})
      end)
      if refund_ok and refund == 1 and count(cargo.inventory,cargo.item) == 1 then
        return false, "return-item-refunded-to-carrier"
      end
    end
    cargo.status = "custody-error"
    return false, "return-item-custody-error"
  end
  -- Readback, not a callback return value, proves the item arrived.
  -- 'inserted' may be unavailable after a post-insert exception.
  discard_empty(cargo.inventory)
  records()[rec.id] = nil
  return true, "physically-returned"
end
_G.TechPriestsStationCargo0824 = M
return M
