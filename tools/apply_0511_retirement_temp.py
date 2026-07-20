#!/usr/bin/env python3
from pathlib import Path
import re


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding="utf-8")


# Canonical direct acquisition owns its own target bounds and overleash return.
path = "tech-priests_src/scripts/core/direct_acquisition_executor_0513.lua"
text = read(path)
old_header = '''local M={version="0.1.674-dev",storage_key="direct_acquisition_executor_0513",
  close_distance_sq=2.25,station_distance_sq=4,move_refresh_ticks=120,
  stall_ticks=240,work_ticks=90,visual_ticks=18,max_pairs_per_pulse=24}'''
new_header = '''local M={version="0.1.674-dev",storage_key="direct_acquisition_executor_0513",
  close_distance_sq=2.25,station_distance_sq=4,move_refresh_ticks=120,
  stall_ticks=240,work_ticks=90,visual_ticks=18,max_pairs_per_pulse=24,
  default_direct_radius=32,default_hard_leash=48,bounds_integrated=true,
  direct_radius_by_tier={
    ["planetary-magos"]=24,["planetary_magos"]=24,planetary=24,
    senior=32,intermediate=34,junior=36,
  },
  hard_leash_by_tier={
    ["planetary-magos"]=36,["planetary_magos"]=36,planetary=36,
    senior=48,intermediate=52,junior=56,
  },
}'''
if old_header not in text:
    raise SystemExit('0513 header anchor missing')
text = text.replace(old_header, new_header, 1)
old_dist = 'local function dist2(a,b)if not(a and b)then return 1e12 end;local x=(a.x or 0)-(b.x or 0);local y=(a.y or 0)-(b.y or 0);return x*x+y*y end\n'
new_dist = old_dist + '''local function lower(v)return string.lower(tostring(v or""))end
local function tier_key(p)local t=lower(p and(p.tier or p.rank or p.station_tier or(valid(p.station)and p.station.name)or""));if t:find("planetary",1,true)or t:find("magos",1,true)then return"planetary-magos"end;if t:find("senior",1,true)then return"senior"end;if t:find("intermediate",1,true)then return"intermediate"end;if t:find("junior",1,true)then return"junior"end;return"default"end
local function runtime_radius(p)local r=tonumber(p and p.radius);if type(_G.refresh_pair_radius)=="function"and p then local ok,v=pcall(_G.refresh_pair_radius,p);if ok and tonumber(v)then r=tonumber(v)end end;if not r and type(_G.get_station_operating_radius)=="function"and valid(p and p.station)then local ok,v=pcall(_G.get_station_operating_radius,p.station);if ok and tonumber(v)then r=tonumber(v)end end;return r end
function M.direct_radius(p)local cap=M.direct_radius_by_tier[tier_key(p)]or M.default_direct_radius;return math.max(8,math.min(runtime_radius(p)or cap,cap))end
function M.hard_leash(p)local cap=M.hard_leash_by_tier[tier_key(p)]or M.default_hard_leash;local direct=M.direct_radius(p);local runtime=runtime_radius(p)or cap;return math.max(direct+6,math.min(math.max(runtime,direct+6),cap))end
function M.target_within_bounds(p,pos)
 if not(valid(p and p.station)and pos)then return true,nil,nil end
 local corridor=rawget(_G,"tech_priests_0574_position_allowed");if type(corridor)=="function"then local ok,allowed=pcall(corridor,p,pos,"direct-acquisition-bounds-0513",{owner="direct-acquisition-0513"});if ok and allowed then return true,nil,nil end end
 local distance=math.sqrt(dist2(p.station.position,pos));local maximum=M.direct_radius(p);return distance<=maximum,distance,maximum
end
'''
if old_dist not in text:
    raise SystemExit('0513 distance helper anchor missing')
