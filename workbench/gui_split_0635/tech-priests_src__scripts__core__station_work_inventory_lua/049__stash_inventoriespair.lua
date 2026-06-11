-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 629-634
local function stash_inventories(pair)
  local out, seen = {}, {}
  for _, e in ipairs(known_stashes(pair)) do add_unique(out, seen, entity_inventory(e), e, "station-stash", defines.inventory.chest) end
  return out
end

