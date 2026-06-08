-- scripts/core/combat_magos_movement_authority_0472.lua
-- Tech Priests 0.1.472
-- Late authority pass for two live-test failures:
--   1. Planetary Magos must be able to treat direct subordinate station operating
--      areas as valid planning / movement territory.
--   2. Point-blank combat and proxy-turret priming must be staged and throttled
--      so damage/contact events cannot create a command-loop slideshow.

local M = {}
M.version = "0.1.472"
M.storage_key = "combat_magos_movement_authority_0472"
M.subordinate_search_multiplier = 2.0
M.max_subordinate_search_radius = 160
M.combat_force_cooldown_ticks = 12
M.point_blank_force_cooldown_ticks = 36
M.proxy_prime_cooldown_ticks = 18
M.point_blank_proxy_cooldown_ticks = 36
M.proxy_sustain_ticks = 30
M.no_ammo_retry_ticks = 180
M.service_phase_mod = 5
M.point_blank_range = 2.35
M.debug_log_ticks = 180

local CombatSafety = nil
pcall(function() CombatSafety = require("scripts.core.combat_safety") end)

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, stats = {} }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  root.stats = root.stats or {}
  return root
end

local function dist_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function selected_pair(player)
  if not (player and player.valid) then return nil end
  local selected = player.selected
  if selected and selected.valid and _G.find_pair_for_entity then
    local ok, pair = pcall(_G.find_pair_for_entity, selected)
    if ok and pair then return pair end
  end
  if selected and selected.valid and storage and storage.tech_priests then
    return (storage.tech_priests.pairs_by_station or {})[selected.unit_number]
        or (storage.tech_priests.pairs_by_priest or {})[selected.unit_number]
  end
  return nil
end

local function station_unit(pair)
  return pair and pair.station and pair.station.valid and pair.station.unit_number or nil
end

local function station_name(pair)
  return tostring(pair and pair.station and pair.station.valid and pair.station.name or "")
end

local function priest_name(pair)
  return tostring(pair and pair.priest and pair.priest.valid and pair.priest.name or "")
end

local function station_rank(pair)
  if _G.tech_priests_radar_pair_station_rank_0280 then
    local ok, r = pcall(_G.tech_priests_radar_pair_station_rank_0280, pair)
    if ok and tonumber(r) then return tonumber(r) end
  end
  local n = station_name(pair) .. " " .. priest_name(pair) .. " " .. tostring(pair and pair.tier or "") .. " " .. tostring(pair and pair.rank or "")
  n = string.lower(n)
  if n:find("planetary%-magos", 1, false) or n:find("magos", 1, true) then return 4 end
  if n:find("senior", 1, true) then return 3 end
  if n:find("intermediate", 1, true) then return 2 end
  if n:find("junior", 1, true) then return 1 end
  return 0
end

local function is_magos(pair)
  return pair and valid(pair.station) and valid(pair.priest) and station_rank(pair) >= 4
end

local function operating_radius(pair)
  local r = tonumber(pair and (pair.radius or pair.scan_radius or pair.station_radius)) or nil
  if _G.refresh_pair_radius then
    local ok, got = pcall(_G.refresh_pair_radius, pair)
    if ok and tonumber(got) then r = tonumber(got) end
  end
  if (not r) and _G.get_station_operating_radius and pair and valid(pair.station) then
    local ok, got = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(got) then r = tonumber(got) end
  end
  return math.max(12, tonumber(r) or 30)
end

local function same_domain(a, b)
  return valid(a and a.station) and valid(b and b.station)
     and a.station.surface == b.station.surface
     and a.station.force == b.station.force
end

