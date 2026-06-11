-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2265-2278
local function add_tiled_frame_mid_0541(parent, sprite_prefix, mid_name, total_len, tile_len, width, height, horizontal)
  local remaining = math.max(1, math.floor(total_len or tile_len or 1))
  local tile = math.max(1, math.floor(tile_len or 32))
  while remaining > 0 do
    local span = math.min(tile, remaining)
    if horizontal then
      add_frame_slice_0540(parent, mid_name, span, height)
    else
      add_frame_slice_0540(parent, mid_name, width, span)
    end
    remaining = remaining - span
  end
end

