# Current Testing Goals

## Base-State Recovery — Stage 5 objective validation

**Packaged baseline:** `0.1.672`  
**Development candidate:** `0.1.674-dev` on `main`  
**Top-level work order:** `../../RECOVERY_REPAIR_SEQUENCE.md`  
**Evidence runbook:** `../../docs/RECOVERY_RUNTIME_EVIDENCE.md`  
**Evidence validator:** `../../tools/check_recovery_runtime_evidence_0747.py`  
**Evidence schema:** `tech-priests-recovery-runtime-evidence-0747-v2`

This candidate is not release-ready. Ordinary feature expansion remains paused. The published `v0.1.674-rc.3` remains an experimental prerelease whose runtime validation is incomplete.

### Machine-output custody versus strict crafting — 2026-10-20

Run `texlua tests/unit/machine_output_acquisition_handoff.lua` (or Lua 5.2).
An active 0528 machine-output return with real item custody must retain
dispatcher classification when an overlapping strict craft is due, for
both explicit crafting and acquisition orders. The target must be the
station. When custody is cleared, strict crafting must resume. An unladen
machine candidate must not preempt a strict craft; combat priority must
remain intact. This focused test does not replace the unchanged 36,000-tick
Factorio ground-rank electronics/science endurance, save/reload, migration,
or UPS gates. Inspect machine custody-return counts and arbitration denials
in the next actual engine log.

### Re-imprint boundary validator reconciliation — 2026-10-20

Run `python3 tools/check_pair_death_reimprint_0426_boundary_0777.py`
and `lua5.2 tests/unit/pair_lifecycle_install.lua`. The static checker
must require the canonical 0499 facade and fail if the legacy 0298
re-imprint helper reappears. The Lua test must confirm that missing,
throwing or non-boolean 0499 responses fail closed without calling
0298. Source validation run `39413419019` failed on the stale
checker contract, not on the sparse-acquisition regression. Re-run
full source validation at the new head; this does not establish
Factorio save/reload or migration acceptance.

### Sparse direct-acquisition field resolution — 2026-10-20

Run `lua5.2 tests/unit/direct_acquisition_physical_guard_regression.lua` and
`lua5.2 tests/unit/machine_output_acquisition_handoff.lua`. A direct task
with its item declared only on the parent must mine exactly one real ore,
deposit exactly one item and clear custody. A child item that conflicts with
the physical resource must fail without extraction. The action classifier
must resolve a leaf target even when the current order has no target, preserve
an explicit order target over the leaf, and use the pair target as a final
fallback. These cases prevent sparse `ipairs` lists from hiding valid work.

These focused regressions do not establish a Factorio runtime pass. Re-run
the unweakened 36,000-tick ground-rank scenario and verify nonzero circuits,
science and completed research, then save/reload and migration. The previous
production failure remains open until accepted engine evidence proves otherwise.

### Headless ground waypoint reliability — 2026-10-20

Run `lua5.2 tests/unit/movement_overleash_return_continuity.lua` and
full `source-validation.yml`. Confirm that a live high-priority
overleash return cannot be stolen after 90 ticks, that ordinary path
commands are not reissued on the fixed 45-tick cadence while the priest
is moving, and that stalled routes retry without losing ownership.
Headless return paths must retain the original authorization reason,
emit a bounded intermediate waypoint and advance segment by segment
until actual final-station arrival. The isolated Lua 5.3 regression
reported **13 PASS scenarios**; GitHub Actions source validation passed
at `a7deefc4` (run `39401200605`).

The machine-logistics terminal now releases its owned priority-740
movement request before surrendering dispatcher ownership. Confirm with
`lua5.2 tests/unit/machine_output_acquisition_handoff.lua`: successful
terminal release must not stop an unrelated direct-acquisition route.
The focused Lua 5.3 suite passed 7 scenarios, and Source Validation
passed at `28ae3463a` (run `39401829390`).
Check `priority_denied` and machine-fulfillment terminal/release counts
in the next engine log; those numbers alone cannot prove circuitry or
science recovery.

**Engine evidence remains separate.** The Factorio ground-rank harness
still requires actual circuits, science and completed research. Run
`39400987217` failed on circuit production despite its greatly
improved priest distances (roughly 5–11 tiles by tick 36000). New
`RETURN_TRACE` fields log each actual intermediate/final target,
`priority_denied`, `stalled_repaths`, `waypoint_advances` and
`overleash_preserved`. Inspect them together with the economy and
machine-logistics traces on the next exact-head run. Do not loosen
endurance assertions or misrepresent source tests as engine proof.

