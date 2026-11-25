-- Release gate for autonomous factory *expansion*, not for repair or
-- machine consecration.  Uses the canonical logistics frustration due tick;
-- no second timer, tick handler, world scan, or synthetic item creation.
local M={version=1}

function M.ready(pair,tick)
  if type(pair)~="table" then return false,"invalid-pair" end
  -- Once the original logistics deadline was reached, the factory may
  -- continue through later steps even if successful supply clears the timer.
  if pair.self_construction_frustration_unlocked_1504==true then
    return true,"logistics-frustration-reached"
  end
  local start=tonumber(pair.logistic_frustration_start_tick)
  local due=tonumber(pair.logistic_frustration_due_tick)
  local now=tonumber(tick)
  if not (start and due and now and start>=0 and due>=start
      and now>=start) then
    return false,"awaiting-logistics-frustration"
  end
  if now<due then return false,"logistics-frustration-countdown" end
  pair.self_construction_frustration_unlocked_1504=true
  pair.self_construction_frustration_reached_tick_1504=now
  return true,"logistics-frustration-reached"
end
return M
