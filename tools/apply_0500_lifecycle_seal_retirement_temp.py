#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing matcher: {label}")
    return text.replace(old, new, 1)


# Retire the wrapper-based lifecycle seal after moving its one legitimate rule.
write(
    "tech-priests_src/scripts/core/priest_lifecycle_seal_0500.lua",
    '''-- scripts/core/priest_lifecycle_seal_0500.lua
-- Source-preserved retirement marker. Priest preservation, destruction
-- authorization, replacement denial, reverse-map integrity, and removal
-- observation are native to priest_lifecycle_authority_0499 and authoritative
-- generated lifecycle functions.
local M = {
  retired = true,
  authority = "priest_lifecycle_seal_0500",
  replacement = "priest_lifecycle_authority_0499 + authoritative lifecycle functions",
}
return M
''',
)

# Extend 0499 with fail-closed destruction and replacement authorization.
path = "tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua"
text = read(path)
text = replace_once(
    text,
    'M.pair_link_integrated = true\n',
    'M.pair_link_integrated = true\nM.destruction_authority_integrated = true\nM.replacement_authority_integrated = true\n',
    "0499 authority flags",
)
text = replace_once(
    text,
    '  r.pair_link_integrated = true\n  return r\n',
    '  r.pair_link_integrated = true\n  r.destruction_authority_integrated = true\n  r.replacement_authority_integrated = true\n  return r\n',
    "0499 root flags",
)
text = replace_once(
    text,
    '''  pair.lifecycle_0499.last_valid_position = { x = pair.priest.position.x, y = pair.priest.position.y, surface = pair.priest.surface and pair.priest.surface.name or nil }
  pair.lifecycle_0499.last_repair_reason = reason or "repair"
  return true
end

local function rank_from_pair(pair)
''',
    '''  pair.lifecycle_0499.last_valid_position = { x = pair.priest.position.x, y = pair.priest.position.y, surface = pair.priest.surface and pair.priest.surface.name or nil }
  pair.lifecycle_0499.last_repair_reason = reason or "repair"
  pcall(function() pair.priest.destructible = false end)
  if not pair.space_platform_fallback_0204 then pcall(function() pair.priest.active = true end) end
  return true
end

function M.replacement_authorized(pair, reason, opts)
  opts = opts or {}
  if pair then
    pair.lifecycle_0499 = pair.lifecycle_0499 or {}
    pair.lifecycle_0499.last_replacement_denied_tick = now()
    pair.lifecycle_0499.last_replacement_denied_reason = tostring(reason or "replacement")
  end
  stat("replacement-denied")
  return false
end

function M.destruction_authorized(pair, priest, reason, opts)
  opts = opts or {}
  reason = tostring(reason or "")
  if opts.allow_station_cleanup == true and reason == "station-cleanup-remove_pair_for_entity" then return true end
  if opts.allow_unbound_replacement_cleanup == true and reason == "platform-recreate-rejected-new-priest" and valid(priest) and (not pair or priest ~= pair.priest) then return true end
  if opts.allow_replacement == true then return M.replacement_authorized(pair, reason, opts) end
  return false
end

function M.destroy_priest_authorized(priest, reason, pair, opts)
  if not valid(priest) or not is_priest_entity(priest) then return false end
  pair = pair or find_pair_for_entity(priest)
  if not M.destruction_authorized(pair, priest, reason, opts) then
    pcall(function() priest.destructible = false end)
    if pair and not pair.space_platform_fallback_0204 then pcall(function() priest.active = true end) end
    if pair and valid(pair.station) then repair_reverse_maps(pair, "blocked-destroy-0499") end
    record("blocked-priest-destroy", pair, "reason=" .. safe(reason) .. " entity=" .. describe_entity(priest))
    return false
  end
  local ok, result = pcall(function() return priest.destroy({ raise_destroy = false }) end)
  local destroyed = ok and result ~= false
  record(destroyed and "authorized-priest-destroy" or "authorized-priest-destroy-failed", pair, "reason=" .. safe(reason) .. " entity=" .. describe_entity(priest))
  return destroyed
end

local function rank_from_pair(pair)
''',
    "0499 destruction functions",
)
text = text.replace(
    '"generated/control_legacy_part_001.lua remove_pair_for_entity: priest.destroy only allowed when station cleanup is the trigger",\n    "generated/control_legacy_part_002.lua respawn_pair_priest: old_priest.destroy now blocked by 0499 wrapper",\n    "generated/control_legacy_part_003.lua upgrade_pair_priest_to_current_mobility: old_priest.destroy now blocked by 0499 wrapper",\n    "generated/control_legacy_part_006.lua purge_orphan_selected_priest: priest.destroy now blocked by 0499 wrapper",',
    '"generated/control_legacy_part_001.lua remove_pair_for_entity: canonical 0499 helper authorizes only station-triggered cleanup",\n    "generated/control_legacy_part_002.lua respawn_pair_priest: replacement authorization is checked before creation",\n    "generated/control_legacy_part_003.lua upgrade_pair_priest_to_current_mobility: replacement authorization is checked before creation",\n    "generated/control_legacy_part_006.lua purge_orphan_selected_priest: orphan destruction is fail-closed",',
)
text = replace_once(
    text,
    '''  _G.TechPriestsPriestLifecycleAuthority0499 = M
  disable_stuck_watchdog_roots()
''',
    '''  _G.TechPriestsPriestLifecycleAuthority0499 = M
  _G.tech_priests_is_priest_0499 = is_priest_entity
  _G.tech_priests_priest_replacement_authorized_0499 = function(pair, reason, opts) return M.replacement_authorized(pair, reason, opts) end
  _G.tech_priests_priest_destruction_authorized_0499 = function(pair, priest, reason, opts) return M.destruction_authorized(pair, priest, reason, opts) end
  _G.tech_priests_destroy_priest_authorized_0499 = function(priest, reason, pair, opts) return M.destroy_priest_authorized(priest, reason, pair, opts) end
  disable_stuck_watchdog_roots()
''',
    "0499 global exports",
)
write(path, text)

