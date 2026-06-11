# Stage 3 Behavior Authority Map — 0.1.628 Source Baseline

This document begins the Stage 3 behavior authority audit from the corrected 0.1.628 source baseline.

This is documentation-only. No runtime behavior has been changed by this note.

## Plain-English purpose

Stage 3 answers the question:

> When a Tech-Priest decides what to do, who owns that decision, who owns the claim, who owns the order, who owns movement, and who actually performs the work?

This matters because the codebase is a layered compatibility stack. Legacy fragments remain active, newer authorities wrap or gate parts of them, and multiple modules can describe themselves as schedulers, queues, arbiters, executors, or governors.

## Current high-level behavior chain

The current behavior chain is best described as:

```text
World events / scans / legacy state
  -> Work Queue records shared world work
    -> Reservations claim targets
      -> Order Queue stabilizes per-pair writs
        -> Single Dispatcher selects routed behavior family
          -> Executors perform physical actions
            -> Movement Controller owns ground movement commands
              -> Legacy fragments remain as helpers/fallbacks unless gated
```

## Core authority layers

### `work_queue_authority.lua`

Classification: shared world-work discovery/backlog authority.

Purpose:

- Records shared work candidates by surface, force, and category.
- Folds duplicate submissions into existing backlog entries.
- Maintains spatial indexing for faster claim lookup.
- Exposes claim/find/report/cleanup behavior for shared jobs.
- Does not execute priest work.
- Does not assign final per-pair behavior by itself.

Categories currently listed:

```text
repair, sanctify, resource, construction, pickup, emergency, combat
```

Important behavior:

- `M.submit(category, target, opts)` records work.
- `M.claim_nearest(pair, category, opts)` finds and claims nearby work.
- Duplicate submissions refresh priority/expiry instead of creating duplicate work orders.
- Cleanup rotates by category.

Disposition: behavior-discovery/backlog authority, not executor.

Stage 3/5 concern:

`work_queue_authority` includes `emergency`, while `work_reservations` omits `emergency` from its category list. The reservation functions can still dynamically create arbitrary categories, but cleanup/reporting rotates through the declared category list. If `emergency` work is claimable through reservations, its reservation cleanup/reporting may be incomplete.

### `work_reservations.lua`

Classification: short-lived shared target-claim authority.

Purpose:

- Prevents many priests from claiming or pathing toward the same target simultaneously.
- Owns target keys and pair IDs for shared reservation categories.
- Cleans expired reservations through broker service when installed.
- Does not select behavior.
- Does not execute work.

Categories currently listed:

```text
repair, sanctify, resource, construction, pickup, combat
```

Important behavior:

- `M.claim(category, target, pair_or_id, ttl, meta)` creates/renews a reservation.
- `M.is_claimed(category, target, pair_or_id)` blocks other pairs but allows the owner to continue.
- `M.release(category, target, pair_or_id)` releases a claim.
- `M.cleanup_expired(...)` rotates cleanup by configured categories.

Disposition: target-claim authority, not behavior owner.

Stage 3/5 concern:

Category mismatch with work queue: `emergency` exists in work queue categories but not reservation categories. Confirm whether any path claims `emergency` via `work_reservations`; if yes, align category sets or add explicit cleanup/report support.

### `order_queue_0469.lua`

Classification: per-pair order/writ stack authority.

Purpose:

- Converts repeated resource, recipe, logistics, scavenge, assignment, repair, consecration, and combat claims into stable per-priest orders.
- Prevents duplicate active/pending orders for the same key.
- Allows higher-priority work to preempt lower-priority work.
- Pauses and resumes lower-priority work rather than destroying it.
- Adopts existing legacy task surfaces into a normalized order where possible.

Important behavior:

- `M.submit(pair, order, opts)` creates active/pending order state.
- Current order lives in `pair.order_queue_0469.current` and `pair.active_order_0469`.
- Pending orders live in `pair.order_queue_0469.pending` with `pending_keys` duplicate protection.
- Order completion/expiry/preemption interacts with lower legacy state surfaces.

Disposition: per-pair order stability authority.

Stage 5 concern:

Paused/current orders can outlive or mismatch older state surfaces. Dead-end audit must check:

- expired order but legacy task still active,
- legacy state cleared but paused order still waiting,
- active order complete but `pair.active_order_0469` still set,
- current order target invalid but executor keeps waiting.

### `single_dispatcher_0510.lua`

Classification: migrated behavior-family dispatcher.

Purpose:

