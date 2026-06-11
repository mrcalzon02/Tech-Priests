-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 531-553
local function safe_entity_label(entity, fallback)
  if not (entity and entity.valid) then return tostring(fallback or "?") end
  local backer = entity.backer_name
  if type(backer) == "string" and backer ~= "" then return backer end
  local name = entity.name
  if type(name) == "string" and name ~= "" then return name end
  return tostring(entity.unit_number or fallback or "?")
end

station_label = function(pair)
  if not pair then return "no station" end
  local station = pair.station
  if station and station.valid then return safe_entity_label(station, pair.station_unit) end
  return "station#" .. tostring(pair.station_unit or "?")
end

priest_label = function(pair)
  if not pair then return "no priest" end
  local priest = pair.priest
  if priest and priest.valid then return safe_entity_label(priest, pair.priest_unit) end
  return "missing priest#" .. tostring(pair.priest_unit or "?")
end

