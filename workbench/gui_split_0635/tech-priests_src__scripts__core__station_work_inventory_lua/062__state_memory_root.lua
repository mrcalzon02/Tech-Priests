-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 786-795
local function state_memory_root()
  if not storage then return nil end
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.station_work_state_memory_0366 = storage.tech_priests.station_work_state_memory_0366 or { version = M.version, by_station = {} }
  local r = storage.tech_priests.station_work_state_memory_0366
  r.version = M.version
  r.by_station = r.by_station or {}
  return r
end

