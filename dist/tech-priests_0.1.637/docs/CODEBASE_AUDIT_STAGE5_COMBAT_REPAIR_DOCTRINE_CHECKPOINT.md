# Stage 5 Checkpoint — Combat Repair Doctrine 0517

This checkpoint records the Stage 5 dead-end/state review of:

```text
scripts/core/combat_repair_doctrine_0517.lua
```

This is documentation-only. No runtime behavior has been changed by this note.

## Plain-English result

`combat_repair_doctrine_0517.lua` is not ordinary repair. It is a combat/repair arbitration layer.

Its doctrine is:

```text
If a damaged wall or gate is part of a defended line,
and enemies are nearby,
and allied turrets or other combat-active priests are covering the line,
then a priest may temporarily repair under fire.
Otherwise ordinary combat remains the correct behavior.
```

The module does not perform the actual repair work itself. It finds an eligible defended wall/gate, reserves the cluster, records combat-repair state, and delegates execution to `repair_executor_0516.lua`.

No immediate code repair is recommended from this pass.

## Confirmed healthy structures

### Clear doctrine separation

The header states that this is not ordinary repair. It only permits combat repair if the damaged wall/gate segment is part of a currently defended line. If the priest is alone and uncovered, combat remains correct.

Disposition: healthy combat/repair boundary.

### Cover and danger checks exist

Eligibility requires:

- wall/gate-like target;
- same force;
- damaged above minimum ratio;
- repair packs available;
- inside station radius;
- not on target cooldown;
- not cluster-reserved by another station;
- enemy pressure near the wall;
- turret or other-priest cover if `require_cover` is enabled;
- personal danger guard if the priest is alone and wall damage is not critical.

Disposition: strong safety doctrine.

### Target scoring is combat-aware

`score_wall(...)` heavily weights:

- damage ratio;
- missing health;
- number of nearby enemies;
- active turret cover;
- active priest cover;
- proximity to enemy pressure;
- priest/station distance.

Disposition: healthy target priority.

### Cluster reservation exists

The module reserves wall clusters rather than single wall pieces:

```text
cluster_reservations[key] = {
  station = ...,
  priest = ...,
  wall = ...,
  until_tick = now() + M.cluster_reservation_ttl
}
```

Disposition: good anti-pileup behavior around defensive lines.

### Cover-loss abort exists in recommendation path

`M.recommend_action(pair)` checks active combat repair state. If the active target is no longer eligible, it calls:

```text
M.abort_pair(pair, "cover-lost:" .. why)
```

This releases cluster reservation where possible, clears combat repair target fields, resets overlapping repair state, and marks the pair as combat-repair-aborted.

Disposition: healthy when the recommendation path is the active flow.

### Execution delegates to repair executor

`M.service_pair(...)` requires:

```text
scripts.core.repair_executor_0516
```

Then it calls:

```text
Repair.submit_or_assign_repair_task(...)
Repair.service_pair(...)
```

Disposition: good reuse of the dedicated repair executor. Movement/repair timing issues belong mostly to 0516 after 0517 selects the target.

### Diagnostics exist

The module installs:

```text
/tp-combat-repair-0517
```

and pair-dump lines with phase, target, missing health, ratio, enemies, turrets, priests, cover, and recent events.

Disposition: useful live diagnostics.

## Watch item 1 — no direct broker service registration is visible

`M.install()` installs the command, wraps pair dump, and exposes `_G.TechPriestsCombatRepairDoctrine0517`. It does not visibly register a broker service in this file.

Potential consequence:

```text
Combat repair likely depends on combat/dispatcher recommendation flow rather than an independent periodic service.
```

This may be intentional. Combat repair should probably be invoked by ordinary combat ownership rather than wake itself independently.

Current disposition:

```text
Flow ownership watch item, not a bug.
```

Recommended follow-up:

```text
Verify which module calls TechPriestsCombatRepairDoctrine0517.recommend_action or service_pair during ordinary combat dispatch.
```

