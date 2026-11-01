-- 1048: counted, co-located station-stock evacuation before staffed mining.
-- No remote withdrawal: worker must reach BOTH real stations. A real engine
-- LuaItemStack.transfer_stack is the only material mutation; it preserves
-- quality, durability, ammo and stack metadata. Distant recovery is unchanged.
local Recovery=require("scripts.core.station_recycling_0822")
local M={version="0.1.674-dev.1048"}
local function valid(e) return e and e.valid end
local function near(a,b)
  return a and b and (a.x-b.x)^2+(a.y-b.y)^2<=25
end
local function records()
  local tp=storage and storage.tech_priests
  if not tp then return nil end
  tp.station_inventory_evacuation_1048=tp.station_inventory_evacuation_1048 or {}
  return tp.station_inventory_evacuation_1048
end
local function sources(pair)
  local get=rawget(_G,"tech_priests_0358_station_sources_for_pair")
  if type(get)~="function" then return nil end
  local ok,list=pcall(get,pair)
  if not ok or type(list)~="table" or #list==0 then return nil end
  local seen={}
  for _,slot in ipairs(list) do
    local inv=slot and slot.inv
    if slot.owner~=pair.station or not valid(inv) or seen[inv]
        or type(inv.get_contents)~="function" then return nil end
    seen[inv]=true
  end
  return list
end
local function read(slot)
  if not(slot and slot.valid) then return nil,nil,nil end
  if not slot.valid_for_read then return 0,nil,nil end
  local ok,n,name,quality=pcall(function()
    return slot.count,slot.name,slot.quality
  end)
  if not(ok and type(n)=="number" and n>0 and type(name)=="string") then
    return nil,nil,nil
  end
  return n,name,quality and (type(quality)=="table" and quality.name or quality)
end
local function has_stock(list)
  for _,source in ipairs(list) do
    local inv=source.inv
    local ok,contents=pcall(function() return inv.get_contents() end)
    if not(ok and type(contents)=="table") then return nil end
    for _,entry in pairs(contents) do
      local amount=type(entry)=="table" and tonumber(entry.count) or tonumber(entry)
      if amount==nil then return nil end
      if amount>0 then return true end
    end
  end
  return false
end
local function owns(parent,candidate,rec,entry)
  return entry and entry.writ==rec.id and entry.item==rec.station_item
    and entry.parent_unit==parent.station.unit_number
    and entry.parent_priest==parent.priest.unit_number
    and entry.child_unit==candidate.station.unit_number
    and entry.child_priest==candidate.priest.unit_number
    and entry.force==parent.station.force
    and entry.surface==parent.station.surface