# Canonical creation establishes pair maps and priest preservation immediately.
path = "tech-priests_src/scripts/generated/control_legacy_part_002.lua"
text = read(path)
text = replace_once(
    text,
    '''  spawn_priest_smoke_for_entity(priest, false)

  local pair = {
''',
    '''  spawn_priest_smoke_for_entity(priest, false)
  pcall(function() priest.destructible = false end)
  pcall(function() priest.active = true end)

  local pair = {
''',
    "create pair preservation",
)
text = replace_once(
    text,
    '''  storage.tech_priests.pairs_by_station[station.unit_number] = pair
  storage.tech_priests.station_by_priest[priest.unit_number] = station.unit_number
''',
    '''  storage.tech_priests.pairs_by_station[station.unit_number] = pair
  storage.tech_priests.pairs_by_priest = storage.tech_priests.pairs_by_priest or {}
  storage.tech_priests.pairs_by_priest[priest.unit_number] = pair
  storage.tech_priests.station_by_priest[priest.unit_number] = station.unit_number
''',
    "create pair reverse maps",
)
text = replace_once(
    text,
    '''respawn_pair_priest = function(pair, reason)
  if not (pair and pair.station and pair.station.valid) then return false end
  ensure_storage()
''',
    '''respawn_pair_priest = function(pair, reason)
  if not (pair and pair.station and pair.station.valid) then return false end
  if type(_G.tech_priests_priest_replacement_authorized_0499) ~= "function" or not _G.tech_priests_priest_replacement_authorized_0499(pair, reason or "respawn", { kind = "respawn" }) then return false end
  ensure_storage()
''',
    "respawn early authorization",
)
text = replace_once(
    text,
    '''    if tech_priests_destroy_priest_0500 then
      tech_priests_destroy_priest_0500(old_priest, "respawn_pair_priest-old-priest", pair)
    else
      old_priest.destroy({ raise_destroy = false })
    end
''',
    '''    if type(_G.tech_priests_destroy_priest_authorized_0499) ~= "function" or not _G.tech_priests_destroy_priest_authorized_0499(old_priest, "respawn_pair_priest-old-priest", pair, { allow_replacement = true }) then return false end
''',
    "respawn destroy authorization",
)
write(path, text)

# Station cleanup is the only paired-priest destruction allowed by the original removal function.
path = "tech-priests_src/scripts/generated/control_legacy_part_001.lua"
text = read(path)
text = replace_once(
    text,
    '''    if tech_priests_destroy_priest_0500 then
      tech_priests_destroy_priest_0500(priest, "station-cleanup-remove_pair_for_entity", pair, { allow_station_cleanup = is_station and is_station(entity) })
    else
      priest.destroy({ raise_destroy = false })
    end
''',
    '''    if type(_G.tech_priests_destroy_priest_authorized_0499) == "function" then
      _G.tech_priests_destroy_priest_authorized_0499(priest, "station-cleanup-remove_pair_for_entity", pair, { allow_station_cleanup = is_station and is_station(entity) })
    elseif log then
      log("[Tech-Priests] priest cleanup denied: canonical lifecycle authority unavailable")
    end
''',
    "station cleanup destruction",
)
write(path, text)

