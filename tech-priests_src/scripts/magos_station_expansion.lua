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
local StarvationReversal0850 = require("scripts.core.station_starvation_reversal_0850")
local StarvationOutbound0895 = require("scripts.core.station_starvation_outbound_0895")
local StarvationIntermediate0911 = require("scripts.core.station_starvation_intermediate_0911")

TECH_PRIESTS_STATION_EXPANSION_VERSION_0256 = "0.1.256+0.1.259-resource-direction"
TECH_PRIESTS_STATION_EXPANSION_RETRY_TICKS_0256 = 60 * 15
TECH_PRIESTS_STATION_EXPANSION_BUILD_TICKS_0256 = 60 * 6
-- A real station ghost is collision-blocking: headless Factorio measured
-- carrier center-distance squared of 2.3502, 7.0181 and then 14.6366,
-- repeatedly halting outside successively enlarged movement radii.
-- Movement completion MUST share the authoritative 0824 physical build reach,
-- rather than maintain a smaller magic threshold that can never be reached.
-- Cargo.begin_build still independently checks the actual priest position,
-- the exact ghost site and the one-item engine-owned inventory debit.
-- This never grants remote stock access, movement teleport or extra reach.
TECH_PRIESTS_STATION_EXPANSION_APPROACH_RADIUS_0256 =
  math.sqrt(StationCargo0824.reach_sq)
-- Factorio's go_to_location radius is a MOVEMENT stopping boundary, not
-- physical item-build reach. The engine stopped 5.087 tiles from a ghost
-- with radius=5 (distance_sq=25.87890625), leaving real cargo stranded.
-- Ask the unit to move farther inward, but accept construction ONLY within
-- the unchanged 0824 five-tile custody boundary. Ghost collision may stop
-- the unit short of the requested radius; this is safe once inside reach.
local GHOST_MOVEMENT_COMMAND_RADIUS_0256 = 3
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
  storage.tech_priests.station_reversal_followup_0911 = storage.tech_priests.station_reversal_followup_0911 or {}
end

-- Allow early, idempotent registry initialization before a newly built
-- station has a paired priest or a planner tick. The ordinary executor uses
-- the same ensure() function, so reservations and next IDs are never reset.
function M.ensure_state()
  ensure()
  return true
end

local function distance_sq(a, b)
  if tech_priests_0252_distance_sq then return tech_priests_0252_distance_sq(a, b) end
  if tech_priests_distance_sq_0186 then return tech_priests_distance_sq_0186(a, b) end
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

-- Pure geometry shared by movement and regression tests. This only detects
-- real proximity; engine Cargo.begin_build independently enforces a 5-tile
-- physical reach and a one-item inventory debit.
function M.is_at_ghost_build_standoff(worker_position,ghost_position)
  return worker_position~=nil and ghost_position~=nil
    and distance_sq(worker_position,ghost_position)
      <= TECH_PRIESTS_STATION_EXPANSION_APPROACH_RADIUS_0256
        * TECH_PRIESTS_STATION_EXPANSION_APPROACH_RADIUS_0256
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

-- A ghost already occupying a site belongs to an existing construction
-- intent, not to the new writ. Factorio can permit a ghost over a buildable
-- tile, so can_place_entity alone does not establish exclusive ownership.
-- A failed scan is treated as occupied rather than risking shared custody.
local function station_ghost_occupies_site(pair, position)
  if not (valid_pair(pair) and position) then return true end
  local ok, ghosts = pcall(function()
    return pair.station.surface.find_entities_filtered({
      name = "entity-ghost",
      -- 0903: an entity-ghost from ANY force can physically obstruct this
      -- site. Never treat a different force's ghost as free placement.
      area = {{position.x - 0.75, position.y - 0.75},
        {position.x + 0.75, position.y + 0.75}},
      limit = 1
    })
  end)
  if not ok or type(ghosts) ~= "table" then return true end
  for _, existing in pairs(ghosts) do
    if existing and existing.valid then return true end
  end
  return false
end

