-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 184-197
local function root()
  if not storage then return nil end
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests.station_work_boot_0364
  if not r then
    r = { seen_by_force = {}, open_by_player = {}, stats = { started = 0, completed = 0 } }
    storage.tech_priests.station_work_boot_0364 = r
  end
  r.seen_by_force = r.seen_by_force or {}
  r.open_by_player = r.open_by_player or {}
  r.stats = r.stats or { started = 0, completed = 0 }
  return r
end

