#!/usr/bin/env python3
from pathlib import Path
import re


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding="utf-8")


def replace_once(path: str, old: str, new: str) -> None:
    text = read(path)
    if old not in text:
        raise SystemExit(f"missing expected text in {path}: {old[:160]}")
    write(path, text.replace(old, new, 1))


def regex_once(path: str, pattern: str, replacement: str) -> None:
    text = read(path)
    text, count = re.subn(pattern, replacement, text, count=1, flags=re.DOTALL)
    if count != 1:
        raise SystemExit(f"regex replacement count={count} in {path}: {pattern[:120]}")
    write(path, text)


# 1. Command hierarchy becomes the native subordinate-area authority and broker service.
path = "tech-priests_src/scripts/core/command_hierarchy_0480.lua"
text = read(path)
text = text.replace('M.version = "0.1.624"', 'M.version = "0.1.674-dev"', 1)
text = text.replace(
    'M.default_peer_limit = 16',
    'M.default_peer_limit = 16\nM.rebuild_service_name = "command_hierarchy_rebuild_0480"\nM.broker_required = true\nM.position_authority_integrated = true',
    1,
)
old_dist = '''local function dist_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end
'''
new_dist = old_dist + '''
local function operating_radius(pair)
  if not valid(pair and pair.station) then return 0 end
  local radius = tonumber(pair.radius or pair.scan_radius or pair.station_radius)
  if type(_G.refresh_pair_radius) == "function" then
    local ok, got = pcall(_G.refresh_pair_radius, pair)
    if ok and tonumber(got) then radius = tonumber(got) end
  end
  if not radius and type(_G.get_station_operating_radius) == "function" then
    local ok, got = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(got) then radius = tonumber(got) end
  end
  return math.max(12, tonumber(radius) or 30)
end
'''
if old_dist not in text:
    raise SystemExit("command hierarchy distance helper anchor missing")
text = text.replace(old_dist, new_dist, 1)
old_subs = '''function M.direct_subordinates(pair)
  local out = {}
  local h = M.hierarchy(pair)
  if not h then return out end
  for _, unit in ipairs(h.direct_subordinate_units or {}) do
    local p = M.pair_by_station_unit(unit)
    if p and valid(p.station) and valid(p.priest) then out[#out + 1] = p end
  end
  return out
end

function M.peers(pair)'''
new_subs = '''function M.direct_subordinates(pair)
  local out = {}
  local h = M.hierarchy(pair)
  if not h then return out end
  for _, unit in ipairs(h.direct_subordinate_units or {}) do
    local p = M.pair_by_station_unit(unit)
    if p and valid(p.station) and valid(p.priest) then out[#out + 1] = p end
  end
  return out
end

function M.position_in_authority(pair, pos)
  if not (pair and valid(pair.station) and valid(pair.priest) and pos) then return false, nil end
  local primary_radius = operating_radius(pair)
  if dist_sq(pair.station.position, pos) <= primary_radius * primary_radius then
    return true, { pair = pair, role = "primary", station_unit = station_unit(pair), radius = primary_radius }
  end
  for _, subordinate in ipairs(M.direct_subordinates(pair)) do
    local radius = operating_radius(subordinate)
    if dist_sq(subordinate.station.position, pos) <= radius * radius then
      return true, { pair = subordinate, role = "direct-subordinate", station_unit = station_unit(subordinate), radius = radius }
    end
  end
  return false, nil
end

function M.peers(pair)'''
if old_subs not in text:
    raise SystemExit("command hierarchy direct subordinate anchor missing")
text = text.replace(old_subs, new_subs, 1)
text, count = re.subn(
    r'\nfunction M\.patch_magos_authority\(\).*?\nend\n\nlocal function describe_pair_line',
    '\nlocal function describe_pair_line',
    text,
    count=1,
    flags=re.DOTALL,
)
if count != 1:
    raise SystemExit(f"command hierarchy 0472 wrapper removal count={count}")
new_tail = '''function M.tick()
  local rebuilt = maybe_rebuild("periodic")
  return {
    processed = 0,
    acted = rebuilt and 1 or 0,
    detail = rebuilt and "command-topology-rebuilt" or "command-topology-unchanged",
  }
end

function M.install()
  if M._installed then return true end
  ensure_root()
  M.rebuild("install")
  M.patch_subordinate_scheduler()
  M.patch_diagnostics()
  _G.TECH_PRIESTS_COMMAND_HIERARCHY_0480 = M
  _G.tech_priests_0480_command_hierarchy_for_pair = M.hierarchy
  _G.tech_priests_0480_direct_subordinates = M.direct_subordinates
  _G.tech_priests_0480_superior = M.superior
  _G.tech_priests_0480_position_in_authority = M.position_in_authority
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not broker then pcall(function() broker = require("scripts.core.runtime_tick_broker") end) end
  if not (broker and type(broker.register_service) == "function") then return false end
  local registered = broker.register_service({
    name = "command_hierarchy_rebuild_0480",
    category = "scheduler",
    interval = M.rebuild_interval,
    priority = 34,
    budget = 1,
    fn = function() return M.tick() end,
    note = "canonical direct-subordinate topology and command territory rebuild",
  })
  if not registered then return false end
  M._installed = true
  M.register_commands()
  if log then log("[Tech-Priests 0.1.674-dev] broker-owned command hierarchy and direct-subordinate territory installed") end
  return true
end

return M'''
text, count = re.subn(
    r'function M\.tick\(\).*?\nend\n\nfunction M\.install\(\).*?\nend\n\nreturn M\s*$',
    new_tail,
    text,
    count=1,
    flags=re.DOTALL,
)
if count != 1:
    raise SystemExit(f"command hierarchy tail replacement count={count}")
