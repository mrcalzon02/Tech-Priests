-- Tech Priests 0.1.260
-- Cogitator Station defensive perimeter planning.
--
-- Stations may build priest-managed wall rings at the edge of station coverage.
-- If station coverage changes, obsolete priest-managed walls are recovered and
-- new walls are planned at the new edge.  If one of those tracked walls is lost,
-- the local priest attempts to place a defensive turret near the breach and then
-- manually service turret ammunition from the station inventory/logistics bridge.

TECH_PRIESTS_DEFENSE_PERIMETER_VERSION_0259 = "0.1.260"
TECH_PRIESTS_DEFENSE_WALL_ITEM_0259 = "stone-wall"
TECH_PRIESTS_DEFENSE_WALL_ENTITY_0259 = "stone-wall"
TECH_PRIESTS_DEFENSE_SCAN_INTERVAL_0259 = 180
TECH_PRIESTS_DEFENSE_REPATH_TICKS_0259 = 90
TECH_PRIESTS_DEFENSE_BUILD_REACH_SQ_0259 = 3.0 * 3.0
TECH_PRIESTS_DEFENSE_BUILD_TICKS_0259 = 60
TECH_PRIESTS_DEFENSE_WALL_SPACING_0259 = 3.0
TECH_PRIESTS_DEFENSE_WALL_RING_TOLERANCE_0259 = 1.75
TECH_PRIESTS_DEFENSE_MAX_WALLS_PER_STATION_0259 = 96
TECH_PRIESTS_DEFENSE_MAX_BREACH_QUEUE_0259 = 12
TECH_PRIESTS_DEFENSE_TURRET_SEARCH_RADIUS_0259 = 6
TECH_PRIESTS_DEFENSE_AMMO_BATCH_0259 = 20
TECH_PRIESTS_DEFENSE_SUPPORT_SEARCH_RADIUS_0260 = 8
TECH_PRIESTS_DEFENSE_PIPE_SUPPORT_ITEM_0260 = "pipe"
TECH_PRIESTS_DEFENSE_POWER_SUPPORT_ITEMS_0260 = { "small-electric-pole", "medium-electric-pole", "big-electric-pole", "substation" }
TECH_PRIESTS_DEFENSE_GATE_ITEM_0646 = "gate"
TECH_PRIESTS_DEFENSE_GATE_ENTITY_0646 = "gate"
TECH_PRIESTS_DEFENSE_CARDINAL_GAP_RADIUS_0646 = 2.25
TECH_PRIESTS_DEFENSE_MAX_TURRET_SLOTS_0646 = 16

-- Registered while control.lua is parsed; no saved state is touched here.
-- Read-only native-grid fixtures can load this file without the mod loader.
local planning_ok_1507, DefensePlanning1507 = pcall(require, "scripts.core.defense_planning_1507")
if not planning_ok_1507 then DefensePlanning1507 = nil end
local function defense_planning_1507()
  assert(DefensePlanning1507, "bounded defense planner must be preloaded during control.lua parsing")
  return DefensePlanning1507
end

local function tech_priests_0646_constraints()
  local C = rawget(_G, "TechPriestsPlanningConstraints0646")
  if not C then local ok, mod = pcall(require, "scripts.core.planning_constraints_0646"); if ok then C = mod end end
  return C
end

