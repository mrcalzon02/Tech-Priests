-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1947-1963
local function display_target_0494(v, seen)
  if valid(v) then return tostring(v.name or "entity") .. "#" .. tostring(v.unit_number or "?") end
  if type(v) ~= "table" then return tostring(v or "none") end
  seen = seen or {}
  if seen[v] then return "recursive target" end
  seen[v] = true
  if v.x and v.y then return string.format("%.1f, %.1f", tonumber(v.x) or 0, tonumber(v.y) or 0) end
  if v.position and v.position.x and v.position.y then return string.format("%.1f, %.1f", tonumber(v.position.x) or 0, tonumber(v.position.y) or 0) end
  for _, key in ipairs({ "target", "entity", "resource_entity", "mining_target", "candidate", "source", "destination", "position" }) do
    if v[key] ~= nil then
      local text = display_target_0494(v[key], seen)
      if text and text ~= "none" and text ~= "nil" then return text end
    end
  end
  return "none"
end

