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

Source implementation is present for governance, history, testing, recovery order, current authority map, release classification, evidence wiring, archived release workflows, and source validation. The current declarative graph contains **26 active hardeners and 47 retired source-only authorities**. `0495` is inert; `0499` owns broker-budgeted pair identity and missing-priest observation without authorizing replacement. `0500` is inert; canonical lifecycle functions fail closed unless `0499` authorizes real station cleanup. `0501` is inert; `0513` validates physical targets and outputs while `0490` has no lifecycle recovery or timer. `0506` and `0508` are inert; neither can wrap recovery globals, mutate movement, or register a cadence. `0503` is broker-only and can recover only an observed missing priest through a one-shot `0499` lease and the canonical generated respawn. `0498` is inert; the canonical order queue pauses work while the priest is missing and resumes it only after `0499` confirms recovery. `0505` is inert; `0514` owns facility-first production, visible timed fallback, movement, strict transactions, custody, and completion while `0513` owns direct-target truth and `0499`/`0503` own recovery. `0426` is inert; `0499` owns priest-death and re-imprint observation, generated `0298` is presentation-only, and `0503` cannot recover until the re-imprint deadline. `0363` is inert; `0362` owns ledger state, canonical creation and recovery refresh it directly, and lifecycle, migration, and inventory repair remain with their existing owners. Complete Source validation passed for exact SHA `511254d59e76980706921c0a518c7b7f9440d214` in workflow run `29875375384` on 2026-07-20. This is accepted static source evidence, not Factorio runtime proof.

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
- observer-only corridor authorization and waypoint proposals in `authority_corridor_pathing_0574`, consumed by the sole movement controller before request mutation;
- physical ground transit with low-priority path-command budgeting inside `movement_controller`; unseen teleport `0572` and global wrapper budget `0577` are retired;
- native visible route chunking and retired-state cleanup in `movement_controller`, broker-only `0631`, inert `0632`/`0633`, and explicit `0634`–`0643` repair loaders;
- retired `priest_vanish_guard_0502` station-side acquisition/movement quarantine and broker-only passive `behavior_stack_cleanup_0509`;
- wrapper-free standard fluid route coordination in `fluid_connection_planner_0691`, with physical pipe work delegated through identified construction requests;
- corrected read-only fluid-turret readiness in `0716`, exact safe proposals in `0717`, and wrapper-free route planning in `0719`.

The standard-fluid wrappers `0694`, `0697`, `0692`, `0696`, `0699`, and `0700` are retired. The fluid-turret wrappers `0731`, `0718`, and `0730` are retired. Roboport readiness/logistics service existing roboports only; roboport placement effectiveness remains a construction responsibility.

### Stage 4 — Static performance protection

`audit_ups_hotspots_0743.py` compares the current authority surface against the frozen pre-recovery baseline. Source validation fails if tracked route, scan, command, or shared-state-write counts regress. Static counts do not replace Factorio profiler evidence.

### Post-cleanup authority inventory — 2026-07-23

A read-only inventory at exact SHA `de8630c5307348f812c06edcd08cf85700731244` scanned **306 Lua files** and found **171 unique command registrations** with no duplicate names: **38** in generated fragments, **126** in core modules, and **7** elsewhere. It also found **109 direct `script.on_*` routes**: 70 `on_nth_tick`, 37 `on_event`, one `on_init`, and one `on_configuration_changed`. None of the commands retired by milestones 0779–0790 reappeared.

This closes the 0779–0790 cleanup tranche but does not close the broader recovery cleanup. The next bounded source audit begins with the 38 generated command registrations—especially fragments 015–020—and classification of direct event/timer routes as canonical registry installation, authorized bootstrap, or obsolete fallback. Gate 2 runtime evidence remains blocked until that source classification and any required consolidation are complete.

## Gate 1 — Full source validation

**Status: passed.** Exact SHA `511254d59e76980706921c0a518c7b7f9440d214` completed `.github/workflows/source-validation.yml` successfully in run `29875375384`.

The required result includes:

- Lua 5.2 parsing of every Lua source file;
- JSON validation and Python compilation;
- governance prerequisites and artifact truth;
- recovery architecture contracts;
- static UPS baseline;
- generic inventory safety;
- focused storage, machine, priest-cargo, item, energy, silo, artillery, roboport, construction, standard-fluid, fluid-turret, and movement-cadence, consolidated combat-proxy, combat-command safety, direct-acquisition bounds, and movement-enforcement/Void-backend, corridor-route-planner, movement-economy, ground-route/loader, and retired-0502 lifecycle audits;
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
3. Confirm final hardener phase is `complete` with 26 attempted active hardeners and 47 retired source-only authorities.
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

