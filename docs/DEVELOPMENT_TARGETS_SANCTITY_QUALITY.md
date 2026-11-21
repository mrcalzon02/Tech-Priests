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
