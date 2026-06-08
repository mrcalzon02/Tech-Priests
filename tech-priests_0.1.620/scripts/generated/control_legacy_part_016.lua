-- Auto-split control.lua fragment 016 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.


function tech_priests_0271_record_no_resources(worker_pair, resource_name)
  if not (worker_pair and resource_name) then return 0 end
  tech_priests_0271_ensure_storage()
  local worker_unit = tech_priests_0271_station_unit(worker_pair)
  local assignment = worker_pair.assignment_0252 or worker_pair.assignment_op_0252
  local requester_unit = assignment and assignment.requester_station_unit or nil
  if not (requester_unit and worker_unit) then return 0 end

  storage.tech_priests.raw_no_resources_0271[requester_unit] = storage.tech_priests.raw_no_resources_0271[requester_unit] or {}
  local by_item = storage.tech_priests.raw_no_resources_0271[requester_unit]
  by_item[resource_name] = by_item[resource_name] or {}
  by_item[resource_name][worker_unit] = (by_item[resource_name][worker_unit] or 0) + 1
  local count = by_item[resource_name][worker_unit]

  local requester = tech_priests_0252_get_pair_by_station_unit and tech_priests_0252_get_pair_by_station_unit(requester_unit) or nil
  if requester then
    requester.no_resource_subordinates_exhausted_0271 = requester.no_resource_subordinates_exhausted_0271 or {}
    requester.no_resource_subordinates_exhausted_0271[resource_name] = nil
    local op = requester.independent_emergency_operation_0184 or requester.assignment_op_0252 or requester.emergency_operation
    if op then
      op.next_tick = game.tick
      op.next_plan_tick = game.tick
      op.retry_tick = game.tick
      op.wait_until = nil
      op.phase = "subordinate-no-resources-retry"
      op.last_item = resource_name
      op.last_probe_reason = "subordinate " .. tostring(worker_unit) .. " reported no resources here"
    end
    if requester.assignment_op_0252 then requester.assignment_op_0252.next_tick = game.tick end
    requester.next_emergency_operation_tick = game.tick
  end

  tech_priests_0271_log("no-resources ledger requester=" .. tostring(requester_unit) .. " worker=" .. tostring(worker_unit) .. " item=" .. tostring(resource_name) .. " count=" .. tostring(count))
  return count
end

function tech_priests_0271_attempt_count(requester_pair, worker_pair, item_name)
  if not (requester_pair and worker_pair and item_name and storage and storage.tech_priests and storage.tech_priests.raw_no_resources_0271) then return 0 end
  local requester_unit = tech_priests_0271_station_unit(requester_pair)
  local worker_unit = tech_priests_0271_station_unit(worker_pair)
  local by_req = requester_unit and storage.tech_priests.raw_no_resources_0271[requester_unit]
  local by_item = by_req and by_req[item_name]
  return (by_item and worker_unit and by_item[worker_unit]) or 0
end

function tech_priests_0271_can_assign_worker(requester_pair, worker_pair, item_name)
  return tech_priests_0271_attempt_count(requester_pair, worker_pair, item_name) < 2
end

