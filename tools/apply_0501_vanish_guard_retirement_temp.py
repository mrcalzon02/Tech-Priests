#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")

def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing matcher: {label}")
    return text.replace(old, new, 1)

# Retire the late vanish/recovery/movement wrapper.
write(
    "tech-priests_src/scripts/core/priest_vanish_guard_0501.lua",
    '''-- scripts/core/priest_vanish_guard_0501.lua
-- Source-preserved retirement marker. Protected-target and physical-output
-- validation are native to direct_acquisition_executor_0513; legacy no-spill
-- mining safety remains in direct_mining_safety_0490; disappearance observation,
-- reverse-map integrity, and orphan rebinding belong to priest_lifecycle_authority_0499.
local M = {
  retired = true,
  authority = "priest_vanish_guard_0501",
  replacement = "direct_acquisition_executor_0513 + direct_mining_safety_0490 + priest_lifecycle_authority_0499",
}
return M
''',
)

# Make canonical direct acquisition own exact target safety and physical output truth.
path = "tech-priests_src/scripts/core/direct_acquisition_executor_0513.lua"
text = read(path)
text = replace_once(
    text,
    'default_direct_radius=32,default_hard_leash=48,bounds_integrated=true,\n',
    'default_direct_radius=32,default_hard_leash=48,bounds_integrated=true,target_safety_integrated=true,\n',
    "0513 safety flag",
)
text = replace_once(
    text,
    'local function item_exists(n)return type(n)=="string"and n~=""and prototypes and prototypes.item and prototypes.item[n]~=nil end\n',
    '''local function item_exists(n)return type(n)=="string"and n~=""and prototypes and prototypes.item and prototypes.item[n]~=nil end
local function priest_or_station(e)
 if not valid(e)then return false end;local n=tostring(e.name or"");return n:find("tech%-priest",1,false)~=nil or n:find("cogitator%-station",1,false)~=nil
end
function M.target_is_safe(p,e)
 if not valid(e)or priest_or_station(e)or(valid(p and p.station)and e==p.station)then return false,"protected-target"end
 local t=e.type;if t=="resource"or t=="tree"then return true end
 if t=="simple-entity"or t=="simple-entity-with-owner"or t=="rock"then if valid(p and p.station)and e.force and e.force==p.station.force then return false,"owned-simple-entity"end;return true end
 return false,"unsupported-target-type:"..safe(t)
end
function M.physical_item(task,cur,e)
 if not valid(e)then return nil,"invalid-target"end
 if e.type=="resource"then return item_exists(e.name)and e.name or nil,"resource"end
 if e.type=="tree"then return item_exists("wood")and"wood"or nil,"tree"end
 local named=cur and(cur.physical_yield_item or cur.output_item)or task and(task.physical_yield_item or task.output_item)
 if (e.type=="simple-entity"or e.type=="simple-entity-with-owner"or e.type=="rock")and item_exists(named)then return named,"declared-destructive-yield"end
 return nil,"exact-physical-yield-required"
end
''',
    "0513 safety helpers",
)
text = replace_once(
    text,
    '''  local e=entity(cur);local item=explicit_item(t,cur)
  if not valid(e)then return replan(p,t,state,"physical-target-invalid")end
  if not item then return fail_unsafe(p,t,key,state,"explicit-output-item-required")end
  if e.surface~=p.station.surface then return fail_unsafe(p,t,key,state,"cross-surface-target")end
''',
    '''  local e=entity(cur);local item=explicit_item(t,cur)
  if not valid(e)then return replan(p,t,state,"physical-target-invalid")end
  if not item then return fail_unsafe(p,t,key,state,"explicit-output-item-required")end
  local safe_target,safety_reason=M.target_is_safe(p,e);if not safe_target then return fail_unsafe(p,t,key,state,safety_reason)end
  local physical_item,physical_reason=M.physical_item(t,cur,e);if not physical_item then return fail_unsafe(p,t,key,state,physical_reason)end
  if item~=physical_item then return fail_unsafe(p,t,key,state,"physical-output-mismatch:"..safe(item).."!="..safe(physical_item))end
  if e.surface~=p.station.surface then return fail_unsafe(p,t,key,state,"cross-surface-target")end
''',
    "0513 service safety",
)
write(path, text)