write(path, text)

# 2. Legacy radar reads command hierarchy directly instead of a late wrapper.
replace_once(
    "tech-priests_src/scripts/generated/control_legacy_part_017.lua",
    '''function tech_priests_radar_entity_inside_station_0278(pair, entity)
  if not (pair and pair.station and pair.station.valid and entity and entity.valid) then return false end
  local radius = pair.radius or (refresh_pair_radius and refresh_pair_radius(pair)) or (get_station_operating_radius and get_station_operating_radius(pair.station)) or 30
  return tech_priests_radar_distance_sq_0278(pair.station.position, entity.position) <= radius * radius
end''',
    '''function tech_priests_radar_entity_inside_station_0278(pair, entity)
  if not (pair and pair.station and pair.station.valid and entity and entity.valid) then return false end
  local radius = pair.radius or (refresh_pair_radius and refresh_pair_radius(pair)) or (get_station_operating_radius and get_station_operating_radius(pair.station)) or 30
  if tech_priests_radar_distance_sq_0278(pair.station.position, entity.position) <= radius * radius then return true end
  local authority = rawget(_G, "tech_priests_0480_position_in_authority")
  if type(authority) == "function" then
    local ok, inside = pcall(authority, pair, entity.position)
    if ok and inside == true then return true end
  end
  return false
end''',
)

# 3. Movement controller absorbs the proxy-prime throttle in its existing wrapper.
path = "tech-priests_src/scripts/core/movement_controller.lua"
text = read(path)
text = text.replace(
    'M.combat_approach_radius = 13',
    'M.combat_approach_radius = 13\nM.proxy_prime_cooldown_ticks = 18\nM.point_blank_proxy_cooldown_ticks = 36\nM.proxy_prime_point_blank_range = 2.35\nM.proxy_prime_throttle_integrated = true',
    1,
)
old_space = '''local function is_space_pair(pair)
  if _G.tech_priests_pair_on_space_platform_0204 then
    local ok, result = pcall(_G.tech_priests_pair_on_space_platform_0204, pair)
    if ok and result then return true end
  end
  return false
end
'''
new_space = old_space + '''
local function proxy_prime_allowed(pair, target)
  if not (pair and valid(pair.priest) and target and target.valid) then return true end
  local root = ensure_root()
  local target_unit = target.unit_number or 0
  local distance = dist_sq(pair.priest.position, target.position) or math.huge
  local point_blank = distance <= M.proxy_prime_point_blank_range * M.proxy_prime_point_blank_range
  local gap = point_blank and M.point_blank_proxy_cooldown_ticks or M.proxy_prime_cooldown_ticks
  if pair.last_prime_target_unit_0419 == target_unit and now() < (pair.next_proxy_prime_tick_0419 or 0) then
    root.stats.proxy_prime_suppressed = (root.stats.proxy_prime_suppressed or 0) + 1
    pair.last_proxy_prime_stage_0419 = point_blank and "point-blank-proxy-cooldown" or "proxy-cooldown"
    return false
  end
  pair.last_prime_target_unit_0419 = target_unit
  pair.next_proxy_prime_tick_0419 = now() + gap
  pair.last_proxy_prime_stage_0419 = point_blank and "point-blank-prime" or "proxy-prime"
  return true
end
'''
if old_space not in text:
    raise SystemExit("movement controller space helper anchor missing")
text = text.replace(old_space, new_space, 1)
old_prime = '''  if _G.tech_priests_0293_prime_proxy_attack and not _G.TECH_PRIESTS_0419_PREVIOUS_PRIME_PROXY_0293 then
    _G.TECH_PRIESTS_0419_PREVIOUS_PRIME_PROXY_0293 = _G.tech_priests_0293_prime_proxy_attack
    _G.tech_priests_0293_prime_proxy_attack = function(pair, target, reason)
      local result = _G.TECH_PRIESTS_0419_PREVIOUS_PRIME_PROXY_0293(pair, target, reason)
      if pair and target and target.valid and pair.priest and pair.priest.valid and not is_space_pair(pair) then
        M.combat_intent(pair, target, reason or "prime-proxy-0293", combat_opts_after_proxy(pair, 88))
      end
      return result
    end
  end'''
