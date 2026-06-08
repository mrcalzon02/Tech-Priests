# Tech Priests Behavior Order of Operations

This document is the stable behavior contract for the Tech Priests runtime while the older legacy `tick_pair` stack is being consolidated into explicit authority modules.

## Core doctrine

A Cogitator Station owns the work state, inventory, known resources, emergency facilities, and order queue. The Tech-Priest is the visible actuator, not the warehouse, not the scheduler, and not the place where resources secretly appear.

A priest may be replaced only by explicit lifecycle authority: paired station removal/death, controlled missing-priest rescue, or authorized mobility-prototype swap. Ordinary stuck detection, recovery, construction, acquisition, scavenge, or crafting code must not delete a priest.

World mining is physical work. A tree, rock, or ore patch may not smoke, take mining damage, lose amount, or produce station inventory unless the visible priest is physically adjacent to that target or a built emergency machine is performing the work. The 0.1.502 station-side quarantine may keep the priest from vanishing, but it is not permission to mine the far map by remote rite.

Crafting is timed work. If a priest performs a fallback station craft, it must have a visible craft phase and wait at least the relevant recipe time, preferably longer. Immediate completion is reserved only for cleanup of already-produced machine output, inventory transfer, or explicit debug tooling.

Emergency production should prefer sources in this order: station inventory and remembered stashes first, local scavenge from nearby friendly machines/containers second, built Martian emergency facilities third, then timed station ritual crafting only as a controlled fallback. Raw direct world acquisition is last, must be physical, and remains quarantined for far native-unit movement until the vanish bug is proven gone.

## Priority chain

1. Pair/lifecycle validation. Repair reverse maps, rebind or controlled-respawn missing priests, and preserve station/priest identity.
2. Combat defense. Hostile threats in range interrupt lower-priority work. Friendly, neutral, station, and priest targets are rejected.
3. Repair service. Damaged friendly machines and stations are repaired before sanctification or logistics work.
4. Active work continuation. Existing mining, crafting, construction, facility, or scavenge phases keep their lease unless combat/lifecycle interrupts them.
5. Inventory stewardship. The station inventory and station-bound stash paths are checked before new production is requested.
6. Local scavenge. Nearby friendly machines, containers, ground stock, and valid local sources are preferred over fresh craft.
7. Martian emergency facility doctrine. Build and use emergency miner, smelter, assembler, condenser, boiler, steam engine, power-grid, and lab chains when the base lacks normal infrastructure.
8. Construction placement. Build station-bound emergency machines or other requested infrastructure from station-owned inventory.
9. Timed station craft. Bootstrap emergency-device items and last-ditch fallback crafts may be made at the station with visible progress.
10. Physical direct acquisition. Mine trees, rocks, ore, or dirt only when the visible priest is actually beside the target. Far native-unit acquisition movement remains quarantined.
11. Consecration and routine logistics. When no emergency, combat, repair, construction, or active work is claiming priority, service machine sanctity and logistics.
12. Chatter/idle flavor. Speech and idle behavior must never mutate task state or hide a blocked higher-priority behavior.

## Current quarantine

Far native-unit emergency acquisition movement remains unsafe. The 0.1.502 station-side tether stopped the original vanish loop, but the 0.1.504 test proved that it could also allow remote smoke/damage/deposit behavior. The 0.1.505 doctrine therefore blocks far world mining entirely unless the visible priest is adjacent or a built emergency machine owns the work.

## Required diagnostics for future behavior work

Any future pass that touches acquisition, emergency craft, construction, or recovery should show the selected pair's lifecycle state, current order, legacy task fields, movement request, target distance, facility state, and why each priority claimed or declined. The expected command set is `/tp-scheduler-0361`, `/tp-behavior-0505`, `/tp-priest-vanish-0502`, `/tp-priest-recovery-0503`, and `/tp-emergency-diagnostics once`.

## 0.1.506 Mobility/Recovery Clarification

Recovery is not a normal scheduler action. A valid same-surface priest is allowed to travel away from the station to perform work. Recovery may rebind or respawn an invalid priest, and a future explicit command may recall a priest, but ordinary `ensure_pair_priest` calls, stale recall flags, direct-acquisition work, or watchdog pulses must not teleport a valid priest home.

Physical direct acquisition now follows this contract: choose target, walk to target, wait until adjacent, then begin mining/scavenging work. No smoke, damage, laser, or deposit is valid while the priest is not physically near the target.

## 0.1.507 Scheduler / Arbiter Split

