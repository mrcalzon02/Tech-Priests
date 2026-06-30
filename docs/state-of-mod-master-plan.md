# Tech Priests — State of Mod and Milestone Development Plan

**Current packaged baseline:** `0.1.672`  
**Current development lane:** `0.1.674-dev` integration, validation, and hardening  
**Authoritative branch:** `main`  
**Engineering authority:** `docs/STANDARDS_AND_PRACTICES.md`  
**Canonical development history:** `docs/DEVELOPMENT_HISTORY.md`  
**Updated:** 2026-06-29

## Milestone Purpose

The source now contains a broad set of physical logistics, movement, construction, repair, combat-repair, fluid-network, energy, artillery, rocket-silo, roboport, defensive-support, lifecycle, migration, and diagnostic authorities.

The milestone objective is not to add disconnected features. It is to prove that these authorities coexist without duplicating resources, carrying imaginary custody, competing for a priest, overwriting concrete targets, corrupting persistent state, creating incompatible fluid networks, accumulating duplicate event or broker ownership, or claiming success when installation or execution failed.

The development standard remains physical honesty:

- Items must be removed from a real source before entering priest custody.
- Custody persists until delivery, return, or an explicitly recorded failure.
- Destination inventories are revalidated immediately before insertion.
- Leftovers are returned rather than deleted or duplicated.
- Fluids move through real Factorio networks rather than simulated inventory transfers.
- Movement target, status text, active leaf task, and visible intent identify the same destination.
- Existing automation retains ownership unless cooperation is explicitly designed.
- Normal gameplay and required diagnostics do not depend on runtime commands.
- Persistent state remains serializable across save, load, and configuration change.

## Governance and History

`docs/STANDARDS_AND_PRACTICES.md` is the authoritative engineering and release-governance document. It was reconstructed from verified repository behavior because the expected prior document was absent; it is not represented as a recovered verbatim original.

`docs/DEVELOPMENT_HISTORY.md` is the single canonical narrative development history. Behavior maps, focused audits, manifests, runbooks, and this plan are supporting documents rather than competing histories.

All active GitHub development remains on the single branch `main`. Work proceeds through meaningful sequential slices.

Packaging is required to fail closed if the standards document, canonical history, milestone truth, or governance checker is missing or inconsistent.

## Completed Foundation

### Behavior and authority mapping

The behavior-map series documents the principal runtime chains from dispatcher and action arbitration through movement, direct acquisition, construction, infrastructure planning, order queues, emergency production, consecration, repair, combat repair, and the broader dispatcher family.

The current authority model is:

1. A broad parent objective may remain active as context.
2. A concrete leaf task owns the immediate action and target.
3. Movement points at the leaf target.
4. Vector enforcement may enforce movement but must not invent a destination.
5. Status and visual intent report the same leaf task.

### Movement and target truth

The direct-acquisition movement stack includes physical-target validation, target locking, request reconciliation, movement-intent authority, active-leaf truth, visual-intent authority, and vector enforcement.

Runtime work must still prove that legacy wrappers and retarget holds cannot restore a stale destination between authority pulses.

### Repair and combat repair

Repair and combat-repair remediation added integrity checks, terminal cleanup, custody protection, and clearer completion handling.

Runtime work must confirm repair packs are neither duplicated nor stranded when combat begins, a target is destroyed, or a task changes family.

### Construction and infrastructure

Construction placement prioritizes the active construction task, bootstrap ghost, master-plan preferred item, and then other placeable stock. Physical placement removes a real item before entity creation and restores or refunds it on failure.

The infrastructure planner still needs behavioral proof that operational readiness—not mere entity existence—drives progression.

### ALT resource fields and station ranges

ALT-mode resource presentation aggregates claims across same-force Cogitators on the player's surface. Central station range authority was increased while preserving the direct-mining leash.

A future polish pass must verify overlay cleanup, surface and force changes, overlapping claims, and dense-field performance.

## Physical Logistics Families

### Machine logistics

Machine logistics contains integrity, candidate recovery, and final-authority layers. It selects exact inventories, visits real sources, persists custody, revalidates destinations, and returns leftovers.

Required runtime evaluation:

- input delivery, output evacuation, and trash evacuation;
- partial insertion and full destinations;
- source or destination destruction;
- combat interruption and save/load;
- storage-full recovery;
- vanilla and modded crafter inventory compatibility;
- proof that no legacy executor acts concurrently with final authority.

### Storage roles and inventory transfer integrity

Storage-role authority and transfer-integrity guards provide common storage selection, exact deposits, and custody support.

Required runtime evaluation:

- every eligible destination full;
- storage replaced or destroyed during custody;
- station ownership preventing cross-station stock consumption.

### Item-family logistics

Specialized item families cover compatible ammunition, modules, fuel, burnt results, and inventory classes that cannot be treated as ordinary ingredients.

Required runtime evaluation:

- prototype-category matching for vanilla and modded items;
- rejection of superficially similar but incompatible variants;
- save/load and interruption with active custody.