new_prime = '''  if _G.tech_priests_0293_prime_proxy_attack and not _G.TECH_PRIESTS_0419_PREVIOUS_PRIME_PROXY_0293 then
    _G.TECH_PRIESTS_0419_PREVIOUS_PRIME_PROXY_0293 = _G.tech_priests_0293_prime_proxy_attack
    _G.tech_priests_0293_prime_proxy_attack = function(pair, target, reason)
      if not proxy_prime_allowed(pair, target) then return true end
      local result = _G.TECH_PRIESTS_0419_PREVIOUS_PRIME_PROXY_0293(pair, target, reason)
      if pair and target and target.valid and pair.priest and pair.priest.valid and not is_space_pair(pair) then
        M.combat_intent(pair, target, reason or "prime-proxy-0293", combat_opts_after_proxy(pair, 88))
      end
      return result
    end
  end'''
if old_prime not in text:
    raise SystemExit("movement controller 0293 prime wrapper anchor missing")
text = text.replace(old_prime, new_prime, 1)
write(path, text)

# 4. Behavior mutex absorbs the force-combat cooldown and staggering in its existing wrapper.
path = "tech-priests_src/scripts/core/behavior_mutex_0466.lua"
text = read(path)
text = text.replace('M.version = "0.1.466"', 'M.version = "0.1.674-dev"', 1)
text = text.replace(
    'M.invalid_target_log_ticks = 180',
    'M.invalid_target_log_ticks = 180\nM.combat_force_cooldown_ticks = 12\nM.point_blank_force_cooldown_ticks = 36\nM.force_service_phase_mod = 5\nM.point_blank_range = 2.35\nM.force_combat_throttle_integrated = true',
    1,
)
old_pair = '''local function pair_for_priest(priest)
  if not valid(priest) then return nil end
  if storage and storage.tech_priests and storage.tech_priests.pairs_by_priest then
    local pair = storage.tech_priests.pairs_by_priest[priest.unit_number]
    if pair then return pair end
  end
  if _G.find_pair_for_entity then local ok, pair = pcall(_G.find_pair_for_entity, priest); if ok and pair then return pair end end
  return nil
end
'''
new_pair = old_pair + '''
local function distance_sq(a, b)
  if not (a and b) then return math.huge end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function current_combat_target(pair)
  if pair and pair.combat_target and pair.combat_target.valid then return pair.combat_target end
  if pair and pair.target and pair.target.valid then return pair.target end
  return nil
end

local function force_phase(pair)
  local unit = pair and pair.station and pair.station.valid and pair.station.unit_number or 0
  return math.abs(tonumber(unit) or 0) % M.force_service_phase_mod
end
'''
if old_pair not in text:
    raise SystemExit("behavior mutex pair helper anchor missing")
text = text.replace(old_pair, new_pair, 1)
old_force = '''  if _G.tech_priests_0293_force_combat_tick and not _G.TECH_PRIESTS_0466_PRE_0293_FORCE_COMBAT_TICK then
    _G.TECH_PRIESTS_0466_PRE_0293_FORCE_COMBAT_TICK = _G.tech_priests_0293_force_combat_tick
    _G.tech_priests_0293_force_combat_tick = function(pair, reason, force)
      M.clear_invalid_combat_target(pair, "before-force-combat")
      local ok = _G.TECH_PRIESTS_0466_PRE_0293_FORCE_COMBAT_TICK(pair, reason, force)
      if ok then M.pause_acquisition_for_combat(pair, "force-combat-active") end
      return ok
    end
    _G.tech_priests_0292_force_combat_tick = _G.tech_priests_0293_force_combat_tick
  end'''
new_force = '''  if _G.tech_priests_0293_force_combat_tick and not _G.TECH_PRIESTS_0466_PRE_0293_FORCE_COMBAT_TICK then
    _G.TECH_PRIESTS_0466_PRE_0293_FORCE_COMBAT_TICK = _G.tech_priests_0293_force_combat_tick
    _G.tech_priests_0293_force_combat_tick = function(pair, reason, force)
      M.clear_invalid_combat_target(pair, "before-force-combat")
      local target = current_combat_target(pair)
      local hostile = target and M.is_hostile(pair, target)
      local point_blank = hostile and valid(pair and pair.priest) and distance_sq(pair.priest.position, target.position) <= M.point_blank_range * M.point_blank_range
      local gap = point_blank and M.point_blank_force_cooldown_ticks or M.combat_force_cooldown_ticks
      if not force and hostile then
        if now() < (pair.next_combat_force_tick_0466 or 0) then
          ensure_root().stats.force_combat_suppressed = (ensure_root().stats.force_combat_suppressed or 0) + 1
          pair.last_force_combat_stage_0466 = point_blank and "point-blank-force-cooldown" or "force-cooldown"
          return true
        end
        if (now() % M.force_service_phase_mod) ~= force_phase(pair) and not point_blank then
          ensure_root().stats.force_combat_staggered = (ensure_root().stats.force_combat_staggered or 0) + 1
          pair.last_force_combat_stage_0466 = "staggered-service-hold"
          return true
        end
      elseif not force and (now() % M.force_service_phase_mod) ~= force_phase(pair) then
        return false
      end
      pair.next_combat_force_tick_0466 = now() + gap
      local ok = _G.TECH_PRIESTS_0466_PRE_0293_FORCE_COMBAT_TICK(pair, reason, force)
      if ok then
        pair.last_force_combat_stage_0466 = point_blank and "point-blank-force" or "force-combat"
        M.pause_acquisition_for_combat(pair, "force-combat-active")
      end
      return ok
    end
    _G.tech_priests_0292_force_combat_tick = _G.tech_priests_0293_force_combat_tick
  end'''
