-- Resolution-aware layout for the Cogitator Auspex ledger.
-- Pure calculations; no events, persistent state or simulation work.
local M = {}

local function minimum_and_cap(value, low, high)
  return math.max(low, math.min(value, high))
end

function M.for_player(player)
  local resolution, scale = nil, nil
  if player and player.valid then
    local ok, value = pcall(function() return player.display_resolution end)
    if ok and type(value) == "table" then resolution = value end
    local ok_scale, user_scale = pcall(function() return player.display_scale end)
    if ok_scale then scale = tonumber(user_scale) end
  end
  local w = tonumber(resolution and resolution.width) or 1920
  local h = tonumber(resolution and resolution.height) or 1080
  if not scale or scale <= 0 then scale = 1 end
  -- Factorio GUI dimensions are logical pixels; display_resolution is physical.
  local width = math.max(1, math.floor(w / scale))
  local height = math.max(1, math.floor(h / scale))
  local margin = 8
  local frame_width = minimum_and_cap(width - 2 * margin, 1, 440)
  local frame_height = minimum_and_cap(height - 2 * margin, 1, 720)
  local details_width = minimum_and_cap(frame_width - 24, 1, 420)
  local details_height = minimum_and_cap(frame_height - 200, 32, 500)
  local x = math.max(0, math.min(24, width - frame_width - margin))
  local y = math.max(0, math.min(96, height - frame_height - margin))
  return {
    frame_width = frame_width,
    frame_height = frame_height,
    details_width = details_width,
    details_height = details_height,
    position = { x = math.floor(x), y = math.floor(y) },
    logical_width = width,
    logical_height = height,
  }
end

-- Wrap long readouts instead of permitting labels to stretch a narrow panel.
function M.add_label(parent, caption, max_width)
  local label = parent.add({type = "label", caption = caption})
  label.style.single_line = false
  label.style.maximal_width = math.max(1, math.floor(tonumber(max_width) or 420))
  return label
end

return M