# Mobility replacement is checked before any duplicate priest is created.
path = "tech-priests_src/scripts/generated/control_legacy_part_003.lua"
text = read(path)
text = replace_once(
    text,
    '''  local desired_name = get_priest_name_for_force(config, pair.station.force)
  if not desired_name or pair.priest.name == desired_name then return false end

  local old_priest = pair.priest
''',
    '''  local desired_name = get_priest_name_for_force(config, pair.station.force)
  if not desired_name or pair.priest.name == desired_name then return false end
  if type(_G.tech_priests_priest_replacement_authorized_0499) ~= "function" or not _G.tech_priests_priest_replacement_authorized_0499(pair, "mobility-upgrade", { kind = "mobility" }) then return false end

  local old_priest = pair.priest
''',
    "mobility early authorization",
)
text = replace_once(
    text,
    '''  if tech_priests_destroy_priest_0500 then
    tech_priests_destroy_priest_0500(old_priest, "mobility-upgrade-old-priest", pair)
  else
    old_priest.destroy({ raise_destroy = false })
  end
''',
    '''  if type(_G.tech_priests_destroy_priest_authorized_0499) ~= "function" or not _G.tech_priests_destroy_priest_authorized_0499(old_priest, "mobility-upgrade-old-priest", pair, { allow_replacement = true }) then
    pcall(function() new_priest.destroy({ raise_destroy = false }) end)
    return false
  end
''',
    "mobility destroy authorization",
)
write(path, text)

# Orphan purge is fail-closed and performs no smoke/map mutation when denied.
path = "tech-priests_src/scripts/generated/control_legacy_part_006.lua"
text = read(path)
old = '''function purge_orphan_selected_priest(priest)
  if not (priest and priest.valid and is_priest(priest)) then return false end
  local pair = find_pair_for_entity and find_pair_for_entity(priest) or nil
  if pair and pair.station and pair.station.valid then return false end
  ensure_storage()
  storage.tech_priests.orphan_priest_purge_cooldowns = storage.tech_priests.orphan_priest_purge_cooldowns or {}
  local unit = priest.unit_number or 0
  local next_tick = storage.tech_priests.orphan_priest_purge_cooldowns[unit] or 0
  if game.tick < next_tick then return true end
  storage.tech_priests.orphan_priest_purge_cooldowns[unit] = game.tick + ORPHAN_PRIEST_PURGE_COOLDOWN_TICKS
  if unit and storage.tech_priests.station_by_priest then
    storage.tech_priests.station_by_priest[unit] = nil
  end
  spawn_orphan_priest_purge_explosion(priest)
  if tech_priests_destroy_priest_0500 then
    tech_priests_destroy_priest_0500(priest, "orphan-priest-purge", pair)
  else
    pcall(function() priest.destroy({ raise_destroy = false }) end)
  end
  return true
end
'''
new = '''function purge_orphan_selected_priest(priest)
  if not (priest and priest.valid and is_priest(priest)) then return false end
  local pair = find_pair_for_entity and find_pair_for_entity(priest) or nil
  if pair and pair.station and pair.station.valid then return false end
  if type(_G.tech_priests_destroy_priest_authorized_0499) ~= "function" then return false end
  local destroyed = _G.tech_priests_destroy_priest_authorized_0499(priest, "orphan-priest-purge", pair, { allow_orphan_purge = false })
  if not destroyed then return false end
  local unit = priest.unit_number or 0
  ensure_storage()
  if unit and storage.tech_priests.station_by_priest then storage.tech_priests.station_by_priest[unit] = nil end
  spawn_orphan_priest_purge_explosion(priest)
  return true
end
'''
text = replace_once(text, old, new, "orphan purge")
write(path, text)