if old_force not in text:
    raise SystemExit("behavior mutex force wrapper anchor missing")
text = text.replace(old_force, new_force, 1)
write(path, text)

# 5. Proxy alignment becomes the sole broker-owned hidden-proxy position/sustain authority.
proxy_source = '''-- scripts/core/proxy_turret_alignment.lua
-- Tech Priests 0.1.674-dev canonical hidden-proxy position authority.
-- Visible priest movement belongs to movement_controller. Proxy ammunition belongs
-- to proxy_ammo_hardener_0649. This module owns only proxy identity, alignment,
-- attachment recovery, and shooting-target sustain through broker services.

local M = {
  version = "0.1.674-dev",
  storage_key = "proxy_turret_alignment_0430",
  heartbeat_interval = 90,
  combat_sustain_interval = 13,
  heartbeat_budget = 24,
  combat_sustain_budget = 12,
  alignment_hold_ticks = 30,
  max_attached_distance_sq = 4.0,
  orphan_search_radius = 20,
  proxy_name = "tech-priest-small-arms-proxy",
  broker_required = true,
  combat_sustain_integrated = true,
}

local CombatSafety = nil
pcall(function() CombatSafety = require("scripts.core.combat_safety") end)

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function distance_sq(a, b)
  if not (a and b) then return math.huge end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end
local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end
local function state()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, stats = {} }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  root.stats = root.stats or {}
  return root
end
local function proxy_name() return rawget(_G, "PROXY_NAME") or M.proxy_name end

function M.align_to_priest(pair, proxy, priest, reason)
  priest = priest or (pair and pair.priest) or nil
  proxy = proxy or (pair and pair.proxy) or nil
  if not (valid(proxy) and valid(priest)) then return false end
  local ok, moved = pcall(function() return proxy.teleport(priest.position) end)
  if ok and moved ~= false then
    if pair then
      pair.last_proxy_alignment_0430 = {
        tick = now(), reason = reason or "proxy-alignment", proxy_unit = proxy.unit_number,
        priest_unit = priest.unit_number, x = priest.position.x, y = priest.position.y,
      }
    end
    return true
  end
  if pair then
    pair.last_proxy_alignment_0430 = {
      tick = now(), reason = reason or "proxy-alignment-failed", failed = true,
      proxy_unit = proxy.unit_number, priest_unit = priest.unit_number,
    }
  end
  return false
end

function M.describe(pair)
  local rec = pair and pair.last_proxy_alignment_0430 or nil
  if not rec then return "no-proxy-alignment-record" end
  return "tick=" .. tostring(rec.tick) .. " reason=" .. tostring(rec.reason) ..
    " failed=" .. tostring(rec.failed or false) .. " proxy=" .. tostring(rec.proxy_unit or "?") ..
    " priest=" .. tostring(rec.priest_unit or "?")
end

local function ensure_proxy(pair)
  if pair and valid(pair.proxy) then return pair.proxy end
  local fn = rawget(_G, "ensure_proxy")
  if type(fn) == "function" then
    local ok, proxy = pcall(fn, pair)
    if ok and valid(proxy) then pair.proxy = proxy; return proxy end
  end
  return nil
end

local function owned_proxy_units()
  local owned = {}
  for _, pair in pairs(pair_map()) do
    if pair and valid(pair.proxy) and pair.proxy.unit_number then owned[pair.proxy.unit_number] = true end
  end
  return owned
end

local function find_unowned_proxy(pair, owned)
  if not (pair and valid(pair.priest) and valid(pair.station)) then return nil end
  local pos, surface = pair.priest.position, pair.priest.surface
  if not surface then return nil end
  local radius = M.orphan_search_radius
  local ok, found = pcall(function()
    return surface.find_entities_filtered({
      name = proxy_name(), force = pair.priest.force,
      area = {{pos.x - radius, pos.y - radius}, {pos.x + radius, pos.y + radius}},
    })
  end)
  if not (ok and found) then return nil end
  local best, best_distance = nil, math.huge
  for _, proxy in ipairs(found) do
    if valid(proxy) and not (proxy.unit_number and owned[proxy.unit_number]) then
      local distance = distance_sq(proxy.position, pos)
      if distance < best_distance then best, best_distance = proxy, distance end
    end
  end
  return best
end

local function current_target(pair)
  if pair and valid(pair.combat_target) then return pair.combat_target end
  if pair and valid(pair.target) then return pair.target end
  return nil
end

local function hostile(pair, target)
  if not (pair and valid(target)) then return false end
  local mutex = rawget(_G, "TECH_PRIESTS_BEHAVIOR_MUTEX_0466")
  if mutex and type(mutex.is_hostile) == "function" then
    local ok, yes = pcall(mutex.is_hostile, pair, target)
    if ok then return yes == true end
  end
  if CombatSafety and type(CombatSafety.is_valid_hostile_target) == "function" then
    local ok, yes = pcall(CombatSafety.is_valid_hostile_target, pair.priest or pair.station or pair, target)
    if ok then return yes == true end
  end
  return false
end

function M.heartbeat_service(_, budget)
  local root = state()
  local owned = owned_proxy_units()
  local processed, repaired, blocked = 0, 0, 0
  local limit = math.max(1, math.min(64, math.floor(tonumber(budget) or M.heartbeat_budget)))
  for _, pair in pairs(pair_map()) do
    if processed >= limit then break end
    if pair and valid(pair.priest) and valid(pair.station) then
      processed = processed + 1
      local proxy = pair.proxy
      if not valid(proxy) then
        proxy = find_unowned_proxy(pair, owned) or ensure_proxy(pair)
        if valid(proxy) then pair.proxy = proxy; if proxy.unit_number then owned[proxy.unit_number] = true end end
      end
      if valid(proxy) then
        local attached = proxy.surface == pair.priest.surface and distance_sq(proxy.position, pair.priest.position) <= M.max_attached_distance_sq
        if not attached then
          if M.align_to_priest(pair, proxy, pair.priest, "proxy-heartbeat-0555-reattach") then
            repaired = repaired + 1
            pcall(function() proxy.shooting_target = nil end)
            pair.proxy_expires = math.max(pair.proxy_expires or 0, now() + 180)
          else
            blocked = blocked + 1
            pcall(function() proxy.destroy({ raise_destroy = false }) end)
            pair.proxy = nil
            ensure_proxy(pair)
          end
        end
      else
        blocked = blocked + 1
      end
    end
  end
  root.stats.heartbeat_processed = (root.stats.heartbeat_processed or 0) + processed
  root.stats.heartbeat_repaired = (root.stats.heartbeat_repaired or 0) + repaired
  root.stats.heartbeat_blocked = (root.stats.heartbeat_blocked or 0) + blocked
  return { processed = processed, acted = repaired, blocked = blocked, exhausted = processed >= limit, detail = "proxy-heartbeat" }
end

function M.combat_sustain_service(_, budget)
  local root = state()
  local processed, acted, blocked = 0, 0, 0
  local limit = math.max(1, math.min(32, math.floor(tonumber(budget) or M.combat_sustain_budget)))
  for _, pair in pairs(pair_map()) do
    if processed >= limit then break end
    if pair and valid(pair.priest) and valid(pair.station) then
      processed = processed + 1
      local target = current_target(pair)
      if target and hostile(pair, target) then
        local proxy = ensure_proxy(pair)
        if valid(proxy) then
          if now() >= (pair.next_proxy_alignment_tick_0430 or 0) then
            pair.next_proxy_alignment_tick_0430 = now() + M.alignment_hold_ticks
            M.align_to_priest(pair, proxy, pair.priest, "combat-proxy-sustain-0430")
          end
          pcall(function() proxy.active = true end)
          pcall(function() proxy.operable = false end)
          pcall(function() proxy.destructible = false end)
          pcall(function() proxy.shooting_target = target end)
          pair.proxy_expires = math.max(pair.proxy_expires or 0, now() + 180)
          pair.last_proxy_combat_sustain_0430 = { tick = now(), target_unit = target.unit_number or 0 }
          acted = acted + 1
        else
          blocked = blocked + 1
        end
      end
    end
  end
  root.stats.combat_processed = (root.stats.combat_processed or 0) + processed
  root.stats.combat_acted = (root.stats.combat_acted or 0) + acted
  root.stats.combat_blocked = (root.stats.combat_blocked or 0) + blocked
  return { processed = processed, acted = acted, blocked = blocked, exhausted = processed >= limit, detail = "combat-proxy-sustain" }
end

function M.install()
  if M._installed then return true end
  state()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not broker then pcall(function() broker = require("scripts.core.runtime_tick_broker") end) end
  if not (broker and type(broker.register_service) == "function") then return false end
  local heartbeat = broker.register_service({
    name = "proxy_turret_alignment_0555", category = "recovery", interval = M.heartbeat_interval,
    priority = 42, budget = M.heartbeat_budget, fn = M.heartbeat_service,
    note = "canonical hidden-proxy identity and physical reattachment",
  })
  local combat = broker.register_service({
    name = "combat_proxy_sustain_0472", category = "combat", interval = M.combat_sustain_interval,
    priority = 48, budget = M.combat_sustain_budget, fn = M.combat_sustain_service,
    note = "canonical hidden-proxy target sustain without visible movement ownership",
  })
  if not (heartbeat and combat) then return false end
  _G.tech_priests_align_proxy_to_priest_0430 = M.align_to_priest
  _G.tech_priests_proxy_alignment_summary_0430 = M.describe
  _G.tech_priests_proxy_alignment_heartbeat_0555 = function(event) return M.heartbeat_service(event, M.heartbeat_budget) end
  _G.TECH_PRIESTS_PROXY_TURRET_ALIGNMENT_0430 = M
  M._installed = true
  if log then log("[Tech-Priests 0.1.674-dev] broker-owned hidden-proxy alignment and combat sustain installed") end
  return true
end

return M
'''
write("tech-priests_src/scripts/core/proxy_turret_alignment.lua", proxy_source)

