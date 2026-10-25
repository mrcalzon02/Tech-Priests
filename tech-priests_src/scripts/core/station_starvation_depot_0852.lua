-- Method I 0852: counted, co-located handoff of a physically recovered
-- station item from its Junior carrier to a protected Magos engine inventory.
-- This is NOT station construction or a claim that the chain is reversed.
local Cargo = require("scripts.core.station_cargo_0824")
local Relocation = require("scripts.core.station_relocation_0823")
local M = {version="0.1.674-dev.0852"}
local function valid(x) return x and x.valid end
local function count(inv,item)
  if not (valid(inv) and type(inv.get_item_count)=="function") then return nil end
  local ok,n=pcall(function() return inv.get_item_count(item) end)
  return ok and type(n)=="number" and n or nil
end
local function near(a,b)
  return a and b and (a.x-b.x)^2+(a.y-b.y)^2<=25
end
local function records()
  local tp=storage and storage.tech_priests
  if not tp then return nil end
  tp.station_reversal_depot_0852=tp.station_reversal_depot_0852 or {}
  return tp.station_reversal_depot_0852
end
local function owns(magos,worker,stage,entry)
  return entry and entry.record_id==stage.id
    and entry.item==stage.station_item
    and entry.magos_station_unit==magos.station.unit_number
    and entry.magos_priest_unit==magos.priest.unit_number
    and entry.worker_station_unit==worker.station.unit_number
    and entry.worker_priest_unit==worker.priest.unit_number
    and entry.leaf_station_unit==stage.leaf_station_unit
    and entry.leaf_priest_unit==stage.leaf_priest_unit
    and entry.force==magos.station.force and entry.surface==magos.station.surface
    and valid(entry.inventory)
end
local function authority(magos,worker,stage)
  if not (valid(magos and magos.station) and valid(magos and magos.priest)
      and valid(worker and worker.station) and valid(worker and worker.priest)
      and type(stage)=="table" and type(stage.id)=="string"
      and stage.station_item=="junior-cogitator-station"
      and stage.worker_station_unit==worker.station.unit_number
      and stage.worker_priest_unit==worker.priest.unit_number
      and stage.id:sub(1,14)=="reversal-leaf:"
      and magos.station.force==worker.station.force
      and magos.station.surface==worker.station.surface) then
    return false,"depot-domain-or-stage-identity-invalid"
  end
  local lease=Relocation.pending_for_record(stage)
  if not (lease and lease.status=="staged" and lease.reversal_leaf_0851
      and lease.old_unit==stage.leaf_station_unit
      and lease.priest_unit==stage.leaf_priest_unit
      and valid(lease.priest) and not (lease.old_station and lease.old_station.valid)
      and lease.worker_unit==worker.station.unit_number) then
    return false,"depot-original-priest-lease-unverified"
  end
  return true
end
function M.get(magos,worker,stage)
  local r=records()
  local entry=r and stage and r[stage.id]
  if not entry then return nil,"no-staged-magos-depot-item" end
  if not owns(magos,worker,stage,entry) then
    return nil,"depot-identity-or-inventory-invalid"
  end
  return entry
end
function M.handoff(magos,worker,stage)
  local ok,reason=authority(magos,worker,stage)
  if not ok then return false,reason end
  local r=records()
  if not r then return false,"depot-storage-unavailable" end
  local entry=r[stage.id]
  if entry and not owns(magos,worker,stage,entry) then
    return false,"depot-identity-or-inventory-invalid"
  end
  if entry and entry.status=="custody-error" then
    return false,"depot-custody-quarantined"
  end
  local cargo=Cargo.get(worker,stage)
  if entry and entry.status=="stored" then
    if count(entry.inventory,stage.station_item)==1
        and not Cargo.has_record(stage) then
      return true,"depot-stored-exactly-once"
    end
    entry.status="custody-error"
    return false,"depot-stored-readback-mismatch"
  end
  -- The worker must actually be at the Magos before any physical debit.
  if not near(worker.priest.position,magos.station.position) then
    return false,"depot-worker-not-at-magos"
  end
  if not (cargo and cargo.status=="carrying") then
    return false,"depot-carrier-custody-unavailable"
  end
  if not entry then
    if count(cargo.inventory,stage.station_item)~=1 then
      return false,"depot-carrier-count-unverified"
    end
    if not (game and type(game.create_inventory)=="function") then
      return false,"depot-engine-inventory-unavailable"
    end
    local made,bag=pcall(function() return game.create_inventory(1) end)
    if not (made and valid(bag) and type(bag.insert)=="function"
        and count(bag,stage.station_item)==0
        and type(bag.is_empty)=="function") then
      return false,"depot-engine-inventory-allocation-refused"
    end
    local empty,yes=pcall(function() return bag.is_empty() end)
    if not empty or yes~=true then
      return false,"depot-new-inventory-not-empty"
    end
    entry={
      record_id=stage.id,item=stage.station_item,
      magos_station_unit=magos.station.unit_number,
      magos_priest_unit=magos.priest.unit_number,
      worker_station_unit=worker.station.unit_number,
      worker_priest_unit=worker.priest.unit_number,
      leaf_station_unit=stage.leaf_station_unit,
      leaf_priest_unit=stage.leaf_priest_unit,
      force=magos.station.force,surface=magos.station.surface,
      inventory=bag,status="receiving",
      started_tick=game.tick
    }
    -- Persist the destination BEFORE debiting the real carrier.
    r[stage.id]=entry
  end
  if entry.status~="receiving" then
    return false,"depot-transaction-state-unavailable"
  end
  local held=count(cargo.inventory,stage.station_item)
  local stored=count(entry.inventory,stage.station_item)
  if held==1 and stored==0 then
    pcall(function() cargo.inventory.remove({name=stage.station_item,count=1}) end)
    held=count(cargo.inventory,stage.station_item)
    if held==0 then
      pcall(function() entry.inventory.insert({name=stage.station_item,count=1}) end)
      held=count(cargo.inventory,stage.station_item)
      stored=count(entry.inventory,stage.station_item)
    end
  end
  if held==0 and stored==1 then
    local released,why=Cargo.release_transferred(worker,stage)
    if not released then return false,"depot-empty-carrier-cleanup:"..tostring(why) end
    entry.status="stored"
    entry.stored_tick=game and game.tick or 0
    return true,"depot-physically-received-one-station-item"
  end
  if held==1 and stored==0 then return false,"depot-carrier-debit-refused" end
  if held==0 and stored==0 then
    -- An insertion may refuse. Restore the *same* item to its original
    -- engine inventory, never synthesize a replacement or a Lua counter.
    pcall(function() cargo.inventory.insert({name=stage.station_item,count=1}) end)
    if count(cargo.inventory,stage.station_item)==1
        and count(entry.inventory,stage.station_item)==0 then
      return false,"depot-insert-refused-item-refunded"
    end
  end
  -- Duplicate, missing or unobservable custody: stop all automated spending.
  entry.status="custody-error"
  cargo.status="custody-error"
  return false,"depot-physical-inventory-deltas-unverifiable"
end
return M
