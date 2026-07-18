# Current Testing Goals

## Base-State Recovery — Integration, migration, and behavioral release gates

**Packaged baseline:** `0.1.672`  
**Development candidate:** `0.1.674-dev` on `main`  
**Top-level work order:** `../../RECOVERY_REPAIR_SEQUENCE.md`  
**Current recovery stage:** Stage 0 — repository, artifact, map, and installation truth

This candidate is not release-ready. Ordinary feature expansion is paused. Do not update `info.json`, describe an experimental package as a release candidate, or describe the milestone as complete until the recovery stages and release gates have objective evidence.

## Recovery Directive

Read these documents before runtime work:

1. `../../RECOVERY_REPAIR_SEQUENCE.md` — temporary repair order and stage gates.
2. `../../docs/STANDARDS_AND_PRACTICES.md` — authoritative repository governance and safety requirements.
3. `STANDARDS_AND_PRACTICES.md` — packaged-source build and runtime-development rules.
4. `AUTHORITY_REFACTOR_CONTINUITY.md` — runtime ownership boundaries.
5. `../../docs/DEVELOPMENT_HISTORY.md` — canonical completed-work and evidence record.

The recovery sequence governs what work happens next. The standards govern how safely it must be done. This file contains the currently active test target and must move forward only when the previous target has evidence.

### Active Stage 0 target

- Reconcile governing documents with committed and published experimental `0.1.674` artifacts.
- Run the full source-validation workflow against the exact current `main` head and record its SHA and result.
- Regenerate the whole-source UPS and authority inventories against current source.
- Update Mermaid coverage for the later 0680–0739 authority layer and current Void movement work.
- Confirm the recovery sequence is discoverable from repository and packaged developer guidance.

### Next code targets after Stage 0

1. Emergency-production transaction integrity.
2. Order-queue truthful acceptance and terminal lifecycle.
3. Consecration claim, refund, timer, movement, and queue integrity.
4. Direct-acquisition deposit, target, clamp, and station-craft handoff integrity.

Do not begin an unrelated feature between these slices.

### Gate 1 — Governance checkpoint

- Read both standards documents and the recovery sequence before any release build.
- Read `AUTHORITY_REFACTOR_CONTINUITY.md` before changing runtime behavior.
- Keep this file as the single active live-test target.
- Append verified work to `../../docs/DEVELOPMENT_HISTORY.md`; do not create another standalone pass-history or audit document.
- Keep all GitHub development on the single `main` branch.
- Confirm governance validation requires the recovery authority and its documentation connections.

Current checkpoint: the explicit recovery exception and top-level sequence exist. Objective source-validation confirmation for the connected documentation state is still required.

### Gate 2 — Source installation and static validation

- Confirm every required hardener module loads and its `install()` function does not return `false` or raise an error.
- Confirm the outer loader does not continue an affected feature family in a half-installed state.
- Confirm runtime broker services replace existing registrations by service name rather than accumulating duplicate pulses after configuration changes.
- Confirm event-registry handlers are owner-keyed, ordered deterministically, and cannot clear unrelated owners.
- Audit persistent storage for functions, cyclic tables, unsupported userdata, live module graphs, or save-breaking values.
- Parse every Lua source file with Lua 5.2.
- Validate `tech-priests_src/info.json` as JSON.
- Compile every Python tool under `tools/`.
- Run governance, inventory safety, integration graph, migration lifecycle, and focused recovery checks.
- Record a successful GitHub Actions source-validation run and its exact commit SHA.

No successful workflow result has yet been recorded for the recovery documentation head.

### Gate 3 — Factorio load and migration validation

Run all tests with the required dependencies installed.

1. Load the development source in a new Factorio 2.0 game.
2. Place each Cogitator tier needed to exercise the runtime families and allow installation/configuration handlers to finish.
3. Confirm there are no Lua load errors, Factorio API errors, missing module errors, failed hardener-install messages, duplicate owners, or degraded families without visible diagnostics.
4. Save, exit, reload, and confirm all Tech-Priest storage remains serializable.
5. Load an existing `0.1.672` save with the development source.
6. Confirm configuration-change installation succeeds without duplicating broker services, event routes, diagnostics wrappers, reservations, pair state, active tasks, orders, or custody ledgers.
7. Save and reload the migrated game again.
8. Capture `factorio-current.log` and automatic pair dumps from both new-save and migrated-save passes.
9. Validate the logs through `../../tools/check_migration_runtime_evidence_0737.py`.

