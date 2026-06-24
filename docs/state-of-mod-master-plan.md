# Tech Priests — State of Mod and Milestone Development Plan

**Current packaged baseline:** `0.1.672`  
**Current development lane:** `0.1.674-dev` integration, validation, and hardening  
**Authoritative branch:** `main`  
**Updated:** 2026-06-24

## Milestone Purpose

The current milestone is no longer primarily about adding another isolated behavior. The mod now contains a broad set of physical logistics, movement, construction, repair, combat-repair, fluid-network, energy, artillery, rocket-silo, roboport, and defensive-support authorities.

The immediate milestone objective is therefore to prove that these authorities can coexist without duplicating items, carrying imaginary resources, fighting over a priest, overwriting one another's targets, corrupting custody state, creating incompatible pipe networks, or silently claiming success when installation or execution failed.

The development standard remains physical honesty:

- Items must be removed from a real source before they enter priest custody.
- Custody must persist until delivery, return, or an explicitly recorded failure.
- Destination inventories must be revalidated immediately before insertion.
- Leftovers must be returned rather than deleted or duplicated.
- Fluids must move through real Factorio fluid networks rather than simulated inventory transfers.
- Movement target, status text, active leaf task, and visible intent line must identify the same concrete destination.
- Existing automation must retain ownership unless a system is explicitly designed to cooperate with it.
- No runtime command should be required to make the mod function or explain its state.

## Completed Foundation

### Behavior and authority mapping

The behavior-map series now documents the principal runtime chains from the dispatcher and action arbiter down to concrete executors. The completed mapping includes movement, direct acquisition, construction, infrastructure planning, order queues, emergency production, consecration, repair, combat repair, and the broad dispatcher family.

This work established the current authority model:

1. A broad parent objective may remain active as context.
2. A concrete leaf task owns the immediate action and target.
3. Movement must point at the leaf target.
4. The vector enforcer may enforce movement but must not invent a destination.
5. Status and visual intent must report the same leaf task.

### Movement and target truth

The direct-acquisition movement stack now contains physical-target validation, target locking, request reconciliation, movement-intent authority, active-leaf truth, visual intent authority, and vector enforcement.

The major remaining concern is no longer basic target selection. It is confirming under runtime load that legacy wrappers and request-retarget holds cannot reintroduce a stale destination between authority pulses.

### Repair and combat repair

Repair and combat-repair remediation added integrity checks, terminal cleanup, custody protection, and clearer completion-state handling.

The next runtime pass must confirm that repair packs are neither duplicated nor stranded when combat begins, a target is destroyed, or a repair task changes family.

### Construction and infrastructure

Construction placement now prioritizes an active construction task, bootstrap ghost, master-plan preferred item, and then other placeable stock. Physical placement removes a real item before entity creation and restores or refunds on failure.

The infrastructure planner still follows a fixed bootstrap sequence. Operational readiness is not yet a complete substitute for simple role existence, so the master infrastructure plan must eventually distinguish between an entity that exists and one that is powered, supplied, connected, and productive.

### ALT resource fields and station ranges

ALT-mode resource presentation now aggregates claims across same-force Cogitators on the player's surface and presents large deposits as field-level overlays instead of one isolated resource icon. Central station range authority was also increased while preserving the direct-mining leash.

A future polish pass should verify overlay cleanup, surface changes, force changes, overlapping claims, and performance on dense resource fields.

## Completed Physical Logistics Families

### Machine logistics

Machine logistics now has integrity, candidate recovery, and final-authority layers. The system is designed to select exact inventories, visit real source inventories, persist custody, revalidate destinations, and return leftovers.

Required next evaluation:

- Test input delivery, output evacuation, trash evacuation, partial insertion, destination destruction, source destruction, combat interruption, and storage-full recovery.
- Confirm furnaces, assemblers, and modded crafters expose the expected inventory constants under Factorio 2.0.
- Confirm no older machine executor can operate concurrently with the final authority.

### Storage roles and inventory transfer integrity

Storage-role authority and transfer-integrity guards now provide common storage selection, exact deposits, and custody support for later families.

Required next evaluation:

- Fill every eligible destination and verify no item disappears.
- Destroy or replace a storage entity while custody exists.
- Confirm station ownership prevents one Cogitator from consuming another Cogitator's reserved stock.

### Item-family logistics

Specialized item families now cover compatible ammunition, modules, fuel, burnt results, and other inventory classes that should not be treated as ordinary crafter ingredients.

Required next evaluation:

- Confirm prototype-category matching against modded ammunition and modules.
- Confirm incompatible item variants are rejected rather than inserted into a superficially similar inventory.
- Confirm all custody survives save/load and task interruption.

## Completed Fluid-Network Families

### Input-fluid network doctrine

The input-fluid doctrine identifies required recipe fluids, reads real segment contents and capacity, finds compatible same-force sources, and proposes physical connections.

The connection planner reserves route tiles, requests real pipe items, and delegates placement to the construction executor. Execution guards and port-context validators prevent ambiguous or contaminated connections.

