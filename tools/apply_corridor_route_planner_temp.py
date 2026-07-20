#!/usr/bin/env python3
from pathlib import Path
import re


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding="utf-8")


# Convert 0574 into a pure authorization/waypoint planner.
path = "tech-priests_src/scripts/core/authority_corridor_pathing_0574.lua"
text = read(path)
text = text.replace('-- Tech Priests 0.1.574 Cogitator Corridor Pathing Guard.', '-- Tech Priests 0.1.674-dev canonical corridor route planner.', 1)
text = text.replace('M.version = "0.1.574"', 'M.version = "0.1.674-dev"', 1)
text = text.replace('M.service_interval = 113\n', '', 1)
text = text.replace('M.return_reissue_ticks = 60 * 4\n', '', 1)
text = text.replace('local pre_request = nil\n\n', '', 1)
text = text.replace(
    '      guard_movement = true,\n      decompose_long_moves = true,\n      return_on_unwrit_far_move = true,\n      stats = {}, recent = {}, last_log = {}, last_return = {},',
    '      planner_enabled = true,\n      decompose_long_moves = true,\n      stats = {}, recent = {}, last_log = {},',
    1,
)
text = text.replace('  if r.guard_movement == nil then r.guard_movement = true end\n', '  if r.planner_enabled == nil then r.planner_enabled = true end\n', 1)
text = text.replace('  if r.return_on_unwrit_far_move == nil then r.return_on_unwrit_far_move = true end\n', '', 1)
text = text.replace('  r.stats = r.stats or {}; r.recent = r.recent or {}; r.last_log = r.last_log or {}; r.last_return = r.last_return or {}\n', '  r.stats = r.stats or {}; r.recent = r.recent or {}; r.last_log = r.last_log or {}\n', 1)
# Remove all mutating/command ownership between position_allowed and waypoint selection.
text, count = re.subn(
    r'\nlocal function clear_invalid_movement\(pair, reason\).*?\nlocal function nearest_authorized_station_to_current\(pair, pos\).*?\nend\n',
    '\n',
    text,
    count=1,
    flags=re.DOTALL,
)
if count != 1:
    raise SystemExit(f'0574 mutating helper removal count={count}')
# Replace guard_request with pure plan_request.
old_guard = '''function M.guard_request(pair, pos, reason, opts)
  local r=M.root()
  if r.enabled == false or r.guard_movement == false then return true, pos, nil end
  if not (valid_pair(pair) and pos) then return true, pos, nil end
  local ok, rec, source = M.authorization_for_destination(pair, pos, reason, opts)
  if ok then
    if rec and rec.role and rec.role ~= "home" and rec.role ~= "exempt" then stat("authorized_superior_move") end
    local wp, wrec = M.maybe_corridor_waypoint(pair, pos, reason, opts, rec)
    if wp then
      record("corridor-waypoint-0574", pair, "role="..safe(wrec.role).." via="..safe(wrec.station_unit).." final="..safe(string.format("%.1f,%.1f", pos.x or 0, pos.y or 0)))
      return true, wp, { owner="authority-corridor-pathing-0574", radius=M.chunk_radius, priority=tonumber(opts and opts.priority or 700) or 700, ttl=tonumber(opts and opts.ttl or 600) or 600, distraction=opts and opts.distraction }
    end
    return true, pos, nil
  end
  clear_invalid_movement(pair, "unauthorized-corridor")
  record("corridor-move-rejected-0574", pair, "source="..safe(source).." dest="..safe(string.format("%.1f,%.1f", pos.x or 0, pos.y or 0)).." nearest="..safe(rec and rec.station_unit or "none").." reason="..safe(reason).." owner="..safe(opts and opts.owner))
  if r.return_on_unwrit_far_move ~= false then M.return_home(pair, "unauthorized-corridor") end
  return false, pos, nil
end
'''
new_guard = '''function M.plan_request(pair, pos, reason, opts)
  local r=M.root()
  if r.enabled == false or r.planner_enabled == false then return true, pos, nil end
  if not (valid_pair(pair) and pos) then return true, pos, nil end
  local ok, rec, source = M.authorization_for_destination(pair, pos, reason, opts)
  if not ok then
    record("corridor-move-rejected-0574", pair, "source="..safe(source).." dest="..safe(string.format("%.1f,%.1f", pos.x or 0, pos.y or 0)).." nearest="..safe(rec and rec.station_unit or "none").." reason="..safe(reason).." owner="..safe(opts and opts.owner))
    return false, pos, { source=source, nearest_station_unit=rec and rec.station_unit or nil }
  end
  if rec and rec.role and rec.role ~= "home" and rec.role ~= "exempt" then stat("authorized_superior_move") end
  local waypoint, waypoint_rec = M.maybe_corridor_waypoint(pair, pos, reason, opts, rec)
  if waypoint then
    record("corridor-waypoint-0574", pair, "role="..safe(waypoint_rec.role).." via="..safe(waypoint_rec.station_unit).." final="..safe(string.format("%.1f,%.1f", pos.x or 0, pos.y or 0)))
    return true, waypoint, {
      radius=M.chunk_radius,
      priority=math.max(tonumber(opts and opts.priority or 0) or 0, 700),
      ttl=tonumber(opts and opts.ttl or 600) or 600,
      distraction=opts and opts.distraction,
      corridor_waypoint=true,
      corridor_role=waypoint_rec.role,
      corridor_station_unit=waypoint_rec.station_unit,
      corridor_final_destination={x=pos.x,y=pos.y},
    }
  end
  return true, pos, nil
end
'''
if old_guard not in text:
    raise SystemExit('0574 guard_request anchor missing')
