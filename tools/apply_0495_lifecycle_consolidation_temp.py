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


# Retire the overlapping pair-link wrapper.
write(
    "tech-priests_src/scripts/core/pair_link_hardening_0495.lua",
    '''-- scripts/core/pair_link_hardening_0495.lua
-- Source-preserved retirement marker. Pair identity, reverse-map repair,
-- conservative orphan rebinding, and missing-priest observation are native to
-- priest_lifecycle_authority_0499. This module may not install or rescue.
local M = {
  retired = true,
  authority = "pair_link_hardening_0495",
  replacement = "priest_lifecycle_authority_0499",
}
return M
''',
)

# Consolidate useful pair-link observation into the canonical lifecycle owner.
path = "tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua"
text = read(path)
text = replace_once(text, 'M.version = "0.1.499"', 'M.version = "0.1.674-dev"', "0499 version")
text = replace_once(
    text,
    'M.tick_interval = 53\nM.rebind_radius = 18\n',
    'M.tick_interval = 53\nM.service_budget = 24\nM.rebind_radius = 18\nM.broker_required = true\nM.pair_link_integrated = true\n',
    "0499 constants",
)
text = replace_once(
    text,
    '  r.known_destroy_sites = r.known_destroy_sites or {}\n  return r\n',
    '  r.known_destroy_sites = r.known_destroy_sites or {}\n  r.pair_link_integrated = true\n  return r\n',
    "0499 root integration",
)
text = text.replace('[Tech-Priests 0.1.499]', '[Tech-Priests 0.1.674-dev]')
text = replace_once(
    text,
    '  local n = valid(pair and pair.station) and pair.station.name or tostring(pair and pair.station_name_0495 or pair and pair.station_name or "")\n',
    '  local n = valid(pair and pair.station) and pair.station.name or tostring(pair and pair.station_name or "")\n',
    "0499 rank compatibility",
)
text = replace_once(
    text,
    '''    pair.paused_by_missing_priest_0498 = nil
    pair.lost_priest_0490 = nil
    pair.link_0495 = pair.link_0495 or {}
    pair.link_0495.missing_since = nil
    repair_reverse_maps(pair, "rebound-nearby-orphan-0499")
    record("rebound-nearby-orphan", pair, "entity=" .. describe_entity(best) .. " distance_sq=" .. safe(best_d))
''',
    '''    pair.paused_by_missing_priest_0498 = nil
    pair.lost_priest_0490 = nil
    pair.lifecycle_0499 = pair.lifecycle_0499 or {}
    pair.lifecycle_0499.missing_since = nil
    pair.lifecycle_0499.last_rebound_tick = now()
    pair.lifecycle_0499.last_rebound_distance_sq = best_d
    repair_reverse_maps(pair, "rebound-nearby-orphan-0499")
    record("rebound-nearby-orphan", pair, "entity=" .. describe_entity(best) .. " distance_sq=" .. safe(best_d))
''',
    "0499 rebound state",
)
text = replace_once(
    text,
    '''
  local link = rawget(_G, "TechPriestsPairLinkHardening0495")
  if link and type(link.service_pair) == "function" and not link.service_pair_no_respawn_0499 then
    link.service_pair_no_respawn_0499 = true
    link.service_pair = function(pair)
      if not (pair and valid(pair.station)) then return false end
      if valid(pair.priest) then
        repair_reverse_maps(pair, "pair-link-no-respawn-valid-0499")
        if pair.link_0495 then pair.link_0495.missing_since = nil end
        clear_stuck_recovery_flags(pair)
        return true
      end
      if rebind_nearby_orphan(pair) then return true end
      pair.link_0495 = pair.link_0495 or {}
      pair.link_0495.missing_since = pair.link_0495.missing_since or now()
      pair.link_0495.rescue_disabled_0499 = true
      clear_stuck_recovery_flags(pair)
      record("pair-link-rescue-disabled", pair, "missing_for=" .. safe(now() - (pair.link_0495.missing_since or now())) .. " no respawn")
      return false
    end
    link.service_all = function()
      for _, pair in pairs(pair_map()) do link.service_pair(pair) end
      return true
    end
  end
''',
    '\n',
    "0499 pair-link wrapper removal",
)
text = replace_once(
    text,
    '''function M.service_pair(pair)
  if not (pair and valid(pair.station)) then return false end
  if valid(pair.priest) then
    repair_reverse_maps(pair, "lifecycle-service-0499")
    clear_stuck_recovery_flags(pair)
    return true
  end
  if rebind_nearby_orphan(pair) then return true end
  clear_stuck_recovery_flags(pair)
  record("missing-priest-no-respawn", pair, "station valid; respawn/recall disabled until delete source is isolated")
  return false
end

function M.service_all()
  local r = root(); if r.enabled == false then return end
  disable_stuck_watchdog_roots()
  for _, pair in pairs(pair_map()) do M.service_pair(pair) end
end
''',
    '''function M.service_pair(pair)
  if not (pair and valid(pair.station)) then return false end
  pair.lifecycle_0499 = pair.lifecycle_0499 or {}
  local lifecycle = pair.lifecycle_0499
  if valid(pair.priest) then
    repair_reverse_maps(pair, "lifecycle-service-0499")
    lifecycle.missing_since = nil
    lifecycle.last_missing_report_tick = nil
    clear_stuck_recovery_flags(pair)
    return true
  end
  if rebind_nearby_orphan(pair) then return true end
  lifecycle.missing_since = lifecycle.missing_since or now()
  clear_stuck_recovery_flags(pair)
  if not lifecycle.last_missing_report_tick or now() - lifecycle.last_missing_report_tick >= 600 then
    lifecycle.last_missing_report_tick = now()
    record("missing-priest-no-respawn", pair, "missing_for=" .. safe(now() - lifecycle.missing_since) .. " station valid; replacement remains disabled")
  end
  return false
end

function M.service_all(_, budget)
  local r = root()
  if r.enabled == false then return { processed = 0, acted = 0, detail = "disabled" } end
  disable_stuck_watchdog_roots()
  local limit = math.max(1, math.min(128, math.floor(tonumber(budget) or M.service_budget)))
  local processed, acted = 0, 0
  for _, pair in pairs(pair_map()) do
    if processed >= limit then break end
    if pair and valid(pair.station) then
      processed = processed + 1
      if M.service_pair(pair) then acted = acted + 1 end
    end
  end
  r.stats.service_processed = (r.stats.service_processed or 0) + processed
  r.stats.service_acted = (r.stats.service_acted or 0) + acted
  return { processed = processed, acted = acted, exhausted = processed >= limit, detail = "lifecycle-observation-only" }
end
''',
    "0499 service consolidation",
)
text = replace_once(
    text,
    '''function M.register_events()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  if R and defines and defines.events then
    R.on_event({ defines.events.on_entity_died, defines.events.script_raised_destroy, defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined }, function(event) return M.handle_removed(event) end, nil, { owner = "priest_lifecycle_authority_0499", category = "pair-lifecycle", priority = "last" })
    R.on_nth_tick(M.tick_interval, function() M.service_all() end, { owner = "priest_lifecycle_authority_0499", category = "pair-lifecycle", priority = "last" })
  elseif script and script.on_nth_tick then
    pcall(function() script.on_nth_tick(M.tick_interval, function() M.service_all() end) end)
  end
end
''',
    '''function M.register_events()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and defines and defines.events then
    registry.on_event({ defines.events.on_entity_died, defines.events.script_raised_destroy, defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined }, function(event) return M.handle_removed(event) end, nil, { owner = "priest_lifecycle_authority_0499", category = "pair-lifecycle", priority = "last" })
    return true
  end
  return false
end

function M.register_broker_service()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not broker then pcall(function() broker = require("scripts.core.runtime_tick_broker") end) end
  if not (broker and type(broker.register_service) == "function") then return false end
  return broker.register_service({
    name = "priest_lifecycle_observation_0499",
    category = "pair-lifecycle",
    interval = M.tick_interval,
    priority = 24,
    budget = M.service_budget,
    fn = M.service_all,
    note = "reverse-map repair, conservative orphan rebind, and missing-priest observation only",
  }) ~= false
end
''',
    "0499 broker/event registration",
)
text = replace_once(
    text,
    '''  M.wrap_pair_dump()
  M.register_events()
  M.register_commands()
  if log then log("[Tech-Priests 0.1.674-dev] priest lifecycle authority installed; respawn/recall/orphan-purge/stuck watchdog deletion paths disabled") end
''',
    '''  M.wrap_pair_dump()
  M.register_events()
  if not M.register_broker_service() then M.installed = false; return false end
  M.register_commands()
  if log then log("[Tech-Priests 0.1.674-dev] broker-owned priest lifecycle observation installed; replacement remains disabled") end
''',
    "0499 install registration",
)
if 'TechPriestsPairLinkHardening0495' in text or 'pair.link_0495' in text:
    raise SystemExit("0499 retains pair-link wrapper/state dependency")