# 6. Retire 0472 and remove its loader; explicitly install proxy alignment after the broker.
write(
    "tech-priests_src/scripts/core/combat_magos_movement_authority_0472.lua",
    '''-- scripts/core/combat_magos_movement_authority_0472.lua
-- Source-preserved retirement marker. Useful territory, combat throttle, and
-- hidden-proxy sustain rules now live in command_hierarchy_0480,
-- movement_controller, behavior_mutex_0466, and proxy_turret_alignment.
local M = {
  retired = true,
  authority = "combat_magos_movement_authority_0472",
  replacement = "command_hierarchy_0480 + movement_controller + behavior_mutex_0466 + proxy_turret_alignment",
}
return M
''',
)
path = "tech-priests_src/control.lua"
text = read(path)
old_broker = '''pcall(function()
  local RuntimeBroker0600 = require("scripts.core.runtime_tick_broker")
  if RuntimeBroker0600 and RuntimeBroker0600.install then RuntimeBroker0600.install() end
end)
'''
new_broker = old_broker + '''
pcall(function()
  local ProxyAlignment0430 = require("scripts.core.proxy_turret_alignment")
  if ProxyAlignment0430 and ProxyAlignment0430.install then ProxyAlignment0430.install() end
end)
'''
if old_broker not in text:
    raise SystemExit("control broker install anchor missing")
