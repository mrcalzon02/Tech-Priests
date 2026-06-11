-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 725-735
function M.try_remove_from_station(pair, item, count, reason)
  if not (item and count and count > 0) then return 0 end
  local need = count
  for _, slot in ipairs(M.station_sources(pair)) do
    if need <= 0 then break end
    local ok, removed = pcall(function() return slot.inv.remove({ name = item, count = need }) end)
    if ok then need = need - (tonumber(removed) or 0) end
  end
  return count - need
end

