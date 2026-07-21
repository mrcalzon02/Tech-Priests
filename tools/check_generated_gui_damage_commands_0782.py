#!/usr/bin/env python3
"""Validate retired 0310-0312 commands and the single canonical damage route."""
from __future__ import annotations
import pathlib,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "part20":ROOT/"tech-priests_src/scripts/generated/control_legacy_part_020.lua",
 "part21":ROOT/"tech-priests_src/scripts/generated/control_legacy_part_021.lua",
 "cleanup":ROOT/"tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
 "integration":ROOT/"tools/check_development_integration_0732.py",
 "source_workflow":ROOT/".github/workflows/source-validation.yml",
 "workflow":ROOT/".github/workflows/generated-gui-damage-validation.yml",
}
REQ={
 "part20":(
  'function tech_priests_0305_on_entity_damaged(event)',
  'pair.last_station_damage_tick_0310 = game and game.tick or 0',
  'pair.station_damage_guard_until_0310 = math.max(',
  'TechPriestsRuntimeEventRegistry.on_event(defines.events.on_entity_damaged, tech_priests_0305_on_entity_damaged)'),
 "part21":(
  'TECH_PRIESTS_0310_DAMAGE_WRAPPER_RETIRED = true',
  'TECH_PRIESTS_0310_DEBUG_COMMAND_RETIRED = true',
  'TECH_PRIESTS_0311_DEBUG_COMMAND_RETIRED = true',
  'TECH_PRIESTS_0312_DEBUG_COMMAND_RETIRED = true',
  'function tech_priests_0312_fallback_combat_laser'),
 "cleanup":(
  '["tp-gui-0310"] = true',
  '["tp-0311"] = true',
  '["tp-laser-0312"] = true'),
 "integration":('check_generated_gui_damage_commands_0782.py',),
 "source_workflow":('Audit retired generated GUI commands and duplicate damage route','check_generated_gui_damage_commands_0782.py'),
 "workflow":('Audit retired generated GUI commands and duplicate damage route','check_generated_gui_damage_commands_0782.py'),
}
FORBID={
 "part21":(
  'TechPriestsDebugCommandRegistry.add("tp-gui-0310"',
  'TechPriestsDebugCommandRegistry.add("tp-0311"',
  'TechPriestsDebugCommandRegistry.add("tp-laser-0312"',
  'TECH_PRIESTS_PRE_DAMAGE_0305_FOR_0310',
  'function tech_priests_0310_note_station_damage',
  'function tech_priests_0310_on_entity_damaged',
  'TechPriestsRuntimeEventRegistry.on_event(defines.events.on_entity_damaged, tech_priests_0310_on_entity_damaged)'),
}
def count_contract(text, needle, expected, label, errors):
 actual=text.count(needle)
 if actual != expected: errors.append(f'{label} expected {expected} occurrence(s) of {needle!r}, found {actual}')
def main():
 errors=[]
 texts={name:path.read_text(encoding='utf-8',errors='replace') for name,path in FILES.items()}
 for name,parts in REQ.items():
  for part in parts:
   if part not in texts[name]: errors.append(f'{FILES[name].relative_to(ROOT)} missing contract: {part}')
 for name,parts in FORBID.items():
  for part in parts:
   if part in texts[name]: errors.append(f'{FILES[name].relative_to(ROOT)} contains forbidden regression: {part}')
 count_contract(texts['part20'],'TechPriestsRuntimeEventRegistry.on_event(defines.events.on_entity_damaged, tech_priests_0305_on_entity_damaged)',1,'canonical generated damage route',errors)
 count_contract(texts['part21'],'TechPriestsRuntimeEventRegistry.on_event(defines.events.on_entity_damaged',0,'retired generated duplicate damage routes',errors)
 if errors:
  print('Generated command/damage ownership audit failed:',file=sys.stderr)
  for error in errors: print('  - '+error,file=sys.stderr)
  return 1
 print('Generated command/damage ownership audit passed: 0310-0312 commands and duplicate 0310 damage wrapper are retired; canonical 0305 owns station bookkeeping and armor-safe damage handling.')
 return 0
if __name__=='__main__': raise SystemExit(main())
