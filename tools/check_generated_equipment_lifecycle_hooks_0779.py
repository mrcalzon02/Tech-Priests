#!/usr/bin/env python3
"""Validate canonical 0302/0305/0306 ownership and retired 0313 overrides."""
from __future__ import annotations
import pathlib,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "part2":ROOT/"tech-priests_src/scripts/generated/control_legacy_part_002.lua",
 "part20":ROOT/"tech-priests_src/scripts/generated/control_legacy_part_020.lua",
 "part21":ROOT/"tech-priests_src/scripts/generated/control_legacy_part_021.lua",
 "lifecycle":ROOT/"tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua",
 "cleanup":ROOT/"tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
 "integration":ROOT/"tools/check_development_integration_0732.py",
 "source_workflow":ROOT/".github/workflows/source-validation.yml",
 "workflow":ROOT/".github/workflows/generated-equipment-lifecycle-validation.yml"}
REQ={
 "part2":('tech_priests_0302_refresh_pair_fixed_armor','tech_priests_0305_refresh_pair_equipment','canonical-pair-created'),
 "part20":(
  'TECH_PRIESTS_0302_ENSURE_WRAPPER_RETIRED = true',
  'TECH_PRIESTS_0305_ENSURE_WRAPPER_RETIRED = true',
  'TECH_PRIESTS_0302_DEBUG_COMMAND_RETIRED = true',
  'TECH_PRIESTS_0305_DEBUG_COMMAND_RETIRED = true',
  'TECH_PRIESTS_0306_REFRESH_OVERRIDE_RETIRED = true',
  'TECH_PRIESTS_0306_DEBUG_COMMAND_RETIRED = true',
  'TECH_PRIESTS_0305_RESEARCH_DOCTRINE_CANONICAL = true',
  'TECH_PRIESTS_0306_GRID_DOCTRINE_RETIRED = true',
  'TECH_PRIESTS_0313_EQUIPMENT_OVERRIDES_RETIRED = true',
  'doctrine = "research-bonuses-station-inventory-only"',
  'pair.sub_equipment_bay_0306 = nil',
  'pair.future_equipment_grid_0301 = nil',
  'function tech_priests_0305_apply_active_defense(pair)',
  'function tech_priests_0305_on_entity_damaged(event)',
  'tech_priests_0313_refresh_research_bonuses("periodic")',
  'function tech_priests_0306_open_gui(player, pair)',
  'function tech_priests_0306_on_gui_opened(event)',
  'TechPriestsRuntimeEventRegistry.on_nth_tick(887',
  'TechPriestsRuntimeEventRegistry.on_nth_tick(83'),
 "part21":(
  'function tech_priests_0313_refresh_research_bonuses(reason)',
  'function tech_priests_0313_profile_for_pair(pair)',
  'TECH_PRIESTS_0313_EQUIPMENT_OVERRIDE_RETIRED = true',
  'TECH_PRIESTS_0313_ACTIVE_DEFENSE_OVERRIDE_RETIRED = true',
  'TECH_PRIESTS_0313_PERIODIC_ROUTE_RETIRED = true',
  'TECH_PRIESTS_0313_DAMAGE_ROUTE_RETIRED = true',
  'TECH_PRIESTS_0313_GUI_ROUTE_RETIRED = true'),
 "lifecycle":('local refresh_fixed_armor = rawget(_G, "tech_priests_0302_refresh_pair_fixed_armor")','local refresh_equipment = rawget(_G, "tech_priests_0305_refresh_pair_equipment")','canonical-reimprint-recovered','canonical-priest-recovered'),
 "cleanup":('["tp-armor-0302"] = true','["tp-grid-0305"] = true','["tp-grid-0306"] = true'),
 "integration":('check_generated_equipment_lifecycle_hooks_0779.py',),
 "source_workflow":('Audit direct 0302 and 0305 lifecycle refresh ownership','check_generated_equipment_lifecycle_hooks_0779.py'),
 "workflow":('Retain generated equipment failure diagnostics','check_generated_equipment_lifecycle_hooks_0779.py')}
FORBID={
 "part20":(
  'TECH_PRIESTS_PRE_INDEPENDENT_ENSURE_PAIR_PRIEST_0302',
  'TECH_PRIESTS_PRE_SUB_EQUIPMENT_ENSURE_PAIR_PRIEST_0305',
  'TECH_PRIESTS_PRE_SUB_EQUIPMENT_DAMAGE_0305 =',
  'TechPriestsDebugCommandRegistry.add("tp-armor-0302"',
  'TechPriestsDebugCommandRegistry.add("tp-grid-0305"',
  '"ensure-priest"','"ensure-0302"','"priest-created-0302"',
  '"visible-grid"','"station-inventory-compatibility"',
  'sub_equipment_shield_energy_0305',
  'script.on_nth_tick(887','script.on_nth_tick(83'),
 "part21":(
  'function tech_priests_0305_refresh_pair_equipment(pair, reason)',
  'function tech_priests_0305_apply_active_defense(pair)',
  'function tech_priests_0313_on_entity_damaged(event)',
  'function tech_priests_0313_on_gui_opened(event)',
  'function tech_priests_0313_on_gui_closed(event)',
  'function tech_priests_0313_on_gui_click(event)',
  'TECH_PRIESTS_PRE_GRID_REFRESH_0306 = tech_priests_0305_refresh_pair_equipment',
  'TechPriestsDebugCommandRegistry.add("tp-grid-0306"',
  'TechPriestsRuntimeEventRegistry.on_nth_tick(83')}
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
 count_contract(texts['part20'],'TechPriestsRuntimeEventRegistry.on_nth_tick(83',1,'0305 research refresh ownership',errors)
 count_contract(texts['part21'],'TechPriestsRuntimeEventRegistry.on_nth_tick(83',0,'retired 0313 duplicate 83-tick route',errors)
 count_contract(texts['part20'],'function tech_priests_0305_refresh_pair_equipment(pair, reason)',1,'canonical 0305 doctrine reader',errors)
 count_contract(texts['part21'],'function tech_priests_0305_refresh_pair_equipment(pair, reason)',0,'retired 0313 doctrine replacement',errors)
 count_contract(texts['part20'],'TechPriestsRuntimeEventRegistry.on_event(defines.events.on_entity_damaged, tech_priests_0305_on_entity_damaged)',1,'canonical equipment damage route',errors)
 count_contract(texts['part21'],'TechPriestsRuntimeEventRegistry.on_event(defines.events.on_entity_damaged, tech_priests_0313_on_entity_damaged)',0,'retired 0313 damage route',errors)
 if errors:
  print('0302/0305/0306/0313 equipment ownership audit failed:',file=sys.stderr)
  for e in errors:print('  - '+e,file=sys.stderr)
  return 1
 print('0302/0305/0306/0313 equipment ownership audit passed: fixed armor and final research-bonus doctrine have one reader, one damage route, one 83-tick route, disabled grid presentation, and no later 0313 replacements.')
 return 0
if __name__=='__main__':raise SystemExit(main())
