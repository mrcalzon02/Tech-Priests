-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 639-658
local function facility_records(pair)
  local root = emergency_root()
  local key = unit(pair)
  local out = {}
  if not key then return out end
  local bucket = root and root.by_station and root.by_station[key] or nil
  if bucket and root.facilities then
    for rec_key in pairs(bucket) do
      local rec = root.facilities[rec_key]
      if rec and valid(rec.entity) then
        out[#out+1] = rec
      elseif root.facilities then
        root.facilities[rec_key] = nil
      end
    end
  end
  table.sort(out, function(a,b) return tostring(a.role or a.name) < tostring(b.role or b.name) end)
  return out
end

