# Stage 5 Checkpoint — Construction Ownership and Contracts

This checkpoint records the Stage 5 dead-end/state review of construction ownership.

This is documentation-only. No runtime behavior has been changed by this note.

## Files reviewed

```text
scripts/core/construction_planner.lua
scripts/core/construction_site_planner.lua
```

## Plain-English result

Construction is active and brokered. It is not merely a passive planner.

The current construction ownership split is:

```text
construction_planner.lua
  owns task selection, source inventory lookup, movement phases, item removal, entity placement, diagnostics, and periodic service

construction_site_planner.lua
  owns placement scanning only: where a machine can safely go
```

This split is mostly healthy. The site planner is deliberately inventory-free and state-free. The main Stage 5 risks live in `construction_planner.lua`, especially movement request failure and placement transaction behavior.

No immediate code repair is recommended from this pass.

## Confirmed healthy structures

### Construction planner is brokered

`construction_planner.lua` installs through the runtime tick broker when available:

```text
broker.register_service({
  name = "construction_planner_0359",
  category = "construction",
  interval = Build.service_period,
  priority = 55,
  budget = Build.max_per_pulse,
  fn = function(event, budget) return Build.service_all("broker-periodic") end,
})
```

It falls back to the runtime event registry or direct `script.on_nth_tick` only if the broker is unavailable.

Disposition:

```text
Construction has a continuing service owner.
```

### Site planner is properly narrow

`construction_site_planner.lua` explicitly keeps inventory ownership out of placement planning. It only decides where something can safely go.

It checks:

- Factorio `can_place_entity`;
- footprint clearance;
- buffer clearance;
- assembler side access;
- resource patch placement for miners;
- station spiral placement for machines/emergency facilities.

Disposition:

```text
Good separation. No state repair target in site planner from this pass.
```

### Station-bound inventory doctrine exists

`construction_planner.lua` does not deliberately use the priest main inventory as active construction stock. It prefers station-bound sources through:

```text
tech_priests_0358_station_sources_for_pair
tech_priests_inventory_steward_sources_for_pair
station inventory fallback
```

Disposition:

```text
Healthy inventory ownership doctrine.
```

### Missing item cancels task cleanly

If a task exists but the item source disappears, service clears:

```text
pair.construction_task_0338 = nil
```

and returns `missing-item`.

Disposition:

```text
Healthy missing-source cleanup.
```

### Placement failure clears task

When the priest reaches the target and `try_place(...)` fails, `Build.service_pair(...)` clears:

```text
pair.construction_task_0338 = nil
```

and records failure stats/status.

Disposition:

```text
Healthy no-permanent-task behavior after actual placement attempt.
```

### Create failure refunds item

`try_place(...)` removes one item from the source inventory before calling `surface.create_entity(...)`. If creation fails after removal, it attempts to refund the item to the source inventory.

Disposition:

```text
Good transactional mitigation, though not perfect.
```

## Watch item 1 — return-to-station ignores movement request failure

When a non-priest source exists and the priest is not near the station, `Build.service_pair(...)` does:

```text
if stale then set_move(pair, pair.station.position, "returning-to-station-for-build") end
task.phase = "returning-to-station"
return true, "returning-station"
```

`set_move(...)` returns false if movement request submission fails, but this return value is ignored.

Potential consequence:

```text
Construction can report returning-to-station even if no movement request was accepted.
The task can stay in returning-to-station while the priest is not moving.
```

Current disposition:

```text
Movement-contract watch item. Do not patch during audit-only continuation.
```

Future repair shape:

```text
If set_move(...) returns false, record movement-request-failed-construction and return false or enter short retry/cooldown instead of claiming returning-station.
```

## Watch item 2 — moving-to-build-site ignores movement request failure

When the priest is not close to the build site, the planner does:

```text
if stale then set_move(pair, task.target_position, "moving-to-build-site") end
task.phase = "moving-to-site"
pair.mode = "construction-moving"
return true, "moving-site"
```

Again, if `set_move(...)` fails, the task still reports movement.

Potential consequence:

```text
Construction can sit in moving-to-site with no accepted movement request.
```

Current disposition:

```text
Movement-contract watch item.
```

This belongs with the broader movement completion/status contract family.

## Watch item 3 — movement phases have no explicit timeout