Every load-time error, serialization error, duplicated service or route, corrupted pair, or incomplete critical installation is release-blocking.

### Gate 4 — Stage 1 physical-state and scheduler scenarios

Before broad family testing, run the recovery-critical scenarios:

- emergency production with complete ingredients, missing ingredients, partial removals, blocked output, partial output insertion, facility destruction, and save/load;
- a full order queue, preemption at capacity, duplicate items at distinct targets, callback rejection, invalid targets, cancellation, immediate promotion, and save/load;
- consecration target loss, supply loss, claim release, refund under full storage, stale timer prevention, movement rejection, and queue handoff;
- direct acquisition target identity, movement lock agreement, work-clamp release, safe deposit, explicit invalid metadata failure, station-craft handoff, and return-to-station failure.

For every scenario, prove that no item or accepted order is silently lost, duplicated, invented, or stranded.

### Gate 5 — Behavioral integration matrix

Exercise each family independently and then under overlap, interruption, and save/load pressure:

- machine input delivery, output evacuation, trash evacuation, partial insertion, source destruction, destination destruction, and storage-full return;
- ammunition, modules, fuel, burnt results, and incompatible item rejection;
- manual energy service and external automation exclusion;
- rocket-silo ingredient service, trash evacuation, launch interruption, and strict payload/launch-state non-mutation;
- fixed artillery refill and stationary manual artillery-wagon refill, including movement or automatic-mode interruption;
- roboport repair-pack service without construction-robot or logistic-robot population mutation;
- input-fluid and output-fluid network planning, contamination rejection, blocked routes, compatible-network adoption, pipe shortage, and save/load during construction;
- fluid-turret source selection, exact port identity, final-tile connection, route retry limits, and unusual modded fluidbox layouts;
- overlapping Cogitator ranges, simultaneous route proposals, reservation conflicts, and station stock ownership;
- combat interruption during every custody-bearing task;
- Void movement short, long, obstructed, competing-owner, high-count, proxy-sync, authorization-corridor, and save/load scenarios;
- save/load during every active task family;
- agreement between canonical action, movement target, active leaf task, status text, and visible intent line.

For every scenario, verify that physical source removal precedes custody, custody persists until delivery or return, destination inventories are revalidated immediately before insertion, leftovers are never deleted or duplicated, and one executor owns the active family.

### Gate 6 — Performance consolidation

- Rerun `../../tools/audit_ups_hotspots_0743.py` after authority consolidation.
- Compare periodic routes, frequent routes, broad scans, direct commands, and task/mode/target rewrite sites against the previous audit.
- Run the clean-world profiler scenarios in `../../docs/UPS_VALIDATION_RUNBOOK_0742.md`.
- Confirm clean idle behavior sleeps cheaply.
- Confirm active categories remain within broker budgets and use fairness cursors.
- Confirm diagnostics do not become a dominant recurring cost.
- Confirm no redundant legacy route or broad scan remains merely because a hardener suppresses its result later.

### Gate 7 — Release packaging

Only after the recovery stages and earlier gates pass:

1. Classify the artifact honestly under `../../RECOVERY_REPAIR_SEQUENCE.md`.
2. Update `info.json` only when the artifact qualifies for the declared class.
3. Update changelog and description with verified behavior only.
4. Append the verified milestone, workflow run, tested Factorio version, migration evidence, behavioral evidence, and artifact class to `../../docs/DEVELOPMENT_HISTORY.md`.
5. Run `python ../../tools/package_local.py --overwrite` from the appropriate project root.
6. Inspect the archive root, output filename, `info.json`, locale uniqueness, required files, and ZIP integrity.
7. Install the packaged archive rather than the source folder and perform one final clean new-save load plus one final `0.1.672` migration load.

The release gate passes only when the exact packaged archive reproduces the verified source behavior and no unresolved error is being carried forward as a documentation note.