text = text.replace(old_broker, new_broker, 1)
old_0472 = '''-- 0.1.472: Planetary Magos may treat subordinate station operating areas as
-- command territory.  Point-blank combat/proxy-turret service is staged and
-- cooled down so damage/contact pressure cannot create command-loop stalls.
pcall(function()
  local Authority0472 = require("scripts.core.combat_magos_movement_authority_0472")
  if Authority0472 and Authority0472.install then Authority0472.install() end
end)

'''
if old_0472 not in text:
    raise SystemExit("control 0472 loader anchor missing")
text = text.replace(old_0472, '-- Historical 0472 wrapper is retired; its policies are integrated into canonical owners.\n\n', 1)
write(path, text)

# 7. Declarative graph and integration contracts become 26 active / 31 retired.
path = "tech-priests_src/scripts/core/planning_constraints_0646.lua"
text = read(path)
text = text.replace('active_hardener_count=26,retired_authority_count=30', 'active_hardener_count=26,retired_authority_count=31', 1)
anchor = ' ["scripts.core.movement_cadence_contract_0518"]="cadence and long-action leases are consolidated into movement_controller",'
entry = anchor + '\n ["scripts.core.combat_magos_movement_authority_0472"]="territory, combat throttling, and proxy sustain are integrated into canonical command, movement, mutex, and proxy owners",'
if anchor not in text:
    raise SystemExit("planning retired 0518 anchor missing")
text = text.replace(anchor, entry, 1)
write(path, text)

path = "tools/check_development_integration_0732.py"
text = read(path)
text = text.replace('    "scripts.core.movement_cadence_contract_0518",', '    "scripts.core.movement_cadence_contract_0518",\n    "scripts.core.combat_magos_movement_authority_0472",', 1)
text = text.replace('"retired_authority_count=30"', '"retired_authority_count=31"', 1)
text = text.replace(
    '"development_lifecycle_checkpoint_0733", "combat_proxy_sustain_0472",',
    '"development_lifecycle_checkpoint_0733", "combat_proxy_sustain_0472",\n    "proxy_turret_alignment_0555", "command_hierarchy_rebuild_0480",',
    1,
)
write(path, text)

path = "tools/check_recovery_architecture_0744.py"
text = read(path)
text = text.replace('"scripts.core.machine_logistics_final_authority_0684", "scripts.core.movement_cadence_contract_0518",', '"scripts.core.machine_logistics_final_authority_0684", "scripts.core.movement_cadence_contract_0518", "scripts.core.combat_magos_movement_authority_0472",', 1)
text = text.replace('"retired_authority_count=30"', '"retired_authority_count=31"', 1)
text = text.replace('"30 source-preserved authorities"', '"31 source-preserved authorities"', 1)
text = text.replace('"26 active hardeners and 30 explicitly retired"', '"26 active hardeners and 31 explicitly retired"', 1)
text = text.replace('active=26 retired=30 construction=canonical', 'active=26 retired=31 construction=canonical', 1)
write(path, text)

