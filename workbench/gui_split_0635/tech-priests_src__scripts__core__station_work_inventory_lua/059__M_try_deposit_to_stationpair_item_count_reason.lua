-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 736-751
function M.try_deposit_to_station(pair, item, count, reason)
  if not (item and count and count > 0) then return 0 end
  local remain = count
  local stack = { name = item, count = count }
  for _, slot in ipairs(M.station_sources(pair)) do
    if remain <= 0 then break end
    local can = true
    if slot.inv.can_insert then local ok, yes = pcall(function() return slot.inv.can_insert({ name = item, count = remain }) end); can = ok and yes end
    if can then
      local ok, inserted = pcall(function() return slot.inv.insert({ name = item, count = remain }) end)
      if ok then remain = remain - (tonumber(inserted) or 0) end
    end
  end
  return count - remain
end

