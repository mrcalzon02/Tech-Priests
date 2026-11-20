-- Transient, per-pair rotating inspection cursor for repair discovery.
-- Never stored in Factorio storage: saved orders and ownership remain unchanged.
local M = {}
local cursors = setmetatable({}, { __mode = "k" })
M.max_checks_per_sweep = 128

function M.window(pair, entity_count, requested_limit)
  local count = math.max(0, math.floor(tonumber(entity_count) or 0))
  local limit = math.max(1, math.min(M.max_checks_per_sweep,
    math.floor(tonumber(requested_limit) or 32)))
  if count == 0 then
    if pair then cursors[pair] = nil end
    return 1, 0, true, 1
  end
  local start = tonumber(pair and cursors[pair]) or 1
  if start < 1 or start > count then start = 1 end
  local inspected = math.min(count, limit)
  local next_start = ((start + inspected - 1) % count) + 1
  if pair then cursors[pair] = next_start end
  return start, inspected, inspected == count, next_start
end

return M
