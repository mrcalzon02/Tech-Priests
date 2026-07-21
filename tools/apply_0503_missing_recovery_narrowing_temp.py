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


# 0499 owns observation and issues/consumes one-shot missing-recovery leases.
path = "tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua"
text = read(path)
text = replace_once(
    text,
    'M.replacement_authority_integrated = true\n',
    'M.replacement_authority_integrated = true\nM.controlled_missing_recovery = true\nM.missing_recovery_delay_ticks = 180\nM.replacement_lease_ticks = 30\nM.recovery_attempt_cooldown_ticks = 600\n',
    "0499 recovery constants",
)
text = replace_once(
    text,
    '  r.replacement_authority_integrated = true\n  return r\n',
    '  r.replacement_authority_integrated = true\n  r.controlled_missing_recovery = true\n  return r\n',
    "0499 root recovery flag",
)
old = '''function M.replacement_authorized(pair, reason, opts)
  opts = opts or {}
  if pair then
    pair.lifecycle_0499 = pair.lifecycle_0499 or {}
    pair.lifecycle_0499.last_replacement_denied_tick = now()
    pair.lifecycle_0499.last_replacement_denied_reason = tostring(reason or "replacement")
  end
  stat("replacement-denied")
  return false
end
'''
new = '''local function controlled_missing_request(reason, opts)
  opts = opts or {}
  return tostring(reason or "") == "controlled-missing-recovery-0503"
    and tostring(opts.owner or "") == "priest_recovery_safety_0503"
    and tostring(opts.kind or "") == "missing-priest-recovery"
end

function M.authorize_missing_recovery(pair, reason, opts)
  opts = opts or {}
  if not controlled_missing_request(reason, opts) or not (pair and valid(pair.station)) or valid(pair.priest) then
    stat("replacement-denied")
    return false, "invalid-controlled-recovery-request"
  end
  pair.lifecycle_0499 = pair.lifecycle_0499 or {}
  local lifecycle = pair.lifecycle_0499
  local missing_since = tonumber(lifecycle.missing_since)
  if not missing_since then stat("replacement-denied-unobserved"); return false, "missing-state-not-observed" end
  if now() - missing_since < M.missing_recovery_delay_ticks then return false, "missing-observation-delay" end
  local last_attempt = tonumber(lifecycle.last_recovery_attempt_tick or -1000000) or -1000000
  if now() - last_attempt < M.recovery_attempt_cooldown_ticks then return false, "recovery-attempt-cooldown" end
  local lease = {
    owner = "priest_recovery_safety_0503",
    kind = "missing-priest-recovery",
    reason = "controlled-missing-recovery-0503",
    issued_tick = now(),
    expires_tick = now() + M.replacement_lease_ticks,
    station_unit = station_unit(pair),
  }
  lifecycle.replacement_lease = lease
  lifecycle.last_recovery_attempt_tick = now()
  record("missing-recovery-lease-issued", pair, "expires=" .. safe(lease.expires_tick))
  return true, lease
end

function M.consume_replacement_lease(pair, reason, opts)
  opts = opts or {}
  if not controlled_missing_request(reason, opts) or not (pair and valid(pair.station)) or valid(pair.priest) then
    stat("replacement-lease-denied")
    return false
  end
  pair.lifecycle_0499 = pair.lifecycle_0499 or {}
  local lifecycle = pair.lifecycle_0499
  local lease = lifecycle.replacement_lease
  lifecycle.replacement_lease = nil
  if type(lease) ~= "table"
    or lease.owner ~= "priest_recovery_safety_0503"
    or lease.kind ~= "missing-priest-recovery"
    or lease.reason ~= "controlled-missing-recovery-0503"
    or tonumber(lease.station_unit) ~= tonumber(station_unit(pair))
    or now() > (tonumber(lease.expires_tick) or -1)
  then
    stat("replacement-lease-denied")
    return false
  end
  lifecycle.last_replacement_lease_consumed_tick = now()
  record("missing-recovery-lease-consumed", pair, "issued=" .. safe(lease.issued_tick))
  return true
end

function M.note_recovered_priest(pair, priest, reason)
  if not (pair and valid(pair.station) and valid(priest) and is_priest_entity(priest)) then return false end
  pair.priest = priest
  pair.priest_unit = priest.unit_number
  pair.lifecycle_0499 = pair.lifecycle_0499 or {}
  pair.lifecycle_0499.missing_since = nil
  pair.lifecycle_0499.last_missing_report_tick = nil
  pair.lifecycle_0499.replacement_lease = nil
  pair.lifecycle_0499.last_recovered_tick = now()
  pair.lifecycle_0499.last_recovered_reason = tostring(reason or "controlled-missing-recovery-0503")
  pair.respawn_disabled_0499 = nil
  pair.ensure_disabled_0499 = nil
  repair_reverse_maps(pair, "controlled-recovery-0499")
  record("missing-priest-recovered", pair, "reason=" .. safe(reason) .. " unit=" .. safe(priest.unit_number))
  return true
end

function M.replacement_authorized(pair, reason, opts)
  opts = opts or {}
  if opts.request_missing_recovery == true then return M.authorize_missing_recovery(pair, reason, opts) end
  if opts.consume_missing_recovery == true then return M.consume_replacement_lease(pair, reason, opts) end
  if pair then
    pair.lifecycle_0499 = pair.lifecycle_0499 or {}
    pair.lifecycle_0499.last_replacement_denied_tick = now()
    pair.lifecycle_0499.last_replacement_denied_reason = tostring(reason or "replacement")
  end
  stat("replacement-denied")
  return false
end
'''
text = replace_once(text, old, new, "0499 replacement lease API")
text = replace_once(
    text,
    '''    lifecycle.missing_since = nil
    lifecycle.last_missing_report_tick = nil
    clear_stuck_recovery_flags(pair)
''',
    '''    lifecycle.missing_since = nil
    lifecycle.last_missing_report_tick = nil
    lifecycle.replacement_lease = nil
    clear_stuck_recovery_flags(pair)
''',
    "0499 valid state lease cleanup",
)
text = replace_once(
    text,
    '    record("missing-priest-no-respawn", pair, "missing_for=" .. safe(now() - lifecycle.missing_since) .. " station valid; replacement remains disabled")\n',
    '    record("missing-priest-awaiting-controlled-recovery", pair, "missing_for=" .. safe(now() - lifecycle.missing_since) .. " station valid; only 0503 lease recovery is eligible")\n',
    "0499 missing observation message",
)
text = replace_once(
    text,
    '''  _G.tech_priests_priest_replacement_authorized_0499 = function(pair, reason, opts) return M.replacement_authorized(pair, reason, opts) end
  _G.tech_priests_priest_destruction_authorized_0499 = function(pair, priest, reason, opts) return M.destruction_authorized(pair, priest, reason, opts) end
''',
    '''  _G.tech_priests_priest_replacement_authorized_0499 = function(pair, reason, opts) return M.replacement_authorized(pair, reason, opts) end
  _G.tech_priests_authorize_missing_recovery_0499 = function(pair, reason, opts) return M.authorize_missing_recovery(pair, reason, opts) end
  _G.tech_priests_consume_replacement_lease_0499 = function(pair, reason, opts) return M.consume_replacement_lease(pair, reason, opts) end
  _G.tech_priests_note_recovered_priest_0499 = function(pair, priest, reason) return M.note_recovered_priest(pair, priest, reason) end
  _G.tech_priests_priest_destruction_authorized_0499 = function(pair, priest, reason, opts) return M.destruction_authorized(pair, priest, reason, opts) end
''',
    "0499 recovery exports",
)
text = replace_once(
    text,
    '  if log then log("[Tech-Priests 0.1.674-dev] broker-owned priest lifecycle observation installed; replacement remains disabled") end\n',
    '  if log then log("[Tech-Priests 0.1.674-dev] broker-owned lifecycle observation installed; only one-shot 0503 missing-recovery leases are authorized") end\n',
    "0499 install log",
)
write(path, text)