## Watch item 2 — cluster release is strongest on abort/complete, weaker on failed delegation

Cluster release is explicit in:

- `M.abort_pair(...)` when the target is valid;
- `clear_if_complete(...)` when the target is valid and fully repaired.

But in `M.service_pair(...)`, if the repair executor is missing or throws an error after cluster reservation, the code sets phase `failed` and returns without an obvious immediate cluster release.

Potential consequence:

```text
A cluster can remain reserved until TTL after repair-executor-missing or repair-error.
```

This is bounded by `M.cluster_reservation_ttl = 150`, so it is not a permanent dead-end. But it can briefly suppress other priests from using that defensive-wall cluster.

Current disposition:

```text
Low/medium priority cleanup watch item.
```

Future repair shape:

```text
Release cluster on repair-executor-missing and repair-error when the reservation still belongs to this pair.
```

## Watch item 3 — invalid target cleanup relies partly on TTL

`clear_if_complete(pair, target)` treats invalid target as complete/cleared, but it can only release a cluster if the target is still valid because cluster key generation needs target surface/position. If the wall entity became invalid, the matching cluster reservation may remain until TTL.

Current disposition:

```text
TTL-bounded cleanup watch item.
```

Future repair shape:

```text
Store cluster key in pair.combat_repair_0517 when reserving, then release by stored key even if target entity becomes invalid.
```

This is not urgent because TTL is short.

## Watch item 4 — service_pair may find a new target instead of aborting old active state

`M.recommend_action(...)` has explicit cover-loss abort for active targets. `M.service_pair(...)` validates forced target or finds a target, then proceeds. If an old active combat repair state exists but service is called through a path that bypasses `recommend_action(...)`, the old target cleanup may depend on target replacement or TTL cleanup rather than the explicit cover-loss abort path.

Current disposition:

```text
Flow ownership watch item. Confirm actual caller path before patching.
```

## Watch item 5 — inherited movement-contract issue from 0516

0517 delegates actual work to `repair_executor_0516.lua`. Therefore, 0517 inherits the 0516 movement-contract weakness:

```text
repair walk-to-target can report moving even if movement request submission fails.
```

0517 itself is not the best place to fix that. The repair should remain in movement contract / repair executor layers.

## Relationship to ordinary combat ownership

This module appears to be intentionally conservative:

```text
under fire + defended line + cover = repair allowed
alone/uncovered/personal danger = combat remains correct
```

The audit did not find evidence that 0517 forcibly steals ordinary combat ownership. However, final confidence requires a caller audit:

```text
Who calls recommend_action?
Who chooses combat-repair over ordinary combat?
Does ordinary combat release/ignore combat repair when enemies become immediate personal threats?
```

## Current Stage 5 decision

No code repair from this pass.

Current priority ranking remains:

```text
1. 0527/0528 machine logistics / known-source fetch stale-state cleanup.
2. 0513 direct acquisition deposit/gathered_units correctness.
3. Movement completion/status contract across movement-dependent executors.
4. 0514 emergency production returning/deposit-block diagnostics.
5. 0516 repair movement failure/reservation release refinement.
6. 0515 consecration movement failure/cooldown-claim refinement.
7. 0517 combat repair cluster-release and caller-flow verification.
```

## Recommended live diagnostics after packaging

Use:

```text
/tp-combat-repair-0517
/tp-repair-executor-0516
/tp-runtime-report
/tp-task-auspex
```

Watch for:

- `phase=repair-via-0516` while repair executor reports no matching target;
- `phase=failed` after repair-error while cluster reservations remain elevated;
- cluster reservation counts that do not decay within TTL;
- combat repair continuing after cover disappears;
- combat repair being chosen while the priest has immediate personal enemy danger.

## Recommended next manual target

Continue Stage 5 caller-flow audit around ordinary combat ownership:

```text
Search for calls to:
  TechPriestsCombatRepairDoctrine0517
  combat_repair_0517
  recommend_action
  combat-repair
```

Then identify which module chooses between ordinary combat, combat repair, and repair executor ownership.