# Platform recreation checks authorization before creating a replacement.
path = "tech-priests_src/scripts/generated/control_legacy_part_011.lua"
text = read(path)
text = replace_once(
    text,
    '''  -- Teleport can fail for unit entities on space platforms.  Recreate the unit at
  -- the exact marker and only swap mappings if the new entity actually lands there.
  local old = priest
''',
    '''  -- Teleport can fail for unit entities on space platforms. Replacement remains
  -- fail-closed unless the canonical lifecycle authority grants a bounded lease.
  if type(_G.tech_priests_priest_replacement_authorized_0499) ~= "function" or not _G.tech_priests_priest_replacement_authorized_0499(pair, "platform-recreate", { kind = "platform" }) then return false end
  local old = priest
''',
    "platform early authorization",
)
text = replace_once(
    text,
    '''      if tech_priests_destroy_priest_0500 and tech_priests_is_priest_0500 and tech_priests_is_priest_0500(ent) then
        tech_priests_destroy_priest_0500(ent, "platform-recreate-rejected-new-priest", pair)
      else
        pcall(function() ent.destroy({ raise_destroy = false }) end)
      end
''',
    '''      if type(_G.tech_priests_destroy_priest_authorized_0499) == "function" and type(_G.tech_priests_is_priest_0499) == "function" and _G.tech_priests_is_priest_0499(ent) then
        _G.tech_priests_destroy_priest_authorized_0499(ent, "platform-recreate-rejected-new-priest", pair, { allow_unbound_replacement_cleanup = true })
      else
        pcall(function() ent.destroy({ raise_destroy = false }) end)
      end
''',
    "platform rejected entity cleanup",
)
text = replace_once(
    text,
    '''      if tech_priests_destroy_priest_0500 then
        tech_priests_destroy_priest_0500(old, "platform-recreate-old-priest", pair)
      else
        pcall(function() old.destroy({ raise_destroy = false }) end)
      end
''',
    '''      if type(_G.tech_priests_destroy_priest_authorized_0499) ~= "function" or not _G.tech_priests_destroy_priest_authorized_0499(old, "platform-recreate-old-priest", pair, { allow_replacement = true }) then
        pcall(function() created.destroy({ raise_destroy = false }) end)
        return false
      end
''',
    "platform old priest destruction",
)
write(path, text)

# Rendering objects are not priest lifecycle entities; remove the obsolete type branch.
path = "tech-priests_src/scripts/generated/control_legacy_part_012.lua"
text = read(path)
text = replace_once(
    text,
    '''      if old.valid then
        if tech_priests_destroy_priest_0500 and tech_priests_is_priest_0500 and tech_priests_is_priest_0500(old) then
          tech_priests_destroy_priest_0500(old, "platform-or-recreate-old-entity", pair)
        else
          old.destroy()
        end
      end
''',
    '''      if old.valid then old.destroy() end
''',
    "render object cleanup",
)
write(path, text)

