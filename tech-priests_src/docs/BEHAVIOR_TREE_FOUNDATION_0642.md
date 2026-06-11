# Tech-Priests Behavior Tree Foundation — 0.1.642

This document is the canonical foundation behavior tree for the Tech-Priests runtime as of the 0.1.641 repair line. It is intentionally a design-and-audit document first, not a new controller. The immediate purpose is to create a stable tree against which the real code can be audited, instrumented, and repaired.

The current runtime already contains several partial authorities: the legacy scheduler behavior-tree map, the runtime broker, the single dispatcher, the action arbiter, direct acquisition, emergency production, emergency facilities, infrastructure-first gating, inventory/deposit safety, construction, repair, combat repair, machine logistics, consecration, cataloging, and idle/chatter. The failure pattern that produced servitor-parts chasing and copper wandering came from those authorities not having a single documented entry/ongoing/exit contract.

From this point forward, every behavior mode must have:

- Entry conditions: what is allowed to create or claim the mode.
- Ongoing conditions: what must remain true while the mode continues.
- Exit conditions: what clears the mode and what state is left behind.
- Failure exits: how the mode leaves safely when blocked, stale, invalid, unreachable, or impossible.
- Observability: command/report/log fields that prove the mode is alive, progressing, waiting, blocked, or complete.

No behavior should be considered valid if it has an entry but no explicit exit.

---

## 1. Current high-level truth from code

The old `scheduler_behavior_tree.lua` lists the intended scheduler priority order: validate pair, combat defense, repair, active work continuation, inventory cleanup, emergency facility doctrine, acquisition doctrine, construction placement, consecration, arterial planning, catalog refresh, chatter, and idle. That old file also states it is meant to make ownership visible so future cleanup can move behavior by explicit ownership instead of guesswork.

The newer runtime has moved much of the actual authority elsewhere:

- `runtime_tick_broker.lua` is the timing/budget spine for registered services.
- `single_dispatcher_0510.lua` is the visible-action dispatcher for direct acquisition, station craft, consecration, repair, and combat repair.
- `action_state_arbiter_0488.lua` decides which visible action family owns beams/status on a tick and suppresses misleading stale visuals.
- `direct_acquisition_executor_0513.lua` owns direct acquisition as a phase machine.
- `emergency_production_executor_0514.lua` owns station/emergency production as a phase machine.
- `emergency_facility_doctrine.lua` owns emergency facility discovery, tagging, build requests, recipe setting, and facility feeding.
- `infrastructure_first_governor_0640.lua` currently gates high-tier station/cogitator requests behind local emergency smelter/miner/assembler and plate production.

The behavior tree below treats those as leaf authorities under one documented pair-level tree.

---

## 2. Canonical pair-level tree

### BT-000 — Cogitator station placement and pair identity

**Purpose:** Convert a placed Cogitator Station into one valid station-priest pair and keep the pair indexed.

**Entry conditions:**

- A Cogitator Station exists, is built, resurrected, revived, migrated, or discovered by repair/recovery code.
- The station either has no priest, has an invalid priest, or has a priest whose unit mapping is stale.

**Ongoing conditions:**

- `pair.station` is valid.
- `pair.priest` is valid.
- `pair.station_unit`, `pair.priest_unit`, `pairs_by_station`, `pairs_by_priest`, and `station_by_priest` agree.
- The priest is non-disposable and not allowed to vanish because commands fail.

**Exit conditions:**

- Pair is valid and indexed.
- Station and priest can be selected and diagnosed.

**Failure exits:**

- If station invalid: delete/forget pair.
- If priest invalid: respawn/reimprint or mark recovery state.
- If station and priest disagree: relink by current valid entity handles.

**Observability:**

- Dispatcher selected-pair diagnostics.
- Pair recovery / vanish guard diagnostics.
- Future required field: `pair.behavior_node = "BT-000"` during relink/recovery.

---

### BT-010 — Runtime service spine

**Purpose:** Decide which services are due without letting broad nth-tick loops all behave as independent controllers.

**Entry conditions:**

- Mod runtime initializes.
- Services register with interval, priority, category, budget, and function.

