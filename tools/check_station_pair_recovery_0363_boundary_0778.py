#!/usr/bin/env python3
"""Validate retired 0363 and direct canonical pair-ledger refresh ownership."""
from __future__ import annotations
import pathlib,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "retired":ROOT/"tech-priests_src/scripts/core/station_pair_recovery.lua",
 "state":ROOT/"tech-priests_src/scripts/core/station_pair_state.lua",
 "create":ROOT/"tech-priests_src/scripts/generated/control_legacy_part_002.lua",
 "lifecycle":ROOT/"tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua",
 "migration":ROOT/"tech-priests_src/scripts/core/migration_pair_integrity_0734.lua",
 "bootstrap":ROOT/"tech-priests_src/scripts/core/bootstrap_runtime.lua",
 "cleanup":ROOT/"tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
 "planning":ROOT/"tech-priests_src/scripts/core/planning_constraints_0646.lua",
 "integration":ROOT/"tools/check_development_integration_0732.py",
 "workflow":ROOT/".github/workflows/source-validation.yml"}
REQ={
 "retired":('retired = true','authority = "station_pair_recovery_0363"','station_pair_state_0362 + priest_lifecycle_authority_0499 + priest_recovery_safety_0503 + migration_pair_integrity_0734 + canonical inventory owners'),
 "state":('function M.ensure_pair','function M.refresh_pair','tech_priests_0362_refresh_pair_state = M.refresh_pair'),
 "create":('tech_priests_0362_refresh_pair_state','canonical-pair-created'),
 "lifecycle":('local refresh_pair_state = rawget(_G, "tech_priests_0362_refresh_pair_state")','canonical-reimprint-recovered','canonical-priest-recovered'),
 "migration":('migration_pair_integrity_0734','pairs_by_station'),
 "bootstrap":('historical 0363 station-pair recovery wrapper retired',),
 "cleanup":('["tp-pairstate-recover-0363"] = true',),
 "planning":('retired_authority_count=47','["scripts.core.station_pair_recovery"]'),
 "integration":('"scripts.core.station_pair_recovery"','check_station_pair_recovery_0363_boundary_0778.py'),
 "workflow":('Audit retired 0363 station-pair recovery wrapper','check_station_pair_recovery_0363_boundary_0778.py')}
FORBID={
 "retired":('function M.install','commands.add_command','write_file','script.on_nth_tick','register_service','_G.create_pair =','_G.respawn_pair_priest =','ensure_pair_priest','pair.mode','pair.target','inventory.insert','inventory.remove'),
 "bootstrap":('require("scripts.core.station_pair_recovery")','TECH_PRIESTS_0363_INSTALL_STATION_PAIR_RECOVERY')}
def main():
 errors=[];texts={n:p.read_text(encoding='utf-8',errors='replace') for n,p in FILES.items()}
 for n,parts in REQ.items():
  for part in parts:
   if part not in texts[n]:errors.append(f'{FILES[n].relative_to(ROOT)} missing contract: {part}')
 for n,parts in FORBID.items():
  for part in parts:
   if part in texts[n]:errors.append(f'{FILES[n].relative_to(ROOT)} contains forbidden regression: {part}')
 if errors:
  print('0363 station-pair recovery boundary audit failed:',file=sys.stderr)
  for e in errors:print('  - '+e,file=sys.stderr)
  return 1
 print('0363 boundary audit passed: 0363 is inert; 0362 owns ledgers; canonical creation/recovery refresh state directly.')
 return 0
if __name__=='__main__':raise SystemExit(main())