# 0503 may request a future authorized swap, but may not disguise it as station cleanup.
path = "tech-priests_src/scripts/core/priest_recovery_safety_0503.lua"
text = read(path)
text = replace_once(
    text,
    '''local function safe_destroy_old_for_mobility(pair, old_priest)
  if not valid(old_priest) then return true end
  pair.lifecycle_0503 = pair.lifecycle_0503 or {}
  pair.lifecycle_0503.authorized_mobility_destroy_until = now() + 5
  pair.lifecycle_0503.authorized_mobility_destroy_unit = old_priest.unit_number
  if pair.lifecycle_0500 then
    pair.lifecycle_0500.allow_priest_destroy_until = now() + 5
    pair.lifecycle_0500.allow_priest_destroy_reason = "authorized-mobility-swap-0503"
  end
  local ok = false
  if type(_G.tech_priests_destroy_priest_0500) == "function" then
    pcall(function() ok = _G.tech_priests_destroy_priest_0500(old_priest, "authorized-mobility-swap-0503", pair, { allow_station_cleanup = true }) end)
  else
    pcall(function() old_priest.destroy({ raise_destroy = false }) ok = true end)
  end
  record("authorized-mobility-old-priest-destroy-0503", pair, "old=" .. safe(pair.lifecycle_0503.authorized_mobility_destroy_unit) .. " ok=" .. safe(ok))
  return ok
end
''',
    '''local function safe_destroy_old_for_mobility(pair, old_priest)
  if not valid(old_priest) then return true end
  pair.lifecycle_0503 = pair.lifecycle_0503 or {}
  pair.lifecycle_0503.authorized_mobility_destroy_unit = old_priest.unit_number
  local ok = false
  if type(_G.tech_priests_destroy_priest_authorized_0499) == "function" then
    pcall(function() ok = _G.tech_priests_destroy_priest_authorized_0499(old_priest, "authorized-mobility-swap-0503", pair, { allow_replacement = true }) end)
  end
  record("mobility-old-priest-destroy-request-0503", pair, "old=" .. safe(pair.lifecycle_0503.authorized_mobility_destroy_unit) .. " ok=" .. safe(ok))
  return ok
end
''',
    "0503 mobility destruction",
)
text = replace_once(
    text,
    '''  local desired = desired_priest_name(pair)
  if not desired or pair.priest.name == desired then
    repair_reverse_maps(pair, "mobility-current-0503")
    return false
  end

  local old = pair.priest
''',
    '''  local desired = desired_priest_name(pair)
  if not desired or pair.priest.name == desired then
    repair_reverse_maps(pair, "mobility-current-0503")
    return false
  end
  local lifecycle = rawget(_G, "TechPriestsPriestLifecycleAuthority0499")
  if not (lifecycle and type(lifecycle.replacement_authorized) == "function" and lifecycle.replacement_authorized(pair, reason or "mobility-swap-0503", { kind = "mobility" })) then
    record("mobility-swap-denied-0503", pair, "desired=" .. safe(desired) .. " reason=" .. safe(reason))
    return false
  end

  local old = pair.priest
''',
    "0503 early authorization",
)
for old, label in (
    ('''  local life499 = rawget(_G, "TechPriestsPriestLifecycleAuthority0499")
  if life499 then
    life499.service_pair = function(pair) return M.service_pair(pair) end
    life499.service_all = function() return M.service_all() end
  end
''', "0503 0499 override"),
    ('''  local seal500 = rawget(_G, "TechPriestsPriestLifecycleSeal0500")
  if seal500 then
    seal500.service_pair = function(pair) return M.service_pair(pair) end
    seal500.service_all = function() return M.service_all() end
  end
''', "0503 0500 override"),
    ('''  local link495 = rawget(_G, "TechPriestsPairLinkHardening0495")
  if link495 then
    link495.service_pair = function(pair) return M.service_pair(pair) end
    link495.service_all = function() return M.service_all() end
  end
''', "0503 0495 override"),
):
    text = replace_once(text, old, '', label)
write(path, text)

# Remove the final 0500 state fallback from the vanish guard.
path = "tech-priests_src/scripts/core/priest_vanish_guard_0501.lua"
text = read(path)
text = replace_once(text, '  local base = pair.lifecycle_0501 and pair.lifecycle_0501.last_valid_position or pair.lifecycle_0500 and pair.lifecycle_0500.last_valid_position\n', '  local base = pair.lifecycle_0501 and pair.lifecycle_0501.last_valid_position or pair.lifecycle_0499 and pair.lifecycle_0499.last_valid_position\n', "0501 lifecycle fallback")
write(path, text)

# Remove retired loader and command.
path = "tech-priests_src/control.lua"
text = read(path)
old = '''-- 0.1.500: direct priest lifecycle seal.  Visible Tech-Priests are preserved
-- unless their paired Cogitator Station is being removed or killed.  Stuck,
-- recall, respawn, mobility-replacement, and orphan-purge paths remain disabled
-- while the vanish source is isolated.
pcall(function()
  local Seal0500 = require("scripts.core.priest_lifecycle_seal_0500")
  if Seal0500 and Seal0500.install then Seal0500.install() end
end)
'''
text = replace_once(text, old, '-- Historical 0500 lifecycle seal is retired into canonical 0499 and authoritative lifecycle functions.\n', "control 0500 loader")
write(path, text)

path = "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua"
text = read(path)
text = replace_once(text, '  ["tp-pair-link-0495"] = true,\n', '  ["tp-pair-link-0495"] = true,\n  ["tp-priest-lifecycle-0500"] = true,\n', "runtime cleanup 0500 command")
write(path, text)

# Update lifecycle audit tools to the canonical owner names.
for path in (
    "tools/audit_lifecycle_global_owners.py",
    "tools/audit_visible_priest_lifecycle.py",
    "tools/audit_visible_priest_lifecycle_sites.py",
):
    text = read(path)
    text = text.replace('tech_priests_destroy_priest_0500', 'tech_priests_destroy_priest_authorized_0499')
    text = text.replace('tech_priests_allow_priest_station_cleanup_0500', 'tech_priests_priest_destruction_authorized_0499')
    text = text.replace('TechPriestsPriestLifecycleSeal0500', 'TechPriestsPriestLifecycleAuthority0499')
    text = text.replace('priest_lifecycle_seal_0500', 'priest_lifecycle_authority_0499')
    text = text.replace('lifecycle_0500', 'lifecycle_0499')
    text = text.replace('lifecycle-seal-owner-or-wrapper', 'canonical-lifecycle-owner-or-wrapper')
    write(path, text)