end
function M.service_local(parent,candidate,rec)
  local all=records()
  if not all then return false,"evacuation-storage-unavailable" end
  if not(valid(parent and parent.station) and valid(parent.priest)
      and valid(candidate and candidate.station) and valid(candidate.priest)
      and type(rec)=="table" and rec.id~=nil
      and rec.station_item==candidate.station.name) then
    return false,"evacuation-pair-or-writ-invalid"
  end
  local id=candidate.station.unit_number
  local entry=all[id]
  if entry and not owns(parent,candidate,rec,entry) then
    return false,"evacuation-existing-writ-or-priest-mismatch"
  end
  local from_sources=sources(candidate)
  if not from_sources then return false,"evacuation-source-unobservable" end
  local occupied=has_stock(from_sources)
  if occupied==nil then return false,"evacuation-source-unobservable" end
  if not occupied and not entry then return true,"no-evacuation-needed" end
  if not(rec.status=="active"
      and rec.worker_station_unit==parent.station.unit_number
      and parent.station.force==candidate.station.force
      and parent.station.surface==candidate.station.surface
      and parent.priest.force==parent.station.force
      and parent.priest.surface==parent.station.surface
      and near(parent.priest.position,parent.station.position)
      and near(parent.priest.position,candidate.station.position)) then
    return false,"evacuation-physical-owner-or-reach-invalid"
  end
  -- Do not migrate into a worker already carrying material or holding
  -- another physical recovery lease. An active safety duty outranks this.
  if parent.dead or parent.recalling or parent.deploying
      or parent.combat_target or parent.repair_target
      or parent.active_task or parent.current_task
      or parent.direct_acquisition_custody_0513
      or parent.machine_logistics_custody_0528
      or parent.inventory_transfer_custody_0687 then
    return false,"evacuation-worker-busy-or-carried-custody"
  end
  local tp=storage.tech_priests
  for _,lease in pairs(tp.station_relocation_0823 or {}) do
    if lease.old_unit==id or lease.worker_unit==parent.station.unit_number then
      return false,"evacuation-other-relocation-lease"
    end
  end
  for _,cargo in pairs(tp.station_cargo_0824 or {}) do
    if cargo.station_unit==parent.station.unit_number
        or cargo.priest_unit==parent.priest.unit_number then
      return false,"evacuation-worker-has-engine-cargo"
    end
  end
  local safe,why=Recovery.check_evacuable_candidate(
    parent,candidate,rec.station_item,rec.id)
  if not safe then return false,why end
  local to_sources=sources(parent)
  if not to_sources then return false,"evacuation-destination-unobservable" end
  if not entry then
    entry={writ=rec.id,item=rec.station_item,
      parent_unit=parent.station.unit_number,
      parent_priest=parent.priest.unit_number,
      child_unit=id,child_priest=candidate.priest.unit_number,
      force=parent.station.force,surface=parent.station.surface,
      moved={},stacks=0,status="evacuating"}
    all[id]=entry
  end
  if not occupied then
    entry.status="ready-to-mine"
    return true,"evacuation-complete"
  end
  entry.status="evacuating"
  local seen={}
  for _,source in ipairs(from_sources) do seen[source.inv]=true end
  for _,dest in ipairs(to_sources) do
    if seen[dest.inv] then
      entry.status="custody-error"
      return false,"evacuation-shared-inventory"
    end
  end
  -- One stack per tick bounds work and makes save/reload reconciliation
  -- depend solely on the persisted real source/destination inventories.
  for _,source in ipairs(from_sources) do
    local inv=source.inv
    for i=1,#inv do
      local from=inv[i]
      local amount,item,quality=read(from)
      if amount==nil then
        entry.status="custody-error"
        return false,"evacuation-source-stack-unobservable"
      end
      if amount>0 then
        for _,dest in ipairs(to_sources) do
          for j=1,#dest.inv do
            local to=dest.inv[j]
            local before_to=read(to)
            if before_to==nil then
              entry.status="custody-error"
              return false,"evacuation-destination-stack-unobservable"
            end
            if before_to==0 and type(to.transfer_stack)=="function" then
              local ok=pcall(function() return to.transfer_stack(from,amount) end)
              local left,left_item=read(from)
              local arrived,arrived_item,arrived_quality=read(to)
              if left==nil or arrived==nil or left+arrived~=amount
                  or (left>0 and left_item~=item)
                  or (arrived>0 and (arrived_item~=item
                    or arrived_quality~=quality)) then
                entry.status="custody-error"
                return false,"evacuation-transfer-custody-unverifiable"
              end
              if arrived>0 then
                entry.stacks=entry.stacks+1
                entry.moved[item]=(entry.moved[item] or 0)+arrived
                entry.last_tick=game and game.tick or 0
                -- Even a post-mutation callback exception cannot duplicate
                -- an item: only the native stack readback counts.
                return false,"evacuation-stack-moved"
              end
              if not ok then
                return false,"evacuation-engine-transfer-refused"
              end
            end
          end
        end
        return false,"evacuation-parent-inventory-full"
      end
    end
  end
  entry.status="custody-error"
  return false,"evacuation-source-changed-during-transfer"
end
function M.complete_local(rec,old_unit)
  local all=records()
  local entry=all and all[old_unit]
  if not entry then return true end
  if entry.writ~=rec.id or entry.status~="ready-to-mine" then return false end
  rec.inventory_evacuation_1048={
    source_station_unit=old_unit,parent_station_unit=entry.parent_unit,
    original_priest_unit=entry.child_priest,
    item_counts=entry.moved,stack_transfers=entry.stacks,
    completed_tick=game and game.tick or 0
  }
  all[old_unit]=nil
  return true
end

-- 1051: distant stock must travel inside an engine-owned LuaInventory held
-- by the actual walking parent priest. No station-to-station transfer occurs
-- unless that priest is physically at the source or destination.
function M.remote_record(candidate)
  local tp=storage and storage.tech_priests
  local id=valid(candidate and candidate.station) and candidate.station.unit_number
  return id and tp and tp.station_inventory_evacuation_1048
    and tp.station_inventory_evacuation_1048[id] or nil
