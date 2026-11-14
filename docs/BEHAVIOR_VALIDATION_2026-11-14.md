# Native autonomous behavior validation, 2026-11-14

Factory/science acceptance remains **FAILED**. Do not publish these changes as a
completed autonomous factory or a successful four-way battle.

Work started from remote main `1f7cbb23146703f35d56a9401ef5f966060d4c46` in
the isolated `behavior/arena-validation-20261114` checkout. Existing local art
work was preserved. Native engine: Factorio 2.1.24, Windows Steam installation.
Evidence is under `../arena-evidence/` relative to this checkout, in persistent
workspace storage. No gameplay save or live mod directory was edited.

## Repaired behavior

- Inventory fetching now approaches an entity's real world bounding box and
  measures pickup reach to that footprint. The large arena cargo chest's center
  was unreachable within the old 1.6-tile pickup radius. Native paired-seed
  reruns changed the same stone fetch from perpetual movement to a real deposit.
- Fetch quantity now retains the active recipe's actual ingredient count and
  the named logistics request count. Previously a five-stone furnace dependency
  stopped after one stone. Existing partial station stock reduces the debit.
- With generic reserve sweeping still disabled, an explicitly independent pair
  may execute its concrete pending raw recipe leaf through 0513. Active combat,
  orders, physical duties, custody and courier/reversal/recycling reservations
  block that planning step. Explicit governor `off` disables this path too.
  This does not authorize an expedition outside rank bounds. Missing sources
  are now exposed as `no-source-stone` in the observed arena.
- The resource governor rotates its bounded twelve-station service across all
  station IDs, rather than revisiting the first hash-table entries forever.
- Construction permission accepts physically available installation kits through
  the same generic storage authority used by construction. Manufacturing still
  requires an enabled recipe. Native midgame comparison: the Senior's 18 stored
  electric drills previously stayed unused with a technology-lock blocker; after
  repair one was physically installed, stock fell to 17, and the plan advanced
  to `mining-output-buffer`. No recipe or technology was unlocked by this fix.

## Arena evidence

Seed `14081114`, preset `4p-ffa`, 36,000 active ticks, native speed 20. Four
separate hostile priest forces start with the same random chest draws and real
Senior kits. Initial materials are never credited as production.

| Evidence directory | Force 2 native result | Final active build events, forces 1/2/3/4 |
| --- | --- | --- |
| `four-way-baseline` | Stone fetch stalled | 0 / 0 / 2 / 0 |
| `four-way-fetch-fix` | Stone deposited; quantity incomplete | 0 / 1 / 3 / 0 |
| `four-way-count-fix` | Furnace built; plan reached research readiness | 0 / 3 / 3 / 0 |
| `four-way-final` | Same research-readiness/material boundary | 0 / 3 / 3 / 0 |

The last arena run includes the first station-only stocked-kit check; the final
external-storage extension is separately verified in `midgame-final`.
`four-way-final/4p-ffa-14081114/result.json` records complete observation but
`factory_progress_proven=false`. Every force has zero native science production
and zero research completions. No participant-versus-participant contact was
observed. Force 1 was fighting a real default-enemy medium worm; this is a real
combat-pressure case, not a friendly target or justification to suppress combat.
The contact flag covers participating arena forces, not environmental enemies.

Final rolling census station counts were 1 / 2 / 4 / 1. Kit disappearance alone
is not accepted as expansion. Fixture-time builds precede active build counters;
use rolling native counts and actual event receipts together.

The final arena save passed CRC validation and an additional independent native
120-tick benchmark reload (exit 0). Save SHA-256 remained
`738f23cfe5c628dd8e954deef22ce304b0f1851e379ed2cd194e1b1a70d52e90`.
See `four-way-final/reload-result.json` and `reload-native.log`. This reload
proves that checkpoint loads, not that factory progress succeeded.

## Additional checks and remaining blockers

`midgame-final/midgame-science` passes native early checkpoint acceptance at
0, 9,000 and 18,000 ticks. This is explicitly a smoke gate. At 18,000 ticks:
three paired priests, a physically built laboratory, boiler, engine and pump,
but zero electric poles, unpowered laboratory, zero science and zero research
completion. Power reports `site-not-verified:small-electric-pole` for the Magos;
the Senior reports missing offshore-pump equipment. Trace this physical power
construction path before accepting the science chain.

In the random arena, forces 3/4 still lack a stone source inside their authority.
The Magos radius is 40 while the authored clear-pad half-width is 48. Ranked
resource-directed expansion and actual supply-chain handoff must solve this;
do not enlarge leashes, create ore, refill inventories or weaken science gates.
Force 2 also needs actual iron/copper delivery for its laboratory prerequisites.

The maintenance fixture needed native 2.1 crafter inventory enums, a readiness
wait for its four original canonical pairs, and initialization of its decay
counters. Readiness times out after 3,600 ticks; the four-rank 24,000-active-tick
repair/consecration requirements remain unchanged. Default runner duration is
30,000 ticks to include pairing. Earlier failures are preserved under
`maintenance-final`, `maintenance-21`, and `maintenance-ready`; do not count them
as production repair failures or successful maintenance runs.

The next native attempt exposed an electrically disconnected test generator.
The explicit fixture power source was moved inside its substations' actual
supply area. Machine production now uses the native completed-operation counter,
so legitimate output collection cannot erase evidence of crafting.
`maintenance-powered/consecration-maintenance` now observes four original pairs
(ready at tick 660) and 120 real completed machine operations per rank. At 12,000
active ticks all four ranks still report zero repairs, zero rites and zero
recorded natural operation decay. The same zero counters persist at 24,000 ticks;
the aggregate decay counter also needed initialization before the final failure
could be reported correctly. This is a real remaining maintenance/decay
service-delivery failure; do not claim that player maintenance is validated.

Focused source checks are recorded by `arena-evidence/run-behavior-regressions.py`.
The Lua runner uses Fengari with real file reads and a userdata-only `tmpfile`
adapter for the existing metatable regression. These are source regressions,
separate from the native engine receipts. The suite includes all 59 existing
bootstrap production scenarios, storage custody, movement ownership, physical
construction source tests, all six arena presets and the new regressions.

Continue with native power-site construction, raw-resource expansion across
ranked authority, force-wide subordinate planning and the actual four-way combat
gate. One-hour throughput, sustained science, defense and full modpack acceptance
remain unproven.