if 'R.on_nth_tick' in text or 'script.on_nth_tick' in text:
    raise SystemExit("0499 retains periodic fallback")
write(path, text)

# Remove the retired loader while retaining the unrelated mining sensor.
path = "tech-priests_src/control.lua"
text = read(path)
old = '''pcall(function()
  local Pair0495 = require("scripts.core.pair_link_hardening_0495")
  if Pair0495 and Pair0495.install then Pair0495.install() end
end)
'''
text = replace_once(text, old, '-- Historical 0495 pair-link wrapper is retired into priest_lifecycle_authority_0499.\n', "control 0495 loader")
write(path, text)

# Remove the retired diagnostic command during migration and periodic cleanup.
path = "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua"
text = read(path)
text = replace_once(text, '  ["tp-vanish-guard-0502"] = true,\n', '  ["tp-vanish-guard-0502"] = true,\n  ["tp-pair-link-0495"] = true,\n', "runtime cleanup 0495 command")
write(path, text)

# Advance the declarative graph.
path = "tech-priests_src/scripts/core/planning_constraints_0646.lua"
text = read(path)
text = replace_once(text, 'active_hardener_count=26,retired_authority_count=38', 'active_hardener_count=26,retired_authority_count=39', "planning count")
text = replace_once(
    text,
    ' ["scripts.core.priest_vanish_guard_0502"]="station-side direct acquisition and movement quarantine are obsolete under canonical 0513 and movement ownership",\n',
    ' ["scripts.core.priest_vanish_guard_0502"]="station-side direct acquisition and movement quarantine are obsolete under canonical 0513 and movement ownership",\n ["scripts.core.pair_link_hardening_0495"]="reverse-map repair, conservative orphan rebinding, and missing-priest observation are native to priest_lifecycle_authority_0499",\n',
    "planning retired 0495",
)
write(path, text)

