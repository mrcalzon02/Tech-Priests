-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 566-573
local function add_unique(out, seen, inv, owner, kind, inv_id)
  if not (inv and inv.valid) then return end
  local key = tostring(inv)
  if seen[key] then return end
  seen[key] = true
  out[#out+1] = { inv = inv, owner = owner, kind = kind, inv_id = inv_id }
end