-- 0898: recovery must choose a site that is actually closer to the
-- original ore, not merely the best angular candidate. When the outer
-- perimeter is blocked, search a bounded inner band before giving up.
-- Ordinary station placement keeps its existing perimeter-only behavior.
local function find_station_ghost_position(pair, station_name, preferred_angle, required_target, excluded_sites, snap_margin)
  if not valid_pair(pair) then return nil end
  local station = pair.station
  local radius = refresh_pair_radius and refresh_pair_radius(pair) or pair.radius or 20
  radius = math.max(8, radius or 20)
  -- 0912: the Intermediate follow-up must leave room for real grid snapping.
  -- Other station placement paths retain their existing exact radius.
  local permitted_radius = math.max(0, radius - (snap_margin or 0))
  local candidates = {}
  local function collect(first_offset,last_offset)
    for angle_i = 0, 31 do
      local angle = (math.pi * 2) * (angle_i / 32)
      for offset = first_offset,last_offset do
        local r = radius - offset
        if r >= 4 and (required_target or r >= math.max(4,radius-4)) then
          local pos = {
            x = math.floor(station.position.x + math.cos(angle) * r) + 0.5,
            y = math.floor(station.position.y + math.sin(angle) * r) + 0.5
          }
          local already_attempted = false
          for _, attempted in ipairs(excluded_sites or {}) do
            if distance_sq(pos, attempted) < 0.25 then
              already_attempted = true
              break
            end
          end
          if not already_attempted
              and distance_sq(pos, station.position) <= permitted_radius * permitted_radius
              and (not required_target or
                distance_sq(pos,required_target)<distance_sq(station.position,required_target))
              and can_place_station(pair, station_name, pos)
              and not station_ghost_occupies_site(pair, pos) then
            local directional_penalty = 0
            if preferred_angle then directional_penalty = angle_diff_0259(angle, preferred_angle) * 2.0 end
            candidates[#candidates + 1] = { position = pos, score = math.abs(r - radius) + offset * 0.01 + directional_penalty }
          end
        end
      end
    end
  end
  collect(0,7)
  if required_target and #candidates==0 then
    collect(8,math.min(math.floor(radius-4),24))
  end
  table.sort(candidates, function(a, b) return (a.score or 0) < (b.score or 0) end)
  return candidates[1] and candidates[1].position or nil
end

-- This is the same bounded, forward-only physical-site selector used by
-- Senior recovery. Exposed for functional Lua regression, not a new planner.
function M.find_outbound_replan_site_0898(pair,station_name,target,excluded_sites)
  if not(valid_pair(pair) and type(target)=="table"
      and type(target.x)=="number" and type(target.y)=="number") then
    return nil
  end
  local origin=pair.station.position
  local angle=math.atan(target.y-origin.y,target.x-origin.x)
  return find_station_ghost_position(pair,station_name,angle,target,excluded_sites)
end

-- 0912: use the existing buildability and collision checks, but reserve a
-- two-tile inward margin for an engine-aligned Intermediate ghost. This does
-- not enlarge any command radius or authorize a site behind the ore target.
function M.find_intermediate_safe_site_0912(pair,station_name,target)
  if not(valid_pair(pair) and type(target)=="table"
      and type(target.x)=="number" and type(target.y)=="number") then
    return nil
  end
  local origin=pair.station.position
  local angle=math.atan(target.y-origin.y,target.x-origin.x)
  return find_station_ghost_position(pair,station_name,angle,target,nil,2)
end

-- 0904: Factorio LuaForce/LuaSurface handles may be re-exposed through
-- distinct LuaObject wrappers. Their engine indices, not wrapper identity,
-- establish the same physical force and surface. Missing or conflicting
-- indices never authorize adopting a foreign ghost.
local function same_engine_domain_0904(observed, expected)
  if not (observed and expected) then return false end
  if observed == expected then return true end
  return type(observed.index) == "number"
    and type(expected.index) == "number"
    and observed.index == expected.index
end

local function ghost_identity_detail_0904(ghost, pair, station_name)
  local function field(fn)
    local ok, value = pcall(fn)
    return ok and tostring(value) or "unreadable"
  end
  return "physical-ghost-identity-unverified:"
    .. "valid=" .. field(function() return ghost.valid end)
    .. ":name=" .. field(function() return ghost.name end)
    .. ":inner=" .. field(function() return ghost.ghost_name end)
    .. ":expected-inner=" .. tostring(station_name)
    .. ":unit=" .. field(function() return ghost.unit_number end)
    .. ":force=" .. field(function() return ghost.force.index end)
    .. ":expected-force=" .. field(function() return pair.station.force.index end)
    .. ":surface=" .. field(function() return ghost.surface.index end)
    .. ":expected-surface=" .. field(function() return pair.station.surface.index end)
end

local function create_station_ghost(pair, station_name, position)
  if not (valid_pair(pair) and station_name and position) then return nil end
  -- Never adopt another writ's ghost, including on recovery after a
  -- save/reload. A carried station item must wait for a genuinely free site.
  if station_ghost_occupies_site(pair, position) then
    return nil, "physical-site-ghost-occupied"
  end
  local ok, ghost = pcall(function()
    return pair.station.surface.create_entity({
      name = "entity-ghost",
      inner_name = station_name,
      position = position,
      force = pair.station.force
    })
  end)
  -- 0902: LuaSurface.create_entity in Factorio 2.0 does not accept
  -- "expires" for entity-ghosts. The old unsupported argument was hidden
  -- by pcall and surfaced only as a generic creation refusal in the engine.
  -- Keep the real API error visible to the strict recovery controller;
  -- neither failure path changes the station item or existing ghost.
  if not ok then
    return nil, "physical-ghost-api-error:" .. tostring(ghost):sub(1,180)
  end
  if not ghost then return nil, "physical-ghost-creation-refused" end
  if ghost.valid and ghost.name == "entity-ghost"
      and ghost.ghost_name == station_name
      and same_engine_domain_0904(ghost.force, pair.station.force)
      and same_engine_domain_0904(ghost.surface, pair.station.surface)
      and type(ghost.unit_number) == "number" then return ghost end
  -- An actual LuaEntity was returned but did not meet identity authority.
  -- Do NOT retry at another site or delete an unverified entity. Surface
  -- the precise engine fields for the next Factorio run; real item custody
  -- remains untouched until an unambiguous ghost can be verified.
  return nil, ghost_identity_detail_0904(ghost, pair, station_name)
end

local function get_pair_by_station_unit(unit)
  if tech_priests_0252_get_pair_by_station_unit then return tech_priests_0252_get_pair_by_station_unit(unit) end
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[unit] or nil
end

-- A physically built station is not yet a functioning resource relay until
-- Factorio has paired a living priest and the hierarchy has accepted the
-- intended rank edge. Keep the existing writ/cargo until that is observable;
-- a ghost, an unpaired entity or a station assigned to another superior is
-- not successful remote-resource expansion.
local function resource_station_link_ready_0820(rec, built)
  -- Derive authority from the persisted resource objective, not a mutable
  -- bootstrap hint that older save records may not carry.
  if not (rec and type(rec.blocked_item) == "string"
      and rec.blocked_item:sub(1, 9) == "resource:") then return true end
  local parent = get_pair_by_station_unit(rec.requester_station_unit)
  local child = built and get_pair_by_station_unit(built.unit_number)
  if not (valid_pair(parent) and valid_pair(child) and child.station == built) then
    return false, "resource-station-awaiting-physical-priest-pair"
  end
  if parent.station.force ~= built.force or parent.station.surface ~= built.surface then
    return false, "resource-station-foreign-domain"
  end
  local parent_rank = math.floor(rank_number(parent) or 0)
  local child_rank = math.floor(rank_number(child) or 0)
  if parent_rank < 1 or child_rank ~= math.max(1, parent_rank - 1)
      or child_rank ~= rec.required_worker_rank then
    return false, "resource-station-rank-mismatch"
  end
  local h = rawget(_G, "TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if not (h and type(h.rebuild) == "function") then
    return false, "resource-station-hierarchy-unavailable"
  end
  local ok = pcall(h.rebuild, "forced")
  if not ok then return false, "resource-station-hierarchy-rebuild-failed" end
  if parent_rank > 1 then
    if type(h.is_direct_subordinate) ~= "function"
        or h.is_direct_subordinate(parent, child) ~= true then
      return false, "resource-station-not-owned-by-requester"
    end
  else
    if type(h.peers) ~= "function" then
      return false, "resource-station-peer-authority-unavailable"
    end
    local peer = false
    for _, p in ipairs(h.peers(parent) or {}) do
      if p == child then peer = true; break end
    end
    if not peer then return false, "resource-station-not-junior-peer" end
  end
  return true
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
  -- Under genuine station-item starvation, reserve an eligible real leaf
  -- immediately when the writ and ghost are created. Waiting for the next
  -- executor tick lets ordinary infrastructure planning occupy that priest
  -- first and can deadlock physical recovery indefinitely. This reserves
  -- only future planning: 0822/0823 recheck full custody before mining.
  if resource_writ and worker and get_station_inventory then
    local stock = get_station_inventory(worker.station)
    if stock and stock.valid and stock.get_item_count then
      local observed, count = pcall(function()
        return stock.get_item_count(station_item)
      end)
      if observed and count == 0 then
        local candidate, reason = StationRecycling0822.find_candidate(
          worker, station_item, ghost.position)
        if candidate then
          rec.recycling_candidate_unit_0822 = station_unit(candidate)
          rec.recycling_preflight_0822 = reason
          rec.next_recycle_probe_tick_0822 =
            now + StationRecycling0822.probe_interval
        else
          -- A fully occupied 4>3>2>1>1 chain cannot yield its Senior until
          -- the distant Junior leaf has been safely recovered first. Record
          -- the actual hierarchy order, not a fabricated station item.
          local mission = worker.resource_expansion_0259
            and worker.resource_expansion_0259.chain_0820
          rec.reversal_plan_0850, rec.reversal_preflight_0850 =
            StarvationReversal0850.preflight(worker,
              mission and mission.target, station_item)
        end
      end
    end
  end
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
  if not (valid_pair(pair) and rec and rec.ghost_position and rec.ghost_unit) then return nil end
  local ghosts = pair.station.surface.find_entities_filtered({
    name = "entity-ghost",
    ghost_name = rec.station_entity,
    force = pair.station.force,
    area = {{rec.ghost_position.x - 1.0, rec.ghost_position.y - 1.0}, {rec.ghost_position.x + 1.0, rec.ghost_position.y + 1.0}}
  })
  -- Never take the first same-prototype ghost in this area: it could belong
  -- to another writ. Recovery and construction must use the reserved entity.
  for _, candidate in pairs(ghosts or {}) do
    if candidate.valid and candidate.unit_number == rec.ghost_unit
        and candidate.ghost_name == rec.station_entity
        and same_engine_domain_0904(candidate.force, pair.station.force)
        and same_engine_domain_0904(candidate.surface, pair.station.surface)
        and distance_sq(candidate.position, rec.ghost_position) < 0.01 then
      return candidate
    end
  end
  return nil
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

-- 0896: restore only the absent 0256-owned Senior construction intent.
-- The 0895 service calls this AFTER independently proving four real depots,
-- original-priest survival, unchanged resource target and exact writ custody.
-- No replacement item or station is created; this is only a ghost.
local function restore_outbound_ghost_attempt_0896(pair,rec,owned)
  if not(valid_pair(pair) and rec and rec.status=="active"
      and rec.station_entity=="senior-cogitator-station"
      and rec.station_item==rec.station_entity
      and rec.worker_station_unit==station_unit(pair)
      and rec.ghost_unit and rec.ghost_position) then
    return nil,"original-writ-unverified"
  end
  -- 0905: a returned real ghost at an unverified engine position must not
  -- be followed by another placement attempt, even after save/reload.
  -- Retain only primitive evidence; the original writ and cargo stay intact.
  if rec.outbound_unverified_ghost_0905 then
    return nil,"physical-ghost-position-quarantined:"..
      tostring(rec.outbound_unverified_ghost_0905.reason)
  end
  if rec.next_outbound_restore_tick_0897
      and game.tick<rec.next_outbound_restore_tick_0897 then
    -- Preserve the first observed engine refusal across same-tick service
    -- calls; a generic backoff must not erase the physical-site blocker.
    return nil,"physical-site-retry-backoff:"..
      tostring(rec.outbound_restore_last_refusal_0901 or "unobserved")
  end
  rec.next_outbound_restore_tick_0897=game.tick+600
  local mission=pair.resource_expansion_0259
    and pair.resource_expansion_0259.chain_0820
  local target=mission and mission.target
  if not(target and type(target.x)=="number"
      and type(target.y)=="number") then
    return nil,"original-resource-target-unavailable"
  end
  local origin=pair.station.position
  local site=rec.ghost_position
  -- 0900: an exact-writ ghost can also be outside the Magos's CURRENT
  -- command radius even while pointing toward ore. Do not adopt or build
  -- it at illegal range: relocate only that verified ghost through the
  -- existing bounded, physically buildable site planner.
  local radius=tonumber(pair.radius)
  if type(_G.refresh_pair_radius)=="function" then
    local radius_ok,current=pcall(_G.refresh_pair_radius,pair)
    if radius_ok and tonumber(current) then radius=tonumber(current) end
  end
  local outside=not(radius and radius>0
    and distance_sq(origin,site)<=radius*radius)
  if owned then
    if not(owned.valid and owned.name=="entity-ghost"
        and owned.ghost_name==rec.station_entity
        and owned.unit_number==rec.ghost_unit
        and same_engine_domain_0904(owned.force,pair.station.force)
        and same_engine_domain_0904(owned.surface,pair.station.surface)
        and distance_sq(owned.position,site)<0.01
        and (outside or distance_sq(site,target)>=distance_sq(origin,target))) then
      return nil,"original-owned-ghost-identity-or-progress-changed"
    end
  end
  -- A different writ's ghost is not ours to delete, but it also must not
  -- permanently pin the recovered Senior item to this obsolete location.
  -- Preserve that ghost and choose a separate, buildable forward site.
  local foreign_ghost_at_original_site=
    not owned and station_ghost_occupies_site(pair,site)
  local ok,occupied=pcall(actual_station_exists_for_record,pair,rec)
  if not ok then return nil,"original-site-station-scan-unavailable" end
  if occupied then return nil,"original-site-built-station-occupied" end
  if owned or foreign_ghost_at_original_site
      or distance_sq(site,target)>=distance_sq(origin,target)
      or not can_place_station(pair,rec.station_entity,site) then
    local alternate=M.find_outbound_replan_site_0898(
      pair,rec.station_entity,target)
    if not(alternate and distance_sq(alternate,site)>0.01
        and distance_sq(alternate,target)<distance_sq(origin,target)
        and not station_ghost_occupies_site(pair,alternate)
        and can_place_station(pair,rec.station_entity,alternate)) then
      return nil,"no-safe-outward-replan-site"
    end
    site=alternate
  end
  -- Place the new ghost before removing ONLY the original owned ghost.
  -- If original destruction fails, remove the new ghost to avoid duplicates.
  -- No station item is consumed in either path.
  -- 0903: Factorio may refuse LuaSurface.create_entity for a particular
  -- tile even when can_place_entity accepted the underlying station.
  -- Do not repeat that tile indefinitely. Retry only an unambiguous nil
  -- creation with no resulting ghost, on distinct forward, in-range sites.
  -- API exceptions, unverified entity identity and ambiguous placement
  -- remain fail-closed. No station item is debited during this search.
  local restored,creation_reason
  local attempted={}
  local max_attempts=8
  for attempt=1,max_attempts do
    attempted[#attempted+1]={x=site.x,y=site.y}
    restored,creation_reason=create_station_ghost(pair,rec.station_entity,site)
    if restored and restored.valid then
      -- Factorio may snap a multi-tile entity ghost to its prototype grid.
      -- The engine-returned position is authoritative, not the requested
      -- half-tile candidate. Accept at most a half-tile shift on each axis,
      -- and only if the ACTUAL ghost remains forward and in command range.
      -- 0895 then binds the same writ to that observed physical position.
      local actual=restored.position
      local observed=actual and type(actual.x)=="number"
        and type(actual.y)=="number"
      local shift=observed and distance_sq(actual,site) or math.huge
      if shift<=0.500001
          and distance_sq(actual,origin)<=radius*radius
          and distance_sq(actual,target)<distance_sq(origin,target) then
        break
      end
      local detail="physical-ghost-position-unverified:requested="..
        tostring(site.x)..","..tostring(site.y)..
        ":actual="..tostring(actual and actual.x)..","..
        tostring(actual and actual.y)..":shift-sq="..tostring(shift)
      -- Do not destroy an unexpectedly placed real ghost or try a second
      -- site: either could create an orphan or duplicate construction writ.
      rec.outbound_unverified_ghost_0905={
        unit=restored.unit_number,
        position=observed and {x=actual.x,y=actual.y} or nil,
        reason=detail
      }
      return nil,detail
    end
    if creation_reason~="physical-ghost-creation-refused" then
      return nil,creation_reason or "physical-ghost-identity-unverified"
    end
    -- A nil API result is not proof that no ghost was placed. Re-observe
    -- the actual world before selecting another construction intent.
    if station_ghost_occupies_site(pair,site) then
      return nil,"physical-ghost-creation-ambiguous-occupied"
    end
    if attempt==max_attempts then
      return nil,"physical-ghost-creation-refused:distinct-sites="..attempt
    end
    local next_site=M.find_outbound_replan_site_0898(
      pair,rec.station_entity,target,attempted)
    if not(next_site and distance_sq(next_site,site)>0.25
        and distance_sq(next_site,origin)<=radius*radius
        and distance_sq(next_site,target)<distance_sq(origin,target)
        and not station_ghost_occupies_site(pair,next_site)
        and can_place_station(pair,rec.station_entity,next_site)) then
      return nil,"physical-ghost-creation-refused:distinct-sites="..
        attempt..":no-safe-alternative"
    end
    site=next_site
  end
  if owned then
    local removed=pcall(function() owned.destroy() end)
    if not removed or owned.valid then
      local cleaned=pcall(function()
        if restored.valid then restored.destroy() end
      end)
      if not cleaned or restored.valid then
        return nil,"owned-ghost-replan-cleanup-uncertain"
      end
      return nil,"owned-ghost-replan-old-destroy-refused"
    end
  end
  return restored
end
-- Remember the original failure, not a later 600-tick throttle response.
-- This changes no item, ghost, movement, rank or construction authority.
local function restore_outbound_ghost_0896(pair,rec,owned)
  local ghost,reason=restore_outbound_ghost_attempt_0896(pair,rec,owned)
  if type(rec)=="table" then
    if ghost then
      rec.outbound_restore_last_refusal_0901=nil
    elseif type(reason)=="string"
        and reason:sub(1,27)~="physical-site-retry-backoff" then
      rec.outbound_restore_last_refusal_0901=reason
    end
  end
  return ghost,reason
end
M.restore_outbound_ghost_0896=restore_outbound_ghost_0896

local function finish_record(rec, status, note)
  if not rec then return end
  ensure()
  rec.status = status or "complete"
  rec.note = note or rec.note
  rec.completed_tick = game.tick
  rec.updated_tick = game.tick
  -- 0911: only a completed, physically reconciled original Senior rebuild
  -- may reserve the next Intermediate ghost. This receipt grants NO item.
  if rec.status=="complete" and rec.reversal_outbound_0895
      and rec.reversal_outbound_0895.phase=="senior-build-authorized"
      and rec.reversal_stage_0854 and rec.worker_station_unit then
    storage.tech_priests.station_reversal_followup_0911[rec.worker_station_unit]=rec.id
  end
  if rec.worker_station_unit then storage.tech_priests.station_expansion_by_worker_0256[rec.worker_station_unit] = nil end
  local worker = get_pair_by_station_unit(rec.worker_station_unit)
  if worker then worker.station_expansion_0256 = nil end
  -- The original Magos is already in this production callback after the
  -- counted Senior build. Reserve the next real ghost here as well as on
  -- later scheduler ticks; do not rely on a CI-only pulse or idle polling.
  if rec.status=="complete" and rec.reversal_outbound_0895
      and rec.reversal_outbound_0895.phase=="senior-build-authorized"
      and worker then
    M.service_reversal_intermediate_0911(worker)
  end
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

-- The replacement priest must physically visit the dead carrier's site.
-- The original LuaInventory stays intact; no free item is created.
local function reclaim_fallen_carrier(worker,rec)
  local site,reason=StationCargo0824.stranded_for(worker,rec)
  if not site then return false,reason end
  if distance_sq(worker.priest.position,site)>25 then
    if not (issue_priest_command and defines and defines.command
        and defines.distraction) then
      return false,"death-site-recovery-movement-unavailable"
    end
    issue_priest_command(worker.priest,{
      type=defines.command.go_to_location,
      destination=site,radius=2,distraction=defines.distraction.none
    })
    return false,"moving-to-fallen-carrier-cargo"
  end
  return StationCargo0824.reclaim_stranded(worker,rec)
end

-- The existing per-pair 0256 executor is the production scheduler for the
-- next stage; no CI-only pulse or synthetic inventory transition is needed.
function M.service_reversal_intermediate_0911(magos)
  return StarvationIntermediate0911.service(magos,{
    rank=rank_number,
    radius=function(pair)
      return refresh_pair_radius and refresh_pair_radius(pair) or pair.radius or 20
    end,
    find_site=M.find_intermediate_safe_site_0912,
    create_ghost=create_station_ghost,
    find_ghost=find_ghost_for_record
  })
end

function M.service_station_expansion_assignment(worker_pair)
  if not valid_pair(worker_pair) then return false end
  ensure()
  local worker_unit = station_unit(worker_pair)
  local id = worker_unit and storage.tech_priests.station_expansion_by_worker_0256[worker_unit] or nil
  local rec = id and storage.tech_priests.station_expansion_0256[id] or nil
  if not (rec and rec.status == "active") then
    return M.service_reversal_intermediate_0911(worker_pair)
  end
  -- 0913: this original Senior must walk back to the real Magos depot
  -- and collect exactly the recovered Intermediate item into its 0824 cargo.
  -- Do not enter ordinary station stock, crafting, or construction paths.
  if rec.reversal_followup_0911 then
    local handled,reason=StarvationIntermediate0911.service_pickup(
      worker_pair,rec,{
        rank=rank_number,find_ghost=find_ghost_for_record,
        command=issue_priest_command})
    if reason=="reversal-intermediate-real-item-carried-from-magos" then
      -- 0915: the real Intermediate item remains in the original Senior's
      -- engine-owned carrier. Never enter ordinary acquisition/build here.
      handled,reason=StarvationIntermediate0911.service_outward_transit(
        worker_pair,rec,{
          rank=rank_number,find_ghost=find_ghost_for_record,
          radius=function(pair)
            return refresh_pair_radius and refresh_pair_radius(pair)
              or pair.radius or 20
          end,
          command=issue_priest_command})
    end
    rec.phase=reason
    rec.updated_tick=game.tick
    return handled
  end

  -- A recovered reversal leaf is stored under the stage's own engine-cargo
  -- record, not this Senior station writ's cargo ID. Before checking a built
  -- ghost, station stock or ordinary acquisition, give the staged hold sole
  -- control. Otherwise a lost saved plan or competing ghost can accidentally
  -- retire the writ while an original priest and item remain in 0823/0824
  -- custody. An unavailable stage authority is an explicit quarantine.
  -- 0895: four physically mined and audited station items may begin their
  -- outward journey only through the original Magos's real 0824 cargo.
  -- The recovery writ remains active, its ghost stays untouched, and all
  -- other depot inventories remain protected. No ordinary acquisition/build
  -- path may spend or retire this stage before outbound custody is reconciled.
  local outbound=rec.reversal_outbound_0895
  if outbound and outbound.phase=="senior-build-authorized" then
    -- 0908: only the original staged Senior lease may enter the existing
    -- 0256 real-item debit/build/0823 priest-claim sequence. Keep verifying
    -- all three untouched depots, the original priest and exact build site.
    local ghost=find_ghost_for_record(worker_pair,rec)
    local built=actual_station_exists_for_record(worker_pair,rec)
    local allowed,why=StarvationOutbound0895.verify_authorized_rebuild(
      worker_pair,rec,ghost,built)
    if not allowed then
      rec.phase=why
      rec.updated_tick=game.tick
      return true
    end
  elseif outbound or
      (rec.reversal_stage_0855 and
       rec.reversal_stage_0855.phase=="in-magos-depot") then
    local owned_ghost=find_ghost_for_record(worker_pair,rec)
    local handled,reason
    if outbound and outbound.phase=="senior-carried" then
      handled,reason=StarvationOutbound0895.service_outward_transit(
        worker_pair,rec,issue_priest_command,owned_ghost)
      if reason=="reversal-senior-real-item-arrived-at-ghost"
          and type(outbound.arrived_tick)=="number"
          and game.tick>outbound.arrived_tick then
        handled,reason=StarvationOutbound0895.arm_original_senior_rebuild(
          worker_pair,rec,owned_ghost,
          actual_station_exists_for_record(worker_pair,rec))
      end
    else
      handled,reason=StarvationOutbound0895.service_first_pickup(
        worker_pair,rec,issue_priest_command,owned_ghost,
        restore_outbound_ghost_0896)
    end
    rec.phase=reason
    rec.updated_tick=game.tick
    return handled
  end
  if rec.reversal_stage_0851 and
      not(outbound and outbound.phase=="senior-build-authorized") then
    local handled,reason=StarvationReversal0850.service_first_leaf(
      worker_pair,rec,issue_priest_command)
    rec.phase=handled and reason
      or "reversal-staged-custody-quarantined:"..tostring(reason)
    rec.updated_tick=game.tick
    return true
  end

  local inv = get_station_inventory and get_station_inventory(worker_pair.station) or nil
  local has_cargo = StationCargo0824.has_record(rec)
  if has_cargo then
    local cargo = StationCargo0824.get(worker_pair, rec)
    if not cargo then
      local reclaimed, reason = reclaim_fallen_carrier(worker_pair, rec)
      if not reclaimed then rec.phase = reason; return true end
    end
    StationCargo0824.observe_carrier(worker_pair, rec)
  end
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
    local linked, link_reason = resource_station_link_ready_0820(rec, built)
    if not linked then rec.phase = link_reason; return true end
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

  -- If a save, runtime interruption or callback exception happened after
  -- the physical station item was debited but before the station existed,
  -- the next service must reconcile that exact item before attempting another
  -- debit. This is distinct from the completed-entity path above, which
  -- consumes the debited item without refunding it.
  if has_cargo then
    local cargo = StationCargo0824.get(worker_pair, rec)
    if cargo and cargo.status == "building" then
      local refunded, why = StationCargo0824.build_failed(worker_pair, rec)
      if not refunded then
        rec.phase = why
        rec.updated_tick = game.tick
        return true
      end
      StationRelocation0823.build_failed(rec)
      rec.build_due_tick = nil
      rec.phase = "interrupted-build-item-physically-refunded"
      rec.updated_tick = game.tick
      return true
    end
  end

  -- A rejected physical build keeps its ghost and returned station item,
  -- but cannot hammer the same blocked tile every service tick.
  if rec.phase == "build-failed" and game.tick < (rec.next_retry_tick or 0) then
    return false
  end

  -- Respect genuine immediate survival priorities. A deferred reversal
  -- records the precise blocker rather than sitting forever as "assigned".
  -- Do not cancel or preempt that actual higher-priority duty.
  if tech_priests_0248_higher_priority_probe then
    local ok, probe = pcall(function() return tech_priests_0248_higher_priority_probe(worker_pair) end)
    if ok and probe and probe.priority and probe.priority ~= "idle" and probe.priority ~= "invalid" then
      if rec.reversal_plan_0850 or rec.reversal_stage_0851 then
        rec.phase="reversal-deferred-higher-priority:"..tostring(probe.priority)
        rec.updated_tick=game.tick
      end
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
    -- A five-station starvation reversal has no spare Senior item. Advance
    -- only its first physically audited leaf stage; never allow the ordinary
    -- acquisition fallback to spend or override a staged Junior station item.
    -- The staged carrier remains locked until a later co-located depot
    -- handoff, so no ancestor is dismantled in this iteration.
    if rec.reversal_plan_0850 or rec.reversal_stage_0851 then
      local handled,why=StarvationReversal0850.service_first_leaf(
        worker_pair,rec,issue_priest_command)
      if handled then
        rec.phase=why
        rec.updated_tick=game.tick
        return true
      end
    end
    if rec.reversal_plan_0850
        and game.tick >= (rec.next_reversal_validation_tick_0850 or 0) then
      local mission=worker_pair.resource_expansion_0259
        and worker_pair.resource_expansion_0259.chain_0820
      local valid_order,why=StarvationReversal0850.validate_plan(
        worker_pair,rec.reversal_plan_0850,
        mission and mission.target,rec.station_item)
      rec.reversal_preflight_0850=why
      rec.next_reversal_validation_tick_0850=
        game.tick+StationRecycling0822.probe_interval
      if not valid_order then
        -- Never execute against a stale saved hierarchy or a retargeted
        -- resource. Continue ordinary physical item acquisition; no station,
        -- detached priest, cargo hold, or external assignment is modified.
        rec.reversal_plan_0850=nil
      end
    end
    -- Recovery is a real trip to the existing lower-ranked station. Only
    -- after the worker reaches it may LuaEntity.mine fill its engine-owned
    -- carried inventory. No remote station-to-station transfer is allowed.
    if game.tick >= (rec.next_recycle_probe_tick_0822 or 0) then
      rec.next_recycle_probe_tick_0822 = game.tick + StationRecycling0822.probe_interval
      local previous = rec.recycling_candidate_unit_0822
      local held = previous and get_pair_by_station_unit(previous) or nil
      if valid_pair(held) and held.station.name == rec.station_item
          and held.station.force == worker_pair.station.force
          and held.station.surface == worker_pair.station.surface then
        -- The first probe selected a real station while its priest was idle.
        -- A later autonomous duty may make that same station temporarily
        -- ineligible. Never erase its physical recovery reservation merely
        -- because a fresh eligible-only scan would omit a busy priest.
        -- try_recover_carried rechecks the complete custody/hierarchy preflight
        -- at the source before ANY real station can be mined.
        local _, reason = StationRecycling0822.check_candidate(
          worker_pair, held, rec.station_item)
        rec.recycling_preflight_0822 = reason
      else
        local candidate, reason = StationRecycling0822.find_candidate(
          worker_pair, rec.station_item, rec.ghost_position)
        rec.recycling_candidate_unit_0822 = candidate and station_unit(candidate) or nil
        rec.recycling_preflight_0822 = reason
        if not candidate then
          local mission = worker_pair.resource_expansion_0259
            and worker_pair.resource_expansion_0259.chain_0820
          rec.reversal_plan_0850, rec.reversal_preflight_0850 =
            StarvationReversal0850.preflight(worker_pair,
              mission and mission.target, rec.station_item)
        end
        if previous ~= rec.recycling_candidate_unit_0822 then
          rec.recovery_move_started_tick_0825 = nil
        end
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
        rec.updated_tick = game.tick
        -- A selected real station remains the recovery candidate even when
        -- its custody becomes temporarily unsafe during the worker's trip.
        -- Retry that physical station; never silently fall through to new
        -- item acquisition while the recovery writ owns the candidate.
        return true
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
  -- A successful physical pickup supersedes the preflight-only starvation
  -- order. No recovery stage may act on stale hierarchy observations.
  rec.reversal_plan_0850 = nil
  rec.reversal_preflight_0850 = nil
  local pos = ghost.position
  if not M.is_at_ghost_build_standoff(worker_pair.priest.position,pos) then
    rec.phase = "moving-to-ghost"
    rec.updated_tick = game.tick
    if issue_priest_command and defines and defines.command then
      issue_priest_command(worker_pair.priest, {
        type = defines.command.go_to_location,
        destination = pos,
        radius = GHOST_MOVEMENT_COMMAND_RADIUS_0256,
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
  local linked, link_reason = resource_station_link_ready_0820(rec, entity)
  if not linked then
    rec.phase = link_reason
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