The task scheduler and the single-action arbiter are not the same authority. The scheduler owns intent: it decides which job, writ, order, or emergency need should exist next. The action arbiter owns physical exclusivity: it decides which one visible action family the priest may perform right now. The executor owns completion: it performs that action over time and reports progress or completion.

A scheduler may submit or promote an order, but it must not directly mine, craft, repair, draw combat beams, or teleport a priest. An arbiter may say `combat beats acquisition this tick` or `crafting suppresses mining visuals`, but it must not invent a new supply request or complete a craft. An executor may move, mine, craft, repair, or build once claimed, but it should not decide the global priority order by itself.

The 0.1.507 cleanup begins this split by moving duplicate direct-acquisition pulsing out of Work State GUI recovery and making acquisition/crafting services single-install runtime-registry owners. Legacy fragments may still submit intent, but recurring executor pulses should now live with their owning executor modules.


## 0.1.508 Recovery / Movement Split

Recovery is now explicitly passive for valid same-surface priests. `ensure_pair_priest`, rescue pulses, watchdog pulses, stale recall flags, and older immediate/force-recall callers may repair maps and clear stale missing-priest state, but they may not teleport or stop a priest that is alive on the same surface as its station. Missing or cross-surface priests still pass to the controlled recovery chain.

Direct acquisition now owns a movement lease. If a direct mining/dirt/tree/rock task has a world target and the priest is not adjacent, the executor submits a movement request and waits. The old mining, smoke, damage, and deposit code is only allowed to run after the visible priest reaches the target band.

## 0.1.509 Unit Survival / Station-Side Quarantine Retirement

The visible Tech-Priest unit prototypes must explicitly opt out of native command-failure cleanup. Every priest and belt-immune priest prototype is hardened with `ai_settings.destroy_when_commands_fail = false`, `allow_try_return_to_spawner = false`, `do_separation = false`, and `join_attacks = false` so the engine does not treat scripted worker priests like expendable attack units.

The 0.1.502 station-side direct-acquisition quarantine is retired as an executor. It may remain as a diagnostic observer, but it must not tether valid priests, suppress far movement, soften remote world targets, or deposit station-side resources. Direct acquisition belongs to the physical executor: walk to target, wait until adjacent, work over time, then deposit.

Mouse-over, radar scan, and overview refreshes are debug/visibility nudges, not behavior owners. They may wake an idle pair, but they must not reset active mining, crafting, facility, scavenge, or return-to-station work every few ticks.

## 0.1.510 Dispatcher Migration Contract

The runtime refactor now treats `scripts/core/single_dispatcher_0510.lua` as the first per-pair controller pass. The dispatcher does not yet own every behavior family, but it establishes the required operating path:

```text
lifecycle validation
→ order_queue_0469 tick/adoption/promotion
→ action_state_arbiter_0488 classification
→ one executor call
→ visuals/audio/GUI read only
```

For 0.1.510, the dispatcher owns two action families:

1. **Physical direct acquisition**: the dispatcher calls `acquisition_executor.service_pair` and gates legacy `tick_pair` while that pair is in a direct-acquisition/travel lease. The old acquisition executor's independent nth-tick pulse is suppressed unless called by the dispatcher or manually.
2. **Timed station craft**: the dispatcher calls `crafting_executor.before_legacy_handle` and gates legacy `tick_pair` while station-craft/return-to-station craft is active. The old crafting executor's independent pulse is suppressed unless called by the dispatcher.

Combat, repair, consecration, construction, and emergency-machine production are still migration targets. They may still execute through older modules, but they must be migrated one family at a time so no two controllers fight over the same priest.

Legacy `tick_pair` is no longer considered the desired controller. It may remain as a compatibility leaf only until each behavior family has been moved behind the dispatcher.


## 0.1.511 movement bounds addendum

Direct acquisition is now additionally constrained by a movement bounds contract. The dispatcher may allow a direct-acquisition family action, but the target must still be inside the role-appropriate direct work radius before travel is allowed. Planetary Magi have the most conservative personal direct-acquisition bounds because their intended role is command, delegation, emergency coordination, and local intervention, not sprinting into the wilderness for fallback raw materials.

If the direct target is outside the allowed radius, the target is rejected, the current direct pointer is cleared, and the scheduler/executor must choose a different local target, delegate, build/use emergency machinery, or wait for proper resources. If the priest has already exceeded the hard leash, the response is a walk-home command, not a teleport.

The old generated 0.1.273 direct-gather one-second hard kick is no longer an authorized control path once `movement_bounds_contract_0511` is installed. Direct acquisition must route through the dispatcher/acquisition-executor path and obey the movement bounds contract.

## 0.1.512 Scheduler Contract Addendum