path = "tools/check_governance_prerequisites_0738.py"
text = read(path)
for old, new in (
    ('26-active / 30-retired graph', '26-active / 31-retired graph'),
    ('26 active hardeners and 30 explicitly retired', '26 active hardeners and 31 explicitly retired'),
    ('26 active hardeners and 30 retired source-only authorities', '26 active hardeners and 31 retired source-only authorities'),
    ('30 source-preserved authorities', '31 source-preserved authorities'),
    ('30 retired source-only authorities', '31 retired source-only authorities'),
    ('Thirty files remain', 'Thirty-one files remain'),
    ('Audit bounded combat proxy ownership', 'Audit consolidated combat proxy ownership'),
):
    text = text.replace(old, new)
write(path, text)

# 8. Focused 0762 checker now proves complete retirement and canonical integration.
write(
    "tools/check_combat_proxy_boundary_0762.py",
    '''#!/usr/bin/env python3
"""Validate complete 0472 retirement and canonical combat-proxy ownership."""
from __future__ import annotations
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "retired": ROOT / "tech-priests_src/scripts/core/combat_magos_movement_authority_0472.lua",
    "control": ROOT / "tech-priests_src/control.lua",
    "hierarchy": ROOT / "tech-priests_src/scripts/core/command_hierarchy_0480.lua",
    "radar": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_017.lua",
    "movement": ROOT / "tech-priests_src/scripts/core/movement_controller.lua",
    "mutex": ROOT / "tech-priests_src/scripts/core/behavior_mutex_0466.lua",
    "proxy": ROOT / "tech-priests_src/scripts/core/proxy_turret_alignment.lua",
    "planning": ROOT / "tech-priests_src/scripts/core/planning_constraints_0646.lua",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
}
REQUIRED = {
    "retired": ('retired = true', 'authority = "combat_magos_movement_authority_0472"', 'return M'),
    "control": ('Historical 0472 wrapper is retired', 'require("scripts.core.proxy_turret_alignment")'),
    "hierarchy": ('M.position_authority_integrated = true', 'function M.position_in_authority', 'name = "command_hierarchy_rebuild_0480"', 'broker.register_service', '_G.tech_priests_0480_position_in_authority'),
    "radar": ('rawget(_G, "tech_priests_0480_position_in_authority")',),
    "movement": ('M.proxy_prime_throttle_integrated = true', 'local function proxy_prime_allowed', 'pair.next_proxy_prime_tick_0419', 'proxy_prime_allowed(pair, target)'),
    "mutex": ('M.force_combat_throttle_integrated = true', 'M.combat_force_cooldown_ticks = 12', 'pair.next_combat_force_tick_0466', 'force_phase(pair)'),
    "proxy": ('combat_sustain_integrated = true', 'name = "proxy_turret_alignment_0555"', 'name = "combat_proxy_sustain_0472"', 'function M.combat_sustain_service', 'broker.register_service'),
    "planning": ('retired_authority_count=31', '["scripts.core.combat_magos_movement_authority_0472"]'),
    "workflow": ('Audit consolidated combat proxy ownership', 'check_combat_proxy_boundary_0762.py'),
}
FORBIDDEN = {
    "retired": ('function M.install', 'register_service', 'on_nth_tick', 'commands.add_command', 'tech_priests_request_movement_0418', 'issue_priest_command', 'pair.target', 'pair.mode'),
    "control": ('require("scripts.core.combat_magos_movement_authority_0472")',),
    "hierarchy": ('patch_magos_authority', 'combat_magos_movement_authority_0472', 'TechPriestsRuntimeEventRegistry', 'registry.on_nth_tick', 'script.on_nth_tick'),
    "proxy": ('TechPriestsRuntimeEventRegistry', 'registry.on_nth_tick', 'script.on_nth_tick', 'pair.target =', 'pair.mode =', 'pair.task_kind ='),
}

def main() -> int:
    errors: list[str] = []
    texts = {}
    for name, path in FILES.items():
        if not path.is_file():
            errors.append(f"missing required file: {path.relative_to(ROOT)}")
            texts[name] = ""
        else:
            texts[name] = path.read_text(encoding="utf-8", errors="replace")
    for name, fragments in REQUIRED.items():
        for fragment in fragments:
            if fragment not in texts[name]: errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {fragment}")
    for name, fragments in FORBIDDEN.items():
        for fragment in fragments:
            if fragment in texts[name]: errors.append(f"{FILES[name].relative_to(ROOT)} contains forbidden regression: {fragment}")
    if errors:
        print("Combat proxy boundary audit failed:", file=sys.stderr)
        for error in errors: print("  - " + error, file=sys.stderr)
        return 1
    print("Combat proxy boundary audit passed: 0472 is inert; command territory, prime throttling, force throttling, and proxy sustain belong to canonical owners.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
''',
)

# 9. Current recovery records reflect 31 retired authorities and canonical ownership.
path = "RECOVERY_REPAIR_SEQUENCE.md"
text = read(path).replace('26-active / 30-retired graph', '26-active / 31-retired graph')
write(path, text)