# Canonical generated respawn consumes the one-shot lease and restores all maps.
path = "tech-priests_src/scripts/generated/control_legacy_part_002.lua"
text = read(path)
text = replace_once(
    text,
    '''respawn_pair_priest = function(pair, reason)
  if not (pair and pair.station and pair.station.valid) then return false end
  if type(_G.tech_priests_priest_replacement_authorized_0499) ~= "function" or not _G.tech_priests_priest_replacement_authorized_0499(pair, reason or "respawn", { kind = "respawn" }) then return false end
  ensure_storage()
''',
    '''respawn_pair_priest = function(pair, reason)
  if not (pair and pair.station and pair.station.valid) or (pair.priest and pair.priest.valid) then return false end
  local recovery_opts = { owner = "priest_recovery_safety_0503", kind = "missing-priest-recovery", consume_missing_recovery = true }
  if type(_G.tech_priests_consume_replacement_lease_0499) ~= "function"
    or not _G.tech_priests_consume_replacement_lease_0499(pair, reason, recovery_opts)
  then return false end
  ensure_storage()
''',
    "canonical respawn lease consumption",
)
text = replace_once(
    text,
    '''  if old_priest and old_priest.valid then
    spawn_priest_smoke_for_entity(old_priest, true)
    if type(_G.tech_priests_destroy_priest_authorized_0499) ~= "function" or not _G.tech_priests_destroy_priest_authorized_0499(old_priest, "respawn_pair_priest-old-priest", pair, { allow_replacement = true }) then return false end
  end
  if old_unit then
    storage.tech_priests.station_by_priest[old_unit] = nil
  end
''',
    '''  if old_priest and old_priest.valid then return false end
  if old_unit then
    storage.tech_priests.station_by_priest[old_unit] = nil
    if storage.tech_priests.pairs_by_priest then storage.tech_priests.pairs_by_priest[old_unit] = nil end
  end
''',
    "canonical respawn old priest handling",
)
text = replace_once(
    text,
    '''  spawn_priest_smoke_for_entity(priest, true)
  set_health_ratio(priest, old_health_ratio)
  pair.priest = priest
''',
    '''  spawn_priest_smoke_for_entity(priest, true)
  set_health_ratio(priest, old_health_ratio)
  pcall(function() priest.destructible = false end)
  pcall(function() priest.active = true end)
  pair.priest = priest
''',
    "canonical respawn preservation",
)
text = replace_once(
    text,
    '''  pair.mode = "deploying"
  pair.target = nil
  pair.combat_target = nil
  pair.last_recall_tick = game.tick
  storage.tech_priests.station_by_priest[priest.unit_number] = station.unit_number
  storage.tech_priests.pairs_by_station[station.unit_number] = pair
  apply_pair_display_names(pair)
  return_to_station(priest, station)
  return true
end

ensure_pair_priest = function(pair, force_recall, immediate)
''',
    '''  pair.mode = "idle"
  pair.target = nil
  pair.combat_target = nil
  pair.movement_request_0418 = nil
  pair.pathing_target_0418 = nil
  pair.recalling = nil
  pair.pending_recall = nil
  pair.force_recall = nil
  pair.last_recovery_tick = game.tick
  storage.tech_priests.pairs_by_priest = storage.tech_priests.pairs_by_priest or {}
  storage.tech_priests.station_by_priest[priest.unit_number] = station.unit_number
  storage.tech_priests.pairs_by_priest[priest.unit_number] = pair
  storage.tech_priests.pairs_by_station[station.unit_number] = pair
  apply_pair_display_names(pair)
  if type(_G.tech_priests_note_recovered_priest_0499) ~= "function"
    or not _G.tech_priests_note_recovered_priest_0499(pair, priest, reason)
  then return false end
  return true
end

_G.tech_priests_canonical_respawn_pair_priest_0503 = respawn_pair_priest

ensure_pair_priest = function(pair, force_recall, immediate)
''',
    "canonical respawn completion",
)
write(path, text)

