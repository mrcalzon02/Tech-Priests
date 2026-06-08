-- scripts/core/movement_controller.lua
-- Tech Priests 0.1.429 unified ground movement controller / combat-movement leftover audit pass.
--
-- Design doctrine:
--   * One module owns ground-priest go-to-location commands.
--   * Other systems submit movement intent; they do not command the entity.
--   * Conversations, mining/work, crafting, and short post-snap stabilisation are
--     clamp bands. During those bands the priest stops/loiters instead of being
--     repeatedly repathed by older behavior code.
--   * Space-platform hover/pathing code is not rewritten here; this controller is
--     for normal ground Tech-Priest character movement.

local M = {}

local TaskTransitionGovernor = nil
pcall(function() TaskTransitionGovernor = require("scripts.core.task_transition_governor") end)

M.version = "0.1.616"
M.storage_key = "movement_controller_0419"
M.service_ticks = 10
M.command_refresh_ticks = 30
M.retarget_hold_ticks = 12
M.minimum_retarget_distance_sq = 0.25
M.default_radius = 0.85
M.loiter_radius_pad = 0.35
M.snap_distance_sq = 0.04
M.snap_sample_ticks = 5
M.stabilize_ticks = 12
M.max_tiles_per_second = 48.0
M.combat_fire_range = 15
M.combat_approach_radius = 13
M.default_request_ttl = 60 * 10
M.max_ground_step_distance_sq = 0.04 -- 0.1.443: visual governor now uses max_tiles_per_second dynamically; this legacy value remains as a floor/audit marker

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function metric(k,n) local fn=rawget(_G,"tech_priests_runtime_metric_0606"); if type(fn)=="function" then pcall(fn,k,n or 1) end end
local function dist_sq(a, b)
  if not (a and b) then return nil end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version,
    stats = {},
    samples = {},
    requests = {},
    active_request_ids = {}
  }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  root.stats = root.stats or {}
  root.samples = root.samples or {}
  root.requests = root.requests or {}
  root.active_request_ids = root.active_request_ids or {}
  if not root._active_request_ids_migrated_0611 then
    for key, req in pairs(root.requests or {}) do
      if req then root.active_request_ids[key] = true end
    end
    root._active_request_ids_migrated_0611 = true
  end
  return root
end

local function pairs_by_station()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function pair_by_request_key(key)
  local map = pairs_by_station()
  if map[key] then return map[key] end
  local n = tonumber(key)
  if n and map[n] then return map[n] end
  if type(key) == "string" and key:sub(1,1) == "p" and storage and storage.tech_priests and storage.tech_priests.pairs_by_priest then
    local pn = tonumber(key:sub(2))
    if pn and storage.tech_priests.pairs_by_priest[pn] then return storage.tech_priests.pairs_by_priest[pn] end
  end
  return nil
end

local function note_active_request(root, key, pair)
  if not (root and key) then return end
  root.active_request_ids = root.active_request_ids or {}
  root.active_request_ids[key] = true
  local Buckets = rawget(_G, "TechPriestsPairBucketRegistry0600")
  if not Buckets then pcall(function() Buckets = require("scripts.core.pair_bucket_registry") end) end
  if Buckets and Buckets.force_bucket and pair then
    pcall(function() Buckets.force_bucket(pair, "movement", M.default_request_ttl, "movement-request-0611") end)
  end
end

local function clear_active_request(root, key)
  if root and root.active_request_ids and key then root.active_request_ids[key] = nil end
end

local function count_table(t) local n=0; if type(t)=="table" then for _ in pairs(t) do n=n+1 end end; return n end

local function pair_key(pair)
  if pair and pair.station and pair.station.valid and pair.station.unit_number then return tostring(pair.station.unit_number) end
  if pair and pair.priest and pair.priest.valid and pair.priest.unit_number then return "p" .. tostring(pair.priest.unit_number) end
  return nil
end

local function selected_pair(player)
  if _G.tech_priests_get_selected_pair_0247 then local ok, pair = pcall(_G.tech_priests_get_selected_pair_0247, player); if ok and pair then return pair end end
  if _G.selected_pair_for_player then local ok, pair = pcall(_G.selected_pair_for_player, player); if ok and pair then return pair end end
  local selected = player and player.selected
  if not (selected and selected.valid and storage and storage.tech_priests) then return nil end
  if storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[selected.unit_number] then return storage.tech_priests.pairs_by_station[selected.unit_number] end
  if storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[selected.unit_number] then return storage.tech_priests.pairs_by_priest[selected.unit_number] end
  if _G.find_pair_for_entity then local ok, pair = pcall(_G.find_pair_for_entity, selected); if ok and pair then return pair end end
  return nil
