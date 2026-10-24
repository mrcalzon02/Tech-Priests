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
-- Reserve a *real* empty engine inventory before physically mining a staffed
-- subordinate station. The recovery lease owns the actual LuaEntity.mine
-- mutation; this module only tracks item custody on the walking worker.
function M.reserve_recovery(worker, rec)
  local r = records()
  if not r then return false, "storage-unavailable" end
  if r[rec.id] then return false, "cargo-already-reserved" end
  if not (valid(worker and worker.station) and valid(worker.priest)
      and worker.priest.unit_number) then
    return false, "recovery-worker-invalid"
  end
  if not (game and type(game.create_inventory) == "function") then
    return false, "engine-cargo-inventory-unavailable"
  end
  local ok, bag = pcall(function() return game.create_inventory(1) end)
  if not (ok and valid(bag) and type(bag.get_item_count) == "function"
      and type(bag.remove) == "function" and type(bag.insert) == "function"
      and count(bag, rec.station_item) == 0) then
    return false, "engine-recovery-cargo-allocation-failed"
  end
  r[rec.id] = {
    record_id=rec.id, station_unit=worker.station.unit_number,
    priest_unit=worker.priest.unit_number, item=rec.station_item,
    surface=worker.station.surface, force=worker.station.force,
    inventory=bag, status="recovering", started_tick=game.tick
  }
  return true, bag
end
function M.confirm_recovery(worker, rec)
  local cargo, reason = M.get(worker, rec)
  if not cargo then return false, reason end
  if cargo.status ~= "recovering" then return false, "not-recovering" end
  if count(cargo.inventory, cargo.item) ~= 1 then
    cargo.status = "custody-error"
    return false, "mined-item-count-invalid"
  end
  cargo.status = "carrying"
  return true, "physical-recovery-carried"
end
function M.abort_recovery(worker, rec)
  local cargo, reason = M.get(worker, rec)
  if not cargo then return false, reason end
  if cargo.status ~= "recovering" then return false, "not-recovering" end
  if count(cargo.inventory, cargo.item) ~= 0 then
    cargo.status = "custody-error"
    return false, "recovery-hold-not-empty"
  end
  discard_empty(cargo.inventory)
  records()[rec.id] = nil
  return true, "empty-recovery-aborted"
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
  -- Factorio callbacks can fail after a physical mutation. The real source
  -- count, not the callback result, determines whether an item was removed.
  local after_ok, after = pcall(function()
    return source.get_item_count(rec.station_item)
  end)
  if after_ok and after == before then
    discard_empty(bag)
    return false, "physical-source-debit-refused"
  end
  if not after_ok or after ~= before - 1 then
    r[rec.id] = {
      record_id=rec.id, station_unit=worker.station.unit_number,
      priest_unit=worker.priest.unit_number, item=rec.station_item,
      surface=worker.station.surface, force=worker.station.force,
      inventory=bag, status="custody-error", started_tick=game.tick
    }
    return false, "physical-source-debit-unverifiable"
  end
  local inserted_ok, inserted = pcall(function()
    return bag.insert({name=rec.station_item,count=1})
  end)
  if count(bag, rec.station_item) ~= 1 then
    -- Preserve any engine item in its actual inventory on a custody fault;
    -- never destroy a nonempty hold or synthesize a replacement.
    local held = count(bag, rec.station_item)
    if held == 0 then
      local refunded_ok, refunded = pcall(function()
        return source.insert({name=rec.station_item,count=1})
      end)
      -- A post-insert callback exception is not a failed refund. Read the
      -- physical source count before retaining an empty orphan cargo hold.
      local read_ok, read_count = pcall(function()
        return source.get_item_count(rec.station_item)
      end)
      if read_ok and read_count == before and count(bag, rec.station_item) == 0 then
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
  -- A Factorio callback can throw after consuming the real item. The
  -- observed engine inventory, not the Lua return value, decides whether
  -- the build debit happened. Never consume the same item twice.
  local after = count(cargo.inventory, cargo.item)
  if after == 0 then
    cargo.status = "building"
    return true, "carrier-item-debited"
  end
  if after == 1 then return false, "carrier-build-debit-refused" end
  cargo.status = "custody-error"
  return false, "carrier-build-debit-unverifiable"
