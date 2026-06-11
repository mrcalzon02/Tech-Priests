-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 680-690
local function inventory_contents(inv)
  local ok, contents = pcall(function() return inv and inv.valid and inv.get_contents and inv.get_contents() or {} end)
  contents = ok and contents or {}
  local out = {}
  for k, v in pairs(contents or {}) do
    if type(v) == "table" and v.name then out[v.name] = (out[v.name] or 0) + (tonumber(v.count) or 0)
    elseif type(k) == "string" then out[k] = (out[k] or 0) + (tonumber(v) or 0) end
  end
  return out
end