Construction refreshes movement commands every `Build.move_refresh_ticks`, but there is no visible maximum travel time or stale-task timeout for:

```text
returning-to-station
moving-to-site
```

If movement remains impossible but the task item remains available, the task can persist indefinitely.

Current disposition:

```text
Watch item. Not higher priority than 0527/0528 because construction at least keeps refreshing movement and clears on item disappearance or placement attempt.
```

Future repair shape:

```text
Track phase_started_tick / last_progress_distance and abandon/replan after a bounded timeout.
```

## Watch item 4 — site can become blocked during travel

The construction site is planned once when the task is created. The planner does not continuously revalidate `can_place(...)` while the priest is walking. It revalidates only at placement time in `try_place(...)`.

If the site becomes blocked while the priest is traveling, the priest may walk there, fail placement, clear the task, and later replan on a future service pulse.

Current disposition:

```text
Probably acceptable. Wastes travel but does not dead-end permanently.
```

## Watch item 5 — remove-before-create is transactionally mitigated but still sensitive

`try_place(...)` does:

```text
remove_one(source.inv, task.item_name)
surface.create_entity(...)
if create failed then source.inv.insert(...)
```

This is safer than no refund, but still not perfectly transactional:

- source inventory may become invalid before refund;
- refund insert can fail if inventory changed;
- item quality/metadata may not be preserved if relevant;
- entity creation side effects may partially occur before failure in unexpected modded cases.

Current disposition:

```text
Watch item, not immediate repair. Lower priority than 0528 output removal because construction checks can_place immediately before removal and attempts refund on failure.
```

Future repair shape:

```text
Strengthen preflight and record explicit refund-failed diagnostics if insert fails.
```

## Watch item 6 — no explicit construction reservation/claim layer

Construction planning selects a site and stores it in `pair.construction_task_0338`, but this pass did not find a shared construction reservation/claim comparable to repair/consecration/combat-repair reservations.

Potential consequence:

```text
Multiple priests could theoretically plan the same or overlapping build site if they see similar placeable inventories and scans.
```

The risk may be reduced by:

- station-bound inventory item scarcity;
- `can_place(...)` revalidation at placement time;
- task clearing on blocked placement;
- site planner clearance checks.

Current disposition:

```text
Low/medium watch item. Not a current top repair target.
```

Future repair shape:

```text
Add construction-site reservation keyed by surface/rounded target position/entity footprint if duplicate planning becomes visible in testing.
```

## Relationship to previous Stage 5 findings

Construction confirms the same broad pattern found in 0527/0528, 0514, 0515, and 0516:

```text
movement requested does not equal movement completed;
callers can report moving/returning phases without checking failed movement request submission.
```

However, construction has cleaner task cleanup than the machine logistics chain because:

- missing source item clears the task;
- blocked placement clears the task after arrival;
- create failure attempts refund;
- periodic broker service exists.

Therefore construction is not the top repair family right now.

## Current Stage 5 decision

No code repair from this pass.

Updated priority ranking:

```text
1. 0527/0528 machine logistics / known-source fetch stale-state cleanup.
2. 0513 direct acquisition deposit/gathered_units correctness.
3. Movement completion/status contract across movement-dependent executors.
4. 0514 emergency production returning/deposit-block diagnostics.
5. 0516 repair movement failure/reservation release refinement.
6. 0515 consecration movement failure/cooldown-claim refinement.
7. 0517 low-priority direct-call abort symmetry and cluster-release refinement.
8. construction movement failure/timeout and optional site reservation refinement.
```

## Recommended live diagnostics after packaging

Use:

```text
/tp-build-0359
/tp-runtime-report
/tp-task-auspex
```

Watch for:

- `construction_task_0338.phase=returning-to-station` while `movement_request_0418` is nil;
- `construction_task_0338.phase=moving-to-site` while `movement_request_0418` is nil;
- repeated movement refresh without distance shrinking;
- placement failure due to blocked site after long travel;
- refund-failed cases if source inventory becomes invalid;
- multiple priests planning the same/overlapping site.

## Recommended next audit target

Continue Stage 5 with ordinary combat ownership and direct command surfaces:

```text
ordinary combat ownership
remaining direct set_command calls outside movement_controller.lua
```

The next concrete audit should search/directly inspect modules that still issue `set_command` outside `movement_controller.lua`, because those are the remaining places that can bypass the movement contract entirely.