- First authoritative dispatcher pass.
- Changes legacy fragments from direct owners into helpers/gated fallback for migrated families.
- Calls order queue first.
- Chooses a visible/action family using combat repair doctrine, action-state arbiter, and legacy task surfaces.
- Routes migrated behavior families to explicit executors.
- Gates legacy `tick_pair` for recently dispatcher-owned families.
- Suppresses independent direct/craft executor pulses outside dispatcher context.

Dispatcher-owned migrated families:

```text
direct acquisition
station craft / emergency production
consecration
repair
combat repair
```

Explicitly not fully migrated according to dispatcher comments:

```text
ordinary combat
construction
```

Important behavior:

- `M.service_pair(pair, reason)` repairs identity, ticks order queue, selects action, routes to executor, and records dispatcher state.
- `M.should_gate_legacy(pair)` gates legacy only inside a small recent window and only for dispatcher-owned action families.
- `wrap_legacy_tick_pair()` gates old `tick_pair` when dispatcher recently owned the active family.
- `wrap_executor_pulses()` suppresses independent direct/craft pulses unless manually kicked or dispatcher-owned.
- Install path is healthy by current Stage 2 standard: global registry -> require registry -> direct fallback.

Disposition: main migrated behavior-control seam. Protect from duplicate owners.

Stage 3/5 concern:

Legacy gating is windowed. If dispatcher state expires but legacy state is still dirty, older behavior can reassert. This may be correct compatibility behavior, but dead-end audit must check stale legacy surfaces.

### `action_state_arbiter_0488.lua`

Classification: single-visible-action arbiter / presentation gate / movement nudge source.

Purpose:

- A priest may have old bookkeeping tables for craft, acquisition, combat, scan, and return simultaneously, but only one visible action should own beams and overhead state on a given tick.
- Suppresses wrong visuals/actions rather than deleting queued work.
- Determines action kind from current order, pair mode, direct acquisition state, crafting state, logistics state, consecration state, and combat target.

Important behavior:

- `M.action(pair)` returns current visible/allowed action kind.
- `M.allow_scan(...)` suppresses scan/mining visuals when current action is not acquisition.
- `M.allow_laser(...)` suppresses wrong laser use and hostile/non-hostile mismatches.
- Can request movement through `tech_priests_request_movement_0418` before scan/laser when target is too far.

Disposition: not the queue owner, not the dispatcher, not the executor. It is a visible-action arbiter and safety gate.

Stage 3/5 concern:

Because it can request movement and suppress visuals based on mixed legacy/current state, stale order or mode fields can produce misleading suppression. Include in dead-end audit as a state interpreter.

### `movement_controller.lua`

Classification: canonical ground movement command authority.

Purpose:

- One module owns ground-priest `go_to_location` commands.
- Other systems submit movement intent; they do not command the entity directly.
- Conversations, mining/work, crafting, and post-snap stabilization are clamp bands.
- Space-platform hover/pathing is outside this controller.

Important behavior:

- Maintains movement requests in `storage.tech_priests.movement_controller_0419`.
- Exposes movement request hooks through globals used by other systems.
- Has direct stop/go-to helpers using `set_command`/`commandable.set_command` internally.
- Integrates with pair buckets and movement lease/update timing.

Disposition: movement command authority.

Stage 4/5 concern:

Movement stale request/lease fields must be checked later. Movement command ownership should not be casually migrated during event/timing cleanup.

## Executor family map

### Direct acquisition — `direct_acquisition_executor_0513.lua`

Classification: dispatcher-owned executor.

Purpose:

- Turns direct acquisition into explicit phases:
  - choose/adopt target,
  - walk to target,
  - work over time,
  - deposit,
  - return or yield to station craft.
- Legacy direct-mining bodies may remain installed as helpers/compatibility shims, but not independent controllers when enabled.

Important storage/state fields:

- `pair.dispatcher_direct_0513`
- `pair.dispatcher_action = "direct-acquisition"`
- `pair.dispatcher_phase`
- legacy task fields such as `pair.emergency_craft`, `pair.direct_acquisition_task_0336`, `pair.active_acquisition_0333`

Disposition: dispatcher-owned migrated executor.

Stage 5 concern: inspect direct acquisition phases for target invalidation, deposit blocked, return/yield loops, and legacy task cleanup.

### Emergency production / station craft — `emergency_production_executor_0514.lua`

Classification: dispatcher-owned executor.

Purpose:

- Cleans up the “I need an item” production chain after direct acquisition migration.
- Keeps Martian emergency facility doctrine as a leaf helper.
- Prevents old desperation craft paths from acting as independent controllers while dispatcher owns production.
- Supports emergency facility preference and timed station fallback.