end

local function pair_for_priest(priest)
  if not (priest and priest.valid) then return nil end
  if storage and storage.tech_priests then
    if storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[priest.unit_number] then
      return storage.tech_priests.pairs_by_priest[priest.unit_number]
    end
    if storage.tech_priests.station_by_priest and storage.tech_priests.pairs_by_station and priest.unit_number then
      local station_unit = storage.tech_priests.station_by_priest[priest.unit_number]
      if station_unit and storage.tech_priests.pairs_by_station[station_unit] then return storage.tech_priests.pairs_by_station[station_unit] end
    end
  end
  if _G.find_pair_for_entity then local ok, pair = pcall(_G.find_pair_for_entity, priest); if ok and pair then return pair end end
  return nil
end

local function is_space_pair(pair)
  if _G.tech_priests_pair_on_space_platform_0204 then
    local ok, result = pcall(_G.tech_priests_pair_on_space_platform_0204, pair)
    if ok and result then return true end
  end
  return false
end

local function direct_stop(priest)
  if not (priest and priest.valid and defines and defines.command) then return false end
  local ok_any = false
  local command = { type = defines.command.stop }
  pcall(function()
    local commandable = priest.commandable
    if commandable and commandable.valid then commandable.set_command(command); ok_any = true end
  end)
  pcall(function()
    if priest.set_command then priest.set_command(command); ok_any = true end
  end)
  pcall(function() priest.walking_state = { walking = false }; ok_any = true end)
  return ok_any
end

local function direct_go_to(priest, pos, radius, distraction)
  if not (priest and priest.valid and pos and defines and defines.command) then return false end
  local command = {
    type = defines.command.go_to_location,
    destination = { x = pos.x, y = pos.y },
    radius = radius or M.default_radius,
    distraction = distraction or defines.distraction.by_enemy
  }
  local ok_any = false
  pcall(function()
    local commandable = priest.commandable
    if commandable and commandable.valid then commandable.set_command(command); ok_any = true end
  end)
  if not ok_any then
    pcall(function() if priest.set_command then priest.set_command(command); ok_any = true end end)
  end
  return ok_any
end

local function current_work_position(pair)
  local task = pair and pair.emergency_craft or nil
  local cur = task and task.current or nil
  if cur then
    if cur.entity and cur.entity.valid then return cur.entity.position, cur.kind end
    if cur.position then return cur.position, cur.kind end
  end
  return nil, nil
end

local function conversation_locked(pair)
  if not pair then return false end
  if pair.idle_conversation then return true end
  if pair.idle_conversation_listener_until and now() < pair.idle_conversation_listener_until then return true end
  if pair.idle_conversation_speaker_station_unit then return true end
  if pair.idle_conversation_lock_position_0179 then return true end
  return false
end

local function work_clamped(pair)
  if not pair then return false, nil end
  if pair.mining_lock_0315 then return true, "mining-lock" end
  if pair.station_craft_lock_0337 then return true, "station-craft-lock" end
  if pair.crafting_lock_0418 then return true, "crafting-lock" end
  local pos, kind = current_work_position(pair)
  if pos and pair.priest and pair.priest.valid then
    local d2 = dist_sq(pair.priest.position, pos) or 999999
    local close = _G.EMERGENCY_CRAFT_PICKUP_DISTANCE_SQ or 2.25
    if d2 <= close and (kind == "direct-mine-0273" or kind == "direct-dirt-0273" or kind == "direct-mine-0336" or kind == "dirt") then
      return false, "close-to-work-target-observed"
    end
  end
  return false, nil
end

local function clamp_reason(pair)
  if not pair then return "invalid" end
  if is_space_pair(pair) then return nil end
  if pair.movement_stabilize_until_0418 and now() < pair.movement_stabilize_until_0418 then return "movement-stabilizing" end
  -- 0.1.419: ignore stale legacy movement-hammer lockdowns.  The hammer is no
  -- longer installed, and save-state leftovers must not immobilize priests.
  pair.movement_lockdown_until_0416 = nil
  pair.movement_lockdown_reason_0416 = nil
  -- 0.1.448: task-transition cogitation must not immobilize a priest already walking.
  -- New ordinary retargets are held in M.request; the current route may continue.
  -- if TaskTransitionGovernor and TaskTransitionGovernor.is_locked and TaskTransitionGovernor.is_locked(pair) then return "task-transition-cogitation" end
  if conversation_locked(pair) then return "conversation" end
  local clamped, reason = work_clamped(pair)
  if clamped then return reason or "work" end
  return nil