# Narrow 0490 to legacy mining and storage safety only.
path = "tech-priests_src/scripts/core/direct_mining_safety_0490.lua"
text = read(path)
text = replace_once(text, 'M.version = "0.1.490"\nM.storage_key = "direct_mining_safety_0490"\n', 'M.version = "0.1.674-dev"\nM.storage_key = "direct_mining_safety_0490"\nM.lifecycle_recovery_retired = true\nM.periodic_authority_retired = true\n', "0490 flags")
text = replace_once(
    text,
    '''local function registry()
  local ok, R = pcall(require, "scripts.core.runtime_event_registry")
  return ok and R or nil
end

''',
    '',
    "0490 registry helper",
)
start = text.index('function M.rescue_missing_priests()')
end = text.index('function M.wrap_pair_dump()', start)
text = text[:start] + text[end:]
text = text.replace('      .. " rescued=" .. tostring(root.stats["rescued-missing-priest"] or 0)\n', '')
start = text.index('function M.register_events()')
end = text.index('function M.install()', start)
text = text[:start] + text[end:]
text = replace_once(
    text,
    '''  M.patch_legacy_direct_gather()
  M.wrap_pair_dump()
  M.register_events()
  M.register_commands()
  if log then log("[Tech-Priests 0.1.490] direct-mining safety installed; direct gathering is literal, station-bound, and no-spill") end
''',
    '''  M.patch_legacy_direct_gather()
  M.wrap_pair_dump()
  if commands and commands.remove_command then pcall(commands.remove_command, "tp-direct-mining-safety-0490") end
  if log then log("[Tech-Priests 0.1.674-dev] legacy direct-mining safety installed without lifecycle recovery or periodic authority") end
''',
    "0490 install narrowing",
)
for forbidden in ('rescue_missing_priests', 'R.on_nth_tick', 'script.on_nth_tick', 'commands.add_command', 'function M.handle_removed'):
    if forbidden in text: raise SystemExit(f"0490 retains forbidden seam: {forbidden}")
write(path, text)

# Remove modules that mutate the retired 0490 rescue seam.
path = "tech-priests_src/scripts/core/task_pair_audit_0498.lua"
text = read(path)
start = text.index('function M.patch_direct_safety_rescue()')
end = text.index('function M.wrap_pair_dump()', start)
text = text[:start] + text[end:]
text = replace_once(text, '  M.patch_respawn_guards()\n  M.patch_direct_safety_rescue()\n  M.wrap_pair_dump()\n', '  M.patch_respawn_guards()\n  M.wrap_pair_dump()\n', "0498 rescue call")
write(path, text)

path = "tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua"
text = read(path)
start = text.index('function M.patch_recovery_modules()')
end = text.index('function M.handle_removed(event)', start)
text = text[:start] + text[end:]
text = replace_once(text, '  M.patch_mobility_upgrade_destroy()\n  M.patch_recovery_modules()\n  M.wrap_pair_dump()\n', '  M.patch_mobility_upgrade_destroy()\n  M.wrap_pair_dump()\n', "0499 rescue call")
write(path, text)

path = "tech-priests_src/scripts/core/priest_recovery_safety_0503.lua"
text = read(path)
start = text.index('local function patch_quarantine_modules()')
end = text.index('local function wrap_pair_dump()', start)
text = text[:start] + text[end:]
text = replace_once(text, '  patch_global_recovery()\n  patch_quarantine_modules()\n  wrap_pair_dump()\n', '  patch_global_recovery()\n  wrap_pair_dump()\n', "0503 quarantine call")
write(path, text)

# Remove retired loader and commands.
path = "tech-priests_src/control.lua"
text = read(path)
old = '''-- 0.1.501: vanish guard. Loaded after the lifecycle seal because the 0.1.500
-- run proved a priest can become invalid while the station and pair remain alive
-- without a recorded destroy/removal event. This seals late direct-mining services
-- and re-enables only controlled missing-priest recovery for testing.
pcall(function()
  local Guard0501 = require("scripts.core.priest_vanish_guard_0501")
  if Guard0501 and Guard0501.install then Guard0501.install() end
end)
'''
text = replace_once(text, old, '-- Historical 0501 vanish/recovery wrapper is retired into canonical acquisition safety and lifecycle observation.\n', "control 0501 loader")
write(path, text)