# Rewrite 0503 as a broker-only controlled missing-priest recovery executor.
write(
    "tech-priests_src/scripts/core/priest_recovery_safety_0503.lua",
    '''-- scripts/core/priest_recovery_safety_0503.lua
-- Broker-owned controlled missing-priest recovery only. This module does not
-- wrap lifecycle globals, recall or teleport valid priests, perform mobility
-- swaps, issue movement commands, create entities directly, or own a timer.

local M = {
  version = "0.1.674-dev",
  storage_key = "priest_recovery_safety_0503",
  service_name = "priest_missing_recovery_0503",
  service_interval = 43,
  service_budget = 8,
  recovery_reason = "controlled-missing-recovery-0503",
  recovery_owner = "priest_recovery_safety_0503",
  recovery_kind = "missing-priest-recovery",
  broker_required = true,
  movement_ownership_retired = true,
  recall_ownership_retired = true,
  mobility_ownership_retired = true,
}

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function safe(value) if value == nil then return "nil" end local ok, out = pcall(tostring, value); return ok and out or "?" end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version, enabled = true, stats = {}, recent = {},
  }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  if root.enabled == nil then root.enabled = true end
  root.stats = root.stats or {}
  root.recent = root.recent or {}
  root.recovery_teleports = nil
  root.authorized_mobility_swap = nil
  root.restore_watchdogs = nil
  return root
end

local function stat(name, amount)
  local root = M.root()
  root.stats[name] = (root.stats[name] or 0) + (amount or 1)
end

local function record(action, pair, detail)
  local root = M.root()
  stat(action)
  root.recent[#root.recent + 1] = {
    tick = now(), action = tostring(action), station = station_unit(pair), detail = tostring(detail or ""),
  }
  while #root.recent > 96 do table.remove(root.recent, 1) end
end

local function lifecycle_authority()
  return rawget(_G, "TechPriestsPriestLifecycleAuthority0499")
end

function M.service_pair(pair)
  if not (pair and valid(pair.station)) then return false, "invalid-pair" end
  local lifecycle = lifecycle_authority()
  if not (lifecycle and type(lifecycle.service_pair) == "function"
    and type(lifecycle.authorize_missing_recovery) == "function")
  then return false, "lifecycle-authority-unavailable" end

  lifecycle.service_pair(pair)
  if valid(pair.priest) then return false, "valid-or-rebound" end
  local state = pair.lifecycle_0499
  if not (state and state.missing_since) then return false, "missing-not-observed" end

  local options = {
    owner = M.recovery_owner,
    kind = M.recovery_kind,
    request_missing_recovery = true,
  }
  local authorized, why = lifecycle.authorize_missing_recovery(pair, M.recovery_reason, options)
  if not authorized then return false, why or "lease-denied" end

  local canonical_respawn = rawget(_G, "tech_priests_canonical_respawn_pair_priest_0503")
  if type(canonical_respawn) ~= "function" then
    record("canonical-respawn-unavailable-0503", pair, "lease-issued")
    return false, "canonical-respawn-unavailable"
  end
  local ok, recovered = pcall(canonical_respawn, pair, M.recovery_reason)
  if ok and recovered == true and valid(pair.priest) then
    record("controlled-missing-recovery-complete-0503", pair, "priest=" .. safe(pair.priest.unit_number))
    return true, "recovered"
  end
  record("controlled-missing-recovery-failed-0503", pair, "ok=" .. safe(ok) .. " result=" .. safe(recovered))
  return false, "canonical-respawn-failed"
end

function M.service(_, budget)
  local root = M.root()
  if root.enabled == false then return { processed = 0, acted = 0, detail = "disabled" } end
  local limit = math.max(1, math.min(64, math.floor(tonumber(budget) or M.service_budget)))
  local processed, acted = 0, 0
  for _, pair in pairs(pair_map()) do
    if processed >= limit then break end
    if pair and valid(pair.station) and not valid(pair.priest) then
      processed = processed + 1
      local recovered = M.service_pair(pair)
      if recovered then acted = acted + 1 end
    end
  end
  root.stats.service_processed = (root.stats.service_processed or 0) + processed
  root.stats.service_acted = (root.stats.service_acted or 0) + acted
  return { processed = processed, acted = acted, exhausted = processed >= limit, detail = "controlled-missing-priest-recovery" }
end

function M.install()
  if M._installed then return true end
  M.root()
  local lifecycle = lifecycle_authority()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not (lifecycle and type(lifecycle.authorize_missing_recovery) == "function"
    and type(rawget(_G, "tech_priests_canonical_respawn_pair_priest_0503")) == "function"
    and broker and type(broker.register_service) == "function")
  then return false end
  local registered = broker.register_service({
    name = M.service_name,
    category = "pair-lifecycle",
    interval = M.service_interval,
    priority = 26,
    budget = M.service_budget,
    fn = M.service,
    note = "one-shot 0499 lease recovery for observed missing priests only",
  })
  if not registered then return false end
  _G.TechPriestsPriestRecoverySafety0503 = M
  M._installed = true
  if log then log("[Tech-Priests 0.1.674-dev] broker-owned controlled missing-priest recovery installed") end
  return true
end

return M
''',
)