end

function M.request(pair, destination, reason, opts)
  opts = opts or {}
  if not (pair and pair.priest and pair.priest.valid and destination) then return false end
  if is_space_pair(pair) and not opts.force_ground_controller then
    return direct_go_to(pair.priest, destination, opts.radius, opts.distraction)
  end
  local root = ensure_root()
  local key = pair_key(pair)
  if not key then return false end

  local current = root.requests[key]
  local pos = { x = destination.x, y = destination.y }
  local priority = tonumber(opts.priority) or 50
  if TaskTransitionGovernor and TaskTransitionGovernor.is_locked and TaskTransitionGovernor.is_locked(pair) and priority < 800 and current and current.expires_tick and current.expires_tick >= now() then
    root.stats.task_transition_request_holds = (root.stats.task_transition_request_holds or 0) + 1; metric("path_task_transition_held",1)
    pair.movement_controller_state_0418 = "task-transition-retarget-held"
    pair.movement_controller_clamp_0418 = "task-transition-retarget-held"
    pair.movement_request_0418 = current
    return true
  end
  if current and current.expires_tick and current.expires_tick >= now() then
    local cd2 = dist_sq(current, pos) or 999999
    local age = now() - (tonumber(current.updated_tick or current.issued_tick) or now())
    local current_priority = tonumber(current.priority) or 0
    if cd2 < M.minimum_retarget_distance_sq and current_priority >= priority then
      current.reason = tostring(reason or current.reason or "movement")
      current.updated_tick = now()
      root.stats.request_collapsed = (root.stats.request_collapsed or 0) + 1; metric("path_requests_collapsed",1)
      note_active_request(root, key, pair)
      pair.movement_request_0418 = current
      return true
    end
    -- 0.1.443: hold low/equal priority retarget churn. The live test showed
    -- priests visually sprinting between rapidly-changing direct-gather / support
    -- assignments. This does not teleport them back; it simply refuses to replace
    -- a still-fresh path with another similar-priority path until the current
    -- intent has had time to resolve.
    if age < M.retarget_hold_ticks and priority <= current_priority + 10 then
      current.suppressed_retarget_count = (current.suppressed_retarget_count or 0) + 1
      current.last_suppressed_target = { x = pos.x, y = pos.y, reason = tostring(reason or "movement"), tick = now(), priority = priority }
      root.stats.retargets_held = (root.stats.retargets_held or 0) + 1; metric("path_retargets_held",1)
      note_active_request(root, key, pair)
      pair.movement_request_0418 = current
      pair.movement_controller_state_0418 = "retarget-held"
      pair.movement_controller_clamp_0418 = "retarget-held"
      return true
    end
  end

  local req = {
    x = pos.x,
    y = pos.y,
    radius = tonumber(opts.radius) or M.default_radius,
    reason = tostring(reason or opts.owner or "movement"),
    owner = tostring(opts.owner or reason or "movement"),
    priority = priority,
    distraction = opts.distraction,
    issued_tick = now(),
    updated_tick = now(),
    expires_tick = now() + (tonumber(opts.ttl) or M.default_request_ttl),
    last_command_tick = 0,
    last_distance_sq = nil
  }
  root.requests[key] = req
  note_active_request(root, key, pair)
  pair.movement_request_0418 = req
  pair.movement_controller_owner_0418 = req.owner
  pair.movement_controller_reason_0418 = req.reason
  root.stats.requests = (root.stats.requests or 0) + 1; metric("path_requests",1)
  return true
end

