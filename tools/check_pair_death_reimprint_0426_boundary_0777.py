#!/usr/bin/env python3
"""Validate retired 0426 and canonical 0499/0503 re-imprint ownership."""
from __future__ import annotations
import pathlib,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
"retired":ROOT/"tech-priests_src/scripts/core/pair_death_and_respawn.lua",
"facade":ROOT/"tech-priests_src/scripts/core/pair_lifecycle.lua",
"lifecycle":ROOT/"tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua",
"recovery":ROOT/"tech-priests_src/scripts/core/priest_recovery_safety_0503.lua",
"part19":ROOT/"tech-priests_src/scripts/generated/control_legacy_part_019.lua",
"part20":ROOT/"tech-priests_src/scripts/generated/control_legacy_part_020.lua",
"bootstrap":ROOT/"tech-priests_src/scripts/core/bootstrap_runtime.lua",
"cleanup":ROOT/"tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
"planning":ROOT/"tech-priests_src/scripts/core/planning_constraints_0646.lua",
"integration":ROOT/"tools/check_development_integration_0732.py",
"workflow":ROOT/".github/workflows/source-validation.yml"}
REQ={
"retired":('retired = true','authority = "pair_death_and_respawn_0426"','generated 0298 reimprint presentation'),
"facade":('death_wrapper_retired_0426 = true','authority.begin_reimprint','tech_priests_0298_enter_reimprint'),
"lifecycle":('M.reimprint_integrated = true','function M.begin_reimprint','function M.is_reimprinting','priest-reimprint-started','priest-reimprint-ready','priest-reimprint-completed','priority="first"','stop_on_truthy=true','tech_priests_begin_reimprint_0499'),
"recovery":('reimprint_completion_integrated = true','reimprint-in-progress','reimprint-ready-for-controlled-recovery-0503','completed intentional re-imprints'),
"part19":('TECH_PRIESTS_REIMPRINT_EVENT_AUTHORITY_RETIRED_0298 = true','TechPriestsPriestLifecycleAuthority0499'),
"part20":('TECH_PRIESTS_REIMPRINT_RESPAWN_WRAPPERS_RETIRED_0298 = true','presentation-only','function tech_priests_0298_service_reimprints'),
"bootstrap":('pair lifecycle facade; 0426 death wrapper retired into 0499/0503',),
"cleanup":('["tp-lifecycle-0426"] = true',),
"planning":('retired_authority_count=46','["scripts.core.pair_death_and_respawn"]'),
"integration":('"scripts.core.pair_death_and_respawn"','check_pair_death_reimprint_0426_boundary_0777.py'),
"workflow":('Audit retired 0426 reimprint lifecycle wrapper','check_pair_death_reimprint_0426_boundary_0777.py')}
FORBID={
"retired":('function M.install','register_events','register_commands','on_nth_tick','TECH_PRIESTS_0426_PRE_','_G.ensure_pair_priest =','_G.respawn_pair_priest =','pair.mode =','pair.target ='),
"facade":('require("scripts.core.pair_death_and_respawn")','TechPriestsPairDeathAndRespawn'),
"part19":('TECH_PRIESTS_PRE_REIMPRINT_ON_REMOVED_0298','TechPriestsRuntimeEventRegistry.on_event'),
"part20":('TECH_PRIESTS_PRE_REIMPRINT_ENSURE_PAIR_PRIEST_0298','TECH_PRIESTS_PRE_REIMPRINT_RESPAWN_PAIR_PRIEST_0298','TechPriestsRuntimeEventRegistry.on_nth_tick(47','respawn_pair_priest(pair, "reimprint-complete")')}
def main():
 errors=[];texts={n:p.read_text(encoding='utf-8',errors='replace') for n,p in FILES.items()}
 for n,parts in REQ.items():
  for part in parts:
   if part not in texts[n]:errors.append(f'{FILES[n].relative_to(ROOT)} missing contract: {part}')
 for n,parts in FORBID.items():
  for part in parts:
   if part in texts[n]:errors.append(f'{FILES[n].relative_to(ROOT)} contains forbidden regression: {part}')
 if errors:
  print('0426 re-imprint boundary audit failed:',file=sys.stderr)
  for e in errors:print('  - '+e,file=sys.stderr)
  return 1
 print('0426 re-imprint boundary audit passed: 0499 owns death state, 0503 owns deadline-gated lease completion, and 0298 is presentation-only.')
 return 0
if __name__=='__main__':raise SystemExit(main())
