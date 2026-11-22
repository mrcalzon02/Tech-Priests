# Development targets — machine sanctity, quality and custom modules

Status: PLANNED / NOT IMPLEMENTATION-VERIFIED. This is a target specification, not evidence of working runtime behavior. Respect the current recovery and validation work order; implement only when the active milestone permits.

## Goals
- Verify whether the custom positive/negative machine-sanctity modules have prototype definitions, actual runtime effects, and Factorio behavioral evidence. Do not assume prior integration succeeded.
- Integrate Factorio machine quality into the existing machine-sanctity authority. Higher-quality assemblers and other sanctity-bearing machines must have higher inherent base sanctity.
- Preserve the existing distinction between inherent base sanctity, current sanctity, module modifiers, ritual/incense modifiers, wear/decay, and malfunctions. Do not introduce a second competing sanctity system.

## Proposed baseline (balance targets; confirm against existing sanctity scale)
| Quality | Base sanctity (0–100 proposed scale) |
| --- | ---: |
| Normal | 50 |
| Uncommon | 60 |
| Rare | 70 |
| Epic | 85 |
| Legendary | 100 |

Values are provisional. Legendary base 100 must not imply immunity from decay or malfunctions; model current sanctity and effective modifiers separately, and define caps and clamping explicitly before implementation.

## Implementation constraints
- Use the existing consecration/sanctity runtime owner and Factorio quality API; avoid duplicate event handlers, parallel state ownership, or per-tick scans of every machine.
- Initialize/reconcile base sanctity on creation, placement, cloning, upgrade/quality change, migration/load, and any other relevant lifecycle transition.
- Recalculate module effects on module inventory change and relevant state change. Define deterministic stacking and handling for positive and negative modifiers.
- Preserve ritual/incense behavior, degradation, and malfunction thresholds. Quality is a better starting foundation, not perpetual protection.
- Validate support for relevant assemblers and other eligible machines, including machines with four module slots, without assuming every entity supports modules.

## Acceptance evidence
1. Source audit identifying exact sanctity authority, module prototypes and handlers, plus any missing wiring.
2. Automated tests for all five quality tiers; zero, positive, negative, and mixed module loadouts; stacking, caps, decay and recovery.
3. Native Factorio tests for placement, quality changes, module insertion/removal, save/reload, migrations, and actual sanctity/malfunction outcomes.
4. Report measured results and failures; attach native screenshots or short captures where useful. Do not label the feature implemented without commit and runtime evidence.
5. Commit on `main` only; report exact commit SHA and read back the committed file.


## Bilateral technology doctrines: Law & Order versus Chaos & Anarchy
**Design authority:** sanctity is not a one-directional good/bad score. Two research routes and corresponding module families must make high-sanctity and low-sanctity machinery viable, with differentiated outputs.

| Dimension | Law & Order (high sanctity) | Chaos & Anarchy (low sanctity) |
| --- | --- | --- |
| Research route | Consecration, precision, efficiency | Degradation tolerance, detritus and salvage |
| Module family | Raise/support effective sanctity; high-sanctity performance | Lower/hold effective sanctity; low-sanctity survival and detritus output |
| Rewards | Efficient, reliable, high-quality production | Continued operation at low sanctity; resource/detritus generation |
| Tradeoff | Requires maintaining sanctity; weak when degraded | Sacrifices pristine efficiency or other clean-production benefits for low-sanctity advantages |

### Design requirements
- Model the two doctrines as explicit technology unlocks and module recipes/effects, not just positive and negative sanctity values.
- Low-sanctity Chaos machinery must have meaningful strengths, not merely reduced penalties; evaluate detritus as an actual defined product/byproduct with mass/resource accounting, rather than free material from nowhere.
- Keep quality-derived **inherent** sanctity distinct from doctrine/module-driven **effective** sanctity; high-quality machines may be deliberately driven toward low effective sanctity.
- Specify stacking, unlock prerequisites, recipes, balancing costs, side effects and compatibility with all eligible machines during implementation. Do not assume mutually exclusive research unless separately authorized.
- Test mono-doctrine and mixed-module configurations across all five quality tiers and sanctity bands, including actual detritus yields, efficiency, malfunction/survival behavior and UPS impact.
- Existing baseline quality numbers are provisional; balance both routes so neither universally dominates.


## Expansion implementation inventory (2026-11-21)