text = text.replace(old_dist, new_dist, 1)
old_bounds = '''local function within_bounds(p,pos)
 local b=rawget(_G,"TechPriestsMovementBounds0511");if not(b and type(b.target_within_bounds)=="function")then return false,"bounds-authority-unavailable"end
 local ok,a,d,m=pcall(b.target_within_bounds,p,pos);if not ok then return false,"bounds-authority-error:"..safe(a)end;return a==true,d,m
end'''
new_bounds = '''local function within_bounds(p,pos)
 local ok,a,d,m=pcall(M.target_within_bounds,p,pos);if not ok then return false,"bounds-authority-error:"..safe(a)end;return a==true,d,m
end
local function recover_overleash(p,state)
 local maximum=M.hard_leash(p);local distance=math.sqrt(dist2(p.priest.position,p.station.position));if distance<=maximum then return false,nil end
 phase(p,"return-overleash","distance="..safe(distance).." max="..safe(maximum));p.mode="direct-acquisition-returning-overleash"
 local moved,why=request_move(p,p.station.position,"direct-acquisition-0513",760,1,"direct-acquisition-overleash-return-0513")
 state.next_overleash_retry_tick=now()+60;record(moved and"overleash-return-0513"or"overleash-return-failed-0513",p,"distance="..safe(distance).." max="..safe(maximum).." why="..safe(why));return true,moved and"returning-overleash"or"overleash-return-failed"
end'''
if old_bounds not in text:
    raise SystemExit('0513 external bounds dependency anchor missing')
text = text.replace(old_bounds, new_bounds, 1)
old_service = ''' local t,cur,key=current_task(p);local state=p.dispatcher_direct_0513 or{};p.dispatcher_direct_0513=state;state.version=M.version;state.reason=safe(reason);state.last_seen_tick=now()
 if p.direct_acquisition_custody_0513 then return service_custody(p,t,cur,key,state)end
 if not(t and cur)then phase(p,"none","no-direct-task");return false,"no-direct-task"end'''
new_service = ''' local t,cur,key=current_task(p);local state=p.dispatcher_direct_0513 or{};p.dispatcher_direct_0513=state;state.version=M.version;state.reason=safe(reason);state.last_seen_tick=now()
 if p.direct_acquisition_custody_0513 then return service_custody(p,t,cur,key,state)end
 if not(t and cur)then phase(p,"none","no-direct-task");return false,"no-direct-task"end
 if not state.next_overleash_retry_tick or now()>=state.next_overleash_retry_tick then local returning,why=recover_overleash(p,state);if returning then return true,why end end'''
if old_service not in text:
    raise SystemExit('0513 service overleash anchor missing')
text = text.replace(old_service, new_service, 1)
text = text.replace(
    '_G.TechPriestsDirectAcquisitionExecutor0513=M;',
    '_G.TechPriestsDirectAcquisitionExecutor0513=M;_G.tech_priests_direct_target_within_bounds_0513=M.target_within_bounds;',
    1,
)
write(path, text)

# Broker-owned runtime cleanup removes the obsolete command and exact legacy 61-tick route.
path = "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua"
text = read(path)
text = text.replace('  audit_interval = 600,', '  audit_interval = 600,\n  legacy_direct_route_cleanup_integrated = true,', 1)
text = text.replace('  ["tp-movement-0429"] = true,', '  ["tp-movement-0429"] = true,\n  ["tp-movement-bounds-0511"] = true,', 1)
anchor = 'function M.remove_all(reason)\n'
route_fn = '''function M.remove_legacy_direct_route(reason)
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  local routes = registry and registry.nth_tick_routes and registry.nth_tick_routes["61"]
  if type(routes) ~= "table" then return 0, "route-unavailable" end
  local kept, removed = {}, 0
  for _, entry in ipairs(routes) do
    local source = tostring(entry.source or "")
    local line = tonumber(entry.line or 0) or 0
    if source:find("control_legacy_part_016.lua", 1, true) and line >= 820 and line <= 850 then
      removed = removed + 1
    else
      kept[#kept + 1] = entry
    end
  end
  if removed > 0 then
    registry.nth_tick_routes["61"] = kept
    local state = root()
    state.stats["legacy-direct-routes-removed"] = (state.stats["legacy-direct-routes-removed"] or 0) + removed
    state.last_route_cleanup_reason = tostring(reason or "cleanup")
    state.last_route_cleanup_tick = now()
  end
  return removed, removed > 0 and "legacy-direct-route-removed" or "legacy-direct-route-clean"
end

'''
if anchor not in text:
    raise SystemExit('0720 remove_all anchor missing')
text = text.replace(anchor, route_fn + anchor, 1)
old_return = '''  state.last_removed = removed
  state.last_initial = initial_cleanup
  return removed, removed > 0 and "removed" or "clean"
end'''
new_return = '''  local routes_removed, route_why = M.remove_legacy_direct_route(reason)
  removed = removed + routes_removed
  state.last_removed = removed
  state.last_initial = initial_cleanup
  state.last_route_result = route_why
  return removed, removed > 0 and "removed" or "clean"
end'''
if old_return not in text:
    raise SystemExit('0720 remove_all return anchor missing')