### Consecration shared-reservation ownership — 2026-10-20

Run `lua tests/unit/consecration_queue_reconciliation.lua` from the
repository root using Lua 5.2+ (or an equivalent compatible interpreter).
The ten new cases must demonstrate that disabled/unavailable authorities
reject claims without removing queued work; missing release-key interfaces
fail closed; missing issued identities roll back by the preclaim key;
a claimed shared order retains the stable release key after destruction;
invalid targets cannot enter either the shared executor path or explicit
consecration admission; direct executor renewal aborts on destruction;
queue rejection returns the previously claimed identity; and the generic
repair-family queue cannot dispatch invalidated work.

**Observed focused result, 2026-10-20:** Lua 5.3 (`texlua`), exit 0,
`[consecration-queue-regression] PASS scenarios=38`. The test file
and six required Lua modules were matched byte-for-byte to the GitHub
blob identities at `main` SHA
`ba9d7a744b89f17835ae23ac2a3c1fa9a56d9b60`.
This was an isolated focused test bundle, not full repository-wide
source validation or an engine run.

**Next live acceptance:** Load the same implementation in Factorio,
reproduce two-priest competition, destruction during acquisition,
admission rejection, order cancellation, save/reload, and reservation
expiry without duplicate rites or leaked claims. Also run the full
repository source-validation gate on a final exact HEAD. Record
in-game evidence separately; do not treat mock success as game proof.

### Pair lifecycle installation integrity — 2026-10-18

Run `tests/unit/pair_lifecycle_install.lua` with Lua 5.2+ and confirm that
missing, failing, or incomplete dependency installation does not publish
the lifecycle facade or mark it installed. A later successful retry must
work. An isolated Lua 5.3 reproduction passed; Factorio initialization,
configuration change, and save/reload still require accepted evidence.

### Stage 5 local smoke-tooling reconciliation — 2026-10-06

The local Stage 5 smoke gate is aligned with the current recovery authority: `movement_controller.lua` owns public/ground movement and enforcement, `void_movement_authority_0630.lua` is a broker-only delegated backend, and `movement_enforcement_0566.lua` is inert. `tools/check_stage5_smoke_bundle.py` now uses `check_movement_enforcement_void_boundary_0765.py`, and package readiness holds `info.json` at the protected `0.1.672` baseline. This is source/static validation tooling repair only; no new Factorio runtime, migration, behavioral, profiler, package, or release evidence is claimed.

### Stage 5 isolated smoke staging boundary — 2026-10-07

The smoke checklist now stages an unpacked `tech-priests_0.1.672/` source copy in a new, disposable mods directory and launches Factorio through `--mod-directory`. This replaces the prior manual ZIP instructions, which could bypass the fail-closed canonical packager and confuse smoke evidence with release packaging. The Stage 5 readiness checker also verifies the mod name and Factorio target, while the two focused movement/proximity checkers now resolve source paths independently of the caller's working directory. The smoke bundle must not recommend packaging. These are source/tooling changes; full source validation and Factorio runtime evidence remain outstanding.

### Stage 5 release-evidence binding hardening — 2026-10-09

The release-authorization validator must hash the same canonical `recovery-evidence.json` that the runtime validator reads, refusing alternate or parent-directory manifest paths. The runtime evidence validator must reject non-finite profiler metrics, including nonstandard JSON constants and valid numeric exponents that overflow to infinity. Focused negative self-tests cover both defects. This is validation-tooling implementation only; exact-head source validation, Factorio loading, migration, behavioral, profiler, and packaged-load evidence remain open.

### Stage 5 emergency facility physical-feed accounting — 2026-10-18

Station-to-facility fuel and ingredient feeding must preserve exact physical
counts: preflight destination capacity, remove real station stock, refund
rejected insertion, and retain primitive per-pair custody if the refund fails.
No subsequent feed may remove more station items until custody is restored.

Run `lua tests/unit/emergency_facility_feed_accounting.lua` from the
repository root with Lua 5.2+. Verify full destinations, partial insertion,
blocked refund and recovery, and preflight errors. Then exercise actual
furnace ore/fuel feeding, blocked inventories, and save/reload with pending
custody in Factorio. Mock tests do not replace game-runtime evidence.

