-- Guard station snapshot reuse against changes in the station's physical world.
-- No timers, events, saved state, or scanning. A missing field fails closed.
local M = {}

local function identity(object)
  if not (object and object.valid ~= false) then return nil end
  return object.index or object.name
end

function M.snapshot(pair, radius)
  local station = pair and pair.station
  if not (station and station.valid and station.position) then return nil end
  local surface_id, force_id = identity(station.surface), identity(station.force)
  if surface_id == nil or force_id == nil then return nil end
  return {
    station_surface_1484 = surface_id,
    station_force_1484 = force_id,
    station_position_1484 = {
      x = station.position.x,
      y = station.position.y,
    },
    station_unit = station.unit_number or pair.station_unit,
    station_name = station.name,
    station_backer_name = station.backer_name,
    radius = radius,
  }
end

function M.matches(pair, catalog, radius)
  if not (pair and catalog and pair.station and pair.station.valid) then
    return false, "missing-station-or-catalog"
  end
  local station = pair.station
  local p = station.position
  local saved = catalog.station_position_1484
  if not (p and saved and saved.x ~= nil and saved.y ~= nil
      and catalog.station_surface_1484 ~= nil
      and catalog.station_force_1484 ~= nil) then
    return false, "legacy-or-incomplete-snapshot"
  end
  local unit = station.unit_number or pair.station_unit
  if unit ~= catalog.station_unit or (pair.station_unit and pair.station_unit ~= unit) then
    return false, "station-identity-changed"
  end
  if radius ~= catalog.radius then return false, "station-radius-changed" end
  if p.x ~= saved.x or p.y ~= saved.y then
    return false, "station-position-changed"
  end
  if identity(station.surface) ~= catalog.station_surface_1484 then
    return false, "station-surface-changed"
  end
  if identity(station.force) ~= catalog.station_force_1484 then
    return false, "station-force-changed"
  end
  if station.name ~= catalog.station_name
      or station.backer_name ~= catalog.station_backer_name then
    return false, "station-label-changed"
  end
  return true, "unchanged"
end

return M