This is an **evaluation and development backlog**, not a claim that the features exist or have passed native tests. Audit actual files and runtime ownership before rewriting. Respect the active recovery sequence and preserve existing working systems.

| ID | System / source anchor | Current evidence | Required action | Acceptance criterion |
| --- | --- | --- | --- | --- |
| S01 | Machine Spirit sanctity authority / consecration runtime | Existing consecration executor, maintenance, overlay and research references | **Review / consolidate** owner, state model, thresholds, decay and events; avoid duplicate systems | One documented authority, no duplicate state writers |
| S02 | Quality integration / `prototypes/compatibility/quality.lua` | Station radius and priest quality hook, not confirmed sanctity integration | **Extend** quality-tier initial sanctity and capacity semantics, entity lifecycle and migration | Five tiers exhibit intended starting values without overriding research |
| S03 | Existing Machine Spirit technologies / `prototypes/technology.lua` | Initial consecration I–II and capacity I–II; maintenance and incense unlocks | **Audit / adjust** unlock dependencies, bonus stacking and progression | Research graph is reachable, no cycles or conflicting caps |
| S04 | Law & Order technology doctrine | Not found in inspected primary technology definitions | **Construct** staged high-sanctity efficiency/precision research | Research unlocks functioning doctrine modules and effects |
| S05 | Chaos & Anarchy technology doctrine | Not found in inspected primary technology definitions | **Construct** staged low-sanctity survival/detritus research | Research unlocks functioning doctrine modules and effects |
| S06 | Custom module prototypes and recipes | No dedicated `prototypes/modules.lua`; other late definitions not exhaustively searched | **Catalog then build/repair** module item prototypes, recipes, icons, limitations and technology unlocks | Native Factorio recognizes every module and recipe |
| S07 | Module runtime modifiers | No validated positive/negative module behavior | **Build/integrate** effective-sanctity adjustments, inventory change invalidation, mixed stacking and caps | Inserting/removing modules changes measured behavior deterministically |
| S08 | Sanctity production effects | No verified doctrine-specific productivity/efficiency calculations | **Design/implement** high-sanctity throughput, energy and quality benefits with Factorio API compatibility | Measured benefits match balance tables and respect engine limitations |
| S09 | Low-sanctity survival | Existing malfunctions/decay not fully traced | **Adjust** chaos tolerance, malfunction thresholds and consequences without immunity | Low-sanctity chaos build remains viable with measurable tradeoffs |
| S10 | Mechanical Detritus economy / `prototypes/item.lua` | Item exists | **Review / scale** generation, recovery and recipe sinks; enforce physical accounting | No free-item duplication; audited yields and consumption |
| S11 | Machine logistics / `scripts/core/logistics_machine_fulfillment_0528.lua` | Explicit detritus transfer into waste box | **Accommodate** doctrine-dependent outputs, overflow and storage handling | No blocked output, lost cargo, or duplicate transfers |
| S12 | Machine eligibility and module slots | Existing machines have differing module capabilities | **Enumerate** eligible assembler, furnace, chemical, reactor and Space Age families; adapt only where supported | Per-machine compatibility matrix and tested slot behavior |
| S13 | UI, overlays and localization / `data.lua` | Per-machine grime/sheen overlays | **Extend** doctrine, base/current/effective sanctity, bonuses, module effects, warnings and localized tech descriptions | Readable accurate feedback with no excessive redraws |
| S14 | Save/load, cloning and migration | Not audited for new fields | **Accommodate** upgrades, replacement, blueprint placement, cloning, removal, load and migration | Stable state with no stale entity keys or lost bonuses |
| S15 | UPS / event and cache ownership | Existing governors and dispatcher infrastructure | **Scale** event-driven invalidation, cached modifiers and bounded work | No global per-tick machine scan; profiler comparison |
| S16 | Balance matrix and combat/economy interaction | Not measured | **Evaluate** all quality tiers × sanctity bands × mono/mixed modules × research stages | Both doctrines viable with explicit tradeoff data |
| S17 | Native Factorio verification and release evidence | Not run for this expansion | **Construct** source tests, real game load, behavioral scenarios, screenshots/captures and regression checks | Exact commits, test outputs and reproducible evidence |
| S18 | Documentation and asset integration | Existing art/tech assets may be reusable | **Review / extend** module icons, technology tree presentation, descriptions and player guidance | All unlocked items have complete assets and discoverable explanations |