# Advance graph and focused boundaries.
path = "tech-priests_src/scripts/core/planning_constraints_0646.lua"
text = read(path)
text = replace_once(text, 'active_hardener_count=26,retired_authority_count=39', 'active_hardener_count=26,retired_authority_count=40', "planning count")
text = replace_once(
    text,
    ' ["scripts.core.pair_link_hardening_0495"]="reverse-map repair, conservative orphan rebinding, and missing-priest observation are native to priest_lifecycle_authority_0499",\n',
    ' ["scripts.core.pair_link_hardening_0495"]="reverse-map repair, conservative orphan rebinding, and missing-priest observation are native to priest_lifecycle_authority_0499",\n ["scripts.core.priest_lifecycle_seal_0500"]="destruction authorization, replacement denial, pair integrity, and removal observation are native to 0499 and authoritative lifecycle functions",\n',
    "planning retired 0500",
)
write(path, text)

write(
    "tools/check_lifecycle_seal_0500_boundary_0771.py",
    '''#!/usr/bin/env python3
"""Validate inert 0500 and fail-closed canonical lifecycle destruction/replacement."""
from __future__ import annotations
import pathlib
import sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "retired": ROOT / "tech-priests_src/scripts/core/priest_lifecycle_seal_0500.lua",
    "lifecycle": ROOT / "tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua",
    "control": ROOT / "tech-priests_src/control.lua",
    "part1": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_001.lua",
    "part2": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_002.lua",
    "part3": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_003.lua",
    "part6": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_006.lua",
    "part11": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_011.lua",
    "part12": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_012.lua",
    "recovery": ROOT / "tech-priests_src/scripts/core/priest_recovery_safety_0503.lua",
    "guard": ROOT / "tech-priests_src/scripts/core/priest_vanish_guard_0501.lua",
    "cleanup": ROOT / "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
    "planning": ROOT / "tech-priests_src/scripts/core/planning_constraints_0646.lua",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
}
REQUIRED = {
    "retired": ('retired = true', 'authority = "priest_lifecycle_seal_0500"', 'priest_lifecycle_authority_0499 + authoritative lifecycle functions'),
    "lifecycle": ('destruction_authority_integrated = true', 'replacement_authority_integrated = true', 'function M.replacement_authorized', 'function M.destruction_authorized', 'function M.destroy_priest_authorized', 'tech_priests_priest_replacement_authorized_0499', 'tech_priests_destroy_priest_authorized_0499', 'allow_station_cleanup == true', 'station-cleanup-remove_pair_for_entity'),
    "control": ('Historical 0500 lifecycle seal is retired into canonical 0499',),
    "part1": ('tech_priests_destroy_priest_authorized_0499', 'allow_station_cleanup = is_station and is_station(entity)', 'priest cleanup denied: canonical lifecycle authority unavailable'),
    "part2": ('priest.destructible = false', 'storage.tech_priests.pairs_by_priest[priest.unit_number] = pair', 'tech_priests_priest_replacement_authorized_0499', 'tech_priests_destroy_priest_authorized_0499'),
    "part3": ('tech_priests_priest_replacement_authorized_0499', 'tech_priests_destroy_priest_authorized_0499', 'new_priest.destroy'),
    "part6": ('tech_priests_destroy_priest_authorized_0499', 'if not destroyed then return false end'),
    "part11": ('tech_priests_priest_replacement_authorized_0499', 'allow_unbound_replacement_cleanup = true', 'allow_replacement = true'),
    "recovery": ('tech_priests_destroy_priest_authorized_0499', 'mobility-swap-denied-0503'),
    "guard": ('pair.lifecycle_0499 and pair.lifecycle_0499.last_valid_position',),
    "cleanup": ('["tp-priest-lifecycle-0500"] = true',),
    "planning": ('retired_authority_count=40', '["scripts.core.priest_lifecycle_seal_0500"]'),
    "workflow": ('Audit retired 0500 lifecycle seal', 'check_lifecycle_seal_0500_boundary_0771.py'),
}
FORBIDDEN = {
    "retired": ('function M.install', 'register_service', 'on_nth_tick', 'commands.add_command', 'tech_priests_destroy_priest_0500'),
    "lifecycle": ('tech_priests_destroy_priest_0500', 'tech_priests_allow_priest_station_cleanup_0500', 'lifecycle_0500'),
    "control": ('require("scripts.core.priest_lifecycle_seal_0500")',),
    "part1": ('tech_priests_destroy_priest_0500', 'priest.destroy({ raise_destroy = false })'),
    "part2": ('tech_priests_destroy_priest_0500',),
    "part3": ('tech_priests_destroy_priest_0500',),
    "part6": ('tech_priests_destroy_priest_0500', 'priest.destroy({ raise_destroy = false })'),
    "part11": ('tech_priests_destroy_priest_0500', 'tech_priests_is_priest_0500'),
    "part12": ('tech_priests_destroy_priest_0500', 'tech_priests_is_priest_0500'),
    "recovery": ('tech_priests_destroy_priest_0500', 'TechPriestsPriestLifecycleSeal0500', 'pair.lifecycle_0500', 'allow_station_cleanup = true', 'life499.service_pair ='),
    "guard": ('pair.lifecycle_0500',),
}
def main() -> int:
    errors = []
    texts = {name: path.read_text(encoding="utf-8", errors="replace") for name, path in FILES.items()}
    for name, fragments in REQUIRED.items():
        for fragment in fragments:
            if fragment not in texts[name]: errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {fragment}")
    for name, fragments in FORBIDDEN.items():
        for fragment in fragments:
            if fragment in texts[name]: errors.append(f"{FILES[name].relative_to(ROOT)} contains forbidden regression: {fragment}")
    if errors:
        print("0500 lifecycle boundary audit failed:", file=sys.stderr)
        for error in errors: print("  - " + error, file=sys.stderr)
        return 1
    print("0500 lifecycle boundary audit passed: destruction and replacement are fail-closed in canonical source; 0500 is inert.")
    return 0
if __name__ == "__main__": raise SystemExit(main())
''',
)

