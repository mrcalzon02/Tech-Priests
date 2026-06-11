-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 715-724
function M.station_item_count(pair, item)
  if not item then return 0 end
  local n = 0
  for _, slot in ipairs(M.station_sources(pair)) do
    local ok, c = pcall(function() return slot.inv.get_item_count(item) end)
    if ok then n = n + (tonumber(c) or 0) end
  end
  return n
end