This remains a source repair, not accepted Stage 5 Factorio proof.

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

Source implementation is present for governance, history, testing, recovery order, current authority map, release classification, evidence wiring, archived release workflows, and source validation. The current declarative graph contains **26 active hardeners and 48 retired source-only authorities**. `0495` is inert; `0499` owns broker-budgeted pair identity and missing-priest observation without authorizing replacement. `0500` is inert; canonical lifecycle functions fail closed unless `0499` authorizes real station cleanup. `0501` is inert; `0513` validates physical targets and outputs while `0490` has no lifecycle recovery or timer. `0506` and `0508` are inert; neither can wrap recovery globals, mutate movement, or register a cadence. `0503` is broker-only and can recover only an observed missing priest through a one-shot `0499` lease and the canonical generated respawn. `0498` is inert; the canonical order queue pauses work while the priest is missing and resumes it only after `0499` confirms recovery. `0505` is inert; `0514` owns facility-first production, visible timed fallback, movement, strict transactions, custody, and completion while `0513` owns direct-target truth and `0499`/`0503` own recovery. `0426` is inert; `0499` owns priest-death and re-imprint observation, generated `0298` is presentation-only, and `0503` cannot recover until the re-imprint deadline. `0363` is inert; `0362` owns ledger state, canonical creation and recovery refresh it directly, and lifecycle, migration, and inventory repair remain with their existing owners. Complete Source validation passed for exact SHA `511254d59e76980706921c0a518c7b7f9440d214` in workflow run `29875375384` on 2026-07-20. This is accepted static source evidence, not Factorio runtime proof.

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
3. Confirm final hardener phase is `complete` with 26 attempted active hardeners and 48 retired source-only authorities.
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

## Milestone 0806 — Infrastructure route ownership

- Validate master infrastructure survey planning through the runtime tick broker, with the named registry fallback used only when broker registration is unavailable.
- Validate infrastructure-first enforcement through the same broker-first boundary.
- Confirm station-local facility scans are force-scoped and limited to infrastructure-relevant entity types.
- Static validation is not Factorio runtime proof.

## Milestone 0807 — Status-state sanity ownership

- `status_state_sanity_0448` owns one named 31-tick `runtime_event_registry` cadence and has no raw timer fallback.
- Installation fails closed before global or wrapper publication when canonical route ownership is unavailable or rejected.
- The visual-classifier adapter is read-only; stale combat-state mutation remains in the cadence-owned service rather than display classification.
- The service reports structured `processed`, `acted`, `blocked`, `failed`, and `exhausted` truth.
- The focused checker is prepared for canonical Source-validation registration through the GitHub connector.
- Static validation is not Factorio runtime proof.

The next live target is new-save and protected-upgrade evidence that invalid or friendly combat targets are cleared through the canonical cadence, visual classification never mutates pair state, configuration changes do not duplicate the route, and save/reload preserves consistent idle/combat status. The next bounded source tranche audits station supply and inventory stewardship routes before Gate 2 evidence collection proceeds.


## Milestone 0808 — Canonical station inventory stewardship

- `inventory_steward` directly owns persistent remove-before-credit priest cargo custody and the broker service `inventory_steward_0357`.
- `inventory_transfer_integrity_0687` is retired source-only and may not install, patch, register, or mutate runtime state.
- `storage_role_authority_0686` exposes direct storage/stash/source APIs and no longer wraps the steward or filtered-cache module.
- `stone_cache_filter_0534` physically reroutes wrong items through exact storage transactions; no item spill or silent clear remains.
- station supply satisfaction and emergency reserve publish only after canonical route acceptance and retain no raw event/timer fallback.
- The declarative graph remains 26 active hardeners and advances to 48 retired source-only authorities.
- Static validation is not Factorio runtime proof.

The next runtime target must exercise priest-cargo save/reload custody, blocked exact restore, filtered-cache wrong-item recovery, configuration-change route uniqueness, storage-full behavior, and agreement between supply state and physical inventory.

## Milestone 0809 — Runtime invalidation route ownership

