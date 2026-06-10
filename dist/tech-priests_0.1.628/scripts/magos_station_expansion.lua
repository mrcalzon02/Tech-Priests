-- Tech Priests 0.1.256: ranked Cogitator Station expansion doctrine.
-- When a Planetary Magos standard-industry placement cannot find room inside
-- its current command radius, it may project a Cogitator Station ghost near the
-- edge of its range.  The ghost is always one tier lower than the commander,
-- except Junior stations which may only replicate Junior stations.  Subordinate
-- Tech-Priests attempt to acquire the station item, travel to the ghost, and
-- complete construction; if no subordinate exists, the task stays recorded and
-- the requester falls back to ordinary acquisition/planning until help or items
-- become available.

local M = {}

TECH_PRIESTS_STATION_EXPANSION_VERSION_0256 = "0.1.256+0.1.259-resource-direction"
TECH_PRIESTS_STATION_EXPANSION_RETRY_TICKS_0256 = 60 * 15
TECH_PRIESTS_STATION_EXPANSION_BUILD_TICKS_0256 = 60 * 6
TECH_PRIESTS_STATION_EXPANSION_APPROACH_RADIUS_0256 = 1.25
TECH_PRIESTS_STATION_EXPANSION_MAX_GHOSTS_PER_REQUESTER_0256 = 3

TECH_PRIESTS_STATION_EXPANSION_BY_RANK_0256 = {
  [4] = "senior-cogitator-station",
  [3] = "intermediate-cogitator-station",
  [2] = "junior-cogitator-station",
  [1] = "junior-cogitator-station"
}

local function diag(message)
  if log then log("[Tech Priests 0.1.256 station expansion] " .. tostring(message)) end
end

local function ensure()
  if ensure_storage then ensure_storage() end
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.station_expansion_0256 = storage.tech_priests.station_expansion_0256 or {}
  storage.tech_priests.station_expansion_by_worker_0256 = storage.tech_priests.station_expansion_by_worker_0256 or {}
  storage.tech_priests.station_expansion_next_id_0256 = storage.tech_priests.station_expansion_next_id_0256 or 1
end

local function distance_sq(a, b)
  if tech_priests_0252_distance_sq then return tech_priests_0252_distance_sq(a, b) end
  if tech_priests_distance_sq_0186 then return tech_priests_distance_sq_0186(a, b) end
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function angle_diff_0259(a, b)
  if not (a and b) then return 0 end
  local d = math.abs((a - b + math.pi) % (math.pi * 2) - math.pi)
  return d
end

local function valid_pair(pair)
  if tech_priests_0252_valid_pair then return tech_priests_0252_valid_pair(pair) end
  return pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid
end

local function station_unit(pair)
  return pair and pair.station and pair.station.valid and pair.station.unit_number or nil
end

local function rank_number(pair)
  if tech_priests_0252_rank_number then
    local ok, n = pcall(function() return tech_priests_0252_rank_number(pair) end)
    if ok and n then return n end
  end
  if tech_priests_0255_rank_number then
    local ok, n = pcall(function() return tech_priests_0255_rank_number(pair) end)
    if ok and n then return n end
  end
  return 1
end

function M.allowed_station_item_for_pair(pair)
  local rank = math.floor(rank_number(pair) or 1)
  if rank >= 4 then return TECH_PRIESTS_STATION_EXPANSION_BY_RANK_0256[4] end
  return TECH_PRIESTS_STATION_EXPANSION_BY_RANK_0256[rank] or "junior-cogitator-station"
end

function M.required_worker_rank_for_pair(pair)
  local rank = math.floor(rank_number(pair) or 1)
  if rank <= 1 then return 1 end
  return rank - 1
end

local function item_valid(item_name)
  return item_name and tech_priests_get_item_prototype_0440 and tech_priests_get_item_prototype_0440(item_name)
end

local function entity_valid(entity_name)
  return entity_name and tech_priests_get_entity_prototype_0440 and tech_priests_get_entity_prototype_0440(entity_name)
end

