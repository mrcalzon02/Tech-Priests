# Stage 5 Checkpoint — Combat Repair Caller Flow

This checkpoint records the Stage 5 caller-flow audit for combat repair ownership.

This is documentation-only. No runtime behavior has been changed by this note.

## Files reviewed

```text
scripts/core/single_dispatcher_0510.lua
scripts/core/action_state_arbiter_0488.lua
scripts/core/combat_repair_doctrine_0517.lua
```

## Plain-English result

The combat repair caller flow is now clear:

```text
single_dispatcher_0510 chooses combat repair before ordinary combat.
combat_repair_doctrine_0517 does not independently wake itself.
0517 is a dispatcher-selected tactical override.
If 0517 returns no action, ordinary action arbitration continues and hostile targets become ordinary combat.
```

This resolves the previous uncertainty about why `combat_repair_doctrine_0517.lua` has no visible broker service registration. It does not need its own periodic service as long as the single dispatcher is active, because the dispatcher invokes its recommendation path each dispatcher pulse.

## Dispatcher caller flow

In `single_dispatcher_0510.lua`, `choose_action(pair)` does this first:

```text
pcall(require, "scripts.core.combat_repair_doctrine_0517")
CombatRepair0517.recommend_action(pair)
if action then return action end
```

Only after that does it call:

```text
action_state_arbiter_0488.action(pair)
```

Then fallback direct/craft/combat/idle checks happen.

Interpretation:

```text
Combat repair is intentionally checked before ordinary combat classification.
```

This matches the comment in dispatcher source:

```text
0.1.517: tactical combat repair is checked before ordinary combat classification.
It only returns an action when a damaged wall/gate is under enemy pressure and has active/loaded turret or priest cover.
```

## Execution flow

`single_dispatcher_0510.action_family(...)` maps `combat-repair` to the `combat-repair` family.

Then `service_pair(...)` runs:

```text
if family == "combat-repair" and dispatcher_owns_combat_repair ~= false then
  execute_combat_repair(pair)
end
```

`execute_combat_repair(pair)` then requires 0517 and calls:

```text
CombatRepair0517.service_pair(pair, "dispatcher-0510")
```

Interpretation:

```text
0517 owns tactical decision/target choice.
0516 owns actual repair execution.
0510 owns dispatcher invocation.
```

## Ordinary combat fallback

If 0517 returns no combat-repair action, dispatcher falls through to `action_state_arbiter_0488.action(pair)`.

In `action_state_arbiter_0488.lua`, hostile targets or combat mode produce ordinary combat:

```text
if hostile target or modekind == "combat" then
  return { kind="combat", target=target, item="combat" }
end
```

Interpretation:

```text
ordinary combat remains the fallback when combat repair is not safe or not applicable.
```

## Cover-loss abort reachability

`combat_repair_doctrine_0517.recommend_action(pair)` contains the cover-loss abort check for active combat repair:

```text
if M.active(pair) then
  if active target is no longer eligible then
    M.abort_pair(pair, "cover-lost:" .. why)
    return nil
  end
end
```

Because dispatcher calls `recommend_action(pair)` before ordinary action arbitration, this cover-loss abort is normally reachable on every dispatcher pulse while dispatcher is active.

This reduces the earlier concern that 0517 might keep repairing after cover disappears.

Current interpretation:

```text
Cover-loss abort is probably healthy in normal dispatcher flow.
```

Remaining caveat:

```text
If some manual/legacy path calls CombatRepair0517.service_pair directly without passing through recommend_action first, cover-loss abort can be bypassed for that call.
```

That caveat is lower priority because normal dispatcher flow is the primary path.

## Broker/service registration finding

`combat_repair_doctrine_0517.lua` does not visibly register its own service. This is probably intentional.

`single_dispatcher_0510.lua` registers dispatcher service through the runtime event registry:

```text
registry.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick-0510") end, ...)
```

Therefore:

```text
0517 is serviced through the dispatcher.
0517 should not need its own independent broker tick.
```

This resolves the prior watch item:

```text
No visible 0517 broker registration is not a bug by itself.
```

## Remaining watch items after caller-flow audit

### 1. Service direct-call bypass

`CombatRepair0517.service_pair(...)` itself does not perform the cover-loss abort precheck. It validates the selected/forced target through `eligible_wall(...)`, but old active-state cleanup is strongest in `recommend_action(...)`.

Risk is low under dispatcher flow, but direct manual/legacy calls could differ.

Future repair shape:

```text
Optionally add a small active-target eligibility precheck to service_pair(...) too, so direct service calls have the same abort safety.
```

Not urgent.

### 2. Cluster release on repair executor errors

Still open from the previous 0517 checkpoint:

```text
repair-executor-missing / repair-error can leave cluster reservation until TTL.
```

TTL is short, so this remains low/medium priority.

### 3. Inherited movement-contract issue

0517 delegates physical repair to `repair_executor_0516.lua`, which still has the movement-request failure watch item.

Repair should remain in the movement/repair layer, not 0517.

## Current Stage 5 decision

No code repair from this pass.

This caller-flow audit reduces concern around 0517:

```text
0517 is dispatcher-owned and ordinary combat fallback is structurally clear.
```

Updated priority ranking:

```text
1. 0527/0528 machine logistics / known-source fetch stale-state cleanup.
2. 0513 direct acquisition deposit/gathered_units correctness.
3. Movement completion/status contract across movement-dependent executors.
4. 0514 emergency production returning/deposit-block diagnostics.
5. 0516 repair movement failure/reservation release refinement.
6. 0515 consecration movement failure/cooldown-claim refinement.
7. 0517 low-priority direct-call abort symmetry and cluster-release refinement.
```

## Recommended next audit target

Continue Stage 5 with construction/ordinary logistics ownership:

```text
construction ownership/contracts
ordinary combat ownership
remaining direct set_command calls outside movement_controller.lua
```

The next most useful target is probably construction ownership, because construction can combine movement, reservations, item fetching, and target invalidation in one chain.