text = text.replace(old_guard, new_guard, 1)
# Remove wrapper/service/command/timer tail and replace with observer-only install.
text, count = re.subn(
    r'\nlocal function wrap_request\(\).*?\nfunction M\.install\(\).*?\nend\n\nreturn M\s*$',
    '''
function M.install()
  M.root()
  _G.TECH_PRIESTS_AUTHORITY_CORRIDOR_PATHING_0574 = M
  _G.tech_priests_0574_position_allowed = M.position_allowed
  _G.tech_priests_0574_authorization_for_destination = M.authorization_for_destination
  _G.tech_priests_0574_plan_request = M.plan_request
  record("install", nil, "observer-only corridor route planner installed", true)
  if log then log("[Tech-Priests 0.1.674-dev] observer-only Cogitator corridor route planner installed") end
  return true
end

return M''',
    text,
    count=1,
    flags=re.DOTALL,
)
if count != 1:
    raise SystemExit(f'0574 ownership tail replacement count={count}')
write(path, text)

# Canonical movement controller calls the planner before state mutation.
path = "tech-priests_src/scripts/core/movement_controller.lua"
text = read(path)
text = text.replace('M.enforcement_integrated = true', 'M.enforcement_integrated = true\nM.corridor_planner_integrated = true', 1)
old_head = '''function M.request(pair, destination, reason, opts)
  opts = opts or {}
  if not (pair and pair.priest and pair.priest.valid and destination) then return false end
  if is_space_pair(pair) and not opts.force_ground_controller then
    local backend = void_backend()
    if backend and type(backend.request) == "function" then return backend.request(pair, destination, reason, opts) end
    return false, "void-movement-backend-unavailable"
  end
  local root = ensure_root()
  local key = pair_key(pair)
  if not key then return false end
  local allowed, distance, maximum = M.position_allowed(pair, destination, reason, opts)
'''
new_head = '''function M.request(pair, destination, reason, opts)
  opts = opts or {}
  if not (pair and pair.priest and pair.priest.valid and destination) then return false end
  local corridor_rejected = false
  local planner = rawget(_G, "tech_priests_0574_plan_request")
  if type(planner) == "function" and opts.skip_corridor_planner ~= true then
    local ok, allowed, planned_destination, planned_opts = pcall(planner, pair, destination, reason, opts)
    if ok then
      if allowed == false then
        corridor_rejected = true
      elseif planned_destination then
        destination = planned_destination
        if type(planned_opts) == "table" then
          local merged = {}
          for key, value in pairs(opts) do merged[key] = value end
          for key, value in pairs(planned_opts) do merged[key] = value end
          opts = merged
          if planned_opts.corridor_waypoint then reason = "corridor-waypoint-0574" end
        end
      end
    end
  end
  if is_space_pair(pair) and not opts.force_ground_controller then
    if corridor_rejected then return false, "void-corridor-not-authorized" end
    local backend = void_backend()
    if backend and type(backend.request) == "function" then return backend.request(pair, destination, reason, opts) end
    return false, "void-movement-backend-unavailable"
  end
  local root = ensure_root()
  local key = pair_key(pair)
  if not key then return false end
  local allowed, distance, maximum = M.position_allowed(pair, destination, reason, opts)
  if corridor_rejected then allowed = false end
'''
if old_head not in text:
    raise SystemExit('movement request planner insertion anchor missing')