function M.combat_intent(pair, target, reason, opts)
  opts = opts or {}
  if not (pair and pair.priest and pair.priest.valid and target and target.valid) then return false end
  if is_space_pair(pair) then return false end
  local range = tonumber(opts.fire_range) or tonumber(_G.COMBAT_FIRE_RANGE) or M.combat_fire_range
  local approach = tonumber(opts.radius) or tonumber(_G.COMBAT_APPROACH_RADIUS) or math.max(1, range - 2)
  local d2 = dist_sq(pair.priest.position, target.position) or 999999
  pair.combat_target = target
  pair.target = target
  pair.movement_controller_combat_intent_0419 = {
    tick = now(),
    target_unit = target.unit_number,
    target_name = target.name,
    dist_sq = d2,
    reason = tostring(reason or "combat-intent")
  }
  if d2 > range * range then
    pair.mode = "moving-to-combat"
    return M.request(pair, target.position, reason or "combat-intent", {
      radius = approach,
      owner = "combat-intent",
      priority = tonumber(opts.priority) or 85,
      ttl = tonumber(opts.ttl) or 60 * 4,
      distraction = defines and defines.distraction and defines.distraction.by_enemy or nil
    })
  end
  -- The hidden/proxy turret owns damage.  Ground-priest attack commands cause
  -- Factorio unit AI to become a second pathing owner, so close-range combat
  -- intentionally stops/loiters instead of issuing defines.command.attack.
  pair.mode = "defending"
  return M.stop(pair, "combat-in-range-proxy-owns-damage")
end

function M.stop(pair, reason)
  if not (pair and pair.priest and pair.priest.valid) then return false end
  local root = ensure_root()
  local key = pair_key(pair)
  if key then root.requests[key] = nil; clear_active_request(root, key) end
  pair.movement_request_0418 = nil
  pair.movement_controller_reason_0418 = tostring(reason or "stop")
  root.stats.stops = (root.stats.stops or 0) + 1
  return direct_stop(pair.priest)
end

local function apply_request(pair, req)
  if not (pair and pair.priest and pair.priest.valid and req) then return false end
  local priest = pair.priest
  local reason = clamp_reason(pair)
  if reason then
    pair.movement_controller_clamp_0418 = reason
    direct_stop(priest)
    return false
  end
  pair.movement_controller_clamp_0418 = nil

  local d2 = dist_sq(priest.position, req) or 999999
  req.last_distance_sq = d2
  local radius = math.max(0.15, tonumber(req.radius) or M.default_radius)
  if d2 <= (radius + M.loiter_radius_pad) * (radius + M.loiter_radius_pad) then
    pair.movement_controller_state_0418 = "loitering"
    direct_stop(priest)
    return true
  end

  if now() - (req.last_command_tick or 0) >= M.command_refresh_ticks then
    local ok = direct_go_to(priest, req, radius, req.distraction)
    if ok then
      req.last_command_tick = now()
      pair.movement_controller_state_0418 = "moving"
      pair.movement_controller_last_command_0418 = { tick = now(), x = req.x, y = req.y, reason = req.reason }
      local root = ensure_root()
      root.stats.commands = (root.stats.commands or 0) + 1; metric("path_engine_commands",1)
      return true
    end
  end
  return false
end

function M.service(event, budget)
  local root = ensure_root()
  local processed, acted = 0, 0
  local max_count = tonumber(budget) or 24
  root.active_request_ids = root.active_request_ids or {}
  for key in pairs(root.active_request_ids) do
    if processed >= max_count then
      root.stats.service_budget_exhausted = (root.stats.service_budget_exhausted or 0) + 1
      metric("movement_service_budget_exhausted", 1)
      return false, "budget-exhausted"
    end
    local pair = pair_by_request_key(key)
    local req = root.requests[key] or (pair and pair.movement_request_0418)
    if not (pair and valid(pair.priest) and valid(pair.station) and not is_space_pair(pair)) then
      root.requests[key] = nil
      clear_active_request(root, key)
      root.stats.invalid_request_pruned = (root.stats.invalid_request_pruned or 0) + 1
    elseif req and req.expires_tick and req.expires_tick < now() then
      root.requests[key] = nil
      clear_active_request(root, key)
      pair.movement_request_0418 = nil
      root.stats.expired_request_pruned = (root.stats.expired_request_pruned or 0) + 1
    elseif req then
      processed = processed + 1
      if apply_request(pair, req) then acted = acted + 1 end
    else
      clear_active_request(root, key)
      root.stats.empty_request_pruned = (root.stats.empty_request_pruned or 0) + 1
    end
  end
  root.stats.service_active_processed = (root.stats.service_active_processed or 0) + processed
  metric("movement_active_requests_processed", processed)
  if processed == 0 then return false, "empty" end
  return acted, "active-requests"
end