path = "tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md"
text = read(path)
text = text.replace('The `RETIRED` table contains **30 source-preserved authorities**.', 'The `RETIRED` table contains **31 source-preserved authorities**.', 1)
text = text.replace('- `movement_cadence_contract_0518.lua`;', '- `movement_cadence_contract_0518.lua`;\n- `combat_magos_movement_authority_0472.lua`;', 1)
section = '''## Combat proxy and command-territory authority

`command_hierarchy_0480.lua` owns direct-subordinate topology and native command-territory membership. The legacy radar function reads that authority directly. `movement_controller.lua` owns proxy-prime throttling and visible combat positioning. `behavior_mutex_0466.lua` owns force-combat cooldown and staggering. `proxy_turret_alignment.lua` owns hidden-proxy identity, physical alignment, attachment recovery, and broker-driven target sustain.

`combat_magos_movement_authority_0472.lua` is retired and inert. It may not wrap radar, movement, combat entry points, visible commands, diagnostics, or timers.

'''
if '## Combat proxy and command-territory authority' not in text:
    anchor = '## Construction placement authority'
    if anchor not in text: raise SystemExit('continuity construction anchor missing')
    text = text.replace(anchor, section + anchor, 1)
write(path, text)

path = "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
text = read(path)
text = text.replace('26 active hardeners and 30 retired source-only authorities', '26 active hardeners and 31 retired source-only authorities', 1)
old_bullet = '- broker-owned hidden-proxy sustain in `combat_magos_movement_authority_0472`, with its movement-request override, visible-command interception, registry timer, and direct timer removed; remaining radar and legacy-combat wrappers are still open for direct integration;\n'
new_bullet = '- canonical command territory in `command_hierarchy_0480`, proxy-prime throttling in `movement_controller`, force-combat throttling in `behavior_mutex_0466`, and broker-owned hidden-proxy alignment/sustain in `proxy_turret_alignment`; the `0472` wrapper is retired;\n'
if old_bullet not in text: raise SystemExit('testing transitional 0472 bullet missing')
text = text.replace(old_bullet, new_bullet, 1)
text = text.replace('movement-cadence and bounded combat-proxy boundary audits;', 'movement-cadence and consolidated combat-proxy boundary audits;', 1)
text = text.replace('26 attempted active hardeners and 30 retired source-only authorities', '26 attempted active hardeners and 31 retired source-only authorities', 1)
write(path, text)

path = "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
text = read(path)
text = text.replace('**30 retired source-only authorities**', '**31 retired source-only authorities**', 1)
text = text.replace('Planning --> Retired[30 retired authorities]', 'Planning --> Retired[31 retired authorities]', 1)
old_section_pattern = r'## Transitional Combat Proxy Boundary\n.*?\n## Construction Placement and Physical Execution'
new_section = '''## Canonical Combat Proxy and Command Territory

```mermaid
flowchart LR
    Hierarchy[command_hierarchy_0480] --> Territory[primary and direct-subordinate territory]
    Territory --> Radar[legacy radar membership]
    Prime[legacy proxy-prime entry] --> Movement[movement_controller throttle and combat intent]
    Force[legacy force-combat entry] --> Mutex[behavior_mutex_0466 throttle]
    Broker[runtime_tick_broker] --> Proxy[proxy_turret_alignment]
    Proxy --> Hidden[hidden proxy alignment and target sustain]
```

`0472` is retired. Command hierarchy owns subordinate topology and territory; movement owns proxy-prime cadence and visible positioning; the behavior mutex owns force-combat cadence; proxy alignment owns the hidden entity and its two broker services. None of these canonical owners uses a registry or direct-timer fallback.

## Construction Placement and Physical Execution'''
text, count = re.subn(old_section_pattern, new_section, text, count=1, flags=re.DOTALL)
if count != 1: raise SystemExit(f'authority map transitional section replacement count={count}')
text = text.replace('Thirty files remain source-preserved', 'Thirty-one files remain source-preserved', 1)
write(path, text)

path = "docs/DEVELOPMENT_HISTORY.md"
text = read(path)
section = '''### Retired `0472` and consolidated combat proxy ownership

The remaining `combat_magos_movement_authority_0472` wrappers were removed rather than preserved as another compatibility layer. Direct-subordinate territory is now native to `command_hierarchy_0480` and is read directly by the legacy radar membership function. Proxy-prime cooldown belongs to the existing `movement_controller` wrapper, force-combat cooldown and staggering belong to the existing `behavior_mutex_0466` wrapper, and hidden-proxy identity, alignment, attachment recovery, and target sustain belong to `proxy_turret_alignment` through broker services.

`command_hierarchy_0480` and `proxy_turret_alignment` no longer retain registry or direct `script.on_nth_tick` fallbacks. `combat_magos_movement_authority_0472.lua` is source-preserved but inert and is no longer loaded by `control.lua`. The declarative graph is now **26 active hardeners and 31 explicitly retired source-only authorities**.

This is source implementation only. A complete Source validation result is required for the exact changed SHA; Factorio load, migration, save/reload, behavioral, profiler, package, and release evidence remain open.

'''
if '### Retired `0472` and consolidated combat proxy ownership' not in text:
    anchor = '## Current Gate State'
    if anchor not in text: raise SystemExit('history current gate anchor missing')
    text = text.replace(anchor, section + anchor, 1)
write(path, text)

Path(__file__).unlink()