-- Prefer a fresh subordinate.  Exhaust every eligible subordinate once, then
-- allow a second pass, then mark the requester as fully exhausted for that raw
-- resource so the result can be kicked upward.  This deliberately replaces the
-- older nearest-only choice when the requested item is a raw resource.
if tech_priests_0252_find_subordinate_pair then
  TECH_PRIESTS_ORIGINAL_FIND_SUBORDINATE_PAIR_0271 = tech_priests_0252_find_subordinate_pair
  function tech_priests_0252_find_subordinate_pair(requester_pair, item_name, count, chain_depth)
    if not (item_name and tech_priests_0269_is_raw_resource_name and tech_priests_0269_is_raw_resource_name(item_name)) then
      return TECH_PRIESTS_ORIGINAL_FIND_SUBORDINATE_PAIR_0271(requester_pair, item_name, count, chain_depth)
    end
    if not (tech_priests_0252_valid_pair and tech_priests_0252_valid_pair(requester_pair)) then return nil end
    if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return nil end
    tech_priests_0271_ensure_storage()
    local requester_rank = tech_priests_0252_rank_number and tech_priests_0252_rank_number(requester_pair) or 1
    local station = requester_pair.station
    local radius = (refresh_pair_radius and refresh_pair_radius(requester_pair) or requester_pair.radius or 20) * (TECH_PRIESTS_ASSIGNMENT_RADIUS_MULTIPLIER_0252 or 1.35)
    local candidates = {}
    for _, other in pairs(storage.tech_priests.pairs_by_station or {}) do
      if other ~= requester_pair and tech_priests_0252_valid_pair(other) then
        if other.station.surface == station.surface and other.station.force == station.force then
          local other_unit = tech_priests_0271_station_unit(other)
          local other_rank = tech_priests_0252_rank_number and tech_priests_0252_rank_number(other) or 1
          if other_rank < requester_rank and not storage.tech_priests.assignment_by_worker_0252[other_unit] then
            local dist_sq = tech_priests_0252_distance_sq and tech_priests_0252_distance_sq(other.station.position, station.position) or 999999999
            local other_radius = refresh_pair_radius and refresh_pair_radius(other) or other.radius or 20
            local allowed = math.max(radius, other_radius * (TECH_PRIESTS_ASSIGNMENT_RADIUS_MULTIPLIER_0252 or 1.35))
            if dist_sq <= allowed * allowed then
              local attempts = tech_priests_0271_attempt_count(requester_pair, other, item_name)
              candidates[#candidates+1] = { pair = other, attempts = attempts, dist_sq = dist_sq, unit = other_unit }
            end
          end
        end
      end
    end
    table.sort(candidates, function(a,b)
      if a.attempts ~= b.attempts then return a.attempts < b.attempts end
      return (a.dist_sq or 0) < (b.dist_sq or 0)
    end)
    for _, row in ipairs(candidates) do
      if row.attempts < 2 then
        requester_pair.no_resource_subordinates_exhausted_0271 = requester_pair.no_resource_subordinates_exhausted_0271 or {}
        requester_pair.no_resource_subordinates_exhausted_0271[item_name] = nil
        tech_priests_0271_log("raw assignment candidate requester=" .. tostring(tech_priests_0271_station_unit(requester_pair)) .. " worker=" .. tostring(row.unit) .. " item=" .. tostring(item_name) .. " attempts=" .. tostring(row.attempts))
        return row.pair
      end
    end
    if #candidates > 0 then
      requester_pair.no_resource_subordinates_exhausted_0271 = requester_pair.no_resource_subordinates_exhausted_0271 or {}
      requester_pair.no_resource_subordinates_exhausted_0271[item_name] = true
      tech_priests_0271_log("raw subordinates exhausted requester=" .. tostring(tech_priests_0271_station_unit(requester_pair)) .. " item=" .. tostring(item_name) .. " candidates=" .. tostring(#candidates))
    end
    return nil
  end
end

-- Extend the no-resources note so a requester learns which subordinate failed.
if tech_priests_0269_assignment_note_no_resources then
  TECH_PRIESTS_ORIGINAL_NOTE_NO_RESOURCES_0271 = tech_priests_0269_assignment_note_no_resources
  function tech_priests_0269_assignment_note_no_resources(pair, resource_name)
    local local_count = TECH_PRIESTS_ORIGINAL_NOTE_NO_RESOURCES_0271(pair, resource_name) or 0
    tech_priests_0271_record_no_resources(pair, resource_name)
    return local_count
  end
end

function tech_priests_0271_begin_top_dirt(pair, resource_name, reason)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  local task = pair.emergency_craft or {}
  task.item_name = resource_name or task.item_name or "stone"
  task.output_item = resource_name or task.output_item or task.item_name or "stone"
  task.recipe = task.recipe or { units = 1 }
  task.count = task.count or 1
  pair.emergency_craft = task
  pair.mode = "emergency-dirt-scraping"
  pair.no_resource_top_dirt_0271 = (pair.no_resource_top_dirt_0271 or 0) + 1
  tech_priests_0271_log("top-chain dirt begin station=" .. tostring(tech_priests_0271_station_unit(pair)) .. " item=" .. tostring(resource_name) .. " reason=" .. tostring(reason))
  if tech_priests_draw_emergency_operation_status_0184 then
    pcall(function() tech_priests_draw_emergency_operation_status_0184(pair, "chain exhausted; scraping dirt for stone") end)
  end
  if tech_priests_0269_begin_dirt_scrape then
    return tech_priests_0269_begin_dirt_scrape(pair, task, resource_name or "stone")
  end
  return false
end

function tech_priests_0271_kick_no_resources_up(pair, resource_name, note)
  if not (pair and resource_name) then return false end
  local assignment = pair.assignment_0252 or pair.assignment_op_0252
  local requester_unit = assignment and assignment.requester_station_unit or nil
  if requester_unit then
    tech_priests_0271_record_no_resources(pair, resource_name)
    if tech_priests_0252_clear_assignment and assignment then
      pcall(function() tech_priests_0252_clear_assignment(assignment, "failed", note or ("no resources here for " .. tostring(resource_name))) end)
    end
    pair.emergency_craft = nil
    pair.mode = "returning"
    if pair.priest and pair.priest.valid and pair.station and pair.station.valid and return_to_station then pcall(function() return_to_station(pair.priest, pair.station) end) end
    tech_priests_0271_log("kicked no-resources upward worker=" .. tostring(tech_priests_0271_station_unit(pair)) .. " requester=" .. tostring(requester_unit) .. " item=" .. tostring(resource_name))
    return true
  end
  return tech_priests_0271_begin_top_dirt(pair, resource_name, note or "no higher requester")
end

-- If an acquire attempt exhausts every subordinate twice, do not fall back into
-- old silent waiting.  Workers kick the task upward; the top of the chain begins
-- dirt scraping and uses the stone trickle to climb back into infrastructure.
if tech_priests_emergency_operation_acquire_item_0185 then
  TECH_PRIESTS_ORIGINAL_ACQUIRE_ITEM_0271 = tech_priests_emergency_operation_acquire_item_0185
  function tech_priests_emergency_operation_acquire_item_0185(pair, item_name, op, count, depth)
    if pair and pair.no_resource_subordinates_exhausted_0271 then pair.no_resource_subordinates_exhausted_0271[item_name or ""] = nil end
    local handled = TECH_PRIESTS_ORIGINAL_ACQUIRE_ITEM_0271(pair, item_name, op, count, depth)
    if item_name and tech_priests_0269_is_raw_resource_name and tech_priests_0269_is_raw_resource_name(item_name) then
      if pair and pair.no_resource_subordinates_exhausted_0271 and pair.no_resource_subordinates_exhausted_0271[item_name] then
        pair.no_resource_subordinates_exhausted_0271[item_name] = nil
        if op then
          op.phase = "raw-subordinates-exhausted"
          op.last_item = item_name
          op.blocker = "all subordinates reported no resources here twice"
          op.next_tick = game.tick + 60
        end
        return tech_priests_0271_kick_no_resources_up(pair, item_name, "all subordinates exhausted twice") or handled
      end
    end
    return handled
  end
end

-- This earlier hook catches the live raw gather worker before 0.1.270 can clear
-- the assignment locally.  Exact/substitute resources still pass through to the
-- existing handler; true no-resource results are now escalated through the chain.
if handle_emergency_desperation_craft then
  TECH_PRIESTS_ORIGINAL_HANDLE_EMERGENCY_DESPERATION_CRAFT_0271 = handle_emergency_desperation_craft
  function handle_emergency_desperation_craft(pair)
    if pair and pair.emergency_craft then
      local task = pair.emergency_craft
      local requested = tech_priests_0271_raw_request_from_task(task)
      if requested then
        local current = task.current
        local current_ok = current and (current.kind == "dirt" or (current.entity and current.entity.valid))
        local candidates = task.candidates or {}
        local idx = math.max(1, task.index or 1)
        local candidate = candidates[idx]
        local candidate_ok = candidate and ((candidate.kind == "dirt") or (candidate.entity and candidate.entity.valid))
        if (not current_ok) and (not candidate_ok) then
          local cand, mode = nil, nil
          if tech_priests_0269_find_resource_candidate then cand, mode = tech_priests_0269_find_resource_candidate(pair, requested, false) end
          if not cand then
            return tech_priests_0271_kick_no_resources_up(pair, requested, "no resources here")
          end
        end
      end
    end
    return TECH_PRIESTS_ORIGINAL_HANDLE_EMERGENCY_DESPERATION_CRAFT_0271(pair)
  end
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-no-resources-debug", "Tech Priests: report no-resources escalation ledger for selected station.", function(event)
      local player = game.get_player(event.player_index)
      if not player then return end
      local pair = tech_priests_0264_find_pair_for_player and tech_priests_0264_find_pair_for_player(player) or nil
      if not pair and player.selected and player.selected.valid and find_pair_for_entity then
        local ok, got = pcall(function() return find_pair_for_entity(player.selected) end)
        if ok then pair = got end
      end
      if not pair then player.print("No Tech Priest pair selected.") return end
      local unit = tech_priests_0271_station_unit(pair)
      player.print("No-resources escalation for station #" .. tostring(unit))
      local by_req = storage and storage.tech_priests and storage.tech_priests.raw_no_resources_0271 and storage.tech_priests.raw_no_resources_0271[unit]
      if not by_req then player.print("  no subordinate no-resource reports recorded") return end
      for item, by_worker in pairs(by_req) do
        for worker, attempts in pairs(by_worker) do
          player.print("  item=" .. tostring(item) .. " worker=" .. tostring(worker) .. " attempts=" .. tostring(attempts))
        end
      end
    end)
  end)
end

tech_priests_0271_log("0.1.271 no-resources escalation ledger + top-chain dirt fallback loaded")

-- 0.1.272: subordinate liveness/availability watcher + command overview subordinate roster.
-- Assigners must notice when workers die or disappear, and when new lower-ranked
-- stations become available.  This late wrapper keeps the existing assignment
-- system intact while adding a one-second command hierarchy refresh.

TECH_PRIESTS_SUBORDINATE_RESCAN_TICKS_0272 = 60

function tech_priests_0272_log(msg)
  if log then log("[Tech Priests 0.1.272 subordinates] " .. tostring(msg)) end
end

function tech_priests_0272_station_unit(pair)
  if tech_priests_0252_station_unit then return tech_priests_0252_station_unit(pair) end
  return pair and pair.station and pair.station.valid and pair.station.unit_number or nil
end

function tech_priests_0272_rank(pair)
  if tech_priests_0252_rank_number then return tech_priests_0252_rank_number(pair) end
  if tech_priests_get_pair_tier_rank then return tech_priests_get_pair_tier_rank(pair) end
  local tier = pair and pair.tier or "junior"
  local ranks = { junior = 1, intermediate = 2, senior = 3, ["planetary-magos"] = 4, planetary_magos = 4, magos = 4, void = 5 }
  return ranks[tier] or 1
end

function tech_priests_0272_valid_station_pair(pair)
  return pair and pair.station and pair.station.valid
end

function tech_priests_0272_valid_working_pair(pair)
  return pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid
end

function tech_priests_0272_label(pair)
  if tech_priests_0252_assignment_label then return tech_priests_0252_assignment_label(pair) end
  if tech_priests_pair_name_0189 then return tech_priests_pair_name_0189(pair) end
  return tostring(pair and pair.tier or "station") .. "#" .. tostring(tech_priests_0272_station_unit(pair) or "?")
end

function tech_priests_0272_distance_sq(a, b)
  if tech_priests_0252_distance_sq then return tech_priests_0252_distance_sq(a, b) end
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

function tech_priests_0272_assignment_storage()
  if tech_priests_0252_ensure_assignment_storage then tech_priests_0252_ensure_assignment_storage() end
  ensure_storage()
  storage.tech_priests.assignments_0252 = storage.tech_priests.assignments_0252 or {}
  storage.tech_priests.assignment_by_worker_0252 = storage.tech_priests.assignment_by_worker_0252 or {}
  storage.tech_priests.assignment_by_requester_0252 = storage.tech_priests.assignment_by_requester_0252 or {}
end

function tech_priests_0272_enumerate_subordinates(requester_pair, include_busy)
  local rows = {}
  if not (requester_pair and requester_pair.station and requester_pair.station.valid and storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return rows end
  tech_priests_0272_assignment_storage()
  local requester_rank = tech_priests_0272_rank(requester_pair)
  local station = requester_pair.station
  local radius = (refresh_pair_radius and refresh_pair_radius(requester_pair) or requester_pair.radius or 20) * (TECH_PRIESTS_ASSIGNMENT_RADIUS_MULTIPLIER_0252 or 1.35)
  for _, other in pairs(storage.tech_priests.pairs_by_station or {}) do
    if other ~= requester_pair and tech_priests_0272_valid_station_pair(other) then
      if other.station.surface == station.surface and other.station.force == station.force then
        local other_rank = tech_priests_0272_rank(other)
        if other_rank < requester_rank then
          local other_unit = tech_priests_0272_station_unit(other)
          local other_radius = refresh_pair_radius and refresh_pair_radius(other) or other.radius or 20
          local allowed = math.max(radius, other_radius * (TECH_PRIESTS_ASSIGNMENT_RADIUS_MULTIPLIER_0252 or 1.35))
          local dist_sq = tech_priests_0272_distance_sq(other.station.position, station.position)
          if dist_sq <= allowed * allowed then
            local assignment_id = other_unit and storage.tech_priests.assignment_by_worker_0252[other_unit] or nil
            if include_busy or not assignment_id then
              rows[#rows + 1] = {
                pair = other,
                unit = other_unit,
                rank = other_rank,
                dist_sq = dist_sq,
                assignment_id = assignment_id,
                alive = other.priest and other.priest.valid,
                station_alive = other.station and other.station.valid
              }
            end
          end
        end
      end
    end
  end
  table.sort(rows, function(a, b)
    if a.alive ~= b.alive then return a.alive end
    if (a.assignment_id ~= nil) ~= (b.assignment_id ~= nil) then return a.assignment_id == nil end
    if a.rank ~= b.rank then return a.rank > b.rank end
    if a.dist_sq ~= b.dist_sq then return a.dist_sq < b.dist_sq end
    return (a.unit or 0) < (b.unit or 0)
  end)
  return rows
end

function tech_priests_0272_subordinate_signature(rows)
  local parts = {}
  for _, row in ipairs(rows or {}) do
    parts[#parts + 1] = tostring(row.unit or "?") .. ":" .. tostring(row.alive and "alive" or "missing") .. ":" .. tostring(row.assignment_id or "free")
  end
  return table.concat(parts, ",")
end

function tech_priests_0272_mark_requester_ready(pair, reason)
  if not pair then return end
  pair.next_assignment_retry_tick_0270 = game.tick
  if pair.no_resource_subordinates_exhausted_0271 then pair.no_resource_subordinates_exhausted_0271 = nil end
  local op = (tech_priests_get_emergency_operation_0184 and tech_priests_get_emergency_operation_0184(pair)) or pair.independent_emergency_operation_0184 or pair.assignment_op_0252 or pair.emergency_operation_0184 or pair.emergency_operation
  if op then
    op.next_tick = game.tick
    op.phase = reason or op.phase or "subordinate-roster-refresh"
    op.last_probe_reason = reason or "subordinate roster changed"
  end
  if pair.assignment_op_0252 then pair.assignment_op_0252.next_tick = game.tick end
end

function tech_priests_0272_clear_dead_worker_assignment(worker_unit, reason)
  if not worker_unit then return false end
  tech_priests_0272_assignment_storage()
  local id = storage.tech_priests.assignment_by_worker_0252[worker_unit]
  local assignment = id and storage.tech_priests.assignments_0252[id] or nil
  if not (assignment and assignment.status == "active") then return false end
  local requester = tech_priests_0252_get_pair_by_station_unit and tech_priests_0252_get_pair_by_station_unit(assignment.requester_station_unit) or nil
  if tech_priests_0252_clear_assignment then
    pcall(function() tech_priests_0252_clear_assignment(assignment, "failed", reason or "worker subordinate lost") end)
  else
    assignment.status = "failed"
    assignment.note = reason or "worker subordinate lost"
    assignment.completed_tick = game.tick
    storage.tech_priests.assignment_by_worker_0252[worker_unit] = nil
  end
  if requester then
    local op = (tech_priests_get_emergency_operation_0184 and tech_priests_get_emergency_operation_0184(requester)) or requester.independent_emergency_operation_0184 or requester.assignment_op_0252 or requester.emergency_operation_0184 or requester.emergency_operation
    if op and op.assignment_requests_0252 then
      for key, active_id in pairs(op.assignment_requests_0252) do
        if active_id == id then op.assignment_requests_0252[key] = nil end
      end
    end
    tech_priests_0272_mark_requester_ready(requester, "subordinate-lost-reassign")
  end
  tech_priests_0272_log("assignment #" .. tostring(id) .. " cleared because worker #" .. tostring(worker_unit) .. " was lost")
  return true
end

function tech_priests_0272_rescan_subordinate_rosters(force)
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  storage.tech_priests.subordinate_rosters_0272 = storage.tech_priests.subordinate_rosters_0272 or {}
  storage.tech_priests.subordinate_last_scan_0272 = storage.tech_priests.subordinate_last_scan_0272 or 0
  if not force and game.tick < (storage.tech_priests.subordinate_last_scan_0272 + TECH_PRIESTS_SUBORDINATE_RESCAN_TICKS_0272) then return end
  storage.tech_priests.subordinate_last_scan_0272 = game.tick
  tech_priests_0272_assignment_storage()

  -- First, cancel active assignments whose worker pair no longer exists or no longer has a valid priest.
  for worker_unit, id in pairs(storage.tech_priests.assignment_by_worker_0252 or {}) do
    local worker = tech_priests_0252_get_pair_by_station_unit and tech_priests_0252_get_pair_by_station_unit(worker_unit) or nil
    if not tech_priests_0272_valid_working_pair(worker) then
      tech_priests_0272_clear_dead_worker_assignment(worker_unit, "assigned subordinate missing or dead")
    end
  end

  -- Then compare the available/busy subordinate roster for each valid requester.
  for unit, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    if tech_priests_0272_valid_working_pair(pair) then
      local rows = tech_priests_0272_enumerate_subordinates(pair, true)
      local sig = tech_priests_0272_subordinate_signature(rows)
      local prev = storage.tech_priests.subordinate_rosters_0272[unit]
      if prev ~= sig then
        storage.tech_priests.subordinate_rosters_0272[unit] = sig
        pair.subordinates_0272 = rows
        pair.subordinate_roster_changed_tick_0272 = game.tick
        pair.subordinate_roster_signature_0272 = sig
        tech_priests_0272_mark_requester_ready(pair, "subordinate-roster-changed")
        tech_priests_0272_log("roster changed requester=" .. tostring(unit) .. " from=" .. tostring(prev or "new") .. " to=" .. tostring(sig))
      else
        pair.subordinates_0272 = rows
      end
    end
  end
end

-- Allow assignment lookup to benefit from the live roster cache.  This does not
-- change the rank rules; it only makes newly available workers visible quickly.
if tech_priests_0252_find_subordinate_pair then
  TECH_PRIESTS_ORIGINAL_FIND_SUBORDINATE_PAIR_0272 = tech_priests_0252_find_subordinate_pair
  function tech_priests_0252_find_subordinate_pair(requester_pair, item_name, count, chain_depth)
    tech_priests_0272_rescan_subordinate_rosters(false)
    local rows = tech_priests_0272_enumerate_subordinates(requester_pair, false)
    if rows and rows[1] and rows[1].pair then return rows[1].pair end
    return TECH_PRIESTS_ORIGINAL_FIND_SUBORDINATE_PAIR_0272(requester_pair, item_name, count, chain_depth)
  end
end

-- Run the liveness watcher before ordinary pair work once per second.
if tick_pair then
  TECH_PRIESTS_TICK_PAIR_BEFORE_SUBORDINATES_0272 = tick_pair
  function tick_pair(pair)
    tech_priests_0272_rescan_subordinate_rosters(false)
    return TECH_PRIESTS_TICK_PAIR_BEFORE_SUBORDINATES_0272(pair)
  end
end

function tech_priests_0272_subordinate_summary(pair, limit)
  local rows = tech_priests_0272_enumerate_subordinates(pair, true)
  if #rows == 0 then return "none" end
  local parts = {}
  for i, row in ipairs(rows) do
    if i > (limit or 5) then parts[#parts + 1] = "+" .. tostring(#rows - (limit or 5)) .. " more"; break end
    local other = row.pair
    local status = row.alive and "alive" or "MISSING"
    if row.assignment_id then status = status .. "/busy#" .. tostring(row.assignment_id) else status = status .. "/free" end
    parts[#parts + 1] = tech_priests_0272_label(other) .. " (" .. tostring(tech_priests_pair_rank_label_0189 and tech_priests_pair_rank_label_0189(other) or other.tier or "?") .. ", " .. status .. ")"
  end
  return table.concat(parts, "\n")
end

function tech_priests_0272_requested_assignment_summary(pair, limit)
  tech_priests_0272_assignment_storage()
  local unit = tech_priests_0272_station_unit(pair)
  local reqs = unit and storage.tech_priests.assignment_by_requester_0252[unit] or nil
  local parts = {}
  local n = 0
  for id, _ in pairs(reqs or {}) do
    local a = storage.tech_priests.assignments_0252[id]
    if a and a.status == "active" then
      n = n + 1
      if n <= (limit or 4) then
        parts[#parts + 1] = "#" .. tostring(id) .. " [item=" .. tostring(a.item_name or "") .. "] " .. tostring(a.item_name or "?") .. " → station#" .. tostring(a.worker_station_unit or "?") .. " phase=" .. tostring(a.phase or "?")
      end
    end
  end
  if n == 0 then return "none" end
  if n > (limit or 4) then parts[#parts + 1] = "+" .. tostring(n - (limit or 4)) .. " more" end
  return table.concat(parts, "\n")
end

-- Extend the existing overview instead of replacing it.  The selected unit panel
-- gains a subordinate roster and currently requested assignments.
if tech_priests_build_command_overview_0189 then
  TECH_PRIESTS_ORIGINAL_BUILD_COMMAND_OVERVIEW_0272 = tech_priests_build_command_overview_0189
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-subordinates-debug", "Tech Priests: report subordinate roster and active requested assignments for the selected station.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      tech_priests_0272_rescan_subordinate_rosters(true)
      local selected = player.selected
      local pair = nil
      if selected and selected.valid then
        pair = find_pair_by_entity and find_pair_by_entity(selected) or nil
        if not pair and selected.unit_number and tech_priests_0252_get_pair_by_station_unit then pair = tech_priests_0252_get_pair_by_station_unit(selected.unit_number) end
      end
      if not pair then player.print("[Tech Priests] Select a Cogitator Station or Tech-Priest for /tp-subordinates-debug."); return end
      player.print("[Tech Priests] subordinates for " .. tech_priests_0272_label(pair) .. " station#" .. tostring(tech_priests_0272_station_unit(pair)))
      player.print(tech_priests_0272_subordinate_summary(pair, 20))
      player.print("Requested assignments:\n" .. tech_priests_0272_requested_assignment_summary(pair, 20))
    end)
  end)
end

tech_priests_0272_log("0.1.272 subordinate liveness watcher + command overview subordinate roster loaded")

-- ============================================================================
-- 0.1.273: brute-force emergency gather/mining service for idle-looking workers.
-- ============================================================================
-- The 0.1.272 logs show workers holding emergency_craft with candidate lists but
-- current=nil forever.  The assignment chain and station handoff work; the
-- actual gather worker is the dead link.  This wrapper bypasses stale candidate
-- cursors: if a priest has an emergency craft target and no valid current target,
-- it creates a direct mining target from nearby resources/trees/rocks, moves to
-- it, waits one second, then deposits the requested item into its station.

TECH_PRIESTS_VERSION_0273 = "0.1.273"
TECH_PRIESTS_DIRECT_GATHER_TICKS_0273 = 60

function tech_priests_0273_log(msg)
  if tech_priests_0264_log then
    pcall(function() tech_priests_0264_log(tostring(msg), true) end)
  elseif log then
    log("[Tech-Priests 0.1.273] " .. tostring(msg))
  end
end

function tech_priests_0273_item_exists(name)
  if not name then return false end
  if prototypes and prototypes.item and prototypes.item[name] then return true end
  if tech_priests_get_item_prototype_0440 and tech_priests_get_item_prototype_0440(name) then return true end
  return false
end

function tech_priests_0273_station_inventory(pair)
  if get_station_inventory and pair and pair.station and pair.station.valid then
    local ok, inv = pcall(function() return get_station_inventory(pair.station) end)
    if ok and inv then return inv end
  end
  if pair and pair.station and pair.station.valid then
    local ok, inv = pcall(function() return pair.station.get_inventory(defines.inventory.chest) end)
    if ok and inv then return inv end
  end
  return nil
end

function tech_priests_0273_output_from_task(task)
  if not task then return nil end
  return task.item_name or task.raw_item or task.material_item or task.ingredient_item or task.need_item or task.current_item or task.output_item or task.item or task.result
end

function tech_priests_0273_source_names_for_output(output)
  local map = {
    ["iron-plate"] = {"iron-ore", "stone", "copper-ore", "coal"},
    ["copper-plate"] = {"copper-ore", "stone", "iron-ore", "coal"},
    ["steel-plate"] = {"iron-ore", "iron-plate", "stone"},
    ["iron-gear-wheel"] = {"iron-ore", "iron-plate", "stone"},
    ["copper-cable"] = {"copper-ore", "copper-plate", "stone"},
    ["electronic-circuit"] = {"copper-ore", "iron-ore", "stone", "coal"},
    ["firearm-magazine"] = {"iron-ore", "iron-plate", "stone", "coal"},
    ["repair-pack"] = {"iron-ore", "stone", "copper-ore", "wood", "coal"},
    ["sacred-machine-oil"] = {"wood", "coal", "stone", "iron-ore"},
    ["wood"] = {"wood"},
    ["stone"] = {"stone"},
    ["coal"] = {"coal"},
    ["iron-ore"] = {"iron-ore", "stone", "copper-ore", "coal"},
    ["copper-ore"] = {"copper-ore", "stone", "iron-ore", "coal"},
    ["uranium-ore"] = {"uranium-ore", "stone", "iron-ore", "copper-ore"}
  }
  return map[output] or { output, "iron-ore", "copper-ore", "stone", "coal", "wood" }
end

function tech_priests_0273_distance_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

function tech_priests_0273_resource_item_name(entity)
  if not (entity and entity.valid) then return nil end
  local typ = entity.type
  if typ == "tree" then return "wood" end
  if typ == "simple-entity" or typ == "simple-entity-with-owner" or typ == "rock" then return "stone" end
  return entity.name
end

function tech_priests_0273_find_direct_target(pair, output)
  if not (pair and pair.station and pair.station.valid and output) then return nil end
  local station = pair.station
  local radius = refresh_pair_radius and refresh_pair_radius(pair) or pair.radius or 24
  radius = math.max(radius, 24)
  local pos = station.position
  local area = {{pos.x - radius, pos.y - radius}, {pos.x + radius, pos.y + radius}}
  local names = tech_priests_0273_source_names_for_output(output)
  local best, best_score = nil, nil

  local function consider(entity, preferred_index)
    if not (entity and entity.valid) then return end
    local d = tech_priests_0273_distance_sq(entity.position, pos)
    if d > radius * radius then return end
    local score = d + ((preferred_index or 99) * 100000)
    if not best_score or score < best_score then
      best_score = score
      best = entity
    end
  end

  for i, name in ipairs(names) do
    if name == "wood" then
      local ok_trees, trees = pcall(function()
        return station.surface.find_entities_filtered({ area = area, type = "tree", limit = 64 })
      end)
      if ok_trees then
        for _, e in pairs(trees or {}) do consider(e, i) end
      end
    else
      -- 0.1.275: name may be an item/intermediate (iron-plate, gear, circuit), not a map resource entity.
      -- Factorio throws on find_entities_filtered(name=<unknown entity>), so never pass item-only names here.
      local resource_proto = nil
      pcall(function()
        resource_proto = prototypes and prototypes.entity and prototypes.entity[name]
      end)
      if resource_proto and resource_proto.type == "resource" then
        local ok_ents, ents = pcall(function()
          return station.surface.find_entities_filtered({ area = area, type = "resource", name = name, limit = 64 })
        end)
        if ok_ents then
          for _, e in pairs(ents or {}) do consider(e, i) end
        end
      else
        if tech_priests_0264_log then
          tech_priests_0264_log("direct-gather-skip non-resource-name=" .. tostring(name) .. " output=" .. tostring(output), true)
        end
      end
    end
  end

  -- Rocks are a last-ditch harvestable stone substitute if no true resource patch exists.
  if not best then
    local rocks = station.surface.find_entities_filtered({ area = area, type = {"simple-entity", "simple-entity-with-owner"}, limit = 64 })
    for _, e in pairs(rocks or {}) do
      local n = e.name or ""
      if string.find(n, "rock", 1, true) or string.find(n, "stone", 1, true) then consider(e, 90) end
    end
  end

  if best then
    return {
      kind = "direct-mine-0273",
      entity = best,
      item_name = tech_priests_0273_resource_item_name(best),
      output_item = output,
      value = 1,
      station_distance_sq = best_score or 0,
      unit_number = best.unit_number or 0,
    }
  end
  return nil
end

function tech_priests_0273_begin_dirt(pair, task, output, reason)
  if not (pair and pair.station and pair.station.valid and task) then return false end
  local station = pair.station
  local radius = math.min(8, refresh_pair_radius and refresh_pair_radius(pair) or 8)
  local angle = ((game.tick or 0) * 0.257) % 6.28318
  local dist = 2 + (((game.tick or 0) % 41) / 41) * math.max(1, radius - 2)
  local pos = { x = station.position.x + math.cos(angle) * dist, y = station.position.y + math.sin(angle) * dist }
  task.current = { kind = "direct-dirt-0273", output_item = "stone", item_name = "stone", position = pos, reason = reason or output }
  task.direct_due_tick_0273 = nil
  pair.mode = "emergency-dirt-scraping"
  pair.target = nil
  if pair.priest and pair.priest.valid then
    pcall(function()
      if tech_priests_request_movement_0418 then
        tech_priests_request_movement_0418(pair, pos, "legacy-direct-gather", { radius = 0.75, owner = "direct-gather", priority = 55, distraction = defines.distraction.by_enemy })
      else
        pair.priest.set_command({ type = defines.command.go_to_location, destination = pos, radius = 0.75, distraction = defines.distraction.by_enemy })
      end
    end)
  end
  tech_priests_0273_log("direct dirt begin station=" .. tostring(station.unit_number) .. " output=stone reason=" .. tostring(reason or output))
  return true
end

function tech_priests_0273_deposit(pair, item, count)
  if not (pair and pair.station and pair.station.valid and item) then return false end
  count = math.max(1, count or 1)
  local inv = tech_priests_0273_station_inventory(pair)
  if inv and inv.can_insert({ name = item, count = count }) then
    inv.insert({ name = item, count = count })
    return true
  end
  pcall(function()
    pair.station.surface.spill_item_stack({ position = pair.priest and pair.priest.valid and pair.priest.position or pair.station.position, stack = { name = item, count = count }, force = pair.station.force, allow_belts = false })
  end)
  return true
end

function tech_priests_0273_service_direct_current(pair, task)
  local cur = task and task.current or nil
  if not cur then return false end
  if cur.kind ~= "direct-mine-0273" and cur.kind ~= "direct-dirt-0273" then return false end
  if not (pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid) then return false end
  local pos = cur.position or (cur.entity and cur.entity.valid and cur.entity.position) or pair.station.position
  local dx = pair.priest.position.x - pos.x
  local dy = pair.priest.position.y - pos.y
  if dx * dx + dy * dy > (EMERGENCY_CRAFT_PICKUP_DISTANCE_SQ or 2.25) then
    pcall(function()
      if tech_priests_request_movement_0418 then
        tech_priests_request_movement_0418(pair, pos, "legacy-direct-gather", { radius = 0.75, owner = "direct-gather", priority = 55, distraction = defines.distraction.by_enemy })
      else
        pair.priest.set_command({ type = defines.command.go_to_location, destination = pos, radius = 0.75, distraction = defines.distraction.by_enemy })
      end
    end)
    pair.mode = cur.kind == "direct-dirt-0273" and "emergency-dirt-scraping" or "emergency-gathering"
    return true
  end
  if not task.direct_due_tick_0273 then
    task.direct_due_tick_0273 = game.tick + TECH_PRIESTS_DIRECT_GATHER_TICKS_0273
    pair.mode = cur.kind == "direct-dirt-0273" and "emergency-dirt-scraping" or "emergency-gathering"
    if draw_priest_status_bubble then pcall(function() draw_priest_status_bubble(pair) end) end
    return true
  end
  if game.tick < task.direct_due_tick_0273 then
    pair.mode = cur.kind == "direct-dirt-0273" and "emergency-dirt-scraping" or "emergency-gathering"
    -- 0.1.306: the visible mining beam must represent real work, not just a
    -- decorative line.  Pulse smoke and light source damage while the priest is
    -- close to the direct target so resource harvesting visibly progresses.
    if cur.entity and cur.entity.valid then
      if draw_emergency_craft_scan_line then pcall(function() draw_emergency_craft_scan_line(pair, cur.entity) end) end
      if (not task.direct_last_visual_tick_0306) or game.tick - task.direct_last_visual_tick_0306 >= 15 then
        task.direct_last_visual_tick_0306 = game.tick
        if spawn_emergency_craft_smoke then pcall(function() spawn_emergency_craft_smoke(pair, cur.entity.position, false) end) end
        pcall(function()
          if cur.entity.valid and cur.entity.health and cur.entity.health > 1 then
            cur.entity.damage(5, pair.station.force, "impact", pair.priest)
          end
        end)
      end
    elseif cur.position and spawn_emergency_craft_smoke and ((not task.direct_last_visual_tick_0306) or game.tick - task.direct_last_visual_tick_0306 >= 20) then
      task.direct_last_visual_tick_0306 = game.tick
      pcall(function() spawn_emergency_craft_smoke(pair, cur.position, false) end)
    end
    return true
  end

  -- 0.1.306: apply the actual extraction hit before depositing the output.
  -- Resource patches lose amount; trees/rocks/simple entities take damage and
  -- can be destroyed.  This keeps the emergency mining rite honest.
  if cur.entity and cur.entity.valid then
    if draw_emergency_craft_scan_line then pcall(function() draw_emergency_craft_scan_line(pair, cur.entity) end) end
    if spawn_emergency_craft_smoke then pcall(function() spawn_emergency_craft_smoke(pair, cur.entity.position, true) end) end
    pcall(function()
      local e = cur.entity
      if e.valid and e.type == "resource" then
        local amount = e.amount or 0
        if amount > 1 then
          e.amount = math.max(1, amount - 25)
        else
          e.destroy()
        end
      elseif e.valid and e.health and e.health > 0 then
        local hit = math.max(25, math.min(125, (e.prototype and e.prototype.max_health or 100) * 0.35))
        e.damage(hit, pair.station.force, "impact", pair.priest)
        if e.valid and e.health and e.health <= 1 then e.destroy() end
      end
    end)
  elseif cur.position and spawn_emergency_craft_smoke then
    pcall(function() spawn_emergency_craft_smoke(pair, cur.position, true) end)
  end

  local output = cur.output_item or tech_priests_0273_output_from_task(task) or "stone"
  if not tech_priests_0273_item_exists(output) then output = "stone" end
  tech_priests_0273_deposit(pair, output, 1)
  tech_priests_0273_log("direct gather complete station=" .. tostring(pair.station.unit_number) .. " output=" .. tostring(output) .. " source=" .. tostring(cur.item_name) .. " kind=" .. tostring(cur.kind))
  pair.emergency_craft = nil
  pair.mode = "returning"
  pair.target = nil
  if return_to_station then pcall(function() return_to_station(pair.priest, pair.station) end) end
  return true
end

function tech_priests_0273_kick_worker(pair, reason)
  local task = pair and pair.emergency_craft
  if not task then return false end
  local cur = task.current
  local ok_current = cur and ((cur.entity and cur.entity.valid) or cur.kind == "direct-dirt-0273" or cur.kind == "direct-mine-0273" or cur.kind == "dirt")
  if ok_current then return false end
  local output = tech_priests_0273_output_from_task(task)
  if not output then return false end
  -- If the assignment is for a carried higher product but the visible task is a
  -- sub-product, prefer the visible/current product.  This is the item the
  -- worker needs to produce right now.
  local target = output
  local cand = tech_priests_0273_find_direct_target(pair, target)
  if cand then
    task.current = cand
    task.candidates = { cand }
    task.index = 1
    task.scan_due_tick = nil
    task.craft_due_tick = nil
    task.direct_due_tick_0273 = nil
    pair.mode = "emergency-gathering"
    tech_priests_0273_log("direct gather target station=" .. tostring(pair.station and pair.station.unit_number) .. " target=" .. tostring(target) .. " source=" .. tostring(cand.item_name) .. " reason=" .. tostring(reason))
    return tech_priests_0273_service_direct_current(pair, task)
  end
  -- No visible resource/rock/tree at all.  Dirt scraping now actually executes,
  -- rather than merely changing the label and letting the old idle wander win.
  return tech_priests_0273_begin_dirt(pair, task, target, reason or "no direct target")
end

if handle_emergency_desperation_craft then
  TECH_PRIESTS_ORIGINAL_HANDLE_EMERGENCY_DESPERATION_CRAFT_0273 = handle_emergency_desperation_craft
  function handle_emergency_desperation_craft(pair)
    if pair and pair.emergency_craft then
      local task = pair.emergency_craft
      if task.current and (task.current.kind == "direct-mine-0273" or task.current.kind == "direct-dirt-0273") then
        return tech_priests_0273_service_direct_current(pair, task)
      end
      local current = task.current
      local ok_current = current and ((current.entity and current.entity.valid) or current.kind == "dirt")
      local candidates = task.candidates or {}
      local candidate = candidates[math.max(1, task.index or 1)]
      local ok_candidate = candidate and ((candidate.entity and candidate.entity.valid) or candidate.kind == "dirt")
      if (not ok_current) and (not ok_candidate) then
        return tech_priests_0273_kick_worker(pair, "nil-current-or-invalid-candidate")
      end
    end
    return TECH_PRIESTS_ORIGINAL_HANDLE_EMERGENCY_DESPERATION_CRAFT_0273(pair)
  end
end

-- One-second hard kick: if another wrapper/state path leaves emergency_craft in
-- place while the priest wanders in idle/old movement, force the direct gather
-- service anyway.  This is intentionally debug-heavy until the underlying older
-- idle scheduler is fully retired.
TechPriestsRuntimeEventRegistry.on_nth_tick(61, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    if pair and pair.emergency_craft then
      local task = pair.emergency_craft
      local cur = task.current
      local ok_current = cur and ((cur.entity and cur.entity.valid) or cur.kind == "direct-mine-0273" or cur.kind == "direct-dirt-0273" or cur.kind == "dirt")
      if not ok_current then
        tech_priests_0273_kick_worker(pair, "nth-tick-guard")
      elseif cur.kind == "direct-mine-0273" or cur.kind == "direct-dirt-0273" then
        tech_priests_0273_service_direct_current(pair, task)
      end
    end
  end
end)

if commands then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-direct-gather-debug", "Tech Priests: force direct emergency gather on selected pair.", function(event)
      local player = game.get_player(event.player_index)
      if not player then return end
      local pair = tech_priests_get_selected_pair_0247 and tech_priests_get_selected_pair_0247(player) or nil
      if not pair and tech_priests_0264_find_pair_for_player then
        local ok, got = pcall(function() return tech_priests_0264_find_pair_for_player(player) end)
        if ok then pair = got end
      end
      if not pair then player.print("[Tech Priests] Select a Cogitator Station or Tech-Priest."); return end
      if not pair.emergency_craft then player.print("[Tech Priests] Selected pair has no emergency craft task."); return end
      local output = tech_priests_0273_output_from_task(pair.emergency_craft)
      local forced = tech_priests_0273_kick_worker(pair, "manual-command")
      player.print("[Tech Priests 0.1.273] direct gather target=" .. tostring(output) .. " forced=" .. tostring(forced) .. " mode=" .. tostring(pair.mode))
    end)
  end)
end

tech_priests_0273_log("0.1.273 direct emergency gather/mining worker override loaded")


-- ============================================================================
-- 0.1.275: stalled direct gather completion guard.
-- ============================================================================
-- 0.1.273 successfully found direct resource targets, but the priests could sit
-- at a constant distance forever because the unit command/pathing layer did not
-- always close the distance.  For debugging and emergency bootstrap purposes,
-- a direct mining target that remains active for a few seconds now performs the
-- red scan/mining rite remotely instead of waiting forever.

TECH_PRIESTS_VERSION_0274 = "0.1.275"
TECH_PRIESTS_DIRECT_GATHER_STALL_TICKS_0274 = 600
TECH_PRIESTS_DIRECT_GATHER_REPATH_TICKS_0274 = 180
TECH_PRIESTS_DIRECT_GATHER_CRAFT_TICKS_0274 = 180

function tech_priests_0274_log(msg)
  if tech_priests_0264_log then
    pcall(function() tech_priests_0264_log(tostring(msg), true) end)
  elseif log then
    log("[Tech-Priests 0.1.275] " .. tostring(msg))
  end
end

function tech_priests_0274_dist_sq(a, b)
  if not (a and b) then return nil end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

function tech_priests_0274_direct_pos(cur, pair)
  if cur and cur.entity and cur.entity.valid then return cur.entity.position end
  if cur and cur.position then return cur.position end
  if pair and pair.station and pair.station.valid then return pair.station.position end
  return nil
end

function tech_priests_0274_set_move_command(pair, pos)
  if not (pair and pair.priest and pair.priest.valid and pos and defines and defines.command) then return false end
  if tech_priests_request_movement_0418 then
    return tech_priests_request_movement_0418(pair, pos, "legacy-direct-gather-0274", { radius = 0.75, owner = "direct-gather-0274", priority = 55, distraction = defines.distraction.by_enemy })
  end
  local ok = pcall(function()
    pair.priest.set_command({
      type = defines.command.go_to_location,
      destination = pos,
      radius = 0.75,
      distraction = defines.distraction.by_enemy
    })
  end)
  return ok
end

function tech_priests_0274_mark_gathered(pair, reason)
  -- 0.1.276 scheduler-cleanup pass: this function name is retained for command
  -- compatibility, but it no longer fabricates gathered materials.  A stalled
  -- direct-gather task is abandoned and sent back through the planner/scavenger
  -- chain instead of silently awarding inventory from a remote resource.
  if not (pair and pair.emergency_craft) then return false end
  local task = pair.emergency_craft
  task.current = nil
  task.candidates = nil
  task.index = nil
  task.direct_completed_by_0274 = nil
  task.direct_assigned_tick_0274 = nil
  task.direct_last_repath_tick_0274 = nil
  task.direct_last_dist_sq_0274 = nil
  task.scan_due_tick = game.tick + (EMERGENCY_CRAFT_SCAN_TICKS or 180)
  task.force_raw_fallback_0270 = true
  pair.mode = "emergency-gathering"
  pair.target = nil
  if draw_priest_status_bubble then pcall(function() draw_priest_status_bubble(pair) end) end
  tech_priests_0274_log("direct gather stalled; abandoned remote completion station=" .. tostring(pair.station and pair.station.unit_number) .. " output=" .. tostring(task.output_item or task.item_name or task.item) .. " reason=" .. tostring(reason))
  return true
end

function tech_priests_0274_service_direct_stall(pair, reason)
  local task = pair and pair.emergency_craft or nil
  local cur = task and task.current or nil
  if not (task and cur and (cur.kind == "direct-mine-0273" or cur.kind == "direct-dirt-0273")) then return false end
  if not (pair.priest and pair.priest.valid and pair.station and pair.station.valid) then return false end

  -- If the forced scan already completed and the one-second crafting rite has
  -- elapsed, finish through the normal emergency craft finisher so station
  -- inventory handoff stays on the established path.
  if task.direct_completed_by_0274 then
    if task.craft_due_tick and game.tick >= task.craft_due_tick then
      if finish_emergency_desperation_craft then
        local ok, done = pcall(function() return finish_emergency_desperation_craft(pair) end)
        if ok and done then
          tech_priests_0274_log("direct gather forced finish station=" .. tostring(pair.station and pair.station.unit_number))
          return true
        end
      end
      -- Last resort if the finisher refuses: insert the target item directly.
      local item = task.output_item or task.item_name or task.item or "stone"
      local inv = nil
      if get_station_inventory then pcall(function() inv = get_station_inventory(pair.station) end) end
      if not inv then pcall(function() inv = pair.station.get_inventory(defines.inventory.chest) end) end
      if inv and inv.can_insert({name=item, count=1}) then inv.insert({name=item, count=1}) end
      pair.emergency_craft = nil
      pair.mode = "returning"
      if return_to_station then pcall(function() return_to_station(pair.priest, pair.station) end) end
      tech_priests_0274_log("direct gather fallback inserted station=" .. tostring(pair.station and pair.station.unit_number) .. " item=" .. tostring(item))
      return true
    end
    pair.mode = "emergency-crafting"
    return true
  end

  local pos = tech_priests_0274_direct_pos(cur, pair)
  local dist_sq = tech_priests_0274_dist_sq(pair.priest.position, pos)
  local pickup_sq = EMERGENCY_CRAFT_PICKUP_DISTANCE_SQ or 2.25
  if dist_sq and dist_sq <= pickup_sq then
    return false -- let 0.1.273 / original code perform the normal close-range gather
  end

  if not task.direct_assigned_tick_0274 then
    task.direct_assigned_tick_0274 = game.tick
    task.direct_last_repath_tick_0274 = 0
    task.direct_last_dist_sq_0274 = dist_sq
    task.direct_stall_reason_0274 = reason
  end

  if pos and ((not task.direct_last_repath_tick_0274) or game.tick - task.direct_last_repath_tick_0274 >= TECH_PRIESTS_DIRECT_GATHER_REPATH_TICKS_0274) then
    task.direct_last_repath_tick_0274 = game.tick
    tech_priests_0274_set_move_command(pair, pos)
  end

  local elapsed = game.tick - (task.direct_assigned_tick_0274 or game.tick)
  local last = task.direct_last_dist_sq_0274
  local not_improving = dist_sq and last and dist_sq >= (last - 0.05)
  if dist_sq then task.direct_last_dist_sq_0274 = math.min(last or dist_sq, dist_sq) end

  if elapsed >= TECH_PRIESTS_DIRECT_GATHER_STALL_TICKS_0274 or (elapsed >= 420 and not_improving) then
    return tech_priests_0274_mark_gathered(pair, reason or "stalled-direct-target")
  end

  pair.mode = cur.kind == "direct-dirt-0273" and "emergency-dirt-scraping" or "emergency-gathering"
  return true
end

if handle_emergency_desperation_craft then
  TECH_PRIESTS_ORIGINAL_HANDLE_EMERGENCY_DESPERATION_CRAFT_0274 = handle_emergency_desperation_craft
  function handle_emergency_desperation_craft(pair)
    if tech_priests_0274_service_direct_stall(pair, "handle-wrapper") then return true end
    return TECH_PRIESTS_ORIGINAL_HANDLE_EMERGENCY_DESPERATION_CRAFT_0274(pair)
  end
end

-- 0.1.425: disabled legacy nth-tick stall guard removed from active control.lua during event switchboard cleanup.

if commands then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-replan-gather", "Tech Priests: abandon selected emergency direct-gather task and replan.", function(event)
      local player = game.get_player(event.player_index)
      if not player then return end
      local pair = tech_priests_get_selected_pair_0247 and tech_priests_get_selected_pair_0247(player) or nil
      if not pair and tech_priests_0264_find_pair_for_player then
        local ok, got = pcall(function() return tech_priests_0264_find_pair_for_player(player) end)
        if ok then pair = got end
      end
      if not pair then player.print("[Tech Priests] Select a Cogitator Station or Tech-Priest."); return end
      if not pair.emergency_craft then player.print("[Tech Priests] Selected pair has no emergency craft task."); return end
      local done = tech_priests_0274_mark_gathered(pair, "manual-command")
      player.print("[Tech Priests 0.1.276] replan-gather=" .. tostring(done) .. " mode=" .. tostring(pair.mode))
    end)
  end)
end

tech_priests_0274_log("0.1.276 stalled direct gather now replans instead of remote-completing loaded")


-- ============================================================================
-- 0.1.276: unified scheduler migration notes and pair-state helpers.
-- ============================================================================
-- This pass does not replace the full historical wrapper chain in one dangerous
-- sweep.  It creates the explicit task-state vocabulary used by the next safe
-- migration step, while the old pair.mode values continue to render status text
-- and preserve save compatibility.
TECH_PRIESTS_VERSION_0276 = "0.1.276"

TECH_PRIESTS_TASK_PRIORITY_0276 = {
  conversation_lock = 5,
  emergency_assignment = 10,
  space_platform_doctrine = 15,
  combat = 20,
  repair = 30,
  consecration = 40,
  logistics_request = 50,
  scavenge = 60,
  cram = 70,
  emergency_operation = 80,
  idle_scan = 90,
  idle_conversation = 100,
  return_idle = 110
}

function tech_priests_set_pair_task_0276(pair, task_kind, task_phase, visual_state, target, task_owner)
  if not pair then return false end
  pair.task_kind_0276 = task_kind or pair.task_kind_0276 or "idle"
  pair.task_phase_0276 = task_phase or pair.task_phase_0276 or "none"
  pair.visual_state_0276 = visual_state or pair.visual_state_0276 or pair.mode or "idle"
  pair.task_owner_0276 = task_owner or pair.task_owner_0276
  if target ~= nil then pair.target = target end
  -- Save compatibility: pair.mode remains the visible/legacy status field until
  -- the old wrapper stack is retired.  New work should set both through this
  -- helper, then later the renderer can read visual_state_0276 directly.
  pair.mode = pair.visual_state_0276
  return true
end

function tech_priests_clear_pair_task_0276(pair, visual_state)
  if not pair then return false end
  pair.task_kind_0276 = "idle"
  pair.task_phase_0276 = "none"
  pair.task_owner_0276 = nil
  pair.visual_state_0276 = visual_state or "idle"
  pair.mode = pair.visual_state_0276
  pair.target = nil
  return true
end

function tech_priests_pair_task_summary_0276(pair)
  if not pair then return "nil-pair" end
  return tostring(pair.task_kind_0276 or "legacy") .. ":" .. tostring(pair.task_phase_0276 or pair.mode or "unknown") .. " visual=" .. tostring(pair.visual_state_0276 or pair.mode or "?")
end

-- Scheduler migration target.  Future behavior modules should implement these
-- methods and be called from one priority loop instead of adding another
-- tick_pair wrapper: can_start(pair), can_continue(pair), start(pair), tick(pair),
-- cancel(pair, reason), and wait_summary(pair).
TECH_PRIESTS_SCHEDULER_MODULES_0276 = TECH_PRIESTS_SCHEDULER_MODULES_0276 or {}

-- ============================================================================
-- 0.1.277 Unified Priority Scheduler Pass 1
-- ============================================================================
-- This is intentionally a conservative scheduler facade.  It does not delete the
-- historic behavior wrapper stack yet; instead it takes explicit ownership of the
-- highest-confidence priorities and falls back to the legacy tick when no managed
-- priority claims the pair.  This gives us one readable priority table without
-- making emergency doctrine, platform doctrine, assignment delegation, or idle
-- conversations explode in the same pass.

TECH_PRIESTS_SCHEDULER_VERSION_0277 = "0.1.277-pass-1"
TECH_PRIESTS_SCHEDULER_TRACE_0277 = false

function tech_priests_0277_scheduler_log(message)
  if not TECH_PRIESTS_SCHEDULER_TRACE_0277 then return end
  if game and game.print then game.print("[TechPriests 0.1.277 scheduler] " .. tostring(message)) end
end

function tech_priests_0277_pair_label(pair)
  if not pair then return "pair=nil" end
  local station = pair.station
  local unit = pair.station_unit or (station and station.valid and station.unit_number) or "?"
  return "station#" .. tostring(unit) .. " mode=" .. tostring(pair.mode or "nil")
end

function tech_priests_0277_set_task(pair, kind, phase, owner, target, visual_state)
  if not pair then return end
  if tech_priests_set_pair_task_0276 then
    tech_priests_set_pair_task_0276(pair, kind, phase, owner, target, visual_state)
  else
    pair.task_kind = kind
    pair.task_phase = phase
    pair.task_owner = owner
    pair.task_target = target
    pair.visual_state = visual_state or phase or kind
    pair.mode = pair.visual_state or pair.mode
  end
end

function tech_priests_0277_clear_task(pair, reason)
  if not pair then return end
  if tech_priests_clear_pair_task_0276 then
    tech_priests_clear_pair_task_0276(pair, reason)
  else
    pair.task_kind = nil
    pair.task_phase = nil
    pair.task_owner = nil
    pair.task_target = nil
    pair.visual_state = nil
  end
  pair.last_scheduler_clear_reason_0277 = reason
end

function tech_priests_0277_validate_and_housekeep(pair)
  if not pair then return nil end
  local station = pair.station
  local priest = pair.priest

  if not (station and station.valid) then
    if cleanup_pair then cleanup_pair(pair) end
    return nil
  end

  if not (priest and priest.valid) then
    if ensure_pair_priest then ensure_pair_priest(pair, false) end
    priest = pair.priest
    if not (priest and priest.valid) then return nil end
  end

  local radius = pair.radius or 0
  if refresh_pair_radius then radius = refresh_pair_radius(pair) or radius end

  if sync_linked_health then sync_linked_health(pair) end
  priest = pair.priest
  if not (priest and priest.valid) then
    if ensure_pair_priest then ensure_pair_priest(pair, false) end
    return nil
  end

  if update_priest_footsteps then update_priest_footsteps(pair) end
  priest = pair.priest
  if not (priest and priest.valid) then
    if ensure_pair_priest then ensure_pair_priest(pair, false) end
    return nil
  end

  if cleanup_expired_proxy then cleanup_expired_proxy(pair) end

  if perform_station_logistic_requisition and game and game.tick >= (pair.next_logistic_requisition_tick or 0) then
    perform_station_logistic_requisition(pair)
    local station_unit = pair.station_unit or (station.unit_number or 0)
    local interval = LOGISTIC_REQUISITION_INTERVAL_TICKS or 180
    pair.next_logistic_requisition_tick = game.tick + interval + (station_unit % 60)
  end

  return {
    station = station,
    priest = priest,
    radius = radius
  }
end

function tech_priests_0277_valid_repair_target(entity)
  return entity and entity.valid and entity.health and entity.health > 0 and entity.max_health and entity.health < entity.max_health
end

function tech_priests_0277_priority_combat(pair, ctx)
  if not handle_combat then return false end
  if handle_combat(pair) then
    tech_priests_0277_set_task(pair, "combat", pair.mode or "defending", "scheduler-0277", pair.target, pair.mode or "defending")
    return true
  end
  return false
end

function tech_priests_0277_priority_repair(pair, ctx)
  local station = ctx.station
  local priest = ctx.priest
  local radius = ctx.radius
  if not (station_has_repair_pack and station_has_repair_pack(station)) then return false end
  if not repair_target then return false end

  if tech_priests_0277_valid_repair_target(pair.target) and (not can_fully_use_repair_pack or can_fully_use_repair_pack(pair.target)) then
    repair_target(pair, pair.target)
    tech_priests_0277_set_task(pair, "repair", pair.mode or "repairing", "scheduler-0277", pair.target, pair.mode or "repairing")
    return true
  end

  if find_damaged_target then
    local target = find_damaged_target(station, radius, priest)
    if target then
      pair.target = target
      repair_target(pair, target)
      tech_priests_0277_set_task(pair, "repair", pair.mode or "moving-to-repair", "scheduler-0277", target, pair.mode or "moving-to-repair")
      return true
    end
  end

  return false
end

function tech_priests_0277_priority_consecration(pair, ctx)
  local station = ctx.station
  local priest = ctx.priest
  local radius = ctx.radius
  if not (is_consecration_target and get_consecration_record and get_available_station_consecration_item and sanctify_target_with_priest) then return false end

  if pair.target and pair.target.valid and is_consecration_target(pair.target) then
    local record = get_consecration_record(pair.target)
    if record then
      local current = record.sanctification or 0
      local maximum = record.max_sanctification or (get_base_sanctification_max and get_base_sanctification_max(record.entity and record.entity.valid and record.entity.force or nil)) or 100
      if current < maximum and get_available_station_consecration_item(station, maximum - current) then
        if sanctify_target_with_priest(pair, pair.target) then
          tech_priests_0277_set_task(pair, "consecration", pair.mode or "consecrating", "scheduler-0277", pair.target, pair.mode or "consecrating")
          return true
        end
      end
    end
  end

  if find_consecration_target_for_station then
    local target = find_consecration_target_for_station(station, radius, priest)
    if target then
      pair.target = target
      if sanctify_target_with_priest(pair, target) then
        tech_priests_0277_set_task(pair, "consecration", pair.mode or "moving-to-consecrate", "scheduler-0277", target, pair.mode or "moving-to-consecrate")
        return true
      end
    end
  end

  return false
end

function tech_priests_0277_priority_cram(pair, ctx)
  if pair.cram and handle_priest_cram_task and handle_priest_cram_task(pair) then
    tech_priests_0277_set_task(pair, "logistics", pair.mode or "cramming-supplies", "scheduler-0277", nil, pair.mode or "cramming-supplies")
    return true
  end
  return false
end

function tech_priests_0277_priority_scavenge(pair, ctx)
  if pair.scavenge and handle_priest_scavenge_task and handle_priest_scavenge_task(pair) then
    tech_priests_0277_set_task(pair, "logistics", pair.mode or "scavenging-supplies", "scheduler-0277", nil, pair.mode or "scavenging-supplies")
    return true
  end
  return false
end

TECH_PRIESTS_PRIORITY_TABLE_0277 = {
  { key = "combat",        run = tech_priests_0277_priority_combat },
  { key = "repair",        run = tech_priests_0277_priority_repair },
  { key = "consecration",  run = tech_priests_0277_priority_consecration },
  { key = "cram",          run = tech_priests_0277_priority_cram },
  { key = "scavenge",      run = tech_priests_0277_priority_scavenge },
}

function tech_priests_0277_scheduler_tick(pair)
  local ctx = tech_priests_0277_validate_and_housekeep(pair)
  if not ctx then return true end

  for _, priority in ipairs(TECH_PRIESTS_PRIORITY_TABLE_0277) do
    if priority.run and priority.run(pair, ctx) then
      pair.last_scheduler_priority_0277 = priority.key
      pair.last_scheduler_tick_0277 = game and game.tick or 0
      return true
    end
  end

  tech_priests_0277_clear_task(pair, "no-managed-priority-claimed")
  return false
end

if tick_pair and not TECH_PRIESTS_LEGACY_TICK_PAIR_0277 then
  TECH_PRIESTS_LEGACY_TICK_PAIR_0277 = tick_pair
  function tick_pair(pair)
    if tech_priests_0277_scheduler_tick(pair) then return end
    return TECH_PRIESTS_LEGACY_TICK_PAIR_0277(pair)
  end
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-scheduler-0277", "Tech Priests: report the selected pair scheduler/task state.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      local selected = player.selected
      local pair = selected and selected.valid and find_pair_by_entity and find_pair_by_entity(selected) or nil
      if not pair then
        player.print("No Tech Priest pair found for selected entity.")
        return
      end
      local summary = tech_priests_pair_task_summary_0276 and tech_priests_pair_task_summary_0276(pair) or ("task_kind=" .. tostring(pair.task_kind) .. " phase=" .. tostring(pair.task_phase) .. " mode=" .. tostring(pair.mode))
      player.print("Scheduler " .. tostring(TECH_PRIESTS_SCHEDULER_VERSION_0277) .. "\n" ..
        "Pair: " .. tech_priests_0277_pair_label(pair) .. "\n" ..
        "Last priority: " .. tostring(pair.last_scheduler_priority_0277 or "legacy/fallback") .. "\n" ..
        "Task: " .. tostring(summary))
    end)
  end)