**Ongoing conditions:**

- Broker remains enabled.
- Services run only when due.
- Services report run, acted, skipped, sleeping, budget exhausted, and errors.

**Exit conditions:**

- Service finishes one pulse and returns acted/detail.
- Service updates its own `next_due_tick`.

**Failure exits:**

- Service error is caught and logged by broker.
- Disabled services are skipped, not executed.

**Observability:**

- `/tp-runtime-report` broker service count, run counts, skipped counts, budget/exhaustion, error count, profiler lines.

---

### BT-020 — Pair validation and recovery gate

**Purpose:** No behavior below this node may run against an invalid pair.

**Entry conditions:**

- Any pair service pulse begins.
- Dispatcher starts `service_pair`.

**Ongoing conditions:**

- `valid(pair.station)` and `valid(pair.priest)` remain true.
- Identity indexes remain repaired by dispatcher identity repair.

**Exit conditions:**

- Pair is valid and lower-priority behavior may evaluate.

**Failure exits:**

- Invalid pair returns `invalid-pair`, `disabled-or-invalid`, or recovery-state result.
- No physical action is attempted.

**Observability:**

- Dispatcher selected-pair diagnostics.
- Pair recovery diagnostics.
- Required future audit: every leaf service should return a standardized invalid-pair result.

---

### BT-030 — Single visible action arbitration

**Purpose:** Prevent old craft/acquisition/combat/consecration fields from all drawing or acting at the same time.

**Entry conditions:**

- Pair has old/new task fields or active visible state.
- Dispatcher asks for action classification.
- Visual emitters ask whether scan/laser/status is allowed.

**Ongoing conditions:**

- Exactly one action family is treated as visible owner: combat, repair, consecration, crafting, acquisition, or idle.
- Stale labels do not suppress the true active family.

**Exit conditions:**

- Current tick’s visible owner is classified.
- Wrong-family beams are suppressed or cleared.

**Failure exits:**

- Invalid pair returns invalid.
- Stale combat/consecration/acquisition claims fall back to idle or suppressed visuals, not destructive state mutation.

**Observability:**

- Action arbiter stats: suppressed scans/lasers, target mismatch, remote laser suppression.
- Future required field: `pair.visible_action_family` and `pair.visible_action_reason`.

---

## 3. Urgent and defensive branches

### BT-100 — Combat defense

**Purpose:** Defend station/priest/network assets when a hostile threat is real.

**Entry conditions:**

- Hostile entity inside station/network range.
- Combat target is valid and hostile.
- Combat repair may preempt ordinary combat if damaged walls/gates are under enemy pressure and covered.

**Ongoing conditions:**

- Target remains valid and hostile.
- Priest/station has weapon/ammo/proxy capability or combat doctrine can safely hold.

**Exit conditions:**

- Target dead/invalid/out of range.
- Combat state clears to prior work or idle.

**Failure exits:**

- Same-force/allied/neutral target rejected.
- Invalid target clears stale combat state.

**Observability:**

- `/tp-dispatcher-0510` family/action.
- Combat repair doctrine command/report if enabled.
- Future required field: combat target unit, target force, ammo state, and exit reason.

---

### BT-120 — Repair service

**Purpose:** Repair damaged friendly entities when repair material and pathing are available.

**Entry conditions:**

- Friendly repairable entity damaged within station/network authority.
- Repair work queue or legacy repair scanner submits repair intent.
- Repair pack or repair-production path exists.

**Ongoing conditions:**

- Target remains valid, damaged, friendly, and reachable.
- Repair supply remains available or requested.

**Exit conditions:**

- Entity fully repaired.
- Repair order completed.
- Priest returns to station or resumes previous higher-priority work.

**Failure exits:**

- Target invalid/fully repaired before arrival: clear repair task.
- No repair supply: route to emergency production or report missing repair pack.
- No path: report movement failure and release reservation.

**Observability:**

- Dispatcher action family `repair`.
- Repair executor phase.
- Runtime report event-fed repair counters.

---

### BT-140 — Stale supply satisfaction

**Purpose:** Clear old survival/supply writs when the station already has the requested critical item.

