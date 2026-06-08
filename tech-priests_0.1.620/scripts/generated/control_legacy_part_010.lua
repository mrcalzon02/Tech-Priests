-- Auto-split control.lua fragment 010 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.


function tech_priests_position_ground_ok_0186(pair, position)
  if not (pair and pair.station and pair.station.valid and position) then return false end
  if tech_priests_tile_is_valid_spawn_ground_0176 then
    local ok, result = pcall(function() return tech_priests_tile_is_valid_spawn_ground_0176(pair.station, position) end)
    if ok and not result then return false end
  end
  return true
end

function tech_priests_can_place_emergency_entity_at_0186(pair, entity_name, position)
  if not (pair and pair.station and pair.station.valid and entity_name and position) then return false end
  if not tech_priests_surface_supports_martian_emergency_doctrine_0184(pair.station.surface) then return false end
  if not tech_priests_position_ground_ok_0186(pair, position) then return false end
  local surface = pair.station.surface
  local ok, can = pcall(function()
    return surface.can_place_entity({ name = entity_name, position = position, force = pair.station.force })
  end)
  if ok and can then return true end
  -- Some prototypes can be fussy about can_place_entity in control-stage tests;
  -- fall back to a non-colliding position check, but still demand the returned
  -- position be essentially the same tile so we do not drift the build plan.
  local ok_find, found = pcall(function()
    return surface.find_non_colliding_position(entity_name, position, 0.35, 0.10, false)
  end)
  return ok_find and found and tech_priests_distance_sq_0186(found, position) <= 0.20
end

function tech_priests_find_emergency_build_position_0186(pair, item_name, op)
  if not (pair and pair.station and pair.station.valid and item_name and op) then return nil end
  local entity_name = tech_priests_get_entity_prototype_name_from_item_0184(item_name)
  if not entity_name then return nil end
  if tech_priests_station_or_site_has_entity_0184(pair, entity_name) then return nil end
  local surface = pair.station.surface
  local site = op.site or tech_priests_find_emergency_operation_site_0184(pair)
  if not site then return nil end
  op.site = site
  local layout = TECH_PRIESTS_EMERGENCY_CONSTRUCTION_LAYOUT_0186[item_name] or { x = 0, y = 0 }
  local preferred = { x = math.floor(site.x + layout.x) + 0.5, y = math.floor(site.y + layout.y) + 0.5 }
  if tech_priests_can_place_emergency_entity_at_0186(pair, entity_name, preferred) then return preferred end
  local candidates = {}
  for r = 0, TECH_PRIESTS_EMERGENCY_CONSTRUCTION_RADIUS_0186 do
    for dx = -r, r do
      for dy = -r, r do
        if math.max(math.abs(dx), math.abs(dy)) == r then
          local pos = { x = math.floor(preferred.x) + dx + 0.5, y = math.floor(preferred.y) + dy + 0.5 }
          local station_radius = refresh_pair_radius(pair) or 20
          if tech_priests_distance_sq_0186(pos, pair.station.position) <= station_radius * station_radius then
            candidates[#candidates + 1] = { position = pos, dist = tech_priests_distance_sq_0186(pos, preferred) + tech_priests_distance_sq_0186(pos, site) * 0.01 }
          end
        end
      end
    end
  end
  table.sort(candidates, function(a, b) return a.dist < b.dist end)
  for _, candidate in pairs(candidates) do
    if tech_priests_can_place_emergency_entity_at_0186(pair, entity_name, candidate.position) then
      return candidate.position
    end
  end
  return nil
end

function tech_priests_begin_emergency_construction_0186(pair, item_name, op)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid and item_name and op) then return false end
  local inv = get_station_inventory(pair.station)
  if not (inv and inv.get_item_count(item_name) > 0) then return false end
  local entity_name = tech_priests_get_entity_prototype_name_from_item_0184(item_name)
  if not entity_name then return false end
  if tech_priests_station_or_site_has_entity_0184(pair, entity_name) then return false end
  local position = tech_priests_find_emergency_build_position_0186(pair, item_name, op)
  if not position then
    op.phase = "construction-site-blocked"
    op.next_tick = game.tick + TECH_PRIESTS_EMERGENCY_OPERATION_RETRY_TICKS_0184
    tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. item_name .. "] no valid emergency construction tile")
    return true
  end
  op.construction = {
    item_name = item_name,
    entity_name = entity_name,
    position = position,
    phase = "approach",
    started_tick = game.tick,
    next_repath_tick = 0,
    build_due_tick = nil
  }
  op.phase = "constructing-" .. item_name
  pair.mode = "emergency-construction"
  pair.target = nil
  tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. item_name .. "] construction rite selected")
  if tech_priests_play_task_sound_0177 then tech_priests_play_task_sound_0177(pair, "emergency_craft", position, 60 * 3, 0.50) end
  return true
end

function tech_priests_complete_emergency_construction_0186(pair, op, task)
  if not (pair and pair.station and pair.station.valid and task and task.item_name and task.entity_name and task.position) then return false end
  local inv = get_station_inventory(pair.station)
  if not (inv and inv.get_item_count(task.item_name) > 0) then
    op.construction = nil
    op.phase = "construction-item-missing"
    tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. task.item_name .. "] construction halted: item missing")
    return false
  end
  if tech_priests_station_or_site_has_entity_0184(pair, task.entity_name) then
    op.construction = nil
    return true
  end
  if not tech_priests_can_place_emergency_entity_at_0186(pair, task.entity_name, task.position) then
    task.position = tech_priests_find_emergency_build_position_0186(pair, task.item_name, op)
    task.phase = "approach"
    task.build_due_tick = nil
    task.next_repath_tick = 0
    if not task.position then
      op.construction = nil
      op.phase = "construction-site-blocked"
      op.next_tick = game.tick + TECH_PRIESTS_EMERGENCY_OPERATION_RETRY_TICKS_0184
      tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. task.item_name .. "] construction site obstructed")
    end
    return true
  end
  local removed = inv.remove({ name = task.item_name, count = 1 }) or 0
  if removed <= 0 then
    op.construction = nil
    return false
  end
  local ok_create, entity = pcall(function()
    return pair.station.surface.create_entity({
      name = task.entity_name,
      position = task.position,
      force = pair.station.force,
      create_build_effect_smoke = true,
      raise_built = true
    })
  end)
  if not (ok_create and entity and entity.valid) then
    inv.insert({ name = task.item_name, count = 1 })
    task.position = tech_priests_find_emergency_build_position_0186(pair, task.item_name, op)
    task.phase = "approach"
    task.build_due_tick = nil
    task.next_repath_tick = 0
    tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. task.item_name .. "] construction failed; reselecting tile")
    return true
  end
  if tech_priests_register_emergency_miner_0183 and entity.name == TECH_PRIESTS_EMERGENCY_MINER_NAME then
    tech_priests_register_emergency_miner_0183(entity)
  end
  if tech_priests_fuel_emergency_entity_from_station_0254 then
    tech_priests_fuel_emergency_entity_from_station_0254(pair, entity)
  end
  op.construction = nil
  op.phase = "construction-complete"
  op.next_tick = game.tick + 15
  tech_priests_draw_emergency_operation_status_0184(pair, "[entity=" .. entity.name .. "] emergency machine constructed")
  tech_priests_status_at_position_0186(pair, entity.position, "[entity=" .. entity.name .. "] constructed")
  if tech_priests_play_task_sound_0177 then tech_priests_play_task_sound_0177(pair, "emergency_craft", entity.position, 60 * 3, 0.65) end
  return true
end

function tech_priests_service_emergency_construction_0186(pair, op)
  local task = op and op.construction or nil
  if not task then return false end
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  if game.tick - (task.started_tick or game.tick) > TECH_PRIESTS_EMERGENCY_CONSTRUCTION_TIMEOUT_TICKS_0186 then
    op.construction = nil
    op.phase = "construction-timeout"
    op.next_tick = game.tick + 60
    tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. tostring(task.item_name) .. "] construction rite timed out; replanning")
    tech_priests_stop_priest_0186(pair)
    return true
  end
  if tech_priests_station_or_site_has_entity_0184(pair, task.entity_name) then
    op.construction = nil
    return true
  end
  local inv = get_station_inventory(pair.station)
  if not (inv and inv.get_item_count(task.item_name) > 0) then
    op.construction = nil
    op.phase = "construction-awaiting-item"
    op.next_tick = game.tick + 15
    tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. tostring(task.item_name) .. "] awaiting construction material")
    return true
  end
  local priest_pos = pair.priest.position
  local dist_sq = tech_priests_distance_sq_0186(priest_pos, task.position)
  if dist_sq > TECH_PRIESTS_EMERGENCY_CONSTRUCTION_APPROACH_RADIUS_0186 * TECH_PRIESTS_EMERGENCY_CONSTRUCTION_APPROACH_RADIUS_0186 then
    task.phase = "approach"
    task.build_due_tick = nil
    if game.tick >= (task.next_repath_tick or 0) then
      issue_priest_command(pair.priest, {
        type = defines.command.go_to_location,
        destination = task.position,
        radius = TECH_PRIESTS_EMERGENCY_CONSTRUCTION_APPROACH_RADIUS_0186,
        distraction = defines.distraction.none
      })
      task.next_repath_tick = game.tick + TECH_PRIESTS_EMERGENCY_CONSTRUCTION_REPATH_TICKS_0186
    end
    tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. task.item_name .. "] moving to construction tile")
    tech_priests_status_at_position_0186(pair, task.position, "[item=" .. task.item_name .. "] planned")
    return true
  end
  tech_priests_stop_priest_0186(pair)
  pair.mode = "emergency-construction"
  if not task.build_due_tick then
    task.phase = "building"
    task.build_due_tick = game.tick + TECH_PRIESTS_EMERGENCY_CONSTRUCTION_BUILD_TICKS_0186
    tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. task.item_name .. "] assembling emergency machine")
    if tech_priests_play_task_sound_0177 then tech_priests_play_task_sound_0177(pair, "emergency_scan_field", task.position, 60 * 3, 0.42) end
    return true
  end
  local remaining = math.max(0, math.ceil(((task.build_due_tick or game.tick) - game.tick) / 60))
  if remaining > 0 then
    tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. task.item_name .. "] construction rite " .. remaining .. "s")
    tech_priests_status_at_position_0186(pair, task.position, "[item=" .. task.item_name .. "] under construction")
    return true
  end
  return tech_priests_complete_emergency_construction_0186(pair, op, task)
