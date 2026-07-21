#!/usr/bin/env python3
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
def read(path):return (ROOT/path).read_text(encoding='utf-8')
def write(path,text):(ROOT/path).write_text(text,encoding='utf-8')
def once(text,old,new,label):
 if old not in text:raise SystemExit('missing matcher: '+label)
 return text.replace(old,new,1)

for path,authority,replacement in (
 ('tech-priests_src/scripts/core/mobility_recovery_contract_0506.lua','mobility_recovery_contract_0506','movement_controller + direct_acquisition_executor_0513 + priest_lifecycle_authority_0499 + priest_recovery_safety_0503'),
 ('tech-priests_src/scripts/core/movement_recovery_authority_0508.lua','movement_recovery_authority_0508','movement_controller + direct_acquisition_executor_0513 + priest_lifecycle_authority_0499 + priest_recovery_safety_0503'),
):
 write(path,f'''-- {path.split('/')[-1]}\n-- Source-preserved retirement marker. Movement, direct acquisition, pair\n-- integrity, and controlled missing-priest recovery now have separate canonical\n-- owners. This compatibility module may not install, wrap globals, mutate pair\n-- state, register a cadence, issue commands, teleport, or create entities.\nlocal M = {{\n  retired = true,\n  authority = "{authority}",\n  replacement = "{replacement}",\n}}\nreturn M\n''')

# Remove both hidden runtime loaders and update the following comment.
path='tech-priests_src/control.lua';text=read(path)
old='''-- 0.1.506: mobility/recovery contract. Loaded after 0.1.505 so valid
-- priests are allowed to travel to work targets instead of being treated as
-- failed recovery cases and yanked back to their Cogitator Station.
do
  local ok, err = pcall(function()
    local Mobility0506 = require("scripts.core.mobility_recovery_contract_0506")
    if Mobility0506 and Mobility0506.install then Mobility0506.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.506] mobility_recovery_contract_0506 failed to install: " .. tostring(err)) end
end
'''
text=once(text,old,'-- Historical 0506 mobility/recovery wrapper is retired into canonical movement, acquisition, and lifecycle owners.\n','control 0506 loader')
old='''-- 0.1.508: recovery is no longer a movement owner. Loaded after the
-- action-stack contract so valid same-surface priests are passively validated
-- instead of being recalled, while direct acquisition owns a visible movement
-- lease and waits for adjacency before mining.
do
  local ok, err = pcall(function()
    local Move0508 = require("scripts.core.movement_recovery_authority_0508")
    if Move0508 and Move0508.install then Move0508.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.508] movement_recovery_authority_0508 failed to install: " .. tostring(err)) end
end
'''
text=once(text,old,'-- Historical 0508 movement/recovery wrapper is retired into canonical movement, acquisition, and lifecycle owners.\n','control 0508 loader')
text=text.replace('-- 0.1.509: behavior stack cleanup. Loaded after 0.1.508 so it can\n','-- 0.1.509: broker-owned passive behavior-stack maintenance. Loaded after the canonical lifecycle stack so it can\n',1)
write(path,text)

# Correct declarative ownership language.
path='tech-priests_src/scripts/core/action_stack_contract_0507.lua';text=read(path)
text=once(text,'  { key = "lifecycle", owner = "pair_lifecycle + 0499/0500/0501/0503/0506", role = "validate identity, rebind invalid priests, respawn only real missing/cross-surface cases" },','  { key = "lifecycle", owner = "priest_lifecycle_authority_0499 + priest_recovery_safety_0503", role = "observe identity and recover only explicitly authorized missing priests" },','0507 lifecycle owner')
text=once(text,'  { key = "movement", owner = "movement_controller + mobility_recovery_contract_0506", role = "move the priest to the target; no recall unless recovery is real" },','  { key = "movement", owner = "movement_controller", role = "sole visible movement request, stop, return, cadence, and engine-command authority" },','0507 movement owner')
write(path,text)

# Remove economy wrappers and cadence entries for retired modules.
path='tech-priests_src/scripts/core/efficiency_economy_0556.lua';text=read(path)
block='''  local ok0508, R0508 = pcall(require, "scripts.core.movement_recovery_authority_0508")
  if ok0508 and R0508 then
    R0508.travel_reissue_ticks = math.max(tonumber(R0508.travel_reissue_ticks or 0) or 0, 240)
    R0508.log_interval = math.max(tonumber(R0508.log_interval or 0) or 0, 1800)
  end
'''
text=once(text,block,'','0556 0508 tuning')
text=once(text,'      .. " service_skips=" .. safe((r.stats.service_skipped_0508 or 0) + (r.stats.service_skipped_0509 or 0))','      .. " service_skips=" .. safe(r.stats.service_skipped_0509 or 0)','0556 service skip report')
text=once(text,'  wrap_service("scripts.core.movement_recovery_authority_0508", "0508", 180)\n','', '0556 0508 wrap')
write(path,text)

