#!/usr/bin/env python3
from pathlib import Path

ROOT = Path('.')
P1 = ROOT / 'tech-priests_src/scripts/generated/control_legacy_part_001.lua'
P2 = ROOT / 'tech-priests_src/scripts/generated/control_legacy_part_002.lua'
P3 = ROOT / 'tech-priests_src/scripts/generated/control_legacy_part_003.lua'
CLEAN = ROOT / 'tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua'
HISTORY = ROOT / 'docs/DEVELOPMENT_HISTORY.md'
COMMANDS = (
    'tp-priest-diag', 'tp-radii', 'tp-spawn-dump', 'tp-last-dump',
    'tp-list-pairs', 'tp-list-names', 'tp-legacy-snapshot', 'tp-cog-summary',
)

all_before = '\n'.join(path.read_text(encoding='utf-8', errors='replace') for path in (ROOT / 'tech-priests_src').rglob('*.lua'))
for command in COMMANDS:
    count = all_before.count(f'TechPriestsDebugCommandRegistry.add("{command}"') + all_before.count(f'commands.add_command("{command}"')
    if count != 1:
        raise SystemExit(f'{command}: expected one registration, found {count}')

p1 = P1.read_text(encoding='utf-8')
start = p1.index('-- 0.1.120 diagnostic command for live priest spawn-state validation.')
end = p1.index('-- 0.1.121 Rank-specific scan radius policy.', start)
p1 = p1[:start] + '''-- 0.1.674-dev / 0790: manual live-priest diagnostic command retired.
TECH_PRIESTS_0120_DEBUG_COMMAND_RETIRED = true


''' + p1[end:]
command_index = p1.index('TechPriestsDebugCommandRegistry.add("tp-radii"')
start = p1.rfind('if commands and commands.add_command then', 0, command_index)
end = p1.index('-- 0.1.124 Creation-time rank stat refresh.', command_index)
p1 = p1[:start] + '''-- 0.1.674-dev / 0790: manual rank-radius report command retired.
TECH_PRIESTS_0121_RADII_COMMAND_RETIRED = true


''' + p1[end:]
P1.write_text(p1, encoding='utf-8')

p2 = P2.read_text(encoding='utf-8')
start = p2.index('TechPriestsDebugCommandRegistry.add("tp-spawn-dump"')
end = p2.index('TECH_PRIESTS_PRIEST_ITEM_RESISTANCE_0125 = {', start)
p2 = p2[:start] + '''-- 0.1.674-dev / 0790: manual creation and last-spawn dump commands retired.
TECH_PRIESTS_0124_SPAWN_DUMP_COMMAND_RETIRED = true
TECH_PRIESTS_0124_LAST_DUMP_COMMAND_RETIRED = true

''' + p2[end:]
start = p2.index('TechPriestsDebugCommandRegistry.add("tp-list-pairs"')
end = p2.index('-- 0.1.128 Tech-Priest item tooltip and machine-scanner diagnostic surface.', start)
p2 = p2[:start] + '''-- 0.1.674-dev / 0790: manual pair and name listing commands retired.
TECH_PRIESTS_0127_LIST_PAIRS_COMMAND_RETIRED = true
TECH_PRIESTS_0127_LIST_NAMES_COMMAND_RETIRED = true


''' + p2[end:]
P2.write_text(p2, encoding='utf-8')

p3 = P3.read_text(encoding='utf-8')
start = p3.index('TechPriestsDebugCommandRegistry.add("tp-legacy-snapshot"')
end = p3.index('-- ============================================================================\n-- TECH PRIESTS 0.1.138 – FALLBACK CONTROL-RADIUS DIAGNOSTICS', start)
p3 = p3[:start] + '''-- 0.1.674-dev / 0790: manual legacy-task snapshot command retired.
TECH_PRIESTS_0137_LEGACY_SNAPSHOT_COMMAND_RETIRED = true


''' + p3[end:]
command_index = p3.index('TechPriestsDebugCommandRegistry.add("tp-cog-summary"')
start = p3.rfind('if commands and commands.add_command then', 0, command_index)
end = p3.index('tech_priests_log_0150("Cogitator inventory summary helper active")', command_index)
p3 = p3[:start] + '''-- 0.1.674-dev / 0790: manual Cogitator inventory summary command retired.
TECH_PRIESTS_0150_COG_SUMMARY_COMMAND_RETIRED = true

''' + p3[end:]
P3.write_text(p3, encoding='utf-8')