# Update loader documentation and remove the historical command.
path = "tech-priests_src/control.lua"
text = read(path)
text = replace_once(
    text,
    '''-- 0.1.503: recovery safety restoration. Loaded after the vanish guards so the
-- 0.1.502 station-side acquisition fix stays active while legitimate recall,
-- missing-priest rescue, watchdog roots, and authorized belt-immunity mobility
-- swaps are restored for behavior verification.
''',
    '''-- 0.1.674-dev: broker-owned controlled missing-priest recovery. Loaded after
-- 0499 so only an observed missing priest can receive and consume a one-shot
-- replacement lease; valid priests are never recalled, teleported, or swapped.
''',
    "control 0503 comment",
)
write(path, text)

path = "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua"
text = read(path)
text = replace_once(
    text,
    '  ["tp-movement-recovery-0508"] = true,\n',
    '  ["tp-movement-recovery-0508"] = true,\n  ["tp-priest-recovery-0503"] = true,\n',
    "runtime cleanup 0503 command",
)
write(path, text)

# Update the earlier 0500 boundary to follow the canonical lease respawn.
path = "tools/check_lifecycle_seal_0500_boundary_0771.py"
text = read(path)
text = text.replace('    "recovery": ROOT / "tech-priests_src/scripts/core/priest_recovery_safety_0503.lua",\n', '')
text = replace_once(
    text,
    '''    "lifecycle": ('destruction_authority_integrated = true', 'replacement_authority_integrated = true', 'function M.replacement_authorized', 'function M.destruction_authorized', 'function M.destroy_priest_authorized', 'tech_priests_priest_replacement_authorized_0499', 'tech_priests_destroy_priest_authorized_0499', 'allow_station_cleanup == true', 'station-cleanup-remove_pair_for_entity'),
''',
    '''    "lifecycle": ('destruction_authority_integrated = true', 'replacement_authority_integrated = true', 'controlled_missing_recovery = true', 'function M.authorize_missing_recovery', 'function M.consume_replacement_lease', 'function M.note_recovered_priest', 'function M.replacement_authorized', 'function M.destruction_authorized', 'function M.destroy_priest_authorized', 'tech_priests_priest_replacement_authorized_0499', 'tech_priests_destroy_priest_authorized_0499', 'allow_station_cleanup == true', 'station-cleanup-remove_pair_for_entity'),
''',
    "0771 lifecycle requirements",
)
text = replace_once(
    text,
    '''    "part2": ('priest.destructible = false', 'storage.tech_priests.pairs_by_priest[priest.unit_number] = pair', 'tech_priests_priest_replacement_authorized_0499', 'tech_priests_destroy_priest_authorized_0499'),
''',
    '''    "part2": ('priest.destructible = false', 'storage.tech_priests.pairs_by_priest[priest.unit_number] = pair', 'tech_priests_consume_replacement_lease_0499', 'tech_priests_note_recovered_priest_0499', 'tech_priests_canonical_respawn_pair_priest_0503'),
''',
    "0771 part2 requirements",
)
text = text.replace('    "recovery": (\'tech_priests_destroy_priest_authorized_0499\', \'mobility-swap-denied-0503\'),\n', '')
text = replace_once(
    text,
    '''    "part2": ('tech_priests_destroy_priest_0500',),
''',
    '''    "part2": ('tech_priests_destroy_priest_0500', 'return_to_station(priest, station)'),
''',
    "0771 part2 forbidden",
)
text = text.replace('    "recovery": (\'tech_priests_destroy_priest_0500\', \'TechPriestsPriestLifecycleSeal0500\', \'pair.lifecycle_0500\', \'allow_station_cleanup = true\', \'life499.service_pair =\'),\n', '')
write(path, text)