end

-- ============================================================================
-- 0.1.278 Radar hover sweep / task detection radius behavior
-- ============================================================================
-- Visual diagnostic radar for Cogitator Stations.  When a player hovers a
-- station or its linked Tech-Priest, the station draws a one-minute circular
-- sweep arm.  Objects touched by the arm refresh the station's knowledge cache,
-- flash an icon above the object, and allow the linked priest's current task to
-- be sanity-checked against the refreshed picture.

TECH_PRIESTS_RADAR_VERSION_0278 = "0.1.280-scaled-radar-overlay-and-task-audit"
TECH_PRIESTS_RADAR_SWEEP_TICKS_0278 = 60 * 60 -- fallback only; actual sweep time is rank/technology aware below.
TECH_PRIESTS_RADAR_SWEEP_ACCELERATION_TECH_0279 = "cogitator-radar-sweep-acceleration"
TECH_PRIESTS_RADAR_BASE_SWEEP_SECONDS_0279 = 60
TECH_PRIESTS_RADAR_RANK_SWEEP_SECONDS_0279 = 10
TECH_PRIESTS_RADAR_TECH_SWEEP_SECONDS_0279 = 15
TECH_PRIESTS_RADAR_MIN_SWEEP_SECONDS_0279 = 5
TECH_PRIESTS_RADAR_TICK_INTERVAL_0278 = 6
TECH_PRIESTS_RADAR_LINE_TTL_0278 = 12
TECH_PRIESTS_RADAR_FLASH_TTL_0278 = 45
TECH_PRIESTS_RADAR_CANDIDATE_REFRESH_TICKS_0278 = 60
TECH_PRIESTS_RADAR_MAX_CANDIDATES_0278 = 900
TECH_PRIESTS_RADAR_MAX_FLASHES_PER_STEP_0278 = 10
TECH_PRIESTS_RADAR_SWEEP_HALF_WIDTH_RADIANS_0278 = math.rad(2.4)
TECH_PRIESTS_RADAR_TRACE_0278 = false