## Fluid-Network Families

Input-fluid doctrine identifies required recipe fluids, reads real segment content and capacity, finds compatible same-force sources, and proposes physical connections.

Output-fluid doctrine identifies compatible sinks and plans real output networks instead of deleting or inventory-simulating produced fluids.

Position-scoped reservations, route planning, collision validation, execution guards, and port-context guards reduce conflicting claims and incompatible joins.

Required runtime evaluation:

- empty, filtered, ambiguous, and contaminated networks;
- source or sink destruction during construction;
- blocked routes and retry limits;
- adoption of existing compatible pipes;
- simultaneous nearby stations;
- save/load during partial construction;
- pipe shortage and later resupply;
- unusual modded fluidbox geometry.

Fluid behavior remains one of the highest-risk runtime areas because a syntactically valid route can still connect the wrong physical network.

## Energy Families

Read-only readiness covers boilers, burner generators, reactors, fusion reactors, electrical connection, heat prerequisites, fluid prerequisites, fuel inventories, and burnt-result inventories.

Physical energy logistics prioritizes burnt-result evacuation before fuel delivery. Fuel is selected only when the exact fuel inventory accepts it and the exact burnt-result inventory can retain its result.

`energy_item_automation_guard_0722.lua` and its installation assertion are installed through `planning_constraints_0646.lua`. The earlier wiring gap is closed at source level.

Required runtime evaluation:

- manual boiler service and automated boiler exclusion;
- reactor fuel delivery and spent-cell evacuation;
- full burnt-result inventory;
- missing heat, water, or steam paths;
- fusion prerequisite reporting;
- custody return if automation appears during an active task.

## Specialized Entity Families

### Rocket silos

Readiness reports crafting inputs, fluid prerequisites, rocket-part progress, launch state, cargo and payload inventories, trash, logistics ownership, and external automation.

Physical service is restricted to approved manual ingredient delivery and trash evacuation. Priest logic does not mutate payload, attached cargo, rocket parts, recipes, launch settings, or launch transitions.

Required runtime evaluation includes manual service, external automation, launch interruption, full inputs, trash handling, and Space Age versus non-Space Age behavior.

### Artillery

Fixed turrets and artillery wagons use dedicated ammunition inventories. Wagons are eligible only while stationary and explicitly in manual control.

Priest logic never changes train speed, schedule, state, manual mode, target selection, or firing behavior. Shell custody must be returned if a wagon moves or automation resumes.

Required runtime evaluation includes fixed turrets, stationary manual wagons, movement before and during custody, automatic-mode transition, inserter ownership, and modded ammunition.

### Roboports

Readiness audits robot inventories, repair materials, electrical buffer, logistic cell and network membership, charging pressure, and network robot counts.

Physical service is limited to repair-pack replenishment. Robot population remains monitor-only.

Required runtime evaluation includes active networks, no construction robots, missing networks, low energy, external automation, full material inventory, and proof that robot inventories are not mutated.

### Fluid turrets

Readiness audits accepted attack fluids, pipeline supply, internal ammunition buffer, contamination, activation threshold, status, and firing readiness.

Source proposal and planner integrity identify one accepted fluid, one real compatible source segment, the exact turret fluidbox, exact unused ports, and a real source interface. Physical planning builds from source toward the turret so final connection occurs only on the last tile.

Required runtime evaluation includes vanilla oil choices and damage preference, filtered and ambiguous empty networks, contamination, unusual modded indices, blocked routes, compatible-pipe adoption, and serializable plan state.

## Runtime, Lifecycle, and Diagnostics

### Commandless runtime

Command cleanup removes confirmed Tech Priests commands and audits for late registrations. Unrelated commands must remain untouched. No gameplay behavior may depend on removed commands.

### Development integration audit

The read-only integration auditor checks overlapping exclusive tasks, simultaneous fluid plans, orphaned custody, ledger mismatch, orphaned pipe tasks, invalid targets and endpoints, fluid prototypes in item requests, missing module globals, and surviving Tech Priests commands.

It diagnoses only and does not silently repair live state.

### Lifecycle and broker integrity

The development lifecycle checkpoint uses the canonical runtime event registry for initialization and configuration changes. Periodic diagnostics use the runtime tick broker.

Broker integrity audits missing, duplicate, and malformed services. Migration lifecycle assertion requires exactly one migration pair audit service and makes clean pair integrity mandatory for lifecycle completion without adding a separate timer or event authority.

### Migration pair integrity

The read-only migration audit inventories every station-pair entry and reports invalid, duplicated, mismatched, cross-force, and cross-surface links. It does not repair, relink, respawn, teleport, or remove pairs.

### Runtime evidence tooling

`tools/prepare_migration_test_mod.py` creates an unpackaged `0.1.673` test copy while preserving the authoritative `0.1.672` source metadata.

