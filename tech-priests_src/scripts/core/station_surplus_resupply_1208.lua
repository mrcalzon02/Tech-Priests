-- 1208: physical one-item Cogitator surplus relay between nearby station
-- inventories. The receiver's ORIGINAL priest walks to the donor and back.
-- No remote inventory credit, fabricated priest, free station or teleport.
-- This module never places ghosts: native 0256 owns station construction.
local M={version="0.1.674-dev.1208",reach_sq=16,max_distance=48,
  donor_keep=1,move_retry_ticks=120}
local function valid(v) return v and v.valid end
local function now() return game and game.tick or 0 end
local function dist2(a,b)
  if not(a and b and type(a.x)=="number" and type(b.x)=="number"
    and type(a.y)=="number" and type(b.y)=="number") then
    return math.huge
  end
  return (a.x-b.x)^2+(a.y-b.y)^2
end
local function same(a,b)
  return a and b and (a==b or
    (type(a.index)=="number" and type(b.index)=="number"
      and a.index==b.index))
end
local function pair_map()
  return storage and storage.tech_priests
    and storage.tech_priests.pairs_by_station or {}
end
local function chest(pair)
  if not(valid(pair and pair.station) and defines and defines.inventory
      and defines.inventory.chest
      and type(pair.station.get_inventory)=="function") then return nil end
  local ok,inv=pcall(function()
    return pair.station.get_inventory(defines.inventory.chest)
  end)
  if ok and valid(inv) and type(inv.get_item_count)=="function"
      and type(inv.remove)=="function" and type(inv.insert)=="function"
      and type(inv.get_insertable_count)=="function" then return inv end
end
local function count(inv,item)
  if not valid(inv) then return nil end
  local ok,n=pcall(function() return inv.get_item_count(item) end)
  return ok and type(n)=="number" and n or nil
end
local function committed(pair,rec)
  return valid(pair and pair.station) and valid(pair.priest)
    and type(rec)=="table" and rec.status=="active"
    and rec.worker_station_unit==pair.station.unit_number
    and rec.station_item==rec.station_entity
    and type(rec.station_item)=="string"
    and pair_map()[pair.station.unit_number]==pair
end
local function available_donor(donor,item)
  local inv=chest(donor)
  local observed=count(inv,item)
  if not observed then return nil,0 end
  local courier=rawget(_G,"TechPriestsResourceReturnCourier0837")
  local spendable=observed
  if courier then
    if type(courier.spendable_station_item)~="function" then
      return nil,0
    end
    local ok,n=pcall(courier.spendable_station_item,donor,item,observed)
    if not(ok and tonumber(n)) then return nil,0 end
    spendable=math.min(observed,tonumber(n))
  end
  local tp=storage and storage.tech_priests
  local busy=tp and tp.station_expansion_by_worker_0256
    and tp.station_expansion_by_worker_0256[donor.station.unit_number]
  local floor=M.donor_keep+(busy and 1 or 0)
  return inv,math.max(0,math.floor(spendable)-floor)
end
function M.find_donor(worker,item)
  if not(valid(worker and worker.station) and valid(worker.priest)
      and type(item)=="string" and item~="") then
    return nil,"invalid-resupply-request"
  end
  local radius=tonumber(worker.radius) or 24
  if type(_G.refresh_pair_radius)=="function" then
    local ok,r=pcall(_G.refresh_pair_radius,worker)
    if ok and tonumber(r) then radius=tonumber(r) end
  end
  local max_dist=math.min(M.max_distance,math.max(0,radius-2))
  if max_dist<4 then return nil,"no-nearby-coverage-corridor" end
  local best,best_d2=nil,nil
  for _,donor in pairs(pair_map()) do
    if donor~=worker and valid(donor and donor.station)
        and valid(donor.priest)
        and same(donor.station.force,worker.station.force)
        and same(donor.station.surface,worker.station.surface)
        and donor.station.unit_number~=worker.station.unit_number then
      local d2=dist2(donor.station.position,worker.station.position)
      if d2<=max_dist^2 then
        local _,spare=available_donor(donor,item)
        if spare>0 and (not best_d2 or d2<best_d2
          or (d2==best_d2
            and donor.station.unit_number<best.station.unit_number)) then
          best,best_d2=donor,d2
        end
      end
    end
  end
  return best,best and "physical-surplus-source" or "no-unreserved-local-surplus"
end
function M.has_record(worker,rec)
  local s=worker and worker.station_surplus_resupply_1208
  if not s then return false end
  return rec==nil or s.record_id==rec.id
end
local function move(worker,record,destination,leg)
  if now()<(record.next_move_tick or 0) then return false,"movement-retry-backoff" end
  local fn=rawget(_G,"tech_priests_request_movement_0418")
  if type(fn)~="function" then return false,"canonical-movement-unavailable" end
  local ok,accepted,why=pcall(fn,worker,destination,
    "station-surplus-"..leg.."-1208",
    {owner="station-surplus-relay-1208",priority=72,ttl=600,radius=2,
     distraction=defines and defines.distraction
       and defines.distraction.none or nil})
  record.next_move_tick=now()+M.move_retry_ticks
  if not ok then return false,"canonical-movement-error" end
  return accepted==true,accepted==true and "physical-movement-requested"
    or tostring(why or "physical-movement-refused")