The scheduler/order queue is now being treated as a stable intent authority rather than a transient reflection of whichever legacy planner shouted most recently. Once an order is active, it receives a short lease so travel, local direct acquisition, station craft, and other visible work can make progress without being reset by passive refreshes. Combat, validation, and repair remain allowed interrupt families, but passive UI/mouse-over/radar refreshes and repeated strategic cascade pulses should fold into, hold behind, or debounce against the active order instead of replacing it.

The dispatcher still owns the per-pair runtime pulse. The scheduler contract does not mine, craft, repair, or move the priest. Its job is to keep intent stable long enough for the dispatcher/action/executor chain to do physical work. If the old order queue tries to clear a current order while dispatcher-owned work is still active, the 0.1.512 contract may re-hold that order for another lease and record `current-reheld-0512` for diagnostics.

Planetary Magos cascade behavior is now explicitly cooldown-gated while active work exists. A Planetary Magos may still coordinate, delegate, and request emergency work, but it should not repeatedly cascade the same emergency plan every few seconds while the station/priest pair is already executing a current order.


## 0.1.513 Direct acquisition executor migration

Direct acquisition is now intended to be a dispatcher-owned executor family rather than an old generated controller. The target operating chain is:

```text
order queue current intent
→ dispatcher classifies direct acquisition
→ direct_acquisition_executor_0513 adopts the current direct task
→ movement bounds validate target distance
→ priest walks adjacent
→ extraction runs over visible time
→ result is deposited through the inventory steward
→ priest returns or yields to station craft
→ order queue observes completion/yield state
```

The direct acquisition executor owns the following phase labels:

```text
none
need-target
target-invalid
target-rejected
walk-to-target
work-target
return-for-craft
return-to-station
complete
```

Legacy 0273/0312/0315 direct mining functions are permitted to remain loaded as compatibility helpers, but once `direct_acquisition_executor_0513` owns a current direct task they must not independently mine, damage, smoke, deposit, retarget, or command movement. The correct behavior for invalid or far targets is to clear/replan or let the 0.1.511 movement-bounds contract reject the target, not to remote mine or long-sprint into the wilderness.

## 0.1.514 Emergency Production Chain

Emergency production must follow this order:

```text
1. Scheduler/order queue maintains the item need.
2. Dispatcher claims station-craft/emergency-production for the pair.
3. Emergency production executor checks whether the Cogitator Station already has the item.
4. Existing owned Martian emergency facility outputs are collected into the station.
5. Emergency facility doctrine is called only as a leaf helper to feed/request machines.
6. If the correct machine exists, wait for machine output rather than instantly hand-crafting.
7. If machine production cannot proceed and gathered materials are ready, use timed station fallback craft.
8. Deposit output to the station and complete the active order/task.
```

Legacy emergency craft and emergency facility periodic pulses must not independently complete dispatcher-owned production work.



## 0.1.515 consecration executor ownership

Consecration is now a dispatcher-owned action family. The correct runtime chain is:

```text
intent/order identifies machine-spirit maintenance
→ dispatcher/action arbiter classifies consecration
→ consecration_executor_0515 selects a useful target
→ priest walks into capsule/service range
→ priest spends visible rite time
→ station-supplied consecration capsule item is consumed
→ shared source-context API applies sanctity
→ machine ledger records priest/station/item/method/order
→ target cooldown prevents repeated top-off loops
```

Legacy `sanctify_target_with_priest` may remain temporarily, but only as an adoption wrapper into the 0.1.515 executor. It must not regain direct controller authority over station inventory consumption or instant sanctity restoration.


## 0.1.516 repair executor doctrine

Repair is now a dispatcher-owned action family. The scheduler/order queue may identify the need for repair, but the 0.1.516 executor owns the physical work. The expected chain is:

```text
damaged entity detected
→ repair order or legacy repair call is adopted
→ dispatcher classifies repair
→ repair_executor_0516 selects the best target by damage severity, role priority, and proximity
→ target is reserved to prevent priest dogpiles
→ priest walks to repair range
→ repair packs are consumed over timed repair ticks
→ target is repaired to full health
→ target cooldown/reservation is released
→ order completes or next repair target is selected
```

Repair should prioritize actual damage and target distribution over perfect repair-pack efficiency. A priest should not look idle because a repair pack would be partially wasted. Combat still interrupts repair; repair should generally beat consecration and routine work.

## 0.1.517 combat repair doctrine

Combat repair is a tactical sub-family inside the combat section, not ordinary routine repair. The intended battlefield chain is now:

