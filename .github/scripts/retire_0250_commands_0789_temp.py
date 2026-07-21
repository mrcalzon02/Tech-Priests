#!/usr/bin/env python3
from pathlib import Path

ROOT = Path('.')
PART14 = ROOT / 'tech-priests_src/scripts/generated/control_legacy_part_014.lua'
CLEANUP = ROOT / 'tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua'
HISTORY = ROOT / 'docs/DEVELOPMENT_HISTORY.md'
COMMANDS = (
    'tp-emergency-miner-debug',
    'tp-assignment-debug',
    'tp-power-chain-debug',
    'tp-fuel-bootstrap-debug',
    'tp-magos-planner-debug',
)

text = PART14.read_text(encoding='utf-8')
for command in COMMANDS:
    token = f'TechPriestsDebugCommandRegistry.add("{command}"'
    if text.count(token) != 1:
        raise SystemExit(f'{command}: expected one registration, found {text.count(token)}')

# 0250 block: diagnostic command only.
start = text.index('-- 0.1.250 Emergency Micro-Miner pseudo-mining diagnostic command.')
end = text.index('-- 0.1.252 Ranked emergency assignment delegation.', start)
text = text[:start] + '''-- 0.1.674-dev / 0789: manual Emergency Micro-Miner diagnostic command retired.
TECH_PRIESTS_0250_DEBUG_COMMAND_RETIRED = true


''' + text[end:]

# 0252 assignment command block, preserving the automatic tick service and loaded marker.
token = 'TechPriestsDebugCommandRegistry.add("tp-assignment-debug"'
command_index = text.index(token)
start = text.rfind('if commands and commands.add_command then', 0, command_index)
end = text.index('tech_priests_0252_diag("ranked emergency assignment delegation loaded")', command_index)
text = text[:start] + '''-- 0.1.674-dev / 0789: manual ranked-assignment diagnostic command retired.
TECH_PRIESTS_0252_DEBUG_COMMAND_RETIRED = true

''' + text[end:]

# 0253 direct power-chain command.
start = text.index('TechPriestsDebugCommandRegistry.add("tp-power-chain-debug"')
end = text.index('-- 0.1.254 diagnostic command for the Martian fuel bootstrap chain.', start)
text = text[:start] + '''-- 0.1.674-dev / 0789: manual powered-lab/power-chain diagnostic command retired.
TECH_PRIESTS_0253_DEBUG_COMMAND_RETIRED = true


''' + text[end:]

# 0254 wrapped fuel command.
start = text.index('-- 0.1.254 diagnostic command for the Martian fuel bootstrap chain.')
end = text.index('-- 0.1.255 Planetary Magos standard-industry degradation planner.', start)
text = text[:start] + '''-- 0.1.674-dev / 0789: manual Martian fuel-bootstrap diagnostic command retired.
TECH_PRIESTS_0254_DEBUG_COMMAND_RETIRED = true


''' + text[end:]

# 0255 wrapped Magos planner command, preserving the loaded marker.
token = 'TechPriestsDebugCommandRegistry.add("tp-magos-planner-debug"'
command_index = text.index(token)
start = text.rfind('if commands and commands.add_command then', 0, command_index)
end = text.index('tech_priests_0255_diag("Planetary Magos standard-industry degradation planner loaded")', command_index)
text = text[:start] + '''-- 0.1.674-dev / 0789: manual Planetary Magos planner diagnostic command retired.
TECH_PRIESTS_0255_DEBUG_COMMAND_RETIRED = true

''' + text[end:]
PART14.write_text(text, encoding='utf-8')

cleanup = CLEANUP.read_text(encoding='utf-8')
anchor = '  ["tp-logistics-debug"] = true,'
insert = '''  ["tp-logistics-debug"] = true,
  ["tp-emergency-miner-debug"] = true,
  ["tp-assignment-debug"] = true,
  ["tp-power-chain-debug"] = true,
  ["tp-fuel-bootstrap-debug"] = true,
  ["tp-magos-planner-debug"] = true,'''
if insert not in cleanup:
    if cleanup.count(anchor) != 1:
        raise SystemExit('runtime cleanup anchor mismatch')
    cleanup = cleanup.replace(anchor, insert, 1)
CLEANUP.write_text(cleanup, encoding='utf-8')

post = '\n'.join(path.read_text(encoding='utf-8', errors='replace') for path in (ROOT / 'tech-priests_src').rglob('*.lua'))
for command in COMMANDS:
    for prefix in ('TechPriestsDebugCommandRegistry.add("', 'commands.add_command("'):
        if prefix + command + '"' in post:
            raise SystemExit(f'retired command remains: {command}')
    if f'["{command}"] = true' not in post:
        raise SystemExit(f'cleanup missing: {command}')
for marker in (
    'TECH_PRIESTS_0250_DEBUG_COMMAND_RETIRED = true',
    'TECH_PRIESTS_0252_DEBUG_COMMAND_RETIRED = true',
    'TECH_PRIESTS_0253_DEBUG_COMMAND_RETIRED = true',
    'TECH_PRIESTS_0254_DEBUG_COMMAND_RETIRED = true',
    'TECH_PRIESTS_0255_DEBUG_COMMAND_RETIRED = true',
):
    if marker not in post:
        raise SystemExit(f'marker missing: {marker}')
for required in (
    'function tech_priests_debug_emergency_miner_0250',
    'function tech_priests_0252_service_assignment(pair)',
    'TECH_PRIESTS_TICK_PAIR_BEFORE_ASSIGNMENTS_0252 = tick_pair',
    'function tech_priests_ensure_power_chain_before_laboratorium_0253',
    'function tech_priests_0254_service_fuel_bootstrap(pair, op)',
    'function tech_priests_0255_service_magos_standard_planner(pair, op)',
):
    if required not in post:
        raise SystemExit(f'preserved runtime contract missing: {required}')

history = HISTORY.read_text(encoding='utf-8')
heading = '## 2026-07-21 — Milestone 0789: 0250–0255 Diagnostic Command Retirement'
if heading not in history:
    history += f'''\n\n{heading}\n\nRetired five manual diagnostic commands covering the Emergency Micro-Miner, ranked assignment delegation, powered Laboratorium chain, Martian fuel bootstrap, and Planetary Magos standard-industry planner. Their reporter and runtime helper functions, assignment tick service, emergency-operation wrappers, power-chain selection, fuel bootstrap behavior, and Magos planner behavior remain active. All five stale command names are removed through runtime_command_cleanup_0720. Static Source validation does not constitute Factorio runtime proof.\n'''
    HISTORY.write_text(history, encoding='utf-8')

print('0789 command retirement complete')