end
function M.build_failed(worker, rec)
  local cargo, reason = M.get(worker, rec)
  if not cargo then return false, reason end
  if cargo.status ~= "building" then return false, "not-building" end
  if count(cargo.inventory,cargo.item) ~= 0 then return false, "carrier-refund-precondition" end
  local ok, inserted = pcall(function()
    return cargo.inventory.insert({name=cargo.item,count=1})
  end)
  local after = count(cargo.inventory, cargo.item)
  if after == 1 then
    cargo.status = "carrying"
    return true, "carrier-refunded"
  end
  -- A rejected insert leaves the build debit pending so a later service
  -- may retry the physical refund. Unknown stock is quarantined.
  if after == 0 then return false, "carrier-build-refund-refused" end
  cargo.status = "custody-error"
  return false, "carrier-build-refund-unverifiable"
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
  local before = count(source, cargo.item)
  if before == nil then return false, "return-source-count-unavailable" end
  local removed_ok, removed = pcall(function()
    return cargo.inventory.remove({name=cargo.item,count=1})
  end)
  local held_after = count(cargo.inventory, cargo.item)
  if held_after == 1 then return false, "return-cargo-debit-refused" end
  if held_after ~= 0 then
    cargo.status = "custody-error"
    return false, "return-cargo-debit-unverifiable"
  end
  local ok, inserted = pcall(function() return source.insert({name=cargo.item,count=1}) end)
  -- Readback also handles an exception AFTER either inventory mutation.
  local observed = count(source, cargo.item)
  if observed ~= before+1 then
    if observed == before then
      local refund_ok, refund = pcall(function()
        return cargo.inventory.insert({name=cargo.item,count=1})
      end)
      if count(cargo.inventory,cargo.item) == 1 then
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

-- Death-site salvage retains the original engine inventory. Reassignment is
-- permitted only after a successor physically reaches the last known location.
-- An empty or ambiguous hold is quarantined, never synthetically refunded.
local function copy_position(pos)
  if not pos then return nil end
  local ok,x,y=pcall(function() return pos.x,pos.y end)
  if not ok or type(x)~="number" or type(y)~="number" then return nil end
  return {x=x,y=y}
end
function M.observe_carrier(worker,rec)
  local cargo,reason=M.get(worker,rec)
  if not cargo then return false,reason end
  if cargo.status~="carrying" and cargo.status~="recovering"
      and cargo.status~="building" then return false,"carrier-not-mobile" end
  local pos=copy_position(worker.priest.position)
  if not pos then return false,"carrier-position-unavailable" end
  cargo.last_position=pos
  return true,"carrier-position-observed"
end
function M.note_priest_lost(pair,dead_priest)
  local r=records()
  local station=valid(pair and pair.station) and pair.station.unit_number or nil
  -- Factorio death callbacks may leave an invalid LuaEntity reference in
  -- pair.priest. Even checking its unit_number, position or surface raises an
  -- engine exception. The last observed primitive unit and cargo position
  -- remain authoritative until a new priest physically reclaims the item.
  local function dead_field(field)
    if not dead_priest then return nil end
    local ok,value=pcall(function() return dead_priest[field] end)
    return ok and value or nil
  end
  local priest_unit=dead_field("unit_number") or (pair and pair.priest_unit)
  if not (r and station and priest_unit) then return 0 end
  local death_pos=copy_position(dead_field("position"))
  local death_surface=dead_field("surface")
  local marked=0
  for _,cargo in pairs(r) do
    if cargo.station_unit==station and cargo.priest_unit==priest_unit
        and cargo.status~="stranded" and cargo.status~="custody-error" then
      local site=death_pos or cargo.last_position
      if cargo.status=="carrying" and count(cargo.inventory,cargo.item)==1
          and site and (not death_surface or death_surface==cargo.surface) then
        cargo.status="stranded"
        cargo.stranded_position=site
      else
        cargo.status="custody-error"
      end
      cargo.lost_priest_unit=priest_unit
      cargo.lost_tick=game and game.tick or 0
      marked=marked+1
    end
  end
  return marked
end
function M.stranded_for(worker,rec)
  local r=records()
  local cargo=r and rec and r[rec.id]
  if not cargo or cargo.status~="stranded" then return nil,"no-stranded-cargo" end
  if not (valid(worker and worker.station) and valid(worker.priest)
      and cargo.station_unit==worker.station.unit_number
      and cargo.surface==worker.station.surface
      and cargo.force==worker.station.force
      and cargo.record_id==rec.id and cargo.item==rec.station_item
      and cargo.priest_unit~=worker.priest.unit_number) then
    return nil,"stranded-cargo-owner-mismatch"
  end
  if count(cargo.inventory,cargo.item)~=1 then
    cargo.status="custody-error"
    return nil,"stranded-cargo-count-invalid"
  end
  if not cargo.stranded_position then return nil,"stranded-site-unavailable" end
  return cargo.stranded_position
end
function M.reclaim_stranded(worker,rec)
  local site,reason=M.stranded_for(worker,rec)
  if not site then return false,reason end
  if not near(worker.priest.position,site) then
    return false,"replacement-priest-not-at-death-site"
  end
  local cargo=records()[rec.id]
  cargo.priest_unit=worker.priest.unit_number
  cargo.status="carrying"
  cargo.last_position=copy_position(worker.priest.position)
  cargo.stranded_position=nil
  cargo.reclaimed_tick=game and game.tick or 0
  return true,"physical-death-site-cargo-reclaimed"
end
_G.TechPriestsStationCargo0824 = M
return M