path = "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua"
text = read(path)
text = replace_once(text, '  ["tp-priest-lifecycle-0500"] = true,\n', '  ["tp-priest-lifecycle-0500"] = true,\n  ["tp-priest-vanish-0501"] = true,\n  ["tp-direct-mining-safety-0490"] = true,\n', "runtime cleanup commands")
write(path, text)

# 0771 no longer depends on the now-retired 0501 source body.
path = "tools/check_lifecycle_seal_0500_boundary_0771.py"
text = read(path)
text = text.replace('    "guard": ROOT / "tech-priests_src/scripts/core/priest_vanish_guard_0501.lua",\n', '')
text = text.replace('    "guard": (\'pair.lifecycle_0499 and pair.lifecycle_0499.last_valid_position\',),\n', '')
text = text.replace('    "guard": (\'pair.lifecycle_0500\',),\n', '')
write(path, text)

# Advance graph and add focused boundary.
path = "tech-priests_src/scripts/core/planning_constraints_0646.lua"
text = read(path)
text = replace_once(text, 'active_hardener_count=26,retired_authority_count=40', 'active_hardener_count=26,retired_authority_count=41', "planning count")
text = replace_once(
    text,
    ' ["scripts.core.priest_lifecycle_seal_0500"]="destruction authorization, replacement denial, pair integrity, and removal observation are native to 0499 and authoritative lifecycle functions",\n',
    ' ["scripts.core.priest_lifecycle_seal_0500"]="destruction authorization, replacement denial, pair integrity, and removal observation are native to 0499 and authoritative lifecycle functions",\n ["scripts.core.priest_vanish_guard_0501"]="protected-target and physical-output validation are native to 0513; lifecycle observation belongs to 0499 and 0490 is safety-only",\n',
    "planning retired 0501",
)
write(path, text)

write(
    "tools/check_vanish_guard_0501_boundary_0772.py",
    '''#!/usr/bin/env python3
"""Validate inert 0501, canonical 0513 target safety, and safety-only 0490."""
from __future__ import annotations
import pathlib
import sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "retired":ROOT/"tech-priests_src/scripts/core/priest_vanish_guard_0501.lua",
 "direct":ROOT/"tech-priests_src/scripts/core/direct_acquisition_executor_0513.lua",
 "legacy":ROOT/"tech-priests_src/scripts/core/direct_mining_safety_0490.lua",
 "audit":ROOT/"tech-priests_src/scripts/core/task_pair_audit_0498.lua",
 "lifecycle":ROOT/"tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua",
 "recovery":ROOT/"tech-priests_src/scripts/core/priest_recovery_safety_0503.lua",
 "control":ROOT/"tech-priests_src/control.lua",
 "cleanup":ROOT/"tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
 "planning":ROOT/"tech-priests_src/scripts/core/planning_constraints_0646.lua",
 "workflow":ROOT/".github/workflows/source-validation.yml",
}
REQUIRED={
 "retired":('retired = true','authority = "priest_vanish_guard_0501"','direct_acquisition_executor_0513 + direct_mining_safety_0490 + priest_lifecycle_authority_0499'),
 "direct":('target_safety_integrated=true','function M.target_is_safe','function M.physical_item','physical-output-mismatch','protected-target','owned-simple-entity'),
 "legacy":('lifecycle_recovery_retired = true','periodic_authority_retired = true','legacy direct-mining safety installed without lifecycle recovery or periodic authority','M.patch_legacy_direct_gather()'),
 "control":('Historical 0501 vanish/recovery wrapper is retired',),
 "cleanup":('["tp-priest-vanish-0501"] = true','["tp-direct-mining-safety-0490"] = true'),
 "planning":('retired_authority_count=41','["scripts.core.priest_vanish_guard_0501"]'),
 "workflow":('Audit retired 0501 vanish guard','check_vanish_guard_0501_boundary_0772.py'),
}
FORBIDDEN={
 "retired":('function M.install','register_service','on_nth_tick','commands.add_command','tech_priests_request_movement_0418','respawn_pair_priest','ensure_pair_priest','pair.target'),
 "legacy":('rescue_missing_priests','R.on_nth_tick','script.on_nth_tick','commands.add_command','function M.handle_removed'),
 "audit":('patch_direct_safety_rescue','rescue_missing_priests','TechPriestsPairLinkHardening0495'),
 "lifecycle":('rescue_missing_priests','direct-safety-rescue-disabled'),
 "recovery":('TechPriestsPriestVanishGuard0501','rescue_missing_priests','patch_quarantine_modules'),
 "control":('require("scripts.core.priest_vanish_guard_0501")',),
}
def main():
 errors=[];texts={n:p.read_text(encoding='utf-8',errors='replace') for n,p in FILES.items()}
 for n,parts in REQUIRED.items():
  for part in parts:
   if part not in texts[n]:errors.append(f'{FILES[n].relative_to(ROOT)} missing contract: {part}')
 for n,parts in FORBIDDEN.items():
  for part in parts:
   if part in texts[n]:errors.append(f'{FILES[n].relative_to(ROOT)} contains forbidden regression: {part}')
 if errors:
  print('0501 boundary audit failed:',file=sys.stderr)
  for error in errors:print('  - '+error,file=sys.stderr)
  return 1
 print('0501 boundary audit passed: 0501 is inert; 0513 owns physical target truth; 0490 is lifecycle-free safety only.')
 return 0
if __name__=='__main__':raise SystemExit(main())
''',
)

