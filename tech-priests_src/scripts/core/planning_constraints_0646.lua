-- Tech Priests 0.1.672 shared construction/defense planning constraints.
-- Owns policy checks only; planners still own their sites, ghosts, and work.
-- Development candidates may be installed here before the packaged version bump.

local M = {}
M.version = "0.1.672"
M.perimeter_band = 4.0
M.perimeter_tolerance = 2.25
M.install_results = M.install_results or {}
M.install_failures = M.install_failures or {}
M.install_complete = false

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
    local ok2, result = pcall(mod.install)
    if ok2 and result ~= false then return true, "installed" end
    local reason = ok2 and "install returned false" or tostring(result)
    if log then
      log("[Tech-Priests 0.1.672] " .. tostring(label)
        .. " install failed: " .. tostring(reason))
    end
    return false, reason
  end
  local reason = ok and "module missing install()" or tostring(mod)
  if log then
    log("[Tech-Priests 0.1.672] " .. tostring(label)
      .. " unavailable: " .. tostring(reason))
  end
  return false, reason
end

function M.installation_summary()
  return {
    complete = M.install_complete == true,
    attempted = M.install_attempted or 0,
    passed = M.install_passed or 0,
    failed = #M.install_failures,
    failures = M.install_failures,
  }
end

function M.install()
  _G.TechPriestsPlanningConstraints0646 = M
  M.install_results = {}
  M.install_failures = {}
  M.install_attempted = 0
  M.install_passed = 0

  local function install(module_name, label)
    M.install_attempted = M.install_attempted + 1
    local ok, reason = install_hardener(module_name, label)
    M.install_results[label] = {
      module = module_name,
      ok = ok == true,
      reason = tostring(reason or ""),
    }
    if ok then
      M.install_passed = M.install_passed + 1
    else
      M.install_failures[#M.install_failures + 1] = {
        module = module_name,
        label = label,
        reason = tostring(reason or "unknown"),
      }
    end
    return ok
  end

  install("scripts.core.direct_acquisition_physical_guard_0649", "direct_acquisition_physical_guard_0649")
  install("scripts.core.proxy_ammo_hardener_0649", "proxy_ammo_hardener_0649")
  install("scripts.core.direct_acquisition_movement_lock_0650", "direct_acquisition_movement_lock_0650")
  install("scripts.core.movement_target_reconciler_0652", "movement_target_reconciler_0652")
  install("scripts.core.movement_intent_authority_0654", "movement_intent_authority_0654")
  install("scripts.core.construction_placement_authority_0656", "construction_placement_authority_0656")
  install("scripts.core.active_leaf_task_truth_0655", "active_leaf_task_truth_0655")
  install("scripts.core.logistics_mineable_source_bridge_0657", "logistics_mineable_source_bridge_0657")
  install("scripts.core.visual_intent_line_authority_0657", "visual_intent_line_authority_0657")
  install("scripts.core.repair_executor_integrity_0673", "repair_executor_integrity_0673")
  install("scripts.core.combat_repair_integrity_0676", "combat_repair_integrity_0676")
  install("scripts.core.combat_repair_terminal_cleanup_0677", "combat_repair_terminal_cleanup_0677")
  install("scripts.core.machine_logistics_integrity_0682", "machine_logistics_integrity_0682")
  install("scripts.core.machine_logistics_candidate_recovery_0683", "machine_logistics_candidate_recovery_0683")
  install("scripts.core.machine_logistics_final_authority_0684", "machine_logistics_final_authority_0684")
  install("scripts.core.storage_role_authority_0686", "storage_role_authority_0686")
  install("scripts.core.inventory_transfer_integrity_0687", "inventory_transfer_integrity_0687")
  install("scripts.core.fluid_network_doctrine_0689", "fluid_network_doctrine_0689")
  install("scripts.core.fluid_output_sink_doctrine_0694", "fluid_output_sink_doctrine_0694")
  install("scripts.core.reservation_position_scope_0697", "reservation_position_scope_0697")
  install("scripts.core.fluid_connection_planner_0691", "fluid_connection_planner_0691")
  install("scripts.core.fluid_connection_execution_guard_0692", "fluid_connection_execution_guard_0692")
  install("scripts.core.fluid_output_connection_planner_0696", "fluid_output_connection_planner_0696")
  install("scripts.core.fluid_port_collision_validator_0699", "fluid_port_collision_validator_0699")
  install("scripts.core.fluid_port_context_guard_0700", "fluid_port_context_guard_0700")
  install("scripts.core.item_family_logistics_0702", "item_family_logistics_0702")
  install("scripts.core.item_family_integrity_0703", "item_family_integrity_0703")
  install("scripts.core.energy_family_readiness_0705", "energy_family_readiness_0705")
  install("scripts.core.energy_readiness_diagnostics_0711", "energy_readiness_diagnostics_0711")
  install("scripts.core.energy_family_logistics_0707", "energy_family_logistics_0707")
  install("scripts.core.energy_item_automation_guard_0722", "energy_item_automation_guard_0722")
  install("scripts.core.rocket_silo_readiness_0709", "rocket_silo_readiness_0709")
  install("scripts.core.rocket_silo_logistics_0710", "rocket_silo_logistics_0710")
  install("scripts.core.artillery_readiness_0712", "artillery_readiness_0712")
  install("scripts.core.artillery_logistics_0713", "artillery_logistics_0713")
  install("scripts.core.artillery_train_validity_guard_0724", "artillery_train_validity_guard_0724")
  install("scripts.core.roboport_readiness_0714", "roboport_readiness_0714")
  install("scripts.core.roboport_repair_pack_logistics_0715", "roboport_repair_pack_logistics_0715")
  install("scripts.core.fluid_turret_readiness_0716", "fluid_turret_readiness_0716")
  install("scripts.core.fluid_turret_connection_proposals_0717", "fluid_turret_connection_proposals_0717")
  install("scripts.core.fluid_turret_proposal_integrity_0718", "fluid_turret_proposal_integrity_0718")
  install("scripts.core.fluid_turret_connection_planner_0719", "fluid_turret_connection_planner_0719")
  install("scripts.core.movement_vector_enforcer_0651", "movement_vector_enforcer_0651")
  install("scripts.core.development_integration_audit_0721", "development_integration_audit_0721")
  install("scripts.core.runtime_command_cleanup_0720", "runtime_command_cleanup_0720")
  install("scripts.core.hardener_installation_audit_0723", "hardener_installation_audit_0723")

  M.install_complete = #M.install_failures == 0
  if log then
    log("[Tech-Priests 0.1.672] planning constraints hardener installation attempted="
      .. tostring(M.install_attempted)
      .. " passed=" .. tostring(M.install_passed)
      .. " failed=" .. tostring(#M.install_failures)
      .. " complete=" .. tostring(M.install_complete))
  end
  return M.install_complete
end

return M
