# Current Testing Goals

## Base-State Recovery — Stage 5 objective validation

**Packaged baseline:** `0.1.672`  
**Development candidate:** `0.1.674-dev` on `main`  
**Top-level work order:** `../../RECOVERY_REPAIR_SEQUENCE.md`  
**Evidence runbook:** `../../docs/RECOVERY_RUNTIME_EVIDENCE.md`  
**Evidence validator:** `../../tools/check_recovery_runtime_evidence_0747.py`  
**Evidence schema:** `tech-priests-recovery-runtime-evidence-0747-v2`

This candidate is not release-ready. Ordinary feature expansion remains paused. The published `v0.1.674-rc.3` remains an experimental prerelease whose runtime validation is incomplete.

## Required reading

1. `../../RECOVERY_REPAIR_SEQUENCE.md`
2. `../../docs/STANDARDS_AND_PRACTICES.md`
3. `STANDARDS_AND_PRACTICES.md`
4. `AUTHORITY_REFACTOR_CONTINUITY.md`
5. `../../docs/RECOVERY_AUTHORITY_MAP_CURRENT.md`
6. `../../docs/RECOVERY_RUNTIME_EVIDENCE.md`
7. `../../docs/DEVELOPMENT_HISTORY.md`

The recovery sequence governs work order. The standards govern safety and evidence. This file is the single active validation target.

## Source recovery status

### Stage 0 — Repository and architecture truth

Source implementation is present for governance, history, testing, recovery order, current authority map, release classification, evidence wiring, archived release workflows, and source validation. The current declarative graph contains **26 active hardeners and 33 retired source-only authorities**. Complete Source validation passed for exact SHA `fdf6039be809a80865e8ea96c551dc0d0797d181` in workflow run `29779229966` on 2026-07-20. This is accepted static source evidence, not Factorio runtime proof.

### Stage 1 — Physical state and scheduler truth

Source implementation is present for:

1. emergency-production planning, rollback, ingredient/output custody, atomic storage, and queue-only completion;
2. truthful queue admission, target identity, duplicate refresh, lossless preemption, promotion, and exactly-once activation;
3. consecration claims, cooldowns, explicit movement, refunds, custody, and terminal cleanup;
4. direct-acquisition target identity, bounds, explicit movement/work acceptance, physical extraction, carried custody, return, deposit, and station-craft transfer.

### Stage 2 — Shared runtime spine

Source implementation is present for owner/route-keyed event registration, deterministic priority, route-local filtering, isolated failures, truthful broker results, broker-before-prearm installation, literal-true hardener installation, and degraded-family quarantine.

### Stage 3 — Behavioral authority

Recovered ownership includes:

- read-only `action_state_arbiter_0488`;
- one fair `single_dispatcher_0510` service;
- `canonical_action_0744` as the selected-action record;
- dispatcher-owned direct acquisition, production, consecration, repair, combat repair, construction, machine logistics, visible item logistics, energy logistics, rocket-silo logistics, artillery logistics, and roboport repair-pack logistics;
- read-only placement effectiveness in `construction_site_planner` and sole physical construction in `construction_planner`;
- canonical read-only standard-fluid machine context, endpoint safety, source/sink discovery, and input/output proposals in `fluid_network_doctrine_0689`;
- canonical movement cadence and long-action leases in `movement_controller.lua`, with broker-only service and the `0518` wrapper retired;
- canonical command territory in `command_hierarchy_0480`, proxy-prime throttling in `movement_controller`, force-combat throttling in `behavior_mutex_0466`, and broker-owned hidden-proxy alignment/sustain in `proxy_turret_alignment`; the `0472` wrapper is retired;
- observer-only friendly-fire predicates in `combat_safety`, consumed by the sole `movement_controller` attack and proxy-prime command wrappers;
- native tier-bounded direct acquisition and active-task overleash return in `direct_acquisition_executor_0513`, with obsolete route/command cleanup in `runtime_command_cleanup_0720` and `0511` retired;
- native ground envelope enforcement and Void-backend delegation in `movement_controller`, with `void_movement_authority_0630` broker-only and `movement_enforcement_0566` retired;
- wrapper-free standard fluid route coordination in `fluid_connection_planner_0691`, with physical pipe work delegated through identified construction requests;
- corrected read-only fluid-turret readiness in `0716`, exact safe proposals in `0717`, and wrapper-free route planning in `0719`.

The standard-fluid wrappers `0694`, `0697`, `0692`, `0696`, `0699`, and `0700` are retired. The fluid-turret wrappers `0731`, `0718`, and `0730` are retired. Roboport readiness/logistics service existing roboports only; roboport placement effectiveness remains a construction responsibility.