text = text.replace(old_return, new_return, 1)
text = text.replace(
    '.. " last_tick=" .. safe(state.last_audit_tick or 0)',
    '.. " legacy_routes_removed=" .. safe(state.stats["legacy-direct-routes-removed"] or 0)\n      .. " last_tick=" .. safe(state.last_audit_tick or 0)',
    1,
)
write(path, text)

# Retire 0511 and remove its loader.
write(
    "tech-priests_src/scripts/core/movement_bounds_contract_0511.lua",
    '''-- scripts/core/movement_bounds_contract_0511.lua
-- Source-preserved retirement marker. Direct target bounds and active-task
-- overleash return are native to direct_acquisition_executor_0513. Obsolete
-- command and legacy route cleanup belong to runtime_command_cleanup_0720.
local M={
 retired=true,
 authority="movement_bounds_contract_0511",
 replacement="direct_acquisition_executor_0513 + runtime_command_cleanup_0720",
}
return M
''',
)
path = "tech-priests_src/control.lua"
text = read(path)
old_loader = '''-- 0.1.511: movement bounds contract. Loaded after the dispatcher so it can
-- keep direct acquisition movement local, decommission the old 0.1.273 hard
-- direct-gather kick, and walk overleashed priests home instead of letting a
-- Planetary Magos chase fallback targets into the wilderness.
do
  local ok, err = pcall(function()
    local Bounds0511 = require("scripts.core.movement_bounds_contract_0511")
    if Bounds0511 and Bounds0511.install then Bounds0511.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.511] movement_bounds_contract_0511 failed to install: " .. tostring(err)) end
end

'''
if old_loader not in text:
    raise SystemExit('control 0511 loader anchor missing')
text = text.replace(old_loader, '-- Historical 0511 bounds wrapper is retired; bounds are native to direct acquisition.\n\n', 1)
write(path, text)

# Declarative graph becomes 26 active / 32 retired.
path = "tech-priests_src/scripts/core/planning_constraints_0646.lua"
text = read(path).replace('active_hardener_count=26,retired_authority_count=31', 'active_hardener_count=26,retired_authority_count=32', 1)
anchor = ' ["scripts.core.combat_magos_movement_authority_0472"]="territory, combat throttling, and proxy sustain are integrated into canonical command, movement, mutex, and proxy owners",'
entry = anchor + '\n ["scripts.core.movement_bounds_contract_0511"]="direct target bounds and overleash recovery are native to direct_acquisition_executor_0513",'
if anchor not in text:
    raise SystemExit('planning 0472 retired anchor missing')
text = text.replace(anchor, entry, 1)
write(path, text)

path = "tools/check_development_integration_0732.py"
text = read(path)
text = text.replace('    "scripts.core.combat_magos_movement_authority_0472",', '    "scripts.core.combat_magos_movement_authority_0472",\n    "scripts.core.movement_bounds_contract_0511",', 1)
text = text.replace('"retired_authority_count=31"', '"retired_authority_count=32"', 1)
text = text.replace('"check_combat_command_boundary_0763.py",', '"check_combat_command_boundary_0763.py", "check_direct_acquisition_bounds_boundary_0764.py",', 1)
write(path, text)

path = "tools/check_recovery_architecture_0744.py"
text = read(path)
text = text.replace('"scripts.core.combat_magos_movement_authority_0472",', '"scripts.core.combat_magos_movement_authority_0472", "scripts.core.movement_bounds_contract_0511",', 1)
text = text.replace('"retired_authority_count=31"', '"retired_authority_count=32"', 1)
text = text.replace('"31 source-preserved authorities"', '"32 source-preserved authorities"', 1)
text = text.replace('"26 active hardeners and 31 explicitly retired"', '"26 active hardeners and 32 explicitly retired"', 1)
text = text.replace('"Thirty-one files remain"', '"Thirty-two files remain"', 1)
text = text.replace('active=26 retired=31 construction=canonical', 'active=26 retired=32 construction=canonical', 1)
text = text.replace(
    '("Audit canonical combat command safety boundary", "check_combat_command_boundary_0763.py"),',
    '("Audit canonical combat command safety boundary", "check_combat_command_boundary_0763.py"),\n        ("Audit canonical direct acquisition bounds", "check_direct_acquisition_bounds_boundary_0764.py"),',
    1,
)
write(path, text)

