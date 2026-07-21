#!/usr/bin/env python3
from pathlib import Path
ROOT=Path('.')
P13=ROOT/'tech-priests_src/scripts/generated/control_legacy_part_013.lua'
P14=ROOT/'tech-priests_src/scripts/generated/control_legacy_part_014.lua'
CLEAN=ROOT/'tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua'
HIST=ROOT/'docs/DEVELOPMENT_HISTORY.md'
NAMES=('tp-debug','tp-dump-state','tp-rebuild-registries','tp-force-station-scan','tp-sweep-debug','tp-logistics-debug')
all_before='\n'.join(p.read_text(errors='replace') for p in (ROOT/'tech-priests_src').rglob('*.lua'))
for name in NAMES:
    if all_before.count('"'+name+'"') < 1: raise SystemExit('missing command '+name)

p13=P13.read_text(); command_index=p13.index('TechPriestsDebugCommandRegistry.add("tp-debug"')
start=p13.rfind('if commands and commands.add_command then',0,command_index)
end=p13.index('TechPriestsRuntimeEventRegistry.on_nth_tick(73',command_index)
p13=p13[:start]+'''-- 0.1.674-dev / 0788: manual 0246 priority and registry commands are retired.
-- Automatic diagnostic heartbeat, registry helpers, and recovery authorities remain active.
TECH_PRIESTS_0246_DEBUG_COMMANDS_RETIRED = true
TECH_PRIESTS_0246_REGISTRY_COMMANDS_RETIRED = true

'''+p13[end:]
P13.write_text(p13)

p14=P14.read_text()
start=p14.index('TechPriestsDebugCommandRegistry.add("tp-sweep-debug"')
end=p14.index('tech_priests_0248_diag("control.lua priority doctrine repair loaded")',start)
p14=p14[:start]+'''-- 0.1.674-dev / 0788: manual sweep-cache command is retired.
TECH_PRIESTS_0248_SWEEP_DEBUG_COMMAND_RETIRED = true

'''+p14[end:]
start=p14.index('TechPriestsDebugCommandRegistry.add("tp-logistics-debug"')
end=p14.index('require("scripts.idle_priest_conversations")',start)
p14=p14[:start]+'''-- 0.1.674-dev / 0788: manual logistics report command is retired.
TECH_PRIESTS_0249_LOGISTICS_DEBUG_COMMAND_RETIRED = true

'''+p14[end:]
P14.write_text(p14)

clean=CLEAN.read_text(); anchor='  ["tp-laser-0312"] = true,'
insert='''  ["tp-laser-0312"] = true,
  ["tp-debug"] = true,
  ["tp-dump-state"] = true,
  ["tp-rebuild-registries"] = true,
  ["tp-force-station-scan"] = true,
  ["tp-sweep-debug"] = true,
  ["tp-logistics-debug"] = true,'''
if insert not in clean:
    if clean.count(anchor)!=1: raise SystemExit('cleanup anchor mismatch')
    clean=clean.replace(anchor,insert,1)
CLEAN.write_text(clean)

after='\n'.join(p.read_text(errors='replace') for p in (ROOT/'tech-priests_src').rglob('*.lua'))
for name in NAMES:
    if 'TechPriestsDebugCommandRegistry.add("'+name+'"' in after or 'commands.add_command("'+name+'"' in after:
        raise SystemExit('command remains '+name)
    if '["'+name+'"] = true' not in after: raise SystemExit('cleanup missing '+name)
for marker in ('TECH_PRIESTS_0246_DEBUG_COMMANDS_RETIRED = true','TECH_PRIESTS_0246_REGISTRY_COMMANDS_RETIRED = true','TECH_PRIESTS_0248_SWEEP_DEBUG_COMMAND_RETIRED = true','TECH_PRIESTS_0249_LOGISTICS_DEBUG_COMMAND_RETIRED = true'):
    if marker not in after: raise SystemExit('marker missing '+marker)

h=HIST.read_text(); heading='## 2026-07-21 — Milestone 0788: Priority, Sweep, and Logistics Command Retirement'
if heading not in h:
    h+=f'''\n\n{heading}\n\nRetired the manual 0.1.246 priority dump, state dump, registry rebuild, and forced station scan commands together with the 0.1.248 sweep-cache dump and 0.1.249 logistics report command. Automatic priority diagnostics, the 73-tick diagnostic heartbeat, registry and scan helper functions, station sweep updates, logistics behavior, and later recovery authorities remain active. All six stale command names are now removed by runtime_command_cleanup_0720. Static Source validation does not constitute Factorio runtime proof.\n'''; HIST.write_text(h)
print('0788 command retirement complete')