text = text.replace(old_head, new_head, 1)
text = text.replace(
    '    last_distance_sq = nil\n  }',
    '    last_distance_sq = nil,\n    corridor_waypoint = opts.corridor_waypoint == true,\n    corridor_role = opts.corridor_role,\n    corridor_station_unit = opts.corridor_station_unit,\n    corridor_final_destination = opts.corridor_final_destination\n  }',
    1,
)
text = text.replace(
    '      " enforcement_rejected=" .. tostring((root.stats or {}).destinations_rejected_0566 or 0) ..',
    '      " enforcement_rejected=" .. tostring((root.stats or {}).destinations_rejected_0566 or 0) ..\n      " corridor_planner_integrated=true" ..',
    1,
)
write(path, text)

# Cleanup historical command on upgrades.
path = "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua"
text = read(path).replace('  ["tp-void-movement-0630"] = true,', '  ["tp-void-movement-0630"] = true,\n  ["tp-path-corridors-0574"] = true,', 1)
write(path, text)

# Permanent validation wiring. Graph count remains 26/33.
path = "tools/check_development_integration_0732.py"
text = read(path).replace('"check_movement_enforcement_void_boundary_0765.py",', '"check_movement_enforcement_void_boundary_0765.py", "check_corridor_route_planner_boundary_0766.py",', 1)
write(path, text)
path = "tools/check_recovery_architecture_0744.py"
text = read(path).replace(
    '("Audit canonical movement enforcement and void backend", "check_movement_enforcement_void_boundary_0765.py"),',
    '("Audit canonical movement enforcement and void backend", "check_movement_enforcement_void_boundary_0765.py"),\n        ("Audit observer-only corridor route planner", "check_corridor_route_planner_boundary_0766.py"),',
    1,
)
write(path, text)
path = "tools/check_governance_prerequisites_0738.py"
text = read(path).replace(
    '"Audit canonical movement enforcement and void backend",\n        "check_movement_enforcement_void_boundary_0765.py",',
    '"Audit canonical movement enforcement and void backend",\n        "check_movement_enforcement_void_boundary_0765.py",\n        "Audit observer-only corridor route planner",\n        "check_corridor_route_planner_boundary_0766.py",',
    1,
)
write(path, text)

write(
    "tools/check_corridor_route_planner_boundary_0766.py",
    '''#!/usr/bin/env python3
"""Validate observer-only corridor planning and movement-controller execution."""
from __future__ import annotations
import pathlib
import sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "planner":ROOT/"tech-priests_src/scripts/core/authority_corridor_pathing_0574.lua",
 "movement":ROOT/"tech-priests_src/scripts/core/movement_controller.lua",
 "cleanup":ROOT/"tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
 "workflow":ROOT/".github/workflows/source-validation.yml",
}
REQUIRED={
 "planner":('M.version = "0.1.674-dev"','function M.authorization_for_destination','function M.position_allowed','function M.maybe_corridor_waypoint','function M.plan_request','observer-only corridor route planner','_G.tech_priests_0574_plan_request = M.plan_request'),
 "movement":('M.corridor_planner_integrated = true','rawget(_G, "tech_priests_0574_plan_request")','corridor_rejected','corridor_final_destination = opts.corridor_final_destination','reason = "corridor-waypoint-0574"'),
 "cleanup":('["tp-path-corridors-0574"] = true',),
 "workflow":('Audit observer-only corridor route planner','check_corridor_route_planner_boundary_0766.py'),
}
FORBIDDEN={
 "planner":('TECH_PRIESTS_0574_PRE_REQUEST_MOVEMENT_0418','tech_priests_request_movement_0418 =','clear_invalid_movement','return_home','set_command','commands.add_command','TechPriestsRuntimeEventRegistry','registry.on_nth_tick','script.on_nth_tick','pair.movement_request_0418 =','pair.move_target ='),
}
def main():
 errors=[];texts={name:path.read_text(encoding='utf-8',errors='replace') for name,path in FILES.items()}
 for name,parts in REQUIRED.items():
  for part in parts:
   if part not in texts[name]:errors.append(f'{FILES[name].relative_to(ROOT)} missing contract: {part}')
 for name,parts in FORBIDDEN.items():
  for part in parts:
   if part in texts[name]:errors.append(f'{FILES[name].relative_to(ROOT)} contains forbidden ownership regression: {part}')
 if errors:
  print('Corridor route planner audit failed:',file=sys.stderr)
  for error in errors:print('  - '+error,file=sys.stderr)
  return 1
 print('Corridor route planner audit passed: 0574 plans authorization/waypoints; movement_controller alone mutates movement state and issues commands.')
 return 0
if __name__=='__main__':raise SystemExit(main())
''',
)