# New focused source boundary.
write(
    "tools/check_priest_recovery_0503_boundary_0774.py",
    '''#!/usr/bin/env python3
"""Validate 0499 one-shot leases, canonical respawn, and broker-only 0503 recovery."""
from __future__ import annotations
import pathlib
import sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "lifecycle": ROOT / "tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua",
    "recovery": ROOT / "tech-priests_src/scripts/core/priest_recovery_safety_0503.lua",
    "respawn": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_002.lua",
    "control": ROOT / "tech-priests_src/control.lua",
    "cleanup": ROOT / "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
    "integration": ROOT / "tools/check_development_integration_0732.py",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
}
REQUIRED = {
    "lifecycle": ('controlled_missing_recovery = true', 'M.missing_recovery_delay_ticks = 180', 'M.replacement_lease_ticks = 30', 'function M.authorize_missing_recovery', 'function M.consume_replacement_lease', 'function M.note_recovered_priest', 'controlled-missing-recovery-0503', 'priest_recovery_safety_0503', 'missing-priest-recovery', 'tech_priests_authorize_missing_recovery_0499', 'tech_priests_consume_replacement_lease_0499', 'tech_priests_note_recovered_priest_0499'),
    "recovery": ('service_name = "priest_missing_recovery_0503"', 'broker_required = true', 'movement_ownership_retired = true', 'recall_ownership_retired = true', 'mobility_ownership_retired = true', 'function M.service_pair', 'function M.service(_, budget)', 'lifecycle.authorize_missing_recovery', 'tech_priests_canonical_respawn_pair_priest_0503', 'broker.register_service', 'one-shot 0499 lease recovery for observed missing priests only'),
    "respawn": ('tech_priests_consume_replacement_lease_0499', 'owner = "priest_recovery_safety_0503"', 'kind = "missing-priest-recovery"', 'storage.tech_priests.pairs_by_priest[priest.unit_number] = pair', 'tech_priests_note_recovered_priest_0499', 'tech_priests_canonical_respawn_pair_priest_0503 = respawn_pair_priest'),
    "control": ('broker-owned controlled missing-priest recovery', 'one-shot replacement lease'),
    "cleanup": ('["tp-priest-recovery-0503"] = true',),
    "integration": ('priest_missing_recovery_0503', 'check_priest_recovery_0503_boundary_0774.py'),
    "workflow": ('Audit broker-owned 0503 missing-priest recovery', 'check_priest_recovery_0503_boundary_0774.py'),
}
FORBIDDEN = {
    "recovery": ('_G.respawn_pair_priest =', '_G.ensure_pair_priest =', 'teleport(', 'create_entity', 'set_command', 'tech_priests_request_movement_0418', 'commands.add_command', 'script.on_nth_tick', 'TechPriestsRuntimeEventRegistry', 'registry.on_nth_tick', 'pair.mode =', 'pair.target =', 'upgrade_pair_priest_to_current_mobility', 'sanity_recall_all_priests'),
    "respawn": ('return_to_station(priest, station)', 'tech_priests_priest_replacement_authorized_0499(pair, reason or "respawn"'),
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
        print("0503 recovery boundary audit failed:", file=sys.stderr)
        for error in errors: print("  - " + error, file=sys.stderr)
        return 1
    print("0503 recovery boundary audit passed: 0499 leases one missing recovery; canonical respawn consumes it; 0503 is broker-only.")
    return 0
if __name__ == "__main__": raise SystemExit(main())
''',
)

