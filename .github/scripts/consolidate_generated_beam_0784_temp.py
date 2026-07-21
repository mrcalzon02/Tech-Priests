#!/usr/bin/env python3
"""Temporary guarded source transformation for milestone 0784."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GENERATED = ROOT / "tech-priests_src/scripts/generated"
PART5_PATH = GENERATED / "control_legacy_part_005.lua"
PART8_PATH = GENERATED / "control_legacy_part_008.lua"
PART21_PATH = GENERATED / "control_legacy_part_021.lua"
PART22_PATH = GENERATED / "control_legacy_part_022.lua"
SAFETY_PATH = ROOT / "tech-priests_src/scripts/core/combat_safety.lua"
CLEANUP_PATH = ROOT / "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua"
HISTORY_PATH = ROOT / "docs/DEVELOPMENT_HISTORY.md"
LUA_PATHS = sorted((ROOT / "tech-priests_src").rglob("*.lua"))


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one exact source block, found {count}")
    return text.replace(old, new, 1)


all_before = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in LUA_PATHS)
pre_counts = {
    "function draw_emergency_craft_scan_line(pair, target_entity)": 3,
    "function tech_priests_0312_fire_laser(priest, target, damage, reason, color)": 3,
    "function tech_priests_0312_service_direct_current(pair, task)": 1,
    "function tech_priests_0315_service_direct_current(pair, task)": 2,
}
for needle, expected in pre_counts.items():
    actual = all_before.count(needle)
    if actual != expected:
        raise SystemExit(f"pre-patch ownership mismatch: {needle!r} expected {expected}, found {actual}")

# ---------------------------------------------------------------------------
# Fragment 005: original scan-line owner absorbs 0177 audio and 0315 suppression.
# ---------------------------------------------------------------------------
part5 = PART5_PATH.read_text(encoding="utf-8")
scan_signature = "function draw_emergency_craft_scan_line(pair, target_entity)"
scan_prefix = '''function draw_emergency_craft_scan_line(pair, target_entity)
  -- 0.1.674-dev / 0784: the original scan-line owner now owns the final policy.
  local task_0784 = pair and pair.emergency_craft or nil
  local current_0784 = task_0784 and task_0784.current or nil
  if current_0784 and (current_0784.kind == "direct-mine-0273" or current_0784.kind == "direct-dirt-0273") then
    return nil
  end
  if target_entity and target_entity.valid and target_entity.type == "item-entity" then
    return nil
  end
  if tech_priests_play_task_sound_0177 and current_0784 then
    local key_0784 = tostring(current_0784.kind or "?") .. ":" .. tostring(current_0784.unit_number or (current_0784.entity and current_0784.entity.unit_number) or "?") .. ":" .. tostring(current_0784.item_name or "?")
    if task_0784.sound_current_key_0177 ~= key_0784 then
      task_0784.sound_current_key_0177 = key_0784
      local sound_key_0784 = current_0784.kind == "inventory" and "emergency_scan_inventory" or "emergency_scan_field"
      tech_priests_play_task_sound_0177(pair, sound_key_0784, target_entity and target_entity.position or nil, TECH_PRIESTS_TASK_SOUND_FAST_COOLDOWN_TICKS_0177, current_0784.kind == "inventory" and 0.32 or 0.42)
    end
  end'''
if part5.count(scan_signature) != 1 or "task_0784.sound_current_key_0177" in part5:
    raise SystemExit("fragment 005 scan-line source does not match the expected pre-0784 shape")
part5 = part5.replace(scan_signature, scan_prefix, 1)
PART5_PATH.write_text(part5, encoding="utf-8")

# Fragment 008: retire the audio-only scan wrapper.
part8 = PART8_PATH.read_text(encoding="utf-8")
old_sound_wrapper = '''tech_priests_original_draw_emergency_craft_scan_line_0177 = draw_emergency_craft_scan_line
function draw_emergency_craft_scan_line(pair, target_entity)
  local result = tech_priests_original_draw_emergency_craft_scan_line_0177(pair, target_entity)
  if pair and pair.emergency_craft and pair.emergency_craft.current then
    local candidate = pair.emergency_craft.current
    local key = tostring(candidate.kind or "?") .. ":" .. tostring(candidate.unit_number or (candidate.entity and candidate.entity.unit_number) or "?") .. ":" .. tostring(candidate.item_name or "?")
    if pair.emergency_craft.sound_current_key_0177 ~= key then
      pair.emergency_craft.sound_current_key_0177 = key
      local sound_key = candidate.kind == "inventory" and "emergency_scan_inventory" or "emergency_scan_field"
      tech_priests_play_task_sound_0177(pair, sound_key, target_entity and target_entity.position or nil, TECH_PRIESTS_TASK_SOUND_FAST_COOLDOWN_TICKS_0177, candidate.kind == "inventory" and 0.32 or 0.42)
    end
  end
  return result
end'''
part8 = replace_once(
    part8,
    old_sound_wrapper,
    '''-- 0.1.674-dev / 0784: scan audio is integrated into the original visual owner.
TECH_PRIESTS_0177_SCAN_LINE_SOUND_WRAPPER_RETIRED = true''',
    "fragment 008 scan audio wrapper",
)
PART8_PATH.write_text(part8, encoding="utf-8")

# ---------------------------------------------------------------------------
# Fragment 021: canonical beam and direct-extraction service.
# ---------------------------------------------------------------------------
part21 = PART21_PATH.read_text(encoding="utf-8")
old_canonical_beam = '''function tech_priests_0312_fire_laser(priest, target, damage, reason, color)
  if not (priest and priest.valid and target and target.valid) then return false end
  damage = math.max(1, damage or TECH_PRIESTS_0312_MINING_LASER_DAMAGE)
  color = color or { r = 0.95, g = 0.25, b = 0.05, a = 0.75 }
  local ok_damage = pcall(function()
    if target.valid and target.health and target.health > 0 then
      target.damage(damage, priest.force, "laser", priest)
    elseif target.valid and target.type == "resource" then
      local amount = target.amount or 0
      if amount > 1 then target.amount = math.max(1, amount - damage) end
    end
  end)
  if rendering then
    pcall(function()
      rendering.draw_line({ color = color, width = 2, from = priest.position, to = target.position, surface = priest.surface, time_to_live = 12, forces = { priest.force } })
    end)
    pcall(function()
      rendering.draw_circle({ color = { r = color.r or 1, g = color.g or 0.5, b = color.b or 0.1, a = 0.18 }, radius = 0.35, width = 1, filled = true, target = target, surface = priest.surface, time_to_live = 8, forces = { priest.force } })
    end)
  end
  if spawn_emergency_craft_smoke then
    pcall(function() spawn_emergency_craft_smoke({ priest = priest, station = nil }, target.position, false) end)
  elseif priest.surface and priest.surface.create_trivial_smoke then
    pcall(function() priest.surface.create_trivial_smoke({ name = "smoke-fast", position = target.position }) end)
  end
  return ok_damage
end'''
canonical_beam = '''function tech_priests_0312_beam_origin(priest)
  return { entity = priest, offset = TECH_PRIEST_SCAN_ORIGIN_OFFSET or { 0, -1.35 } }
end

function tech_priests_0312_beam_target_position(target)
  if target and target.valid and target.position then return target.position end
  return target
end

function tech_priests_0312_effective_beam_profile(force)
  if tech_priests_0313_force_upgrade_profile then
    local ok, profile = pcall(function() return tech_priests_0313_force_upgrade_profile(force) end)
    if ok and profile then return profile end
  end
  return {
    mining_laser_damage = TECH_PRIESTS_0312_MINING_LASER_DAMAGE or 5,
    mining_laser_ticks = TECH_PRIESTS_0315_MINING_PULSE_TICKS or 5,
    mining_pulse_smoke = 2,
  }
end

function tech_priests_0312_fire_laser(priest, target, damage, reason, color)
  if not (priest and priest.valid and target and target.valid) then return false end
  if tech_priests_0322_is_laser_target_allowed then
    local ok, allowed = pcall(function() return tech_priests_0322_is_laser_target_allowed(priest, target, reason) end)
    if not (ok and allowed) then return false end
  end
  if target.type == "item-entity" then return false end
  local pos = tech_priests_0312_beam_target_position(target)
  if not pos then return false end
  local force = priest.force
  local profile = tech_priests_0312_effective_beam_profile(force)
  local d = math.max(1, damage or profile.mining_laser_damage or 5)
  color = color or { r = 1.0, g = 0.25, b = 0.05, a = 0.68 }

  local ok_damage = true
  pcall(function()
    if target.valid and target.type == "resource" then
      local amount = target.amount or 0
      if amount and amount > 1 then target.amount = math.max(1, amount - math.max(1, math.floor(d * 0.35))) end
    elseif target.valid and target.health and target.health > 0 then
      target.damage(d, force, "laser", priest)
    end
  end)

  if rendering and rendering.draw_line then
    pcall(function()
      rendering.draw_line({
        color = color,
        width = TECH_PRIESTS_0315_BEAM_WIDTH or 2,
        from = tech_priests_0312_beam_origin(priest),
        to = pos,
        surface = priest.surface,
        time_to_live = 7,
        forces = { force },
      })
    end)
    pcall(function()
      rendering.draw_circle({
        color = { r = color.r or 1, g = color.g or 0.4, b = color.b or 0.05, a = 0.24 },
        radius = 0.22,
        width = 1,
        filled = true,
        target = target,
        surface = priest.surface,
        time_to_live = 6,
        forces = { force },
      })
    end)
  end

  local smoke_count = math.max(2, profile.mining_pulse_smoke or 2)
  for i = 1, smoke_count do
    pcall(function()
      priest.surface.create_trivial_smoke({
        name = "smoke-fast",
        position = { x = pos.x + (i - 1.5) * 0.07, y = pos.y + ((i % 2) - 0.5) * 0.08 },
      })
    end)
  end
  pcall(function() priest.surface.create_entity({ name = "spark-explosion", position = pos }) end)
  return ok_damage
end'''
part21 = replace_once(part21, old_canonical_beam, canonical_beam, "canonical 0312 beam")

old_canonical_service = '''function tech_priests_0312_service_direct_current(pair, task)
  local cur = task and task.current or nil
  if not cur then return false end
  if cur.kind ~= "direct-mine-0273" and cur.kind ~= "direct-dirt-0273" then return false end
  if not tech_priests_0312_valid_pair(pair) then return false end
  local priest = pair.priest
  local pos = cur.position or (cur.entity and cur.entity.valid and cur.entity.position) or pair.station.position
  local dx = priest.position.x - pos.x
  local dy = priest.position.y - pos.y
  if dx * dx + dy * dy > (EMERGENCY_CRAFT_PICKUP_DISTANCE_SQ or 2.25) then
    pcall(function()
      if tech_priests_request_movement_0418 then
        tech_priests_request_movement_0418(pair, pos, "legacy-direct-gather-0312", { radius = 0.75, owner = "direct-gather-0312", priority = 55, distraction = defines.distraction.by_enemy })
      else
        priest.set_command({ type = defines.command.go_to_location, destination = pos, radius = 0.75, distraction = defines.distraction.by_enemy })
      end
    end)
    pair.mode = cur.kind == "direct-dirt-0273" and "emergency-dirt-scraping" or "emergency-gathering"
    return true
  end
  if not task.direct_due_tick_0312 then
    task.direct_due_tick_0312 = (game and game.tick or 0) + (TECH_PRIESTS_DIRECT_GATHER_TICKS_0273 or 60)
    task.direct_due_tick_0273 = task.direct_due_tick_0312
  end
  pair.mode = cur.kind == "direct-dirt-0273" and "emergency-dirt-scraping" or "emergency-gathering"

  local tick = game and game.tick or 0
  if cur.entity and cur.entity.valid then
    if draw_emergency_craft_scan_line then pcall(function() draw_emergency_craft_scan_line(pair, cur.entity) end) end
    if tick >= (task.next_direct_laser_tick_0312 or 0) then
      task.next_direct_laser_tick_0312 = tick + TECH_PRIESTS_0312_MINING_LASER_TICKS
      tech_priests_0312_fire_laser(priest, cur.entity, TECH_PRIESTS_0312_MINING_LASER_DAMAGE, "direct-mining", { r = 1.0, g = 0.45, b = 0.05, a = 0.75 })
    end
  elseif cur.position and spawn_emergency_craft_smoke and tick >= (task.next_direct_laser_tick_0312 or 0) then
    task.next_direct_laser_tick_0312 = tick + TECH_PRIESTS_0312_MINING_LASER_TICKS
    pcall(function() spawn_emergency_craft_smoke(pair, cur.position, false) end)
  end

  if tick < (task.direct_due_tick_0312 or task.direct_due_tick_0273 or tick) then return true end

  -- Final extraction: the laser does a slightly heavier finishing cut and then
  -- the existing emergency craft doctrine receives one unit of the requested output.
  if cur.entity and cur.entity.valid then
    local e = cur.entity
    tech_priests_0312_fire_laser(priest, e, math.max(10, TECH_PRIESTS_0312_MINING_LASER_DAMAGE * 3), "direct-mining-final", { r = 1.0, g = 0.65, b = 0.1, a = 0.95 })
    pcall(function()
      if e.valid and e.type == "resource" then
        local amount = e.amount or 0
        if amount > 1 then e.amount = math.max(1, amount - 25) else e.destroy() end
      elseif e.valid and e.health and e.health <= 1 then
        e.destroy()
      end
    end)
  end

  local output = cur.output_item or (tech_priests_0273_output_from_task and tech_priests_0273_output_from_task(task)) or task.item_name or task.output_item or "stone"
  if not tech_priests_0312_item_exists(output) then output = "stone" end
  if tech_priests_0273_deposit then
    pcall(function() tech_priests_0273_deposit(pair, output, 1) end)
  else
    local inv = get_station_inventory and get_station_inventory(pair.station) or pair.station.get_inventory(defines.inventory.chest)
    if inv and inv.can_insert({ name = output, count = 1 }) then inv.insert({ name = output, count = 1 }) end
  end
  pair.last_direct_mining_laser_0312 = { tick = tick, output = output, source = cur.item_name or (cur.entity and cur.entity.name) or cur.kind }
  pair.emergency_craft = nil
  pair.mode = "returning"
  pair.target = nil
  if return_to_station then pcall(function() return_to_station(priest, pair.station) end) end
  return true
end'''
canonical_service = '''function tech_priests_0312_insert_loose_item(pair, item_entity)
  if not (pair and pair.station and pair.station.valid and item_entity and item_entity.valid and item_entity.type == "item-entity") then return false end
  local stack = nil
  local ok_stack = pcall(function() stack = item_entity.stack end)
  if not (ok_stack and stack and stack.valid_for_read) then return false end
  local inv = get_station_inventory and get_station_inventory(pair.station) or nil
  if not inv then return false end
  local inserted = 0
  pcall(function() inserted = inv.insert(stack) end)
  if inserted and inserted > 0 then
    if inserted >= stack.count then
      pcall(function() item_entity.destroy() end)
    else
      pcall(function() stack.count = stack.count - inserted end)
    end
    pair.last_ground_pickup_0315 = { tick = game and game.tick or 0, item = stack.name, count = inserted }
    return true
  end
  return false
end

function tech_priests_0312_stop_for_mining(pair)
  if not tech_priests_0312_valid_pair(pair) then return end
  local tick = game and game.tick or 0
  if tick < (pair.next_mining_stop_command_0315 or 0) then return end
  pair.next_mining_stop_command_0315 = tick + 30
  if tech_priests_stop_movement_0418 then
    pcall(function() tech_priests_stop_movement_0418(pair, "mining-work-clamp-0315") end)
  else
    pcall(function() pair.priest.set_command({ type = defines.command.stop }) end)
  end
end

function tech_priests_0312_is_hostile_nearby(pair, radius)
  if not tech_priests_0312_valid_pair(pair) then return false end
  local priest = pair.priest
  local found = nil
  local ok = pcall(function()
    found = priest.surface.find_entities_filtered({
      position = priest.position,
      radius = radius or TECH_PRIESTS_0315_INTERRUPT_RADIUS or 2.25,
      type = { "unit", "spider-unit", "spider-vehicle" },
      limit = 32,
    })
  end)
  if not (ok and found) then return false end
  for _, entity in pairs(found) do
    if entity and entity.valid and entity.force and priest.force and entity.force ~= priest.force then
      local hostile = false
      pcall(function() hostile = priest.force.is_enemy and priest.force.is_enemy(entity.force) end)
      if hostile or entity.force ~= priest.force then return true end
    end
  end
  return false
end

function tech_priests_0312_service_direct_current(pair, task)
  local cur = task and task.current or nil
  if not cur then return false end
  if cur.kind ~= "direct-mine-0273" and cur.kind ~= "direct-dirt-0273" then return false end
  if not tech_priests_0312_valid_pair(pair) then return false end
  if tech_priests_0322_validate_direct_mining_current then
    local ok, allowed = pcall(function() return tech_priests_0322_validate_direct_mining_current(pair, task) end)
    if not (ok and allowed) then return false end
  end

  if cur.entity and cur.entity.valid and cur.entity.type == "item-entity" then
    return tech_priests_0312_insert_loose_item(pair, cur.entity)
  end

  if tech_priests_0312_is_hostile_nearby(pair, TECH_PRIESTS_0315_INTERRUPT_RADIUS or 2.25) then
    pair.mining_lock_0315 = nil
    return false
  end

  local priest = pair.priest
  local pos = cur.position or (cur.entity and cur.entity.valid and cur.entity.position) or pair.station.position
  local dx = priest.position.x - pos.x
  local dy = priest.position.y - pos.y
  local dist2 = dx * dx + dy * dy
  local lock_radius_sq = TECH_PRIESTS_0315_MINING_LOCK_RADIUS_SQ or 2.25

  if dist2 > lock_radius_sq then
    if (game and game.tick or 0) >= (pair.next_mining_move_command_0315 or 0) then
      pair.next_mining_move_command_0315 = (game and game.tick or 0) + 30
      pcall(function()
        if tech_priests_request_movement_0418 then
          tech_priests_request_movement_0418(pair, pos, "legacy-direct-gather-0315", { radius = 0.65, owner = "direct-gather-0315", priority = 55, distraction = defines.distraction.by_enemy })
        else
          priest.set_command({ type = defines.command.go_to_location, destination = pos, radius = 0.65, distraction = defines.distraction.by_enemy })
        end
      end)
    end
    pair.mining_lock_0315 = nil
    pair.mode = cur.kind == "direct-dirt-0273" and "emergency-dirt-scraping" or "emergency-gathering"
    return true
  end

  tech_priests_0312_stop_for_mining(pair)
  pair.mining_lock_0315 = { tick = game and game.tick or 0, x = pos.x, y = pos.y, kind = cur.kind, item = cur.output_item or cur.item_name }
  pair.mode = cur.kind == "direct-dirt-0273" and "emergency-dirt-scraping" or "emergency-gathering"

  local tick = game and game.tick or 0
  if not task.direct_due_tick_0315 then
    task.direct_due_tick_0315 = tick + (TECH_PRIESTS_0315_MINING_FINISH_TICKS or 60)
    task.direct_due_tick_0312 = task.direct_due_tick_0315
    task.direct_due_tick_0273 = task.direct_due_tick_0315
  end

  local profile = tech_priests_0312_effective_beam_profile(priest.force)
  local pulse_limit = TECH_PRIESTS_0315_MINING_PULSE_TICKS or 5
  local pulse_ticks = math.max(3, math.min(pulse_limit, profile.mining_laser_ticks or pulse_limit))
  if cur.entity and cur.entity.valid and tick >= (task.next_direct_laser_tick_0315 or 0) then
    task.next_direct_laser_tick_0315 = tick + pulse_ticks
    tech_priests_0312_fire_laser(priest, cur.entity, profile.mining_laser_damage or 5, "direct-mining", { r = 1.0, g = 0.34, b = 0.04, a = 0.78 })
  elseif cur.position and tick >= (task.next_direct_laser_tick_0315 or 0) then
    task.next_direct_laser_tick_0315 = tick + pulse_ticks
    if spawn_emergency_craft_smoke then pcall(function() spawn_emergency_craft_smoke(pair, cur.position, false) end) end
  end

  if tick < (task.direct_due_tick_0315 or tick) then return true end

  if cur.entity and cur.entity.valid then
    tech_priests_0312_fire_laser(priest, cur.entity, math.max(10, (profile.mining_laser_damage or 5) * 2), "direct-mining-final", { r = 1.0, g = 0.58, b = 0.08, a = 0.92 })
    pcall(function()
      local entity = cur.entity
      if entity.valid and entity.type == "resource" then
        local amount = entity.amount or 0
        if amount > 1 then entity.amount = math.max(1, amount - 25) else entity.destroy() end
      elseif entity.valid and entity.health and entity.health > 0 then
        entity.damage(math.max(25, (profile.mining_laser_damage or 5) * 4), priest.force, "laser", priest)
        if entity.valid and entity.health and entity.health <= 1 then entity.destroy() end
      end
    end)
  end

  local output = cur.output_item or cur.item_name or (task and task.item) or "stone"
  if not (tech_priests_0312_item_exists and tech_priests_0312_item_exists(output)) then output = "stone" end
  local deposited = false
  if tech_priests_0273_deposit then
    local ok, result = pcall(function() return tech_priests_0273_deposit(pair, output, 1) end)
    deposited = ok and result
  end
  if not deposited then
    local inv = get_station_inventory and get_station_inventory(pair.station) or nil
    if inv and inv.can_insert({ name = output, count = 1 }) then pcall(function() inv.insert({ name = output, count = 1 }) end) end
  end

  task.gathered_units = (task.gathered_units or 0) + 1
  task.current = nil
  task.direct_due_tick_0315 = nil
  task.direct_due_tick_0312 = nil
  task.direct_due_tick_0273 = nil
  pair.mining_lock_0315 = nil
  pair.last_direct_mining_laser_0315 = { tick = tick, output = output, source = cur.item_name or (cur.entity and cur.entity.name) or cur.kind }
  return true
end'''
part21 = replace_once(part21, old_canonical_service, canonical_service, "canonical 0312 direct service")

old_valid_pair = '''function tech_priests_0315_valid_pair(pair)
  return pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid
end'''
old_origin = '''function tech_priests_0315_origin(priest)
  return { entity = priest, offset = TECH_PRIEST_SCAN_ORIGIN_OFFSET or { 0, -1.35 } }
end'''
old_target_position = '''function tech_priests_0315_target_position(target)
  if target and target.valid and target.position then return target.position end
  return target
end'''
old_hostile = '''function tech_priests_0315_is_hostile_nearby(pair, radius)
  if not tech_priests_0315_valid_pair(pair) then return false end
  local priest = pair.priest
  local r = radius or TECH_PRIESTS_0315_INTERRUPT_RADIUS
  local found = nil
  local ok = pcall(function()
    found = priest.surface.find_entities_filtered({
      position = priest.position,
      radius = r,
      type = { "unit", "spider-unit", "spider-vehicle" },
      limit = 32
    })
  end)
  if not (ok and found) then return false end
  for _, e in pairs(found) do
    if e and e.valid and e.force and priest.force and e.force ~= priest.force then
      local hostile = false
      pcall(function() hostile = priest.force.is_enemy and priest.force.is_enemy(e.force) end)
      if hostile or e.force ~= priest.force then return true end
    end
  end
  return false
end'''
old_effective = '''function tech_priests_0315_effective_profile(force)
  if tech_priests_0313_force_upgrade_profile then
    local ok, profile = pcall(function() return tech_priests_0313_force_upgrade_profile(force) end)
    if ok and profile then return profile end
  end
  return { mining_laser_damage = TECH_PRIESTS_0312_MINING_LASER_DAMAGE or 5, mining_laser_ticks = TECH_PRIESTS_0315_MINING_PULSE_TICKS, mining_pulse_smoke = 2 }
end'''
old_scan_override = '''TECH_PRIESTS_0315_PRE_DRAW_EMERGENCY_CRAFT_SCAN_LINE = draw_emergency_craft_scan_line
function draw_emergency_craft_scan_line(pair, target_entity)
  local cur = pair and pair.emergency_craft and pair.emergency_craft.current or nil
  if cur and (cur.kind == "direct-mine-0273" or cur.kind == "direct-dirt-0273") then
    return nil
  end
  if target_entity and target_entity.valid and target_entity.type == "item-entity" then
    return nil
  end
  if TECH_PRIESTS_0315_PRE_DRAW_EMERGENCY_CRAFT_SCAN_LINE then
    return TECH_PRIESTS_0315_PRE_DRAW_EMERGENCY_CRAFT_SCAN_LINE(pair, target_entity)
  end
end'''
old_beam_override = '''function tech_priests_0312_fire_laser(priest, target, damage, reason, color)
  if not (priest and priest.valid and target and target.valid) then return false end
  if target.type == "item-entity" then return false end
  local pos = tech_priests_0315_target_position(target)
  if not pos then return false end
  local force = priest.force
  local profile = tech_priests_0315_effective_profile(force)
  local d = math.max(1, damage or profile.mining_laser_damage or 5)
  color = color or { r = 1.0, g = 0.25, b = 0.05, a = 0.68 }

  local ok_damage = true
  pcall(function()
    if target.valid and target.type == "resource" then
      local amount = target.amount or 0
      if amount and amount > 1 then target.amount = math.max(1, amount - math.max(1, math.floor(d * 0.35))) end
    elseif target.valid and target.health and target.health > 0 then
      target.damage(d, force, "laser", priest)
    end
  end)

  if rendering and rendering.draw_line then
    pcall(function()
      rendering.draw_line({
        color = color,
        width = TECH_PRIESTS_0315_BEAM_WIDTH,
        from = tech_priests_0315_origin(priest),
        to = pos,
        surface = priest.surface,
        time_to_live = 7,
        forces = { force }
      })
    end)
    pcall(function()
      rendering.draw_circle({
        color = { r = color.r or 1, g = color.g or 0.4, b = color.b or 0.05, a = 0.24 },
        radius = 0.22,
        width = 1,
        filled = true,
        target = target,
        surface = priest.surface,
        time_to_live = 6,
        forces = { force }
      })
    end)
  end

  local smoke_count = math.max(2, profile.mining_pulse_smoke or 2)
  for i = 1, smoke_count do
    pcall(function()
      priest.surface.create_trivial_smoke({ name = "smoke-fast", position = { x = pos.x + (i - 1.5) * 0.07, y = pos.y + ((i % 2) - 0.5) * 0.08 } })
    end)
  end
  pcall(function() priest.surface.create_entity({ name = "spark-explosion", position = pos }) end)
  return ok_damage
end'''
for old, new, label in (
    (old_valid_pair, "TECH_PRIESTS_0315_VALID_PAIR_HELPER_RETIRED = true", "0315 valid-pair helper"),
    (old_origin, "TECH_PRIESTS_0315_BEAM_ORIGIN_HELPER_RETIRED = true", "0315 beam-origin helper"),
    (old_target_position, "TECH_PRIESTS_0315_BEAM_TARGET_HELPER_RETIRED = true", "0315 beam-target helper"),
    (old_hostile, "TECH_PRIESTS_0315_HOSTILE_NEARBY_HELPER_RETIRED = true", "0315 hostile-nearby helper"),
    (old_effective, "TECH_PRIESTS_0315_BEAM_PROFILE_HELPER_RETIRED = true", "0315 beam-profile helper"),
    (old_scan_override, '''-- 0.1.674-dev / 0784: scan suppression is integrated into fragment 005.
TECH_PRIESTS_0315_SCAN_LINE_OVERRIDE_RETIRED = true''', "0315 scan-line override"),
    (old_beam_override, '''-- 0.1.674-dev / 0784: final beam behavior is integrated into canonical 0312.
TECH_PRIESTS_0315_BEAM_OVERRIDE_RETIRED = true''', "0315 beam override"),
):
    part21 = replace_once(part21, old, new, label)
PART21_PATH.write_text(part21, encoding="utf-8")

# Fragment 022 becomes a retirement ledger plus the unchanged runtime bootstrap.
part22_before = PART22_PATH.read_text(encoding="utf-8")
for required in (
    "function tech_priests_0315_insert_loose_item",
    "function tech_priests_0315_stop_for_mining",
    "function tech_priests_0315_service_direct_current",
    "TECH_PRIESTS_0315_PRE_HANDLE_EMERGENCY_DESPERATION_CRAFT",
    'TechPriestsDebugCommandRegistry.add("tp-mining-0315"',
    'TechPriestsDebugCommandRegistry.add("tp-mining-0316"',
    'TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421 = require("scripts.core.bootstrap_runtime")',
):
    if required not in part22_before:
        raise SystemExit(f"fragment 022 missing expected pre-0784 source: {required}")
part22 = '''-- Auto-split control.lua fragment 022 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.

-- 0.1.674-dev / 0784: the final movement-locked extraction service is integrated
-- directly into canonical 0312 in fragment 021. Save-compatible 0315 state-field
-- names remain in use, but no 0315 function replacement retains runtime ownership.
TECH_PRIESTS_0315_LOOSE_ITEM_HELPER_RETIRED = true
TECH_PRIESTS_0315_STOP_HELPER_RETIRED = true
TECH_PRIESTS_0315_DIRECT_SERVICE_OVERRIDE_RETIRED = true
TECH_PRIESTS_0315_HANDLE_WRAPPER_RETIRED = true
TECH_PRIESTS_0315_DEBUG_COMMAND_RETIRED = true
TECH_PRIESTS_0316_DEBUG_COMMAND_RETIRED = true

if tech_priests_0315_log then
  tech_priests_0315_log("canonical 0312 movement-locked mining beam active; 0315 wrappers retired")
end
if log then log("[Tech-Priests 0.1.316] canonical mining service loaded; local-variable-limit marker retained") end

-- ============================================================================
-- 0.1.421: extracted late runtime installer spine.
-- ============================================================================
-- The 0.1.321+ patch/install chain used to live directly in control.lua.  It is
-- now delegated to scripts.core.bootstrap_runtime so control.lua is not the
-- permanent dumping ground for every new module installer and debug command.
TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421 = require("scripts.core.bootstrap_runtime")
if TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421 and TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421.install then
  TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421.install()
end
TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421 = nil
'''
PART22_PATH.write_text(part22, encoding="utf-8")

# ---------------------------------------------------------------------------
# combat_safety: publish predicates instead of redefining beam/service functions.
# ---------------------------------------------------------------------------
safety = SAFETY_PATH.read_text(encoding="utf-8")
old_safety_wrappers = '''  if tech_priests_0312_fire_laser then
    TECH_PRIESTS_0322_PRE_0312_FIRE_LASER = tech_priests_0312_fire_laser
    function tech_priests_0312_fire_laser(priest, target, damage, reason, color)
      local reason_text = tostring(reason or "")
      local direct = string.find(reason_text, "direct%-mining") or string.find(reason_text, "direct%-dirt") or string.find(reason_text, "mining")
      if direct then
        if not M.is_safe_direct_mining_target(priest, target) then
          log_block(nil, "blocked direct laser against protected target=" .. entity_name(target) .. " force=" .. force_name(target and target.force) .. " reason=" .. reason_text)
          return false
        end
      else
        if not M.is_valid_hostile_target(priest, target) then
          log_block(nil, "blocked combat laser against non-hostile target=" .. entity_name(target) .. " force=" .. force_name(target and target.force) .. " reason=" .. reason_text)
          return false
        end
      end
      return TECH_PRIESTS_0322_PRE_0312_FIRE_LASER(priest, target, damage, reason, color)
    end
  end

  if tech_priests_0315_service_direct_current then
    TECH_PRIESTS_0322_PRE_0315_SERVICE_DIRECT_CURRENT = tech_priests_0315_service_direct_current
    function tech_priests_0315_service_direct_current(pair, task)
      local cur = task and task.current or nil
      if cur and cur.entity and cur.entity.valid and not M.is_safe_direct_mining_target(pair and (pair.priest or pair.station), cur.entity) then
        log_block(pair, "cancelled direct mining current against protected target=" .. entity_name(cur.entity) .. " force=" .. force_name(cur.entity.force))
        task.current = nil
        if pair then pair.mining_lock_0315 = nil end
        return false
      end
      return TECH_PRIESTS_0322_PRE_0315_SERVICE_DIRECT_CURRENT(pair, task)
    end
  end'''
new_safety_predicates = '''  tech_priests_0322_is_laser_target_allowed = function(priest, target, reason)
    local reason_text = tostring(reason or "")
    local direct = string.find(reason_text, "direct%-mining") or string.find(reason_text, "direct%-dirt") or string.find(reason_text, "mining")
    if direct then
      if M.is_safe_direct_mining_target(priest, target) then return true end
      log_block(nil, "blocked direct laser against protected target=" .. entity_name(target) .. " force=" .. force_name(target and target.force) .. " reason=" .. reason_text)
      return false
    end
    if M.is_valid_hostile_target(priest, target) then return true end
    log_block(nil, "blocked combat laser against non-hostile target=" .. entity_name(target) .. " force=" .. force_name(target and target.force) .. " reason=" .. reason_text)
    return false
  end

  tech_priests_0322_validate_direct_mining_current = function(pair, task)
    local cur = task and task.current or nil
    if not (cur and cur.entity and cur.entity.valid) then return true end
    if cur.entity.type == "item-entity" then return true end
    if M.is_safe_direct_mining_target(pair and (pair.priest or pair.station), cur.entity) then return true end
    log_block(pair, "cancelled direct mining current against protected target=" .. entity_name(cur.entity) .. " force=" .. force_name(cur.entity.force))
    task.current = nil
    if pair then pair.mining_lock_0315 = nil end
    return false
  end

  TECH_PRIESTS_0322_BEAM_SERVICE_WRAPPERS_RETIRED = true'''
safety = replace_once(safety, old_safety_wrappers, new_safety_predicates, "combat safety beam/service wrappers")
old_safety_command = '''  if commands and commands.add_command then
    pcall(function()
      commands.add_command("tp-combat-safety-0322", "Tech Priests: inspect the 0.1.322 friendly-fire combat target gate.", function(event)
        local player = game and game.get_player(event.player_index)
        if not player then return end
        local pair = nil
        if selected_pair_for_player then
          local ok, found = pcall(function() return selected_pair_for_player(player) end)
          if ok then pair = found end
        end
        if not pair and find_pair_for_entity and player.selected then
          local ok, found = pcall(function() return find_pair_for_entity(player.selected) end)
          if ok then pair = found end
        end
        if not pair then player.print("[Tech Priests 0.1.322] select a Cogitator Station or Tech-Priest."); return end
        M.clear_invalid_combat_state(pair, "manual-inspect")
        local target = pair.combat_target or pair.target
        player.print("[Tech Priests 0.1.322] combat safety loaded. target=" .. entity_name(target) .. " hostile=" .. tostring(M.is_valid_hostile_target(pair.priest or pair.station, target)) .. " mode=" .. tostring(pair.mode))
      end)
    end)
  end'''
safety = replace_once(
    safety,
    old_safety_command,
    '''  TECH_PRIESTS_0322_DEBUG_COMMAND_RETIRED = true''',
    "combat safety debug command",
)
SAFETY_PATH.write_text(safety, encoding="utf-8")

# Command cleanup owns all retired names.
cleanup = CLEANUP_PATH.read_text(encoding="utf-8")
cleanup_anchor = '''  ["tp-laser-0312"] = true,'''
cleanup_insert = '''  ["tp-laser-0312"] = true,
  ["tp-mining-0315"] = true,
  ["tp-mining-0316"] = true,
  ["tp-combat-safety-0322"] = true,'''
if cleanup_insert not in cleanup:
    cleanup = replace_once(cleanup, cleanup_anchor, cleanup_insert, "runtime command cleanup insertion")
CLEANUP_PATH.write_text(cleanup, encoding="utf-8")

# Post-patch ownership and safety assertions.
all_after = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in LUA_PATHS)
post_counts = {
    "function draw_emergency_craft_scan_line(pair, target_entity)": 1,
    "function tech_priests_0312_fire_laser(priest, target, damage, reason, color)": 1,
    "function tech_priests_0312_service_direct_current(pair, task)": 1,
    "function tech_priests_0315_service_direct_current(pair, task)": 0,
    "function tech_priests_0312_insert_loose_item(pair, item_entity)": 1,
    "function tech_priests_0312_stop_for_mining(pair)": 1,
    "function tech_priests_0312_is_hostile_nearby(pair, radius)": 1,
    "tech_priests_0322_is_laser_target_allowed = function": 1,
    "tech_priests_0322_validate_direct_mining_current = function": 1,
}
for needle, expected in post_counts.items():
    actual = all_after.count(needle)
    if actual != expected:
        raise SystemExit(f"post-patch ownership mismatch: {needle!r} expected {expected}, found {actual}")
for forbidden in (
    "tech_priests_original_draw_emergency_craft_scan_line_0177",
    "TECH_PRIESTS_0315_PRE_DRAW_EMERGENCY_CRAFT_SCAN_LINE",
    "TECH_PRIESTS_0315_PRE_HANDLE_EMERGENCY_DESPERATION_CRAFT",
    "TECH_PRIESTS_0322_PRE_0312_FIRE_LASER",
    "TECH_PRIESTS_0322_PRE_0315_SERVICE_DIRECT_CURRENT",
    "function tech_priests_0315_valid_pair(pair)",
    "function tech_priests_0315_origin(priest)",
    "function tech_priests_0315_target_position(target)",
    "function tech_priests_0315_is_hostile_nearby(pair, radius)",
    "function tech_priests_0315_effective_profile(force)",
    'TechPriestsDebugCommandRegistry.add("tp-mining-0315"',
    'TechPriestsDebugCommandRegistry.add("tp-mining-0316"',
    'commands.add_command("tp-combat-safety-0322"',
):
    if forbidden in all_after:
        raise SystemExit(f"post-patch forbidden ownership remains: {forbidden}")
for required in (
    "local direct_current_0784",
    "task_0784.sound_current_key_0177",
    "tech_priests_0322_is_laser_target_allowed(priest, target, reason)",
    "tech_priests_0322_validate_direct_mining_current(pair, task)",
    "TECH_PRIESTS_0177_SCAN_LINE_SOUND_WRAPPER_RETIRED = true",
    "TECH_PRIESTS_0315_DIRECT_SERVICE_OVERRIDE_RETIRED = true",
    "TECH_PRIESTS_0315_HANDLE_WRAPPER_RETIRED = true",
    "TECH_PRIESTS_0322_BEAM_SERVICE_WRAPPERS_RETIRED = true",
    '  ["tp-mining-0315"] = true,',
    '  ["tp-mining-0316"] = true,',
    '  ["tp-combat-safety-0322"] = true,',
    'TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421 = require("scripts.core.bootstrap_runtime")',
):
    if required not in all_after:
        raise SystemExit(f"post-patch required contract missing: {required}")

history = HISTORY_PATH.read_text(encoding="utf-8")
heading = "## 2026-07-21 — Milestone 0784: Canonical Generated Mining Beam and Extraction Ownership"
if heading not in history:
    history += f'''\n\n{heading}\n\nConsolidated the final 0.1.315 mining-beam and direct-extraction implementation into canonical 0.1.312 ownership. The original 0.1.127 scan-line function now owns the later 0.1.177 task-audio behavior and final direct-mining/item suppression policy. Canonical 0.1.312 now owns beam safety invocation, raised-origin rendering, research-scaled pulse behavior, loose-item pickup, combat interruption, movement clamping, extraction timing, deposit, and save-compatible 0315 state cleanup. The 0.1.177 audio wrapper, 0.1.315 scan/beam/service/handler replacements, and 0.1.322 beam/service safety wrappers are retired. Friendly-fire protection remains supplied through named combat-safety predicates, including explicit allowance for loose-item pickup without allowing item entities to become laser targets. Mining and combat-safety debug commands are retired through runtime command cleanup. Static Source validation does not constitute Factorio runtime proof.\n'''
    HISTORY_PATH.write_text(history, encoding="utf-8")

print("0784 transformation complete: one scan line, one beam, one direct service, named safety predicates")