```text
combat threat detected
→ check immediate self-preservation
→ scan for defended damaged wall/gate clusters
→ if loaded/active turrets or combat-active priests cover the wall, claim combat-repair
→ route physical repair through repair_executor_0516
→ abort repair if cover disappears or the priest becomes exposed
→ otherwise continue ordinary combat firing/legacy combat leaf behavior
```

This means wall repair under fire is allowed when it preserves a functioning defensive system. A priest should not continue repairing an uncovered wall while enemies are reaching him. Ordinary repair remains lower-priority routine work; combat repair is the exception that keeps a defended wall screen intact while guns or other priests suppress the swarm.



## 0.1.518 movement cadence doctrine

Long physical actions now require movement leases. Consecration, direct acquisition, repair, combat repair, construction, and dispatcher-owned production travel may request a route and keep that route while the target remains valid. Lower-priority scheduler or legacy refreshes should not replace that route every few ticks. Combat, retreat, and real lifecycle recovery remain allowed to interrupt.

Consecration is routine local maintenance. A priest should not wander far away to service a distant machine, and missing consecration supplies should cool down instead of spamming a new failed consecration attempt every dispatcher pulse.


## 0.1.519 logistics and construction placement doctrine

Inventory transfer is physical unless the source is the Cogitator Station itself. Loose items, containers, machines, and other source inventories require the priest to travel to the source before withdrawal/deposit is credited to station work inventory. Construction from an already-owned placeable item has high priority: create/hold a ghost marker, move the priest to the source/site as needed, then place the actual item. Resource expansion ghosts are deferred unless the required station item is present or producible by currently unlocked/station-known means.


## 0.1.520 Portrait assignment note

Portrait assignment is not a behavior authority. The portrait system slices existing portrait sheets into GUI sprite cells and stores a persistent portrait seal for each Cogitator/Tech-Priest pair. It must remain read-only with respect to work: it may display identity, but it must not submit orders, move priests, pulse executors, or alter scheduler/dispatcher state.


## 0.1.521 UI tab note

Writ Queue, Forge Plan, and Command Tree are now structured read-only Work State tables. They should help diagnose the authoritative stack but must not become behavior controllers.


## UI slate note — 0.1.522

The Cogitator Work-State Reliquary captions were polished after the structured tab cleanup. This does not change behavior order: UI slates report state only and must not create, complete, replace, teleport, mine, craft, repair, consecrate, or construct work.


## 0.1.525 Tech-Priest identity background note

Expanded Tech-Priest background dossiers are UI/lore state only. `scripts/core/priest_identity_background_0525.lua` writes persistent personal dossier fields for the Work-State Reliquary and diagnostics. It must not submit orders, move priests, alter repair/consecration/combat priorities, or change scheduler/dispatcher behavior.

## 0.1.527 universal known-resource fetch note

Known cataloged item sources beat raw acquisition. If an exact needed item exists in a scanned container, machine inventory, vehicle/corpse inventory, or loose ground stack, `logistics_fetch_executor_0527` should send the priest to physically collect it before direct mining or emergency crafting tries to produce it from scratch.

## 0.1.528 machine logistics fulfillment note

Non-automated local assemblers and furnaces may now be serviced as dispatcher-owned machine logistics. The intended chain is:

```text
machine has output, detritus, low fuel, or missing item ingredients
→ dispatcher offers machine-logistics before raw acquisition/emergency crafting
→ skip machines adjacent to inserters/loaders/belts/pipes/pumps by default
→ priest walks to the machine
→ output/detritus is physically removed or fuel/ingredients are physically inserted
→ output is carried to retention/station storage
→ detritus/scrap are carried to an internally tagged waste box when available
→ missing ingredients become exact item needs for universal known-source fetch
```

This is not fluid logistics yet. Machines with pipe/fluid arrangements are treated as automated/handled by the player's network until a dedicated fluid-service doctrine exists.

## 0.1.529 scan and ground-item logistics doctrine

The scan-beam controller is now the single visual authority for Tech-Priest scan/mining/combat beam lines. Direct mining, resource scanning, inventory scanning, and world-object damage should use the 0.1.529 controller rather than adding new independent `rendering.draw_line` fragments. Beam color is now semantic: mining/resource/world-damage uses hot orange/red, inventory fetch uses amber, logistics uses green, repair/consecration use maintenance colors, and combat uses hostile red.

Loose ground items are now a dispatcher-owned logistics action. If safe and inside station range, a priest should physically walk to dropped item stacks, pick them up, and then deposit them into station or retention storage. If station storage is full, the priest should prefer remembered retention boxes, then unautomated nearby containers, then place station-adjacent storage if a chest item is available. Returning items to the ground is not an ordinary completion path.