**Entry conditions:**

- Pair has active or stale supply request fields such as ammo/repair/oil/litany/appeasement.
- Station-owned inventory contains satisfying critical item.

**Ongoing conditions:**

- Critical item remains present long enough to clear state.

**Exit conditions:**

- Matching request fields cleared.
- Matching order queue entries completed or removed.
- Emergency blocker text cleared.
- Stale icon disappears.

**Failure exits:**

- Requested critical item not present: no mutation except missing counter.

**Observability:**

- `/tp-supply-satisfaction-0639` selected station ammo/repair counts.
- `satisfied-stale-supply-0639` recent events.

---

### BT-150 — Inventory safety and station-bound cleanup

**Purpose:** Keep priest cargo, station stock, stash stock, and generic deposits safe and understandable.

**Entry conditions:**

- Priest has accidental cargo.
- Direct acquisition or fallback production needs to deposit output.
- Station/stash storage exists.

**Ongoing conditions:**

- Generic deposits may insert only into Cogitator chest or container/logistic-container storage.
- Machine/furnace result/input/fuel inventories must not be generic arbitrary storage.

**Exit conditions:**

- Cargo unloaded or output deposited.
- Blocked deposit reports safe failure.

**Failure exits:**

- No safe container space: return blocked; do not insert into machine result/fuel/source/output.

**Observability:**

- `/tp-inventory-safety-0638`.
- `generic-deposit-blocked-0638` events.

---

## 4. Bootstrap and infrastructure branches

### BT-200 — Infrastructure-first gate

**Purpose:** Prevent high-tier station/cogitator dependency requests from leaking into primitive acquisition before local emergency fabrication exists.

**Entry conditions:**

- Pair lacks local emergency fabrication spine or minimum plates.
- High-tier pressure exists, such as `servitor-parts`, `offworld-cogitator-components`, advanced circuits, processing units, higher Cogitator stations, ritual appeasement, or similar.
- Pair is idle/loitering/logistics/scavenging/assignment while local spine is missing.

**Ongoing conditions:**

- Needed local step remains missing.
- Gate remains enabled.
- Audit mode, if enabled, records but does not mutate.

**Exit conditions:**

- Local fabrication spine exists and local plate threshold is satisfied.
- High-tier request is deferred until local infrastructure is ready.

**Failure exits:**

- Invalid pair: return invalid.
- Active non-gate work continues if not idle/scavenging/logistics/assignment and no high-tier pressure is active.
- Missing local item prototype returns invalid-local-step.

**Canonical local step order:**

1. Emergency smelter.
2. Minimum iron plates if iron ore or miner exists.
3. Emergency miner.
4. Emergency assembler.
5. Minimum copper plates if copper ore exists.

**Observability:**

- `/tp-infra-first-0640` selected station status.
- `needed`, `why`, `high`, `source`, known roles, ore/plate counts.
- `infrastructure-gate-assigned-0640` and audit events.

---

### BT-220 — Emergency facility construction doctrine

**Purpose:** Ensure a Cogitator cell has primitive local machines before it expects advanced logistics.

**Entry conditions:**

- Station lacks one or more required emergency facility items/entities.
- Emergency facility doctrine is enabled.
- Construction planner can place items already available in station-bound inventory, or production/acquisition can produce the missing item.

**Ongoing conditions:**

- Facilities inside station radius are tagged to the owning station.
- Missing facilities are requested one at a time.
- Construction planner handles physical placement.

**Exit conditions:**

- Required core facility list is present and tagged.
- Facility doctrine shifts from build-request to use-owned-facilities.

**Failure exits:**

- Required item missing: produce/acquire item; do not pretend facility exists.
- Construction planner cannot place: report no build site/no build stock.
- Facility invalid/destroyed: forget and request replacement.

**Current required core:**

- Emergency miner.
- Emergency smelter.
- Atmospheric water condenser.
- Emergency boiler.
- Emergency steam engine.
- Emergency power grid.
- Emergency assembler.

**Observability:**

- `/tp-emergency-facilities-0357` selected station status.
- Facility counts, roles, requested-build count, tagged count, used count.