end
local function remote_move(parent,entry,destination,phase,issue_command)
  if near(parent.priest.position,destination) then return true end
  if not(issue_command and defines and defines.command
      and defines.distraction) then
    return false,"evacuation-movement-authority-unavailable"
  end
  local now=game and game.tick or 0
  if entry.travel_phase~=phase then
    entry.travel_phase,entry.travel_started_tick=phase,now
  end
  if now-(entry.travel_started_tick or now)>60*120 then
    return false,"evacuation-physical-travel-timeout"
  end
  local ok,issued=pcall(issue_command,parent.priest,{
    type=defines.command.go_to_location,destination=destination,
    radius=2,distraction=defines.distraction.none})
  if not ok or issued==false then
    return false,"evacuation-movement-command-refused"
  end
  entry.status=phase
  return false,phase
end
local function remote_worker_safe(parent,candidate,rec)
  if not(valid(parent and parent.station) and valid(parent.priest)
      and valid(candidate and candidate.station) and valid(candidate.priest)
      and type(rec)=="table" and rec.id~=nil
      and rec.status=="active"
      and rec.worker_station_unit==parent.station.unit_number
      and rec.station_item==candidate.station.name
      and parent.station.force==candidate.station.force
      and parent.station.surface==candidate.station.surface
      and parent.priest.force==parent.station.force
      and parent.priest.surface==parent.station.surface) then
    return false,"evacuation-physical-owner-invalid"
  end
  if parent.dead or parent.recalling or parent.deploying
      or parent.combat_target or parent.repair_target
      or parent.direct_acquisition_custody_0513
      or parent.machine_logistics_custody_0528
      or parent.inventory_transfer_custody_0687 then
    return false,"evacuation-worker-busy-or-carried-custody"
  end
  local tp=storage.tech_priests
  for _,lease in pairs(tp.station_relocation_0823 or {}) do
    if lease.old_unit==candidate.station.unit_number
        or lease.worker_unit==parent.station.unit_number then
      return false,"evacuation-other-relocation-lease"
    end
  end
  for _,cargo in pairs(tp.station_cargo_0824 or {}) do
    if cargo.station_unit==parent.station.unit_number
        or cargo.priest_unit==parent.priest.unit_number then
      return false,"evacuation-worker-has-engine-cargo"
    end
  end
  return Recovery.check_evacuable_candidate(
    parent,candidate,rec.station_item,rec.id)