end
function M.authorized_movement(worker,req)
  local s=worker and worker.station_surplus_resupply_1208
  if not(s and type(req)=="table"
      and req.owner=="station-surplus-relay-1208"
      and valid(worker.station) and valid(worker.priest)
      and s.worker_station_unit==worker.station.unit_number
      and s.worker_priest_unit==worker.priest.unit_number
      and pair_map()[s.worker_station_unit]==worker
      and valid(s.bag) and s.item and s.record_id) then return false end
  local tp=storage and storage.tech_priests
  local rec=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[s.record_id]
  if not committed(worker,rec) or rec.station_item~=s.item then return false end
  local donor=pair_map()[s.donor_station_unit]
  if not(valid(donor and donor.station) and valid(donor.priest)
      and same(donor.station.force,worker.station.force)
      and same(donor.station.surface,worker.station.surface)) then return false end
  local leg=s.phase=="to-source" and "pickup"
    or s.phase=="to-home" and "return"
  local place=leg=="pickup" and donor.station.position
    or leg=="return" and worker.station.position
  local bag_count=count(s.bag,s.item)
  if not(place and bag_count==(leg=="pickup" and 0 or 1)
      and req.reason=="station-surplus-"..leg.."-1208")then return false end
  return dist2(place,req.ground_route_final_destination or req)<=4
end
function M.service(worker,rec)
  if not committed(worker,rec) then return false,"no-valid-expansion-writ" end
  local s=worker.station_surplus_resupply_1208
  if not s then
    local home=chest(worker)
    if not home or count(home,rec.station_item)~=0 then
      return false,"receiver-not-empty-or-unobservable"
    end
    local donor,why=M.find_donor(worker,rec.station_item)
    if not donor then return false,why end
    if not(game and type(game.create_inventory)=="function") then
      return false,"engine-owned-cargo-unavailable"
    end
    local ok,bag=pcall(function() return game.create_inventory(1) end)
    if not(ok and valid(bag) and count(bag,rec.station_item)==0) then
      return false,"engine-owned-cargo-invalid"
    end
    s={record_id=rec.id,item=rec.station_item,worker_station_unit=
      worker.station.unit_number,worker_priest_unit=worker.priest.unit_number,
      donor_station_unit=donor.station.unit_number,bag=bag,
      phase="to-source",started_tick=now()}
    worker.station_surplus_resupply_1208=s
  end
  if s.record_id~=rec.id or s.item~=rec.station_item
      or s.worker_station_unit~=worker.station.unit_number
      or s.worker_priest_unit~=worker.priest.unit_number
      or not valid(s.bag) then return true,"surplus-custody-quarantined" end
  local donor=pair_map()[s.donor_station_unit]
  if not(valid(donor and donor.station) and valid(donor.priest)
      and same(donor.station.force,worker.station.force)
      and same(donor.station.surface,worker.station.surface)) then
    return true,"donor-pair-or-domain-changed"
  end
  local donor_inv,spare=available_donor(donor,s.item)
  local bag_n=count(s.bag,s.item)
  if s.phase=="to-source" and bag_n==0 then
    if dist2(worker.priest.position,donor.station.position)>M.reach_sq then
      local ok,why=move(worker,s,donor.station.position,"pickup")
      return true,ok and "surplus-moving-to-physical-source" or why
    end
    if not donor_inv or spare<1 then return true,"donor-surplus-reserved-or-depleted" end
    local before=count(donor_inv,s.item)
    local removed=donor_inv.remove({name=s.item,count=1})
    if removed~=1 or count(donor_inv,s.item)~=before-1 then
      return true,"donor-physical-debit-refused"
    end
    local accepted=s.bag.insert({name=s.item,count=1})
    if accepted~=1 or count(s.bag,s.item)~=1 then
      local restored=donor_inv.insert({name=s.item,count=1})
      if restored~=1 or count(donor_inv,s.item)~=before then
        s.phase="custody-quarantine"
        return true,"source-to-cargo-custody-disputed"
      end
      return true,"physical-cargo-insert-refused"
    end
    -- Preserve both native inventory observations for later acceptance.
    -- A receipt is evidence of a transfer, never inventory credit itself.
    s.donor_readback_before=before
    s.donor_readback_after=count(donor_inv,s.item)
    s.phase="to-home"
    s.picked_tick=now()
    return true,"physically-carried-one-station-item"
  end
  if s.phase=="to-home" and bag_n==1 then
    if dist2(worker.priest.position,worker.station.position)>M.reach_sq then
      local ok,why=move(worker,s,worker.station.position,"return")
      return true,ok and "surplus-returning-with-physical-cargo" or why
    end
    local home=chest(worker)
    if not(home and home.get_insertable_count(s.item)>=1) then
      return true,"receiver-engine-inventory-full"
    end
    local before=count(home,s.item)
    if s.bag.remove({name=s.item,count=1})~=1 then
      s.phase="custody-quarantine"
      return true,"carried-item-debit-refused"
    end
    local inserted=home.insert({name=s.item,count=1})
    if inserted~=1 or count(home,s.item)~=before+1 then
      -- No remote credit or false success on an ambiguous partial deposit.
      if inserted~=1 and s.bag.insert({name=s.item,count=1})==1 then
        return true,"receiver-deposit-refused-bag-restored"
      end
      s.phase="custody-quarantine"
      return true,"receiver-deposit-custody-disputed"
    end
    if count(s.bag,s.item)~=0 then
      s.phase="custody-quarantine"
      return true,"received-item-bag-not-empty"
    end
    worker.station_surplus_last_receipt_1208={
      record_id=s.record_id,item=s.item,donor_unit=s.donor_station_unit,
      destination_unit=s.worker_station_unit,quantity=1,
      picked_tick=s.picked_tick,delivered_tick=now(),
      donor_readback_before=s.donor_readback_before,
      donor_readback_after=s.donor_readback_after,
      destination_readback=count(home,s.item)}
    pcall(function()s.bag.destroy()end)
    worker.station_surplus_resupply_1208=nil
    return true,"real-neighbor-surplus-physically-delivered"
  end
  return true,"surplus-custody-quarantined"
end
return M
