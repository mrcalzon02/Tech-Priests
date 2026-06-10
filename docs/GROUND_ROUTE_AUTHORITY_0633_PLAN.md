# Ground Route Authority 0633 Plan

## Purpose

`ground_route_authority_0633.lua` will convert Tech-Priest ground movement from a loose destination-command model into a measured route contract that matches Factorio's unit movement system.

Factorio's `go_to_location` command is useful as an actuator, but it is not a precise labor contract. It accepts a destination, radius, distraction policy, and pathfinder flags, then lets the engine unit AI decide how to path. The Tech-Priest mod therefore must own the real movement truth: legality, route lease, waypoint sequence, arrival, failure, recall, and task handoff.

## Existing systems to preserve and reuse

### `movement_controller.lua`

Keep as the low-level ground command actuator. It should continue to be the place where actual `set_command` calls are funneled, but it should receive shorter and more explicit waypoint commands from 0633 instead of broad final destinations from every executor.

### `movement_enforcement_0566.lua`

Keep as the leash and safety governor. 0633 should ask 0566 whether a final target and each waypoint are legal before issuing movement. 0566 still owns stale/far target rejection and return-home behavior.

### `authority_corridor_pathing_0574.lua`

Reuse this as the authorized station-corridor policy source. 0574 already knows whether a destination is within home station coverage, superior station coverage, or an authorized corridor, and it can decompose long authorized movement into a station-corridor waypoint. 0633 should call or mirror this policy before issuing any visible path command.

### `efficiency_economy_0572.lua`

Preserve this as the unobserved transit fast path. 0572 already defines unobserved movement as: no player can observe the priest, destination, or owning station; the pair is same-surface; the destination is inside station radius; and the reason is not combat/conversation/player-visible. 0633 should route through this first for eligible work movement, because when movement is unobserved we do not need engine pathfinding at all.

### `void_movement_authority_0630.lua`

Do not merge with 0633. Void Priests remain separate. 0633 is only for ground priests.

## New movement contract

Every ground movement request should be converted into this internal shape:

```lua
{
  owner = "direct-acquisition-0513",
  reason = "direct-acquisition-travel-0513",
  final_target = { x = ..., y = ... },
  final_radius = 0.75,
  station_unit = ...,
  priest_unit = ...,
  task_key = "direct_acquisition_task_0336",
  sequence = 42,
  issued_tick = game.tick,
  expires_tick = game.tick + ttl,
  state = "planning" | "unobserved-transit" | "requesting-path" | "moving-waypoint" | "arrived" | "failed" | "recalled",
  waypoint = { x = ..., y = ... },
  path_handle = nil,
  source = "route-authority-0633"
}
```

The final target is task intent. The waypoint is the only thing given to Factorio's unit movement command.

## Decision order

0633 should evaluate movement in this exact order:

1. Reject invalid pair, invalid priest, invalid station, cross-surface ground movement, or missing destination.
2. Reject or recall if 0566 says the final target is outside the legal work envelope.
3. If the pair is a Void Priest, refuse and let 0630 own it.
4. If the request is eligible for unobserved travel, hand it to 0572 or perform the same unobserved-safe transit path.
5. If 0574 authorizes a corridor waypoint, issue only that waypoint, not the final work target.
6. If the final target is near and legal, issue a short explicit `go_to_location` command to a legal waypoint/final approach point.
7. If a route is not obvious or repeated movement failure occurred, request an async `LuaSurface.request_path` route and store the returned handle.
8. On `on_script_path_request_finished`, store the returned waypoints and issue only the next bounded waypoint.
9. Complete movement only when 0633's own distance check says the priest is within the requested radius of the final target.
10. Report movement completion/failure to the task owner through existing 0418-compatible status fields.

## Visible movement command rules

When 0633 issues a visible ground movement command, it must always set:

```lua
{
  type = defines.command.go_to_location,
  destination = waypoint,
  radius = explicit_radius,
  distraction = defines.distraction.none,
  pathfind_flags = {
    cache = false for recall/recovery/repeated failure,
    cache = true for ordinary stable work movement,
    prefer_straight_paths = true for short same-station waypoints,
    low_priority = true for background non-urgent work,
  }
}
```

No executor should issue an unbounded final target directly to engine pathing.

## Unobserved movement rule

When no player can observe the priest, destination, or station, and the destination is legal and same-surface, 0633 should prefer simulated travel rather than engine pathing.

This must preserve the 0572 behavior:

- Do not simulate combat, retreat, conversation, player-following, or player-visible movement.
- Do not simulate cross-surface movement.
- Do not simulate movement outside the station/corridor authorization envelope.
- Move the priest to a non-colliding destination near the final target.
- Stop the priest after simulated transit.
- Clear the active movement request.
- Let the work executor perform its own proximity/work/deposit gate afterward.

## Corridor movement rule

If a final destination is legal only because a superior-station corridor or authorized writ exists, 0633 should not issue one wilderness path to the final target.

It should ask the corridor policy for the next station waypoint and issue only that waypoint. Once the priest enters authorized station coverage, the executor or 0633 can re-evaluate the final destination and issue the next waypoint.

## Path request use

0633 should use `LuaSurface.request_path` only when one of these is true:

- The priest has failed or stalled on the same visible route more than once.
- The destination is legal but far enough that a single command is too vague.
- A corridor waypoint cannot be simplified by station coverage.
- Obstruction handling needs a real path result instead of repeated melee obstruction behavior.

Path results are advisory. They are used to create bounded waypoints; they do not define task completion.

## Executor integration order

### Phase 1: wrapper only

Wrap `_G.tech_priests_request_movement_0418` after 0572, 0574, and 0566 are installed. Do not modify executors yet.

0633 should consume movement requests, create a route lease, and issue equivalent movement through the existing actuator.

### Phase 2: direct acquisition first

Convert `direct_acquisition_executor_0513.lua` to call 0633 explicitly for resource travel, because this is where the current lost-child behavior is most visible.

### Phase 3: logistics and construction

Convert:

- `logistics_fetch_executor_0527.lua`
- `logistics_machine_fulfillment_0528.lua`
- `ground_item_hoover_0529.lua`
- `construction_planner.lua`

These all already have proximity gates, so the route authority only needs to own travel truth.

### Phase 4: repair/consecration/crafting

Convert:

- `repair_executor_0516.lua`
- `consecration_executor_0515.lua`
- `crafting_executor.lua`
- `emergency_production_executor_0514.lua`

These should be lower risk after direct acquisition/logistics are stable.

## Diagnostics

Add `/tp-ground-route-0633` showing:

- active route leases
- visible waypoint commands issued
- unobserved simulated moves delegated/performed
- corridor waypoints delegated/performed
- async path requests pending/completed/failed
- route owner/reason/final target/current waypoint
- recalled/expired/replaced routes
- direct-acquisition routes rejected before command issue

## Acceptance criteria

0633 is considered successful when:

- No direct-acquisition request can issue an engine command to a final destination outside the station/corridor legal envelope.
- Priests no longer fight return-home enforcement by immediately reissuing ore/resource travel.
- Unobserved in-radius work movement continues to complete without visible pathing calls.
- Observed priests still visibly walk.
- Corridor-authorized long movement decomposes through station waypoints.
- Executors still own actual work completion through their own proximity gates.
- Movement completion is determined by 0633/0418 distance checks, not by trusting the engine command as task truth.

## Implementation note

Do not remove the recall guard in 0.1.632 immediately. It is a useful safety net while 0633 is introduced. Once 0633 is proven to prevent illegal final target commands before issue, the guard can become mostly diagnostic instead of corrective.
