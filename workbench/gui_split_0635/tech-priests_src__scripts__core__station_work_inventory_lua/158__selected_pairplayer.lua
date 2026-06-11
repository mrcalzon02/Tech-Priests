-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2619-2628
local function selected_pair(player)
  if not (player and player.valid) then return nil end
  local selected = player.selected
  if selected and selected.valid and _G.find_pair_for_entity then local ok, pair = pcall(_G.find_pair_for_entity, selected); if ok and pair then return pair end end
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) and (pair.station == selected or pair.priest == selected) then return pair end
  end
  return nil
end

