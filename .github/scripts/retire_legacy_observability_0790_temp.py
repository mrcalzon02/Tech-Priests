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
SOURCE_FILES = (P1, P2, P3, CLEAN)

COMMANDS = (
    'tp-priest-diag', 'tp-radii', 'tp-spawn-dump', 'tp-last-dump',
    'tp-list-pairs', 'tp-list-names', 'tp-legacy-snapshot', 'tp-cog-summary',
)

MARKER_BLOCKS = {
    P1: '''

-- 0.1.674-dev / 0790: legacy priest and rank-radius observability commands are retired.
TECH_PRIESTS_0120_DEBUG_COMMAND_RETIRED = true
TECH_PRIESTS_0121_RADII_COMMAND_RETIRED = true''',
    P2: '''

-- 0.1.674-dev / 0790: legacy spawn, pair, and name observability commands are retired.
TECH_PRIESTS_0124_SPAWN_DUMP_COMMAND_RETIRED = true
TECH_PRIESTS_0124_LAST_DUMP_COMMAND_RETIRED = true
TECH_PRIESTS_0127_LIST_PAIRS_COMMAND_RETIRED = true
TECH_PRIESTS_0127_LIST_NAMES_COMMAND_RETIRED = true''',
    P3: '''

-- 0.1.674-dev / 0790: legacy task snapshot and Cogitator summary commands are retired.
TECH_PRIESTS_0137_LEGACY_SNAPSHOT_COMMAND_RETIRED = true
TECH_PRIESTS_0150_COG_SUMMARY_COMMAND_RETIRED = true''',
}


def registration_pattern(command: str) -> re.Pattern[str]:
    return re.compile(
        r'(?:TechPriestsDebugCommandRegistry\.add|commands\.add_command)\(\s*([\"\'])'
        + re.escape(command)
        + r'\1'
    )


source_before = '\n'.join(path.read_text(encoding='utf-8', errors='replace') for path in (P1, P2, P3))
for command in COMMANDS:
    if registration_pattern(command).search(source_before):
        raise SystemExit(f'0790 retirement ledger repair found restored command registration: {command}')

for path, block in MARKER_BLOCKS.items():
    text = path.read_text(encoding='utf-8')
    first_marker = next(line for line in block.splitlines() if line.startswith('TECH_PRIESTS_'))
    if first_marker not in text:
        path.write_text(text.rstrip() + block.rstrip() + '\n', encoding='utf-8')

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
    CLEAN.write_text(cleanup.replace(anchor, insert, 1), encoding='utf-8')

post = '\n'.join(path.read_text(encoding='utf-8', errors='replace') for path in SOURCE_FILES)
for command in COMMANDS:
    if registration_pattern(command).search(post):
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

history = HISTORY.read_text(encoding='utf-8')
heading = '## 2026-07-21 — Milestone 0790: Legacy Observability Command Retirement'
if heading not in history:
    history += f'''\n\n{heading}\n\nCompleted the retirement ledger for eight report-only legacy commands: live priest diagnostics, rank-radius reporting, spawn and last-spawn dumps, active pair and name listings, legacy task snapshots, and Cogitator inventory summaries. The registrations were already absent; this repair adds explicit source retirement markers and stale-command cleanup without modifying any existing runtime helper or behavior body. Static Source validation does not constitute Factorio runtime proof.\n'''
    HISTORY.write_text(history, encoding='utf-8')

print('0790 legacy observability retirement ledger repair complete')