### Output-fluid sink doctrine

Output-fluid handling identifies compatible sinks and plans real output networks instead of deleting or inventory-simulating produced fluids.

### Fluid port collision and reservation scope

Position-scoped reservations, collision validation, and port-context guards reduce the risk of two fluid plans claiming the same tile or joining incompatible segments.

Required next evaluation for all fluid work:

- Empty source network.
- Source contamination.
- Destination contamination.
- Source or sink destroyed during construction.
- Route blocked after reservation.
- Existing compatible pipe adoption.
- Existing ambiguous empty network rejection.
- Two simultaneous stations proposing nearby routes.
- Save/load during a partially constructed route.
- Pipe shortage and later resupply.

Fluid behavior remains one of the highest-risk runtime areas because a syntactically valid plan can still create an incorrect network when modded entities expose unusual fluidbox geometry.

## Completed Energy Development Candidates

### Energy readiness

Read-only energy readiness covers boilers, burner generators, reactors, fusion reactors, electrical connection, heat-network prerequisites, fluid prerequisites, fuel inventories, and burnt-result inventories.

### Physical energy logistics

The energy executor was repaired from an incomplete fragment into a full custody-based implementation. Burnt-result evacuation is prioritized before fuel delivery. Fuel is selected only when the exact fuel inventory accepts it and its burnt result can be retained by the exact burnt-result inventory.

### Energy automation ownership guard

`energy_item_automation_guard_0722.lua` exists and identifies inserter- or loader-owned energy entities so priests do not compete with established automation.

**Current integration gap:** the guard exists in source but is not presently listed in `planning_constraints_0646.lua`. Wiring and validating this guard is an immediate next task.

Required next evaluation:

- Manual boiler fuel delivery.
- Automated boiler exclusion.
- Reactor fresh-fuel delivery and spent-cell evacuation.
- Full burnt-result inventory.
- Missing heat connection.
- Missing water or steam path.
- Fusion prerequisite reporting.
- Custody return when automation appears during an active task.

## Completed Specialized Entity Families

### Rocket silos

The rocket-silo readiness doctrine separately reports rocket-part crafting inputs, fluid prerequisites, rocket-part progress, launch state, cargo and payload inventories, trash, logistics-network ownership, and external automation.

Physical silo logistics is restricted to manual rocket-part ingredient delivery and trash evacuation. It does not mutate rocket payload, attached cargo, rocket parts, recipes, transitional requests, automatic launch settings, or launch-state transitions.

Required next evaluation:

- Manual silo ingredient delivery.
- Silo owned by inserters or logistics automation.
- Rocket ready while a priest task is pending.
- Launch begins during custody.
- Full input inventory.
- Trash evacuation without touching payload cargo.
- Space Age and non-Space Age silo behavior.

### Artillery

Fixed artillery turrets and artillery wagons use their dedicated ammunition inventories. Wagons are eligible only while their train is stationary and explicitly in manual control.

The priest must return shells if a wagon moves or returns to automatic control. The mod must never change train speed, schedule, state, manual mode, target selection, or firing behavior.

Required next evaluation:

- Fixed turret refill.
- Manual stationary wagon refill.
- Wagon begins moving before pickup.
- Wagon begins moving during custody.
- Train switches to automatic mode.
- Existing inserter-owned artillery exclusion.
- Modded artillery ammunition compatibility.

### Roboports

Roboport readiness audits robot inventories, repair-material inventory, electrical buffer, logistic cell and network membership, charging pressure, and network robot counts.

Physical service is intentionally limited to repair-pack replenishment. Construction-robot and logistic-robot population remains monitor-only because changing robot population changes network strategy rather than merely replacing a consumed supply.

Required next evaluation:

- Repair-pack refill with an active construction network.
- No construction robots.
- Missing logistic network.
- Low energy buffer.
- External inserter ownership.
- Full material inventory.
- Verify robot inventory is never mutated.

### Fluid turrets

Fluid-turret readiness audits accepted attack fluids, pipeline supply, internal ammunition buffer, contamination, activation threshold, status, and firing readiness.

The source proposal and integrity layers identify one accepted fluid, one real same-fluid source segment, the exact turret fluidbox, exact unused turret ports, and an actual unused source interface.

The physical planner reserves an ordinary-pipe route and builds from source toward turret so the turret is connected only on the final tile.

Required next evaluation:

- Vanilla flamethrower turret with crude oil, heavy oil, and light oil sources.
- Correct damage-modifier preference where multiple fluids are available.
- Empty but filtered source network.
- Unfiltered ambiguous empty source network.
- Contaminated source or turret.
- Unusual modded turret fluidbox indices.
- Blocked route and route retry limit.
- Existing compatible pipe adoption.
- Ensure no cyclic storage data survives.

## Runtime and Diagnostic Hardening

### Commandless runtime

The command-cleanup authority removes confirmed Tech Priests diagnostic commands after installation and periodically audits for late registrations. Automatic pair-dump diagnostics remain authoritative.

Required next evaluation:

- Confirm all known Tech Priests commands are removed.
- Confirm commands owned by unrelated mods are not removed.
- Confirm no gameplay behavior depends on a removed command.

### Development integration audit

The read-only integration auditor checks for:

- overlapping exclusive logistics tasks,
- simultaneous fluid plans,
- orphaned custody,
- custody/task ledger mismatches,
- orphaned pipe-construction tasks,
- invalid task targets and plan endpoints,
- fluid prototypes accidentally placed into item requests,
- missing module globals,
- surviving Tech Priests commands.

The auditor diagnoses only. It must not silently rewrite live state until individual recovery policies are explicitly designed and tested.

### Source-validation workflow

A `main`-branch GitHub Actions workflow now parses Lua with Lua 5.2, validates `info.json`, and compiles Python tooling.

**Current validation gap:** connector-authored commits did not automatically produce a completed Actions result, and no successful validation run has yet been recorded for this development batch.

## Current Milestone Evaluation

The source tree contains the broad feature set needed for a serious integration candidate, but it is not yet a release candidate.

The following statements are currently true:

- `info.json` remains at `0.1.672`.
- New authorities use internal `0.1.674-dev` identifiers.
- The development modules are installed through the `planning_constraints_0646.lua` hardener chain, except the energy automation guard noted above.
- No 0.1.674 package has been compiled.
- No complete Factorio runtime load test has been recorded for this batch.
- No successful CI source-validation result has been recorded for this batch.
- `docs/STANDARDS_AND_PRACTICES.md` is absent from the expected path.
- The standards prerequisite therefore remains unresolved before packaging.

## Immediate Next Work — Required Order

### Gate 1: restore governance and build prerequisites

1. Restore or locate the authoritative `docs/STANDARDS_AND_PRACTICES.md` document.
2. Read and summarize it before any package build.
3. Confirm the authoritative development-history location and append this milestone honestly rather than creating another standalone audit history.
4. Keep all GitHub development on the single `main` branch.

### Gate 2: complete source integration

1. Add `energy_item_automation_guard_0722.lua` to the installed hardener chain.
2. Confirm every required module returns a successful installation result.
3. Confirm broker service registration is idempotent by name and does not accumulate duplicate pulses after configuration changes.
4. Review all new storage tables for cyclic references, functions, or other non-serializable values.
5. Review all Factorio 2.0 API names used by specialized inventories, train state, logistic cells, rocket silos, fluidboxes, and command cleanup.

### Gate 3: run objective static validation

1. Trigger the source-validation workflow on `main`.
2. Resolve every Lua parser, JSON, or Python-tooling failure.
3. Record the successful workflow run and commit SHA in development history.
4. Do not bump the package version merely because syntax validation passes.

### Gate 4: Factorio load and migration validation

1. Load the current source as a development mod with required dependencies.
2. Test a new game.
3. Test an existing 0.1.672 save.
4. Confirm configuration-change installation succeeds.
5. Confirm storage remains serializable across save and reload.
6. Capture `factorio-current.log` and automatic emergency diagnostics.
7. Treat every load-time API error as release-blocking.

### Gate 5: behavioral integration matrix

Run focused scenarios for:

- machine input, output, and trash logistics,
- storage-full and custody-return behavior,
- item-family compatibility,
- energy manual service and automation exclusion,
- rocket-silo manual service and launch interruption,
- fixed artillery and manual stationary wagons,
- roboport repair packs without robot-population mutation,
- fluid input and output construction,
- fluid-turret source selection and final connection,
- overlapping stations and reservation conflicts,
- combat interruption during every custody-bearing task,
- save/load during every active task family,
- movement, status, leaf truth, and visual-line agreement.

### Gate 6: release-candidate packaging

Only after Gates 1 through 5 pass:

1. Update `info.json` to `0.1.674`.
2. Update the package description and changelog to match verified behavior only.
3. Append the verified milestone to development history.
4. Run `python tools/package_local.py --overwrite`.
5. Inspect the archive root, metadata, locale uniqueness, required files, and versioned output name.
6. Install the packaged archive and perform one final clean load test.

## Release Definition for 0.1.674

Version `0.1.674` is complete only when the mod can demonstrate all of the following:

- It loads without Lua or API errors.
- Existing saves migrate without corrupting Tech Priest pairs or storage.
- One priest cannot hold two incompatible custody ledgers.
- Physical items cannot be created by destination insertion without source removal.
- Fluid systems use real connected networks and reject incompatible segments.
- Automated entities are not silently taken over by manual priest logistics.
- Mobile artillery wagons are never chased or controlled.
- Rocket launch and payload state remain outside priest logistics authority.
- Roboport robot populations remain unchanged.
- Removed runtime commands are not required for normal operation or diagnostics.
- Automatic diagnostics expose enough evidence to explain every rejected, waiting, active, returned, completed, and aborted task.
- The packaged archive is reproducible and matches the verified source commit.

Until these conditions are satisfied, the correct project state remains:

> **0.1.672 packaged baseline with an active 0.1.674-dev integration candidate on `main`.**