cleanup = CLEAN.read_text(encoding='utf-8')
anchor = '  ["tp-magos-planner-debug"] = true,'
insert = '''  ["tp-magos-planner-debug"] = true,
  ["tp-priest-diag"] = true,
  ["tp-radii"] = true,
  ["tp-spawn-dump"] = true,
  ["tp-last-dump"] = true,
  ["tp-list-pairs"] = true,
  ["tp-list-names"] = true,
  ["tp-legacy-snapshot"] = true,
  ["tp-cog-summary"] = true,'''
if insert not in cleanup:
    if cleanup.count(anchor) != 1:
        raise SystemExit('runtime cleanup anchor mismatch')
    cleanup = cleanup.replace(anchor, insert, 1)
CLEAN.write_text(cleanup, encoding='utf-8')

post = '\n'.join(path.read_text(encoding='utf-8', errors='replace') for path in (ROOT / 'tech-priests_src').rglob('*.lua'))
for command in COMMANDS:
    for prefix in ('TechPriestsDebugCommandRegistry.add("', 'commands.add_command("'):
        if prefix + command + '"' in post:
            raise SystemExit(f'retired command remains: {command}')
    if f'["{command}"] = true' not in post:
        raise SystemExit(f'cleanup missing: {command}')
for marker in (
    'TECH_PRIESTS_0120_DEBUG_COMMAND_RETIRED = true',
    'TECH_PRIESTS_0121_RADII_COMMAND_RETIRED = true',
    'TECH_PRIESTS_0124_SPAWN_DUMP_COMMAND_RETIRED = true',
    'TECH_PRIESTS_0124_LAST_DUMP_COMMAND_RETIRED = true',
    'TECH_PRIESTS_0127_LIST_PAIRS_COMMAND_RETIRED = true',
    'TECH_PRIESTS_0127_LIST_NAMES_COMMAND_RETIRED = true',
    'TECH_PRIESTS_0137_LEGACY_SNAPSHOT_COMMAND_RETIRED = true',
    'TECH_PRIESTS_0150_COG_SUMMARY_COMMAND_RETIRED = true',
):
    if marker not in post:
        raise SystemExit(f'marker missing: {marker}')
for required in (
    'function tech_priests_find_priest_for_player_0120(player)',
    'function rank_scan_radius(pair)',
    'TECH_PRIESTS_ACTIVE_PAIRS_0127',
    'TECH_PRIESTS_ACTIVE_NAMES_0127',
    'function tech_priests_inventory_summary_0150(inv)',
    'function tech_priests_cogitator_inventory_summary_0150(pair)',
    'tech_priests_log_0150("Cogitator inventory summary helper active")',
):
    if required not in post:
        raise SystemExit(f'preserved helper missing: {required}')

history = HISTORY.read_text(encoding='utf-8')
heading = '## 2026-07-21 — Milestone 0790: Legacy Observability Command Retirement'
if heading not in history:
    history += f'''\n\n{heading}\n\nRetired eight report-only legacy commands: live priest diagnostics, rank-radius reporting, spawn and last-spawn dumps, active pair and name listings, legacy task snapshots, and Cogitator inventory summaries. Shared priest lookup, rank-radius policy, creation diagnostics, active pair/name registries, legacy task state, and Cogitator inventory-summary helpers remain in source for automatic behavior and internal reporting. All eight stale command names are removed through runtime_command_cleanup_0720. Static Source validation does not constitute Factorio runtime proof.\n'''
    HISTORY.write_text(history, encoding='utf-8')

print('0790 legacy observability command retirement complete')