for path in (
 "tools/check_movement_cadence_boundary_0761.py","tools/check_combat_proxy_boundary_0762.py",
 "tools/check_direct_acquisition_bounds_boundary_0764.py","tools/check_movement_enforcement_void_boundary_0765.py",
 "tools/check_movement_economy_boundary_0767.py","tools/check_ground_route_loader_boundary_0768.py",
 "tools/check_priest_vanish_0502_boundary_0769.py","tools/check_pair_link_0495_boundary_0770.py",
 "tools/check_lifecycle_seal_0500_boundary_0771.py",
):
 text=read(path)
 if 'retired_authority_count=40' not in text:raise SystemExit(f'count anchor missing: {path}')
 write(path,text.replace('retired_authority_count=40','retired_authority_count=41'))

path="tools/check_recovery_architecture_0744.py"
text=read(path)
text=replace_once(text,'"scripts.core.pair_link_hardening_0495", "scripts.core.priest_lifecycle_seal_0500", "scripts.core.fluid_output_sink_doctrine_0694",','"scripts.core.pair_link_hardening_0495", "scripts.core.priest_lifecycle_seal_0500", "scripts.core.priest_vanish_guard_0501", "scripts.core.fluid_output_sink_doctrine_0694",',"architecture retired set")
text=text.replace('retired_authority_count=40','retired_authority_count=41').replace('"Forty files remain"','"Forty-one files remain"').replace('"40 source-preserved authorities"','"41 source-preserved authorities"').replace('"26 active hardeners and 40 explicitly retired"','"26 active hardeners and 41 explicitly retired"')
write(path,text)

path="tools/check_development_integration_0732.py"
text=read(path)
text=replace_once(text,'    "scripts.core.priest_lifecycle_seal_0500",\n','    "scripts.core.priest_lifecycle_seal_0500",\n    "scripts.core.priest_vanish_guard_0501",\n',"integration retired set")
text=text.replace('retired_authority_count=40','retired_authority_count=41')
text=replace_once(text,'"check_lifecycle_seal_0500_boundary_0771.py",\n','"check_lifecycle_seal_0500_boundary_0771.py", "check_vanish_guard_0501_boundary_0772.py",\n',"integration checker 0772")
write(path,text)

path="tools/check_governance_prerequisites_0738.py"
text=read(path)
for old,new in (
 ('26-active / 40-retired graph','26-active / 41-retired graph'),('26 active hardeners and 40 explicitly retired','26 active hardeners and 41 explicitly retired'),
 ('26 active hardeners and 40 retired source-only authorities','26 active hardeners and 41 retired source-only authorities'),('40 source-preserved authorities','41 source-preserved authorities'),
 ('40 retired source-only authorities','41 retired source-only authorities'),('Forty files remain','Forty-one files remain')):text=text.replace(old,new)