### Architecture and design decisions to resolve before implementation
1. **Canonical sanctity equation:** define base (machine quality + researched starting bonus), current condition, researched capacity, effective module/ritual modifiers, and final clamp; ensure legendary quality does not confer immunity.
2. **Research doctrine access:** whether both branches can be researched simultaneously or are mutually exclusive is **undecided**. Do not silently lock one route.
3. **Module tiers:** exact counts, costs, power draw, speed/productivity/quality effects, stack rules, slot compatibility, and whether quality-grade modules alter sanctity effects are **undecided**.
4. **Chaos output:** decide what inputs or wear yield mechanical detritus, where it is physically deposited, and how output scales with sanctity and production activity.
5. **Machine coverage:** create an explicit eligibility matrix before modifying entity prototypes; exclude unsupported entities rather than force module slots.
6. **Research stacking:** initial consecration and capacity technologies must remain meaningful alongside quality; do not use a fixed universal cap of 100.
7. **Runtime ownership:** identify the actual sanctity writer, module inventory signal, production-completion events, and save schema before changes.
8. **Performance:** recompute on actual changes, use bounded queues when needed, and measure UPS against baseline.

### Execution order and evidence gates
- **Phase A — audit:** trace exact source owners, enumerate every relevant prototype/technology/recipe and map current behavior; record confirmed/present/partial/absent/unknown.
- **Phase B — specification:** settle equation, progression, module families, recipe economy and compatibility matrix; preserve user decisions and mark unresolved choices.
- **Phase C — foundation:** implement quality/base/current/effective sanctity in the existing authority with save/migration and unit tests.
- **Phase D — doctrine content:** add both technology routes, module items/recipes, localization and assets.
- **Phase E — behavior:** integrate Order performance and Chaos tolerance/detritus with physical accounting and logistics.
- **Phase F — verification:** run Factorio native scenario matrix, inspect visual evidence and profiler results; report failures separately from release-blocking criteria.

**Scope:** development targets only. No runtime behavior, prototype integration, native game testing, or publication is asserted by this document update.


## Phase A audit — first verified source pass (2026-11-21)
**Evidence scope:** direct reads from `main`; not a full repository search or native Factorio run.

- `prototypes/technology.lua` (628 lines): defines initial-consecration tiers 1/2, capacity tiers 1/2, maintenance litanies and incense; comments describe capacity 100/110/120. **Present as prototypes; runtime application still to trace.**
- `prototypes/compatibility/quality.lua` (9 lines): comments describe station-radius and priest/proxy quality; no sanctity baseline code in this file. **Quality-sanctity behavior not demonstrated.**
- `prototypes/item.lua`: `mechanical-detritus` item defined. **Item present; production formula not established.**
- `scripts/core/logistics_machine_fulfillment_0528.lua`: detritus counted and routed from machine inventory. **Logistics path present; no evidence of Chaos-specific yields.**
- `scripts/core/consecration_executor_0515.lua`: uses record `max_sanctification`, `sanctification`, global `get_base_sanctification_max`, and wraps existing `sanctify_target_with_priest`. **This is a scheduling/execution wrapper, not proof of canonical sanctity-state ownership.**
- `scripts/core/consecration/mining_sensor_0495.lua`: invokes global `apply_completed_sanctification_operation` and overlay refresh. **Potential production-hook integration point, pending ownership audit.**
- `data.lua`: explicitly loads Quality compatibility conditionally and defines machine-specific grime/sheen overlays. **Rendering exists; gameplay effects unverified.**
- `prototypes/modules.lua`: path not found; this does **not** prove no modules elsewhere.
- Existing `control.lua` comments describe the consecration and detritus machine logistics subsystems. **Loader presence is not native behavior proof.**

### Next audit tasks (must precede implementation)
A1. Locate exact definitions and callers of `get_base_sanctification_max`, `apply_completed_sanctification_operation`, `sanctify_target_with_priest` and state initialization; identify one canonical writer.
A2. Enumerate all module-type prototypes and any data-final-fixes or compatibility injections, not just a guessed `modules.lua` path.
A3. Trace `mechanical-detritus` production, recycling, and physical custody end to end.
A4. Enumerate machine eligibility and module slot definitions including Space Age; document quality event semantics and migration behavior.
A5. Produce a current-versus-target research graph and locate localized strings for each unlock.
A6. Only then implement the smallest bounded change on `main` with source tests and native game evidence.