for path in (
    "tools/check_movement_cadence_boundary_0761.py",
    "tools/check_combat_proxy_boundary_0762.py",
    "tools/check_direct_acquisition_bounds_boundary_0764.py",
    "tools/check_movement_enforcement_void_boundary_0765.py",
    "tools/check_movement_economy_boundary_0767.py",
    "tools/check_ground_route_loader_boundary_0768.py",
    "tools/check_priest_vanish_0502_boundary_0769.py",
    "tools/check_pair_link_0495_boundary_0770.py",
):
    text = read(path)
    if 'retired_authority_count=39' not in text: raise SystemExit(f"count anchor missing: {path}")
    write(path, text.replace('retired_authority_count=39', 'retired_authority_count=40'))

path = "tools/check_recovery_architecture_0744.py"
text = read(path)
text = replace_once(text, '"scripts.core.priest_vanish_guard_0502", "scripts.core.pair_link_hardening_0495", "scripts.core.fluid_output_sink_doctrine_0694",', '"scripts.core.priest_vanish_guard_0502", "scripts.core.pair_link_hardening_0495", "scripts.core.priest_lifecycle_seal_0500", "scripts.core.fluid_output_sink_doctrine_0694",', "architecture retired set")
text = text.replace('retired_authority_count=39', 'retired_authority_count=40')
text = text.replace('"Thirty-nine files remain"', '"Forty files remain"')
text = text.replace('"39 source-preserved authorities"', '"40 source-preserved authorities"')
text = text.replace('"26 active hardeners and 39 explicitly retired"', '"26 active hardeners and 40 explicitly retired"')
write(path, text)

path = "tools/check_development_integration_0732.py"
text = read(path)
text = replace_once(text, '    "scripts.core.pair_link_hardening_0495",\n', '    "scripts.core.pair_link_hardening_0495",\n    "scripts.core.priest_lifecycle_seal_0500",\n', "integration retired set")
text = text.replace('retired_authority_count=39', 'retired_authority_count=40')
text = replace_once(text, '"check_pair_link_0495_boundary_0770.py",\n', '"check_pair_link_0495_boundary_0770.py", "check_lifecycle_seal_0500_boundary_0771.py",\n', "integration checker 0771")
write(path, text)

