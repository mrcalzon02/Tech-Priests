# Tech Priests — State of Mod and Recovery Milestone Plan

**Current packaged baseline:** `0.1.672`  
**Current development lane:** `0.1.674-dev` base-state recovery and unification  
**Authoritative branch:** `main`  
**Engineering authority:** `docs/STANDARDS_AND_PRACTICES.md`  
**Temporary work-order authority:** `RECOVERY_REPAIR_SEQUENCE.md`  
**Canonical development history:** `docs/DEVELOPMENT_HISTORY.md`  
**Current architecture map:** `docs/RECOVERY_AUTHORITY_MAP_CURRENT.md`  
**Updated:** 2026-07-17

## Current Project Truth

The source contains broad movement, construction, production, logistics, repair, combat-repair, fluid-network, energy, artillery, rocket-silo, roboport, defensive-support, lifecycle, migration, and diagnostic systems. That breadth makes the project a serious integration candidate, but not a verified release candidate.

The protected source metadata remains `0.1.672`. Runtime recovery modules may identify themselves as `0.1.674-dev`, and an unpackaged `0.1.673` copy exists only to trigger migration testing.

A published `v0.1.674-rc.3` experimental prerelease and committed `tech-priests_0.1.674.zip` artifact also exist. Their manifest and publication receipt record `runtime_validation_complete=false` and require clean-world manual validation. The experimental prerelease is not a verified release candidate under the current recovery gates.

Publication, packaging, static validation, runtime validation, behavioral validation, and verified release status are separate evidence states. No accepted Factorio runtime evidence has yet been recorded.

## Recovery Purpose

Ordinary feature expansion is paused. The project must recover one understandable, physically honest, bounded, and evidenced runtime model from generated legacy fragments, modern shared authorities, dispatcher wrappers, and chronological hardeners.

Recovery completion requires truthful order acceptance, atomic accounting or explicit custody, one owner per action family, one physical leaf target, deterministic cleanup, owner-keyed runtime registration, fail-closed installation, bounded UPS cost, serializable state, objective migration evidence, and one release doctrine.

## Completed Recovery Foundation

### Governance and architecture truth

`RECOVERY_REPAIR_SEQUENCE.md` governs work order. `docs/STANDARDS_AND_PRACTICES.md` governs engineering safety. `docs/DEVELOPMENT_HISTORY.md` remains the canonical completed-work record.

`README.md`, both standards documents, `CURRENT_TESTING_GOALS.md`, `AUTHORITY_REFACTOR_CONTINUITY.md`, the governance checker, and source validation are connected to recovery.

The historical `BEHAVIOR_MERMAID_*` series remains detailed evidence for the 0659–0675 stack. `docs/RECOVERY_AUTHORITY_MAP_CURRENT.md` connects it to 0680–0739 specialized/lifecycle authorities, current Void movement, and Stage 1.

### Void movement

Stage 1 records request identity and priority, stops inherited commands, scales expiry, centralizes terminal cleanup, returns truthful broker state, and removes ground-leash ownership while retaining corridor authorization. Collision recovery, proxy synchronization, elapsed-time stepping, fairness, serialization, and executor recovery remain open.

### Emergency-production transaction integrity

`emergency_production_executor_0514.lua` now requires strict ingredient metadata, plans all removals before mutation, rolls back partial removal, persists rollback shortfalls and completed outputs in custody, excludes assembling-machine input from output collection, deposits through atomic storage, and hands completion to the canonical queue.

### Order-queue truth

`order_queue_0469.lua` now rejects full queues truthfully, uses target-aware keys, refreshes duplicate metadata, prevents lossy preemption, fails invalid targets, promotes immediately after terminal states, separates initial caller-owned activation from promoted callbacks, uses a fair cursor, and reports truthful broker activity.

These are source implementations. Factorio runtime behavior remains unproven.

## Specialized Families

Machine logistics, storage roles, item-family logistics, and energy logistics use exact physical source removal, persistent custody, destination revalidation, exact insertion, and leftover return. Fluid systems keep Factorio fluid simulation authoritative and prohibit synthetic fluid custody.

They still require live evidence for unusual inventories, modded machines, Space Age APIs, overlapping stations, interruption, and save/load.

## Open Critical Recovery Work

### Remaining Stage 1

1. Consecration claim, refund, timer, movement, and queue integrity.
2. Direct-acquisition deposit, target, clamp, and station-craft handoff integrity.
3. Focused transaction and full-queue scenarios.

### Stage 2 shared runtime spine

1. Owner-keyed event registrations with safe filters and real final-order semantics.
2. Owner-specific removal and failure isolation.
3. Phased fail-closed hardener installation.
4. Structured broker result contracts.

### Stage 3 behavioral authority

1. Pure read-only action classification.
2. One scheduler mutation authority.
3. One canonical action record.
4. Legacy fields as generated compatibility mirrors.
5. Family-by-family demotion of parallel controllers and redundant wrappers.

### Stage 4 performance

Regenerate UPS inventories, remove redundant routes, prefer event-fed queues over broad scans, require fair cursors, reduce diagnostic self-cost, and record profiler evidence.

### Stage 5 runtime evidence

Run clean new-save, real `0.1.672` migration, configuration-change, save/reload, transaction, queue-full, destruction, storage-full, combat interruption, overlapping station, fluid, specialized family, movement-truth, high-count, and profiler scenarios.

### Stage 6 artifact doctrine

Artifact classes are protected baseline, migration-test copy, experimental prerelease, runtime-test candidate, behavioral candidate, verified release candidate, and verified release. `v0.1.674-rc.3` remains an experimental prerelease because its own evidence records incomplete runtime validation.

## Gate Ledger — Required Order

### Gate 1: governance and build prerequisites

- [x] Standards and canonical history.
- [x] Recovery authority and connected documentation.
- [x] Current recovery Mermaid map.
- [x] Experimental RC3 truth reconciled.
- [ ] Successful recovery-aware source-validation run recorded by exact SHA.

### Gate 2: source integration and recovery repairs

- [x] Emergency-production transaction source repair.
- [x] Order-queue truth source repair.
- [ ] Consecration integrity.
- [ ] Direct-acquisition integrity.
- [ ] Event-registry, installation, and broker spine.
- [ ] Canonical action authority.

### Gate 3: objective static validation

- [x] Lua, JSON, Python, governance, inventory, integration, lifecycle, migration, and recovery checks defined.
- [ ] Successful full workflow result recorded.
- [ ] Every reported failure resolved.

### Gate 4: Factorio load and migration validation

- [ ] New-save and real `0.1.672` upgrade with valid pairs.
- [ ] Configuration-change, save, and reload.
- [ ] Separate unedited logs accepted by the evidence validator.

### Gate 5: behavioral and performance integration

- [ ] Stage 1 transaction and scheduler matrix.
- [ ] Every custody family under interruption and save/load.
- [ ] Specialized entity and fluid boundaries.
- [ ] Overlapping stations and movement truth.
- [ ] Clean-world profiler and high-count evidence.

### Gate 6: verified release-candidate packaging

Blocked until Gates 1 through 5 pass. The protected source version remains `0.1.672`; experimental publication does not authorize a source bump or verified release-candidate status.

## Immediate Sequential Work

1. Record a successful recovery-aware source-validation run.
2. Repair consecration.
3. Repair direct acquisition.
4. Repair the shared runtime spine.
5. Consolidate authority and reduce measured runtime pressure.
6. Execute runtime, migration, behavioral, and performance evidence.
7. Enforce the final artifact doctrine.
