-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 435-447
local function play_boot_sound(player, pair, stage)
  local b = active_boot(player)
  if not b or b.last_boot_sound_stage_0411 == stage then return end
  b.last_boot_sound_stage_0411 = stage
  local surface = valid(pair and pair.station) and pair.station.surface or (player and player.valid and player.surface) or nil
  if not (surface and surface.play_sound) then return end
  local position = valid(pair and pair.station) and pair.station.position or (player and player.valid and player.position) or nil
  for _, path in ipairs(BOOT_SOUND_CANDIDATES_0411) do
    local ok = pcall(function() surface.play_sound({ path = path, position = position, volume_modifier = 0.38 }) end)
    if ok then return end
  end
end