path='tech-priests_src/scripts/core/efficiency_economy_0568.lua';text=read(path)
text=once(text,'  movement_recovery_authority_0508 = 60 * 5,\n  mobility_recovery_contract_0506 = 60 * 5,\n','', '0568 cadence entries')
write(path,text)

# Clean obsolete dead-end audit fields.
for path in ('tools/audit_dead_end_transition_sites.py','tools/audit_dead_end_transition_sites_v2.py'):
 text=read(path)
 text=text.replace('|lifecycle_0506|lifecycle_0508','')
 text=text.replace(', "lifecycle_0506", "lifecycle_0508"','')
 write(path,text)
path='tools/audit_dead_end_state_fields.py';text=read(path)
text=text.replace('        "lifecycle_0506",\n','').replace('        "lifecycle_0508",\n','')
write(path,text)

# Remove old commands during migration/runtime cleanup.
path='tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua';text=read(path)
text=once(text,'  ["tp-direct-mining-safety-0490"] = true,\n','  ["tp-direct-mining-safety-0490"] = true,\n  ["tp-mobility-recovery-0506"] = true,\n  ["tp-movement-recovery-0508"] = true,\n','runtime cleanup 0506 0508')
write(path,text)

# Advance the authority graph and add the focused boundary.
path='tech-priests_src/scripts/core/planning_constraints_0646.lua';text=read(path)
text=once(text,'active_hardener_count=26,retired_authority_count=41','active_hardener_count=26,retired_authority_count=43','planning count')
text=once(text,' ["scripts.core.priest_vanish_guard_0501"]="protected-target and physical-output validation are native to 0513; lifecycle observation belongs to 0499 and 0490 is safety-only",\n',' ["scripts.core.priest_vanish_guard_0501"]="protected-target and physical-output validation are native to 0513; lifecycle observation belongs to 0499 and 0490 is safety-only",\n ["scripts.core.mobility_recovery_contract_0506"]="movement and direct acquisition belong to movement_controller and 0513; pair integrity and missing recovery belong to 0499 and 0503",\n ["scripts.core.movement_recovery_authority_0508"]="valid-priest observation, direct travel, and recovery passivation are consolidated into canonical movement, acquisition, and lifecycle owners",\n','planning retired 0506 0508')
write(path,text)