function M.sample(event, budget)
  local root = ensure_root()
  local processed = 0
  local max_count = tonumber(budget) or 32
  root.active_request_ids = root.active_request_ids or {}
  for key in pairs(root.active_request_ids) do
    if processed >= max_count then
      root.stats.sample_budget_exhausted = (root.stats.sample_budget_exhausted or 0) + 1
      metric("movement_sample_budget_exhausted", 1)
      return false, "budget-exhausted"
    end
    local pair = pair_by_request_key(key)
    if pair and valid(pair.priest) and valid(pair.station) and not is_space_pair(pair) then
      processed = processed + 1
      local key = pair_key(pair)
      local pos = pair.priest.position
      local prev = key and root.samples[key]
      if prev and prev.surface == pair.priest.surface.index and prev.priest_unit == pair.priest.unit_number then
        local d2 = dist_sq(prev, pos) or 0
        local dt = math.max(1, now() - (prev.tick or now()))
        local allowed_step = math.max(0.16, (tonumber(M.max_tiles_per_second) or 2.2) * dt / 60)
        local allowed_sq = math.max(tonumber(M.snap_distance_sq) or 0.04, allowed_step * allowed_step)
        if dt <= 90 and d2 > math.max(36, allowed_sq) then
          root.stats.snaps = (root.stats.snaps or 0) + 1
          root.stats.high_speed_suppressed = (root.stats.high_speed_suppressed or 0) + 1
          root.stats.speed_violations = (root.stats.speed_violations or 0) + 1
          local rec = {
            tick = now(), station = pair.station.unit_number, priest = pair.priest.unit_number,
            from = { x = prev.x, y = prev.y }, to = { x = pos.x, y = pos.y },
            dist = math.sqrt(d2), dt = dt, allowed = math.sqrt(allowed_sq), mode = tostring(pair.mode),
            reason = pair.movement_controller_reason_0418 or (pair.movement_request_0418 and pair.movement_request_0418.reason)
          }
          root.last_snap = rec
          pair.last_ground_snap_0418 = rec
          pair.movement_stabilize_until_0418 = now() + M.stabilize_ticks
          -- Do not teleport the visible ground priest backwards. Stop, clear the
          -- current movement request, and let the scheduler submit a fresh sane
          -- route on the next behavior pass.
          -- 0.1.452: do not freeze normal pathing while investigating movement churn.
          -- Only truly huge visual jumps reach this branch now; record them and clear
          -- the stale request, then let the scheduler repath without immobilizing.
          root.requests[key] = nil
          clear_active_request(root, key)
          pair.movement_request_0418 = nil
          pair.movement_controller_state_0418 = "speed-governed"
          pair.movement_controller_clamp_0418 = "ground-speed-governor"
          if log then log("[Tech-Priests 0.1.442] ground speed governor stop station=" .. tostring(rec.station) .. " priest=" .. tostring(rec.priest) .. " dist=" .. tostring(rec.dist) .. " dt=" .. tostring(dt) .. " mode=" .. tostring(rec.mode) .. " reason=" .. tostring(rec.reason)) end
        end
      end
      if key then root.samples[key] = { x = pos.x, y = pos.y, tick = now(), surface = pair.priest.surface.index, priest_unit = pair.priest.unit_number } end
    else
      clear_active_request(root, key)
    end
  end
  root.stats.sample_active_processed = (root.stats.sample_active_processed or 0) + processed
  metric("movement_active_samples_processed", processed)
  if processed == 0 then return false, "empty" end
  return processed, "active-samples"
end

local function destination_from_entity_or_position(target)
  if not target then return nil end
  if target.valid and target.position then return target.position end
  if target.position then return target.position end
  if target.x and target.y then return target end
  return nil
end


