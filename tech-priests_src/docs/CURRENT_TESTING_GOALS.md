# Current Testing Goals

## Base-State Recovery — Stage 5 objective validation

**Packaged baseline:** `0.1.672`  
**Development candidate:** `0.1.674-dev` on `main`  
**Top-level work order:** `../../RECOVERY_REPAIR_SEQUENCE.md`  
**Evidence runbook:** `../../docs/RECOVERY_RUNTIME_EVIDENCE.md`  
**Evidence validator:** `../../tools/check_recovery_runtime_evidence_0747.py`  
**Evidence schema:** `tech-priests-recovery-runtime-evidence-0747-v2`

This candidate is not release-ready. Ordinary feature expansion remains paused. The published `v0.1.674-rc.3` is an experimental prerelease whose runtime validation is incomplete.

## Required Reading

1. `../../RECOVERY_REPAIR_SEQUENCE.md`
2. `../../docs/STANDARDS_AND_PRACTICES.md`
3. `STANDARDS_AND_PRACTICES.md`
4. `AUTHORITY_REFACTOR_CONTINUITY.md`
5. `../../docs/RECOVERY_AUTHORITY_MAP_CURRENT.md`
6. `../../docs/RECOVERY_RUNTIME_EVIDENCE.md`
7. `../../docs/DEVELOPMENT_HISTORY.md`

The recovery sequence governs work order. The standards govern safety and evidence. This file is the single active validation target.

## Source Recovery Status

### Stage 0 — Repository and architecture truth

Source implementation is complete:

- governance, history, testing, recovery order, current Mermaid map, release classification, and CI wiring are connected;
- the protected source version and experimental RC3 archive, digest, manifest, and publication receipt are checked;
- later specialized and lifecycle layers are connected to the older 0659–0675 maps;
- source validation includes recovery architecture, evidence wiring, release blocking, and static UPS regression checks.

A successful complete source-validation result has not yet been recorded for an exact current head.

### Stage 1 — Physical state and scheduler truth

Source implementation is complete:

1. **Emergency-production transaction integrity** — strict recipe metadata, complete ingredient-removal planning, rollback, persistent ingredient/output custody, output-only facility collection, atomic storage, explicit movement acceptance, an `output-deposited` handoff phase, and canonical queue-only completion.
2. **Order-queue truthful acceptance** — queue-full rejection, target-aware identity, duplicate refresh, lossless preemption, invalid-target failure, immediate promotion, exactly-once activation ownership, canonical transitions, obsolete-task clearing, and fair servicing.
3. **Consecration lifecycle integrity** — stored-key claim cleanup, pre-selection cooldown, explicit movement acceptance, rite-timer reset, verified admission, exact refund or persistent refund custody, and canonical terminal handling.
4. **Direct-acquisition physical custody** — explicit output metadata, exact physical target identity, fail-closed bounds, explicit movement and work-clamp acceptance, completed extraction before mutation, persistent carried custody, real station return, atomic deposit, and canonical station-craft task transfer.

### Stage 2 — Shared runtime spine

Source implementation is complete:

- owner/route-keyed event registration;
- deterministic priority with real `first/front` and `last/final` semantics;
- route-local filters and owner-specific removal;
- isolated handler failures;
- structured broker results with truthful action accounting;
- cadence preservation during service replacement;
- early hardener prearm and final post-loader verification;
- degraded-family quarantine when required integrity layers fail.

### Stage 3 — Behavioral authority

Source implementation is complete for the recovered core families:

- `action_state_arbiter_0488` is read-only;
- `single_dispatcher_0510` owns one fair broker service;
- `canonical_action_0744` records owner, family, phase, status, target, order, and timestamps;
- direct acquisition, emergency production, consecration, repair, and combat repair are dispatcher-owned;
- matching parallel legacy behavior is gated while owned work is nonterminal.

Later specialized families remain compatibility leaves pending deliberate live validation.

### Stage 4 — Performance consolidation and static protection

Source implementation is complete:

- `audit_ups_hotspots_0743.py` compares the current authority surface against the frozen pre-recovery baseline;
- source validation fails if tracked route, scan, command, or shared-state-write counts regress;
- static counts do not replace Factorio profiler evidence.

## Gate 1 — Full Source Validation

Run the exact current `main` head through `.github/workflows/source-validation.yml`.

The required result includes:

- Lua 5.2 parsing of every Lua source file;
- JSON validation and Python compilation;
- governance prerequisites and artifact truth;
- recovery architecture contracts;
- static UPS baseline;
- inventory safety and development integration;
- migration lifecycle integration and migration evidence self-test;
- complete recovery validator and template self-tests;
- recovery evidence wiring;
- archived release-workflow audit;
- proof that verified release authorization remains blocked;
- disposable migration-test builder verification.

Record the full 40-character commit SHA and successful workflow run. Every failure must be repaired and rerun against a new exact head.

## Gate 2 — New-Save, Upgrade, and Reload

Use Factorio 2.0 with every required dependency.

### New-save scenario

1. Install the exact selected source.
2. Start a clean save and place real Cogitator/priest pairs.
3. Confirm final hardener phase is `complete`.
4. Confirm event routes and broker services are unique by owner and name.
5. Save, close Factorio, restart, and reload.
6. Preserve the unedited `factorio-current.log` and calculate `new_save_log_sha256`.

### Upgrade scenario

1. Make a disposable copy of a real `0.1.672` save.
2. Use `prepare_migration_test_mod.py` only as described by the migration runbook.
3. Load the copied save and verify configuration-change installation.
4. Confirm pairs, queues, reservations, claims, custody, services, routes, and wrappers are not duplicated.
5. Save, close Factorio, restart, and reload.
6. Preserve a separate unedited `factorio-current.log` and calculate `upgrade_log_sha256`.