text=replace_once(text,'        "check_lifecycle_seal_0500_boundary_0771.py",\n','        "check_lifecycle_seal_0500_boundary_0771.py",\n        "Audit retired 0501 vanish guard",\n        "check_vanish_guard_0501_boundary_0772.py",\n',"governance 0772")
write(path,text)

# Current authority documents.
path="tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md"
text=read(path).replace('**40 source-preserved authorities**','**41 source-preserved authorities**',1)
anchor='`priest_lifecycle_seal_0500` is retired. Valid-priest preservation and destruction/replacement authorization are native to `0499`; original creation, removal, respawn, mobility, orphan, and platform functions now check that authority before mutating physical priest state.'
if anchor not in text:raise SystemExit('continuity 0500 paragraph missing')
text=text.replace(anchor,anchor+'\n\n`priest_vanish_guard_0501` is retired. `0513` owns protected-target and physical-output truth, `0490` is legacy mining/no-spill safety only, and `0499` owns disappearance observation and pair integrity.',1)
write(path,text)

path="tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
text=read(path).replace('26 active hardeners and 40 retired source-only authorities','26 active hardeners and 41 retired source-only authorities',1).replace('26 attempted active hardeners and 40 retired source-only authorities','26 attempted active hardeners and 41 retired source-only authorities',1)
anchor='`0500` is inert; canonical lifecycle functions fail closed unless `0499` authorizes real station cleanup.'
if anchor not in text:raise SystemExit('testing 0500 statement missing')
text=text.replace(anchor,anchor+' `0501` is inert; `0513` validates physical targets and outputs while `0490` has no lifecycle recovery or timer.',1)
write(path,text)

path="docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
text=read(path).replace('**26 declarative active hardeners** and **40 retired source-only authorities**','**26 declarative active hardeners** and **41 retired source-only authorities**',1).replace('Forty files remain source-preserved','Forty-one files remain source-preserved',1)
anchor='`0500` is retired as a wrapper seal. `0499` exports the fail-closed destruction and replacement policy, while the authoritative generated lifecycle functions establish pair maps on creation and consult `0499` before station cleanup, respawn, mobility, orphan purge, or platform recreation.'
if anchor not in text:raise SystemExit('map 0500 paragraph missing')
text=text.replace(anchor,anchor+'\n\n`0501` is retired as a late vanish, direct-mining, movement, and recovery wrapper. Canonical `0513` now rejects protected targets and physical-output mismatches; `0490` retains only legacy literal-mining/no-spill safeguards; `0499` owns disappearance evidence.',1)
write(path,text)

path="docs/DEVELOPMENT_HISTORY.md"
text=read(path)
section='''### Retired `0501` vanish and recovery wrapper

`priest_vanish_guard_0501` wrapped four direct-mining functions, the canonical movement request API, respawn and ensure, pair-link and mining-safety recovery, diagnostics, events, commands, and a 31-tick rescue loop. Those responsibilities now have canonical owners.

`direct_acquisition_executor_0513` natively rejects priests, stations, owned simple entities, unsupported target types, and physical-output mismatches before movement or extraction. `direct_mining_safety_0490` remains only as legacy literal-mining and no-spill protection; its missing-priest rescue, lifecycle event route, command, and 113-tick timer are removed. `0499` remains the sole disappearance observer. The graph is now **26 active hardeners and 41 explicitly retired source-only authorities**.

Complete Source validation and Factorio runtime evidence remain separately required.

'''
if '### Retired `0501` vanish and recovery wrapper' not in text:text=replace_once(text,'## Current Gate State',section+'## Current Gate State','history current gate')
write(path,text)

path="RECOVERY_REPAIR_SEQUENCE.md"
write(path,read(path).replace('26-active / 40-retired graph','26-active / 41-retired graph',1))

for temporary in (ROOT/".github/workflows/audit-0501-retirement-references-temp.yml",Path(__file__)):
 if temporary.exists():temporary.unlink()
