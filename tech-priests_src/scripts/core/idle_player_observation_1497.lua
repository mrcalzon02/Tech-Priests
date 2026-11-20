-- Shared one-tick player-position snapshots for adaptive idle observations.
-- Selections/opened GUIs remain live, so player interaction wakes immediately.
-- This is module-local and never written to Factorio storage.
local M = {}
local snapshot_game, snapshot_tick, snapshot_players

local function players_for(game_ref)
  local tick = game_ref and game_ref.tick
  if tick ~= nil and game_ref == snapshot_game and tick == snapshot_tick then
    return snapshot_players
  end
  local players = {}
  for _, player in pairs(game_ref and game_ref.connected_players or {}) do
    if player and player.valid then
      local character = player.character
      local rec = {player = player}
      if character and character.valid then
        local p = character.position
        if p then
          rec.surface = character.surface
          rec.x, rec.y = p.x or 0, p.y or 0
        end
      end
      players[#players + 1] = rec
    end
  end
  snapshot_players = players
  snapshot_game, snapshot_tick = game_ref, tick
  return players
end

function M.observed(pair, game_ref)
  local priest = pair and pair.priest
  local station = pair and pair.station
  local entity = priest and priest.valid and priest or station
  if not (entity and entity.valid and game_ref) then return false end
  local surface, pos = entity.surface, entity.position
  if not pos then return false end
  local x, y = pos.x or 0, pos.y or 0
  for _, item in ipairs(players_for(game_ref)) do
    local player = item.player
    if player.valid then
      -- Never cache GUI state: opening/selecting a priest during the same
      -- tick must wake it even if the positional snapshot was already read.
      if player.opened == station then return true end
      local selected = player.selected
      if selected and (selected == station or selected == priest) then return true end
      if item.surface == surface then
        local dx, dy = item.x - x, item.y - y
        if dx*dx + dy*dy <= 80*80 then return true end
      end
    end
  end
  return false
end

return M