---

### BT-230 — Emergency facility operation doctrine

**Purpose:** Use owned emergency machines to turn local resources into local products.

**Entry conditions:**

- Owned emergency facility exists and is tagged.
- A request item maps to a miner, smelter, assembler, condenser, boiler, or power role.

**Ongoing conditions:**

- Facility remains valid and owned by station.
- Recipe can be set or is already selected.
- Inputs/fuel are fed from station-owned inventory where relevant.
- Facility output is collected by emergency production / station cleanup.

**Exit conditions:**

- Facility has correct recipe and is fed.
- Output is available for collection.
- Emergency production completes request or continues waiting on facility.

**Failure exits:**

- Recipe missing: return no action; production falls back only if materials ready.
- Facility invalid: forget and return to construction request.
- Input missing: route to acquisition or infrastructure-first local step.

**Special 0.1.641 rule:**

- Emergency miner no longer requires fuel. It costs very slow recipe time instead of early fuel logistics.

**Observability:**

- Facility doctrine draw/status lines.
- Emergency production `feed-machine`, `need-machine`, `wait-machine`, `collect-output`, or `facility-output-complete` phases.

---

### BT-240 — Emergency production / station fallback crafting

**Purpose:** Turn an active item-production task into a completed station item through facilities first, then timed station fallback only when safe.

**Entry conditions:**

- `pair.emergency_craft`, `pair.station_crafting_task_0337`, `pair.active_craft_0479`, or a craft order proxy exists.
- Dispatcher classifies family as station-craft.

**Ongoing conditions:**

- If task has a direct acquisition current target, production waits for acquisition.
- If item already supplied, task completes.
- Facility output is collected when present.
- Emergency facilities are preferred before timed fallback.
- Timed fallback requires priest at station.

**Exit conditions:**

- Item inserted into station inventory.
- Matching order queue entry completed.
- Craft task cleared.
- Dispatcher phase becomes complete.

**Failure exits:**

- No production task: phase none.
- Invalid item: phase need-item / invalid-item.
- Direct current active: phase await-direct-acquisition.
- Materials not ready: phase check-scavenge and yields to acquisition.
- Return movement failed: movement-request-failed.
- Output deposit blocked: deposit-output / deposit-blocked and retry later.

**Observability:**

- `pair.dispatcher_emergency_production_0514.phase`.
- `/tp-dispatcher-0510` action/family/result.
- Emergency production recent events.

---

## 5. Acquisition and construction branches

### BT-260 — Direct acquisition

**Purpose:** Physically acquire a simple local resource or object by moving to a valid target, working, depositing output, and returning.

**Entry conditions:**

- Current direct acquisition task exists in `pair.emergency_craft`, `pair.direct_acquisition_task_0336`, or `pair.active_acquisition_0333`.
- Current kind is one of direct mine/direct dirt/dirt/direct mine 0336.
- Target entity or target position exists.

**Ongoing conditions:**

- Target remains valid or position remains known.
- Target stays within movement bounds.
- Priest progresses toward target or repaths after stall.
- Work only begins when physically close.
- Output item resolves to valid item.

**Exit conditions:**

- Required units gathered and deposited.
- If recipe-backed task: mark station craft pending and return to station for production.
- If pure acquisition: clear acquisition fields and return to station.

**Failure exits:**

- No task: phase none.
- Target invalid: clear current and replan.
- No target position: clear current and request new target.
- Target out of bounds: clear current and report rejected.
- Movement request failed: report movement failure.
- Deposit blocked: report blocked and do not advance gathered count.
- Return movement failed: report return failure.

**Observability:**

- `pair.dispatcher_direct_0513.phase`: none, need-target, target-invalid, target-rejected, walk-to-target, work-target, deposit-blocked, return-for-craft, complete.
- Direct acquisition recent events and overhead status.

---

### BT-280 — Construction placement

**Purpose:** Place station-owned buildable items and planner ghosts without using the priest inventory as hidden stock.

**Entry conditions:**

- Station-bound inventory contains placeable item.
- Emergency facility doctrine requests missing facility placement.
- Arterial planner or construction planner emits build/ghost need.

