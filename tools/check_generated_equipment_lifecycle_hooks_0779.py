#!/usr/bin/env python3
"""Validate canonical 0302/0305 lifecycle, damage-chain, and periodic ownership."""
from __future__ import annotations
import pathlib,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "part2":ROOT/"tech-priests_src/scripts/generated/control_legacy_part_002.lua",
 "part20":ROOT/"tech-priests_src/scripts/generated/control_legacy_part_020.lua",
 "lifecycle":ROOT/"tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua",
 "cleanup":ROOT/"tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
 "integration":ROOT/"tools/check_development_integration_0732.py",
 "workflow":ROOT/".github/workflows/generated-equipment-lifecycle-validation.yml"}
REQ={
 "part2":('tech_priests_0302_refresh_pair_fixed_armor','tech_priests_0305_refresh_pair_equipment','canonical-pair-created'),
 "part20":(
  'TECH_PRIESTS_0302_ENSURE_WRAPPER_RETIRED = true','TECH_PRIESTS_0305_ENSURE_WRAPPER_RETIRED = true',
  'TECH_PRIESTS_0302_DEBUG_COMMAND_RETIRED = true','TECH_PRIESTS_0305_DEBUG_COMMAND_RETIRED = true',
  'TechPriestsRuntimeEventRegistry.on_event(defines.events.on_entity_damaged, tech_priests_0302_mitigate_damage)',
  'TECH_PRIESTS_PRE_SUB_EQUIPMENT_DAMAGE_0305 = tech_priests_0302_mitigate_damage',
  'pcall(function() TECH_PRIESTS_PRE_SUB_EQUIPMENT_DAMAGE_0305(event) end)',
  'TechPriestsRuntimeEventRegistry.on_event(defines.events.on_entity_damaged, tech_priests_0305_on_entity_damaged)',
  'TechPriestsRuntimeEventRegistry.on_nth_tick(887','tech_priests_0302_refresh_pair_fixed_armor(pair, "periodic-0302")',
  'TechPriestsRuntimeEventRegistry.on_nth_tick(83','tech_priests_0305_refresh_pair_equipment(pair, "periodic")',
  'pair.sub_equipment_shield_energy_0305 = math.min','tech_priests_0305_apply_active_defense(pair)'),
 "lifecycle":('local refresh_fixed_armor = rawget(_G, "tech_priests_0302_refresh_pair_fixed_armor")','local refresh_equipment = rawget(_G, "tech_priests_0305_refresh_pair_equipment")','canonical-reimprint-recovered','canonical-priest-recovered'),
 "cleanup":('["tp-armor-0302"] = true','["tp-grid-0305"] = true'),
 "integration":('check_generated_equipment_lifecycle_hooks_0779.py',),
 "workflow":('Audit direct 0302 and 0305 lifecycle refresh ownership','check_generated_equipment_lifecycle_hooks_0779.py')}
FORBID={
 "part20":(
  'TECH_PRIESTS_PRE_INDEPENDENT_ENSURE_PAIR_PRIEST_0302','TECH_PRIESTS_PRE_SUB_EQUIPMENT_ENSURE_PAIR_PRIEST_0305',
  'TechPriestsDebugCommandRegistry.add("tp-armor-0302"','TechPriestsDebugCommandRegistry.add("tp-grid-0305"',
  'script.on_nth_tick(887','script.on_nth_tick(83','"ensure-priest"','"ensure-0302"','"priest-created-0302"')}
def main():
 errors=[];texts={n:p.read_text(encoding='utf-8',errors='replace') for n,p in FILES.items()}
 for n,parts in REQ.items():
  for part in parts:
   if part not in texts[n]:errors.append(f'{FILES[n].relative_to(ROOT)} missing contract: {part}')
 for n,parts in FORBID.items():
  for part in parts:
   if part in texts[n]:errors.append(f'{FILES[n].relative_to(ROOT)} contains forbidden regression: {part}')
 part20=texts['part20']
 if part20.count('TechPriestsRuntimeEventRegistry.on_nth_tick(887') != 1:
  errors.append('0302 periodic cadence must have exactly one registry-owned 887-tick route')
 if part20.count('TechPriestsRuntimeEventRegistry.on_nth_tick(83') != 1:
  errors.append('0305 periodic cadence must have exactly one registry-owned 83-tick route')
 if part20.count('TECH_PRIESTS_PRE_SUB_EQUIPMENT_DAMAGE_0305 = tech_priests_0302_mitigate_damage') != 1:
  errors.append('0305 shield mitigation must chain the 0302 fixed-armor handler exactly once')
 if errors:
  print('0302/0305 lifecycle and periodic ownership audit failed:',file=sys.stderr)
  for e in errors:print('  - '+e,file=sys.stderr)
  return 1
 print('0302/0305 audit passed: creation/recovery refresh is canonical; damage mitigation is one ordered chain; periodic routes are registry-owned and unique; ensure wrappers and commands remain retired.')
 return 0
if __name__=='__main__':raise SystemExit(main())