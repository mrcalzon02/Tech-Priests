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
-- Load at control initialization, never during a live Factorio tick.
local StationRecycling0822 = require("scripts.core.station_recycling_0822")
local StationRelocation0823 = require("scripts.core.station_relocation_0823")
local StationCargo0824 = require("scripts.core.station_cargo_0824")

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
      -- A retained remote-resource writ owns its one physical ghost until
      -- finished or failed. Never issue duplicate stations just because a
      -- retry timer elapsed while its commander is fetching materials.
      if rec.blocked_item == blocked_item
          and (type(blocked_item)=="string"
            and blocked_item:sub(1,9)=="resource:"
            or now < (rec.next_retry_tick or 0)) then return true end
    end
  end
  if existing_count >= TECH_PRIESTS_STATION_EXPANSION_MAX_GHOSTS_PER_REQUESTER_0256 then return true end

  local station_item = M.allowed_station_item_for_pair(requester_pair)
  if not (item_valid(station_item) and entity_valid(station_item)) then return false end
  local required_rank = M.required_worker_rank_for_pair(requester_pair)
  local resource_writ=type(blocked_item)=="string"
      and blocked_item:sub(1,9)=="resource:"
  -- Physical remote-resource relay: the actual parent builds its immediate
  -- lower-rank successor, THEN the new paired priest builds the next link.
  -- Existing subordinates retain their own assignments and inventory.
  local worker=resource_writ and requester_pair
      or find_exact_rank_subordinate(requester_pair,required_rank)
  local commander_bootstrap=resource_writ
  local worker_unit=worker and station_unit(worker)
  if worker_unit
      and storage.tech_priests.station_expansion_by_worker_0256[worker_unit] then
    return false
  end
  -- Reserve the physical builder BEFORE creating a ghost, otherwise a
  -- second writ for a busy commander leaves an orphan station ghost.
  local position = find_station_ghost_position(requester_pair, station_item, preferred_angle)
  if not position then return false end
  local ghost = create_station_ghost(requester_pair, station_item, position)
  if not (ghost and ghost.valid) then return false end
  local id = storage.tech_priests.station_expansion_next_id_0256
  storage.tech_priests.station_expansion_next_id_0256 = id + 1
  local rec = {
    id = id,
    status = "active",
    requester_station_unit = requester_unit,
    requester_rank = rank_number(requester_pair),
    required_worker_rank = required_rank,
    worker_station_unit = worker and station_unit(worker) or nil,
    commander_bootstrap = commander_bootstrap,
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

-- The unit must physically visit the inventory it collects from or returns to.
local function move_to_stock(worker, rec, phase)
  if distance_sq(worker.priest.position, worker.station.position) <= 25 then
    return false
  end
  rec.phase = phase
  rec.updated_tick = game.tick
  if issue_priest_command and defines and defines.command then
    issue_priest_command(worker.priest, {
      type = defines.command.go_to_location,
      destination = worker.station.position, radius = 2,
      distraction = defines.distraction.none
    })
  end
  return true
end

function M.service_station_expansion_assignment(worker_pair)
  if not valid_pair(worker_pair) then return false end
  ensure()
  local worker_unit = station_unit(worker_pair)
  local id = worker_unit and storage.tech_priests.station_expansion_by_worker_0256[worker_unit] or nil
  local rec = id and storage.tech_priests.station_expansion_0256[id] or nil
  if not (rec and rec.status == "active") then return false end

  local inv = get_station_inventory and get_station_inventory(worker_pair.station) or nil
  local has_cargo = StationCargo0824.has_record(rec)
  local built = actual_station_exists_for_record(worker_pair, rec)
  if built then
    if has_cargo then
      local cargo, reason = StationCargo0824.get(worker_pair, rec)
      if not cargo then rec.phase = reason; return true end
      if cargo.status == "carrying" then
        if move_to_stock(worker_pair, rec, "returning-unused-station-item") then return true end
        local returned, why = StationCargo0824.return_unused(worker_pair, rec, inv)
        if not returned then rec.phase = why; return true end
      elseif cargo.status ~= "building" then
        rec.phase = "station-cargo-" .. tostring(cargo.status)
        return true
      end
    end
    if StationRelocation0823.pending_for_record(rec) then
      if not StationRelocation0823.claim(built) then
        rec.phase = "relocation-awaiting-priest-pair"
        return true
      end
    end
    if has_cargo then
      local cargo = StationCargo0824.get(worker_pair, rec)
      if cargo and cargo.status == "building" then
        local done, why = StationCargo0824.complete(worker_pair, rec)
        if not done then rec.phase = why; return true end
      end
    end
    finish_record(rec, "complete", "physical station exists and cargo reconciled")
    return false
  end
  local ghost = find_ghost_for_record(worker_pair, rec)
  if not (ghost and ghost.valid) then
    if has_cargo or StationRelocation0823.pending_for_record(rec) then
      -- Do not retire a mission while it owns a real carried station item
      -- or a detached living priest. Reconstitute only the missing ghost.
      ghost = create_station_ghost(worker_pair, rec.station_entity, rec.ghost_position)
      if not (ghost and ghost.valid) then
        rec.phase = "ghost-missing-with-physical-custody"
        return true
      end
      rec.ghost_unit = ghost.unit_number
      local cargo = StationCargo0824.get(worker_pair, rec)
      if cargo and cargo.status == "building" then
        local refunded, why = StationCargo0824.build_failed(worker_pair, rec)
        if not refunded then rec.phase = why; return true end
        StationRelocation0823.build_failed(rec)
      end
    else
      finish_record(rec, "failed", "ghost missing")
      return false
    end
  end

  -- A rejected physical build keeps its ghost and returned station item,
  -- but cannot hammer the same blocked tile every service tick.
  if rec.phase == "build-failed" and game.tick < (rec.next_retry_tick or 0) then
    return false
  end

  -- Respect immediate survival priorities.
  if tech_priests_0248_higher_priority_probe then
    local ok, probe = pcall(function() return tech_priests_0248_higher_priority_probe(worker_pair) end)
    if ok and probe and probe.priority and probe.priority ~= "idle" and probe.priority ~= "invalid" then
      return false
    end
  end

  local pending_lease = StationRelocation0823.pending_for_record(rec)
  if pending_lease and (pending_lease.status ~= "mined" or not has_cargo) then
    -- Never create or acquire a second station while a detached living
    -- priest's mined item is in disputed or missing physical custody.
    rec.phase = "relocation-lease-custody-" .. tostring(pending_lease.status)
    return true
  end
  if not has_cargo and not (inv and inv.get_item_count(rec.station_item) > 0) then
    rec.phase = "acquiring-station-item"
    rec.updated_tick = game.tick
    -- Recovery is a real trip to the existing lower-ranked station. Only
    -- after the worker reaches it may LuaEntity.mine fill its engine-owned
    -- carried inventory. No remote station-to-station transfer is allowed.
    if game.tick >= (rec.next_recycle_probe_tick_0822 or 0) then
      rec.next_recycle_probe_tick_0822 = game.tick + StationRecycling0822.probe_interval
      local previous = rec.recycling_candidate_unit_0822
      local candidate, reason = StationRecycling0822.find_candidate(
        worker_pair, rec.station_item, rec.ghost_position)
      rec.recycling_candidate_unit_0822 = candidate and station_unit(candidate) or nil
      rec.recycling_preflight_0822 = reason
      if previous ~= rec.recycling_candidate_unit_0822 then
        rec.recovery_move_started_tick_0825 = nil
      end
    end
    if rec.recycling_candidate_unit_0822 then
      local candidate = get_pair_by_station_unit(rec.recycling_candidate_unit_0822)
      if not valid_pair(candidate) then
        rec.recycling_candidate_unit_0822 = nil
        rec.recycling_preflight_0822 = "recovery-candidate-no-longer-valid"
        rec.recovery_move_started_tick_0825 = nil
      elseif distance_sq(worker_pair.priest.position, candidate.station.position) > 25 then
        rec.recovery_move_started_tick_0825 =
          rec.recovery_move_started_tick_0825 or game.tick
        if game.tick - rec.recovery_move_started_tick_0825 > 60 * 120 then
          rec.recycling_candidate_unit_0822 = nil
          rec.recycling_preflight_0822 = "physical-recovery-travel-timeout"
          rec.recovery_move_started_tick_0825 = nil
          rec.next_recycle_probe_tick_0822 =
            game.tick + StationRecycling0822.probe_interval
        elseif issue_priest_command and defines and defines.command
            and defines.distraction then
          rec.phase = "moving-to-physical-station-recovery"
          issue_priest_command(worker_pair.priest, {
            type = defines.command.go_to_location,
            destination = candidate.station.position, radius = 2,
            distraction = defines.distraction.none
          })
          return true
        else
          rec.recycling_preflight_0822 = "recovery-movement-command-unavailable"
        end
      else
        rec.recovery_move_started_tick_0825 = nil
        local recovered, reason = StationRelocation0823.try_recover_carried(
          worker_pair, candidate, rec, ghost)
        rec.recycling_preflight_0822 = reason
        if recovered then
          rec.phase = "station-item-physically-recovered-to-priest-cargo"
          return true
        end
        rec.phase = "station-recovery-blocked"
      end
    end
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

  -- A real Factorio unit has no character inventory. Its station item is
  -- debited from the station only at local pickup and held in an engine-owned
  -- LuaInventory bound to the priest's identity while it travels.
  if not has_cargo then
    if move_to_stock(worker_pair, rec, "moving-to-physical-pickup") then return true end
    local picked, reason = StationCargo0824.pickup(worker_pair, rec, inv)
    if not picked then rec.phase = reason; return true end
  else
    local cargo, reason = StationCargo0824.get(worker_pair, rec)
    if not cargo or cargo.status ~= "carrying" then
      rec.phase = reason or "station-cargo-" .. tostring(cargo.status)
      return true
    end
  end
  rec.recycling_candidate_unit_0822 = nil
  rec.recycling_preflight_0822 = nil
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

  -- Preserve the ghost until a real entity exists. Destroying it before
  -- create_entity used to strand the expansion after a collision/error, and
  -- an unchecked refund could silently erase the physical station item.
  -- The cargo currently holds a normal-quality station item. Never turn
  -- that into a higher-quality entity merely because a ghost requested it.
  local quality = nil
  pcall(function() quality = ghost.quality and ghost.quality.name or nil end)
  if quality and quality ~= "normal" then
    rec.phase = "ghost-quality-does-not-match-carried-item"
    rec.updated_tick = game.tick
    return true
  end
  local removed, debit_reason = StationCargo0824.begin_build(worker_pair, rec)
  if not removed then
    rec.phase = debit_reason
    rec.build_due_tick = nil
    return true
  end
  -- A recycled station must have its preserved priest's lease ready
  -- before a real station item is consumed by Factorio construction.
  if StationRelocation0823.pending_for_record(rec)
      and not StationRelocation0823.begin_build(rec, worker_pair) then
    local refunded, why = StationCargo0824.build_failed(worker_pair, rec)
    rec.phase = refunded and "relocation-lease-not-ready" or why
    rec.build_due_tick = nil
    return true
  end
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
  -- A built-event callback can throw AFTER Factorio has created the entity.
  -- Re-observe the physical site before refunding, or a successful build
  -- would also receive its consumed station item back.
  if not (ok and entity and entity.valid) then
    entity = actual_station_exists_for_record(worker_pair, rec)
  end
  if not (entity and entity.valid) then
    StationRelocation0823.build_failed(rec)
    local refund_ok, refund_reason = StationCargo0824.build_failed(worker_pair, rec)
    if not refund_ok then
      -- Retain the live writ, inventory reference and preserved priest lease.
      -- Retiring the worker here would orphan the only custody evidence.
      rec.phase = "station-item-refund-custody-error"
      rec.note = "carried station item refund failed: " .. tostring(refund_reason)
      rec.updated_tick = game.tick
      diag("CRITICAL expansion #" .. tostring(rec.id)
        .. " station item custody unresolved; mission retained for recovery")
      return true
    end
    if not (ghost and ghost.valid) then
      local restored = create_station_ghost(worker_pair, rec.station_entity, rec.ghost_position)
      if not (restored and restored.valid) then
        rec.phase = "ghost-missing-with-physical-custody"
        rec.note = "ghost restoration failed while physical station item remains carried"
        rec.updated_tick = game.tick
        return true
      end
      rec.ghost_unit = restored.unit_number
    end
    rec.phase = "build-failed"
    rec.build_due_tick = nil
    rec.updated_tick = game.tick
    rec.next_retry_tick = game.tick + TECH_PRIESTS_STATION_EXPANSION_RETRY_TICKS_0256
    return true
  end
  if ghost and ghost.valid then
    pcall(function() ghost.destroy({ raise_destroy = false }) end)
  end
  if on_built then pcall(function() on_built({ entity = entity }) end) end
  if StationRelocation0823.pending_for_record(rec)
      and not StationRelocation0823.claim(entity) then
    rec.phase = "relocation-awaiting-priest-pair"
    return true
  end
  local cargo_done, cargo_reason = StationCargo0824.complete(worker_pair, rec)
  if not cargo_done then
    rec.phase = cargo_reason
    return true
  end
  finish_record(rec, "complete", "constructed by subordinate from carried physical item")
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
          player.print("  requested expansion #" .. tostring(id) .. " station=" .. tostring(r.station_item) .. " worker=" .. tostring(r.worker_station_unit or "none") .. " phase=" .. tostring(r.phase) .. " blocked=" .. tostring(r.blocked_item)
            .. " recovery_candidate=" .. tostring(r.recycling_candidate_unit_0822 or "none")
            .. " recovery_preflight=" .. tostring(r.recycling_preflight_0822 or "not-probed"))
        end
      end
      if not any then player.print("  requested expansions: none") end
    end)
  end)
end

_G.TECH_PRIESTS_STATION_EXPANSION_0256 = M
diag("ranked station ghost expansion doctrine loaded")

return M
