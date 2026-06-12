-- Tech Priests 0.1.658 shared construction/defense planning constraints.
-- Owns policy checks only; planners still own their sites, ghosts, and work.
-- Runtime hardeners are installed from this already-loaded policy module.

local M = {}
M.version = "0.1.658"
M.perimeter_band = 4.0
M.perimeter_tolerance = 2.25

local item_by_entity = {}
local unlock_cache_tick = -1
local unlock_cache = {}

local function valid(e) return e and e.valid end
local function dist_sq(a, b)
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end

local function radius_for(pair)
  if not (pair and valid(pair.station)) then return 0 end
  if type(_G.refresh_pair_radius) == "function" then local ok, radius = pcall(_G.refresh_pair_radius, pair); if ok and tonumber(radius) then return math.max(8, tonumber(radius)) end end
  if type(_G.get_station_operating_radius) == "function" then local ok, radius = pcall(_G.get_station_operating_radius, pair.station); if ok and tonumber(radius) then return math.max(8, tonumber(radius)) end end
  return math.max(8, tonumber(pair.radius or pair.base_radius) or 20)
end

local function recipe_produces(recipe, item_name)
  local products = nil
  pcall(function() products = recipe.products end)
  for _, product in pairs(products or {}) do local name = nil; pcall(function() name = product.name or product[1] end); if name == item_name then return true end end
  local main = nil
  pcall(function() main = recipe.main_product end)
  return main and (main.name or main) == item_name or false
end

function M.item_for_entity(entity_name)
  if not (entity_name and prototypes and prototypes.item) then return nil end
  if item_by_entity[entity_name] ~= nil then return item_by_entity[entity_name] or nil end
  for item_name, item in pairs(prototypes.item) do local place = nil; pcall(function() place = item.place_result end); if place and place.name == entity_name then item_by_entity[entity_name] = item_name; return item_name end end
  item_by_entity[entity_name] = false
  return nil
end

function M.item_unlocked(force, item_name)
  if not (force and force.valid and item_name and force.recipes) then return false, "invalid-force-or-item" end
  local tick = game and game.tick or 0
  if unlock_cache_tick ~= tick then unlock_cache_tick = tick; unlock_cache = {} end
  local key = tostring(force.index or force.name or "?") .. ":" .. item_name
  if unlock_cache[key] ~= nil then return unlock_cache[key], unlock_cache[key] and "enabled-recipe" or "technology-locked-or-no-enabled-recipe" end
  for _, recipe in pairs(force.recipes) do local enabled = false; pcall(function() enabled = recipe.enabled == true end); if enabled and recipe_produces(recipe, item_name) then unlock_cache[key] = true; return true, "enabled-recipe" end end
  unlock_cache[key] = false
  return false, "technology-locked-or-no-enabled-recipe"
end

function M.entity_unlocked(pair, entity_name)
  if not (pair and valid(pair.station) and entity_name) then return false, "invalid-pair-or-entity" end
  local item_name = M.item_for_entity(entity_name)
  if not item_name then return false, "no-placeable-item" end
  local unlocked, why = M.item_unlocked(pair.station.force, item_name)
  return unlocked, why, item_name
end

function M.interior_position_allowed(pair, position, margin)
  if not (pair and valid(pair.station) and position) then return false, "invalid" end
  local radius = radius_for(pair)
  local interior_radius = math.max(3, radius - (tonumber(margin) or M.perimeter_band))
  if dist_sq(pair.station.position, position) > interior_radius * interior_radius then return false, "reserved-defense-perimeter" end
  return true, "interior-owned"
end

function M.defense_position_allowed(pair, position, tolerance)
  if not (pair and valid(pair.station) and position) then return false, "invalid" end
  local radius = radius_for(pair)
  local distance = math.sqrt(dist_sq(pair.station.position, position))
  if math.abs(distance - radius) > (tonumber(tolerance) or M.perimeter_tolerance) then return false, "outside-defense-perimeter-band" end
  for _, other in pairs(pair_map()) do
    if other ~= pair and other and valid(other.station) and other.station.surface == pair.station.surface and other.station.force == pair.station.force then
      local other_radius = radius_for(other)
      if dist_sq(other.station.position, position) <= other_radius * other_radius then return false, "overlaps-station-control:" .. tostring(other.station.unit_number or "?") end
    end
  end
  return true, "defense-territory-owned"
end

local function install_hardener(module_name, label)
  local ok, mod = pcall(require, module_name)
  if ok and mod and type(mod.install) == "function" then
    local ok2, err2 = pcall(mod.install)
    if ok2 then return true end
    if log then log("[Tech-Priests 0.1.658] " .. tostring(label) .. " install failed: " .. tostring(err2)) end
  elseif log then
    log("[Tech-Priests 0.1.658] " .. tostring(label) .. " unavailable: " .. tostring(mod))
  end
  return false
end

function M.install()
  _G.TechPriestsPlanningConstraints0646 = M
  install_hardener("scripts.core.direct_acquisition_physical_guard_0649", "direct_acquisition_physical_guard_0649")
  install_hardener("scripts.core.proxy_ammo_hardener_0649", "proxy_ammo_hardener_0649")
  install_hardener("scripts.core.direct_acquisition_movement_lock_0650", "direct_acquisition_movement_lock_0650")
  install_hardener("scripts.core.movement_target_reconciler_0652", "movement_target_reconciler_0652")
  install_hardener("scripts.core.movement_intent_authority_0654", "movement_intent_authority_0654")
  install_hardener("scripts.core.construction_placement_authority_0656", "construction_placement_authority_0656")
  install_hardener("scripts.core.active_leaf_task_truth_0655", "active_leaf_task_truth_0655")
  install_hardener("scripts.core.nearby_inventory_scavenge_authority_0658", "nearby_inventory_scavenge_authority_0658")
  install_hardener("scripts.core.logistics_mineable_source_bridge_0657", "logistics_mineable_source_bridge_0657")
  install_hardener("scripts.core.visual_intent_line_authority_0657", "visual_intent_line_authority_0657")
  install_hardener("scripts.core.movement_vector_enforcer_0651", "movement_vector_enforcer_0651")
  if log then log("[Tech-Priests 0.1.658] planning constraints installed; nearby inventory scavenge loads before mineable fallback and vector enforcer") end
  return true
end

return M