`tools/check_migration_runtime_evidence_0737.py` requires separate new-save and `0.1.672` upgrade logs. Both scenarios must contain at least one valid station/priest pair and must show clean installation, lifecycle, broker, and migration diagnostics with no Lua or event errors.

`docs/MIGRATION_RUNTIME_VALIDATION.md` is the operator runbook for those scenarios.

No accepted Factorio runtime evidence has yet been recorded.

## Source Validation

The `main` workflow parses every Lua source file with Lua 5.2, validates `info.json`, compiles Python tooling, audits generic inventory safety, validates the development integration graph, validates migration lifecycle wiring, self-tests runtime evidence parsing, validates governance prerequisites, and verifies the disposable migration-test builder.

**Current validation gap:** connector-authored commits have not surfaced a completed Actions run. No successful source-validation run has yet been recorded for the current development head.

## Current Milestone Evaluation

The source tree contains the breadth needed for a serious integration candidate, but it is not yet a release candidate.

Current facts:

- `info.json` remains at `0.1.672`.
- Development authorities use internal `0.1.674-dev` identifiers.
- Required development modules are installed through the `planning_constraints_0646.lua` hardener chain.
- Governance authority is `docs/STANDARDS_AND_PRACTICES.md`.
- Canonical narrative history is `docs/DEVELOPMENT_HISTORY.md`.
- Packaging is being made fail-closed on governance prerequisites.
- No `0.1.674` package has been compiled.
- No complete Factorio runtime load or migration test has been recorded.
- No successful CI source-validation result has been recorded for the current head.

## Gate Ledger — Required Order

### Gate 1: governance and build prerequisites

Source work:

- [x] Restore an authoritative standards document.
- [x] Establish one canonical development-history location.
- [x] Keep development on the single `main` branch.
- [ ] Complete and pass governance enforcement in CI and packaging.

### Gate 2: source integration

Source work:

- [x] Install the energy automation guard and assertion.
- [x] Track every hardener installation result.
- [x] Add broker exact-once integrity auditing.
- [x] Add lifecycle and migration integrity assertions.
- [x] Add source checks for the development integration graph.
- [ ] Prove every installation succeeds in a real Factorio load.
- [ ] Complete runtime review of specialized Factorio 2.0 API surfaces.
- [ ] Prove persistent storage remains serializable in save/reload.

### Gate 3: objective static validation

- [x] Define the source-validation workflow.
- [x] Add focused source and tooling checks.
- [ ] Record one successful workflow run and exact commit SHA in `docs/DEVELOPMENT_HISTORY.md`.
- [ ] Resolve every failure exposed by that run.

Passing static validation does not authorize a version bump.

### Gate 4: Factorio load and migration validation

- [ ] Build the disposable unpackaged `0.1.673` test copy from one exact source commit.
- [ ] Test a new game containing at least one valid pair.
- [ ] Test a disposable copy of an existing `0.1.672` save containing at least one valid pair.
- [ ] Confirm configuration-change installation.
- [ ] Save and reload both scenarios.
- [ ] Capture separate unedited `factorio-current.log` files.
- [ ] Produce accepted JSON evidence records.
- [ ] Treat every load-time API error as release-blocking.

### Gate 5: behavioral integration matrix

Run focused scenarios for:

- machine input, output, and trash logistics;
- storage-full and custody-return behavior;
- item-family compatibility;
- energy manual service and automation exclusion;
- rocket-silo manual service and launch interruption;
- fixed artillery and manual stationary wagons;
- roboport repair packs without robot-population mutation;
- fluid input and output construction;
- fluid-turret source selection and final connection;
- overlapping stations and reservation conflicts;
- combat interruption during every custody-bearing task;
- save/load during every active task family;
- movement, status, leaf truth, and visual-line agreement.

### Gate 6: release-candidate packaging

Only after Gates 1 through 5 pass:

1. Update `info.json` to `0.1.674`.
2. Update package description and changelog to verified behavior only.
3. Append the verified milestone to `docs/DEVELOPMENT_HISTORY.md`.
4. Run `python tools/package_local.py --overwrite`.
5. Inspect archive root, metadata, locale uniqueness, required files, and output name.
6. Install the packaged archive and perform a final clean load test.

## Release Definition for 0.1.674

Version `0.1.674` is complete only when the mod demonstrates all of the following:

- clean Lua and Factorio API loading;
- migration without corrupting station/priest pairs or storage;
- no incompatible simultaneous custody ledgers;
- no destination insertion without real source removal;
- real compatible fluid networks;
- no silent takeover of automated entities;
- no chasing or controlling mobile artillery wagons;
- rocket launch and payload state outside priest logistics authority;
- unchanged roboport robot populations;
- commandless normal operation and diagnostics;
- evidence explaining rejected, waiting, active, returned, completed, and aborted tasks;
- a reproducible archive matching the verified source commit.

Until these conditions are satisfied, the correct project state remains:

> **0.1.672 packaged baseline with an active 0.1.674-dev integration candidate on `main`.**