write('tools/check_mobility_recovery_0506_0508_boundary_0773.py','''#!/usr/bin/env python3
"""Validate inert 0506/0508 and canonical movement/lifecycle ownership."""
from __future__ import annotations
import pathlib,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 'r506':ROOT/'tech-priests_src/scripts/core/mobility_recovery_contract_0506.lua','r508':ROOT/'tech-priests_src/scripts/core/movement_recovery_authority_0508.lua',
 'control':ROOT/'tech-priests_src/control.lua','stack':ROOT/'tech-priests_src/scripts/core/action_stack_contract_0507.lua',
 'e556':ROOT/'tech-priests_src/scripts/core/efficiency_economy_0556.lua','e568':ROOT/'tech-priests_src/scripts/core/efficiency_economy_0568.lua',
 'cleanup':ROOT/'tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua','planning':ROOT/'tech-priests_src/scripts/core/planning_constraints_0646.lua',
 'workflow':ROOT/'.github/workflows/source-validation.yml'}
REQUIRED={
 'r506':('retired = true','authority = "mobility_recovery_contract_0506"','movement_controller + direct_acquisition_executor_0513 + priest_lifecycle_authority_0499 + priest_recovery_safety_0503'),
 'r508':('retired = true','authority = "movement_recovery_authority_0508"','movement_controller + direct_acquisition_executor_0513 + priest_lifecycle_authority_0499 + priest_recovery_safety_0503'),
 'control':('Historical 0506 mobility/recovery wrapper is retired','Historical 0508 movement/recovery wrapper is retired'),
 'stack':('owner = "priest_lifecycle_authority_0499 + priest_recovery_safety_0503"','owner = "movement_controller"','sole visible movement request, stop, return, cadence, and engine-command authority'),
 'cleanup':('["tp-mobility-recovery-0506"] = true','["tp-movement-recovery-0508"] = true'),
 'planning':('retired_authority_count=43','["scripts.core.mobility_recovery_contract_0506"]','["scripts.core.movement_recovery_authority_0508"]'),
 'workflow':('Audit retired 0506 and 0508 recovery wrappers','check_mobility_recovery_0506_0508_boundary_0773.py')}
FORBIDDEN={
 'r506':('function M.install','register_service','on_nth_tick','commands.add_command','tech_priests_request_movement_0418','set_command','ensure_pair_priest =','respawn_pair_priest =','pair.mode','pair.target'),
 'r508':('function M.install','register_service','on_nth_tick','commands.add_command','tech_priests_request_movement_0418','set_command','ensure_pair_priest =','respawn_pair_priest =','pair.mode','pair.target'),
 'control':('require("scripts.core.mobility_recovery_contract_0506")','require("scripts.core.movement_recovery_authority_0508")'),
 'stack':('mobility_recovery_contract_0506','0499/0500/0501/0503/0506'),
 'e556':('movement_recovery_authority_0508','service_skipped_0508'),
 'e568':('movement_recovery_authority_0508','mobility_recovery_contract_0506')}
def main():
 errors=[];texts={n:p.read_text(encoding='utf-8',errors='replace') for n,p in FILES.items()}
 for n,parts in REQUIRED.items():
  for part in parts:
   if part not in texts[n]:errors.append(f'{FILES[n].relative_to(ROOT)} missing contract: {part}')
 for n,parts in FORBIDDEN.items():
  for part in parts:
   if part in texts[n]:errors.append(f'{FILES[n].relative_to(ROOT)} contains forbidden regression: {part}')
 if errors:
  print('0506/0508 boundary audit failed:',file=sys.stderr)
  for e in errors:print('  - '+e,file=sys.stderr)
  return 1
 print('0506/0508 boundary audit passed: both wrappers are inert; movement, acquisition, and lifecycle ownership is canonical.')
 return 0
if __name__=='__main__':raise SystemExit(main())
''')

for path in ('tools/check_movement_cadence_boundary_0761.py','tools/check_combat_proxy_boundary_0762.py','tools/check_direct_acquisition_bounds_boundary_0764.py','tools/check_movement_enforcement_void_boundary_0765.py','tools/check_movement_economy_boundary_0767.py','tools/check_ground_route_loader_boundary_0768.py','tools/check_priest_vanish_0502_boundary_0769.py','tools/check_pair_link_0495_boundary_0770.py','tools/check_lifecycle_seal_0500_boundary_0771.py','tools/check_vanish_guard_0501_boundary_0772.py'):
 text=read(path)
 if 'retired_authority_count=41' not in text:raise SystemExit('count anchor missing: '+path)
 write(path,text.replace('retired_authority_count=41','retired_authority_count=43'))

path='tools/check_recovery_architecture_0744.py';text=read(path)
text=once(text,'"scripts.core.priest_lifecycle_seal_0500", "scripts.core.priest_vanish_guard_0501", "scripts.core.fluid_output_sink_doctrine_0694",','"scripts.core.priest_lifecycle_seal_0500", "scripts.core.priest_vanish_guard_0501", "scripts.core.mobility_recovery_contract_0506", "scripts.core.movement_recovery_authority_0508", "scripts.core.fluid_output_sink_doctrine_0694",','architecture retired pair')
text=text.replace('retired_authority_count=41','retired_authority_count=43').replace('"Forty-one files remain"','"Forty-three files remain"').replace('"41 source-preserved authorities"','"43 source-preserved authorities"').replace('"26 active hardeners and 41 explicitly retired"','"26 active hardeners and 43 explicitly retired"')
write(path,text)

path='tools/check_development_integration_0732.py';text=read(path)
text=once(text,'    "scripts.core.priest_vanish_guard_0501",\n','    "scripts.core.priest_vanish_guard_0501",\n    "scripts.core.mobility_recovery_contract_0506",\n    "scripts.core.movement_recovery_authority_0508",\n','integration retired pair')
text=text.replace('retired_authority_count=41','retired_authority_count=43')
text=once(text,'"check_vanish_guard_0501_boundary_0772.py",\n','"check_vanish_guard_0501_boundary_0772.py", "check_mobility_recovery_0506_0508_boundary_0773.py",\n','integration 0773')
write(path,text)