# Focused checker for the new lifecycle boundary.
write(
    "tools/check_pair_link_0495_boundary_0770.py",
    '''#!/usr/bin/env python3
"""Validate retired 0495 and broker-owned canonical lifecycle observation in 0499."""
from __future__ import annotations
import pathlib
import sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "retired": ROOT / "tech-priests_src/scripts/core/pair_link_hardening_0495.lua",
    "lifecycle": ROOT / "tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua",
    "control": ROOT / "tech-priests_src/control.lua",
    "cleanup": ROOT / "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
    "planning": ROOT / "tech-priests_src/scripts/core/planning_constraints_0646.lua",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
}
REQUIRED = {
    "retired": ('retired = true', 'authority = "pair_link_hardening_0495"', 'replacement = "priest_lifecycle_authority_0499"', 'return M'),
    "lifecycle": ('version = "0.1.674-dev"', 'broker_required = true', 'pair_link_integrated = true', 'local function repair_reverse_maps', 'local function rebind_nearby_orphan', 'lifecycle.missing_since', 'function M.register_broker_service', 'name = "priest_lifecycle_observation_0499"', 'broker.register_service', 'function M.service_all(_, budget)'),
    "control": ('Historical 0495 pair-link wrapper is retired into priest_lifecycle_authority_0499',),
    "cleanup": ('["tp-pair-link-0495"] = true',),
    "planning": ('retired_authority_count=39', '["scripts.core.pair_link_hardening_0495"]'),
    "workflow": ('Audit retired 0495 pair-link authority', 'check_pair_link_0495_boundary_0770.py'),
}
FORBIDDEN = {
    "retired": ('function M.install', 'ensure_pair_priest', 'respawn_pair_priest', 'commands.add_command', 'on_nth_tick', 'register_service', 'pair.target', 'pair.mode'),
    "lifecycle": ('TechPriestsPairLinkHardening0495', 'pair.link_0495', 'R.on_nth_tick', 'registry.on_nth_tick', 'script.on_nth_tick'),
    "control": ('require("scripts.core.pair_link_hardening_0495")',),
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
        print("0495 lifecycle boundary audit failed:", file=sys.stderr)
        for error in errors: print("  - " + error, file=sys.stderr)
        return 1
    print("0495 lifecycle boundary audit passed: pair-link wrapper is inert; 0499 owns broker-budgeted observation without replacement.")
    return 0
if __name__ == "__main__": raise SystemExit(main())
''',
)