**Ongoing conditions:**

- Item still exists in station/stash inventory.
- Site is valid, reachable, unblocked, inside authority.
- Construction task reserves item/site.

**Exit conditions:**

- Entity placed and tagged/claimed where applicable.
- Inventory decremented.
- Construction task cleared.

**Failure exits:**

- No build site: report deferred.
- No build stock: yield to production/acquisition.
- No path: release reservation and report movement failure.
- Entity already present: claim/tag and clear build request.

**Observability:**

- Construction planner command/report.
- Emergency facility doctrine `requested-build` and `tagged` counters.
- Future required field: `pair.construction_phase` standardized.

---

### BT-300 — Machine logistics

**Purpose:** Service nearby machines with station-owned materials through machine-specific logistics, not generic storage insertion.

**Entry conditions:**

- A nearby machine/furnace/assembler/boiler needs fuel, input, output collection, or recipe support.
- Station has or can obtain required material.

**Ongoing conditions:**

- Machine remains valid and claimed/reserved where necessary.
- Input/fuel/output inventories are touched only by machine-specific service code.
- Generic deposit safety remains separate and chest/container-only.

**Exit conditions:**

- Machine input/fuel supplied.
- Output collected into safe storage.
- Machine logistics phase complete.

**Failure exits:**

- Machine invalid: clear claim.
- Missing material: issue supply/acquisition/production request.
- Output full: report output blocked.
- Recipe mismatch: claim recipe before mutation or yield.

**Observability:**

- Machine logistics command/report.
- Action arbiter treats active machine logistics as acquisition until complete.
- Future required field: `pair.machine_logistics_0528.phase` normalized in behavior audit.

---

## 6. Service and background branches

### BT-320 — Consecration service

**Purpose:** Apply sanctification, oil/litany/appeasement, incense, and related machine-spirit service when supported and supplied.

**Entry conditions:**

- Machine sanctity below threshold, player request, or consecration order.
- Required consecration item exists or can be produced.

**Ongoing conditions:**

- Target remains valid and supported.
- Consecration item remains available.
- Action arbiter allows consecration visuals only when this branch owns visible action.

**Exit conditions:**

- Consecration applied or rejected as unsupported.
- Target/order cleared.

**Failure exits:**

- No item: report need-item and route to production.
- Target invalid: clear target.
- Unsupported target: reject cleanly.

**Observability:**

- `pair.consecration_0515.phase`.
- `/tp-dispatcher-0510` family/result when dispatcher owns consecration.
- Action arbiter status.

---

### BT-340 — Catalog, planning, and network background

**Purpose:** Maintain station-local knowledge and high-level planning without interrupting active work.

**Entry conditions:**

- Radar/catalog cadence due.
- Dirty region/event update.
- Superior station, player GUI, or planning queue emits a request.

**Ongoing conditions:**

- Catalog removes stale claims.
- Planner creates one bounded build/logistic intent at a time.
- Background scans never mask a blocked active task.

**Exit conditions:**

- Catalog refreshed or dirty region marked clean.
- Planning request becomes concrete work or remains deferred.

**Failure exits:**

- Unsupported plan: defer, do not produce wandering acquisition.
- Stale entity: remove catalog record.

**Observability:**

- `/tp-runtime-report` catalog/cache efficiency lines.
- Station catalog command/report.
- Planning queue command/report.

---

### BT-900 — Chatter and idle

**Purpose:** Provide flavor only when no higher-priority behavior owns the pair.

**Entry conditions:**

- No valid active task, no repair/combat/construction/acquisition/craft/consecration, and no blocking recovery.
- Player directly interacts with priest or chatter cadence fires.

**Ongoing conditions:**

- Must yield immediately to any real behavior claim.
- Must not set movement, target, acquisition, production, repair, or construction state.

**Exit conditions:**

- Chatter bubble shown or idle wait at station.

**Failure exits:**

- Higher-priority work appears: stop chatter/idle and do not mask blocker.

**Observability:**

- Chatter stats.
- Action arbiter `conversation` or `idle` family.

---

## 7. Station placement to behavior flow