Any Lua/API error, serialization failure, corrupted pair, incomplete critical hardener installation, or duplicate authority remains release-blocking.

## Gate 3 — Stage 1 Behavioral Matrix

Every retained scenario record must contain the exact source SHA and this exact marker form:

```text
TECH-PRIESTS-RECOVERY-SCENARIO <scenario-id> PASS
```

Each scenario manifest record must include the matching retained-file `log_sha256`.

### Emergency production

Required canonical identifiers:

- `emergency-production-success`;
- `emergency-production-partial-rollback`;
- `emergency-production-output-custody`.

Also exercise missing ingredients before mutation, forced partial removal, blocked ingredient return, blocked output deposit, output deposited while queue completion is rejected, retry without duplicate output, facility output without input harvesting, destruction, save/load during custody, and exact promotion.

### Order queue

Required identifiers:

- `order-queue-full-rejection`;
- `order-queue-lossless-preemption`;
- `order-queue-distinct-targets`;
- `order-callback-exactly-once`;
- `order-acquisition-production-transition`.

Also exercise cancellation, invalid targets, complete duplicate refresh, activation rejection, fair servicing beyond one budget, and save/load with current and pending orders.

### Consecration

Required identifiers:

- `consecration-claim-cleanup`;
- `consecration-refund-custody`;
- `consecration-save-load`.

Also exercise movement rejection, target invalidation, pair and target cooldowns, item changes, blocked refunds, successful refund retry, and terminal promotion.

### Direct-acquisition

Required identifiers:

- `direct-acquisition-physical-custody`;
- `direct-acquisition-return-retry`;
- `direct-acquisition-station-craft-transition`.

Also exercise bounds-authority failure, movement rejection, clamp rejection, depletion, destruction, blocked station storage, save/load while carrying output, and exact task transfer into `p.emergency_craft`.

## Gate 4 — Shared Runtime and Canonical Action Matrix

Required identifiers:

- `hardener-final-complete`;
- `event-owner-order`;
- `event-owner-replacement`;
- `event-owner-removal-isolated`;
- `event-handler-failure-isolated`;
- `broker-zero-not-acted`;
- `broker-waiting-not-acted`;
- `broker-replacement-preserves-cadence`;
- `canonical-action-movement-status-visual-agreement`;
- `broker-high-count-fairness`;
- `diagnostics-nondominant`.

The canonical action, order, executor phase, movement request, visible status, and terminal result must agree for every observed pair.

## Gate 5 — Specialized Families and Movement

Required identifiers:

- `machine-logistics-custody`;
- `storage-full-custody-return`;
- `energy-external-automation`;
- `rocket-silo-launch-interruption`;
- `artillery-manual-stationary-only`;
- `roboport-repair-pack-only`;
- `fluid-contamination-rejection`;
- `fluid-turret-final-port-connection`;
- `combat-interruption-custody`;
- `overlapping-station-reservations`;
- `ordinary-movement-obstruction`;
- `void-movement-short-open`;
- `void-movement-obstruction`;
- `void-movement-high-count-fairness`.

Specialized tests must cover source removal, custody, destination revalidation, leftovers, automation ownership, destruction, interruption, overlapping claims, unusual inventories/fluidboxes, and save/load.

## Gate 6 — Profiler Evidence

Retain at least 30 samples for each profile and scenario:

- `idle-profiler`;
- `active-profiler`;
- `high-count-profiler`.

The manifest must contain exactly `idle`, `active`, and `high-count` profile records. Each must identify a retained profiler JSON file and matching `file_sha256`. The high-count profile requires at least 49 valid pairs. `worst_ms` may not be below `average_ms`.

Measure the mod’s own work separately from Factorio simulation load. Diagnostics must remain nondominant, and the static UPS baseline must pass for the same commit.

## Evidence Assembly

Generate the pending v2 structure:

```bash
python3 tools/create_recovery_evidence_template_0748.py \
  <40-character-source-sha> \
  --output /absolute/path/to/tech-priests-recovery-evidence/recovery-evidence.json
```

Calculate retained-file digests with `sha256sum`, complete every exact scenario record, and run:

```bash
python3 tools/check_recovery_runtime_evidence_0747.py --self-test
python3 tools/create_recovery_evidence_template_0748.py \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  --self-test
python3 tools/check_recovery_evidence_wiring_0749.py
python3 tools/check_recovery_runtime_evidence_0747.py \
  /absolute/path/to/tech-priests-recovery-evidence
```

Do not edit logs to make them pass. Repair source, select a new exact commit, and rerun affected scenarios.

## Release Boundary

No `VERIFIED_RELEASE_AUTHORIZATION.json` may be created until the complete v2 evidence validator accepts one source commit. Protected `0.1.672` metadata must not be advanced merely because source implementation or an experimental prerelease exists.

After accepted evidence:

1. record the evidence directory, digests, and exact SHA in `../../docs/DEVELOPMENT_HISTORY.md`;
2. create the verified release authorization record;
3. advance the version only through the qualified transition;
4. build with the canonical packager;
5. load-test the exact archive with clean new-save and real `0.1.672` upgrade scenarios;
6. publish only under the artifact class actually proven.

## Stop Conditions

Stop and open a repair slice when any of the following occurs:

- Lua or API error;
- nonserializable state;
- missing or duplicated event/service authority;
- incomplete required hardener;
- item loss or duplication;
- stale claim, reservation, custody, queue, or action state;
- action, movement, status, or visual disagreement;
- starvation or unbounded service delay;
- profiler regression;
- digest mismatch or mixed source commits.

The next project action is objective execution of Gate 1, followed by Gate 2. No unrelated feature development is authorized before those gates advance.
