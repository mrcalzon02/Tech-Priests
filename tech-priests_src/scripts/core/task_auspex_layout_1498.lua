-- Compact, resolution-aware Task Auspex layout. Read-only calculations.
-- The parent Command Overview remains the owner of the actual GUI frame.
local M = {}

local function clamp(value, lo, hi)
  return math.max(lo, math.min(hi, value))
end

function M.for_player(player)
  local width, height, scale = 1920, 1080, 1
  if player and player.valid then
    local ok, resolution = pcall(function() return player.display_resolution end)
    if ok and type(resolution) == "table" then
      width = tonumber(resolution.width) or width
      height = tonumber(resolution.height) or height
    end
    local ok_scale, selected = pcall(function() return player.display_scale end)
    if ok_scale then scale = tonumber(selected) or scale end
  end
  if width ~= width or width <= 0 or width == math.huge then width = 1920 end
  if height ~= height or height <= 0 or height == math.huge then height = 1080 end
  if scale ~= scale or scale <= 0 or scale == math.huge then scale = 1 end
  -- Factorio GUI style sizes are logical pixels, not physical display pixels.
  local logical_width = math.max(1, math.floor(width / scale))
  local logical_height = math.max(1, math.floor(height / scale))
  -- Leave space for the Command Overview's own frame and headers.
  local scroll_width = clamp(logical_width - 64, 1, 1040)
  local scroll_height = clamp(logical_height - 180, 1, 590)
  local interior = math.max(1, scroll_width - 24)
  local key_width = math.max(1, math.floor(interior * 0.24))
  local value_width = math.max(1, interior - key_width)
  local button_columns = scroll_width >= 980 and 7
    or scroll_width >= 720 and 4
    or scroll_width >= 480 and 3 or 2
  return {
    scroll_width = scroll_width,
    scroll_height = scroll_height,
    label_width = interior,
    key_width = key_width,
    value_width = value_width,
    button_columns = button_columns,
    page_height = math.min(640, math.max(1, logical_height - 80)),
    logical_width = logical_width,
    logical_height = logical_height,
  }
end

return M