- `runtime_config_0626` owns one named `runtime-setting-changed` registry route and publishes its initial snapshot only after route acceptance.
- `station_area_change_invalidator_0634` owns named `build-created`, `removed-destroyed`, and `player-inventory-change` routes with rollback when any route or later initialization step fails.
- Neither module retains a raw `script.on_event` fallback.
- The 26-active / 48-retired authority graph is unchanged.
- Static validation is not Factorio runtime proof.

The next live target is exact-head new-save and protected-upgrade configuration-change evidence: change every debug mode, confirm the broker and registry profiler state switches once, save/reload, and prove no duplicate setting handler exists. The station-area invalidation path must then be exercised by player and robot construction, mining/destruction, cursor and main-inventory changes, storage-full conditions, and configuration-change reloads while proving nearby catalogs and supply conclusions are invalidated exactly once. The next bounded source audit is chatter event/cadence ownership and the remaining direct core event inventory.

## Milestone 0810 — Bootstrap and chatter route ownership

- `bootstrap_runtime.lua` owns named composite routes for explicit consecration capsule use, build, removal, selected-entity refresh, and the 149-tick consecration watchdog.
- `chatter.lua` owns named `background-pulse` and `pending-line-visibility` cadences and publishes only after both routes are accepted.
- The chatter direct-tap wrapper remains inside the final bootstrap selection-chain handler; it does not independently replace the selected-entity event.
- Neither source retains a raw `script.on_event` or `script.on_nth_tick` fallback.
- The 26-active / 48-retired authority graph is unchanged.
- Static validation is not Factorio runtime proof.

The next live target is exact-head new-save and protected-upgrade evidence proving one execution per build, removal, selection, capsule use, and 149-tick watchdog dispatch. Exercise idle and busy chatter cadence, pending typewriter-line visibility, repeated selection changes, save/reload, and configuration-change while confirming the legacy composite chain executes once and no registry route duplicates appear. After this, resume Stage 5 objective validation and audit the remaining economy-housekeeping and direct core event registrations.

## Milestone 0811 — Economy housekeeping route ownership

- Twelve passive economy cadences in 0568, 0569, 0570, 0571, 0575, 0576, 0578, 0579, 0582, 0585, 0593, and 0594 now require named `runtime_event_registry` nth-tick routes instead of falling back to raw `script.on_nth_tick`.
- `efficiency_economy_0576` also requires a named registry route for runtime diagnostic-setting changes and retains no raw `script.on_event` fallback.
- The matching `control.lua` loaders now treat any non-literal-true installer result as a failed family install instead of silently continuing.
- `check_economy_housekeeping_route_ownership_0811.py` protects the route identities, raw-route ban, loader result checks, documentation markers, and the intentionally temporary `0596` early hook.
- `efficiency_economy_0596` is not retired by this tranche. It remains an explicitly temporary compatibility hook until the remaining non-economy direct-route inventory is proven empty or deliberately migrated.
- Static validation is not Factorio runtime proof.

The next bounded source audit is the remaining non-economy direct `script.on_*` inventory. Runtime evidence must also prove each migrated housekeeping cadence executes once, does not duplicate across configuration change or save/reload, and preserves its existing pruning/flush semantics.

## Milestone 0812 — Dormant wake-event route ownership

- `efficiency_economy_0595` now requires canonical `runtime_event_registry` ownership for Tech-Priest build, removal, and research wake events.
- Build, remove, and research routes have stable `wake-build`, `wake-remove`, and `wake-research` identities.
- Partial route acquisition is rolled back before installation fails, and dormant-gate globals/commands publish only after all wake routes are accepted.
- The `control.lua` loader now rejects a non-literal-true 0595 install result.
- `0596` remains the only deliberate raw hook in the efficiency family because it intercepts pre-registry legacy nth-tick registration at the very top of control loading.
- Static validation is not Factorio runtime proof.

The next bounded source audit is now strictly outside the efficiency family: enumerate remaining active raw event/lifecycle registrations and prove whether 0596 can finally be retired.


## Fourth-stage reversal saved-plan guard — 0855 (2026-10-25)

Run `lua5.2 tests/unit/station_recycling_preflight_0822.lua` and source validation; verify missing and non-table predecessor descriptors do not throw or spend protected physical cargo. Four-stage real Factorio 2.0.77 reversal, save/reload and outward rebuilding remain independent acceptance gates.

## Five-station wrong-direction engine topology probe — 0856 (2026-10-25)

