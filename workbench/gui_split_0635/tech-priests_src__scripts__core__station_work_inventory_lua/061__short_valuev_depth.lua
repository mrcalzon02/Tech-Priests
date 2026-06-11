-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 766-785
local function short_value(v, depth)
  depth = depth or 0
  if depth > 1 then return "..." end
  if type(v) ~= "table" then return tostring(v) end
  local parts = {}
  for _, k in ipairs({ "type", "kind", "item", "item_name", "entity", "entity_name", "recipe", "recipe_name", "mode", "state", "phase", "reason", "target", "current", "amount", "count", "needed", "gathered" }) do
    local val = v[k]
    if val ~= nil then
      if type(val) == "table" and val.valid and val.name then val = val.name .. "#" .. tostring(val.unit_number or "?") end
      parts[#parts+1] = k .. "=" .. short_value(val, depth + 1)
    end
  end
  if #parts == 0 then
    local n = 0
    for k, val in pairs(v) do n = n + 1; if n <= 4 then parts[#parts+1] = tostring(k) .. "=" .. short_value(val, depth+1) end end
  end
  return table.concat(parts, ", ")
end