path = "tools/check_governance_prerequisites_0738.py"
text = read(path)
for old,new in (
    ('26-active / 31-retired graph','26-active / 32-retired graph'),
    ('26 active hardeners and 31 explicitly retired','26 active hardeners and 32 explicitly retired'),
    ('26 active hardeners and 31 retired source-only authorities','26 active hardeners and 32 retired source-only authorities'),
    ('31 source-preserved authorities','32 source-preserved authorities'),
    ('31 retired source-only authorities','32 retired source-only authorities'),
    ('Thirty-one files remain','Thirty-two files remain'),
):
    text=text.replace(old,new)
text=text.replace(
    '"Audit canonical combat command safety boundary",\n        "check_combat_command_boundary_0763.py",',
    '"Audit canonical combat command safety boundary",\n        "check_combat_command_boundary_0763.py",\n        "Audit canonical direct acquisition bounds",\n        "check_direct_acquisition_bounds_boundary_0764.py",',
    1,
)
write(path,text)

# Existing focused checkers track the current retired count.
for checker in (
    "tools/check_movement_cadence_boundary_0761.py",
    "tools/check_combat_proxy_boundary_0762.py",
):
    text=read(checker).replace('retired_authority_count=31','retired_authority_count=32')
    write(checker,text)

# Focused 0764 proof.
write(
    "tools/check_direct_acquisition_bounds_boundary_0764.py",
    '''#!/usr/bin/env python3
"""Validate native direct-acquisition bounds and inert 0511 retirement."""
from __future__ import annotations
import pathlib
import sys

ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "direct":ROOT/"tech-priests_src/scripts/core/direct_acquisition_executor_0513.lua",
 "cleanup":ROOT/"tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
 "retired":ROOT/"tech-priests_src/scripts/core/movement_bounds_contract_0511.lua",
 "control":ROOT/"tech-priests_src/control.lua",
 "planning":ROOT/"tech-priests_src/scripts/core/planning_constraints_0646.lua",
 "workflow":ROOT/".github/workflows/source-validation.yml",
}
REQUIRED={
 "direct":('bounds_integrated=true','function M.direct_radius','function M.hard_leash','function M.target_within_bounds','local function recover_overleash','direct-acquisition-overleash-return-0513','_G.tech_priests_direct_target_within_bounds_0513'),
 "cleanup":('legacy_direct_route_cleanup_integrated = true','["tp-movement-bounds-0511"] = true','function M.remove_legacy_direct_route','control_legacy_part_016.lua','registry.nth_tick_routes["61"] = kept'),
 "retired":('retired=true','authority="movement_bounds_contract_0511"','replacement="direct_acquisition_executor_0513 + runtime_command_cleanup_0720"','return M'),
 "control":('Historical 0511 bounds wrapper is retired',),
 "planning":('retired_authority_count=32','["scripts.core.movement_bounds_contract_0511"]'),
 "workflow":('Audit canonical direct acquisition bounds','check_direct_acquisition_bounds_boundary_0764.py'),
}
FORBIDDEN={
 "direct":('TechPriestsMovementBounds0511','bounds-authority-unavailable'),
 "retired":('function M.install','register_service','on_nth_tick','commands.add_command','tech_priests_request_movement_0418','pair.mode','pair.target'),
 "control":('require("scripts.core.movement_bounds_contract_0511")',),
}
def main():
 errors=[];texts={name:path.read_text(encoding='utf-8',errors='replace')for name,path in FILES.items()}
 for name,parts in REQUIRED.items():
  for part in parts:
   if part not in texts[name]:errors.append(f'{FILES[name].relative_to(ROOT)} missing contract: {part}')
 for name,parts in FORBIDDEN.items():
  for part in parts:
   if part in texts[name]:errors.append(f'{FILES[name].relative_to(ROOT)} contains forbidden regression: {part}')
 if errors:
  print('Direct acquisition bounds audit failed:',file=sys.stderr)
  for error in errors:print('  - '+error,file=sys.stderr)
  return 1
 print('Direct acquisition bounds audit passed: 0513 owns bounds/overleash recovery; 0720 removes the obsolete route/command; 0511 is inert.')
 return 0
if __name__=='__main__':raise SystemExit(main())
''',
)

