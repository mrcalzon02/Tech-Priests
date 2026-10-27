-- 0921: reconnect the original Intermediate's first-Junior continuation to
-- the already-existing per-pair tick, after the 0599 sleep governor and all
-- legacy priority wrappers. No independent event handler or work scheduler.
-- A ghost reservation never preempts combat/emergency work or moves an item.
local M={}
function M.install()
  if rawget(_G,"TECH_PRIESTS_TICK_PAIR_BEFORE_JUNIOR_0921") then
    return true
  end
  local previous=rawget(_G,"tick_pair")
  local expansion=rawget(_G,"TECH_PRIESTS_STATION_EXPANSION_0256")
  assert(type(previous)=="function",
    "[Tech-Priests] original per-pair scheduler unavailable for Junior continuation")
  assert(expansion and type(expansion.service_reversal_junior_followup_0921)=="function",
    "[Tech-Priests] original Intermediate continuation authority unavailable")
  _G.TECH_PRIESTS_TICK_PAIR_BEFORE_JUNIOR_0921=previous
  _G.tick_pair=function(pair,...)
    -- Preserve the entire pre-existing priority decision and its result.
    local result=previous(pair,...)
    if pair and type(pair.reversal_junior_followup_0920)=="table" then
      -- The 0919 controller independently checks original priest, root writ,
      -- hierarchy, exact ghost, real station inventories and 120-tick escrow.
      -- It reserves only a physical ghost; it never spends or moves cargo.
      expansion.service_reversal_junior_followup_0921(pair)
    end
    return result
  end
  return true
end