### Phase A follow-up — verified canonical research calculations
- `scripts/generated/control_legacy_part_001.lua` defines `STARTING_SANCTIFICATION_TECH_BONUSES`: initial-consecration-1 = +20, initial-consecration-2 = +20.
- The same file defines `MAX_SANCTIFICATION_TECH_BONUSES`: capacity-1 = +10, capacity-2 = +10.
- `get_base_sanctification_max(force)` reads configured base maximum plus force research bonus; `get_base_sanctification_start(force)` reads configured starting value plus research bonus, clamped to maximum. Neither function currently accepts an entity/quality argument.
- `get_current_consecration_config_snapshot(force)` already exposes base start/max, decay, damage and degradation settings; extend this interface rather than duplicating it.
- `scripts/generated/control_legacy_part_003.lua` defines `sanctify_target_with_priest`; `scripts/core/consecration_executor_0515.lua` wraps that function and references `record.sanctification` / `record.max_sanctification`.
- **Design correction:** do not assume proposed quality-tier bases 50/60/70/85/100 are immediately compatible with configured defaults, +40 start research and +20 capacity research. Specify quality bonuses relative to existing settings or explicitly migrate the entire scale. Preserve degradation and research meaning.
- GitHub code search returned no matches even for known symbols; direct file reads are authoritative for this pass, but do not infer repository-wide absence from empty search results.

**Next bounded task:** trace creation of sanctification records and `apply_completed_sanctification_operation` in generated fragments, then implement a pure tested quality-aware calculation at that owner. Do not change game behavior until the ownership path is established.


### Phase A continued — generated-fragment call-site audit
- Directly inspected all 22 `scripts/generated/control_legacy_part_001..022.lua` files for exact declarations/calls of `get_consecration_record`, `register_consecration_target`, and `apply_completed_sanctification_operation`.
- `control_legacy_part_002.lua` invokes `register_consecration_target(entity)` (near line 994) and queries records (near 1225).
- `control_legacy_part_003.lua` invokes `get_consecration_record`, restores `record.sanctification` in `sanctify_target_with_priest` (near lines 1018–1051).
- `control_legacy_part_004.lua` invokes record lookups in existing research/state logic.
- Additional record lookups are in parts 014, 016, and 017.
- Exact definitions of the record owner and `apply_completed_sanctification_operation` were **not located in these generated fragments** by this scan. They may live in other runtime files; this is **not** evidence that they are missing.
- Existing default settings in fragment 001 are base max = 100, base start = 50, decay = 3–10 per operation, with configurable jitter, pollution, malfunction and damage parameters.
- Therefore proposed quality values 50/60/70/85/100 match the **unresearched defaults only**, not all configurations. Preserve settings and force research; quality adjustment must be designed relative to them.

**Open blocker to gameplay edits:** locate and inspect the actual record-definition and operation-completion owner outside generated fragments. Avoid altering the generated fragments speculatively or introducing a parallel state store.


### Phase A investigation — record ownership and integration risks (continued)
- Confirmed `control.lua` loads generated fragments 001–022 **before** installing newer runtime wrappers. This matters for preserving existing sanctification globals and avoiding shadow ownership.
- The `consecration_executor_0515` wrapper delegates to the original `sanctify_target_with_priest`; its `maximum(record, entity)` first trusts `record.max_sanctification`, then falls back to `get_base_sanctification_max(force)`. A quality-aware maximum must reconcile existing persisted record maxima, not merely change a global default.
- The `mining_sensor_0495` explicitly calls `apply_completed_sanctification_operation(record_obj, pseudo_recipe(...))` and requests overlay refresh; production-completion hooks must remain compatible with this path.
- The current `quality.lua` compatibility file contains **comments only**, describing station quality radius and priest/proxy quality. It is not a machine-sanctity modifier implementation.
- Direct reads of 22 generated fragments found consumers but not the target record definitions. Guessed filenames under `scripts/core/consecration/` did not resolve; filename guesses are not an exhaustive inventory. GitHub code search is not returning known symbols, so it cannot establish absence.
- Canonical owner discovery is still required before touching production code. Next reliable method is a full repository file-tree/content scan through a runner or checked-out workspace, searching exact symbols and recording actual paths and line numbers; do not claim a native test or completed integration without that evidence.

