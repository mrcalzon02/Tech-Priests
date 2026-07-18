# Current Testing Goals

## Base-State Recovery — Objective validation boundary

**Packaged baseline:** `0.1.672`  
**Development candidate:** `0.1.674-dev` on `main`  
**Top-level work order:** `../../RECOVERY_REPAIR_SEQUENCE.md`  
**Current recovery stage:** Stage 5 — external source-validation, Factorio, migration, behavioral, and profiler evidence

This candidate is not release-ready. Ordinary feature expansion remains paused. The published `v0.1.674-rc.3` is an experimental prerelease with runtime validation incomplete.

## Required Reading

1. `../../RECOVERY_REPAIR_SEQUENCE.md`
2. `../../docs/STANDARDS_AND_PRACTICES.md`
3. `STANDARDS_AND_PRACTICES.md`
4. `AUTHORITY_REFACTOR_CONTINUITY.md`
5. `../../docs/RECOVERY_AUTHORITY_MAP_CURRENT.md`
6. `../../docs/DEVELOPMENT_HISTORY.md`

The recovery sequence governs work order. The standards govern safety and evidence. This file is the single active live-test target.

## Source Recovery Status

### Stage 0 — Repository and architecture truth

Source implementation complete:

- artifact and milestone language acknowledges the committed and published experimental `0.1.674` prerelease;
- governance checks protected source version, archive digest, manifest, publication receipt, recovery map, and workflow wiring;
- the current Mermaid map connects the older behavior maps to later specialized/lifecycle systems and the recovered runtime spine;
- source validation includes recovery architecture and static UPS regression checks.

Objective workflow confirmation remains open. GitHub combined status currently exposes no checks for the current recovery head.

### Stage 1 — Physical state and scheduler truth

Source implementation complete:

1. **Emergency-production transaction integrity** — strict recipe metadata, complete removal planning, rollback, output/refund custody, output-only facility collection, atomic storage, canonical completion.
2. **Order-queue truthful acceptance** — queue-full rejection, target-aware identity, duplicate refresh, lossless preemption, invalid-target failure, immediate promotion, order transition, fair servicing.
3. **Consecration lifecycle integrity** — stored-key claim cleanup, pre-selection cooldown, canonical movement truth, rite timer reset, verified admission, exact refund custody, canonical terminal handling.
4. **Direct-acquisition physical custody** — explicit output metadata, exact physical target, completed extraction before mutation, carried custody, real station return, atomic deposit, canonical station-craft transition.

### Stage 2 — Shared runtime spine

Source implementation complete:

- event routes replace by owner/route identity;
- priority is deterministic and `last/final` is real;
- route filters are evaluated locally;
- one owner can be removed without clearing others;
- handler failures are isolated and recorded;
- broker results distinguish processed, acted, blocked, waiting, failed, and exhausted;
- numeric zero and `nil` are not counted as actions;
- service replacement preserves cadence;
- hardeners pre-arm early and finalize after normal loading;
- final installation failures disable affected runtime families and record degraded state.

### Stage 3 — Behavioral authority

Source implementation complete for the recovered core families:

- `action_state_arbiter_0488` is a pure read-only classifier and visual gate;
- `single_dispatcher_0510` owns one fair broker service;
- the dispatcher publishes `canonical_action_0744`;
- direct acquisition, station production, consecration, repair, and combat repair are dispatcher-owned;
- matching parallel legacy execution is gated while owned work is nonterminal;
- later specialized families remain compatibility leaves pending live proof and deliberate family-by-family migration.

### Stage 4 — Static performance protection

Source implementation complete:

- `audit_ups_hotspots_0743.py` compares current route, scan, command, and shared-state-write counts against the frozen pre-recovery baseline;
- source validation fails when a tracked metric regresses;
- this source count does not replace runtime profiler evidence.

## Gate 1 — Full Source Validation

Run the exact current `main` head through `.github/workflows/source-validation.yml` and record:

- exact commit SHA;
- Lua 5.2 parse result for every Lua file;
- Python compilation;
- metadata and governance checks;
- recovery architecture check;
- UPS recovery baseline comparison;
- inventory safety;
- development integration;
- migration lifecycle integration;
- migration evidence validator self-test;
- disposable migration-test builder result.

Every failure must be repaired and rerun. No successful workflow result has yet been recorded for the current recovery head.

## Gate 2 — New-Save and Migration Load