-- 0922: the 2.0.77 engine proved that a persisted Intermediate follow-up can
-- outlive 15,000 ticks without the late per-pair wrapper ever recording a
-- dispatch. Use the ALREADY INSTALLED 0600 broker, not a new event handler.
-- Only active original reversal roots are scanned; the original 0919/0920
-- authority rechecks the real hierarchy, priests, depots and ghost geometry.
-- A persistent rotating cursor prevents a busy Magos from starving others.
function M.service_broker_0922(_,budget)
  local tp=storage and storage.tech_priests
  local index=tp and tp.station_reversal_followup_0911
  local priest_pairs=tp and tp.pairs_by_priest
  local expansion=rawget(_G,"TECH_PRIESTS_STATION_EXPANSION_0256")
  if not(index and priest_pairs and expansion
      and type(expansion.service_reversal_junior_followup_0921)=="function") then
    return {processed=0,waiting=0,detail="junior-broker-no-active-authority"}
  end
  local keys={}
  for station_unit,root_id in pairs(index) do
    if type(station_unit)=="number" and type(root_id)=="number" then
      keys[#keys+1]=station_unit
    end
  end
  table.sort(keys)
  if #keys==0 then
    return {processed=0,detail="junior-broker-no-reversal-roots"}
  end
  local cursor=tp.station_junior_broker_cursor_0922
  local first=1
  if type(cursor)=="number" then
    for i,key in ipairs(keys) do
      if key>cursor then first=i;break end
    end
  end
  local limit=math.min(#keys,math.max(1,math.min(16,
    math.floor(tonumber(budget) or 4))))
  local checked,reserved,waiting,last=0,0,0,nil
  for offset=0,limit-1 do
    local key=keys[((first+offset-1)%#keys)+1]
    last=key
    local root=tp.station_expansion_0256
      and tp.station_expansion_0256[index[key]]
    local stage=root and root.reversal_stage_0854
    local pair=stage and priest_pairs[stage.leaf_priest_unit]
    if type(pair)=="table"
        and type(pair.reversal_junior_followup_0920)=="table" then
      local step=type(root and root.reversal_junior_0919)=="table"
        and root.reversal_junior_0919 or nil
      local child=step and tp.station_expansion_0256
        and tp.station_expansion_0256[step.child_writ_id]
      local follow=type(child and child.reversal_junior_0919)=="table"
        and child.reversal_junior_0919 or nil
      local station=pair.station
      local priest=pair.priest
      -- 0937: Factorio 2.0.77 run 40589519063 created the real Junior
      -- ghost, but the original Intermediate's 0256 worker was never polled
      -- again: its source depot remained 1, carrier absent, and pickup timed
      -- out. Continue the SAME canonical 0256 executor from the already
      -- registered broker. The executor still owns every movement, inventory
      -- debit, original-priest lease and native construction guard.
      local owned_child=root and root.status=="complete"
        and step and step.status=="ghost-reserved"
        and child and child.status=="active"
        and follow and follow.root_writ_id==root.id
        and type(root.reversal_stage_0853)=="table"
        and follow.stage_id==root.reversal_stage_0853.id
        and priest and priest.valid
        and follow.original_intermediate_priest==priest.unit_number
        and follow.magos_station_unit==key
        and step.child_writ_id==child.id
        and step.ghost_unit==child.ghost_unit
        and station and station.valid
        and priest and priest.valid
        and station.name=="intermediate-cogitator-station"
        and tp.pairs_by_station
        and tp.pairs_by_station[station.unit_number]==pair
        and priest_pairs[priest.unit_number]==pair
        and child.worker_station_unit==station.unit_number
        and child.requester_station_unit==station.unit_number
        and tp.station_expansion_by_worker_0256
        and tp.station_expansion_by_worker_0256[station.unit_number]==child.id
      if owned_child then
        -- 0938: 0647 can retain a recipe-only mode and ingredient request
        -- after the original Intermediate is reserved for the first Junior.
        -- Ask the 0647 OWNER to retire ONLY an uncommitted request; a live
        -- physical duty or higher-priority command continues untouched.
        local handoff_reason
        if pair.mode=="infrastructure-material-acquisition-0647" then
          local governor=rawget(_G,"TechPriestsInfrastructureFirstGovernor0640")
          if governor and type(governor.yield_uncommitted_recipe_to_reversal_0938)
              =="function" then
            local ok,_,why=pcall(
              governor.yield_uncommitted_recipe_to_reversal_0938,pair,child)
            handoff_reason=ok and why or "junior-recipe-handoff-exception"
          else
            handoff_reason="junior-recipe-handoff-owner-unavailable"
          end
        end
        -- A broker dispatch cannot bypass active combat, emergency work or
        -- custody: the original 0256/0919 controllers check them again.
        local idle=pair.mode=="idle" and not(pair.dead or pair.recalling
          or pair.deploying)
        for _,field in ipairs({"active_task","current_task","construction_task",
            "build_task","repair_target","combat_target","consecration_target",
            "direct_acquisition_task_0336","active_acquisition_0333",
            "inventory_transfer_custody_0687","station_crafting_task_0337"}) do
          if pair[field]~=nil and pair[field]~=false then idle=false;break end
        end
        local probe=rawget(_G,"tech_priests_0248_higher_priority_probe")
        if idle and type(probe)=="function" then
          local ok,status=pcall(probe,pair)
          idle=ok and type(status)=="table"
            and (status.priority=="idle" or status.priority=="invalid")
        end
        if idle and type(expansion.service_station_expansion_assignment)=="function" then
          local handled,reason=expansion.service_station_expansion_assignment(pair)
          root.reversal_junior_0937_last_reason=reason or child.phase
          root.reversal_junior_0937_last_tick=game and game.tick
          checked=checked+1
          waiting=waiting+1
        else
          root.reversal_junior_0937_last_reason=handoff_reason
            or "junior-broker-priority-deferred"
          root.reversal_junior_0937_last_tick=game and game.tick
          waiting=waiting+1
        end
      else
        -- Before ghost reservation, retain the original audited 0919 path.
        -- Invalid children cannot acquire a new construction authorization.
        local _,reason=expansion.service_reversal_junior_followup_0921(pair)
        checked=checked+1
        if reason=="reversal-first-junior-real-ghost-reserved" then
          reserved=reserved+1
        else
          waiting=waiting+1
        end
      end
    end
  end
  tp.station_junior_broker_cursor_0922=last
  return {processed=limit,acted=reserved,waiting=waiting,
    detail="junior-broker-original-writ-audits="..checked}
end

-- 0924: engine run 40532022133 intermittently reached the rebuilt Senior
-- without ever observing the next Intermediate ghost. The original callback
-- is not a guaranteed recurring scheduler after the Magos goes idle. Reuse
-- the existing 0600 broker to retry ONLY the original audited 0911 ghost
-- reservation; never grant an item, build, rank or priest reattachment here.
-- A completed root with a registered child is deliberately never reissued.
function M.service_intermediate_broker_0924(_,budget)
  local tp=storage and storage.tech_priests
  local index=tp and tp.station_reversal_followup_0911
  local expansion=rawget(_G,"TECH_PRIESTS_STATION_EXPANSION_0256")
  if not(index and tp.pairs_by_station and tp.station_expansion_0256
      and expansion and type(expansion.service_reversal_intermediate_0911)=="function") then
    return {processed=0,acted=0,detail="intermediate-broker-no-active-authority"}
  end
  local keys={}
  for station_unit,root_id in pairs(index) do
    if type(station_unit)=="number" and type(root_id)=="number" then
      keys[#keys+1]=station_unit
    end
  end
  table.sort(keys)
  if #keys==0 then
    return {processed=0,acted=0,detail="intermediate-broker-no-reversal-roots"}
  end
  local cursor=tp.station_intermediate_broker_cursor_0924
  local first=1
  if type(cursor)=="number" then
    for i,key in ipairs(keys) do
      if key>cursor then first=i;break end
    end
  end
  local limit=math.min(#keys,math.max(1,math.min(16,
    math.floor(tonumber(budget) or 4))))
  local checked,reserved,last=0,0,nil
  for offset=0,limit-1 do
    local key=keys[((first+offset-1)%#keys)+1]
    last=key
    local root=tp.station_expansion_0256[index[key]]
    local magos=tp.pairs_by_station[key]
    if root and root.status=="complete" and root.worker_station_unit==key
        and root.reversal_outbound_0895
        and root.reversal_outbound_0895.phase=="senior-build-authorized"
        and root.reversal_stage_0854 and not root.reversal_next_0911
        and magos and magos.station and magos.station.valid
        and magos.station.unit_number==key then
      -- 0911.service performs all live original-priest, hierarchy, real
      -- inventory, lease and forward-site checks. This broker only schedules.
      local _,reason=expansion.service_reversal_intermediate_0911(magos)
      checked=checked+1
      root.reversal_intermediate_0924_last_reason=reason
      root.reversal_intermediate_0924_last_tick=game and game.tick
      if reason=="reversal-intermediate-real-ghost-reserved" then
        reserved=reserved+1
      end
    end
  end
  tp.station_intermediate_broker_cursor_0924=last
  return {processed=limit,acted=reserved,
    detail="intermediate-broker-original-writ-audits="..checked}
end

function M.install_intermediate_broker_0924()
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  assert(broker and type(broker.register_service)=="function",
    "[Tech-Priests] canonical 0600 broker unavailable for Intermediate follow-up")
  local service=broker.register_service{
    name="station-starvation-intermediate-0924",
    category="construction",priority=70,interval=30,
    budget=4,dynamic_budget=false,fn=M.service_intermediate_broker_0924
  }
  assert(service and service.name=="station-starvation-intermediate-0924",
    "[Tech-Priests] canonical Intermediate follow-up registration refused")
  return true
end

function M.install_broker_0922()
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  assert(broker and type(broker.register_service)=="function",
    "[Tech-Priests] canonical 0600 broker unavailable for Junior follow-up")
  local service=broker.register_service{
    name="station-starvation-first-junior-0922",
    category="construction",priority=70,interval=30,
    budget=4,dynamic_budget=false,fn=M.service_broker_0922
  }
  assert(service and service.name=="station-starvation-first-junior-0922",
    "[Tech-Priests] canonical Junior follow-up service registration refused")
  return true
end
return M
