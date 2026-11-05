-- Version-specific native ItemPrototype fuel schema; no custom fuel system.
-- Factorio 2.1 removed fuel_category; 2.0 still requires the singular field.
return function(item, category, game_version)
  assert(type(item) == "table", "item prototype table is required")
  assert(type(category) == "string" and category ~= "", "fuel category is required")
  local major, minor = tostring(game_version or ""):match("^(%d+)%.(%d+)")
  assert(major and minor, "unknown Factorio base version; cannot select fuel schema")
  major, minor = tonumber(major), tonumber(minor)
  if major > 2 or (major == 2 and minor >= 1) then
    item.fuel_category = nil
    item.fuel_categories = { category }
  else
    item.fuel_categories = nil
    item.fuel_category = category
  end
  return item
end