local function can_place_station(pair, station_name, pos)
  if not (valid_pair(pair) and station_name and pos and entity_valid(station_name)) then return false end
  if not tech_priests_surface_supports_martian_emergency_doctrine_0184 or not tech_priests_surface_supports_martian_emergency_doctrine_0184(pair.station.surface) then return false end
  if tech_priests_position_ground_ok_0186 then
    local ok, ground = pcall(function() return tech_priests_position_ground_ok_0186(pair, pos) end)
    if ok and not ground then return false end
  end
  local ok, can = pcall(function()
    return pair.station.surface.can_place_entity({ name = station_name, position = pos, force = pair.station.force })
  end)
  if ok and can then return true end
  return false
end

local function find_station_ghost_position(pair, station_name, preferred_angle)
  if not valid_pair(pair) then return nil end
  local station = pair.station
  local radius = refresh_pair_radius and refresh_pair_radius(pair) or pair.radius or 20
  radius = math.max(8, radius or 20)
  local inner = math.max(4, radius - 4)
  local candidates = {}
  for angle_i = 0, 31 do
    local angle = (math.pi * 2) * (angle_i / 32)
    for offset = 0, 7 do
      local r = radius - offset
      if r >= inner then
        local pos = {
          x = math.floor(station.position.x + math.cos(angle) * r) + 0.5,
          y = math.floor(station.position.y + math.sin(angle) * r) + 0.5
        }
        if distance_sq(pos, station.position) <= radius * radius and can_place_station(pair, station_name, pos) then
          local directional_penalty = 0
          if preferred_angle then directional_penalty = angle_diff_0259(angle, preferred_angle) * 2.0 end
          candidates[#candidates + 1] = { position = pos, score = math.abs(r - radius) + offset * 0.01 + directional_penalty }
        end
      end
    end
  end
  table.sort(candidates, function(a, b) return (a.score or 0) < (b.score or 0) end)
  return candidates[1] and candidates[1].position or nil
end

local function create_station_ghost(pair, station_name, position)
  if not (valid_pair(pair) and station_name and position) then return nil end
  local ghosts = pair.station.surface.find_entities_filtered({
    name = "entity-ghost",
    ghost_name = station_name,
    force = pair.station.force,
    area = {{position.x - 0.75, position.y - 0.75}, {position.x + 0.75, position.y + 0.75}},
    limit = 1
  })
  if ghosts and ghosts[1] and ghosts[1].valid then return ghosts[1] end
  local ok, ghost = pcall(function()
    return pair.station.surface.create_entity({
      name = "entity-ghost",
      inner_name = station_name,
      position = position,
      force = pair.station.force,
      expires = false
    })
  end)
  if ok and ghost and ghost.valid then return ghost end
  return nil
end

local function get_pair_by_station_unit(unit)
  if tech_priests_0252_get_pair_by_station_unit then return tech_priests_0252_get_pair_by_station_unit(unit) end
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[unit] or nil
end

local function find_exact_rank_subordinate(requester_pair, required_rank)
  if not (valid_pair(requester_pair) and storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return nil end
  ensure()
  local station = requester_pair.station
  local radius = refresh_pair_radius and refresh_pair_radius(requester_pair) or requester_pair.radius or 20
  local best, best_score = nil, nil
  for _, other in pairs(storage.tech_priests.pairs_by_station or {}) do
    if other ~= requester_pair and valid_pair(other) then
      local other_unit = station_unit(other)
      if other.station.surface == station.surface and other.station.force == station.force and not storage.tech_priests.station_expansion_by_worker_0256[other_unit] then
        if math.floor(rank_number(other) or 1) == required_rank then
          local other_radius = refresh_pair_radius and refresh_pair_radius(other) or other.radius or 20
          local allowed = math.max(radius, other_radius) * (TECH_PRIESTS_ASSIGNMENT_RADIUS_MULTIPLIER_0252 or 1.35)
          local score = distance_sq(other.station.position, station.position)
          if score <= allowed * allowed and (not best_score or score < best_score) then best, best_score = other, score end
        end
      end
    end
  end
  -- Junior stations are allowed to replicate Junior stations even when no
  -- lower-rank subordinate exists; the requester becomes its own construction worker.
  if not best and required_rank == 1 and math.floor(rank_number(requester_pair) or 1) == 1 then return requester_pair end
  return best
end

function M.request_station_expansion(requester_pair, blocked_item, op, note, preferred_angle)
  if not valid_pair(requester_pair) then return false end
  ensure()
  local requester_unit = station_unit(requester_pair)
  if not requester_unit then return false end
  local now = game.tick
  local existing_count = 0
  for _, rec in pairs(storage.tech_priests.station_expansion_0256 or {}) do
    if rec.requester_station_unit == requester_unit and rec.status == "active" then
      existing_count = existing_count + 1
      if rec.blocked_item == blocked_item and now < (rec.next_retry_tick or 0) then return true end
    end
  end
  if existing_count >= TECH_PRIESTS_STATION_EXPANSION_MAX_GHOSTS_PER_REQUESTER_0256 then return true end

  local station_item = M.allowed_station_item_for_pair(requester_pair)
  if not (item_valid(station_item) and entity_valid(station_item)) then return false end
  local position = find_station_ghost_position(requester_pair, station_item, preferred_angle)
  if not position then return false end
  local ghost = create_station_ghost(requester_pair, station_item, position)
  if not (ghost and ghost.valid) then return false end

  local required_rank = M.required_worker_rank_for_pair(requester_pair)
  local worker = find_exact_rank_subordinate(requester_pair, required_rank)
  local id = storage.tech_priests.station_expansion_next_id_0256
  storage.tech_priests.station_expansion_next_id_0256 = id + 1
  local rec = {
    id = id,
    status = "active",
    requester_station_unit = requester_unit,
    requester_rank = rank_number(requester_pair),
    required_worker_rank = required_rank,
    worker_station_unit = worker and station_unit(worker) or nil,
    station_item = station_item,
    station_entity = station_item,
    blocked_item = blocked_item,
    ghost_unit = ghost.unit_number,
    ghost_position = { x = ghost.position.x, y = ghost.position.y },
    phase = worker and "assigned" or "awaiting-subordinate",
    note = note,
    preferred_angle = preferred_angle,
    created_tick = now,
    updated_tick = now,
    next_retry_tick = now + TECH_PRIESTS_STATION_EXPANSION_RETRY_TICKS_0256
  }
  storage.tech_priests.station_expansion_0256[id] = rec
  if worker then
    local worker_unit = station_unit(worker)
    storage.tech_priests.station_expansion_by_worker_0256[worker_unit] = id
    worker.station_expansion_0256 = rec
    if tech_priests_draw_emergency_operation_status_0184 then
      tech_priests_draw_emergency_operation_status_0184(worker, "[item=" .. station_item .. "] station expansion writ received")
    end
  end
  if op then
    op.station_expansion_request_0256 = id
    op.magos_planner_phase_0255 = "range-expansion-ghost"
    op.magos_planner_item_0255 = station_item
    op.next_tick = now + 60
  end
  if tech_priests_draw_emergency_operation_status_0184 then
    tech_priests_draw_emergency_operation_status_0184(requester_pair, "[item=" .. station_item .. "] projected lower-tier Cogitator ghost for range expansion")
  end
  diag("expansion #" .. tostring(id) .. " requester=" .. tostring(requester_unit) .. " worker=" .. tostring(rec.worker_station_unit or "none") .. " station=" .. station_item .. " blocked=" .. tostring(blocked_item))
  return true
end

local function find_ghost_for_record(pair, rec)
  if not (valid_pair(pair) and rec and rec.ghost_position) then return nil end
  local ghosts = pair.station.surface.find_entities_filtered({
    name = "entity-ghost",
    ghost_name = rec.station_entity,
    force = pair.station.force,
    area = {{rec.ghost_position.x - 1.0, rec.ghost_position.y - 1.0}, {rec.ghost_position.x + 1.0, rec.ghost_position.y + 1.0}},
    limit = 1
  })
  return ghosts and ghosts[1] or nil
end

local function actual_station_exists_for_record(pair, rec)
  if not (valid_pair(pair) and rec and rec.ghost_position) then return nil end
  local found = pair.station.surface.find_entities_filtered({
    name = rec.station_entity,
    force = pair.station.force,
    area = {{rec.ghost_position.x - 1.0, rec.ghost_position.y - 1.0}, {rec.ghost_position.x + 1.0, rec.ghost_position.y + 1.0}},
    limit = 1
  })
  return found and found[1] or nil
end

local function finish_record(rec, status, note)
  if not rec then return end
  ensure()
  rec.status = status or "complete"
  rec.note = note or rec.note
  rec.completed_tick = game.tick
  rec.updated_tick = game.tick
  if rec.worker_station_unit then storage.tech_priests.station_expansion_by_worker_0256[rec.worker_station_unit] = nil end
  local worker = get_pair_by_station_unit(rec.worker_station_unit)
  if worker then worker.station_expansion_0256 = nil end
end

function M.service_station_expansion_assignment(worker_pair)
  if not valid_pair(worker_pair) then return false end
  ensure()
  local worker_unit = station_unit(worker_pair)
  local id = worker_unit and storage.tech_priests.station_expansion_by_worker_0256[worker_unit] or nil
  local rec = id and storage.tech_priests.station_expansion_0256[id] or nil
  if not (rec and rec.status == "active") then return false end

  local built = actual_station_exists_for_record(worker_pair, rec)
  if built then
    finish_record(rec, "complete", "station exists")
    return false
  end
  local ghost = find_ghost_for_record(worker_pair, rec)
  if not (ghost and ghost.valid) then
    finish_record(rec, "failed", "ghost missing")
    return false
  end

  -- Respect immediate survival priorities.
  if tech_priests_0248_higher_priority_probe then
    local ok, probe = pcall(function() return tech_priests_0248_higher_priority_probe(worker_pair) end)
    if ok and probe and probe.priority and probe.priority ~= "idle" and probe.priority ~= "invalid" then
      return false
    end
  end

  local inv = get_station_inventory and get_station_inventory(worker_pair.station) or nil
  if not (inv and inv.get_item_count(rec.station_item) > 0) then
    rec.phase = "acquiring-station-item"
    rec.updated_tick = game.tick
    local op = worker_pair.station_expansion_op_0256 or {
      enabled = true,
      reason = "station-expansion",
      phase = "station-expansion-acquisition",
      site = ghost.position,
      next_tick = game.tick,
      started_tick = rec.created_tick or game.tick,
      assignment_parent_id_0252 = rec.id,
      assignment_requests_0252 = {}
    }
    worker_pair.station_expansion_op_0256 = op
    if tech_priests_emergency_operation_acquire_item_0185 then
      return tech_priests_emergency_operation_acquire_item_0185(worker_pair, rec.station_item, op, 1, 0)
    end
    return false
  end

  local pos = ghost.position
  if distance_sq(worker_pair.priest.position, pos) > TECH_PRIESTS_STATION_EXPANSION_APPROACH_RADIUS_0256 * TECH_PRIESTS_STATION_EXPANSION_APPROACH_RADIUS_0256 then
    rec.phase = "moving-to-ghost"
    rec.updated_tick = game.tick
    if issue_priest_command and defines and defines.command then
      issue_priest_command(worker_pair.priest, {
        type = defines.command.go_to_location,
        destination = pos,
        radius = TECH_PRIESTS_STATION_EXPANSION_APPROACH_RADIUS_0256,
        distraction = defines.distraction.none
      })
    end
    if tech_priests_draw_emergency_operation_status_0184 then
      tech_priests_draw_emergency_operation_status_0184(worker_pair, "[item=" .. rec.station_item .. "] moving to Cogitator ghost")
    end
    return true
  end

  if not rec.build_due_tick then
    rec.phase = "building-ghost"
    rec.build_due_tick = game.tick + TECH_PRIESTS_STATION_EXPANSION_BUILD_TICKS_0256
    rec.updated_tick = game.tick
    if tech_priests_stop_priest_0186 then tech_priests_stop_priest_0186(worker_pair) end
    if tech_priests_draw_emergency_operation_status_0184 then
      tech_priests_draw_emergency_operation_status_0184(worker_pair, "[item=" .. rec.station_item .. "] consecrating Cogitator ghost")
    end
    return true
  end
  if game.tick < rec.build_due_tick then
    if tech_priests_stop_priest_0186 then tech_priests_stop_priest_0186(worker_pair) end
    return true
  end

  local removed = inv.remove({ name = rec.station_item, count = 1 }) or 0
  if removed <= 0 then
    rec.phase = "acquiring-station-item"
    rec.build_due_tick = nil
    return true
  end
  local quality = nil
  pcall(function() quality = ghost.quality and ghost.quality.name or nil end)
  if ghost and ghost.valid then pcall(function() ghost.destroy({ raise_destroy = false }) end) end
  local ok, entity = pcall(function()
    return worker_pair.station.surface.create_entity({
      name = rec.station_entity,
      position = rec.ghost_position,
      force = worker_pair.station.force,
      quality = quality,
      create_build_effect_smoke = true,
      raise_built = true
    })
  end)
  if not (ok and entity and entity.valid) then
    inv.insert({ name = rec.station_item, count = 1 })
    rec.phase = "build-failed"
    rec.build_due_tick = nil
    rec.next_retry_tick = game.tick + TECH_PRIESTS_STATION_EXPANSION_RETRY_TICKS_0256
    return true
  end
  if on_built then pcall(function() on_built({ entity = entity }) end) end
  finish_record(rec, "complete", "constructed by subordinate")
  if tech_priests_draw_emergency_operation_status_0184 then
    tech_priests_draw_emergency_operation_status_0184(worker_pair, "[entity=" .. entity.name .. "] range Cogitator constructed")
  end
  return true
end

-- Wrap blocked emergency construction.  If a Magos-rank standard machine cannot
-- fit in current range, project a lower-tier Cogitator ghost instead of simply
-- stalling the planner.
if tech_priests_begin_emergency_construction_0186 and not TECH_PRIESTS_ORIGINAL_BEGIN_EMERGENCY_CONSTRUCTION_0256 then
  TECH_PRIESTS_ORIGINAL_BEGIN_EMERGENCY_CONSTRUCTION_0256 = tech_priests_begin_emergency_construction_0186
  function tech_priests_begin_emergency_construction_0186(pair, item_name, op)
    local result = TECH_PRIESTS_ORIGINAL_BEGIN_EMERGENCY_CONSTRUCTION_0256(pair, item_name, op)
    if result and op and op.phase == "construction-site-blocked" and tech_priests_0255_pair_is_magos_planner and tech_priests_0255_pair_is_magos_planner(pair) then
      M.request_station_expansion(pair, item_name, op, "blocked-construction")
    end
    return result
  end
end

if tick_pair and not TECH_PRIESTS_TICK_PAIR_BEFORE_STATION_EXPANSION_0256 then
  TECH_PRIESTS_TICK_PAIR_BEFORE_STATION_EXPANSION_0256 = tick_pair
  function tick_pair(pair)
    if pair and M.service_station_expansion_assignment(pair) then return true end
    return TECH_PRIESTS_TICK_PAIR_BEFORE_STATION_EXPANSION_0256(pair)
  end
end

if commands and commands.add_command then
  pcall(function()
    commands.add_command("tp-station-expansion-debug", "Tech Priests: report ranked Cogitator ghost-expansion state for the selected station.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      ensure()
      local selected = player.selected
      local pair = nil
      if selected and selected.valid then
        if tech_priests_find_pair_for_player_selection_0184 then pair = tech_priests_find_pair_for_player_selection_0184(player) end
        if not pair and find_pair_for_entity then pair = find_pair_for_entity(selected) end
        if not pair and selected.unit_number then pair = get_pair_by_station_unit(selected.unit_number) end
      end
      if not pair then
        player.print("[Tech Priests] Select a Cogitator Station or Tech-Priest for /tp-station-expansion-debug.")
        return
      end
      local unit = station_unit(pair)
      player.print("[Tech Priests] station expansion debug: unit=" .. tostring(unit) .. " rank=" .. tostring(rank_number(pair)) .. " may-command=" .. tostring(M.allowed_station_item_for_pair(pair)))
      local worker_id = storage.tech_priests.station_expansion_by_worker_0256[unit]
      if worker_id then
        local r = storage.tech_priests.station_expansion_0256[worker_id]
        player.print("  worker expansion #" .. tostring(worker_id) .. " station=" .. tostring(r and r.station_item) .. " phase=" .. tostring(r and r.phase) .. " requester=" .. tostring(r and r.requester_station_unit))
      else
        player.print("  worker expansion: none")
      end
      local any = false
      for id, r in pairs(storage.tech_priests.station_expansion_0256 or {}) do
        if r.requester_station_unit == unit and r.status == "active" then
          any = true
          player.print("  requested expansion #" .. tostring(id) .. " station=" .. tostring(r.station_item) .. " worker=" .. tostring(r.worker_station_unit or "none") .. " phase=" .. tostring(r.phase) .. " blocked=" .. tostring(r.blocked_item))
        end
      end
      if not any then player.print("  requested expansions: none") end
    end)
  end)
end

_G.TECH_PRIESTS_STATION_EXPANSION_0256 = M
diag("ranked station ghost expansion doctrine loaded")

return M