Important storage/state fields:

- `pair.dispatcher_emergency_production_0514`
- `pair.dispatcher_action = "emergency-production"`
- `pair.dispatcher_phase`
- `pair.emergency_craft`, `pair.station_crafting_task_0337`, `pair.active_craft_0479`

Disposition: dispatcher-owned migrated executor.

Stage 5 concern: inspect facility wait, timed station fallback, impossible ingredient, and order completion cleanup.

### Consecration — `consecration_executor_0515.lua`

Classification: dispatcher-owned executor with local target claims.

Purpose:

- Converts old station rite into visible phased priest action.
- Chooses eligible machine, walks within range, spends ritual time, consumes consecration item, applies sanctity with explicit priest/station source context.
- Old station-rite function may remain as helper but may no longer directly apply sanctity once installed.

Important storage/state fields:

- `pair.consecration_0515`
- `storage.tech_priests.consecration_executor_0515.target_claims`
- `pair.dispatcher_0510.family = "consecration"`

Disposition: dispatcher-owned migrated executor.

Stage 3/5 concern:

Consecration has local target-claim logic rather than obviously using shared `work_reservations`. This may be intentional due to consecration-specific item/range/cooldown rules, but the audit must confirm all claim release/timeout paths.

### Repair — `repair_executor_0516.lua`

Classification: dispatcher-owned executor using shared reservation authority where available.

Purpose:

- Turns repair into visible phased action:
  - select damaged target by urgency,
  - reserve it,
  - walk to repair range,
  - spend timed repair ticks,
  - consume repair packs,
  - keep repairing until full repair or supplies fail.
- Prevents multiple priests from piling onto one wall section.

Important behavior:

- Uses `work_reservations` when available for shared repair target spreading.
- Falls back to local reservations only if shared reservation authority is missing.
- Uses `work_queue_authority` when available.

Disposition: dispatcher-owned migrated executor and currently good shared-reservation model.

Stage 5 concern: inspect reservation release when repair target becomes invalid, fully repaired, no packs, or force/surface mismatch.

### Combat repair — `combat_repair_doctrine_0517.lua`

Classification: dispatcher-owned doctrine/selector plus executor.

Purpose:

- Decides whether a damaged wall/gate under enemy pressure should be repaired under fire.
- Requires cover from loaded/active turrets or other priests unless configured otherwise.
- If uncovered and alone, ordinary combat remains the correct answer.

Important storage/state fields:

- `storage.tech_priests.combat_repair_doctrine_0517.cluster_reservations`
- `target_cooldowns`

Disposition: dispatcher-owned migrated combat-repair family.

Stage 5 concern: local cluster reservations need timeout/release review.

### Ordinary combat

Classification: legacy leaf-controlled / mixed.

Current evidence:

`single_dispatcher_0510.lua` explicitly says combat is not fully migrated and remains legacy leaf-controlled until a later pass moves it behind the dispatcher.

Disposition: do not migrate casually. Needs separate combat authority audit.

### Construction placement

Classification: legacy leaf-controlled / mixed.

Current evidence:

`single_dispatcher_0510.lua` explicitly says construction is not fully migrated and remains legacy leaf-controlled until a later pass moves it behind the dispatcher.

Disposition: do not migrate casually. Needs separate construction authority audit.

## Event feeder / discovery boundary

### `event_driven_work_feeder_0608.lua`

Classification: event-to-work-queue feeder.

Purpose:

- Converts high-signal world events into work queue submissions and telemetry counters.
- Feeds existing authorities.
- Does not execute priest work.

Explicit boundary from file comments:

```text
Work Queue finds/records jobs.
Reservation claims jobs.
Order Queue executes jobs.
```

Updated Stage 3 interpretation:

The comment is close but too compressed for the current architecture. More precise wording is:

```text
Work Queue finds/records jobs.
Reservation claims targets.
Order Queue stabilizes per-pair orders.
Single Dispatcher routes migrated behavior families.
Executors perform physical work.
```

Disposition: work discovery/event feeder only.

## Current behavior ownership matrix