# Living records.
path="RECOVERY_REPAIR_SEQUENCE.md";write(path,read(path).replace('26-active / 31-retired graph','26-active / 32-retired graph'))
path="tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md";text=read(path)
text=text.replace('The `RETIRED` table contains **31 source-preserved authorities**.','The `RETIRED` table contains **32 source-preserved authorities**.',1)
text=text.replace('- `combat_magos_movement_authority_0472.lua`;','- `combat_magos_movement_authority_0472.lua`;\n- `movement_bounds_contract_0511.lua`;',1)
section='''## Direct acquisition bounds authority

`direct_acquisition_executor_0513.lua` owns tier-capped target bounds, authority-corridor allowance, active-task overleash return, target movement, extraction, custody, return, deposit, replan, and terminal state. `runtime_command_cleanup_0720.lua` removes the exact obsolete 61-tick direct-gather route and the historical movement-bounds command.

`movement_bounds_contract_0511.lua` is retired and inert. It may not wrap target discovery, movement requests, executors, legacy direct functions, diagnostics, commands, or timers.

'''
if '## Direct acquisition bounds authority' not in text:
 anchor='## Construction placement authority'
 if anchor not in text:raise SystemExit('continuity construction anchor missing')
 text=text.replace(anchor,section+anchor,1)
write(path,text)

path="tech-priests_src/docs/CURRENT_TESTING_GOALS.md";text=read(path)
text=text.replace('26 active hardeners and 31 retired source-only authorities','26 active hardeners and 32 retired source-only authorities',1)
anchor='- observer-only friendly-fire predicates in `combat_safety`, consumed by the sole `movement_controller` attack and proxy-prime command wrappers;\n'
bullet='- native tier-bounded direct acquisition and active-task overleash return in `direct_acquisition_executor_0513`, with obsolete route/command cleanup in `runtime_command_cleanup_0720` and `0511` retired;\n'
if bullet not in text:
 if anchor not in text:raise SystemExit('testing combat command anchor missing')
 text=text.replace(anchor,anchor+bullet,1)
text=text.replace('movement-cadence, consolidated combat-proxy, and combat-command safety boundary audits;','movement-cadence, consolidated combat-proxy, combat-command safety, and direct-acquisition bounds audits;',1)
text=text.replace('26 attempted active hardeners and 31 retired source-only authorities','26 attempted active hardeners and 32 retired source-only authorities',1)
write(path,text)

path="docs/RECOVERY_AUTHORITY_MAP_CURRENT.md";text=read(path)
text=text.replace('**31 retired source-only authorities**','**32 retired source-only authorities**',1)
text=text.replace('Planning --> Retired[31 retired authorities]','Planning --> Retired[32 retired authorities]',1)
text=text.replace('Thirty-one files remain source-preserved','Thirty-two files remain source-preserved',1)
section='''## Canonical Direct Acquisition Bounds

```mermaid
flowchart LR
    Task[identified direct task] --> Bounds[0513 tier and corridor bounds]
    Bounds --> Move[movement_controller request]
    Move --> Extract[0513 physical extraction]
    Extract --> Custody[direct_acquisition_custody_0513]
    Custody --> Return[station return and atomic deposit]
    Cleanup[runtime_command_cleanup_0720] --> Legacy[remove exact legacy 61-tick route and command]
```

`movement_bounds_contract_0511` is retired. Bounds, overleash recovery, movement, physical work, custody, and terminal state now remain in one executor path.

'''
if '## Canonical Direct Acquisition Bounds' not in text:
 anchor='## Construction Placement and Physical Execution'
 if anchor not in text:raise SystemExit('map construction anchor missing')
 text=text.replace(anchor,section+anchor,1)
write(path,text)

path="docs/DEVELOPMENT_HISTORY.md";text=read(path)
section='''### Retired `0511` and made direct-acquisition bounds native

`movement_bounds_contract_0511` combined target filtering, movement-request wrapping, an older executor wrapper, three legacy direct-function wrappers, registry surgery, direct engine commands, diagnostics, commands, and a periodic service. Its useful policy is now located in the canonical owners instead of another late layer.

`direct_acquisition_executor_0513` now owns tier-capped target bounds, authority-corridor allowance, and active direct-task overleash return alongside its existing movement, extraction, custody, station return, atomic deposit, replan, and terminal transitions. `runtime_command_cleanup_0720` removes the exact obsolete 61-tick direct-gather route and historical bounds command. `0511` is source-preserved but inert and is no longer loaded.

The declarative graph is now **26 active hardeners and 32 explicitly retired source-only authorities**. Complete Source validation and Factorio runtime evidence remain separately required.

'''
if '### Retired `0511` and made direct-acquisition bounds native' not in text:
 anchor='## Current Gate State'
 if anchor not in text:raise SystemExit('history gate anchor missing')
 text=text.replace(anchor,section+anchor,1)
write(path,text)

Path(__file__).unlink()