1. Install the exact source or disposable migration-test copy in Factorio 2.0 with required dependencies.
2. Create a clean new save and place real Cogitator/priest pairs.
3. Confirm final hardener phase is `complete`, or identify every deliberately degraded family.
4. Confirm event routes and broker services are unique by owner/name.
5. Save, exit, and reload.
6. Upgrade a disposable copy of a real `0.1.672` save.
7. Confirm configuration-change installation does not duplicate routes, services, wrappers, orders, claims, reservations, custody, or pair links.
8. Save and reload the migrated scenario.
9. Capture separate unedited `factorio-current.log` files and automatic pair dumps.
10. Validate with `../../tools/check_migration_runtime_evidence_0737.py`.

Every Lua/API error, non-serializable state, incomplete critical installation, or corrupted pair is release-blocking.

## Gate 3 — Stage 1 Behavioral Matrix

### Emergency production

- strict ingredient success;
- missing ingredient before mutation;
- forced partial removal and rollback;
- blocked rollback with persistent custody;
- blocked output deposit with persistent custody;
- facility output without input harvesting;
- target destruction;
- save/load during custody;
- exact completion and queue promotion.

### Order queue

- queue-full rejection;
- preemption while full;
- same item at distinct physical targets;
- complete duplicate refresh;
- initial and promoted callbacks each execute once;
- activation rejection fails and continues promotion;
- invalid target fails;
- cancellation and immediate promotion;
- transition from acquisition to production;
- fair servicing beyond one budget;
- save/load with current and pending orders.

### Consecration

- cooldown leaves no claim;
- target destruction releases stored-key claim;
- movement rejection is terminal;
- target/item changes reset timers;
- consumption and application failures release state;
- exact refund occurs once;
- full storage persists refund custody;
- custody survives save/load;
- rejected admission remains rejected;
- queued task promotes once;
- success clears claim/timers and promotes next order.

### Direct acquisition

- explicit output and target identity;
- cross-surface and bounds rejection;
- movement and clamp truth;
- no resource mutation during presentation;
- extraction creates exact custody;
- return-to-station retry retains custody;
- atomic deposit advances gathered count only after success;
- invalid exact-yield metadata fails;
- station-craft transition preserves one order;
- target depletion replans honestly;
- save/load during work, return, and deposit.

## Gate 4 — Runtime Spine and Canonical Action Matrix

- two owners on one Factorio event both execute in deterministic order;
- replacing one owner route does not duplicate it;
- removing one route preserves unrelated owners;
- route-local filters neither hide other handlers nor overfilter the Factorio dispatcher;
- one handler failure is isolated and later handlers still run;
- configuration change preserves exact route and broker counts;
- broker numeric zero, `nil`, waiting, and blocked results do not increment action counts;
- service replacement preserves next due tick;
- one hardener failure disables only its mapped family;
- final hardener summary matches actual enabled families;
- classifier performs no task, queue, movement, mode, or target mutation;
- canonical action, order, executor, movement target, leaf status, overhead text, and visual line agree;
- owned legacy execution is gated only during nonterminal owned work;
- compatibility leaves do not claim dispatcher ownership falsely.

## Gate 5 — Specialized Family Integration

Exercise machine, storage, item-family, energy, rocket-silo, artillery, roboport, fluid, fluid-turret, construction, repair, combat-repair, ordinary movement, Void movement, overlapping stations, combat interruption, and every custody-bearing save/load path.

Specialized families must preserve physical source removal, custody, destination revalidation, leftover return, external automation ownership, and family-specific safety boundaries.

## Gate 6 — Performance Validation

1. Run `../../tools/audit_ups_hotspots_0743.py --check-baseline` and retain the generated JSON/Markdown comparison.
2. Run `../../docs/UPS_VALIDATION_RUNBOOK_0742.md` in a clean world.
3. Capture idle, active, high-count, combat, logistics, fluid-planning, and diagnostic profiler samples.
4. Confirm diagnostics are not a dominant cost.
5. Confirm fair broker progress with more pairs than one service budget.
6. Remove redundant routes rather than merely suppressing results.
7. Record measured improvement and remaining hotspots.

## Gate 7 — Artifact and Packaged-Load Validation

Only after every earlier gate passes:

1. classify the artifact honestly;
2. update source version only when qualification permits;
3. record exact source-validation, Factorio, migration, behavior, performance, and artifact evidence;
4. package through the canonical packager;
5. inspect filename, root, metadata, locale, required files, digest, and ZIP integrity;
6. install the exact archive rather than the source folder;
7. repeat clean new-save and real `0.1.672` migration load tests against the archive;
8. publish only under the artifact class actually proven.