```text
Cogitator Station placed / discovered
  -> BT-000 pair identity created or repaired
  -> BT-010 runtime service spine pulses due services
  -> BT-020 pair validation gate
  -> BT-030 action arbitration / dispatcher classification
  -> urgent branches first
      -> BT-100 combat defense / combat repair
      -> BT-120 repair service
      -> BT-140 stale supply satisfaction
      -> BT-150 inventory cleanup / safe deposit
  -> bootstrap branches
      -> BT-200 infrastructure-first gate
      -> BT-220 emergency facility construction
      -> BT-230 emergency facility operation
      -> BT-240 emergency production / timed station fallback
  -> work branches
      -> BT-260 direct acquisition
      -> BT-280 construction placement
      -> BT-300 machine logistics
      -> BT-320 consecration service
  -> background branches
      -> BT-340 catalog/planning/network refresh
      -> BT-900 chatter/idle
```

---

## 8. Required behavior-state record

The next implementation pass should give every pair a common behavior audit record. Suggested shape:

```lua
pair.behavior_tree_0642 = {
  tick = game.tick,
  node = "BT-260",
  phase = "walk-to-target",
  owner = "direct_acquisition_executor_0513",
  entry_reason = "direct task current target",
  ongoing = "dist=12.4 target=iron-ore#123",
  exit_reason = nil,
  blocked_reason = nil,
  previous_node = "BT-200",
  started_tick = 123456,
  last_progress_tick = 123500,
  target = "iron-ore#123",
  item = "iron-ore"
}
```

Rules:

- `node` must be one of the documented BT IDs.
- `phase` must be a bounded vocabulary owned by that node.
- `started_tick` changes only when node changes.
- `last_progress_tick` changes when distance decreases, inventory count changes, target changes validly, item count changes, facility role appears, or order completes.
- `blocked_reason` must be explicit and finite.
- A node that sets `blocked_reason` must also have either a retry cadence or an exit path.

---

## 9. Immediate audit checklist

The next behavior-debugging pass should audit code against this document in this order:

1. Pair validation and identity repair: confirm no leaf service can mutate invalid pairs.
2. Dispatcher/action arbiter: confirm exactly one visible action family is selected per pair per tick.
3. Infrastructure-first gate: confirm high-tier items cannot re-enter direct acquisition before local spine readiness.
4. Emergency production: confirm `materials-not-ready` has a single legal successor, not random acquisition.
5. Direct acquisition: confirm every phase has a replan, movement failure, deposit blocked, or complete exit.
6. Emergency facility doctrine: confirm requested core facility order matches the canonical bootstrap path and does not endlessly ask for missing build stock without a production/acquisition successor.
7. Construction placement: confirm facility build requests become either placed/tagged, waiting for item production, or cleanly blocked.
8. Machine logistics: confirm machine inventories are serviced only by machine-specific logic.
9. Idle/chatter: confirm idle never hides a blocked non-idle node.

---

## 10. Known likely dead-end risks to eliminate

- High-tier station recipe ingredients such as servitor-parts or offworld-cogitator-components becoming direct acquisition goals before local infrastructure exists.
- `materials-not-ready` returning false without a canonical successor.
- Facility doctrine asking construction planner to place a missing facility item when no module has a clear obligation to produce that item.
- Generic deposit paths treating machine/furnace inventories as arbitrary storage.
- Stale mode strings making the action arbiter show the wrong icon/beam while another task is active.
- Return-to-station failures leaving production/acquisition modes alive but unprogressing.
- Output deposit blocked loops with no visible storage remedy.
- Idle/chatter activating while a blocked higher-priority node still owns the pair.

---

## 11. Acceptance target

A selected station should eventually be able to answer all of these questions in one diagnostic command:

- What behavior node am I in?
- Why did I enter it?
- What phase am I in?
- What target/item/facility/order am I acting on?
- What changed most recently to prove progress?
- What condition will let me exit?
- If blocked, what exactly is blocking me?
- What node will run next after success or failure?

Until that exists, behavior debugging will continue to depend on scattered logs and mode strings. This document is the baseline for replacing that uncertainty with a visible state machine.
