-- Tech Priests 0.1.324
-- Inventory-target safety gate.
-- Priests may scan machines and storage controlled by their force, but they must
-- not target live player/character entities for inventory searches or idle scan
-- beams. Player inventories are command authority, not polite salvage boxes.

local M = {}

M.version = "0.1.324"

local function is_direct_player_entity(entity)
  if not (entity and entity.valid) then return false end
  if entity.type == "character" then return true end
  if entity.name == "character" then return true end
  -- Some modded or scenario-controlled character-like entities expose a player
  -- reference. Guard with pcall so prototypes that do not support it do not crash.
  local ok, player = pcall(function() return entity.player end)
  if ok and player then return true end
  return false
end

function M.is_direct_player_entity(entity)
  return is_direct_player_entity(entity)
end

function M.install()
  _G.tech_priests_0324_is_direct_player_inventory_target = is_direct_player_entity

  local previous_candidate_filter = _G.is_logistic_scan_candidate_entity
  if previous_candidate_filter then
    _G.TECH_PRIESTS_0324_PRE_IS_LOGISTIC_SCAN_CANDIDATE_ENTITY = previous_candidate_filter
    _G.is_logistic_scan_candidate_entity = function(pair, entity)
      if is_direct_player_entity(entity) then return false end
      return previous_candidate_filter(pair, entity)
    end
  else
    _G.is_logistic_scan_candidate_entity = function(pair, entity)
      if is_direct_player_entity(entity) then return false end
      return entity and entity.valid or false
    end
  end

  local previous_idle_candidates = _G.get_idle_scan_candidates
  if previous_idle_candidates then
    _G.TECH_PRIESTS_0324_PRE_GET_IDLE_SCAN_CANDIDATES = previous_idle_candidates
    _G.get_idle_scan_candidates = function(pair)
      local ok, candidates = pcall(function() return previous_idle_candidates(pair) end)
      if not (ok and type(candidates) == "table") then return {} end
      local filtered = {}
      for _, candidate in pairs(candidates) do
        local entity = candidate and candidate.entity
        if not is_direct_player_entity(entity) then
          filtered[#filtered + 1] = candidate
        end
      end
      return filtered
    end
  end

  if commands and commands.add_command then
    pcall(function()
      commands.add_command("tp-inventory-target-safety-0324", "Tech Priests: inspect whether selected entity is blocked from inventory scans as a player/character target.", function(event)
        local player = game and game.get_player(event.player_index)
        if not player then return end
        local selected = player.selected
        if not (selected and selected.valid) then
          player.print("[Tech Priests 0.1.324] Select an entity to inspect inventory-target safety.")
          return
        end
        player.print("[Tech Priests 0.1.324] selected=" .. tostring(selected.name) .. " type=" .. tostring(selected.type) .. " direct-player-target=" .. tostring(is_direct_player_entity(selected)))
      end)
    end)
  end

  if log then log("[Tech-Priests 0.1.324] inventory scan player/character target safety installed") end
end

return M