# Integration and governance know the new service/checker.
path = "tools/check_development_integration_0732.py"
text = read(path)
text = replace_once(
    text,
    '    "behavior_stack_cleanup_0509", "priest_lifecycle_observation_0499",\n',
    '    "behavior_stack_cleanup_0509", "priest_lifecycle_observation_0499", "priest_missing_recovery_0503",\n',
    "integration recovery service",
)
text = replace_once(
    text,
    '"check_mobility_recovery_0506_0508_boundary_0773.py",\n',
    '"check_mobility_recovery_0506_0508_boundary_0773.py", "check_priest_recovery_0503_boundary_0774.py",\n',
    "integration recovery checker",
)
write(path, text)

path = "tools/check_governance_prerequisites_0738.py"
text = read(path)
text = replace_once(
    text,
    '''        "Audit retired 0506 and 0508 recovery wrappers",
        "check_mobility_recovery_0506_0508_boundary_0773.py",
''',
    '''        "Audit retired 0506 and 0508 recovery wrappers",
        "check_mobility_recovery_0506_0508_boundary_0773.py",
        "Audit broker-owned 0503 missing-priest recovery",
        "check_priest_recovery_0503_boundary_0774.py",
''',
    "governance recovery checker",
)
write(path, text)

# Current ownership documents; graph count remains 26/43.
path = "tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md"
text = read(path)
anchor = '`mobility_recovery_contract_0506` and `movement_recovery_authority_0508` are retired together. Visible movement belongs to `movement_controller`, direct work to `0513`, pair observation to `0499`, and controlled missing recovery temporarily to `0503`.'
if anchor not in text: raise SystemExit("continuity recovery paragraph missing")
text = text.replace(anchor, anchor + '\n\n`priest_recovery_safety_0503` is now narrow and broker-owned. It may request only the exact `controlled-missing-recovery-0503` lease after `0499` has observed a missing priest. The generated canonical respawn consumes that one-shot lease, restores every reverse map, and reports recovery to `0499` without recall, teleport, mobility replacement, or movement commands.', 1)
write(path, text)