local function subordinate_pairs(pair)
  local out = {}
  if not is_magos(pair) then return out end
  local rank = station_rank(pair)
  local search_r = math.min(M.max_subordinate_search_radius, operating_radius(pair) * M.subordinate_search_multiplier)
  for _, other in pairs(pair_map()) do
    if other ~= pair and same_domain(pair, other) and station_rank(other) < rank then
      if dist_sq(pair.station.position, other.station.position) <= search_r * search_r then
        out[#out + 1] = other
      end
    end
  end
  table.sort(out, function(a, b) return dist_sq(pair.station.position, a.station.position) < dist_sq(pair.station.position, b.station.position) end)
  return out
end

local function pos_in_pair_radius(pair, pos)
  if not (pair and valid(pair.station) and pos) then return false end
  local r = operating_radius(pair)
  return dist_sq(pair.station.position, pos) <= r * r
end

function M.position_in_authority(pair, pos)
  if not (pair and valid(pair.station) and valid(pair.priest) and pos) then return false, nil end
  if pos_in_pair_radius(pair, pos) then return true, { pair = pair, role = "primary", station_unit = station_unit(pair), radius = operating_radius(pair) } end
  if is_magos(pair) then
    for _, sub in ipairs(subordinate_pairs(pair)) do
      if pos_in_pair_radius(sub, pos) then
        return true, { pair = sub, role = "subordinate", station_unit = station_unit(sub), radius = operating_radius(sub) }
      end
    end
  end
  return false, nil
end

local function current_target(pair)
  local target = pair and pair.combat_target
  if target and target.valid then return target end
  target = pair and pair.target
  if target and target.valid then return target end
  local task = pair and (pair.active_task or pair.active_task_0285) or nil
  if type(task) == "table" and task.target and task.target.valid then return task.target end
  return nil
end

local function is_hostile(pair, target)
  if not (pair and target and target.valid) then return false end
  if _G.TECH_PRIESTS_BEHAVIOR_MUTEX_0466 and _G.TECH_PRIESTS_BEHAVIOR_MUTEX_0466.is_hostile then
    local ok, yes = pcall(_G.TECH_PRIESTS_BEHAVIOR_MUTEX_0466.is_hostile, pair, target)
    if ok then return yes == true end
  end
  if CombatSafety and CombatSafety.is_valid_hostile_target then
    local ok, yes = pcall(CombatSafety.is_valid_hostile_target, pair.priest or pair.station or pair, target)
    if ok then return yes == true end
  end
  if not (pair.priest and pair.priest.valid and pair.priest.force and target.force) then return false end
  if target.force == pair.priest.force then return false end
  if target.force.name == "neutral" then return false end
  local enemy = false
  pcall(function() if pair.priest.force.is_enemy then enemy = pair.priest.force.is_enemy(target.force) end end)
  return enemy == true
end

local function target_distance_sq(pair, target)
  if not (pair and valid(pair.priest) and target and target.valid) then return 999999999 end
  return dist_sq(pair.priest.position, target.position)
end

local function is_point_blank(pair, target)
  return target_distance_sq(pair, target) <= (M.point_blank_range * M.point_blank_range)
end

local function phase_for(pair)
  return math.abs(tonumber(station_unit(pair) or 0) or 0) % M.service_phase_mod
end

local function has_proxy_ammo(pair)
  if _G.tech_priests_0295_station_or_proxy_has_ammo then
    local ok, yes = pcall(_G.tech_priests_0295_station_or_proxy_has_ammo, pair)
    if ok then return yes == true end
  end
  if _G.tech_priests_0293_proxy_has_ammo then
    local ok, yes = pcall(_G.tech_priests_0293_proxy_has_ammo, pair)
    if ok and yes then return true end
  end
  if _G.tech_priests_0293_station_has_ammo then
    local ok, yes = pcall(_G.tech_priests_0293_station_has_ammo, pair)
    if ok and yes then return true end
  end
  return false
end

local function ensure_proxy_entity(pair)
  if pair and pair.proxy and pair.proxy.valid then return pair.proxy end
  if _G.ensure_proxy then
    local ok, proxy = pcall(_G.ensure_proxy, pair)
    if ok and proxy and proxy.valid then pair.proxy = proxy; return proxy end
  end
  return nil
end

function M.sustain_proxy(pair, target, reason)
  if not (pair and valid(pair.priest) and target and target.valid and is_hostile(pair, target)) then return false end
  local tick = now()
  local proxy = ensure_proxy_entity(pair)
  if not (proxy and proxy.valid) then
    pair.last_combat_stage_0472 = "no-proxy"
    return false
  end

  if tick >= (pair.next_proxy_alignment_tick_0472 or 0) then
    pair.next_proxy_alignment_tick_0472 = tick + M.proxy_sustain_ticks
    if _G.tech_priests_align_proxy_to_priest_0430 then
      pcall(_G.tech_priests_align_proxy_to_priest_0430, pair, proxy, pair.priest, reason or "combat-stage-sustain")
    else
      pcall(function() proxy.teleport(pair.priest.position) end)
    end
    pcall(function() proxy.active = true end)
    pcall(function() proxy.operable = false end)
    pcall(function() proxy.destructible = false end)
  end

  if not has_proxy_ammo(pair) then
    if tick >= (pair.next_proxy_ammo_load_tick_0472 or 0) then
      pair.next_proxy_ammo_load_tick_0472 = tick + M.no_ammo_retry_ticks
      pcall(function() if _G.load_proxy_from_station then _G.load_proxy_from_station(pair) end end)
    end
  end

  if tick >= (pair.next_proxy_target_sustain_tick_0472 or 0) or pair.last_proxy_target_unit_0472 ~= (target.unit_number or 0) then
    pair.next_proxy_target_sustain_tick_0472 = tick + M.proxy_sustain_ticks
    pair.last_proxy_target_unit_0472 = target.unit_number or 0
    pcall(function() proxy.shooting_target = target end)
  end

  pair.proxy_expires = math.max(pair.proxy_expires or 0, tick + 180)
  pair.combat_target = target
  pair.target = target
  pair.task_kind = "combat"
  if pair.mode ~= "moving-to-combat" then pair.mode = "defending" end
  pair.last_combat_stage_0472 = reason or "proxy-sustained"
  pair.last_combat_stage_tick_0472 = tick
  local root = ensure_root()
  root.stats.proxy_sustains = (root.stats.proxy_sustains or 0) + 1
  return true
end

function M.wrap_magos_authority()
  if _G.tech_priests_radar_entity_inside_station_0278 and not _G.TECH_PRIESTS_0472_PRE_RADAR_INSIDE_STATION then
    _G.TECH_PRIESTS_0472_PRE_RADAR_INSIDE_STATION = _G.tech_priests_radar_entity_inside_station_0278
    _G.tech_priests_radar_entity_inside_station_0278 = function(pair, entity)
      local ok, inside = pcall(_G.TECH_PRIESTS_0472_PRE_RADAR_INSIDE_STATION, pair, entity)
      if ok and inside then return true end
      if pair and entity and entity.valid and is_magos(pair) then
        local yes, anchor = M.position_in_authority(pair, entity.position)
        if yes and anchor and anchor.role == "subordinate" then
          pair.last_subordinate_authority_0472 = { tick = now(), station_unit = anchor.station_unit, entity = entity.name, role = anchor.role }
          ensure_root().stats.subordinate_area_accepts = (ensure_root().stats.subordinate_area_accepts or 0) + 1
          return true
        end
      end
      return false
    end
  end

  if _G.tech_priests_request_movement_0418 and not _G.TECH_PRIESTS_0472_PRE_REQUEST_MOVEMENT then
    _G.TECH_PRIESTS_0472_PRE_REQUEST_MOVEMENT = _G.tech_priests_request_movement_0418
    _G.tech_priests_request_movement_0418 = function(pair, destination, reason, opts)
      if pair and destination and is_magos(pair) then
        local yes, anchor = M.position_in_authority(pair, destination)
        if yes and anchor and anchor.role == "subordinate" then
          opts = opts or {}
          opts.force_subordinate_area_0472 = true
          pair.last_subordinate_movement_authority_0472 = { tick = now(), x = destination.x, y = destination.y, station_unit = anchor.station_unit, reason = tostring(reason or "movement") }
          ensure_root().stats.subordinate_movement_accepts = (ensure_root().stats.subordinate_movement_accepts or 0) + 1
        end
      end
      return _G.TECH_PRIESTS_0472_PRE_REQUEST_MOVEMENT(pair, destination, reason, opts)
    end
  end
end

function M.wrap_combat()
  if _G.tech_priests_0293_prime_proxy_attack and not _G.TECH_PRIESTS_0472_PRE_PRIME_PROXY_ATTACK then
    _G.TECH_PRIESTS_0472_PRE_PRIME_PROXY_ATTACK = _G.tech_priests_0293_prime_proxy_attack
    _G.tech_priests_0293_prime_proxy_attack = function(pair, target, reason)
      if not (pair and valid(pair.priest) and target and target.valid and is_hostile(pair, target)) then
        return _G.TECH_PRIESTS_0472_PRE_PRIME_PROXY_ATTACK(pair, target, reason)
      end
      local tick = now()
      local near = is_point_blank(pair, target)
      local gap = near and M.point_blank_proxy_cooldown_ticks or M.proxy_prime_cooldown_ticks
      local same_target = pair.last_prime_target_unit_0472 == (target.unit_number or 0)

      if not has_proxy_ammo(pair) and tick < (pair.next_no_ammo_prime_retry_0472 or 0) then
        pair.last_combat_stage_0472 = "no-ammo-cooldown"
        M.sustain_proxy(pair, target, "no-ammo-cooldown-hold")
        return true
      elseif not has_proxy_ammo(pair) then
        pair.next_no_ammo_prime_retry_0472 = tick + M.no_ammo_retry_ticks
      end

      if same_target and tick < (pair.next_proxy_prime_tick_0472 or 0) then
        pair.last_combat_stage_0472 = near and "point-blank-proxy-cooldown" or "proxy-cooldown"
        M.sustain_proxy(pair, target, pair.last_combat_stage_0472)
        ensure_root().stats.proxy_prime_suppressed = (ensure_root().stats.proxy_prime_suppressed or 0) + 1
        return true
      end

      pair.next_proxy_prime_tick_0472 = tick + gap
      pair.last_prime_target_unit_0472 = target.unit_number or 0
      local ok = _G.TECH_PRIESTS_0472_PRE_PRIME_PROXY_ATTACK(pair, target, reason)
      if ok then M.sustain_proxy(pair, target, near and "point-blank-prime" or "proxy-prime") end
      return ok
    end
  end

  if _G.tech_priests_0293_force_combat_tick and not _G.TECH_PRIESTS_0472_PRE_FORCE_COMBAT_TICK then
    _G.TECH_PRIESTS_0472_PRE_FORCE_COMBAT_TICK = _G.tech_priests_0293_force_combat_tick
    _G.tech_priests_0293_force_combat_tick = function(pair, reason, force)
      if not (pair and valid(pair.station) and valid(pair.priest)) then return false end
      local tick = now()
      local target = current_target(pair)
      local hostile = target and target.valid and is_hostile(pair, target)
      local near = hostile and is_point_blank(pair, target)
      local gap = near and M.point_blank_force_cooldown_ticks or M.combat_force_cooldown_ticks

      if not force and hostile then
        if tick < (pair.next_combat_force_tick_0472 or 0) then
          pair.last_combat_stage_0472 = near and "point-blank-force-cooldown" or "force-cooldown"
          M.sustain_proxy(pair, target, pair.last_combat_stage_0472)
          ensure_root().stats.force_combat_suppressed = (ensure_root().stats.force_combat_suppressed or 0) + 1
          return true
        end
        if (tick % M.service_phase_mod) ~= phase_for(pair) and not near then
          pair.last_combat_stage_0472 = "staggered-service-hold"
          M.sustain_proxy(pair, target, "staggered-service-hold")
          return true
        end
      elseif not force and (tick % M.service_phase_mod) ~= phase_for(pair) then
        return false
      end

      pair.next_combat_force_tick_0472 = tick + gap
      local ok = _G.TECH_PRIESTS_0472_PRE_FORCE_COMBAT_TICK(pair, reason, force)
      target = current_target(pair)
      if ok and target and target.valid and is_hostile(pair, target) then M.sustain_proxy(pair, target, near and "point-blank-force" or "force-combat") end
      return ok
    end
    _G.tech_priests_0292_force_combat_tick = _G.tech_priests_0293_force_combat_tick
  end

  if _G.issue_priest_command and not _G.TECH_PRIESTS_0472_PRE_ISSUE_PRIEST_COMMAND then
    _G.TECH_PRIESTS_0472_PRE_ISSUE_PRIEST_COMMAND = _G.issue_priest_command
    _G.issue_priest_command = function(priest, command)
      if command and defines and defines.command and command.type == defines.command.attack and priest and priest.valid then
        local pair = nil
        if storage and storage.tech_priests and storage.tech_priests.pairs_by_priest then pair = storage.tech_priests.pairs_by_priest[priest.unit_number] end
        local target = command.target
        if pair and target and target.valid and is_hostile(pair, target) then
          pair.combat_target = target
          pair.target = target
          -- Do not let the visible character AI become a second attack/pathing owner.
          -- The hidden proxy turret and movement controller own combat.
          M.sustain_proxy(pair, target, "visible-attack-command-routed")
          return true
        end
      end
      return _G.TECH_PRIESTS_0472_PRE_ISSUE_PRIEST_COMMAND(priest, command)
    end
  end
end

function M.service()
  local root = ensure_root()
  local processed = 0
  for _, pair in pairs(pair_map()) do
    if pair and valid(pair.station) and valid(pair.priest) then
      local target = current_target(pair)
      if target and target.valid and is_hostile(pair, target) then
        processed = processed + 1
        if processed > 12 then break end
        if now() >= (pair.next_proxy_alignment_tick_0472 or 0) then M.sustain_proxy(pair, target, "periodic-combat-sustain") end
      end
    end
  end
  root.stats.service_ticks = (root.stats.service_ticks or 0) + 1
end

function M.commands()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-combat-stage-0472") end end)
  commands.add_command("tp-combat-stage-0472", "Tech Priests 0.1.472: inspect combat staging and Magos subordinate-area authority.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    if not (player and player.valid) then return end
    local pair = selected_pair(player)
    if not pair then player.print("[tp-combat-stage-0472] Select a Cogitator Station or Tech-Priest."); return end
    local target = current_target(pair)
    local root = ensure_root()
    player.print("[tp-combat-stage-0472] rank=" .. safe(station_rank(pair)) .. " magos=" .. safe(is_magos(pair)) .. " mode=" .. safe(pair.mode) .. " stage=" .. safe(pair.last_combat_stage_0472) .. " target=" .. safe(target and target.valid and target.name) .. " hostile=" .. safe(is_hostile(pair, target)) .. " point_blank=" .. safe(target and target.valid and is_point_blank(pair, target)) .. " proxy=" .. safe(pair.proxy and pair.proxy.valid and pair.proxy.unit_number) .. " next_force=" .. safe(pair.next_combat_force_tick_0472) .. " stats_force_suppressed=" .. safe(root.stats.force_combat_suppressed or 0))
    if pair.last_subordinate_movement_authority_0472 then player.print("  subordinate movement anchor=" .. safe(pair.last_subordinate_movement_authority_0472.station_unit) .. " reason=" .. safe(pair.last_subordinate_movement_authority_0472.reason)) end
    if pair.last_subordinate_authority_0472 then player.print("  subordinate radar anchor=" .. safe(pair.last_subordinate_authority_0472.station_unit) .. " entity=" .. safe(pair.last_subordinate_authority_0472.entity)) end
  end)
end

function M.install()
  ensure_root()
  M.wrap_magos_authority()
  M.wrap_combat()
  M.commands()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if registry and registry.on_nth_tick then
    registry.on_nth_tick(13, function() M.service() end, { owner = "combat_magos_movement_authority_0472", category = "combat", note = "staged proxy sustain and point-blank throttle" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(13, function() M.service() end)
  end
  _G.TECH_PRIESTS_COMBAT_MAGOS_MOVEMENT_AUTHORITY_0472 = M
  _G.tech_priests_magos_position_in_authority_0472 = M.position_in_authority
  if log then log("[Tech-Priests 0.1.472] Magos subordinate-area authority + staged point-blank combat throttle installed") end
  return true
end

return M