#### Required quality integration contract (provisional)
1. Preserve `DEFAULT_BASE_SANCTIFICATION_START=50` and `DEFAULT_BASE_SANCTIFICATION_MAX=100` as the configurable Normal baseline; preserve +20/+20 starting and +10/+10 capacity research.
2. Define a quality delta table relative to Normal (proposed +0/+10/+20/+35/+50) rather than hardcoding absolute values that override settings.
3. Decide whether quality affects only initial sanctity or also max capacity. Current design asks for **higher base sanctity**, not necessarily higher capacity; do not silently increase max.
4. At machine registration, derive the quality-adjusted initial value, clamp against researched/current capacity, and persist without overwriting existing wear/decay on reload.
5. On quality change, define whether current sanctity is preserved, raised proportionally, or reset; default safety rule: never heal a worn machine just because it is reloaded or moved.
6. Module modifiers must operate on **effective** sanctity, leaving stored condition and quality baseline intact; mixed modules need deterministic stacking and bounds.
7. Preserve low-sanctity penalties unless Chaos research/modules explicitly modify their susceptibility. Do not make Legendary quality immune to degradation.
8. Test Normal and Legendary with no research, +40 starting research, +20 capacity research, custom settings, save/reload, and module insertion/removal before broader rollout.

**Status:** implementation intentionally held pending exact record-owner discovery; no runtime code or native evidence changed in this pass.


### Phase B1 — first code integration: quality-aware initial sanctity (2026-11-21)
- Implemented in `scripts/core/consecration/quality_baseline.lua` and wired directly into canonical `consecration/registry.lua` record creation; no alternate record store, new tick service or new event handler.
- Quality occupies a fraction of **remaining headroom** between the researched/configured starting sanctity and maximum: Normal 0%, Uncommon 20%, Rare 40%, Epic 70%, Legendary 100%. With default 50/100 values this yields the proposed 50/60/70/85/100. With researched 90/120 this yields 90/96/102/111/120, preserving quality differences rather than saturating most tiers.
- Quality **does not raise capacity** at this stage. Existing force research (+40 starting, +20 capacity), mod settings, degradation, detritus and rituals remain authoritative.
- Only **newly registered records** get a quality-adjusted start. Re-registering, scanning, save/load and existing machine records retain their worn sanctity; no automatic healing of pre-existing high-quality machines. Quality upgrade/replacement lifecycle rules remain a separate target.
- No Quality mod or unknown custom quality defaults to Normal rather than inventing additional benefits.
- Unit regression added at `tests/unit/machine_spirit_quality_baseline.lua` for five quality tiers, researched headroom, clamping, no-Quality fallback and existing-record preservation. Local pure-Lua calculation smoke test passed; repository-integrated unit test and native Factorio load/scenario execution remain to be verified.
- Law & Order / Chaos & Anarchy module prototypes, research branches and doctrine runtime effects remain **unimplemented** by this patch.

### Phase C — initial bilateral doctrine vertical slice (2026-11-21)
- Added two nonexclusive research chains: Law & Order I/II and Chaos & Anarchy I/II, with four real module prototypes and craftable, researched recipes in `prototypes/machine_spirit_doctrines.lua`.
- Order I/II: +10/+20 effective sanctity per installed module, plus native -8%/-14% operating energy effect. Chaos I/II: -12/-22 effective sanctity, 12%/25% resilience per module, extra detritus probability 8%/14% of remaining headroom, plus native +8%/+14% speed and +12%/+24% energy consumption. Resilience capped at 70%; waste bonus capped at 45%.
- Runtime `doctrine_effects.lua` reads **installed module inventories only**, supports mixes and arbitrary qualities (same sanctity value per count), snapshots at most once per 60 ticks per accessed machine, and adds no new tick or scan registration.
- Existing sanctity ratio, production throttling, physical/capacity wear chances, and **actual completed-operation** detritus output paths now use appropriate doctrine modifiers. Underlying stored sanctity is not directly overwritten by module effects; removals revert after snapshot refresh.
- Data-final-fixes excludes these machine-local module categories from beacons that previously allowed all categories; explicit third-party beacon category restrictions are preserved.
- English locale names/descriptions and pure Lua regression tests added. Existing module slots are respected: no slots are added to ineligible machines. New assets are temporarily tinted existing icons.
- **Evidence:** local plain-Lua tests for doctrine modules, caching, and prototype structure passed before commit. Native Factorio mod load, recipe/technology graph, in-game module insert/remove, detritus custody, performance, and migration tests still outstanding. Do not represent this as native-validated.
- **Future tasks:** source audit for beacon category compatibility, actual visual icons, quality-scaled sanctity effect for quality-grade modules, more responsive invalidation on module changes where engine events allow, doctrine UI, end-to-end native performance and balance.
### Chaos wear-coupling correction — 2026-11-21
- **Finding:** Initial doctrine integration reduced effective sanctity for Chaos but used that reduced number when calculating physical damage and maximum sanctity-capacity damage. Chaos modules could therefore *increase* self-harm even while advertising resilience.
- **Repair:** `doctrine_effects.damage_value(record)` returns the greater of the stored sanctity and effective sanctity for physical-degradation checks. Consequently, Order still offers additional wear protection, and Chaos lowering effective sanctity for detritus/operational penalties never by itself worsens physical harm. Chaos's resilience multiplier separately reduces damage-event probability (cap remains 70%).
- **Tests:** Expanded `tests/unit/machine_spirit_doctrine_modules.lua` to verify mixed Order/Chaos, no additional wear exposure, and Order's wear benefit. Two local `texlua` suites passed (doctrine prototypes and doctrine runtime), before this commit; no native Factorio result is claimed.
- **Outstanding:** Native 2.1 startup, real module inventory, and scenario measurements on the existing local runner.