function M.route_command(priest, command, owner, opts)
  opts = opts or {}
  local root = ensure_root()
  root.stats.route_command_attempts = (root.stats.route_command_attempts or 0) + 1
  metric("movement_route_command_attempts", 1)
  if not (priest and priest.valid and command and defines and defines.command) then
    root.stats.route_command_invalid = (root.stats.route_command_invalid or 0) + 1
    return false
  end
  local pair = opts.pair or pair_for_priest(priest)
  if pair and not is_space_pair(pair) then
    root.stats.route_command_ground = (root.stats.route_command_ground or 0) + 1
    if command.type == defines.command.go_to_location and command.destination then
      root.stats.route_command_go_to = (root.stats.route_command_go_to or 0) + 1
      return M.request(pair, command.destination, owner or command.reason or "legacy-routed-command", {
        radius = command.radius,
        distraction = command.distraction,
        owner = owner or opts.owner or "legacy-command-route-0429",
        priority = opts.priority or 50,
        ttl = opts.ttl or M.default_request_ttl
      })
    end
    if command.type == defines.command.attack and command.target then
      root.stats.route_command_attack = (root.stats.route_command_attack or 0) + 1
      return M.combat_intent(pair, command.target, owner or "legacy-routed-attack-0429", {
        distraction = command.distraction,
        owner = owner or opts.owner or "legacy-attack-route-0429",
        priority = opts.priority or 85,
        ttl = opts.ttl or 60 * 4,
        fire_range = opts.fire_range,
        radius = opts.radius
      })
    end
    if command.type == defines.command.stop then
      root.stats.route_command_stop = (root.stats.route_command_stop or 0) + 1
      return M.stop(pair, owner or "legacy-routed-stop-0429")
    end
  end

  root.stats.route_command_direct_fallback = (root.stats.route_command_direct_fallback or 0) + 1
  metric("movement_route_command_direct_fallback", 1)

  -- Space-platform handling and non-ground exceptions intentionally fall through
  -- to the engine command path.  The controller governs ground priests; hover,
  -- platform-tether, and proxy exceptions are documented by the 0.1.429 audit.
  local ok_any = false
  pcall(function()
    local commandable = priest.commandable
    if commandable and commandable.valid then commandable.set_command(command); ok_any = true end
  end)
  if not ok_any then pcall(function() if priest.set_command then priest.set_command(command); ok_any = true end end) end
  return ok_any
end

