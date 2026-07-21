#!/usr/bin/env python3
"""Validate direct 0302/0305 refresh ownership and retired ensure/command hooks."""
from __future__ import annotations
import pathlib,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "part2":ROOT/"tech-priests_src/scripts/generated/control_legacy_part_002.lua",
 "part20":ROOT/"tech-priests_src/scripts/generated/control_legacy_part_020.lua",
 "lifecycle":ROOT/"tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua",
 "cleanup":ROOT/"tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
 "integration":ROOT/"tools/check_development_integration_0732.py",
 "source_workflow":ROOT/".github/workflows/source-validation.yml",
 "workflow":ROOT/".github/workflows/generated-equipment-lifecycle-validation.yml"}
REQ={
 "part2":('tech_priests_0302_refresh_pair_fixed_armor','tech_priests_0305_refresh_pair_equipment','canonical-pair-created'),
 "part20":('TECH_PRIESTS_0302_ENSURE_WRAPPER_RETIRED = true','TECH_PRIESTS_0305_ENSURE_WRAPPER_RETIRED = true','TECH_PRIESTS_0302_DEBUG_COMMAND_RETIRED = true','TECH_PRIESTS_0305_DEBUG_COMMAND_RETIRED = true','TechPriestsRuntimeEventRegistry.on_nth_tick(887','TechPriestsRuntimeEventRegistry.on_nth_tick(83','TECH_PRIESTS_PRE_SUB_EQUIPMENT_DAMAGE_0305 = tech_priests_0302_mitigate_damage'),
 "lifecycle":('local refresh_fixed_armor = rawget(_G, "tech_priests_0302_refresh_pair_fixed_armor")','local refresh_equipment = rawget(_G, "tech_priests_0305_refresh_pair_equipment")','canonical-reimprint-recovered','canonical-priest-recovered'),
 "cleanup":('["tp-armor-0302"] = true','["tp-grid-0305"] = true'),
 "integration":('check_generated_equipment_lifecycle_hooks_0779.py',),
 "source_workflow":('Audit direct 0302 and 0305 lifecycle refresh ownership','check_generated_equipment_lifecycle_hooks_0779.py'),
 "workflow":('Audit direct 0302 and 0305 lifecycle refresh ownership','check_generated_equipment_lifecycle_hooks_0779.py')}
FORBID={
 "part20":('TECH_PRIESTS_PRE_INDEPENDENT_ENSURE_PAIR_PRIEST_0302','TECH_PRIESTS_PRE_SUB_EQUIPMENT_ENSURE_PAIR_PRIEST_0305','TechPriestsDebugCommandRegistry.add("tp-armor-0302"','TechPriestsDebugCommandRegistry.add("tp-grid-0305"','"ensure-priest"','"ensure-0302"','"priest-created-0302"','script.on_nth_tick(887','script.on_nth_tick(83')}
def count_contract(text, needle, expected, label, errors):
 actual=text.count(needle)
 if actual != expected: errors.append(f'{label} expected {expected} occurrence(s) of {needle!r}, found {actual}')
def main():
 errors=[];texts={n:p.read_text(encoding='utf-8',errors='replace') for n,p in FILES.items()}
 for n,parts in REQ.items():
  for part in parts:
   if part not in texts[n]:errors.append(f'{FILES[n].relative_to(ROOT)} missing contract: {part}')
 for n,parts in FORBID.items():
  for part in parts:
   if part in texts[n]:errors.append(f'{FILES[n].relative_to(ROOT)} contains forbidden regression: {part}')
 count_contract(texts['part20'],'TechPriestsRuntimeEventRegistry.on_nth_tick(887',1,'0302 periodic ownership',errors)
 count_contract(texts['part20'],'TechPriestsRuntimeEventRegistry.on_nth_tick(83',1,'0305 periodic ownership',errors)
 count_contract(texts['part20'],'TECH_PRIESTS_PRE_SUB_EQUIPMENT_DAMAGE_0305 = tech_priests_0302_mitigate_damage',1,'0302/0305 damage chain',errors)
 if errors:
  print('0302/0305 lifecycle hook audit failed:',file=sys.stderr)
  for e in errors:print('  - '+e,file=sys.stderr)
  return 1
 print('0302/0305 lifecycle hook audit passed: canonical creation/recovery and one ordered damage/periodic chain own equipment state; generated ensure wrappers and commands are retired.')
 return 0
if __name__=='__main__':raise SystemExit(main())