# Existing focused checkers must follow the live graph count.
for path in (
    "tools/check_movement_cadence_boundary_0761.py",
    "tools/check_combat_proxy_boundary_0762.py",
    "tools/check_direct_acquisition_bounds_boundary_0764.py",
    "tools/check_movement_enforcement_void_boundary_0765.py",
    "tools/check_movement_economy_boundary_0767.py",
    "tools/check_ground_route_loader_boundary_0768.py",
    "tools/check_priest_vanish_0502_boundary_0769.py",
):
    text = read(path)
    if 'retired_authority_count=38' not in text:
        raise SystemExit(f"count anchor missing: {path}")
    write(path, text.replace('retired_authority_count=38', 'retired_authority_count=39'))

# Architecture and integration graph checkers.
path = "tools/check_recovery_architecture_0744.py"
text = read(path)
text = replace_once(text, '"scripts.core.ground_route_authority_0633", "scripts.core.priest_vanish_guard_0502", "scripts.core.fluid_output_sink_doctrine_0694",', '"scripts.core.ground_route_authority_0633", "scripts.core.priest_vanish_guard_0502", "scripts.core.pair_link_hardening_0495", "scripts.core.fluid_output_sink_doctrine_0694",', "architecture retired set")
text = text.replace('retired_authority_count=38', 'retired_authority_count=39')
text = text.replace('"Thirty-eight files remain"', '"Thirty-nine files remain"')
text = text.replace('"38 source-preserved authorities"', '"39 source-preserved authorities"')
text = text.replace('"26 active hardeners and 38 explicitly retired"', '"26 active hardeners and 39 explicitly retired"')
write(path, text)

path = "tools/check_development_integration_0732.py"
text = read(path)
text = replace_once(text, '    "scripts.core.priest_vanish_guard_0502",\n', '    "scripts.core.priest_vanish_guard_0502",\n    "scripts.core.pair_link_hardening_0495",\n', "integration retired set")
text = text.replace('retired_authority_count=38', 'retired_authority_count=39')
text = replace_once(text, '    "behavior_stack_cleanup_0509",\n', '    "behavior_stack_cleanup_0509", "priest_lifecycle_observation_0499",\n', "integration critical service")
text = replace_once(text, '"check_priest_vanish_0502_boundary_0769.py",\n', '"check_priest_vanish_0502_boundary_0769.py", "check_pair_link_0495_boundary_0770.py",\n', "integration workflow checker")
write(path, text)

# Governance checker follows only current graph declarations.
path = "tools/check_governance_prerequisites_0738.py"
text = read(path)
for old, new in (
    ('26-active / 38-retired graph', '26-active / 39-retired graph'),
    ('26 active hardeners and 38 explicitly retired', '26 active hardeners and 39 explicitly retired'),
    ('26 active hardeners and 38 retired source-only authorities', '26 active hardeners and 39 retired source-only authorities'),
    ('38 source-preserved authorities', '39 source-preserved authorities'),
    ('38 retired source-only authorities', '39 retired source-only authorities'),
    ('Thirty-eight files remain', 'Thirty-nine files remain'),
):
    text = text.replace(old, new)
