-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 615-628
local function known_stashes(pair)
  local out = {}
  local root = steward_root()
  local key = unit(pair)
  local bucket = root and root.stashes_by_station and key and root.stashes_by_station[key] or nil
  if bucket then
    for id, rec in pairs(bucket) do
      local e = rec and rec.entity
      if valid(e) then out[#out+1] = e else bucket[id] = nil end
    end
  end
  return out
end

