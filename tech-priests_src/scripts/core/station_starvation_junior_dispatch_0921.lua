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
  local dispatched,last=0,nil
  for offset=0,limit-1 do
    local key=keys[((first+offset-1)%#keys)+1]
    last=key
    local root=tp.station_expansion_0256
      and tp.station_expansion_0256[index[key]]
    local stage=root and root.reversal_stage_0854
    local pair=stage and priest_pairs[stage.leaf_priest_unit]
    if pair and type(pair.reversal_junior_followup_0920)=="table" then
      -- Never grant a build, item, hierarchy edge or movement from this
      -- scheduler: this is exactly the already audited 0919 reservation.
      expansion.service_reversal_junior_followup_0921(pair)
      dispatched=dispatched+1
    end
  end
  tp.station_junior_broker_cursor_0922=last
  return {processed=limit,acted=dispatched,
    detail="junior-broker-original-writ-audits="..dispatched}
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