local function tech_priests_0646_entity_unlocked(pair, entity_name)
  local C = tech_priests_0646_constraints()
  if not (C and type(C.entity_unlocked) == "function") then return true end
  local unlocked=C.entity_unlocked(pair,entity_name)
  if unlocked then return true end
  -- Research gates MANUFACTURING the item, not placing an already-owned,
  -- engine-real defensive item. Permit only an urgent hostile-damage response
  -- with the exact physical placeable item in this station's chest. Never
  -- enable a recipe, create inventory or waive position/supply checks.
  local state=pair and pair.defense_perimeter_0259
  local last=state and state.last_hostile_damage_0816
  local recent=last and game and game.tick-last.tick<=7200
  local active=pair and pair.defense_task_0259
  local active_memory=false
  for _,incident in ipairs(state and state.hostile_incidents_0817 or {}) do
    if active and active.incident_id_0817==incident.id
        and incident.expires_at>(game and game.tick or 0) then
      active_memory=true; break
    end
  end
  local committed=(recent or active_memory) and active
      and (active.type=="build-turret" or active.type=="build-turret-support")
      and active.entity_name==entity_name
  -- Incident is consumed when a real construction order STARTS, not when
  -- the priest reaches the site. Keep that one authorized build legal
  -- through movement and placement without opening unrestricted manufacture.
  if not (state and ((state.threats and #state.threats>0) or committed)
      and C.item_for_entity and pair.station and pair.station.valid) then
    return false
  end
  local item=C.item_for_entity(entity_name)
  if not item then return false end
  local ok,owned=pcall(function()
    local inv=pair.station.get_inventory(defines.inventory.chest)
    return inv and inv.valid and inv.get_item_count(item)>0
  end)
  return ok and owned==true
end

local function tech_priests_0646_defense_position_allowed(pair, position)
  local C = tech_priests_0646_constraints()
  if not (C and type(C.defense_position_allowed) == "function") then return true end
  return C.defense_position_allowed(pair, position)
end
local function tech_priests_1507_defense_local_allowed(pair,position)
  local C=tech_priests_0646_constraints()
  if not(C and C.perimeter_tolerance) then
    return tech_priests_0646_defense_position_allowed(pair,position)
  end
  local radius=DefensePlanning1507.radius(pair)
  local dx,dy=position.x-pair.station.position.x,position.y-pair.station.position.y
  return math.abs(math.sqrt(dx*dx+dy*dy)-radius)<=C.perimeter_tolerance
end

function tech_priests_0259_diag(message)
  if tech_priests_0246_diag_line then
    tech_priests_0246_diag_line("0.1.259 " .. tostring(message))
  elseif log then
    log("[Tech Priests 0.1.259] " .. tostring(message))
  end
end

local function tech_priests_0259_valid_pair(pair)
  if tech_priests_0248_valid_pair then return tech_priests_0248_valid_pair(pair) end
  return pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid
end

local function tech_priests_0259_distance_sq(a, b)
  if tech_priests_distance_sq_0186 then return tech_priests_distance_sq_0186(a, b) end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function tech_priests_0259_radius(pair)
  local ok, radius = pcall(function()
    if refresh_pair_radius then return refresh_pair_radius(pair) end
    return pair.radius or pair.base_radius or 20
  end)
  if ok and radius then return radius end
  return 20
end

local function tech_priests_0259_station_inventory(pair)
  if get_station_inventory and pair and pair.station and pair.station.valid then return get_station_inventory(pair.station) end
  if pair and pair.station and pair.station.valid then return pair.station.get_inventory(defines.inventory.chest) end
  return nil
end

local function tech_priests_0259_item_count(pair, item_name)
  local inv = tech_priests_0259_station_inventory(pair)
  if inv and inv.valid and item_name then return inv.get_item_count(item_name) end
  return 0
end

local function tech_priests_0259_force_has_item(pair, item_name)
  if tech_priests_0259_item_count(pair, item_name) > 0 then return true end
  if not (pair and pair.station and pair.station.valid and item_name) then return false end
  if transfer_cache_inventory_to_station then pcall(function() transfer_cache_inventory_to_station(pair) end) end
  if tech_priests_0259_item_count(pair, item_name) > 0 then return true end
  local network = get_station_logistic_network and get_station_logistic_network(pair.station) or nil
  if network and logistic_network_item_count then
    local ok, count = pcall(function() return logistic_network_item_count(network, { name = item_name, count = 1 }) end)
    if ok and count and count > 0 then return true end
  end
  return false
end

local function tech_priests_0259_request_item(pair, item_name, count, kind)
  if not (pair and item_name and issue_station_logistic_request) then return false end
  local request = {
    kind = kind or "defense",
    candidates = {
      { name = item_name, count = count or 1, score = 100 }
    }
  }
  local ok, result = pcall(function() return issue_station_logistic_request(pair, request) end)
  return ok and result or false
end

local function tech_priests_0259_take_item(pair, item_name, count)
  local inv = tech_priests_0259_station_inventory(pair)
  if not (inv and inv.valid and item_name) then return 0 end
  return inv.remove({ name = item_name, count = count or 1 }) or 0
end

local function tech_priests_0259_return_item(pair, item_name, count)
  local inv = tech_priests_0259_station_inventory(pair)
  if inv and inv.valid and item_name and count and count > 0 then return inv.insert({ name = item_name, count = count }) or 0 end
  return 0
end

local function tech_priests_0259_entity_from_item(item_name)
  if tech_priests_get_entity_prototype_name_from_item_0184 then
    local ok, entity_name = pcall(function() return tech_priests_get_entity_prototype_name_from_item_0184(item_name) end)
    if ok and entity_name then return entity_name end
  end
  local item_proto = tech_priests_get_item_prototype_0440 and tech_priests_get_item_prototype_0440(item_name) or nil
  if item_proto then
    local ok, place = pcall(function() return item_proto.place_result end)
    if ok and place and place.name then return place.name end
  end
  return nil
end

local function tech_priests_0259_item_from_entity(entity_name)
  return DefensePlanning1507 and DefensePlanning1507.item_for_entity(entity_name)
end

local function tech_priests_0259_entity_type(entity_name)
  local entity_proto = tech_priests_get_entity_prototype_0440 and tech_priests_get_entity_prototype_0440(entity_name) or nil
  if not entity_proto then return nil end
  local ok, typ = pcall(function() return entity_proto.type end)
  if ok then return typ end
  return nil
end

local function tech_priests_0259_is_defensive_entity(entity_name)
  local typ = tech_priests_0259_entity_type(entity_name)
  return typ == "ammo-turret" or typ == "electric-turret" or typ == "fluid-turret" or typ == "turret" or typ == "artillery-turret"
end

local function tech_priests_0259_turret_candidates()
  -- Diagnostics see only the completed catalogue. Live selectors advance it
  -- one immutable prototype membership at a time inside the force broker.
  return DefensePlanning1507 and DefensePlanning1507.cached_candidates() or {}
end

local function tech_priests_0259_select_turret(pair)
  local fallback = nil
  local unlocked_fallback = nil
  for _, rec in pairs(tech_priests_0259_turret_candidates()) do
    local unlocked = tech_priests_0646_entity_unlocked(pair, rec.entity)
    if unlocked and not unlocked_fallback then unlocked_fallback = rec end
    if unlocked and tech_priests_0259_item_count(pair, rec.item) > 0 then return rec.item, rec.entity end
    if unlocked and not fallback and tech_priests_0259_force_has_item(pair, rec.item) then fallback = rec end
  end
  if fallback then return fallback.item, fallback.entity end
  if unlocked_fallback then return unlocked_fallback.item, unlocked_fallback.entity end
  return nil, nil
end

local function tech_priests_0259_defense_state(pair)
  -- Combat memory is initialized on the first REAL damage event, often
  -- before the older perimeter worker has ever seen this priest. That owner
  -- creates a partial defense_perimeter_0259 table (incident ledger/threats).
  -- Backfill only missing perimeter fields: never replace the ledger, queued
  -- incidents, existing entity references, counters or physical task state.
  pair.defense_perimeter_0259 = pair.defense_perimeter_0259 or {}
  local state=pair.defense_perimeter_0259
  state.walls=state.walls or {}
  state.gates=state.gates or {}
  state.turrets=state.turrets or {}
  state.breaches=state.breaches or {}
  if state.next_scan_tick==nil then state.next_scan_tick=0 end
  if state.built==nil then state.built=0 end
  if state.recovered==nil then state.recovered=0 end
  if state.turrets_built==nil then state.turrets_built=0 end
  if state.last_reason==nil then state.last_reason="initialized" end
  return state
end

local function tech_priests_0259_position_key(pos)
  return tostring(math.floor((pos.x or 0) + 0.5)) .. ":" .. tostring(math.floor((pos.y or 0) + 0.5))
end

local function tech_priests_0259_can_place(pair, entity_name, position, local_only)
  if not (pair and pair.station and pair.station.valid and entity_name and position) then return false end
  if not tech_priests_0646_entity_unlocked(pair, entity_name) then return false end
  if not (local_only and tech_priests_1507_defense_local_allowed(pair,position)
      or not local_only and tech_priests_0646_defense_position_allowed(pair,position)) then return false end
  local surface = pair.station.surface
  local ok, can = pcall(function()
    return surface.can_place_entity({ name = entity_name, position = position, force = pair.station.force })
  end)
  return ok and can or false
end

-- Placement alternatives must remain in their intended *station* perimeter
-- band. A technically placeable tile beyond the authority radius is not a
-- valid fallback for a wall or hostile-facing turret. Support items still
-- use their existing distinct power/pipe checks.
local function tech_priests_0259_perimeter_band_allowed(pair,entity_name,pos)
  local entity_type=tech_priests_0259_entity_type(entity_name)
  local is_wall=entity_type=="wall" or entity_name==TECH_PRIESTS_DEFENSE_WALL_ENTITY_0259
      or entity_name==TECH_PRIESTS_DEFENSE_GATE_ENTITY_0646
  local is_turret=entity_type=="ammo-turret"
      or entity_type=="electric-turret"
      or entity_type=="fluid-turret"
      or entity_type=="artillery-turret"
  if not (is_wall or is_turret) then return true end
  local operating=math.max(8,math.min(96,tonumber(
      tech_priests_0259_radius(pair)) or 20))
  local ring=math.max(8,math.floor(operating-1))
  local radial=math.sqrt(tech_priests_0259_distance_sq(
    pair.station.position,pos))
  local min_radius=math.max(4,ring-(is_wall and 2 or 6))
  -- Allow tile-centre rounding, but not positions outside the station reach.
  local max_radius=math.min(operating+0.5,ring+1.5)
  return radial>=min_radius and radial<=max_radius
end
local function tech_priests_0259_turrets_near(pair,position,radius)
  if not (pair and pair.station and pair.station.valid) then return {} end
  return pair.station.surface.find_entities_filtered({
    position=position,radius=radius or 2.5,force=pair.station.force,
    -- Filter only concrete Factorio entity types; 'turret' is an
    -- abstract prototype family, not a placeable entity type.
    type={"ammo-turret","electric-turret","fluid-turret",
      "artillery-turret"},limit=8
  })
end

local function tech_priests_0259_higher_priority_visible(pair)
  if tech_priests_0248_higher_priority_probe then
    local ok, probe = pcall(function() return tech_priests_0248_higher_priority_probe(pair) end)
    if ok and probe and probe.priority and probe.priority ~= "idle" then return true, probe.priority end
  end
  if tech_priests_pair_has_higher_priority_work_0248 then
    local ok, result = pcall(function() return tech_priests_pair_has_higher_priority_work_0248(pair) end)
    if ok and result then return true, "higher-priority" end
  end
  return false, "idle"
end

local function tech_priests_0259_queue_breach(state, position, reason)
  if not (state and position) then return end
  state.breaches = state.breaches or {}
  if #state.breaches >= TECH_PRIESTS_DEFENSE_MAX_BREACH_QUEUE_0259 then table.remove(state.breaches, 1) end
  state.breaches[#state.breaches + 1] = { position = { x = position.x, y = position.y }, tick = game and game.tick or 0, reason = reason or "wall-lost" }
end

local function tech_priests_0259_start_task(pair, task)
  pair.defense_task_0259 = task
  pair.mode = task.mode or "defense-perimeter"
  pair.target = nil
  return true
end

local function tech_priests_0259_start_recover_wall(pair, rec)
  if not (rec and rec.entity and rec.entity.valid) then return false end
  return tech_priests_0259_start_task(pair, {
    type = "recover-wall",
    entity = rec.entity,
    key = rec.key,
    position = { x = rec.entity.position.x, y = rec.entity.position.y },
    next_repath_tick = 0,
    mode = "relocating-defense-wall"
  })
end

local function tech_priests_0259_start_build(pair, task_type, item_name, entity_name, position, key, direction)
  return tech_priests_0259_start_task(pair, {
    type = task_type,
    item = item_name,
    entity_name = entity_name,
    position = { x = position.x, y = position.y },
    key = key,
    direction = direction,
    phase = "approach",
    next_repath_tick = 0,
    build_due_tick = nil,
    mode = task_type == "build-turret" and "placing-defense-turret" or (task_type == "build-turret-support" and "placing-defense-support" or (task_type == "build-gate" and "placing-defense-gate" or "placing-defense-wall"))
  })
end

local function tech_priests_0259_turret_needs_ammo(entity)
  return entity and entity.valid and tech_priests_0259_entity_type(entity.name) == "ammo-turret"
end

local function tech_priests_0259_find_ammo(pair)
  return defense_planning_1507().ammo(pair)
end

local function tech_priests_0259_start_ammo_service(pair, turret)
  if not (turret and turret.valid and tech_priests_0259_turret_needs_ammo(turret)) then return false end
  local ammo, status = tech_priests_0259_find_ammo(pair)
  if not ammo then
    local state=tech_priests_0259_defense_state(pair)
    state.pending_ammo_turret_1507=turret
    if status=="none" then
      tech_priests_0259_request_item(pair, "firearm-magazine", TECH_PRIESTS_DEFENSE_AMMO_BATCH_0259, "defense-ammo")
    end
    return false
  end
  tech_priests_0259_defense_state(pair).pending_ammo_turret_1507=nil
  return tech_priests_0259_start_task(pair, {
    type = "ammo-turret",
    turret = turret,
    ammo = ammo,
    position = { x = turret.position.x, y = turret.position.y },
    next_repath_tick = 0,
    mode = "refilling-defense-turret"
  })
end

-- Preserve physical ammunition logistics through the canonical priest task.
-- A remembered incident can request resupply after its first turret was built.
local function tech_priests_0259_complete_build(pair, task)
  local removed = tech_priests_0259_take_item(pair, task.item, 1)
  if removed <= 0 then
    tech_priests_0259_request_item(pair, task.item, 1, task.type)
    return false
  end
  local ok, entity = pcall(function()
    return pair.station.surface.create_entity({
      name = task.entity_name,
      position = task.position,
      force = pair.station.force,
      direction = task.direction,
      create_build_effect_smoke = true,
      raise_built = true
    })
  end)
  if not (ok and entity and entity.valid) then
    tech_priests_0259_return_item(pair, task.item, 1)
    return false
  end
  local state = tech_priests_0259_defense_state(pair)
  if task.type == "build-wall" then
    state.walls[task.key or tech_priests_0259_position_key(task.position)] = {
      entity = entity,
      item = task.item,
      position = { x = entity.position.x, y = entity.position.y },
      radius = state.last_radius,
      built_tick = game.tick
    }
    state.built = (state.built or 0) + 1
  elseif task.type == "build-gate" then
    state.gates = state.gates or {}
    state.gates[task.key or tech_priests_0259_position_key(task.position)] = {
      entity = entity,
      item = task.item,
      position = { x = entity.position.x, y = entity.position.y },
      radius = state.last_radius,
      built_tick = game.tick,
    }
    state.gates_built_0646 = (state.gates_built_0646 or 0) + 1
  elseif task.type == "build-turret" then
    state.turrets = state.turrets or {}
    if task.key then
      state.turrets[task.key] = { entity = entity, item = task.item,
        position = { x = entity.position.x, y = entity.position.y },
        built_tick = game.tick }
      -- 1130: advance the persistent family cursor ONLY after a real,
      -- paid-for routine ring build. Hostile incident builds have no slot key
      -- and must not reset the planned multi-family layering schedule.
      state.last_routine_turret_family_1130=entity.name
    end
    state.turrets_built = (state.turrets_built or 0) + 1
    state.last_turret = entity
    tech_priests_0259_start_ammo_service(pair, entity)
    return true
  elseif task.type == "build-turret-support" then
    state.supports_built_0260 = (state.supports_built_0260 or 0) + 1
    if task.pending_breach_position_0260 then
      tech_priests_0259_queue_breach(state, task.pending_breach_position_0260, "turret-support-complete")
    end
  end
  if tech_priests_draw_emergency_operation_status_0184 then tech_priests_draw_emergency_operation_status_0184(pair, "[entity=" .. entity.name .. "] defense placement complete") end
  return true
end

local function tech_priests_0259_handle_task(pair)
  local task = pair.defense_task_0259
  if not task then return false end
  if not tech_priests_0259_valid_pair(pair) then pair.defense_task_0259 = nil; return false end
  local priest = pair.priest

  if task.type == "recover-wall" then
    if not (task.entity and task.entity.valid) then pair.defense_task_0259 = nil; return false end
    local dist = tech_priests_0259_distance_sq(priest.position, task.entity.position)
    if dist > TECH_PRIESTS_DEFENSE_BUILD_REACH_SQ_0259 then
      if game.tick >= (task.next_repath_tick or 0) and issue_priest_command then
        issue_priest_command(priest, { type = defines.command.go_to_location, destination = task.entity.position, radius = 2, distraction = defines.distraction.by_enemy })
        task.next_repath_tick = game.tick + TECH_PRIESTS_DEFENSE_REPATH_TICKS_0259
      end
      pair.mode = "relocating-defense-wall"
      return true
    end
    pair.defense_task_0259 = nil
    local inventory = tech_priests_0259_station_inventory(pair)
    if not (inventory and inventory.valid and task.entity.mine{inventory = inventory, raise_destroyed = false}) then
      return false
    end
    local state = tech_priests_0259_defense_state(pair)
    if task.key then state.walls[task.key] = nil end
    state.recovered = (state.recovered or 0) + 1
    return true
  end

  if task.type == "ammo-turret" then
    if not (task.turret and task.turret.valid) then pair.defense_task_0259 = nil; return false end
    local dist = tech_priests_0259_distance_sq(priest.position, task.turret.position)
    if dist > TECH_PRIESTS_DEFENSE_BUILD_REACH_SQ_0259 then
      if game.tick >= (task.next_repath_tick or 0) and issue_priest_command then
        issue_priest_command(priest, { type = defines.command.go_to_location, destination = task.turret.position, radius = 2, distraction = defines.distraction.by_enemy })
        task.next_repath_tick = game.tick + TECH_PRIESTS_DEFENSE_REPATH_TICKS_0259
      end
      pair.mode = "refilling-defense-turret"
      return true
    end
    local ammo,status=task.ammo,"ready"
    if not ammo then ammo,status=tech_priests_0259_find_ammo(pair) end
    if not ammo then
      if status=="pending" or status=="queue-full" then return true end
      pair.defense_task_0259=nil;return false
    end
    local removed = tech_priests_0259_take_item(pair, ammo, TECH_PRIESTS_DEFENSE_AMMO_BATCH_0259)
    if removed <= 0 then pair.defense_task_0259 = nil; return false end
    local inv = task.turret.get_inventory(defines.inventory.turret_ammo)
    if inv and inv.valid then
      local inserted = inv.insert({ name = ammo, count = removed }) or 0
      if inserted < removed then tech_priests_0259_return_item(pair, ammo, removed - inserted) end
    else
      tech_priests_0259_return_item(pair, ammo, removed)
    end
    pair.defense_task_0259 = nil
    return true
  end

  if task.type == "build-wall" or task.type == "build-gate" or task.type == "build-turret" or task.type == "build-turret-support" then
    if not task.position then pair.defense_task_0259 = nil; return false end
    local planner=defense_planning_1507()
    if not planner.policy_ready(pair) then return true end
    if not planner.claim_live() then return true end
    if task.support_witness_1507 and not planner.claim_live() then return true end
    local supported=planner.task_support_current(pair,task)
    if supported==nil then return true end
    if not tech_priests_0259_can_place(pair,task.entity_name,task.position,true) or not supported then
      local new_pos,status=planner.retry_position(pair,task)
      if not new_pos then
        if status=="pending" or status=="queue-full" then
          -- An obstructed, unladen build does not own the priest while its
          -- alternative sites are being searched. Keep the exact work state.
          tech_priests_0259_defense_state(pair).site_waiting_task_1507=task
        end
        pair.defense_task_0259=nil
        return false
      end
      task.position=new_pos;task.build_due_tick=nil;task.next_repath_tick=0
    end
    if not tech_priests_0259_force_has_item(pair, task.item) then
      tech_priests_0259_request_item(pair, task.item, 1, task.type)
      pair.defense_task_0259 = nil
      return false
    end
    local dist = tech_priests_0259_distance_sq(priest.position, task.position)
    if dist > TECH_PRIESTS_DEFENSE_BUILD_REACH_SQ_0259 then
      if game.tick >= (task.next_repath_tick or 0) and issue_priest_command then
        issue_priest_command(priest, { type = defines.command.go_to_location, destination = task.position, radius = 2, distraction = defines.distraction.by_enemy })
        task.next_repath_tick = game.tick + TECH_PRIESTS_DEFENSE_REPATH_TICKS_0259
      end
      pair.mode = task.mode or "defense-construction"
      return true
    end
    if not task.build_due_tick then
      task.build_due_tick = game.tick + TECH_PRIESTS_DEFENSE_BUILD_TICKS_0259
      if tech_priests_draw_emergency_operation_status_0184 then tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. task.item .. "] defense construction rite") end
      return true
    end
    if game.tick < task.build_due_tick then return true end
    local ok = tech_priests_0259_complete_build(pair, task)
    if ok and pair.defense_task_0259 == task then pair.defense_task_0259 = nil end
    return ok
  end

  pair.defense_task_0259 = nil
  return false
end



-- 0.1.260 Defensive turret support validation.
-- Flamethrower/fluid turrets must be placed with a pipe connection available
-- or an adjacent support-pipe build queued first. Laser/electric turrets must be
-- placed inside electrical supply coverage or have a pole requested/queued.
local function tech_priests_0260_entity_kind(entity_name)
  local typ = tech_priests_0259_entity_type(entity_name)
  if typ == "electric-turret" then return "electric" end
  if typ == "fluid-turret" then return "fluid" end
  if entity_name and string.find(entity_name, "laser", 1, true) then return "electric" end
  if entity_name and string.find(entity_name, "flamethrower", 1, true) then return "fluid" end
  return "ordinary"
end

local function tech_priests_0260_position_has_power(pair, position)
  -- A geometrically nearby, disconnected pole is NOT a powered laser
  -- support. Factorio 2.x prototypes expose quality-aware supply distance
  -- via a method, not the obsolete 1.1 property. Fail closed on unavailable
  -- network identity/geometry rather than crediting an imaginary supply.
  if not (pair and pair.station and pair.station.valid and position) then return false end
  local surface = pair.station.surface
  -- A legendary substation covers farther than 12 tiles. Keep one bounded
  -- native scan but include higher-quality and custom Martian power poles.
  local search_radius = 24
  local area = {{position.x - search_radius, position.y - search_radius},
    {position.x + search_radius, position.y + search_radius}}
  local ok, poles = pcall(function()
    return surface.find_entities_filtered{
      area = area, type = "electric-pole", force = pair.station.force, limit = 64 }
  end)
  if not (ok and type(poles) == "table") then return false end
  for _, pole in pairs(poles) do
    if pole and pole.valid and pole.force == pair.station.force then
      local connected, supply = false, nil
      pcall(function()
        connected = type(pole.electric_network_id) == "number"
          and pole.electric_network_id > 0
      end)
      pcall(function()
        local proto = pole.prototype
        if proto and type(proto.get_supply_area_distance) == "function" then
          local quality_name = pole.quality and pole.quality.name or "normal"
          supply = tonumber(proto.get_supply_area_distance(quality_name))
        end
      end)
      if connected and supply and supply > 0 then
        local dx = math.abs(pole.position.x - position.x)
        local dy = math.abs(pole.position.y - position.y)
        -- Electric poles supply a square, not a circular radius.
        if dx <= supply + 0.35 and dy <= supply + 0.35 then return true end
      end
    end
  end
  return false
end

local function tech_priests_0260_native_pole_range(proto, method, quality_name)
  if not proto then return nil end
  local ok,range=pcall(function()
    local getter=proto[method]
    return type(getter)=="function" and getter(quality_name or "normal") or nil
  end)
  range=ok and tonumber(range) or nil
  return range and range>0 and range or nil
end

local function tech_priests_0260_connected_pole_site(pair, new_proto, position, anchors)
  local new_wire=tech_priests_0260_native_pole_range(
    new_proto,"get_max_wire_distance")
  if not new_wire then return false end
  for _,pole in ipairs(anchors or {}) do
    if pole and pole.valid and pole.force==pair.station.force then
      local network_id
      pcall(function() network_id=pole.electric_network_id end)
      local old_wire=tech_priests_0260_native_pole_range(
        pole.prototype,"get_max_wire_distance",
        pole.quality and pole.quality.name or "normal")
      if type(network_id)=="number" and network_id>0 and old_wire then
        local dx=pole.position.x-position.x
        local dy=pole.position.y-position.y
        local legal_wire=math.min(new_wire,old_wire)-0.2
        if dx*dx+dy*dy<=legal_wire*legal_wire then return true end
      end
    end
  end
  return false
end

local function tech_priests_0646_turret_range(entity_name)
  local proto = tech_priests_get_entity_prototype_0440 and tech_priests_get_entity_prototype_0440(entity_name) or nil
  local range = 18
  pcall(function() range = tonumber(proto.attack_parameters.range) or range end)
  return math.max(6, range)
end

local function tech_priests_0259_service_perimeter(pair,mode,preempt)
  if not tech_priests_0259_valid_pair(pair) then return false end
  local state=tech_priests_0259_defense_state(pair)
  local planner=defense_planning_1507()
  local waiting=state.site_waiting_task_1507
  if waiting and not preempt then
    local pos,status=planner.retry_position(pair,waiting)
    if pos then
      waiting.position=pos;waiting.build_due_tick=nil;waiting.next_repath_tick=0
      state.site_waiting_task_1507=nil
      return tech_priests_0259_start_task(pair,waiting)
    elseif status=="none" then state.site_waiting_task_1507=nil
    else state.last_reason="defense-site-planning-"..tostring(status);return false end
  end
  if not preempt and game.tick<(state.next_scan_tick or 0) then return false end
  local result,status=planner.poll(pair,mode)
  if not result then
    state.last_reason="defense-planning-"..tostring(status)
    return false
  end
  -- A pending job never sets a failure cooldown and never takes inventory.
  -- Results carry only proposals; current stock and live site/support checks
  -- still decide whether the physical task may start.
  state.last_radius=result.radius or state.last_radius
  state.last_reason=result.reason or "defense-plan-ready"
  if result.kind=="build" then
    if not tech_priests_0259_force_has_item(pair,result.item) then
      local count=result.task_type=="build-wall" and 10 or 1
      tech_priests_0259_request_item(pair,result.item,count,result.task_type)
      state.last_reason="awaiting-"..tostring(result.item)
      return false
    end
    if preempt then
      if result.task_type~="build-turret" and result.task_type~="build-turret-support" then return false end
      state.suspended_defense_task_0819=pair.defense_task_0259
      pair.defense_task_0259=nil
    end
    if tech_priests_0259_start_build(pair,result.task_type,result.item,result.entity,result.position,result.key,result.direction) then
      local task=pair.defense_task_0259
      task.support_witness_1507=result.support;task.support_kind_1507=result.support_kind
      task.authority_1507=result.authority
      task.pipe_scan_1507=result.pipe_scan;task.fluid_proof_1507=result.fluid_proof;task.planned_fluid_1507=result.planned_fluid
      task.pending_breach_position_0260=result.pending_position
      task.pending_turret_entity_0260=result.pending_turret
      local queue=result.queue_name and state[result.queue_name]
      if result.responds_to_threat and result.threat and queue and queue[1]==result.threat then
        task.incident_id_0817=result.threat.incident_id_0817
        table.remove(queue,1)
      end
      state.next_scan_tick=game.tick+((state.threats and #state.threats>0) and 60 or TECH_PRIESTS_DEFENSE_SCAN_INTERVAL_0259)
      return true
    end
  elseif result.kind=="recover" and not preempt then
    return tech_priests_0259_start_recover_wall(pair,{entity=result.entity,key=result.key})
  elseif result.kind=="ammo" and not preempt then
    pair.defense_ammo_1507=result.ammo
    return tech_priests_0259_start_ammo_service(pair,result.turret)
  elseif result.kind=="request" then
    tech_priests_0259_request_item(pair,result.item,result.count,result.request_kind)
  end
  state.next_scan_tick=game.tick+((state.threats and #state.threats>0) and 60 or TECH_PRIESTS_DEFENSE_SCAN_INTERVAL_0259)
  return false
end

-- The later canonical single dispatcher no longer guarantees that the
-- legacy tick_pair wrapper runs. Export the SAME physical perimeter executor
-- as a subordinate service; never duplicate its build or ammo logic.
local function tech_priests_0818_has_pending(pair)
  local state=pair and pair.defense_perimeter_0259
  if state and game then
    state.last_defense_dispatch_probe_tick_0818=game.tick
  end
  return state and ((state.threats and #state.threats>0)
    or (state.unresolved_incidents_0817 or 0)>0
    or pair.defense_task_0259~=nil
    or state.site_waiting_task_1507~=nil
    or state.pending_ammo_turret_1507~=nil
    or state.suspended_defense_task_0819~=nil) or false
end

-- A routine wall segment must not monopolize a priest while a stocked
-- turret is needed at a genuinely attacked location. Park the exact
-- unfinished task (including target and ownership), without consuming its
-- item or discarding its work. There can be only one parked task per priest.
local function tech_priests_0819_preempt_routine_wall(pair,state)
  local task=pair.defense_task_0259
  if not (task and (task.type=="build-wall"
      or task.type=="build-gate" or task.type=="recover-wall")
      and not state.suspended_defense_task_0819
      and state.threats and #state.threats>0
      and state.hostile_incidents_0817
      and #state.hostile_incidents_0817>0) then
    return false
  end
  -- Keep constructing/moving while urgent planning runs. Only a live,
  -- stocked, ready turret proposal may park this exact physical task.
  return tech_priests_0259_service_perimeter(pair,"urgent",true)
end

local function tech_priests_0819_resume_routine_wall(pair,state)
  if pair.defense_task_0259 or not state.suspended_defense_task_0819
      or (state.threats and #state.threats>0)
      or (state.unresolved_incidents_0817 or 0)>0 then
    return false
  end
  local task=state.suspended_defense_task_0819
  state.suspended_defense_task_0819=nil
  -- Reestablish the physical build delay after resuming a paused task.
  task.build_due_tick=nil
  task.next_repath_tick=0
  pair.defense_task_0259=task
  pair.mode=task.mode or "defense-perimeter"
  state.last_reason="resumed-suspended-wall"
  return true
end

local function tech_priests_0818_service_pair(pair)
  local ledger=pair and pair.defense_perimeter_0259
  if ledger and game then
    ledger.last_defense_bridge_entry_tick_0818=game.tick
  end
  if not tech_priests_0259_valid_pair(pair) then
    return {processed=0,failed=1,detail="invalid-defense-pair"}
  end
  local state=pair.defense_perimeter_0259
  if state and state.hostile_incidents_0817 then
    local memory=rawget(_G,"TechPriestsCombatDefenseReaction0816")
    assert(memory and type(memory.reconcile_pair)=="function",
      "hostile defense memory must be preloaded during control.lua parsing")
    memory.reconcile_pair(pair,tech_priests_0259_turrets_near)
  end
  if not tech_priests_0818_has_pending(pair) then
    return {processed=1,detail="no-hostile-defense-demand"}
  end
  state=tech_priests_0259_defense_state(pair)
  if pair.machine_logistics_custody_0528
      or pair.direct_acquisition_custody_0513
      or pair.emergency_facility_feed_custody_0357 then
    -- Yield to the incumbent custodian to complete its physical transfer.
    return {processed=1,waiting=1,detail="defense-awaits-physical-custody"}
  end
  local tick=game and game.tick or 0
  if tick==(state.last_dispatcher_service_tick_0818 or -1) then
    return {processed=1,waiting=1,detail="defense-already-serviced-this-tick"}
  end
  state.last_dispatcher_service_tick_0818=tick
  tech_priests_0819_preempt_routine_wall(pair,state)
  tech_priests_0819_resume_routine_wall(pair,state)
  if pair.defense_task_0259 and tech_priests_0259_handle_task(pair) then
    return {processed=1,acted=1,detail="defense-task-"..
      tostring(pair.defense_task_0259 and pair.defense_task_0259.type or "finished")}
  end
  if tech_priests_0259_service_perimeter(pair) then
    return {processed=1,acted=1,detail="defense-perimeter-work-started"}
  end
  return {processed=1,waiting=1,detail=state.last_reason or "defense-awaiting-supplies"}
end
-- Adapter functions are Lua-local and reconstructed when control.lua loads.
-- Only their plain-data inputs/cursors are saved by the shared broker.
if DefensePlanning1507 then
  DefensePlanning1507.configure({
    valid_pair=tech_priests_0259_valid_pair,
    state=tech_priests_0259_defense_state,
    radius=tech_priests_0259_radius,
    inventory=tech_priests_0259_station_inventory,
    item_count=tech_priests_0259_item_count,
    item_proto=function(name)
      return tech_priests_get_item_prototype_0440 and tech_priests_get_item_prototype_0440(name)
    end,
    entity_proto=function(name)
      return tech_priests_get_entity_prototype_0440 and tech_priests_get_entity_prototype_0440(name)
    end,
    entity_from_item=tech_priests_0259_entity_from_item,
    defensive=tech_priests_0259_is_defensive_entity,
    entity_kind=tech_priests_0260_entity_kind,
    unlocked=tech_priests_0646_entity_unlocked,
    allowed=tech_priests_1507_defense_local_allowed,
    band_allowed=tech_priests_0259_perimeter_band_allowed,
    can_place=function(pair,name,position)return tech_priests_0259_can_place(pair,name,position,true) end,
    metadata_ready=function(pair)
      local C=tech_priests_0646_constraints()
      return not(C and C.request_metadata) or C.request_metadata(pair.station.force)==true
    end,
    turrets_near=tech_priests_0259_turrets_near,
    turret_range=tech_priests_0646_turret_range,
    queue_breach=tech_priests_0259_queue_breach,
    power_items=TECH_PRIESTS_DEFENSE_POWER_SUPPORT_ITEMS_0260,
    pole_range=tech_priests_0260_native_pole_range,
    available=function(pair,item)
      if tech_priests_0259_item_count(pair,item)>0 then return true end
      local network=get_station_logistic_network and get_station_logistic_network(pair.station)
      if not(network and logistic_network_item_count) then return false end
      local ok,count=pcall(logistic_network_item_count,network,{name=item,count=1})
      return ok and tonumber(count) and count>0 or false
    end,
    power_witness=function(pair,position,pole)
      if not(pole and pole.valid and pole.force==pair.station.force) then return false end
      local network_id=pole.electric_network_id
      local supply=tech_priests_0260_native_pole_range(pole.prototype,
        "get_supply_area_distance",pole.quality and pole.quality.name or "normal")
      return type(network_id)=="number" and network_id>0 and supply
        and math.abs(pole.position.x-position.x)<=supply+0.35
        and math.abs(pole.position.y-position.y)<=supply+0.35 or false
    end,
    pole_witness=function(pair,entity,position,pole)
      local proto=tech_priests_get_entity_prototype_0440 and tech_priests_get_entity_prototype_0440(entity)
      return tech_priests_0260_connected_pole_site(pair,proto,position,{pole})
    end,
    planned_fluid=function(pair)
      local op=pair.independent_emergency_operation_0184
        or (tech_priests_get_emergency_operation_0184 and tech_priests_get_emergency_operation_0184(pair))
      if not op then return nil end
      if op.magos_pipe_fluid_0258 then return op.magos_pipe_fluid_0258 end
      if op.construction and op.construction.planned_fluid_0258 then return op.construction.planned_fluid_0258 end
      local fluids=op.magos_ratio_plan_0257 and op.magos_ratio_plan_0257.fluids
      local name=fluids and next(fluids)
      if name and next(fluids,name)==nil then return name end
    end,
    stored_fluid=function(entity)
      local data=storage and storage.tech_priests and storage.tech_priests.placement_safety_0258
      local surface=data and data.fluid_runs and data.fluid_runs[tostring(entity.surface.index)]
      local rec=surface and surface[math.floor(entity.position.x)..":"..math.floor(entity.position.y)]
      return rec and rec.fluid
    end,
  })
end
_G.TechPriestsDefensePerimeter0259={
  has_pending=tech_priests_0818_has_pending,
  service_pair=tech_priests_0818_service_pair,
  -- Read-only live native electrical-grid probe for layered defense tests.
  -- This never places an entity, changes inventory or claims powered status.
  connected_laser_supply_at=tech_priests_0260_position_has_power,
  -- Testable read-only proposed-pole wire connectivity; never builds it.
  connected_laser_pole_site=tech_priests_0260_connected_pole_site,
}
if tick_pair then
  TECH_PRIESTS_TICK_PAIR_BEFORE_0259 = tick_pair
  function tick_pair(pair)
    local state=pair and pair.defense_perimeter_0259
    if state and state.last_dispatcher_service_tick_0818
        and game and game.tick-state.last_dispatcher_service_tick_0818<=30 then
      -- Canonical dispatcher owns current hostile response; let unrelated
      -- legacy housekeeping proceed without racing its physical build task.
      return TECH_PRIESTS_TICK_PAIR_BEFORE_0259(pair)
    end
    -- Legacy standalone perimeter tests do not load the full Factorio mod
    -- path; only resolve the canonical incident owner for actual live memory.
    if pair and pair.defense_perimeter_0259
        and pair.defense_perimeter_0259.hostile_incidents_0817 then
      local incident_memory=rawget(_G,"TechPriestsCombatDefenseReaction0816")
      assert(incident_memory and type(incident_memory.reconcile_pair)=="function",
        "hostile defense memory must be preloaded during control.lua parsing")
      incident_memory.reconcile_pair(pair,tech_priests_0259_turrets_near)
    end
    local state=pair and pair.defense_perimeter_0259
    local damage=state and state.last_hostile_damage_0816
    local recent=damage and game and (game.tick-damage.tick)<=7200
    local pending=state and ((state.threats and #state.threats>0)
      or (state.unresolved_incidents_0817 or 0)>0)
    -- Hostile damage may preempt an unrelated routine objective, but never
    -- seize an item while another subsystem holds physical logistics custody.
    -- The emergency craft, machine recipe and inventory are not reset.
    local safe_to_defend=pair and not (
        pair.machine_logistics_custody_0528
        or pair.direct_acquisition_custody_0513
        or pair.emergency_facility_feed_custody_0357)
    local urgent=safe_to_defend and (pending or (recent and pair.defense_task_0259))
    if safe_to_defend and pair.defense_task_0259 then
      local blocked = tech_priests_0259_higher_priority_visible(pair)
      if (urgent or not blocked)
          and tech_priests_0259_handle_task(pair) then return true end
    end
    if safe_to_defend and tech_priests_0259_valid_pair(pair) then
      local blocked = tech_priests_0259_higher_priority_visible(pair)
      if (urgent or not blocked)
          and tech_priests_0259_service_perimeter(pair) then return true end
    end
    return TECH_PRIESTS_TICK_PAIR_BEFORE_0259(pair)
  end
end

if commands and commands.add_command then
  pcall(function()
    commands.add_command("tp-defense-debug", "Tech Priests: report Cogitator Station defense perimeter state for the selected station.", function(event)
      local player = game.get_player(event.player_index)
      if not player then return end
      local pair = nil
      if tech_priests_find_pair_for_player_selection_0184 then pair = tech_priests_find_pair_for_player_selection_0184(player) end
      if not pair and player.selected and player.selected.valid and get_pair_by_station then pair = get_pair_by_station(player.selected) end
      if not pair then player.print("[Tech Priests] Select a Cogitator Station or priest first."); return end
      local state = tech_priests_0259_defense_state(pair)
      local wall_count, gate_count, turret_count, invalid_count = 0, 0, 0, 0
      for _, rec in pairs(state.walls or {}) do
        if rec and rec.entity and rec.entity.valid then wall_count = wall_count + 1 else invalid_count = invalid_count + 1 end
      end
      for _, rec in pairs(state.gates or {}) do if rec and rec.entity and rec.entity.valid then gate_count = gate_count + 1 else invalid_count = invalid_count + 1 end end
      for _, rec in pairs(state.turrets or {}) do if rec and rec.entity and rec.entity.valid then turret_count = turret_count + 1 else invalid_count = invalid_count + 1 end end
      local turret_item, turret_entity = tech_priests_0259_select_turret(pair)
      player.print("[Tech Priests] defense perimeter diagnostics:")
      player.print("  station=" .. tostring(pair.station and pair.station.valid and pair.station.name or "nil") .. " unit=" .. tostring(pair.station and pair.station.valid and pair.station.unit_number or "nil"))
      player.print("  radius=" .. tostring(state.last_radius or "unknown") .. " walls=" .. tostring(wall_count) .. " gates=" .. tostring(gate_count) .. " fire_slots=" .. tostring(turret_count) .. " invalid_records=" .. tostring(invalid_count))
      player.print("  breaches=" .. tostring(state.breaches and #state.breaches or 0) .. " active_task=" .. tostring(pair.defense_task_0259 and pair.defense_task_0259.type or "none"))
      player.print("  wall_items=" .. tostring(tech_priests_0259_item_count(pair, TECH_PRIESTS_DEFENSE_WALL_ITEM_0259)) .. " last_reason=" .. tostring(state.last_reason or "none"))
      player.print("  preferred_turret=" .. tostring(turret_item or "none") .. " entity=" .. tostring(turret_entity or "none") .. " support_kind=" .. tostring(turret_entity and tech_priests_0260_entity_kind(turret_entity) or "none"))
      player.print("  built_walls=" .. tostring(state.built or 0) .. " built_gates=" .. tostring(state.gates_built_0646 or 0) .. " recovered_walls=" .. tostring(state.recovered or 0) .. " turrets_built=" .. tostring(state.turrets_built or 0) .. " supports_built=" .. tostring(state.supports_built_0260 or 0))
      local incidents=state.hostile_incidents_0817 or {}
      player.print("  hostile_incidents="..#incidents..
        " unresolved="..tostring(state.unresolved_incidents_0817 or 0)..
        " suppressed="..tostring(state.suppressed_new_incidents_0817 or 0))
      for i=1,math.min(#incidents,8) do
        local incident=incidents[i]
        local pos=incident.position or {}
        local quiet=math.max(0,math.ceil(
          ((incident.expires_at or 0)-game.tick)/60))
        local hot=math.max(0,math.ceil(
          ((incident.active_until or 0)-game.tick)/60))
        player.print("  incident#"..tostring(incident.id or i)..
          " center="..tostring(math.floor((pos.x or 0)*10)/10)..
          ","..tostring(math.floor((pos.y or 0)*10)/10)..
          " hits="..tostring(incident.hit_count or 0)..
          " waves="..tostring(incident.waves or 1)..
          " phase="..(hot>0 and "hot" or "cooling")..
          " hot_s="..tostring(hot)..
          " retention_s="..tostring(quiet)..
          " defended="..tostring(incident.covered==true))
      end
    end)
  end)
end

tech_priests_0259_diag("defense perimeter executor loaded with bounded 1507 force planning and native support validation")
