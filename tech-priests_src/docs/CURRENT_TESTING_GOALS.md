# Current Testing Goals

## Base-State Recovery — Integration, migration, and behavioral release gates

**Packaged baseline:** `0.1.672`  
**Development candidate:** `0.1.674-dev` on `main`  
**Top-level work order:** `../../RECOVERY_REPAIR_SEQUENCE.md`  
**Current recovery stage:** Stage 1 — physical-state and scheduler integrity

This candidate is not release-ready. Ordinary feature expansion is paused. The published `v0.1.674-rc.3` remains an experimental prerelease with runtime validation incomplete.

## Recovery Directive

Read, in order:

1. `../../RECOVERY_REPAIR_SEQUENCE.md`
2. `../../docs/STANDARDS_AND_PRACTICES.md`
3. `STANDARDS_AND_PRACTICES.md`
4. `AUTHORITY_REFACTOR_CONTINUITY.md`
5. `../../docs/RECOVERY_AUTHORITY_MAP_CURRENT.md`
6. `../../docs/DEVELOPMENT_HISTORY.md`

The recovery sequence governs work order. The standards govern safety and evidence. This file is the active live-test target.

### Active Stage 0 target

Source-side Stage 0 is substantially implemented:

- governing documents acknowledge the committed and published experimental `0.1.674` artifacts;
- the current Mermaid map connects the older 0659–0675 maps to later specialized/lifecycle authorities and current recovery work;
- governance verifies protected source version, archive digest, release manifest, publication receipt, recovery map, and CI wiring;
- source validation includes `check_recovery_architecture_0744.py`.

Still open:

- obtain and record one successful full source-validation workflow result for an exact current `main` SHA;
- rerun the source-wide UPS inventory after further authority consolidation;
- retain honest distinction between local grammar parsing, Lua 5.2 compilation, and Factorio runtime loading.

### Active Stage 1 source repairs

Completed in source:

1. **Emergency-production transaction integrity** — strict recipe metadata, planned exact removal, rollback, output/refund custody, output-only facility collection, atomic storage, canonical terminal handoff.
2. **Order-queue truthful acceptance** — truthful queue-full rejection, target-aware identity, duplicate refresh, lossless preemption, invalid-target failure, immediate promotion, fair cursor, truthful broker result.
3. **Consecration lifecycle integrity** — claim release by stored key, pre-selection cooldown, strict movement result, timer reset, verified scheduler admission, exact refund custody, canonical terminal cleanup.

Next source target:

4. Direct-acquisition deposit, target, clamp, and station-craft handoff integrity.

Do not begin an unrelated feature between these slices.

### Gate 1 — Governance checkpoint

- Keep all work on `main`.
- Update this file, `../../docs/DEVELOPMENT_HISTORY.md`, and `../../docs/RECOVERY_AUTHORITY_MAP_CURRENT.md` for every repair slice.
- Do not create another standalone audit/history document.
- Do not classify source implementation as runtime evidence.

Current checkpoint: governance and recovery connections exist; objective workflow confirmation remains pending.

### Gate 2 — Source installation and static validation

- Parse every Lua source file with Lua 5.2.
- Validate `info.json` and release/governance JSON.
- Compile every Python tool.
- Run governance, recovery architecture, inventory safety, development integration, migration lifecycle, and evidence self-tests.
- Confirm every required installation succeeds and affected families fail closed rather than running partially hardened.
- Confirm broker services replace by stable name.
- Confirm event routes become owner-keyed, deterministic, and owner-removable.
- Audit persistent storage for functions, cycles, unsupported userdata, or non-serializable module graphs.
- Record the exact successful workflow SHA.

No successful workflow result has yet been recorded for the current recovery head.

### Gate 3 — Factorio load and migration validation

1. Load the exact development source in a new Factorio 2.0 game.
2. Place real Cogitator/priest pairs and allow all installation and lifecycle handlers to complete.
3. Confirm no Lua, API, module, installation, duplicate-owner, or degraded-family error.
4. Save, exit, and reload.
5. Upgrade a disposable copy of a real `0.1.672` save.
6. Confirm configuration-change installation does not duplicate services, event routes, wrappers, claims, tasks, orders, or custody.
7. Save and reload the migrated game.
8. Capture separate unedited logs and automatic pair dumps.
9. Validate through `../../tools/check_migration_runtime_evidence_0737.py`.

Every error or incomplete critical installation is release-blocking.

### Gate 4 — Stage 1 physical-state and scheduler scenarios

#### Emergency production

- complete strict ingredients;
- missing ingredient before mutation;
- forced partial removal and complete rollback;
- rollback storage blocked and persistent custody;
- output storage blocked and persistent custody;
- partial/anomalous atomic insertion;
- facility output collection without harvesting input inventory;
- target facility destruction;
- save/load during refund and output custody;
- exact queue completion and next-order promotion.

#### Order queue

- full pending queue rejection;
- preemption while pending is full;
- identical item at distinct physical targets;
- duplicate refresh of target, count, source, callback, and timeout;
- initial callback executes once;
- promoted callback executes once;
- callback rejection fails and continues promotion;
- invalid target fails rather than completes;
- cancellation and immediate promotion;
- fair service with more pairs than one budget;
- save/load with current and pending orders.

#### Consecration

- pair cooldown before target selection leaves no claim;
- target destroyed during walk or rite releases stored-key claim;
- movement authority unavailable or rejecting request is terminal;
- item changes and target changes reset rite timers;
- consumption failure releases claim and clears timers;
- application failure refunds exactly once;
- full storage creates persistent refund custody;
- refund custody survives save/load and blocks unrelated completion;
- queue rejection is reported rather than treated as assigned;
- queued consecration promotes and activates exactly once;
- successful rite releases claim, clears target/timers, and promotes next order.

#### Direct acquisition

- target identity and physical validity;
- movement-lock agreement;
- work-clamp release;
- exact safe deposit;
- invalid metadata failure;
- station-craft handoff;
- return-to-station failure;
- save/load during active extraction and deposit.

For every scenario, prove that no item, claim, reservation, or accepted order is silently lost, duplicated, invented, or stranded.

### Gate 5 — Behavioral integration matrix

After Stage 1 scenarios pass, exercise machine, item-family, energy, silo, artillery, roboport, fluid, fluid-turret, construction, repair, combat-repair, ordinary movement, Void movement, overlapping station, combat interruption, and every custody-bearing save/load path.

Movement target, canonical action, active leaf, status text, and visible intent must agree.

### Gate 6 — Performance consolidation

- Rerun `../../tools/audit_ups_hotspots_0743.py` after authority consolidation.
- Compare periodic routes, broad scans, direct commands, and mode/target rewrites with the previous audit.
- Run `../../docs/UPS_VALIDATION_RUNBOOK_0742.md`.
- Confirm fair broker budgets, cheap idle state, and non-dominant diagnostics.
- Remove redundant legacy routes rather than merely suppressing their results.

### Gate 7 — Release packaging

Only after every earlier gate passes:

1. classify the artifact honestly;
2. update source version only when qualified;
3. record exact workflow, Factorio, migration, behavior, performance, and artifact evidence;
4. package through the canonical packager;
5. inspect identity, root, metadata, locale, required files, digest, and ZIP integrity;
6. load-test the exact packaged archive in both new-save and migration scenarios.