### Stage 4 — Static performance protection

`audit_ups_hotspots_0743.py` compares the current authority surface against the frozen pre-recovery baseline. Source validation fails if tracked route, scan, command, or shared-state-write counts regress. Static counts do not replace Factorio profiler evidence.

## Gate 1 — Full source validation

**Status: passed.** Exact SHA `fdf6039be809a80865e8ea96c551dc0d0797d181` completed `.github/workflows/source-validation.yml` successfully in run `29779229966`.

The required result includes:

- Lua 5.2 parsing of every Lua source file;
- JSON validation and Python compilation;
- governance prerequisites and artifact truth;
- recovery architecture contracts;
- static UPS baseline;
- generic inventory safety;
- focused storage, machine, priest-cargo, item, energy, silo, artillery, roboport, construction, standard-fluid, fluid-turret, and movement-cadence, consolidated combat-proxy, combat-command safety, direct-acquisition bounds, and movement-enforcement/Void-backend audits;
- development integration and migration lifecycle integration;
- migration and complete-recovery evidence self-tests;
- recovery evidence wiring;
- archived release-workflow and canonical packaging audits;
- proof that verified release authorization remains blocked;
- disposable migration-test builder verification.

The accepted 40-character SHA and successful run are recorded above. Any later source change creates a new candidate and must pass Source validation again before runtime evidence is accepted for that later SHA.

## Gate 2 — New save, upgrade, and reload

Use Factorio 2.x with every required dependency.

### New-save scenario

1. Install the exact selected source.
2. Start a clean save and place real Cogitator/priest pairs.
3. Confirm final hardener phase is `complete` with 26 attempted active hardeners and 33 retired source-only authorities.
4. Confirm event routes and broker services are unique by owner and name.
5. Exercise construction, specialized logistics, standard fluid routes, and fluid turret routing.
6. Save, close Factorio, restart, and reload.
7. Preserve the unedited `factorio-current.log` and calculate `new_save_log_sha256`.

### Upgrade scenario

1. Make a disposable copy of a real `0.1.672` save.
2. Use `prepare_migration_test_mod.py` only as described by the migration runbook.
3. Load the copied save and verify configuration-change installation.
4. Confirm pairs, queues, reservations, claims, custody, services, routes, and retired wrappers are not duplicated.
5. Confirm old standard-fluid and fluid-turret wrapper state does not reactivate retired modules.
6. Save, close Factorio, restart, and reload.
7. Preserve a separate unedited `factorio-current.log` and calculate `upgrade_log_sha256`.

Any Lua/API error, serialization failure, corrupted pair, incomplete critical installation, duplicated authority, or reactivated retired wrapper remains release-blocking.

## Gate 3 — Stage 1 behavioral matrix

Every retained scenario record must contain the exact source SHA and this exact marker form:

```text
TECH-PRIESTS-RECOVERY-SCENARIO <scenario-id> PASS
```

Each scenario manifest record must include the matching retained-file `log_sha256`.

### Emergency production

Canonical identifiers:

- `emergency-production-success`;
- `emergency-production-partial-rollback`;
- `emergency-production-output-custody`.

Exercise missing ingredients before mutation, forced partial removal, blocked ingredient return, blocked output deposit, deposited output while queue completion is rejected, retry without duplicate output, destruction, save/load during custody, and exact promotion.

### Order queue

Canonical identifiers:

- `order-queue-full-rejection`;
- `order-queue-lossless-preemption`;
- `order-queue-distinct-targets`;
- `order-callback-exactly-once`;
- `order-acquisition-production-transition`.

Exercise cancellation, invalid targets, completed duplicate refresh, activation rejection, fair servicing beyond one budget, and save/load with current and pending orders.

### Consecration

Canonical identifiers:

- `consecration-claim-cleanup`;
- `consecration-refund-custody`;
- `consecration-save-load`.

Exercise movement rejection, target invalidation, pair and target cooldowns, item changes, blocked refunds, successful refund retry, and terminal promotion.

### Direct acquisition

Canonical identifiers:

- `direct-acquisition-physical-custody`;
- `direct-acquisition-return-retry`;
- `direct-acquisition-station-craft-transition`.

Exercise bounds-authority failure, movement rejection, clamp rejection, depletion, destruction, blocked station storage, save/load while carrying output, and exact transfer into `p.emergency_craft`.

## Gate 4 — Shared runtime and canonical-action matrix

Canonical identifiers:

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

The canonical action, order, executor phase, movement request, visible status, custody, and terminal result must agree for every observed pair.

