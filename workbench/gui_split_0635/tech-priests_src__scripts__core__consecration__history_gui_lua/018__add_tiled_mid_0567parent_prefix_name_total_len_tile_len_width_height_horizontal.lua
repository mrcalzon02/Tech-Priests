-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 195-204
local function add_tiled_mid_0567(parent, prefix, name, total_len, tile_len, width, height, horizontal)
  local remaining = math.max(1, math.floor(total_len or tile_len or 1))
  local tile = math.max(1, math.floor(tile_len or 32))
  while remaining > 0 do
    local span = math.min(tile, remaining)
    if horizontal then add_frame_slice_0567(parent, prefix, name, span, height) else add_frame_slice_0567(parent, prefix, name, width, span) end
    remaining = remaining - span
  end
end