The existing headless save/reload runner now requires `PASS REVERSAL_ENGINE_FIVE_STATION_FIXTURE` after the retained ore-return acceptance. Review the raw Factorio log to confirm actual 4→3→2→1→1 links, distinct living priests, empty station-item/manufacturing stock, and a naturally generated ore patch in the opposite direction. The marker explicitly asserts only a CI-created **topology fixture**; 0850 preflight may legitimately be blocked by live duty. The later stage must let the production 0256/0850 owners physically recover all four station items, verify all four depots through an independent save/reload, and reconstruct the ranked chain toward ore. Do not substitute this topology marker for these later gates.

## 0856 corrected five-station hierarchy — preflight acceptance

The former engine fixture marker at b54ed7cf carried `ambiguous-intermediate-subordinates`, so it did not prove a reversal-eligible topology. New geometry uses the live 0480 220-tile direct link rule and requires exactly one child at each higher-rank station and a single peer link between Juniors. The CI fixture now fails if it cannot obtain a valid production 0850 four-stage leaf-first preflight after permitted idle opportunities. Review engine log `REVERSAL_ENGINE_PREFLIGHT_WAIT` for real active-duty blockers; do not cancel legitimate tasks to fabricate success.

## 0857 first real Junior-station depot witness

The CI five-station test now calls production 0256 to issue a real Senior ghost writ, reserving original Magos ownership and using the genuine ore target. It executes existing station-reversal handling and waits for one counted terminal-Junior station item in the 0852 Magos depot and survival of the original priest. A passed topology fixture alone is insufficient: the independent Factorio test must emit `PASS REVERSAL_ENGINE_FIRST_PHYSICAL_DEPOT`. Inspect `REVERSAL_ENGINE_RECOVERY_PHASE` on failure. No test supplies fabricated station items or bypasses live duties.

## 0858 — CI 0820/0256 mission ownership fidelity (2026-10-25)

Require the five-station physical recovery engine fixture to preserve complete 0820 mission identity and bind `pending_expansion_id` to the **real** production 0256 station-expansion record. Assert positive `next_tick`, zero initial segments, original Magos route and target outside root operating radius. The 0820 planner must wait on that very writ rather than autonomously issue an unrelated ghost. Still require actual first-depot item and priest evidence; do not count this fixture wiring as completed material recovery.

## 0859 actual second-Junior physical recovery — Factorio 2.0.77

After proving first recovery, the CI scenario must continue production 0256/0853 to recover Intermediate's direct Junior with another physical mine and return. Assert two distinct engine-owned Magos depots containing exactly one real Junior station item each, both original priests alive, both old station units absent, unchanged expansion ownership and no synthetic item credit. Require `PASS REVERSAL_ENGINE_SECOND_PHYSICAL_DEPOT` as an independent runner acceptance marker. This test does not yet cover Intermediate or Senior dismantling or separate-process four-depot persistence.

## 0860 — CI physical-reversal failure observability

The established four-process Factorio smoke runner now includes `REVERSAL_ENGINE_*` messages in its bounded failure-log evidence output, alongside the existing ore-courier and explicit fatal markers. A first/second physical station-item recovery timeout must surface the last 90 actual reversal state, preflight, writ and inventory markers in the Actions job, not merely a short tail unrelated to the blocked stage. This does not alter game logic or weaken any acceptance marker.

## 0861 — No task churn during physically authorized reversal

Keep the five original participating priests free of **new ordinary 0640 tasks** as long as their own active, structurally coherent 0256/0850 five-station reversal writ remains in authority. Use read-only `0850.future_worker_reserved`; active priorities and in-flight duties are never cancelled or treated as mineable. Test every original participant, a foreign priest, completed-writ release and saved-plan corruption. Instrument 0256's priority-deferral reason. The old `40230982911` real first-depot run failed with `phase=assigned`; do not count a new engine pass until it produces real first and second counted Magos depot markers.

## 0862 — Guard the actual 0640 dispatcher and expose engine arbitration

The source regression must call the real 0640 production planner and see it reject new work for all five original 0850 recovery participants. The Factorio headless five-station fixture now records every 600 ticks the 0248 root priority, Magos/Junior modes, current work and the stage phase. Review these `REVERSAL_ENGINE_RECOVERY_WAIT` lines on first-/second-depot timeouts before modifying any other owner or preempting a priest.