end

-- Override the 0.1.184/0.1.185 service to route machine deployment through the
-- explicit construction state while preserving the acquisition ladder added in
-- 0.1.185.
function tech_priests_service_independent_emergency_operation_0184(pair)
  local op = tech_priests_get_emergency_operation_0184(pair)
  if not (op and op.enabled and pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  if not tech_priests_surface_supports_martian_emergency_doctrine_0184(pair.station.surface) then
    op.phase = "invalid-surface"
    tech_priests_draw_emergency_operation_status_0184(pair, "[virtual-signal=signal-deny] Emergency doctrine requires planet, gravity, atmosphere")
    return false
  end
  if op.construction then
    return tech_priests_service_emergency_construction_0186(pair, op)
  end
  if pair.emergency_craft then
    return handle_emergency_desperation_craft(pair)
  end
  if pair.scavenge then
    return handle_priest_scavenge_task(pair)
  end

  if game.tick < (op.next_tick or 0) then return true end
  op.next_tick = game.tick + TECH_PRIESTS_EMERGENCY_OPERATION_TICK_SPACING_0184
  pair.mode = "independent-emergency-operation"

  if not op.site then op.site = tech_priests_find_emergency_operation_site_0184(pair) end
  if not op.site then
    op.next_tick = game.tick + TECH_PRIESTS_EMERGENCY_OPERATION_RETRY_TICKS_0184
    tech_priests_draw_emergency_operation_status_0184(pair, "[virtual-signal=signal-deny] No safe Martian emergency site")
    return true
  end

  if tech_priests_service_emergency_fuel_bootstrap_0254(pair, op) then return true end

  for _, item_name in pairs(TECH_PRIESTS_EMERGENCY_OPERATION_PLACE_NAMES_0184) do
    if item_name ~= "tech-priests-emergency-power-grid" or not tech_priests_station_has_nearby_power_grid_0184(pair) then
      local entity_name = tech_priests_get_entity_prototype_name_from_item_0184(item_name)
      if not tech_priests_station_or_site_has_entity_0184(pair, entity_name) then
        local inv = get_station_inventory(pair.station)
        if inv and inv.get_item_count(item_name) > 0 then
          return tech_priests_begin_emergency_construction_0186(pair, item_name, op)
        else
          tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. item_name .. "] escalating emergency acquisition")
          return tech_priests_emergency_operation_acquire_item_0185(pair, item_name, op, 1, 0)
        end
      end
    end
  end

  local science_item = tech_priests_get_next_science_objective_0184(pair, op)
  op.science_item = science_item
  local lab = tech_priests_station_or_site_has_entity_0184(pair, "tech-priests-emergency-laboratorium")
  if lab and science_item then
    if tech_priests_insert_science_into_lab_0184(pair, lab, science_item) then
      tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. science_item .. "] offered to emergency Laboratorium")
      return true
    end
    tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. science_item .. "] recipe-order acquisition ladder")
    return tech_priests_emergency_operation_acquire_item_0185(pair, science_item, op, 1, 0)
  end

  return true
end

-- 0.1.187 Emergency Operation task-force coordination pass.
-- Nearby Cogitator Stations and their Tech-Priests may now assist a lead
-- station's Independent Emergency Operation by accepting explicit acquisition
-- jobs.  Jobs are assigned by ID, assistants use the existing acquisition
-- ladder to obtain their assigned item, then transfer the result back to the
-- lead station when both stations are still in cooperative range.  This remains
-- intentionally conservative: no remote building, no forced theft from busy
-- priests, and no attempt to override active repair/consecration/combat work.
TECH_PRIESTS_TASK_FORCE_ASSIGNMENT_COOLDOWN_0187 = 60 * 12
TECH_PRIESTS_TASK_FORCE_JOB_TIMEOUT_0187 = 60 * 120
TECH_PRIESTS_TASK_FORCE_MAX_JOBS_0187 = 3
TECH_PRIESTS_TASK_FORCE_MAX_ASSIST_DISTANCE_MULT_0187 = 1.50
TECH_PRIESTS_TASK_FORCE_SERVICE_SPACING_0187 = 30

function tech_priests_pair_key_0187(pair)
  if pair and pair.station_unit then return pair.station_unit end
  if pair and pair.station and pair.station.valid then return pair.station.unit_number end
  return nil
end

function tech_priests_pair_distance_sq_0187(a, b)
  if not (a and b and a.station and a.station.valid and b.station and b.station.valid) then return 999999999 end
  local dx = a.station.position.x - b.station.position.x
  local dy = a.station.position.y - b.station.position.y
  return dx * dx + dy * dy
end

function tech_priests_is_pair_available_for_task_force_0187(pair)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  if pair.dead or pair.recalling or pair.deploying then return false end
  if pair.repair_target or pair.consecration_target or pair.combat_target then return false end
  if pair.emergency_assist_job_0187 then return false end
  if pair.emergency_craft or pair.scavenge then return false end
  local op = pair.independent_emergency_operation_0184
  if op and op.construction then return false end
  return true
end