path='tools/check_governance_prerequisites_0738.py';text=read(path)
for old,new in (('26-active / 41-retired graph','26-active / 43-retired graph'),('26 active hardeners and 41 explicitly retired','26 active hardeners and 43 explicitly retired'),('26 active hardeners and 41 retired source-only authorities','26 active hardeners and 43 retired source-only authorities'),('41 source-preserved authorities','43 source-preserved authorities'),('41 retired source-only authorities','43 retired source-only authorities'),('Forty-one files remain','Forty-three files remain')):text=text.replace(old,new)
text=once(text,'        "check_vanish_guard_0501_boundary_0772.py",\n','        "check_vanish_guard_0501_boundary_0772.py",\n        "Audit retired 0506 and 0508 recovery wrappers",\n        "check_mobility_recovery_0506_0508_boundary_0773.py",\n','governance 0773')
write(path,text)

path='tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md';text=read(path).replace('**41 source-preserved authorities**','**43 source-preserved authorities**',1)
anchor='`priest_vanish_guard_0501` is retired. `0513` owns protected-target and physical-output truth, `0490` is legacy mining/no-spill safety only, and `0499` owns disappearance observation and pair integrity.'
if anchor not in text:raise SystemExit('continuity 0501 paragraph missing')
text=text.replace(anchor,anchor+'\n\n`mobility_recovery_contract_0506` and `movement_recovery_authority_0508` are retired together. Visible movement belongs to `movement_controller`, direct work to `0513`, pair observation to `0499`, and controlled missing recovery temporarily to `0503`.',1);write(path,text)

path='tech-priests_src/docs/CURRENT_TESTING_GOALS.md';text=read(path).replace('26 active hardeners and 41 retired source-only authorities','26 active hardeners and 43 retired source-only authorities',1).replace('26 attempted active hardeners and 41 retired source-only authorities','26 attempted active hardeners and 43 retired source-only authorities',1)
anchor='`0501` is inert; `0513` validates physical targets and outputs while `0490` has no lifecycle recovery or timer.'
if anchor not in text:raise SystemExit('testing 0501 statement missing')
text=text.replace(anchor,anchor+' `0506` and `0508` are inert; neither can wrap recovery globals, mutate movement, or register a cadence.',1);write(path,text)

path='docs/RECOVERY_AUTHORITY_MAP_CURRENT.md';text=read(path).replace('**26 declarative active hardeners** and **41 retired source-only authorities**','**26 declarative active hardeners** and **43 retired source-only authorities**',1).replace('Forty-one files remain source-preserved','Forty-three files remain source-preserved',1)
anchor='`0501` is retired as a late vanish, direct-mining, movement, and recovery wrapper. Canonical `0513` now rejects protected targets and physical-output mismatches; `0490` retains only legacy literal-mining/no-spill safeguards; `0499` owns disappearance evidence.'
if anchor not in text:raise SystemExit('map 0501 paragraph missing')
text=text.replace(anchor,anchor+'\n\n`0506` and `0508` are retired as overlapping mobility/recovery contracts. Their movement and direct-acquisition behavior was already native to `movement_controller` and `0513`; their pair validation is native to `0499`; their fallback timers and command surfaces are removed.',1);write(path,text)

path='docs/DEVELOPMENT_HISTORY.md';text=read(path)
section='''### Retired overlapping `0506` and `0508` recovery movement wrappers

`mobility_recovery_contract_0506` and `movement_recovery_authority_0508` both repaired reverse maps, cleared recovery flags, moved direct-acquisition priests, wrapped legacy executors, wrapped ensure and respawn, modified diagnostics, installed commands, and registered periodic services with registry/direct-timer fallbacks. `0508` additionally disabled `0506`, demonstrating that the pair was an accumulated compatibility stack rather than two independent authorities.

Both modules are now inert and unloaded. `action_stack_contract_0507` names `movement_controller` as the sole movement owner and `0499` plus `0503` as the temporary lifecycle/recovery pair. Economy modules no longer require or wrap the retired services. The graph is now **26 active hardeners and 43 explicitly retired source-only authorities**.

Complete Source validation and Factorio runtime evidence remain separately required.

'''
if '### Retired overlapping `0506` and `0508` recovery movement wrappers' not in text:text=once(text,'## Current Gate State',section+'## Current Gate State','history current gate')
write(path,text)

path='RECOVERY_REPAIR_SEQUENCE.md';write(path,read(path).replace('26-active / 41-retired graph','26-active / 43-retired graph',1))

for temporary in (ROOT/'.github/workflows/audit-current-lifecycle-globals-temp.yml',ROOT/'.github/workflows/audit-0506-0508-retirement-temp.yml',Path(__file__)):
 if temporary.exists():temporary.unlink()