end
function M.service_remote(parent,candidate,rec,issue_command)
  local all=records()
  if not all then return false,"evacuation-storage-unavailable" end
  local safe,why=remote_worker_safe(parent,candidate,rec)
  if not safe then return false,why end
  local id=candidate.station.unit_number
  local entry=all[id]
  if entry and not owns(parent,candidate,rec,entry) then
    return false,"evacuation-existing-writ-or-priest-mismatch"
  end
  if entry and entry.status=="custody-error" then
    return false,"evacuation-custody-error"
  end
  local from_sources=sources(candidate)
  local to_sources=sources(parent)
  if not(from_sources and to_sources) then
    return false,"evacuation-inventory-authority-unobservable"
  end
  local occupied=has_stock(from_sources)
  if occupied==nil then return false,"evacuation-source-unobservable" end
  if not occupied and not entry then return true,"no-evacuation-needed" end
  local seen={}
  for _,source in ipairs(from_sources) do seen[source.inv]=true end
  for _,dest in ipairs(to_sources) do
    if seen[dest.inv] then return false,"evacuation-shared-inventory" end
  end
  -- A new hold may be created ONLY beside the real source station.
  if not entry then
    if not near(parent.priest.position,candidate.station.position) then
      return false,"evacuation-worker-not-at-source"
    end
    if not(game and type(game.create_inventory)=="function") then
      return false,"evacuation-engine-inventory-unavailable"
    end
    local ok,bag=pcall(function() return game.create_inventory(1) end)
    if not(ok and valid(bag) and #bag==1 and read(bag[1])==0) then
      return false,"evacuation-engine-inventory-refused"
    end
    entry={writ=rec.id,item=rec.station_item,
      parent_unit=parent.station.unit_number,
      parent_priest=parent.priest.unit_number,
      child_unit=id,child_priest=candidate.priest.unit_number,
      force=parent.station.force,surface=parent.station.surface,
      bag=bag,moved={},stacks=0,status="at-source"}
    all[id]=entry
  end
  local bag=entry.bag
  if not(valid(bag) and #bag==1) then
    entry.status="custody-error"
    return false,"evacuation-carried-inventory-missing"
  end
  local amount,item,quality=read(bag[1])
  if amount==nil then
    entry.status="custody-error"
    return false,"evacuation-carried-stack-unobservable"
  end
  if amount>0 then
    local arrived,reason=remote_move(parent,entry,
      parent.station.position,"evacuation-carrying-to-parent",issue_command)
    if not arrived then return false,reason end
    for _,dest in ipairs(to_sources) do
      for j=1,#dest.inv do
        local slot=dest.inv[j]
        local before=read(slot)
        if before==nil then
          entry.status="custody-error"
          return false,"evacuation-parent-stack-unobservable"
        end
        if before==0 and type(slot.transfer_stack)=="function" then
          local ok=pcall(function() return slot.transfer_stack(bag[1],amount) end)
          local remaining=read(bag[1])
          local received,received_item,received_quality=read(slot)
          if remaining==nil or received==nil
              or remaining+received~=amount
              or (received>0 and (received_item~=item
                or received_quality~=quality)) then
            entry.status="custody-error"
            return false,"evacuation-delivery-custody-unverifiable"
          end
          if received>0 then
            entry.moved[item]=(entry.moved[item] or 0)+received
            entry.stacks=entry.stacks+1
            entry.status="evacuation-returning-to-child"
            entry.travel_phase=nil
            entry.last_tick=game and game.tick or 0
            return false,"evacuation-counted-parent-deposit"
          end
          if not ok then return false,"evacuation-engine-deposit-refused" end
        end
      end
    end
    return false,"evacuation-parent-inventory-full"
  end
  local arrived,reason=remote_move(parent,entry,
    candidate.station.position,"evacuation-returning-to-child",issue_command)
  if not arrived then return false,reason end
  entry.travel_phase=nil
  if not occupied then
    entry.status="ready-to-mine"
    return true,"evacuation-complete"
  end
  if entry.status=="ready-to-mine" then
    entry.status="custody-error"
    return false,"evacuation-source-refilled-after-ready"
  end
  for _,source in ipairs(from_sources) do
    for i=1,#source.inv do
      local from=source.inv[i]
      local n,name,q=read(from)
      if n==nil then
        entry.status="custody-error"
        return false,"evacuation-source-stack-unobservable"
      end
      if n>0 then
        local ok=pcall(function() return bag[1].transfer_stack(from,n) end)
        local left=read(from)
        local carried,carried_item,carried_quality=read(bag[1])
        if left==nil or carried==nil or left+carried~=n
            or (carried>0 and (carried_item~=name
              or carried_quality~=q)) then
          entry.status="custody-error"
          return false,"evacuation-pickup-custody-unverifiable"
        end
        if carried>0 then
          entry.status="evacuation-carrying-to-parent"
          entry.last_tick=game and game.tick or 0
          return false,"evacuation-counted-source-pickup"
        end
        return false,ok and "evacuation-pickup-refused"
          or "evacuation-engine-pickup-refused"
      end
    end
  end
  entry.status="custody-error"
  return false,"evacuation-source-changed-during-pickup"
end
function M.complete_remote(rec,old_unit)
  local all=records()
  local entry=all and all[old_unit]
  if not entry then return true end
  if entry.writ~=rec.id or entry.status~="ready-to-mine"
      or not(valid(entry.bag) and #entry.bag==1
        and read(entry.bag[1])==0) then return false end
  local ok=pcall(function() entry.bag.destroy() end)
  if not ok or entry.bag.valid then
    entry.status="custody-error"
    return false
  end
  rec.inventory_evacuation_1048={
    source_station_unit=old_unit,parent_station_unit=entry.parent_unit,
    original_priest_unit=entry.child_priest,
    item_counts=entry.moved,stack_transfers=entry.stacks,
    completed_tick=game and game.tick or 0,physical_carrier=true}
  all[old_unit]=nil
  return true
end
return M