function M.patch_globals()
  _G.TECH_PRIESTS_MOVEMENT_CONTROLLER_0418 = M
  _G.tech_priests_request_movement_0418 = function(pair, destination, reason, opts)
    return M.request(pair, destination, reason, opts)
  end
  _G.tech_priests_stop_movement_0418 = function(pair, reason)
    return M.stop(pair, reason)
  end
  _G.tech_priests_route_ground_command_0429 = function(priest, command, owner, opts)
    return M.route_command(priest, command, owner, opts)
  end
  _G.TECH_PRIESTS_COMBAT_MOVEMENT_LEFTOVER_PASS_0429 = true

  if _G.issue_priest_command and not _G.TECH_PRIESTS_0418_PREVIOUS_ISSUE_PRIEST_COMMAND then
    _G.TECH_PRIESTS_0418_PREVIOUS_ISSUE_PRIEST_COMMAND = _G.issue_priest_command
    _G.issue_priest_command = function(priest, command)
      local pair = pair_for_priest(priest)
      if command and defines and (command.type == defines.command.go_to_location or command.type == defines.command.attack or command.type == defines.command.stop) then
        if pair and not is_space_pair(pair) then
          return M.route_command(priest, command, "legacy-issue-priest-command", {
            pair = pair,
            radius = command.radius,
            distraction = command.distraction,
            owner = "legacy-command",
            ttl = 60 * 10,
            priority = command.type == defines.command.attack and 85 or 45
          })
        end
      end
      return _G.TECH_PRIESTS_0418_PREVIOUS_ISSUE_PRIEST_COMMAND(priest, command)
    end
  end

  if _G.move_priest_to and not _G.TECH_PRIESTS_0418_PREVIOUS_MOVE_PRIEST_TO then
    _G.TECH_PRIESTS_0418_PREVIOUS_MOVE_PRIEST_TO = _G.move_priest_to
    _G.move_priest_to = function(priest, target)
      local pair = pair_for_priest(priest)
      local destination = nil
      if _G.find_priest_service_position then
        local ok, result = pcall(_G.find_priest_service_position, priest, target)
        if ok then destination = result end
      end
      destination = destination or destination_from_entity_or_position(target)
      if pair and destination and not is_space_pair(pair) then
        return M.request(pair, destination, "move-priest-to", { radius = 0.75, owner = "move_priest_to", priority = 50 })
      end
      return _G.TECH_PRIESTS_0418_PREVIOUS_MOVE_PRIEST_TO(priest, target)
    end
  end

  if _G.return_to_station and not _G.TECH_PRIESTS_0418_PREVIOUS_RETURN_TO_STATION then
    _G.TECH_PRIESTS_0418_PREVIOUS_RETURN_TO_STATION = _G.return_to_station
    _G.return_to_station = function(subject, maybe_station)
      local pair, priest, station = nil, nil, nil
      if type(subject) == "table" and subject.priest and subject.station then
        pair = subject; priest = subject.priest; station = subject.station
      else
        priest = subject
        pair = pair_for_priest(priest)
        station = maybe_station or (pair and pair.station) or nil
      end
      if pair and valid(priest) and valid(station) and not is_space_pair(pair) then
        return M.request(pair, station.position, "return-to-station", { radius = 2.0, owner = "return_to_station", priority = 40 })
      end
      return _G.TECH_PRIESTS_0418_PREVIOUS_RETURN_TO_STATION(subject, maybe_station)
    end
  end

  -- 0.1.419: combat functions may still issue attack commands.  Rather than
  -- letting character AI path independently, make the proxy turret the weapon
  -- and the movement controller the only positioning owner.  These wrappers are
  -- intentionally late, after legacy combat functions have been declared.
  local function combat_opts_after_proxy(pair, priority)
    local opts = { priority = priority or 88 }
    local last = pair and pair.last_combat_fallback_0312 or nil
    if last and last.tick == now() and pair and type(pair.mode) == "string" and string.find(pair.mode, "laser%-fallback", 1, false) then
      local point_blank = tonumber(_G.TECH_PRIESTS_POINT_BLANK_LASER_RANGE) or tonumber(last.point_blank) or 1.5
      opts.fire_range = point_blank
      opts.radius = math.max(0.55, point_blank * 0.65)
      opts.owner = "fallback-combat-laser-0423"
    end
    return opts
  end

  if _G.tech_priests_0292_prime_proxy_attack and not _G.TECH_PRIESTS_0419_PREVIOUS_PRIME_PROXY_0292 then
    _G.TECH_PRIESTS_0419_PREVIOUS_PRIME_PROXY_0292 = _G.tech_priests_0292_prime_proxy_attack
    _G.tech_priests_0292_prime_proxy_attack = function(pair, target, reason)
      local result = _G.TECH_PRIESTS_0419_PREVIOUS_PRIME_PROXY_0292(pair, target, reason)
      if pair and target and target.valid and pair.priest and pair.priest.valid and not is_space_pair(pair) then
        M.combat_intent(pair, target, reason or "prime-proxy-0292", combat_opts_after_proxy(pair, 88))
      end
      return result
    end
  end
  if _G.tech_priests_0293_prime_proxy_attack and not _G.TECH_PRIESTS_0419_PREVIOUS_PRIME_PROXY_0293 then
    _G.TECH_PRIESTS_0419_PREVIOUS_PRIME_PROXY_0293 = _G.tech_priests_0293_prime_proxy_attack
    _G.tech_priests_0293_prime_proxy_attack = function(pair, target, reason)
      local result = _G.TECH_PRIESTS_0419_PREVIOUS_PRIME_PROXY_0293(pair, target, reason)
      if pair and target and target.valid and pair.priest and pair.priest.valid and not is_space_pair(pair) then
        M.combat_intent(pair, target, reason or "prime-proxy-0293", combat_opts_after_proxy(pair, 88))
      end
      return result
    end
  end
end