# Living records.
path = "tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md"
text = read(path)
section = '''## Authority-corridor route planning

`authority_corridor_pathing_0574.lua` is an observer-only authorization and waypoint planner. It reads the authorized-pair topology from `0573`, determines whether a destination is legal, and may propose a superior-station waypoint plus the preserved final destination. It does not replace the movement API, clear pair movement state, command priests, return them home, register a timer, or install commands.

`movement_controller.lua` consumes the proposal before accepting a request and remains the sole owner of request state, rejection, return routing, and engine commands.

'''
if '## Authority-corridor route planning' not in text:
    anchor = '## Ground enforcement and Void backend authority'
    if anchor not in text: raise SystemExit('continuity ground enforcement anchor missing')
    text = text.replace(anchor, section + anchor, 1)
write(path, text)

path = "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
text = read(path)
anchor = '- native ground envelope enforcement and Void-backend delegation in `movement_controller`, with `void_movement_authority_0630` broker-only and `movement_enforcement_0566` retired;\n'
bullet = '- observer-only corridor authorization and waypoint proposals in `authority_corridor_pathing_0574`, consumed by the sole movement controller before request mutation;\n'
if bullet not in text:
    if anchor not in text: raise SystemExit('testing enforcement anchor missing')
    text = text.replace(anchor, anchor + bullet, 1)
text = text.replace('movement-enforcement/Void-backend audits;', 'movement-enforcement/Void-backend and corridor-route-planner audits;', 1)
write(path, text)

path = "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
text = read(path)
anchor = '`movement_enforcement_0566` is retired. The Void backend does not patch ground authorities or public globals, and its former child pulse is loaded explicitly.'
replacement = anchor + '\n\n`authority_corridor_pathing_0574` is a pure planner: it proposes authorization and optional waypoints, while `movement_controller` owns rejection, request state, return movement, and engine commands.'
if anchor not in text: raise SystemExit('map enforcement paragraph missing')
text = text.replace(anchor, replacement, 1)
write(path, text)

path = "docs/DEVELOPMENT_HISTORY.md"
text = read(path)
section = '''### Converted `0574` from movement wrapper to route planner

`authority_corridor_pathing_0574` previously replaced the canonical request API, cleared movement compatibility fields, directly stopped priests, initiated return movement, scanned every pair on a periodic route, and installed its own command. Its actual distinct value is authorization and waypoint selection, not execution.

The module is now an observer-only route planner. `movement_controller` calls it before request acceptance, preserves proposed final-destination metadata on the canonical request, and remains solely responsible for rejection, return routing, request state, and engine commands. The obsolete corridor command is removed by runtime cleanup. The authority count remains **26 active / 33 retired** because `0574` remains a useful non-mutating planner rather than being retired.

Complete Source validation and Factorio runtime evidence remain separately required.

'''
if '### Converted `0574` from movement wrapper to route planner' not in text:
    anchor = '## Current Gate State'
    if anchor not in text: raise SystemExit('history gate anchor missing')
    text = text.replace(anchor, section + anchor, 1)
write(path, text)

Path(__file__).unlink()
