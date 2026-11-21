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
