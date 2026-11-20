-- Determines whether a duplicate backlog submission changes actual work eligibility.
-- Pure module: no Factorio state, no storage, no event handler or delayed wake.
local M = {}
function M.reason(existing, incoming, tick)
  if type(existing) ~= "table" then return "new-order" end
  if (tonumber(existing.expires_tick) or 0) <= (tonumber(tick) or 0) then
    return "expired-revived"
  end
  if (tonumber(incoming and incoming.priority) or 0) > (tonumber(existing.priority) or 0) then
    return "priority-raised"
  end
  return nil
end
return M
