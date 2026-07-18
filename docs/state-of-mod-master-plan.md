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

The source contains broad movement, construction, production, logistics, repair, combat-repair, fluid-network, energy, artillery, rocket-silo, roboport, defensive-support, lifecycle, migration, and diagnostic systems. Recovery Stages 0 through 4 are now source-implemented, but the project remains an unverified integration candidate because objective source-validation and Factorio evidence are absent.

The protected source metadata remains `0.1.672`. Runtime recovery modules identify themselves as `0.1.674-dev`. An unpackaged `0.1.673` copy exists only for migration testing.

A published `v0.1.674-rc.3` experimental prerelease and committed `tech-priests_0.1.674.zip` artifact exist. Their manifest and receipt record `runtime_validation_complete=false`. They are not a verified release candidate or verified release.

Publication, packaging, static validation, runtime loading, migration, behavioral validation, profiler evidence, and verified release status are separate facts. No accepted Factorio runtime evidence has yet been recorded.

## Recovery Objective

Ordinary feature expansion remains paused. Recovery is complete only when the mod demonstrates:

- truthful order acceptance and terminal handoff;
- atomic accounting or explicit persistent custody;
- one canonical action identity, family, target, and owner;
- deterministic movement and failure cleanup;
- owner-keyed event and service registration;
- fail-closed family installation;
- bounded and measured runtime cost;
- serializable save/load state;
- objective new-save and migration evidence;
- one artifact and release doctrine.

## Source-Implemented Recovery

### Stage 0 — Repository, documentation, artifact, and architecture truth

Completed in source:

- `RECOVERY_REPAIR_SEQUENCE.md` governs repair order.
- Standards remain the permanent safety authority.
- README, testing, continuity, current map, governance, history, and CI are connected.
- The current Mermaid map links the older 0659–0675 maps to later specialized/lifecycle systems and the recovered spine.
- Governance verifies the protected source version and experimental RC3 archive, digest, manifest, and receipt.

Still unevidenced: one successful full source-validation run for an exact current SHA.

### Stage 1 — Physical state and scheduler truth

Completed in source:

- **Emergency production:** strict recipe metadata, planned ingredient removal, rollback, output/refund custody, atomic deposit, canonical completion.
- **Order queue:** truthful queue-full rejection, target-aware identity, duplicate refresh, lossless preemption, invalid-target failure, immediate promotion, canonical transition, fair service.
- **Consecration:** stored-key claims, pre-selection cooldown, movement truth, timer cleanup, verified admission, atomic refund or persistent refund custody, canonical terminal handling.
- **Direct acquisition:** explicit output and target identity, completed physical extraction, persistent carried custody, real return travel, atomic deposit, canonical acquisition-to-production transition.

### Stage 2 — Shared runtime spine

Completed in source:

- owner/route-keyed event registrations;
- deterministic priority with real final/last semantics;
- route-local filters and owner-specific removal;
- handler failure isolation;
- structured broker results and truthful action metrics;
- preserved service cadence on replacement;
- early hardener prearm plus final post-loader installation pass;
- degraded-family quarantine when a required hardener still fails.

### Stage 3 — Behavioral authority

Completed in source for the recovered core families:

- `action_state_arbiter_0488` is a pure read-only classifier and presentation gate;
- `single_dispatcher_0510` owns one fair broker service;
- `canonical_action_0744` records action identity, family, owner, phase, status, order, item, target identity, position, source, and timestamps;
- direct acquisition, station production, consecration, repair, and combat repair are dispatcher-owned;
- matching parallel legacy execution is gated during nonterminal owned work;
- later specialized families remain compatibility leaves until live proof permits deliberate migration.

### Stage 4 — Static runtime-pressure protection

Completed in source:

- `audit_ups_hotspots_0743.py` compares current periodic-route, fast-route, risky-scan, direct-command, and pair-state-write counts with the frozen pre-recovery baseline;
- source validation fails when a tracked metric regresses;
- the recovery checker enforces Stages 1 through 4;
- source-count improvement is not represented as profiler evidence.

## Specialized Families Still Requiring Live Proof

Machine logistics, storage roles, item-family logistics, energy, rocket silos, artillery, roboports, input/output fluid planning, fluid turrets, construction, ordinary repair, combat repair, ordinary movement, and Void movement contain substantial source doctrine but require Factorio 2.0 and Space Age evidence.

The later families must prove physical source removal, custody, destination revalidation, leftover return, automation ownership, unusual inventory/fluidbox compatibility, interruption, overlap, and save/load behavior.

Void movement still requires collision recovery, associated-proxy synchronization, elapsed-time stepping, fair high-count service, save/load proof, and executor recovery scenarios.

## Objective Evidence Boundary

Further recovery claims require external execution in this order:

1. successful full source-validation workflow against one exact current SHA;
2. clean new-save Factorio load with real pairs;
3. disposable upgrade from a real `0.1.672` save;
4. configuration-change and save/reload proof;
5. Stage 1 transaction/scheduler scenarios;
6. runtime-spine and canonical-action scenarios;
7. specialized family, movement, overlap, interruption, and custody scenarios;
8. clean-world and high-count profiler evidence;
9. exact packaged-archive repetition of the verified behavior.

GitHub combined status currently exposes no checks for the current recovery head. No CI pass is claimed.

## Gate Ledger

### Gate 1 — Governance and architecture truth

- [x] Standards and canonical history.
- [x] Recovery authority and connected documentation.
- [x] Current recovery Mermaid map.
- [x] Experimental RC3 truth reconciled and checked.
- [ ] Successful recovery-aware source-validation run recorded by exact SHA.

### Gate 2 — Recovery source integration

- [x] Emergency-production transaction integrity.
- [x] Order-queue truth and transition.
- [x] Consecration lifecycle integrity.
- [x] Direct-acquisition physical custody.
- [x] Event-registry ownership.
- [x] Broker result truth.
- [x] Phased fail-closed hardener installation.
- [x] Pure action classification.
- [x] Canonical action dispatcher.
- [x] Static UPS regression gate.

### Gate 3 — Objective static validation

- [x] Lua, JSON, Python, governance, recovery, UPS, inventory, integration, lifecycle, migration, and evidence checks defined.
- [ ] Successful full workflow result recorded.
- [ ] Every reported failure resolved and rerun.

### Gate 4 — Factorio load and migration

- [ ] Clean new save with valid pairs.
- [ ] Real `0.1.672` disposable upgrade.
- [ ] Configuration-change verification.
- [ ] Save and reload both scenarios.
- [ ] Separate unedited logs accepted by the evidence validator.

### Gate 5 — Behavioral and performance integration

- [ ] Stage 1 transaction and scheduler matrix.
- [ ] Event, broker, installation, and canonical-action matrix.
- [ ] Every custody family under interruption and save/load.
- [ ] Specialized entity and fluid boundaries.
- [ ] Overlapping stations and movement truth.
- [ ] Void movement completion.
- [ ] Clean-world and high-count profiler evidence.

### Gate 6 — Verified release-candidate packaging

Blocked until Gates 1 through 5 pass. The protected source version remains `0.1.672`; experimental publication does not authorize a source-version bump or verified release-candidate status.

## Immediate Sequential Work

1. Run the full source-validation workflow on the current recovery head and repair any reported source failure.
2. Run clean new-save and real `0.1.672` migration scenarios.
3. Execute the Stage 1 and runtime-spine matrices.
4. Continue family-by-family authority migration only when live evidence proves the existing custody path.
5. Complete Void movement and runtime profiling.
6. Qualify and load-test an exact packaged artifact.
