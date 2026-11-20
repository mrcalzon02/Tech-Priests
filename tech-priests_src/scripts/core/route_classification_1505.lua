-- Immutable route classification for the 0594 adaptive economy governor.
-- Registry route owner/category are set when a route is registered. Classify
-- once at wrapper install, then resolve only the live pair tier at invocation.
-- No persisted state or added nth-tick wake routes.
local M = {}

local function lower(value)
  return string.lower(tostring(value or ""))
end

function M.classify(category, owner)
  category, owner = lower(category), lower(owner)
  -- Preserve precedence: diagnostic > presentation > background > unknown.
  if category == "diagnostics"
      or owner:find("diagnostics", 1, true)
      or owner:find("pair_dump", 1, true) then
    return "diagnostics"
  end
  if category == "visuals" or category == "audio" or category == "gui"
      or owner:find("visual", 1, true)
      or owner:find("overhead", 1, true)
      or owner:find("sound", 1, true)
      or owner:find("voice", 1, true)
      or owner:find("chatter", 1, true) then
    return "presentation"
  end
  if category == "inventory" or category == "scheduler"
      or category == "crafting"
      or owner:find("order_queue", 1, true)
      or owner:find("planning", 1, true)
      or owner:find("reserve", 1, true)
      or owner:find("inventory", 1, true) then
    return "background"
  end
  return "other"
end

function M.multiplier(class, pairs, diagnostics)
  local n = tonumber(pairs) or 0
  if class == "diagnostics" then
    if not diagnostics then return 999999, "diagnostics-off" end
    if n >= 80 then return 8, "diagnostics-heavy" end
    return 3, "diagnostics"
  end
  if class == "presentation" then
    if n >= 160 then return 8, "presentation-extreme" end
    if n >= 80 then return 5, "presentation-heavy" end
    if n >= 35 then return 3, "presentation-busy" end
    return 1, "presentation-quiet"
  end
  if class == "background" then
    if n >= 160 then return 3, "background-extreme" end
    if n >= 80 then return 2, "background-heavy" end
    return 1, "background-quiet"
  end
  return 1, "critical-or-unknown"
end

return M
