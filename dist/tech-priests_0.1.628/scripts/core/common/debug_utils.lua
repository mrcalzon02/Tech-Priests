-- Tech Priests common debug helpers.
-- 0.1.421: shared utility module introduced during control.lua cleanup.

local M = {}

function M.safe_tostring(value)
  local ok, result = pcall(function() return tostring(value) end)
  if ok then return result end
  return "<unprintable>"
end

function M.print_to_player(player, message)
  if player and player.valid and player.print then
    player.print(message)
    return true
  end
  return false
end

function M.log(message)
  if log then log(message) end
end

return M