The accepted cleanup implementation `511254d59e76980706921c0a518c7b7f9440d214` passed complete Source validation in run `29875375384`. Milestones 0779–0790 are closed, but the post-cleanup inventory confirms that broader source recovery remains open. The next source audit begins with generated command surfaces in fragments 015–020 and classification of the remaining direct event/timer routes. No unrelated feature development or Gate 2 evidence collection is authorized until that source tranche is classified and any obsolete ownership is retired.


### Generated command closure — 2026-07-23

Milestones 0792 and 0793 retired all 38 generated-fragment command registrations identified by the post-cleanup inventory. Generated fragments now contain zero command registrations, retain 69 TechPriestsRuntimeEventRegistry routes, and contain zero direct script.on_* routes. The next source cleanup boundary is the remaining direct event/timer inventory outside generated fragments, classified by canonical registry implementation, authorized bootstrap, or obsolete fallback. Gate 2 runtime evidence remains blocked until that route classification is complete.


### Consecration route ownership — 2026-07-23

Milestone 0794 removed six direct consecration event/timer routes. The Machine-Spirit State Ledger now registers opened, closed, and click handlers once through the canonical GUI router and refreshes through one registry-owned 121-tick route. The consecration runtime bridge and mining sensor use registry-owned cadences only and fail closed when the registry is unavailable. The next direct-route tranche must be selected from the remaining non-generated inventory; Factorio runtime evidence remains blocked until direct ownership classification is complete.


### Startup provisioning route ownership — 2026-07-23

Milestone 0795 moved player-created, player-joined, and pending starter-kit service ownership into runtime_event_registry. startup_provisioning now fails closed when canonical routing is unavailable and marks itself installed only after all three routes are accepted. Starter-kit grants, delayed retries, current-player repair scheduling, name awareness, compatibility redirection, and diagnostic commands remain unchanged.


### Acquisition route ownership — 2026-07-23

Milestone 0796 moved the direct-acquisition executor, assigned-idle repair watchdog, and acquisition-unstick watchdog to three fail-closed runtime_event_registry cadences. Each module registers its route before initializing storage, installing wrappers or commands, or publishing installed state. Existing pulse reasons, repair behavior, unstick behavior, and diagnostic commands remain unchanged.


### Stable visual route ownership — 2026-07-24

Milestone 0797 moved the stable Cogitator overlay refresh cadence and its cursor-stack, runtime-setting, and selected-entity refresh events to four fail-closed runtime_event_registry routes. Storage initialization, legacy visual patching, global publication, commands, and installed state now occur only after all four routes are accepted.


### Behavior mutex route ownership — 2026-07-24

Milestone 0798 moved the combat/acquisition behavior mutex to one fail-closed 11-tick runtime_event_registry cadence. Storage, global/module wrappers, commands, exported globals, and installed state now occur only after the cadence is accepted.


### Behavior contracts route ownership — 2026-07-24

Milestone 0799 moved the behavior-contract enforcement service to one fail-closed runtime_event_registry cadence. Storage, movement/beam/diagnostic wrappers, commands, global publication, and installed state now occur only after route acceptance.


### Behavior-tree monitor route ownership — 2026-07-24

Milestone 0800 preserved runtime_tick_broker as the primary behavior-tree monitor owner, retained one named runtime_event_registry cadence as the only fallback, and removed the raw timer fallback. Storage, exported globals, route-owner metadata, and installed state now publish only after one canonical owner accepts the service.


### Bootstrap resource governor route ownership — 2026-07-24

Milestone 0801 moved the disabled-by-default bootstrap reserve service to one fail-closed runtime_event_registry cadence. Storage, command registration, global publication, and installed state now follow route acceptance.


### Construction ghost planner ownership — 2026-07-24

Milestone 0802 preserved runtime_tick_broker as the primary one-ghost planner owner, retained one named runtime_event_registry fallback, and removed the raw timer route. Storage, global publication, route-owner metadata, and installed state now follow ownership acceptance.


### Audio route ownership — 2026-07-24

Milestone 0803 consolidated conversation voice, operational sounds, and placeholder audio under ten named runtime_event_registry routes and removed seven raw event/timer fallbacks. Commands, wrappers, exported globals, and installed state now follow route acceptance.

## Milestone 0804 — GUI and visual ownership consolidation

- Verify Work State opens, closes, and handles clicks only through the canonical GUI router.
- Verify 0474 alone schedules station overlays, known-resource icons, selection refresh, and command-camera refresh.
- Verify station catalog scanning/destruction cleanup remains active without reopening the retired standalone catalog GUI.
- Verify 0476 retains task/writ cadence behavior without a second visual lease scheduler.
- Static source validation is not Factorio runtime proof.

## Milestone 0805 — Frequent route ownership

- Validate station crafting at the Cogitator Station with the single `station-crafting-service` registry cadence.
- Confirm crafting movement fails closed when neither canonical movement request nor routed ground command is available.
- Confirm `overhead_status_governor_0471` is the sole periodic overhead owner and 0473 remains a route-free late compatibility authority.
- Static validation is not Factorio runtime proof.