| Behavior family | Current owner classification | Primary owner / path | Notes |
|---|---|---|---|
| Shared repair/sanctify/construction/pickup/combat/resource backlog | Work discovery/backlog | `work_queue_authority.lua` | Records/folds shared jobs; does not execute. |
| Target claims | Shared claim authority | `work_reservations.lua` | Category mismatch with work queue: `emergency` missing. |
| Per-pair orders | Per-pair order authority | `order_queue_0469.lua` | Stabilizes current/pending orders; prevents duplicates/preemption loss. |
| Action family selection | Dispatcher-owned for migrated families | `single_dispatcher_0510.lua` | Calls order queue, arbiter/doctrines, then executors. |
| Visible action/beam/status arbitration | Action arbiter | `action_state_arbiter_0488.lua` | Suppresses wrong visuals/actions; can request movement nudges. |
| Ground movement commands | Movement authority | `movement_controller.lua` | Other systems should submit movement intent rather than command directly. |
| Direct acquisition/mining | Dispatcher-owned migrated executor | `direct_acquisition_executor_0513.lua` | Legacy direct-mining becomes helper/shim. |
| Emergency production/station craft | Dispatcher-owned migrated executor | `emergency_production_executor_0514.lua` | Old desperation craft/facility paths become helpers. |
| Consecration/sanctification | Dispatcher-owned migrated executor | `consecration_executor_0515.lua` | Uses local target claims; release paths need audit. |
| Repair | Dispatcher-owned migrated executor | `repair_executor_0516.lua` | Uses shared reservations when available. |
| Combat repair | Dispatcher-owned doctrine/executor | `combat_repair_doctrine_0517.lua` | Uses local cluster reservations. |
| Ordinary combat | Legacy leaf-controlled / mixed | Legacy fragments and combat modules | Dispatcher explicitly says not fully migrated. |
| Construction placement | Legacy leaf-controlled / mixed | Legacy fragments and construction modules | Dispatcher explicitly says not fully migrated. |
| GUI display/update | GUI ownership, not behavior execution | `gui_router`, GUI modules | Stage 6 handles routing/containment. |
| Machine-spirit ledger/state updates | Consecration/history subsystem | `consecration/history_gui.lua` and related record functions | UI/state display; not task execution. |
| Sound/reporting/visual overlays | Presentation/telemetry | Chatter, sound, visual modules, arbiter status | Not behavior owners unless they issue movement/action calls. |

## Current overlap/conflict list

1. **Work queue / reservation category mismatch**
   - `work_queue_authority` categories include `emergency`.
   - `work_reservations` categories omit `emergency`.
   - Dynamic buckets may still allow `emergency`, but cleanup/reporting rotates only through configured categories.
   - Disposition: probable small repair candidate if reachable.

2. **Consecration local claims vs shared reservations**
   - Consecration uses local `target_claims` rather than obviously using `work_reservations`.
   - May be intentional due to consecration-specific rules.
   - Disposition: fragile but likely working; Stage 5 must verify release/expiry paths.

3. **Combat repair local cluster reservations**
   - Combat repair has local `cluster_reservations` and cooldowns.
   - May be appropriate because it works by wall/gate clusters under fire rather than single target jobs.
   - Disposition: intentional-looking; Stage 5 must verify timeout/release paths.

4. **Legacy leaf families remain active**
   - Ordinary combat and construction are explicitly not fully migrated.
   - Dispatcher gating should not be broadened until those families are mapped.
   - Disposition: intentional legacy fallback, not bug by itself.

5. **Action arbiter interprets mixed state**
   - Arbiter can suppress visuals/actions based on current order, mode, and many legacy fields.
   - Stale mode/order fields may suppress correct visuals.
   - Disposition: Stage 5 dead-end/state audit input.

6. **Movement intent vs direct movement command**
   - Movement controller is intended sole owner of ground movement commands.
   - Some older/fallback systems may still call `set_command` directly.
   - Disposition: Stage 4/5 movement-command inventory required.

## Immediate next Stage 3 tasks

1. Inspect logistics and machine-logistics authority modules.
2. Inspect construction authority/contracts because construction is not dispatcher-migrated yet.
3. Inspect ordinary combat authority because combat is not dispatcher-migrated yet.
4. Search for direct `set_command` calls outside `movement_controller.lua` and classify them.
5. Decide whether the `emergency` reservation category mismatch is safe to repair before Stage 4, or should wait until dead-end audit confirms reachability.

## Current Stage 3 conclusion

The active behavior stack is increasingly coherent for migrated families. The dispatcher owns direct acquisition, station craft/emergency production, consecration, repair, and combat repair. Work queue/reservation/order queue are not executors; they provide backlog, claims, and stable writs. Movement controller owns ground movement. Ordinary combat and construction remain legacy/mixed and should not be migrated or timing-edited until they receive their own ownership pass.
