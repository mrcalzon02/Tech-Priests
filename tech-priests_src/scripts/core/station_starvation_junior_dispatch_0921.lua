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
return M