function tech_priests_find_task_force_assistants_0187(lead_pair, limit)
  local result = {}
  if not (lead_pair and lead_pair.station and lead_pair.station.valid and storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return result end
  local base_radius = (refresh_pair_radius(lead_pair) or 20) * TECH_PRIESTS_TASK_FORCE_MAX_ASSIST_DISTANCE_MULT_0187
  for _, other in pairs(storage.tech_priests.pairs_by_station or {}) do
    if other ~= lead_pair and tech_priests_is_pair_available_for_task_force_0187(other) then
      if other.station.surface == lead_pair.station.surface and other.station.force == lead_pair.station.force then
        local other_radius = (refresh_pair_radius(other) or 20) * TECH_PRIESTS_TASK_FORCE_MAX_ASSIST_DISTANCE_MULT_0187
        local allowed = math.max(base_radius, other_radius)
        local dist_sq = tech_priests_pair_distance_sq_0187(lead_pair, other)
        if dist_sq <= allowed * allowed then
          result[#result + 1] = { pair = other, dist_sq = dist_sq }
        end
      end
    end
  end
  table.sort(result, function(a, b) return (a.dist_sq or 0) < (b.dist_sq or 0) end)
  while #result > (limit or TECH_PRIESTS_TASK_FORCE_MAX_JOBS_0187) do table.remove(result) end
  return result
end

function tech_priests_missing_task_force_components_0187(pair, item_name, count)
  local result = {}
  if not item_name then return result end
  local inv = pair and pair.station and pair.station.valid and get_station_inventory(pair.station) or nil
  local ingredients = tech_priests_get_recipe_ingredients_for_item_0185 and tech_priests_get_recipe_ingredients_for_item_0185(item_name) or {}
  if #ingredients == 0 then
    local have = inv and inv.get_item_count(item_name) or 0
    if have < math.max(1, count or 1) then
      result[#result + 1] = { name = item_name, count = math.max(1, (count or 1) - have) }
    end
    return result
  end
  for _, ingredient in pairs(ingredients) do
    local name = ingredient.name
    local required = math.max(1, ingredient.count or 1)
    local have = inv and inv.get_item_count(name) or 0
    if name and have < required then
      result[#result + 1] = { name = name, count = math.max(1, required - have) }
    end
  end
  table.sort(result, function(a, b)
    if (a.count or 1) ~= (b.count or 1) then return (a.count or 1) > (b.count or 1) end
    return tostring(a.name) < tostring(b.name)
  end)
  return result
end

function tech_priests_transfer_between_station_inventories_0187(from_pair, to_pair, item_name, count)
  if not (from_pair and to_pair and from_pair.station and from_pair.station.valid and to_pair.station and to_pair.station.valid and item_name) then return 0 end
  local from_inv = get_station_inventory(from_pair.station)
  local to_inv = get_station_inventory(to_pair.station)
  if not (from_inv and to_inv) then return 0 end
  local available = from_inv.get_item_count(item_name)
  local take = math.min(math.max(1, count or 1), available, get_item_stack_size(item_name))
  if take <= 0 then return 0 end
  if get_insertable_item_count then
    take = get_insertable_item_count(to_inv, item_name, take)
    if take <= 0 then return 0 end
  end
  local removed = from_inv.remove({ name = item_name, count = take }) or 0
  if removed <= 0 then return 0 end
  local inserted = to_inv.insert({ name = item_name, count = removed }) or 0
  if inserted < removed then from_inv.insert({ name = item_name, count = removed - inserted }) end
  return inserted
end

function tech_priests_task_force_snippet_0187(pair, text)
  if not (pair and pair.priest and pair.priest.valid and text) then return end
  if rendering and rendering.draw_text then
    pcall(function()
      rendering.draw_text({
        text = text,
        target = pair.priest,
        target_offset = { 0, -2.4 },
        surface = pair.priest.surface,
        color = { r = 1.0, g = 0.78, b = 0.22, a = 0.95 },
        scale = 0.70,
        alignment = "center",
        time_to_live = 60 * 5
      })
    end)
  end
end

function tech_priests_make_task_force_job_id_0187(lead_pair, assistant_pair, item_name)
  local lead = tech_priests_pair_key_0187(lead_pair) or 0
  local assistant = tech_priests_pair_key_0187(assistant_pair) or 0
  return tostring(game.tick) .. ":" .. tostring(lead) .. ":" .. tostring(assistant) .. ":" .. tostring(item_name)
end

function tech_priests_assign_task_force_jobs_0187(lead_pair, item_name, op, count, depth)
  if not (lead_pair and lead_pair.station and lead_pair.station.valid and item_name and op) then return false end
  depth = depth or 0
  if depth > 2 then return false end
  if op.task_force_item_0187 == item_name and game.tick < (op.task_force_next_assignment_tick_0187 or 0) then return false end
  local missing = tech_priests_missing_task_force_components_0187(lead_pair, item_name, count)
  if #missing == 0 then return false end
  local assistants = tech_priests_find_task_force_assistants_0187(lead_pair, math.min(#missing, TECH_PRIESTS_TASK_FORCE_MAX_JOBS_0187))
  if #assistants == 0 then return false end

  op.task_force_jobs_0187 = op.task_force_jobs_0187 or {}
  op.task_force_item_0187 = item_name
  op.task_force_next_assignment_tick_0187 = game.tick + TECH_PRIESTS_TASK_FORCE_ASSIGNMENT_COOLDOWN_0187
  op.task_force_generation_0187 = (op.task_force_generation_0187 or 0) + 1

  local assigned = 0
  for i = 1, math.min(#missing, #assistants, TECH_PRIESTS_TASK_FORCE_MAX_JOBS_0187) do
    local target = missing[i]
    local assistant_pair = assistants[i].pair
    if target and target.name and assistant_pair and not assistant_pair.emergency_assist_job_0187 then
      local job_id = tech_priests_make_task_force_job_id_0187(lead_pair, assistant_pair, target.name)
      local job = {
        id = job_id,
        lead_station_unit = tech_priests_pair_key_0187(lead_pair),
        assistant_station_unit = tech_priests_pair_key_0187(assistant_pair),
        item_name = target.name,
        count = math.max(1, target.count or 1),
        parent_item = item_name,
        assigned_tick = game.tick,
        timeout_tick = game.tick + TECH_PRIESTS_TASK_FORCE_JOB_TIMEOUT_0187,
        status = "assigned"
      }
      op.task_force_jobs_0187[job_id] = job
      assistant_pair.emergency_assist_job_0187 = job
      assistant_pair.emergency_assist_op_0187 = {
        enabled = true,
        site = tech_priests_find_emergency_operation_site_0184 and tech_priests_find_emergency_operation_site_0184(assistant_pair) or nil,
        next_tick = 0,
        phase = "task-force-assist",
        parent_lead_station_unit = job.lead_station_unit
      }
      assigned = assigned + 1
      tech_priests_task_force_snippet_0187(lead_pair, "[item=" .. target.name .. "] Task-force writ " .. tostring(job_id) .. " issued.")
      tech_priests_task_force_snippet_0187(assistant_pair, "[item=" .. target.name .. "] Writ " .. tostring(job_id) .. " accepted. Scrounging begins.")
      if tech_priests_play_task_sound_0177 then tech_priests_play_task_sound_0177(assistant_pair, "logistics_request", assistant_pair.station.position, 60 * 3, 0.40) end
    end
  end
  if assigned > 0 then
    op.phase = "task-force-assignment"
    op.last_item = item_name
    op.last_action_tick = game.tick
    tech_priests_draw_emergency_operation_status_0184(lead_pair, "[item=" .. item_name .. "] emergency task force assigned: " .. tostring(assigned) .. " writs")
    return true
  end
  return false
end

function tech_priests_service_task_force_assist_job_0187(pair)
  local job = pair and pair.emergency_assist_job_0187 or nil
  if not job then return false end
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  local lead_pair = nil
  if job.lead_station_unit and storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
    lead_pair = storage.tech_priests.pairs_by_station[job.lead_station_unit]
  end
  if not (lead_pair and lead_pair.station and lead_pair.station.valid and lead_pair.station.surface == pair.station.surface and lead_pair.station.force == pair.station.force) then
    pair.emergency_assist_job_0187 = nil
    pair.emergency_assist_op_0187 = nil
    return false
  end
  if game.tick > (job.timeout_tick or 0) then
    tech_priests_task_force_snippet_0187(pair, "[item=" .. tostring(job.item_name) .. "] Writ " .. tostring(job.id) .. " expired. Returning to doctrine.")
    pair.emergency_assist_job_0187 = nil
    pair.emergency_assist_op_0187 = nil
    return false
  end
  if game.tick < (job.next_service_tick or 0) then return true end
  job.next_service_tick = game.tick + TECH_PRIESTS_TASK_FORCE_SERVICE_SPACING_0187

  local own_inv = get_station_inventory(pair.station)
  local lead_inv = get_station_inventory(lead_pair.station)
  if not (own_inv and lead_inv and job.item_name) then return true end

  if own_inv.get_item_count(job.item_name) >= math.max(1, job.count or 1) then
    local moved = tech_priests_transfer_between_station_inventories_0187(pair, lead_pair, job.item_name, job.count)
    if moved > 0 then
      tech_priests_task_force_snippet_0187(pair, "[item=" .. job.item_name .. "] Writ " .. tostring(job.id) .. " fulfilled.")
      tech_priests_task_force_snippet_0187(lead_pair, "[item=" .. job.item_name .. "] Writ " .. tostring(job.id) .. " received from station " .. tostring(tech_priests_pair_key_0187(pair)) .. ".")
      local lead_op = lead_pair.independent_emergency_operation_0184
      if lead_op and lead_op.task_force_jobs_0187 then lead_op.task_force_jobs_0187[job.id] = nil end
      pair.emergency_assist_job_0187 = nil
      pair.emergency_assist_op_0187 = nil
      if tech_priests_play_task_sound_0177 then tech_priests_play_task_sound_0177(pair, "scavenge_pickup", pair.station.position, 60 * 3, 0.45) end
      return true
    end
  end

  pair.mode = "emergency-task-force-assist"
  local assist_op = pair.emergency_assist_op_0187 or { enabled = true, next_tick = 0, phase = "task-force-assist" }
  pair.emergency_assist_op_0187 = assist_op
  assist_op.last_item = job.item_name
  assist_op.parent_lead_station_unit = job.lead_station_unit
  tech_priests_task_force_snippet_0187(pair, "[item=" .. job.item_name .. "] Writ " .. tostring(job.id) .. " acquisition in progress.")
  return tech_priests_emergency_operation_acquire_item_0185(pair, job.item_name, assist_op, math.max(1, job.count or 1), 0) or true
end

tech_priests_original_acquire_item_0187 = tech_priests_emergency_operation_acquire_item_0185
function tech_priests_emergency_operation_acquire_item_0185(pair, item_name, op, count, depth)
  depth = depth or 0
  if op and not op.parent_lead_station_unit and item_name and depth <= 1 then
    tech_priests_assign_task_force_jobs_0187(pair, item_name, op, count or 1, depth)
  end
  return tech_priests_original_acquire_item_0187(pair, item_name, op, count, depth)
end

tech_priests_original_tick_pair_0187 = tick_pair
function tick_pair(pair)
  if tech_priests_service_task_force_assist_job_0187(pair) then return true end
  return tech_priests_original_tick_pair_0187(pair)
end


-- 0.1.188 seniority-aware emergency task-force and instructional vox logging.
-- Seniority now shapes emergency doctrine naturally: senior Tech-Priests prefer
-- to coordinate construction-class writs, juniors are preferred for raw mining
-- and base mineral scrounging, and intermediate priests fill the gap when a
-- proper subordinate is unavailable.  Conversation completion is also echoed to
-- force chat with enough location/surface context for debugging and storytelling.
TECH_PRIESTS_TASK_FORCE_ASSIGNMENT_COOLDOWN_0188 = 60 * 10
TECH_PRIESTS_TASK_FORCE_JOB_TIMEOUT_0188 = 60 * 150
TECH_PRIESTS_TASK_FORCE_MAX_JOBS_0188 = 4
TECH_PRIESTS_TASK_FORCE_MAX_ASSIST_DISTANCE_MULT_0188 = 1.75

function tech_priests_pair_rank_name_0188(pair)
  if tech_priests_get_pair_tier_name_0167 then return tech_priests_get_pair_tier_name_0167(pair) end
  if pair and pair.tier then return pair.tier end
  return "junior"
end

function tech_priests_pair_rank_value_0188(pair)
  local r = tech_priests_pair_rank_name_0188(pair)
  if r == "senior" then return 3 end
  if r == "intermediate" then return 2 end
  return 1
end

function tech_priests_pair_key_0188(pair)
  if pair and pair.station_unit then return pair.station_unit end
  if pair and pair.station and pair.station.valid then return pair.station.unit_number end
  return 0
end

function tech_priests_rank_title_0188(pair)
  local r = tech_priests_pair_rank_name_0188(pair)
  if r == "senior" then return "Senior Tech-Priest" end
  if r == "intermediate" then return "Intermediate Tech-Priest" end
  return "Junior Tech-Priest"
end

function tech_priests_station_coord_0188(pair)
  if pair and pair.station and pair.station.valid then
    return tostring(math.floor(pair.station.position.x + 0.5)) .. "," .. tostring(math.floor(pair.station.position.y + 0.5))
  end
  if pair and pair.priest and pair.priest.valid then
    return tostring(math.floor(pair.priest.position.x + 0.5)) .. "," .. tostring(math.floor(pair.priest.position.y + 0.5))
  end
  return "?,?"
end

function tech_priests_surface_name_0188(pair)
  if pair and pair.station and pair.station.valid and pair.station.surface then return pair.station.surface.name end
  if pair and pair.priest and pair.priest.valid and pair.priest.surface then return pair.priest.surface.name end
  return "unknown-surface"
end

function tech_priests_pair_label_0188(pair)
  return tech_priests_rank_title_0188(pair) .. " #" .. tostring(tech_priests_pair_key_0188(pair))
end

function tech_priests_force_print_0188(pair, message)
  if not (pair and pair.station and pair.station.valid and pair.station.force and message) then return end
  pcall(function() pair.station.force.print(message) end)
end

function tech_priests_vox_print_conversation_0188(speaker_pair, listener_label, text)
  if not (speaker_pair and speaker_pair.station and speaker_pair.station.valid and text and text ~= "") then return end
  local key = tostring(tech_priests_pair_key_0188(speaker_pair)) .. ":" .. tostring(listener_label) .. ":" .. tostring(text)
  if speaker_pair.last_vox_line_key_0188 == key and game.tick < (speaker_pair.last_vox_line_tick_0188 or 0) + 60 * 3 then return end
  speaker_pair.last_vox_line_key_0188 = key
  speaker_pair.last_vox_line_tick_0188 = game.tick
  local prefix = "[Tech-Priest Vox][" .. tech_priests_surface_name_0188(speaker_pair) .. " @ " .. tech_priests_station_coord_0188(speaker_pair) .. "][" .. tech_priests_pair_label_0188(speaker_pair) .. " -> " .. tostring(listener_label or "unknown listener") .. "] "
  tech_priests_force_print_0188(speaker_pair, prefix .. tostring(text))
end

function tech_priests_is_raw_acquisition_item_0188(item_name)
  if not item_name then return false end
  local raw = {
    wood = true, stone = true, coal = true, ["iron-ore"] = true, ["copper-ore"] = true,
    ["uranium-ore"] = true, scrap = true, sand = true, clay = true, ["raw-fish"] = true
  }
  if raw[item_name] then return true end
  local lower = string.lower(tostring(item_name))
  if string.find(lower, "ore", 1, true) or string.find(lower, "stone", 1, true) or string.find(lower, "scrap", 1, true) then return true end
  if string.find(lower, "wood", 1, true) or string.find(lower, "coal", 1, true) or string.find(lower, "mineral", 1, true) then return true end
  return false
end

function tech_priests_is_construction_item_0188(item_name, parent_item)
  local name = tostring(item_name or "")
  local parent = tostring(parent_item or "")
  if string.find(name, "tech%-priests%-emergency", 1) then return true end
  if string.find(parent, "tech%-priests%-emergency", 1) then return true end
  local proto = get_item_prototype(name)
  if proto and proto.place_result then return true end
  return false
end

function tech_priests_task_role_0188(item_name, parent_item)
  if tech_priests_is_raw_acquisition_item_0188(item_name) then return "raw-resource" end
  if tech_priests_is_construction_item_0188(item_name, parent_item) then return "construction" end
  return "component"
end

function tech_priests_role_priority_0188(lead_pair, assistant_pair, role)
  local ar = tech_priests_pair_rank_value_0188(assistant_pair)
  local lr = tech_priests_pair_rank_value_0188(lead_pair)
  local score = 0
  if role == "raw-resource" then
    -- Juniors naturally get the shovel-and-prayer jobs; seniors are preserved
    -- for coordination/construction unless no subordinate exists.
    score = ({ [1] = 0, [2] = 20, [3] = 60 })[ar] or 50
    if ar < lr then score = score - 10 end
  elseif role == "construction" then
    -- Construction doctrine prefers senior handling, then intermediates, with
    -- juniors used only if the emergency is truly pathetic.
    score = ({ [3] = 0, [2] = 20, [1] = 80 })[ar] or 50
  else
    -- Components are natural intermediate labor, but subordinates still take
    -- precedence over the lead doing everything alone.
    score = ({ [2] = 0, [1] = 15, [3] = 30 })[ar] or 50
    if ar < lr then score = score - 5 end
  end
  return score
end

function tech_priests_pair_available_for_seniority_task_force_0188(pair)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  if pair.dead or pair.recalling or pair.deploying then return false end
  if pair.repair_target or pair.consecration_target or pair.combat_target then return false end
  if pair.emergency_assist_job_0187 then return false end
  if pair.emergency_craft or pair.scavenge then return false end
  if pair.idle_conversation or pair.idle_player_conversation_0181 then return false end
  local op = pair.independent_emergency_operation_0184
  if op and op.construction then return false end
  return true
end

function tech_priests_find_seniority_assistants_0188(lead_pair, role, limit)
  local result = {}
  if not (lead_pair and lead_pair.station and lead_pair.station.valid and storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return result end
  local base_radius = (refresh_pair_radius(lead_pair) or 20) * TECH_PRIESTS_TASK_FORCE_MAX_ASSIST_DISTANCE_MULT_0188
  for _, other in pairs(storage.tech_priests.pairs_by_station or {}) do
    if other ~= lead_pair and tech_priests_pair_available_for_seniority_task_force_0188(other) then
      if other.station and other.station.valid and other.station.surface == lead_pair.station.surface and other.station.force == lead_pair.station.force then
        local dx = other.station.position.x - lead_pair.station.position.x
        local dy = other.station.position.y - lead_pair.station.position.y
        local dist_sq = dx * dx + dy * dy
        if dist_sq <= base_radius * base_radius then
          result[#result + 1] = { pair = other, dist_sq = dist_sq, role_score = tech_priests_role_priority_0188(lead_pair, other, role) }
        end
      end
    end
  end
  table.sort(result, function(a, b)
    if (a.role_score or 0) ~= (b.role_score or 0) then return (a.role_score or 0) < (b.role_score or 0) end
    return (a.dist_sq or 0) < (b.dist_sq or 0)
  end)
  while #result > (limit or TECH_PRIESTS_TASK_FORCE_MAX_JOBS_0188) do table.remove(result) end
  return result
end

function tech_priests_recipe_missing_components_0188(pair, item_name, count)
  local result = {}
  if not item_name then return result end
  local inv = pair and pair.station and pair.station.valid and get_station_inventory(pair.station) or nil
  local ingredients = tech_priests_get_recipe_ingredients_for_item_0185 and tech_priests_get_recipe_ingredients_for_item_0185(item_name) or {}
  if #ingredients == 0 then
    local have = inv and inv.get_item_count(item_name) or 0
    if have < math.max(1, count or 1) then result[#result + 1] = { name = item_name, count = math.max(1, (count or 1) - have) } end
    return result
  end
  for _, ingredient in pairs(ingredients) do
    local name = ingredient.name
    local required = math.max(1, ingredient.count or 1)
    local have = inv and inv.get_item_count(name) or 0
    if name and have < required then result[#result + 1] = { name = name, count = math.max(1, required - have) } end
  end
  table.sort(result, function(a, b)
    local ra = tech_priests_task_role_0188(a.name, item_name)
    local rb = tech_priests_task_role_0188(b.name, item_name)
    if ra ~= rb then return ra == "raw-resource" end
    if (a.count or 1) ~= (b.count or 1) then return (a.count or 1) > (b.count or 1) end
    return tostring(a.name) < tostring(b.name)
  end)
  return result
end

function tech_priests_make_task_force_job_id_0188(lead_pair, assistant_pair, item_name, role)
  return tostring(game.tick) .. ":0188:" .. tostring(tech_priests_pair_key_0188(lead_pair)) .. ":" .. tostring(tech_priests_pair_key_0188(assistant_pair)) .. ":" .. tostring(role) .. ":" .. tostring(item_name)
end

function tech_priests_task_force_snippet_0188(pair, text)
  if tech_priests_task_force_snippet_0187 then return tech_priests_task_force_snippet_0187(pair, text) end
  if not (pair and pair.priest and pair.priest.valid and rendering and rendering.draw_text) then return end
  pcall(function()
    rendering.draw_text({ text = text, target = pair.priest, target_offset = { 0, -2.4 }, surface = pair.priest.surface, color = { r = 1, g = 0.78, b = 0.22, a = 0.95 }, scale = 0.70, alignment = "center", time_to_live = 60 * 5 })
  end)
end

function tech_priests_seniority_job_phrase_0188(role, lead_pair, assistant_pair, item_name, job_id)
  local lead_rank = tech_priests_pair_rank_name_0188(lead_pair)
  local assistant_rank = tech_priests_pair_rank_name_0188(assistant_pair)
  if role == "raw-resource" then
    return "[item=" .. item_name .. "] Writ " .. tostring(job_id) .. ": " .. assistant_rank .. " subordinate assigned to base mineral acquisition. Bring raw offerings to the lead shrine."
  elseif role == "construction" then
    if assistant_rank == "senior" then
      return "[item=" .. item_name .. "] Writ " .. tostring(job_id) .. ": senior construction doctrine delegated. Establish the emergency workpiece."
    end
    return "[item=" .. item_name .. "] Writ " .. tostring(job_id) .. ": construction support assigned under senior oversight. Acquire and stage the machine component."
  end
  return "[item=" .. item_name .. "] Writ " .. tostring(job_id) .. ": component acquisition assigned by " .. lead_rank .. " doctrine."
end

function tech_priests_assign_seniority_task_force_jobs_0188(lead_pair, item_name, op, count, depth)
  if not (lead_pair and lead_pair.station and lead_pair.station.valid and item_name and op) then return false end
  depth = depth or 0
  if depth > 2 then return false end
  if op.task_force_item_0187 == item_name and game.tick < (op.task_force_next_assignment_tick_0187 or 0) then return false end
  local missing = tech_priests_recipe_missing_components_0188(lead_pair, item_name, count)
  if #missing == 0 then return false end

  op.task_force_jobs_0187 = op.task_force_jobs_0187 or {}
  op.task_force_item_0187 = item_name
  op.task_force_next_assignment_tick_0187 = game.tick + TECH_PRIESTS_TASK_FORCE_ASSIGNMENT_COOLDOWN_0188
  op.task_force_generation_0187 = (op.task_force_generation_0187 or 0) + 1

  local assigned = 0
  local already_assigned = {}
  for _, target in pairs(missing) do
    if assigned >= TECH_PRIESTS_TASK_FORCE_MAX_JOBS_0188 then break end
    local role = tech_priests_task_role_0188(target.name, item_name)
    local assistants = tech_priests_find_seniority_assistants_0188(lead_pair, role, TECH_PRIESTS_TASK_FORCE_MAX_JOBS_0188)
    local assistant_pair = nil
    for _, candidate in pairs(assistants) do
      local key = tech_priests_pair_key_0188(candidate.pair)
      if not already_assigned[key] then assistant_pair = candidate.pair; already_assigned[key] = true; break end
    end
    if assistant_pair and not assistant_pair.emergency_assist_job_0187 then
      local job_id = tech_priests_make_task_force_job_id_0188(lead_pair, assistant_pair, target.name, role)
      local job = {
        id = job_id,
        lead_station_unit = tech_priests_pair_key_0188(lead_pair),
        assistant_station_unit = tech_priests_pair_key_0188(assistant_pair),
        item_name = target.name,
        count = math.max(1, target.count or 1),
        parent_item = item_name,
        role = role,
        seniority_doctrine_0188 = true,
        assigned_tick = game.tick,
        timeout_tick = game.tick + TECH_PRIESTS_TASK_FORCE_JOB_TIMEOUT_0188,
        status = "assigned"
      }
      op.task_force_jobs_0187[job_id] = job
      assistant_pair.emergency_assist_job_0187 = job
      assistant_pair.emergency_assist_op_0187 = {
        enabled = true,
        site = tech_priests_find_emergency_operation_site_0184 and tech_priests_find_emergency_operation_site_0184(assistant_pair) or nil,
        next_tick = 0,
        phase = "task-force-assist",
        parent_lead_station_unit = job.lead_station_unit
      }
      assigned = assigned + 1
      local assignment_line = tech_priests_seniority_job_phrase_0188(role, lead_pair, assistant_pair, target.name, job_id)
      tech_priests_task_force_snippet_0188(lead_pair, "[item=" .. target.name .. "] Seniority writ issued: " .. tostring(role) .. ".")
      tech_priests_task_force_snippet_0188(assistant_pair, assignment_line)
      tech_priests_vox_print_conversation_0188(lead_pair, tech_priests_pair_label_0188(assistant_pair), assignment_line)
      if tech_priests_play_task_sound_0177 then tech_priests_play_task_sound_0177(assistant_pair, "logistics_request", assistant_pair.station.position, 60 * 3, 0.40) end
    end
  end
  if assigned > 0 then
    op.phase = "seniority-task-force-assignment"
    op.last_item = item_name
    op.last_action_tick = game.tick
    if tech_priests_draw_emergency_operation_status_0184 then
      tech_priests_draw_emergency_operation_status_0184(lead_pair, "[item=" .. item_name .. "] seniority-aware task force assigned: " .. tostring(assigned) .. " writs")
    end
    return true
  end
  return false
end

-- Supersede the 0.1.187 acquisition wrapper by assigning seniority-aware writs
-- first and setting the same cooldown fields the earlier layer respects.  The
-- old layer remains available as a fallback when no suitable subordinate exists.
tech_priests_original_acquire_item_0188 = tech_priests_emergency_operation_acquire_item_0185
function tech_priests_emergency_operation_acquire_item_0185(pair, item_name, op, count, depth)
  depth = depth or 0
  if op and not op.parent_lead_station_unit and item_name and depth <= 1 then
    tech_priests_assign_seniority_task_force_jobs_0188(pair, item_name, op, count or 1, depth)
  end
  return tech_priests_original_acquire_item_0188(pair, item_name, op, count, depth)
end

-- Add doctrine snippets to existing assistant service without replacing its
-- actual transfer/acquisition logic.
tech_priests_original_tick_pair_0188 = tick_pair
function tick_pair(pair)
  if pair and pair.emergency_assist_job_0187 and pair.emergency_assist_job_0187.seniority_doctrine_0188 then
    local job = pair.emergency_assist_job_0187
    if game.tick >= (job.next_seniority_vox_tick_0188 or 0) then
      job.next_seniority_vox_tick_0188 = game.tick + 60 * 18
      local role = job.role or tech_priests_task_role_0188(job.item_name, job.parent_item)
      local line
      if role == "raw-resource" then
        line = "[item=" .. tostring(job.item_name) .. "] Junior doctrine engaged: raw acquisition proceeds in humiliating but necessary increments."
      elseif role == "construction" then
        line = "[item=" .. tostring(job.item_name) .. "] Construction doctrine acknowledged: staging materials for emergency machine deployment."
      else
        line = "[item=" .. tostring(job.item_name) .. "] Component doctrine acknowledged: subordinate acquisition continues."
      end
      tech_priests_task_force_snippet_0188(pair, line)
    end
  end
  return tech_priests_original_tick_pair_0188(pair)
end

-- Print completed Tech-Priest-to-Tech-Priest conversation lines to chat with
-- surface and station context.  This intentionally prints only when the full
-- typewriter line has completed, avoiding one-character spam.
tech_priests_original_update_idle_conversation_behavior_0188 = update_idle_conversation_behavior
function update_idle_conversation_behavior(pair)
  local before_convo = pair and pair.idle_conversation or nil
  local before_phase = before_convo and before_convo.phase or nil
  local before_complete = before_convo and before_convo.phase_complete_tick or nil
  local result = tech_priests_original_update_idle_conversation_behavior_0188(pair)
  local convo = pair and pair.idle_conversation or nil
  if convo and convo.phase_complete_tick and convo.phase_complete_tick == game.tick and (before_complete ~= convo.phase_complete_tick or before_phase ~= convo.phase) then
    local listener_pair = convo.listener_station_unit and tech_priests_get_pair_by_station_unit_0179 and tech_priests_get_pair_by_station_unit_0179(convo.listener_station_unit) or nil
    if convo.phase == 1 then
      tech_priests_vox_print_conversation_0188(pair, listener_pair and tech_priests_pair_label_0188(listener_pair) or "unknown Tech-Priest", convo.speaker_line or "...")
    else
      tech_priests_vox_print_conversation_0188(listener_pair or pair, pair and tech_priests_pair_label_0188(pair) or "unknown Tech-Priest", convo.response_line or "...")
    end
  end
  return result
end

-- Print direct player-address conversations once their typewriter line has
-- completed.  The listener label uses the same High Fabricator / Archmagos
-- address already selected by the player conversation layer.
if tech_priests_update_idle_player_conversation_0181 then
  tech_priests_original_update_idle_player_conversation_0188 = tech_priests_update_idle_player_conversation_0181
  function tech_priests_update_idle_player_conversation_0181(pair)
    local before = pair and pair.idle_player_conversation_0181 or nil
    local before_complete = before and before.phase_complete_tick or nil
    local result = tech_priests_original_update_idle_player_conversation_0188(pair)
    local convo = pair and pair.idle_player_conversation_0181 or nil
    if convo and convo.phase_complete_tick and convo.phase_complete_tick == game.tick and before_complete ~= convo.phase_complete_tick then
      local player = convo.player_index and game.get_player(convo.player_index) or nil
      local label = player and player.valid and tech_priests_format_player_address_0170 and tech_priests_format_player_address_0170(player) or "Archmagos"
      tech_priests_vox_print_conversation_0188(pair, label, convo.line or "...")
    end
    return result
  end
end


-- 0.1.189 Tech-Priest Command Overview.
-- Factorio does not expose the internal train-overview GUI for cloning, so this
-- is a custom force-wide command screen opened with Shift+O.  It provides a
-- sortable/readable roster, per-priest task summaries, station/surface context,
-- and a small camera pane centered on the selected priest/station.
TECH_PRIESTS_COMMAND_OVERVIEW_FRAME_0189 = "tech_priests_command_overview_0189"
TECH_PRIESTS_COMMAND_OVERVIEW_PREFIX_0189 = "tech_priests_command_select_0189_"
TECH_PRIESTS_COMMAND_OVERVIEW_CLOSE_0189 = "tech_priests_command_overview_close_0189"
TECH_PRIESTS_COMMAND_OVERVIEW_REFRESH_0189 = "tech_priests_command_overview_refresh_0189"
TECH_PRIESTS_COMMAND_OVERVIEW_EMERGENCY_TOGGLE_0190 = "tech_priests_command_overview_emergency_toggle_0190"
TECH_PRIESTS_COMMAND_OVERVIEW_EMERGENCY_AUTO_0190 = "tech_priests_command_overview_emergency_auto_0190"
TECH_PRIESTS_COMMAND_OVERVIEW_TABS_0371 = "tech_priests_command_overview_tabs_0371"

function tech_priests_command_overview_tab_storage_0371()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.command_overview_tab_0371 = storage.tech_priests.command_overview_tab_0371 or {}
  return storage.tech_priests.command_overview_tab_0371
end

function tech_priests_command_overview_selected_tab_0371(player)
  local map = tech_priests_command_overview_tab_storage_0371()
  return tostring(map[player.index] or "roster")
end

function tech_priests_command_overview_set_selected_tab_0371(player, tab_key)
  if not (player and player.valid) then return end
  tech_priests_command_overview_tab_storage_0371()[player.index] = tostring(tab_key or "roster")
end

function tech_priests_command_overview_storage_0189()
  ensure_storage()
  storage.tech_priests.command_overview_selected_0189 = storage.tech_priests.command_overview_selected_0189 or {}
  return storage.tech_priests.command_overview_selected_0189
end

function tech_priests_destroy_command_overview_0189(player)
  if player and player.valid and player.gui and player.gui.screen then
    local frame = player.gui.screen[TECH_PRIESTS_COMMAND_OVERVIEW_FRAME_0189]
    if frame and frame.valid then frame.destroy() end
  end
end

function tech_priests_surface_name_0189(surface_index)
  local surface = surface_index and game.surfaces[surface_index] or nil
  return surface and surface.valid and surface.name or "unknown"
end

function tech_priests_pair_rank_label_0189(pair)
  local rank = nil
  if tech_priests_get_pair_tier_name_0167 then
    rank = tech_priests_get_pair_tier_name_0167(pair)
  elseif pair and pair.tier then
    rank = pair.tier
  end
  rank = tostring(rank or "junior")
  return string.upper(string.sub(rank, 1, 1)) .. string.sub(rank, 2)
end

function tech_priests_entity_coord_0189(entity)
  if not (entity and entity.valid and entity.position) then return "?,?" end
  return tostring(math.floor(entity.position.x + 0.5)) .. "," .. tostring(math.floor(entity.position.y + 0.5))
end

function tech_priests_station_unit_0189(pair)
  return pair and (pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number)) or nil
end

function tech_priests_pair_name_0189(pair)
  if not pair then return "Uncatalogued Cell" end
  if apply_pair_display_names then apply_pair_display_names(pair) end
  return pair.priest_display_name or ("Tech-Priest " .. tostring(get_pair_display_name and get_pair_display_name(pair) or tech_priests_station_unit_0189(pair) or "?"))
end

function tech_priests_station_name_0189(pair)
  if not pair then return "Uncatalogued Station" end
  if apply_pair_display_names then apply_pair_display_names(pair) end
  return pair.station_display_name or ("Cogitator Station #" .. tostring(tech_priests_station_unit_0189(pair) or "?"))
end

function tech_priests_item_tag_0189(name)
  if type(name) == "string" and name ~= "" then return "[item=" .. name .. "] " end
  return ""
end

function tech_priests_task_summary_0189(pair)
  if not pair then return "Uncatalogued" end
  if pair.idle_player_conversation_0181 then return "Addressing player" end
  if pair.idle_conversation or pair.idle_conversation_approach_0180 or pair.idle_conversation_speaker_station_unit then return "Conversing" end
  if pair.emergency_assist_job_0187 then
    local job = pair.emergency_assist_job_0187
    return "Assist writ " .. tostring(job.id or "?") .. " · " .. tech_priests_item_tag_0189(job.item_name) .. tostring(job.role or "acquire")
  end
  local overview_op_0190 = (tech_priests_get_emergency_operation_0184 and tech_priests_get_emergency_operation_0184(pair)) or pair.independent_emergency_operation_0184 or pair.emergency_operation_0184
  if overview_op_0190 and overview_op_0190.enabled then
    local op = overview_op_0190
    local need = op.need_item or op.last_item or op.current_item or op.target_item or op.science_pack
    return "Emergency Operation · " .. tostring(op.phase or "planning") .. (need and (" · " .. tech_priests_item_tag_0189(need) .. need) or "")
  end
  if pair.emergency_construction_0186 then
    local c = pair.emergency_construction_0186
    return "Emergency construction · " .. tech_priests_item_tag_0189(c.item_name) .. tostring(c.item_name or c.entity_name or "machine")
  end
  if pair.emergency_craft then
    local target = pair.emergency_craft.target_item or pair.emergency_craft.item_name or pair.emergency_craft.result
    return "Emergency fabrication · " .. tech_priests_item_tag_0189(target) .. tostring(target or "materials")
  end
  if pair.inventory_scan then
    local item = pair.inventory_scan.item_name or pair.inventory_scan.request_item or pair.inventory_scan.target_item
    return "Inventory scan · " .. tech_priests_item_tag_0189(item) .. tostring(item or "requested item")
  end
  if pair.scavenge then
    local item = pair.scavenge.item_name or pair.scavenge.request_item or pair.scavenge.target_item
    return "Scavenging · " .. tech_priests_item_tag_0189(item) .. tostring(item or "supplies")
  end
  if pair.cram then
    local item = pair.cram.item_name or pair.cram.target_item
    return "Cram disposal · " .. tech_priests_item_tag_0189(item) .. tostring(item or "station clutter")
  end
  if pair.logistic_request or pair.current_logistic_request then
    local req = pair.logistic_request or pair.current_logistic_request
    local item = type(req) == "table" and (req.name or req.item_name) or req
    return "Logistic request · " .. tech_priests_item_tag_0189(item) .. tostring(item or "supplies")
  end
  if pair.target and pair.target.valid then return "Working target · [entity=" .. pair.target.name .. "]" end
  if pair.combat_target and pair.combat_target.valid then return "Combat pressure · [entity=" .. pair.combat_target.name .. "]" end
  if pair.idle_scan then return "Idle machine inspection" end
  return tostring(pair.mode or "idle")
end

function tech_priests_pair_health_0189(entity)
  if not (entity and entity.valid and entity.health and entity.max_health and entity.max_health > 0) then return "—" end
  return tostring(math.floor((entity.health / entity.max_health) * 100 + 0.5)) .. "%"
end

function tech_priests_station_inventory_summary_0189(pair)
  if not (pair and pair.station and pair.station.valid and get_station_inventory) then return "—" end
  local inv = get_station_inventory(pair.station)
  if not inv or not inv.valid then return "—" end
  local contents = inv.get_contents()
  local parts = {}
  local n = 0
  for name, count in pairs(contents or {}) do
    n = n + 1
    if n <= 5 then parts[#parts + 1] = "[item=" .. name .. "]×" .. tostring(count) end
  end
  if n > 5 then parts[#parts + 1] = "+" .. tostring(n - 5) .. " more" end
  if #parts == 0 then return "empty" end
  return table.concat(parts, "  ")
end

function tech_priests_valid_pairs_for_player_0189(player)
  local rows = {}
  if not (player and player.valid and storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return rows end
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    if pair and pair.station and pair.station.valid and pair.station.force == player.force then
      rows[#rows + 1] = pair
    end
  end
  table.sort(rows, function(a, b)
    local sa = a.station and a.station.valid and a.station.surface and a.station.surface.name or ""
    local sb = b.station and b.station.valid and b.station.surface and b.station.surface.name or ""
    if sa ~= sb then return sa < sb end
    local ax = a.station and a.station.valid and a.station.position.x or 0
    local bx = b.station and b.station.valid and b.station.position.x or 0
    if ax ~= bx then return ax < bx end
    return (tech_priests_station_unit_0189(a) or 0) < (tech_priests_station_unit_0189(b) or 0)
  end)
  return rows
end

function tech_priests_get_selected_pair_0189(player, rows)
  local selected = tech_priests_command_overview_storage_0189()[player.index]
  if selected and storage.tech_priests.pairs_by_station[selected] then
    local pair = storage.tech_priests.pairs_by_station[selected]
    if pair and pair.station and pair.station.valid and pair.station.force == player.force then return pair end
  end
  return rows and rows[1] or nil
end

function tech_priests_add_labeled_line_0189(parent, label, value)
  local flow = parent.add({ type = "flow", direction = "horizontal" })
  flow.style.horizontally_stretchable = true
  local l = flow.add({ type = "label", caption = label })
  l.style.width = 120
  local v = flow.add({ type = "label", caption = value or "—" })
  v.style.single_line = false
  return v
end

function tech_priests_build_command_overview_0189(player)
  if not (player and player.valid) then return end
  tech_priests_destroy_command_overview_0189(player)
  local rows = tech_priests_valid_pairs_for_player_0189(player)
  local selected_pair = tech_priests_get_selected_pair_0189(player, rows)
  if selected_pair then tech_priests_command_overview_storage_0189()[player.index] = tech_priests_station_unit_0189(selected_pair) end

  local frame = player.gui.screen.add({ type = "frame", name = TECH_PRIESTS_COMMAND_OVERVIEW_FRAME_0189, direction = "vertical", caption = "Tech-Priest Command Overview" })
  frame.auto_center = true
  frame.style.width = 1120
  frame.style.height = 760
  frame.style.minimal_width = 1120
  frame.style.minimal_height = 760

  local top = frame.add({ type = "flow", direction = "horizontal" })
  top.style.horizontally_stretchable = true
  local title = top.add({ type = "label", caption = "[entity=senior-tech-priest] Force roster · Shift+Y" })
  title.style.horizontally_stretchable = true
  top.add({ type = "button", name = TECH_PRIESTS_COMMAND_OVERVIEW_REFRESH_0189, caption = "Refresh" })
  top.add({ type = "button", name = TECH_PRIESTS_COMMAND_OVERVIEW_CLOSE_0189, caption = "Close" })

  local body = frame.add({ type = "flow", direction = "horizontal" })
  body.style.vertically_stretchable = true
  body.style.horizontally_stretchable = true
  body.style.height = 640

  local left = body.add({ type = "scroll-pane", direction = "vertical" })
  left.style.width = 720
  left.style.height = 625
  left.style.maximal_height = 625
  left.style.vertically_stretchable = true
  left.style.horizontally_stretchable = false
  local table_el = left.add({ type = "table", column_count = 6 })
  table_el.add({ type = "label", caption = "Priest" })
  table_el.add({ type = "label", caption = "Rank" })
  table_el.add({ type = "label", caption = "Station" })
  table_el.add({ type = "label", caption = "Surface" })
  table_el.add({ type = "label", caption = "Location" })
  table_el.add({ type = "label", caption = "Current task" })

  if #rows == 0 then
    table_el.add({ type = "label", caption = "No active Cogitator Stations / Tech-Priests for this force." })
  else
    for _, pair in ipairs(rows) do
      local station_unit = tech_priests_station_unit_0189(pair) or 0
      local selected = selected_pair and station_unit == tech_priests_station_unit_0189(selected_pair)
      local btn = table_el.add({ type = "button", name = TECH_PRIESTS_COMMAND_OVERVIEW_PREFIX_0189 .. tostring(station_unit), caption = (selected and "▶ " or "") .. tech_priests_pair_name_0189(pair) })
      btn.style.width = 155
      table_el.add({ type = "label", caption = tech_priests_pair_rank_label_0189(pair) })
      table_el.add({ type = "label", caption = tech_priests_station_name_0189(pair) })
      table_el.add({ type = "label", caption = pair.station.surface.name })
      table_el.add({ type = "label", caption = tech_priests_entity_coord_0189(pair.station) })
      local task = table_el.add({ type = "label", caption = tech_priests_task_summary_0189(pair) })
      task.style.single_line = false
      task.style.width = 300
    end
  end

  local right = body.add({ type = "frame", direction = "vertical", caption = "Selected unit preview" })
  right.style.width = 360
  right.style.height = 625
  right.style.maximal_height = 625
  right.style.vertically_stretchable = false
  if selected_pair and selected_pair.station and selected_pair.station.valid then
    local preview_target = (selected_pair.priest and selected_pair.priest.valid and selected_pair.priest) or selected_pair.station
    local ok = pcall(function()
      local cam = right.add({
        type = "camera",
        name = "tech_priests_command_camera_0189",
        position = preview_target.position,
        surface_index = preview_target.surface.index,
        zoom = 0.45
      })
      cam.style.width = 335
      cam.style.height = 220
    end)
    if not ok then
      right.add({ type = "label", caption = "Camera preview unavailable in this runtime; use the coordinates below." })
    end
    tech_priests_add_labeled_line_0189(right, "Priest", tech_priests_pair_name_0189(selected_pair))
    tech_priests_add_labeled_line_0189(right, "Rank", tech_priests_pair_rank_label_0189(selected_pair))
    tech_priests_add_labeled_line_0189(right, "Station", tech_priests_station_name_0189(selected_pair))
    tech_priests_add_labeled_line_0189(right, "Surface", selected_pair.station.surface.name)
    tech_priests_add_labeled_line_0189(right, "Station coords", tech_priests_entity_coord_0189(selected_pair.station))
    tech_priests_add_labeled_line_0189(right, "Priest coords", tech_priests_entity_coord_0189(selected_pair.priest))
    tech_priests_add_labeled_line_0189(right, "Station health", tech_priests_pair_health_0189(selected_pair.station))
    tech_priests_add_labeled_line_0189(right, "Priest health", tech_priests_pair_health_0189(selected_pair.priest))
    tech_priests_add_labeled_line_0189(right, "Task", tech_priests_task_summary_0189(selected_pair))
    tech_priests_add_labeled_line_0189(right, "Inventory", tech_priests_station_inventory_summary_0189(selected_pair))
    local emergency_op_0190 = (tech_priests_get_emergency_operation_0184 and tech_priests_get_emergency_operation_0184(selected_pair)) or selected_pair.independent_emergency_operation_0184
    local emergency_status_0190 = emergency_op_0190 and "Independent / Emergency doctrine: ENABLED" or "Independent / Emergency doctrine: disabled"
    tech_priests_add_labeled_line_0189(right, "Emergency", emergency_status_0190)
    right.add({ type = "button", name = TECH_PRIESTS_COMMAND_OVERVIEW_EMERGENCY_TOGGLE_0190, caption = emergency_op_0190 and "Disable independent / emergency mode" or "Enable independent / emergency mode" })
    right.add({ type = "button", name = TECH_PRIESTS_COMMAND_OVERVIEW_EMERGENCY_AUTO_0190, caption = "Allow frustration auto-enable" })
    right.add({ type = "button", name = TECH_PRIESTS_COMMAND_OVERVIEW_PREFIX_0189 .. tostring(tech_priests_station_unit_0189(selected_pair) or 0) .. "_center", caption = "Mark selected priest in chat" })
  else
    right.add({ type = "label", caption = "No Tech-Priest selected." })
  end
end

function tech_priests_toggle_command_overview_0189(player)
  if not (player and player.valid) then return end
  local frame = player.gui.screen[TECH_PRIESTS_COMMAND_OVERVIEW_FRAME_0189]
  if frame and frame.valid then
    frame.destroy()
  else
    tech_priests_build_command_overview_0189(player)
  end
end

TechPriestsRuntimeEventRegistry.on_event("tech-priests-toggle-command-overview", function(event)
  local player = game.get_player(event.player_index)
  tech_priests_toggle_command_overview_0189(player)
end)

tech_priests_previous_on_gui_click_0189 = tech_priests_on_gui_click_0184
TechPriestsGuiRouter.register("click", function(event)
  if tech_priests_previous_on_gui_click_0189 then tech_priests_previous_on_gui_click_0189(event) end
  local element = event.element
  if not (element and element.valid) then return end
  local name = element.name or ""
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end
  if name == TECH_PRIESTS_COMMAND_OVERVIEW_CLOSE_0189 then
    tech_priests_destroy_command_overview_0189(player)
    return
  end
  if name == TECH_PRIESTS_COMMAND_OVERVIEW_REFRESH_0189 then
    tech_priests_build_command_overview_0189(player)
    return
  end
  if name == TECH_PRIESTS_COMMAND_OVERVIEW_EMERGENCY_TOGGLE_0190 then
    local rows = tech_priests_valid_pairs_for_player_0189(player)
    local pair = tech_priests_get_selected_pair_0189(player, rows)
    if pair and tech_priests_set_emergency_operation_0184 and tech_priests_get_emergency_operation_0184 then
      local enable = tech_priests_get_emergency_operation_0184(pair) == nil
      if tech_priests_set_emergency_operation_0184(pair, enable, "overview-ui") then
        player.print({ "", "[Tech-Priest Command] Independent / emergency doctrine ", enable and "enabled" or "disabled", " for ", tech_priests_station_name_0189(pair), "." })
      end
    end
    tech_priests_build_command_overview_0189(player)
    return
  end
  if name == TECH_PRIESTS_COMMAND_OVERVIEW_EMERGENCY_AUTO_0190 then
    local rows = tech_priests_valid_pairs_for_player_0189(player)
    local pair = tech_priests_get_selected_pair_0189(player, rows)
    if pair then
      pair.emergency_operation_auto_allowed_0190 = true
      player.print({ "", "[Tech-Priest Command] Frustration auto-enable is authorized for ", tech_priests_station_name_0189(pair), "." })
    end
    tech_priests_build_command_overview_0189(player)
    return
  end
  if string.sub(name, 1, #TECH_PRIESTS_COMMAND_OVERVIEW_PREFIX_0189) == TECH_PRIESTS_COMMAND_OVERVIEW_PREFIX_0189 then
    local rest = string.sub(name, #TECH_PRIESTS_COMMAND_OVERVIEW_PREFIX_0189 + 1)
    local center = false
    if string.sub(rest, -7) == "_center" then
      center = true
      rest = string.sub(rest, 1, -8)
    end
    local station_unit = tonumber(rest)
    if station_unit and storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
      local pair = storage.tech_priests.pairs_by_station[station_unit]
      if pair and pair.station and pair.station.valid and pair.station.force == player.force then
        tech_priests_command_overview_storage_0189()[player.index] = station_unit
        if tech_priests_command_overview_set_selected_tab_0371 then tech_priests_command_overview_set_selected_tab_0371(player, "roster") end
        if center and pair.priest and pair.priest.valid then
          player.print({ "", "[Tech-Priest Command] ", tech_priests_pair_name_0189(pair), " is on ", pair.priest.surface.name, " at ", tech_priests_entity_coord_0189(pair.priest), "." })
        end
        tech_priests_build_command_overview_0189(player)
      end
    end
  end
end)


-- 0.1.201 command overview sizing, spawn tile hygiene, and priest lifecycle diagnostics.
-- The roster window is deliberately fixed-height now so long dynamic tables stay
-- inside the panel background instead of visually spilling beyond it.  This pass
-- also rejects conveyor/belt tiles as spawn loci and replaces the old destructive
-- orphan-selected-priest purge with a repair-first diagnostic path.

TECH_PRIESTS_LIFECYCLE_DEBUG_LIMIT_0201 = 80
TECH_PRIESTS_BELTLIKE_TYPES_0201 = {
  ["transport-belt"] = true,
  ["underground-belt"] = true,
  ["splitter"] = true,
  ["loader"] = true,
  ["loader-1x1"] = true,
  ["linked-belt"] = true
}

function tech_priests_lifecycle_bucket_0201()
  ensure_storage()
  storage.tech_priests.priest_lifecycle_debug_0201 = storage.tech_priests.priest_lifecycle_debug_0201 or {}
  return storage.tech_priests.priest_lifecycle_debug_0201
end

function tech_priests_lifecycle_note_0201(pair, reason, entity, extra)
  local bucket = tech_priests_lifecycle_bucket_0201()
  local station = pair and pair.station and pair.station.valid and pair.station or nil
  local subject = entity and entity.valid and entity or (pair and pair.priest and pair.priest.valid and pair.priest) or station
  bucket[#bucket + 1] = {
    tick = game and game.tick or 0,
    reason = tostring(reason or "unknown"),
    station_unit = pair and pair.station_unit or (station and station.unit_number) or nil,
    priest_unit = subject and subject.valid and subject.unit_number or (pair and pair.priest_unit) or nil,
    surface = subject and subject.valid and subject.surface and subject.surface.name or station and station.surface and station.surface.name or "unknown",
    position = subject and subject.valid and { x = subject.position.x, y = subject.position.y } or nil,
    extra = tostring(extra or "")
  }
  while #bucket > TECH_PRIESTS_LIFECYCLE_DEBUG_LIMIT_0201 do table.remove(bucket, 1) end
end

function tech_priests_tile_has_beltlike_entity_0201(surface, position)
  if not (surface and position) then return false end
  local area = { { position.x - 0.49, position.y - 0.49 }, { position.x + 0.49, position.y + 0.49 } }
  local ok, entities = pcall(function() return surface.find_entities_filtered({ area = area }) end)
  if not (ok and entities) then return false end
  for _, entity in pairs(entities) do
    if entity and entity.valid and TECH_PRIESTS_BELTLIKE_TYPES_0201[entity.type] then return true end
  end
  return false
end

if tech_priests_can_spawn_at_tile_0176 then
  tech_priests_original_can_spawn_at_tile_0201 = tech_priests_can_spawn_at_tile_0176
  function tech_priests_can_spawn_at_tile_0176(station, priest_name, position)
    if station and station.valid and position and tech_priests_tile_has_beltlike_entity_0201(station.surface, position) then
      return false
    end
    return tech_priests_original_can_spawn_at_tile_0201(station, priest_name, position)
  end
end

function tech_priests_repair_priest_mapping_0201(pair)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  ensure_storage()
  pair.station_unit = pair.station.unit_number
  pair.priest_unit = pair.priest.unit_number
  pair.force = pair.station.force.name
  pair.surface = pair.station.surface.index
  storage.tech_priests.pairs_by_station[pair.station.unit_number] = pair
  storage.tech_priests.station_by_priest[pair.priest.unit_number] = pair.station.unit_number
  return true
end

function tech_priests_find_relink_pair_for_orphan_0201(priest)
  if not (priest and priest.valid and storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return nil end
  local best = nil
  local best_distance = nil
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if pair and pair.station and pair.station.valid and pair.station.force == priest.force and pair.station.surface == priest.surface then
      local radius = get_station_operating_radius(pair.station) or 0
      local dx = priest.position.x - pair.station.position.x
      local dy = priest.position.y - pair.station.position.y
      local dist = dx * dx + dy * dy
      if dist <= (radius + 4) * (radius + 4) then
        if not best_distance or dist < best_distance then
          best = pair
          best_distance = dist
        end
      end
    end
  end
  return best
end

if purge_orphan_selected_priest then
  tech_priests_original_purge_orphan_selected_priest_0201 = purge_orphan_selected_priest
  function purge_orphan_selected_priest(priest)
    if not (priest and priest.valid and is_priest and is_priest(priest)) then return false end
    local pair = find_pair_for_entity and find_pair_for_entity(priest) or nil
    if pair and pair.station and pair.station.valid then
      tech_priests_repair_priest_mapping_0201(pair)
      return false
    end
    local relink_pair = tech_priests_find_relink_pair_for_orphan_0201(priest)
    if relink_pair then
      relink_pair.priest = priest
      tech_priests_repair_priest_mapping_0201(relink_pair)
      apply_pair_display_names(relink_pair)
      tech_priests_lifecycle_note_0201(relink_pair, "relinked selected orphan priest", priest, "mapping repaired instead of purged")
      if priest.force then priest.force.print("[Tech-Priest Debug] Relinked an unmapped Tech-Priest to " .. tostring(tech_priests_station_name_0189 and tech_priests_station_name_0189(relink_pair) or "nearest Cogitator Station") .. ".") end
      return true
    end
    tech_priests_lifecycle_note_0201(nil, "orphan priest selected", priest, "no valid station mapping; not destroyed in 0.1.201")
    if priest.force then priest.force.print("[Tech-Priest Debug] Unmapped Tech-Priest detected at " .. tostring(priest.surface and priest.surface.name or "unknown") .. "; left alive for diagnosis.") end
    return true
  end
end

function tech_priests_audit_priest_mappings_0201(verbose_force)
  ensure_storage()
  local repaired = 0
  local missing = 0
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    if pair and pair.station and pair.station.valid then
      if pair.priest and pair.priest.valid then
        if tech_priests_repair_priest_mapping_0201(pair) then repaired = repaired + 1 end
      else
        missing = missing + 1
        tech_priests_lifecycle_note_0201(pair, "missing priest during audit", nil, "station has no valid priest entity")
      end
    end
  end
  if verbose_force then verbose_force.print("[Tech-Priest Debug] Mapping audit complete. Repaired/confirmed: " .. tostring(repaired) .. "; missing priest links: " .. tostring(missing) .. ".") end
end

TechPriestsRuntimeEventRegistry.on_nth_tick(911, function()
  tech_priests_audit_priest_mappings_0201(nil)
end)

if commands then
  TechPriestsDebugCommandRegistry.add("tech-priests-debug-priests", "Audit Tech-Priest mappings and print recent lifecycle diagnostics.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local force = player and player.valid and player.force or game.forces.player
    tech_priests_audit_priest_mappings_0201(force)
    local bucket = tech_priests_lifecycle_bucket_0201()
    local start = math.max(1, #bucket - 9)
    if #bucket == 0 then
      force.print("[Tech-Priest Debug] No lifecycle notes recorded yet.")
    else
      force.print("[Tech-Priest Debug] Recent lifecycle notes:")
      for i = start, #bucket do
        local entry = bucket[i]
        local p = entry.position and (math.floor(entry.position.x + 0.5) .. "," .. math.floor(entry.position.y + 0.5)) or "?,?"
        force.print("  tick " .. tostring(entry.tick) .. " · " .. tostring(entry.surface) .. " @ " .. p .. " · " .. tostring(entry.reason) .. " · station " .. tostring(entry.station_unit or "?") .. " · priest " .. tostring(entry.priest_unit or "?") .. (entry.extra ~= "" and (" · " .. entry.extra) or ""))
      end
    end
  end)
end

-- 0.1.202 lifecycle trace logging for disappearing Tech-Priests.
-- This pass writes compact transition records both to factorio-current.log via log()
-- and to script-output/tech-priests-lifecycle.log via game.write_file.  It is
-- intended as a temporary diagnostic net around priest spawn, recall, mapping,
-- removal, and task-state changes.

TECH_PRIESTS_LIFECYCLE_DEBUG_LIMIT_0202 = 240
TECH_PRIESTS_LIFECYCLE_LOG_FILE_0202 = "tech-priests-lifecycle.log"
TECH_PRIESTS_LIFECYCLE_HEARTBEAT_TICKS_0202 = 60 * 5
TECH_PRIESTS_LIFECYCLE_TRACE_ENABLED_0202 = false
TECH_PRIESTS_LIFECYCLE_FILE_ENABLED_0202 = false

function tech_priests_lifecycle_safe_coord_0202(entity_or_position)
  if not entity_or_position then return "?,?" end
  local p = nil
  if entity_or_position.valid and entity_or_position.position then p = entity_or_position.position else p = entity_or_position end
  if not (p and p.x and p.y) then return "?,?" end
  return tostring(math.floor(p.x * 10 + 0.5) / 10) .. "," .. tostring(math.floor(p.y * 10 + 0.5) / 10)
end

function tech_priests_lifecycle_station_label_0202(pair)
  if not pair then return "station=?" end
  local unit = pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number) or "?"
  local name = nil
  if tech_priests_station_name_0189 then
    pcall(function() name = tech_priests_station_name_0189(pair) end)
  end
  return "station=" .. tostring(unit) .. (name and ("/" .. tostring(name)) or "")
end

function tech_priests_lifecycle_priest_label_0202(pair, entity)
  local priest = entity and entity.valid and entity or (pair and pair.priest and pair.priest.valid and pair.priest) or nil
  local unit = priest and priest.unit_number or (pair and pair.priest_unit) or "?"
  local name = nil
  if pair and apply_pair_display_names then pcall(function() apply_pair_display_names(pair) end) end
  if pair and pair.priest_display_name then name = pair.priest_display_name elseif priest and priest.valid then name = priest.name end
  return "priest=" .. tostring(unit) .. (name and ("/" .. tostring(name)) or "")
end