function tech_priests_radar_log_0278(message)
  if not TECH_PRIESTS_RADAR_TRACE_0278 then return end
  if game and game.print then game.print("[TechPriests radar 0.1.278] " .. tostring(message)) end
end

function tech_priests_radar_ensure_storage_0278()
  if ensure_storage then ensure_storage() end
  storage.tech_priests.radar_0278 = storage.tech_priests.radar_0278 or {}
  storage.tech_priests.radar_0278.players = storage.tech_priests.radar_0278.players or {}
  storage.tech_priests.radar_0278.station_cache = storage.tech_priests.radar_0278.station_cache or {}
  return storage.tech_priests.radar_0278
end

function tech_priests_radar_destroy_object_0278(object)
  if not object then return end
  pcall(function()
    if object.valid then object.destroy() end
  end)
end

function tech_priests_radar_destroy_objects_0278(objects)
  if not objects then return end
  if objects.object then tech_priests_radar_destroy_object_0278(objects.object) end
  if objects.line then tech_priests_radar_destroy_object_0278(objects.line) end
  if objects.endcap then tech_priests_radar_destroy_object_0278(objects.endcap) end
  if objects.flash then tech_priests_radar_destroy_object_0278(objects.flash) end
  if objects.text then tech_priests_radar_destroy_object_0278(objects.text) end
  for _, object in pairs(objects) do
    if type(object) ~= "table" or object.valid ~= nil then
      tech_priests_radar_destroy_object_0278(object)
    end
  end