path = "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
text = read(path)
anchor = '`0506` and `0508` are inert; neither can wrap recovery globals, mutate movement, or register a cadence.'
if anchor not in text: raise SystemExit("testing recovery paragraph missing")
text = text.replace(anchor, anchor + ' `0503` is broker-only and can recover only an observed missing priest through a one-shot `0499` lease and the canonical generated respawn.', 1)
write(path, text)

path = "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
text = read(path)
anchor = '`0506` and `0508` are retired as overlapping mobility/recovery contracts. Their movement and direct-acquisition behavior was already native to `movement_controller` and `0513`; their pair validation is native to `0499`; their fallback timers and command surfaces are removed.'
if anchor not in text: raise SystemExit("authority map recovery paragraph missing")
text = text.replace(anchor, anchor + '\n\n`0503` remains active only as the broker-owned controlled missing-priest executor. `0499` observes the missing state, delays and rate-limits the attempt, issues a one-shot exact-owner lease, and the generated canonical respawn consumes that lease before creating a replacement. No valid priest is recalled, teleported, swapped, or destroyed by this route.', 1)
write(path, text)

path = "docs/DEVELOPMENT_HISTORY.md"
text = read(path)
section = '''### Narrowed `0503` to one-shot missing-priest recovery

`priest_recovery_safety_0503` previously combined reverse-map repair, valid-priest recall teleports, nearby rebinding, direct entity creation, mobility replacement, global ensure/respawn/recall wrappers, watchdog restoration, diagnostics, a command, and a 41-tick route. It is now a broker-owned executor for one case only: a Cogitator Station remains valid, its priest has been observed missing by `0499`, conservative orphan rebinding failed, and the observation delay and retry cooldown have elapsed.

`0499` issues an exact-owner, exact-kind, short-lived, one-shot replacement lease. The authoritative generated `respawn_pair_priest` consumes that lease before creation, refuses to replace a valid priest, restores `pairs_by_station`, `pairs_by_priest`, and `station_by_priest`, preserves the new priest, and reports recovery back to `0499`. It no longer commands the priest to return to a station after spawning beside it. The declarative graph remains **26 active hardeners and 43 retired source-only authorities**.

Complete Source validation and Factorio runtime evidence remain separately required.

'''
if '### Narrowed `0503` to one-shot missing-priest recovery' not in text:
    text = replace_once(text, '## Current Gate State', section + '## Current Gate State', "history current gate")
write(path, text)

# Remove the completed temporary audit workflow and this patch script.
for temporary in (
    ROOT / ".github/workflows/audit-0503-narrowing-temp.yml",
    Path(__file__),
):
    if temporary.exists(): temporary.unlink()