### Phase C2 — Chaos low-sanctity extraction yield repair (2026-11-21)
- **Bug:** at the minimum 5% sanctity ratio, existing `get_waste_chance_from_ratio` reaches 100%. The first Chaos implementation only added probability, so its detritus benefit disappeared precisely when sanctity was lowest.
- **Fix:** keep the existing chance uplift, but also add a bounded multiplier to generated quantity: `1 + min(1, sum(extraction)) * (1 - effective_sanctity_ratio)`; Chaos I grants 0.20 extraction per module and Chaos II 0.40, capped at 1.0 total. One Chaos II at the 5% floor yields 1.38 times base detritus per completed operation, even at 100% chance. This is deliberately a production-linked byproduct, not an idle generator.
- **Accounting:** all extra detritus still passes the existing recipe output-slot gate, `roll_count_from_expected`, and `add_mechanical_detritus` physical inventory path; no extra item source or scheduler.
- Added unit tests for quantity at capped probability, mixed-module effects, bounds, absence of Order-only extraction, and output-slot rejection. Wired `machine_spirit_doctrine_waste.lua` into the existing manual hot-path source smoke suite, without changing any workflow trigger, runner, or scheduler.
- **Evidence:** Lua tests run locally using the pure module and a source-equivalent isolated operation-waste fixture; the committed test runs the actual full `effects.lua` when invoked. Native Factorio launch, completed recipe, inventory screenshot, and save/load still outstanding.

### Phase C3 — isolated native doctrine acceptance scenario (2026-11-21)
- Added `tests/scenarios/machine-spirit-doctrine/fixture.lua` to the **existing** `tools/run_factorio_isolated_service_scenario.py` runner's CASES; no workflow, scheduler or dependency downloader modified.
- The 4,200-tick isolated real-engine test covers exact prototype/tech/recipe availability, native researched unlocks, actual module insertion/readback (baseline, Order, Chaos, mixed), real powered iron-gear production, completed-operation count, output-inventory detritus custody, and Chaos's increased quantity at the 100% chance ceiling. Fixture pre-ages machines to 5/100 but never fabricates operations or output.
- Test case runs using the locally cached Factorio binary/mods; original engine logs and artifacts are retained by the existing runner. **Status: scenario authored and syntax checked; not executed in native Factorio in this turn.** Engine launch/load remains the acceptance gate.

### Native production fixture stabilization — 2026-11-21
- Isolated `machine-spirit-doctrine` production acceptance now marks **only its disposable test assemblers** `destructible=false`, because intentionally pre-aging them to 5/100 can otherwise cause random destruction while testing crafting and physical waste custody. The shipped mod's damage logic remains unchanged; the planned survival scenario must use destructible entities.
- Runtime module contents must read back as Order/Chaos `0/0`, `20/0`, `0/22`, and `10/12` for baseline, Order, Chaos, and mixed fixtures. Mixed extraction must increase expected detritus quantity.
- Order is allowed to generate **zero** detritus because that is a valid high-sanctity result. Baseline and Chaos still require physically credited detritus. A zero on Order is not a failure.
- Local `texlua` syntax fixture analogue and three doctrine source-level regression suites passed. **Native Factorio execution is still pending.** No CI scheduling, downloads, or release gates changed.
