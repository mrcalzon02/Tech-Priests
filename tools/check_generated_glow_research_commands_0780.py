#!/usr/bin/env python3
"""Validate retired generated glow/research commands and preserved cadences."""
from __future__ import annotations
import pathlib,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "part21":ROOT/"tech-priests_src/scripts/generated/control_legacy_part_021.lua",
 "cleanup":ROOT/"tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
 "integration":ROOT/"tools/check_development_integration_0732.py",
 "source_workflow":ROOT/".github/workflows/source-validation.yml",
 "workflow":ROOT/".github/workflows/generated-glow-research-validation.yml",
}
REQ={
 "part21":(
  'TECH_PRIESTS_0307_DEBUG_COMMAND_RETIRED = true',
  'TECH_PRIESTS_0308_DEBUG_COMMAND_RETIRED = true',
  'TECH_PRIESTS_0313_DEBUG_COMMAND_RETIRED = true',
  'TechPriestsRuntimeEventRegistry.on_nth_tick(TECH_PRIESTS_GLOW_REFRESH_TICKS_0307',
  'TechPriestsRuntimeEventRegistry.on_nth_tick(37',
  'tech_priests_0313_refresh_research_bonuses("movement-service")'),
 "cleanup":(
  '["tp-glow-0307"] = true',
  '["tp-glow-0308"] = true',
  '["tp-upgrades-0313"] = true'),
 "integration":('check_generated_glow_research_commands_0780.py',),
 "source_workflow":('Audit retired generated glow and research commands','check_generated_glow_research_commands_0780.py'),
 "workflow":('Audit retired generated glow and research commands','check_generated_glow_research_commands_0780.py'),
}
FORBID={
 "part21":(
  'TechPriestsDebugCommandRegistry.add("tp-glow-0307"',
  'TechPriestsDebugCommandRegistry.add("tp-glow-0308"',
  'TechPriestsDebugCommandRegistry.add("tp-upgrades-0313"',
  'script.on_nth_tick(TECH_PRIESTS_GLOW_REFRESH_TICKS_0307',
  'script.on_nth_tick(37'),
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
 count_contract(texts['part21'],'TechPriestsRuntimeEventRegistry.on_nth_tick(TECH_PRIESTS_GLOW_REFRESH_TICKS_0307',1,'0307 glow cadence',errors)
 count_contract(texts['part21'],'TechPriestsRuntimeEventRegistry.on_nth_tick(37',1,'0313 research cadence',errors)
 if errors:
  print('Generated glow/research command audit failed:',file=sys.stderr)
  for error in errors: print('  - '+error,file=sys.stderr)
  return 1
 print('Generated glow/research command audit passed: 0307/0308/0313 commands are retired and registry-owned 19/37-tick behavior remains single-sourced.')
 return 0
if __name__=='__main__': raise SystemExit(main())