## Gate 5 — Specialized families, construction, fluids, and movement

Canonical identifiers remain:

- `machine-logistics-custody`;
- `storage-full-custody-return`;
- `energy-external-automation`;
- `rocket-silo-launch-interruption`;
- `artillery-manual-stationary-only`;
- `roboport-repair-pack-only`;
- `fluid-contamination-rejection`;
- `standard-fluid-input-route`;
- `standard-fluid-output-route`;
- `fluid-turret-final-port-connection`;
- `combat-interruption-custody`;
- `overlapping-station-reservations`;
- `ordinary-movement-obstruction`;
- `void-movement-short-open`;
- `void-movement-obstruction`;
- `void-movement-high-count-fairness`.

### Construction placement effectiveness

Exercise wall, gate, mine, turret, artillery, radar, and roboport placement effectiveness; full operating-radius perimeter search; threat alignment; duplicate spacing; support, power, coverage, and charging-network usefulness; overlap rejection; exact position/direction revalidation; blocked source removal; movement rejection; combat interruption; target obstruction; ghost revival; failed placement; custody return; and save/reload.

### Standard fluid route

`standard-fluid-input-route` and `standard-fluid-output-route` must prove:

- exact recipe, machine, force, surface, fluidbox, segment, and port identity;
- shared-port collision rejection and ambiguous empty-port rejection;
- compatible source and sink discovery;
- output sink capacity and input capability;
- stale proposal rejection and exact context refresh;
- surface-scoped route reservation and overlapping-station rejection;
- one identified `construction_request` per pipe tile;
- exact pipe-item custody through `construction_planner`;
- obstruction before pickup, after reservation, and before placement;
- endpoint destruction, recipe/filter change, source depletion, sink filling, and contamination;
- competing external construction and fluid-turret routes;
- bounded retry and cooldown;
- save/reload mid-route, mid-construction, and while awaiting final connection;
- final machine readiness transition;
- proof that `0689` and `0691` never wrap construction, move priests, transfer pipe items, create entities, clear construction tasks, or mutate fluid contents;
- proof that retired `0694`, `0697`, `0692`, `0696`, `0699`, and `0700` never install or reactivate.

### Fluid turret route

`fluid-turret-final-port-connection` must cover accepted attack-fluid selection, corrected internal buffer interpretation, contamination, exact source and free-port identity, freshness, safe route search, route conflicts, construction handoff, custody, obstruction, endpoint destruction, retry, save/reload, and final readiness transition. `0719` must remain wrapper-free and physically nonmutating.

### Existing specialized families

Machine, item, energy, silo, artillery, and roboport tests must continue covering exact source removal, family custody, destination revalidation, leftovers, external automation ownership, destruction, interruption, unusual inventories, and save/load.

## Gate 6 — Profiler evidence

Retain at least 30 samples for each profile and scenario:

- `idle-profiler`;
- `active-profiler`;
- `high-count-profiler`.

The manifest must contain exactly `idle`, `active`, and `high-count` profile records. Each must identify a retained profiler JSON file and matching `file_sha256`. The high-count profile requires at least 49 valid pairs. `worst_ms` may not be below `average_ms`.

Measure the mod’s own work separately from Factorio simulation load. Diagnostics must remain nondominant, and the static UPS baseline must pass for the same commit.

## Evidence assembly

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

## Release boundary

No `VERIFIED_RELEASE_AUTHORIZATION.json` may be created until the complete v2 evidence validator accepts one source commit. Protected `0.1.672` metadata must not advance merely because source implementation or an experimental prerelease exists.

After accepted evidence, record the exact SHA and evidence digests, create verified release authorization, advance the version through the qualified transition, build with the canonical packager, load-test the exact archive, and publish only under the artifact class actually proven.

## Stop conditions

Stop and open a repair slice for any Lua/API error, nonserializable state, missing or duplicated authority, incomplete hardener, item loss or duplication, stale claim/reservation/custody/queue/route/request/action state, action/movement/status disagreement, reactivated retired wrapper, starvation, profiler regression, digest mismatch, or mixed source commits.

The movement-cadence consolidation changes the source candidate after the accepted Gate 1 SHA; rerun complete Source validation for the new exact head before attaching Gate 2 evidence. The active runtime objective remains Gate 2: clean new-save and protected `0.1.672` upgrade loads with configuration-change and save/reload evidence for one exact source SHA. The next source audit remains movement and lifecycle reconciliation, beginning with remaining direct command and compatibility-state writers identified by the UPS and authority maps. No unrelated feature development is authorized before those gates advance.
