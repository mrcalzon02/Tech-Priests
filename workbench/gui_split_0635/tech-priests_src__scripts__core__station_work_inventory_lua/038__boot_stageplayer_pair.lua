-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 462-472
local function boot_stage(player, pair)
  local b = active_boot(player)
  if not b then return nil end
  if tostring(b.station_unit) ~= station_key(pair) then return nil end
  local elapsed = math.max(0, now() - (b.start_tick or now()))
  local total = boot_phase_count(station_rank(pair))
  local stage = math.floor(elapsed / boot_stage_ticks()) + 1
  if stage > total then stage = total end
  return stage, total, elapsed
end