function M.commands()
  if not (commands and commands.add_command) then return end
  pcall(function() commands.remove_command("tp-movement-0418") end)
  pcall(function() commands.remove_command("tp-movement-0419") end)
  pcall(function() commands.remove_command("tp-movement-0429") end)
  commands.add_command("tp-movement-0429", "Tech Priests 0.1.429 unified movement controller diagnostic for selected station/priest.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    if not (player and player.valid) then return end
    local pair = selected_pair(player)
    local root = ensure_root()
    if not pair then
      player.print("[tp-movement-0429] Select a Cogitator Station or Tech-Priest.")
      player.print("  stats requests=" .. tostring(root.stats.requests or 0) .. " collapsed=" .. tostring(root.stats.request_collapsed or 0) .. " commands=" .. tostring(root.stats.commands or 0) .. " snaps=" .. tostring(root.stats.snaps or 0))
      return
    end
    local req = pair.movement_request_0418
    player.print("[tp-movement-0429] mode=" .. tostring(pair.mode) .. " state=" .. tostring(pair.movement_controller_state_0418 or "nil") .. " clamp=" .. tostring(clamp_reason(pair) or pair.movement_controller_clamp_0418 or "none") .. " station=" .. tostring(pair.station and pair.station.unit_number) .. " priest=" .. tostring(pair.priest and pair.priest.valid and pair.priest.unit_number))
    if pair.priest and pair.priest.valid then player.print("  priest_pos=" .. string.format("%.2f,%.2f", pair.priest.position.x, pair.priest.position.y)) end
    if req then
      player.print("  request owner=" .. tostring(req.owner) .. " reason=" .. tostring(req.reason) .. " target=" .. string.format("%.2f,%.2f", req.x, req.y) .. " radius=" .. tostring(req.radius) .. " last_cmd=" .. tostring(req.last_command_tick or "nil") .. " d2=" .. tostring(req.last_distance_sq or "nil"))
    else
      player.print("  request=nil")
    end
    local snap = pair.last_ground_snap_0418 or root.last_snap
    if snap then player.print("  last_snap tick=" .. tostring(snap.tick) .. " dist=" .. tostring(snap.dist) .. " dt=" .. tostring(snap.dt) .. " allowed=" .. tostring(snap.allowed or "?") .. " reason=" .. tostring(snap.reason)) end
    player.print("  stats requests=" .. tostring(root.stats.requests or 0) .. " collapsed=" .. tostring(root.stats.request_collapsed or 0) .. " held=" .. tostring(root.stats.retargets_held or 0) .. " commands=" .. tostring(root.stats.commands or 0) .. " stops=" .. tostring(root.stats.stops or 0) .. " snaps=" .. tostring(root.stats.snaps or 0) .. " governed=" .. tostring(root.stats.high_speed_suppressed or 0))
  end)
end

function M.report_lines()
  local root = ensure_root()
  return {
    "[tp-runtime-report] movement-controller-0611 active_requests=" .. tostring(count_table(root.active_request_ids)) ..
      " stored_requests=" .. tostring(count_table(root.requests)) ..
      " requests=" .. tostring((root.stats or {}).requests or 0) ..
      " collapsed=" .. tostring((root.stats or {}).request_collapsed or 0) ..
      " retargets_held=" .. tostring((root.stats or {}).retargets_held or 0) ..
      " engine_commands=" .. tostring((root.stats or {}).commands or 0) ..
      " route_attempts=" .. tostring((root.stats or {}).route_command_attempts or 0) ..
      " route_ground=" .. tostring((root.stats or {}).route_command_ground or 0) ..
      " route_direct_fallback=" .. tostring((root.stats or {}).route_command_direct_fallback or 0) ..
      " active_processed=" .. tostring((root.stats or {}).service_active_processed or 0) ..
      " invalid_pruned=" .. tostring((root.stats or {}).invalid_request_pruned or 0) ..
      " expired_pruned=" .. tostring((root.stats or {}).expired_request_pruned or 0) ..
      " budget_exhausted=" .. tostring(((root.stats or {}).service_budget_exhausted or 0) + ((root.stats or {}).sample_budget_exhausted or 0))
  }
end

function M.install()
  ensure_root()
  M.patch_globals()
  M.commands()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not broker then pcall(function() broker = require("scripts.core.runtime_tick_broker") end) end
  if broker and type(broker.register_service) == "function" then
    broker.register_service({ name = "movement_controller_service_0611", category = "movement", priority = 42, interval = M.service_ticks, budget = 24, fn = function(event, budget) return M.service(event, budget) end, note = "service only active movement requests" })
    broker.register_service({ name = "movement_controller_sample_0611", category = "movement", priority = 80, interval = M.snap_sample_ticks, budget = 32, fn = function(event, budget) return M.sample(event, budget) end, note = "sample only active movement requests" })
  else
    local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
    if registry and registry.on_nth_tick then
      registry.on_nth_tick(M.service_ticks, function(event) M.service(event, 24) end, { owner = "movement_controller", category = "movement", note = "service movement requests" })
      registry.on_nth_tick(M.snap_sample_ticks, function(event) M.sample(event, 32) end, { owner = "movement_controller", category = "movement", note = "sample ground priest displacement" })
    elseif script and script.on_nth_tick then
      script.on_nth_tick(M.service_ticks, function(event) M.service(event, 24) end)
      script.on_nth_tick(M.snap_sample_ticks, function(event) M.sample(event, 32) end)
    end
  end
  if log then log("[Tech-Priests 0.1.452] unified ground movement controller installed; freeze-prone speed governor relaxed and converted to large-jump audit") end
  return true
end

return M