end

function tech_priests_radar_station_rank_0279(pair)
  if not (pair and pair.station and pair.station.valid) then return 1 end
  local station_name = pair.station.name
  local tier = nil
  if TIER_CONFIGS and TIER_CONFIGS[station_name] then tier = TIER_CONFIGS[station_name].tier end
  tier = tier or pair.tier or station_name
  local ranks = TECH_PRIESTS_TIER_RANKS_0129 or { junior = 1, intermediate = 2, senior = 3, ["planetary-magos"] = 4, planetary_magos = 4, magos = 4, void = 5 }
  if ranks[tier] then return ranks[tier] end
  if tier == "intermediate-cogitator-station" then return 2 end
  if tier == "senior-cogitator-station" then return 3 end
  if tier == "planetary-magos-cogitator-station" then return 4 end
  if tier == "void-cogitator-station" then return 5 end
  return 1
end

function tech_priests_radar_force_has_acceleration_0279(force)
  if not (force and force.valid and force.technologies) then return false end
  local tech = force.technologies[TECH_PRIESTS_RADAR_SWEEP_ACCELERATION_TECH_0279]
  return tech and tech.researched or false
end

function tech_priests_radar_sweep_ticks_for_pair_0279(pair)
  local rank = tech_priests_radar_station_rank_0279(pair)
  local seconds = TECH_PRIESTS_RADAR_BASE_SWEEP_SECONDS_0279 - ((math.max(rank, 1) - 1) * TECH_PRIESTS_RADAR_RANK_SWEEP_SECONDS_0279)
  if pair and pair.station and pair.station.valid and tech_priests_radar_force_has_acceleration_0279(pair.station.force) then
    seconds = seconds - TECH_PRIESTS_RADAR_TECH_SWEEP_SECONDS_0279
  end
  seconds = math.max(TECH_PRIESTS_RADAR_MIN_SWEEP_SECONDS_0279, seconds)
  return seconds * 60, seconds, rank
end

function tech_priests_radar_get_hover_pair_0278(player)
  if not (player and player.valid and player.selected and player.selected.valid) then return nil end
  local selected = player.selected
  local pair = nil
  if is_station and is_station(selected) then
    pair = find_pair_for_entity and find_pair_for_entity(selected) or nil
    if not pair and create_pair then
      create_pair(selected)
      pair = find_pair_for_entity and find_pair_for_entity(selected) or nil
    end
  elseif is_priest and is_priest(selected) then
    pair = find_pair_for_entity and find_pair_for_entity(selected) or nil
  end
  if pair and pair.station and pair.station.valid then return pair end
  return nil
end