text = replace_once(text, '        "check_priest_vanish_0502_boundary_0769.py",\n', '        "check_priest_vanish_0502_boundary_0769.py",\n        "Audit retired 0495 pair-link authority",\n        "check_pair_link_0495_boundary_0770.py",\n', "governance workflow 0770")
write(path, text)

# Current governance documents.
path = "tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md"
text = read(path).replace('**38 source-preserved authorities**', '**39 source-preserved authorities**', 1)
anchor = 'The `RETIRED` table contains **39 source-preserved authorities**. It is not a secondary loader. A retired module may remain for historical comparison but may not install, register a cadence, wrap a canonical API, mutate pair state, or perform physical work.'
if anchor not in text: raise SystemExit("continuity count paragraph missing")
text = text.replace(anchor, anchor + '\n\n`pair_link_hardening_0495` is retired. Reverse-map truth, conservative nearby orphan rebinding, and missing-priest observation are native to broker-owned `priest_lifecycle_authority_0499`; replacement remains disabled.', 1)
write(path, text)

path = "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
text = read(path)
text = text.replace('26 active hardeners and 38 retired source-only authorities', '26 active hardeners and 39 retired source-only authorities', 1)
text = text.replace('26 attempted active hardeners and 38 retired source-only authorities', '26 attempted active hardeners and 39 retired source-only authorities', 1)
anchor = 'The current declarative graph contains **26 active hardeners and 39 retired source-only authorities**.'
if anchor not in text: raise SystemExit("testing current graph missing")
text = text.replace(anchor, anchor + ' `0495` is inert; `0499` owns broker-budgeted pair identity and missing-priest observation without authorizing replacement.', 1)
write(path, text)

path = "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
text = read(path)
text = text.replace('**26 declarative active hardeners** and **38 retired source-only authorities**', '**26 declarative active hardeners** and **39 retired source-only authorities**', 1)
text = text.replace('Thirty-eight files remain source-preserved', 'Thirty-nine files remain source-preserved', 1)
anchor = '`0502` is also retired: station-side acquisition, movement quarantine, and anti-slam task mutation are obsolete under the canonical executor and movement controller. `0509` remains only as broker-owned passive reverse-map and UI/cascade maintenance.'
if anchor not in text: raise SystemExit("authority map 0502 paragraph missing")
text = text.replace(anchor, anchor + '\n\n`0495` is retired as a parallel pair-link rescue authority. `0499` now owns reverse-map repair, conservative nearby orphan rebinding, and missing-priest observation through the runtime broker. Broad search and direct respawn remain forbidden.', 1)
write(path, text)

path = "docs/DEVELOPMENT_HISTORY.md"
text = read(path)
section = '''### Retired `0495` pair-link rescue wrapper

`pair_link_hardening_0495` duplicated reverse-map repair, orphan discovery, missing-priest observation, ensure/respawn wrappers, direct rescue attempts, a diagnostic command, and a separate timer. Its broad 96-tile orphan search and direct replacement calls were not retained.

`priest_lifecycle_authority_0499` now natively owns reverse-map truth, conservative nearby orphan rebinding, and rate-limited missing-priest observation through the runtime broker. Replacement remains disabled until the authoritative creation path is repaired. The graph is now **26 active hardeners and 39 explicitly retired source-only authorities**.

Complete Source validation and Factorio runtime evidence remain separately required.

'''
if '### Retired `0495` pair-link rescue wrapper' not in text:
    text = replace_once(text, '## Current Gate State', section + '## Current Gate State', "history current gate")
write(path, text)

path = "RECOVERY_REPAIR_SEQUENCE.md"
text = read(path).replace('26-active / 38-retired graph', '26-active / 39-retired graph', 1)
write(path, text)

# The reference-audit workflow and this deterministic script are temporary.
for temporary in (
    ROOT / ".github/workflows/audit-0495-retirement-references-temp.yml",
    Path(__file__),
):
    if temporary.exists(): temporary.unlink()
