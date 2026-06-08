-- Tech Priests common station/priest pair helpers.
-- 0.1.421: shared utility module introduced during control.lua cleanup.

local entity = require("scripts.core.common.entity_utils")
local storage_utils = require("scripts.core.common.storage_utils")

local M = {}

function M.pair_map()
  return storage_utils.ensure_root("pairs")
end

function M.pairs_by_station()
  return storage_utils.ensure_root("pairs_by_station")
end

function M.valid_pair(pair)
  return pair ~= nil and entity.valid(pair.station) and entity.valid(pair.priest)
end

function M.find_by_station_unit(unit_number)
  if not unit_number then return nil end
  local index = M.pairs_by_station()
  local key = index[unit_number] or index[tostring(unit_number)]
  if not key then return nil end
  return M.pair_map()[key]
end

function M.selected_pair(player)
  if not (player and player.valid and player.selected and player.selected.valid) then return nil end
  local selected = player.selected
  if selected.unit_number then
    local by_station = M.find_by_station_unit(selected.unit_number)
    if by_station then return by_station end
  end
  local pair_map = M.pair_map()
  for _, pair in pairs(pair_map) do
    if pair.station == selected or pair.priest == selected then return pair end
  end
  return nil
end

return M
