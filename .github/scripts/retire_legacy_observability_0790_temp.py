#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path('.')
P1 = ROOT / 'tech-priests_src/scripts/generated/control_legacy_part_001.lua'
P2 = ROOT / 'tech-priests_src/scripts/generated/control_legacy_part_002.lua'
P3 = ROOT / 'tech-priests_src/scripts/generated/control_legacy_part_003.lua'
CLEAN = ROOT / 'tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua'
HISTORY = ROOT / 'docs/DEVELOPMENT_HISTORY.md'

COMMAND_MARKERS = {
    'tp-priest-diag': '-- 0.1.674-dev / 0790: manual live-priest diagnostic command retired.\nTECH_PRIESTS_0120_DEBUG_COMMAND_RETIRED = true',
    'tp-radii': '-- 0.1.674-dev / 0790: manual rank-radius report command retired.\nTECH_PRIESTS_0121_RADII_COMMAND_RETIRED = true',
    'tp-spawn-dump': '-- 0.1.674-dev / 0790: manual creation spawn dump command retired.\nTECH_PRIESTS_0124_SPAWN_DUMP_COMMAND_RETIRED = true',
    'tp-last-dump': '-- 0.1.674-dev / 0790: manual last-spawn dump command retired.\nTECH_PRIESTS_0124_LAST_DUMP_COMMAND_RETIRED = true',
    'tp-list-pairs': '-- 0.1.674-dev / 0790: manual active-pair listing command retired.\nTECH_PRIESTS_0127_LIST_PAIRS_COMMAND_RETIRED = true',
    'tp-list-names': '-- 0.1.674-dev / 0790: manual active-name listing command retired.\nTECH_PRIESTS_0127_LIST_NAMES_COMMAND_RETIRED = true',
    'tp-legacy-snapshot': '-- 0.1.674-dev / 0790: manual legacy-task snapshot command retired.\nTECH_PRIESTS_0137_LEGACY_SNAPSHOT_COMMAND_RETIRED = true',
    'tp-cog-summary': '-- 0.1.674-dev / 0790: manual Cogitator inventory summary command retired.\nTECH_PRIESTS_0150_COG_SUMMARY_COMMAND_RETIRED = true',
}

FILE_COMMANDS = {
    P1: ('tp-priest-diag', 'tp-radii'),
    P2: ('tp-spawn-dump', 'tp-last-dump', 'tp-list-pairs', 'tp-list-names'),
    P3: ('tp-legacy-snapshot', 'tp-cog-summary'),
}


def matching_paren(text: str, open_index: int) -> int:
    depth = 0
    i = open_index
    quote: str | None = None
    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ''
        if quote:
            if ch == '\\':
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue
        if ch in ('"', "'"):
            quote = ch
            i += 1
            continue
        if ch == '-' and nxt == '-':
            newline = text.find('\n', i + 2)
            if newline == -1:
                return len(text) - 1
            i = newline + 1
            continue
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise SystemExit('unbalanced command registration parentheses')


def remove_registration(text: str, command: str, marker: str) -> str:
    needles = (
        f'TechPriestsDebugCommandRegistry.add("{command}"',
        f'commands.add_command("{command}"',
    )
    matches = [(needle, text.find(needle)) for needle in needles if text.find(needle) >= 0]
    if len(matches) != 1:
        raise SystemExit(f'{command}: expected one registration, found {len(matches)}')
    _, index = matches[0]
    open_index = text.find('(', index)
    close_index = matching_paren(text, open_index)
    statement_start = text.rfind('\n', 0, index) + 1
    statement_end = close_index + 1
    while statement_end < len(text) and text[statement_end] in ' \t;':
        statement_end += 1
    if statement_end < len(text) and text[statement_end] == '\n':
        statement_end += 1

    # Collapse an otherwise-empty command wrapper when this registration is its
    # only statement. Helpers outside the wrapper are never included.
    wrapper_start = text.rfind('if commands and commands.add_command then', 0, statement_start)
    if wrapper_start >= 0:
        wrapper_line_start = text.rfind('\n', 0, wrapper_start) + 1
        between = text[wrapper_start + len('if commands and commands.add_command then'):statement_start]
        suffix = text[statement_end:]
        suffix_match = re.match(r'(?s)\s*end\)\s*end\s*', suffix)
        if re.fullmatch(r'\s*pcall\(function\(\)\s*', between) and suffix_match:
            statement_start = wrapper_line_start
            statement_end += suffix_match.end()

    replacement = marker + '\n'
    return text[:statement_start] + replacement + text[statement_end:]


all_before = '\n'.join(
    path.read_text(encoding='utf-8', errors='replace')
    for path in (ROOT / 'tech-priests_src').rglob('*.lua')
)
for command in COMMAND_MARKERS:
    count = all_before.count(f'TechPriestsDebugCommandRegistry.add("{command}"') + all_before.count(f'commands.add_command("{command}"')
    if count != 1:
        raise SystemExit(f'{command}: expected one registration, found {count}')

for path, commands in FILE_COMMANDS.items():
    text = path.read_text(encoding='utf-8')
    for command in commands:
        text = remove_registration(text, command, COMMAND_MARKERS[command])
    path.write_text(text, encoding='utf-8')

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

post = '\n'.join(
    path.read_text(encoding='utf-8', errors='replace')
    for path in (ROOT / 'tech-priests_src').rglob('*.lua')
)
for command in COMMAND_MARKERS:
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
    'TECH_PRIESTS_RANK_SCAN_RADII_0121',
    'TECH_PRIESTS_ACTIVE_PAIRS_0127',
    'TECH_PRIESTS_ACTIVE_NAMES_0127',
    'function tech_priests_0127_register_pair(pair)',
    'function tech_priests_0127_sync_names(pair)',
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