path = "tools/check_governance_prerequisites_0738.py"
text = read(path)
for old, new in (
    ('26-active / 39-retired graph', '26-active / 40-retired graph'),
    ('26 active hardeners and 39 explicitly retired', '26 active hardeners and 40 explicitly retired'),
    ('26 active hardeners and 39 retired source-only authorities', '26 active hardeners and 40 retired source-only authorities'),
    ('39 source-preserved authorities', '40 source-preserved authorities'),
    ('39 retired source-only authorities', '40 retired source-only authorities'),
    ('Thirty-nine files remain', 'Forty files remain'),
): text = text.replace(old, new)
text = replace_once(text, '        "check_pair_link_0495_boundary_0770.py",\n', '        "check_pair_link_0495_boundary_0770.py",\n        "Audit retired 0500 lifecycle seal",\n        "check_lifecycle_seal_0500_boundary_0771.py",\n', "governance workflow 0771")
write(path, text)

# Current authority documents.
path = "tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md"
text = read(path).replace('**39 source-preserved authorities**', '**40 source-preserved authorities**', 1)
anchor = '`pair_link_hardening_0495` is retired. Reverse-map truth, conservative nearby orphan rebinding, and missing-priest observation are native to broker-owned `priest_lifecycle_authority_0499`; replacement remains disabled.'
if anchor not in text: raise SystemExit("continuity 0495 paragraph missing")
text = text.replace(anchor, anchor + '\n\n`priest_lifecycle_seal_0500` is retired. Valid-priest preservation and destruction/replacement authorization are native to `0499`; original creation, removal, respawn, mobility, orphan, and platform functions now check that authority before mutating physical priest state.', 1)
write(path, text)

path = "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
text = read(path)
text = text.replace('26 active hardeners and 39 retired source-only authorities', '26 active hardeners and 40 retired source-only authorities', 1)
text = text.replace('26 attempted active hardeners and 39 retired source-only authorities', '26 attempted active hardeners and 40 retired source-only authorities', 1)
anchor = '`0495` is inert; `0499` owns broker-budgeted pair identity and missing-priest observation without authorizing replacement.'
if anchor not in text: raise SystemExit("testing 0495 statement missing")
text = text.replace(anchor, anchor + ' `0500` is inert; canonical lifecycle functions fail closed unless `0499` authorizes real station cleanup.', 1)
write(path, text)

path = "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
text = read(path)
text = text.replace('**26 declarative active hardeners** and **39 retired source-only authorities**', '**26 declarative active hardeners** and **40 retired source-only authorities**', 1)
text = text.replace('Thirty-nine files remain source-preserved', 'Forty files remain source-preserved', 1)
anchor = '`0495` is retired as a parallel pair-link rescue authority. `0499` now owns reverse-map repair, conservative nearby orphan rebinding, and missing-priest observation through the runtime broker. Broad search and direct respawn remain forbidden.'
if anchor not in text: raise SystemExit("map 0495 paragraph missing")
text = text.replace(anchor, anchor + '\n\n`0500` is retired as a wrapper seal. `0499` exports the fail-closed destruction and replacement policy, while the authoritative generated lifecycle functions establish pair maps on creation and consult `0499` before station cleanup, respawn, mobility, orphan purge, or platform recreation.', 1)
write(path, text)

path = "docs/DEVELOPMENT_HISTORY.md"
text = read(path)
section = '''### Retired `0500` lifecycle seal into canonical source

`priest_lifecycle_seal_0500` wrapped creation, removal, respawn, ensure, recall, platform replacement, recovery modules, events, diagnostics, commands, and a 17-tick watchdog. Its one legitimate rule—paired priests may be destroyed only during real Cogitator Station cleanup—now lives in `priest_lifecycle_authority_0499` and the original lifecycle functions.

Canonical `create_pair` now establishes both reverse maps and immediately preserves the priest. Respawn, mobility upgrade, and platform recreation check replacement authorization before creating a duplicate. Station removal is the sole paired-priest destruction route; orphan purge and the former `0503` mobility-swap cleanup fail closed. The graph is now **26 active hardeners and 40 explicitly retired source-only authorities**.

Complete Source validation and Factorio runtime evidence remain separately required.

'''
if '### Retired `0500` lifecycle seal into canonical source' not in text:
    text = replace_once(text, '## Current Gate State', section + '## Current Gate State', "history current gate")
write(path, text)

path = "RECOVERY_REPAIR_SEQUENCE.md"
text = read(path).replace('26-active / 39-retired graph', '26-active / 40-retired graph', 1)
write(path, text)

# Temporary audit and patch files leave in the implementation commit.
for temporary in (
    ROOT / ".github/workflows/audit-0500-retirement-references-temp.yml",
    Path(__file__),
):
    if temporary.exists(): temporary.unlink()
