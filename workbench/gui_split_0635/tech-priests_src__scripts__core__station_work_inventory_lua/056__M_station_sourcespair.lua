-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 707-714
function M.station_sources(pair)
  local out = {}
  for _, s in ipairs(station_inventories(pair)) do out[#out+1] = s end
  for _, s in ipairs(stash_inventories(pair)) do out[#out+1] = s end
  for _, s in ipairs(facility_inventories(pair)) do out[#out+1] = s end
  return out
end

