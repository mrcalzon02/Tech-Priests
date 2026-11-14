# Native autonomous behavior validation, 2026-11-14

Factory/science acceptance remains **FAILED**. Do not publish these changes as a
completed autonomous factory or a successful four-way battle.

Work started from remote main `1f7cbb23146703f35d56a9401ef5f966060d4c46` in
the isolated `behavior/arena-validation-20261114` checkout. Existing local art
work was preserved. Native engine: Factorio 2.1.24, Windows Steam installation.
Evidence is under `../arena-evidence/` relative to this checkout, in persistent
workspace storage. User gameplay saves and the installed live mod were preserved;
isolated native factory saves are now resumed between behavior corrections.

## Latest measured state

Further native continuations exposed a data-stage smelting failure: the
zero-probability Mechanical Detritus product made ordinary smelting recipes
require two item output slots, while vanilla and emergency furnaces retained
one. Even fresh, empty, fueled furnaces rejected stone, iron and copper. The
final prototype pass now provides the required waste slot without changing
recipe costs or probabilities. `stateful-science-19/observation-smelting.json`
verifies existing native furnaces accept inputs and physically produce bricks.
At tick 450,233 that run records 418 red and 73 green packs, military zero,
and physical-projectile-damage research progressing. Its native save passes
CRC validation and its original source save remains unchanged.

The legacy lifecycle now yields strict manufacturing and physical acquisition
to their canonical owners; an obsolete parent mining alias cannot resume after
its material child finishes. Periodic repair pulses also yield their own
movement lease to existing physical courier cargo, retaining the pending repair.
At tick 484,998 the continued native factory has 462 red and 88 green packs;
military remains zero. Native observation confirms five actual grenades reached
the military assembler, with piercing ammunition and walls still missing.
Buffered science now yields transport urgency to those missing intermediates;
that latest balance change is undergoing native validation in science-22.

Arena-10 preserves a native continuation at tick 327,024. All four factions
have expanded (3/3/3/2 stations); science and participant combat acceptance
remain unfulfilled. Nearby native ore reports uncharted for every faction,
including within the scenario's initial chart area. This discovery/cold-start
blocker remains under investigation; no ore, lower-rank kits, science or
recurring inventory has been injected to conceal it.

The full native maintenance gate passes in `maintenance-final-regression`:
all four ranks completed 120 real machine operations, repaired all eight targets,
and observed natural operation decay on all eight. Consecration counts were
Junior 5, Intermediate 4, Senior 8 and Magos 6.

The stateful factory now manufactures science and completes research. At tick
180,121, `stateful-science-05` records 84 red packs, two green packs, three genuine
research completions and electric-mining-drill research in progress. No science
packs were seeded. The native save passed ZIP CRC verification; its source save
was unchanged. This proves functional progression, **not sustained throughput**.
The original full nine-checkpoint/15-SPM acceptance gate remains unmet.

Further resumed native runs now physically build and configure twelve standard
assemblers, including military science, walls, grenades, ammunition, circuits
and inserters. At tick 300,451, genuine one-minute native rates are red 10 SPM,
green 5 SPM and military 0, with totals 168 red and 20 green. This meets the
individual red/green starter rates at that observation, not the complete sustained
three-family acceptance gate. `stateful-science-11` preserves that continuation.
Large assembler delivery now measures the same 1.6-tile reach from its actual
footprint and chooses collision-clear perimeter contacts. Hidden Cogitator
backing inventories use their physical host station footprint for pickup.
An unreachable backing-cache center had stranded the real fuel carrier; the
native continuation verifies its return, refueling and resumed production.

The independent component planner now includes each actually unlocked red,
green and military science family alongside the native current research basket.
Counted five-cycle input batches and deficient-recipe priority prevent incidental
raw collection from starving these configured machines. Physical lab supply
precedes fresh routine machine collection while existing cargo retains its owner.

Arena combat had two further extension failures: large targets were measured to
their unreachable solid centers, and combat remained a compatibility-only
dispatcher leaf. The existing proxy/fallback combat owner is now serviced by the
canonical dispatcher, with native cooldowns, diplomacy revalidation and incumbent
cargo restitution. Its safety dependency is loaded at control initialization;
Factorio cannot perform that require from an event-stage tick. Native continuation
`stateful-arena-05` clears the root force's long-running spawner fight and resumes
the authentic station expansion writ. Participant battle and four-force factory
acceptance remain unproven. Runtime damage receipts expose actual engine damage.

The legacy generated beam ownership audit cannot run in full on this branch:
its required `.github/workflows/source-validation.yml` is absent from tracked
source, independently of sparse checkout. Focused canonical owner, movement,
friendly-fire, cargo, science graph and physical delivery regressions pass.

At tick 324,044, the continued native factory has 207 red and 44 green packs;
military remains zero. Its wall assembler's brick shortage now reaches the
existing strict smelting and physical stone acquisition owners. Canonical steel
and brick stock reads prevent duplicate requests for the 300 real steel plates
already in crates. Existing partially funded strict brick batches can replenish
stone through a separate marked 0513 child while retaining actual furnace inputs,
completed brick output and the active native craft. Stale compatibility mining
targets on a strict manufacturing parent cannot seize that child's extraction.
Configured intermediate machines lose deficit priority when their actual general
stock already covers a bounded buffer, so surplus gears cannot starve ammunition.

`stateful-arena-06` proves another source-empty/cargo-full extension fix: force 4
now has two real stations and a physically built, fueled emergency smelter. The
0519 wrapper previously rejected a station assignment after its last item had
already been debited into 0824 cargo. It now lets the original cargo owner validate
that hold before testing new item producibility. Unfunded new work remains deferred.
Ordinary 0256 pickup/build movement now uses the same canonical owner and priority
as its already repaired edge-ghost contact route.

Native observations identified and corrected these additional blockers:

- Standard bootstrap assemblers were built but omitted from the existing owned
  workshop ledger. Only actual bootstrap construction receipts register them;
  arbitrary player assemblers remain unclaimed.
- Consumer pole construction delegated a laboratory dependency to an owner the
  dispatcher did not service. The power owner now completes its actual consumer
  pole; the native laboratory receives real generated electricity.
- Production read legacy buffers and removed inventory enums. Canonical storage
  identities and native crafter input/output IDs now supply and collect recipes.
- A superseded red recipe was continuously refilled. Its unconsumed input queue
  now returns through exact deposit/refund custody while its last engine cycle
  finishes. Zero-probability detritus cannot block recipe handoff.
- Strict engine production prevented its own boiler fuel delivery. The existing
  energy owner may service that prerequisite while retaining the original recipe,
  acquisition order, combat priority and physical cargo ledgers.
- The master planner and Conclave wrote the native 2.1 read-only current research
  property. Both now call `add_research` and require actual engine acceptance.
- Native chest and fuel inventory IDs alias. Drill output receivers were treated
  as burners, creating endless coal deposit/collection jobs. Receiver containers
  are excluded and native `get_fuel_inventory()` is authoritative. Native rerun
  `stateful-science-06` tests this last correction.

The latest completed four-way run, `four-way-capacity-contact-proxy`, preserved
its genuine final save and still fails factory/science/participant-combat gates.
Force 2 made six build events and force 3 made two; both have their Magos and two
Senior stations, within direct command capacity. Forces 1 and 4 made no builds.
No force manufactured science or completed research. Natural enemy combat does
not satisfy the separate participant battle gate.

Arena corrections include shared actual staffed-domain resource observations,
command-capacity admission before new station spending, delegated resource scouts,
in-bounds contact points for edge station ghosts, exclusion of hidden proxies from
ordinary turret deliveries, and native-compatible proxy ammunition selection.
Legacy rock targets lacked exact yield metadata and repeatedly failed extraction.
The existing direct owner now mines into native persistent inventory custody,
returns actual random stone and secondary coal, and preserves refused deposits
through reload. `four-way-native-rock-fuel` tests these latest corrections.

Focused regressions cover native inventory aliasing, random multi-item rock
custody, read-only research, completed workshop recipe handoff, physical lab
delivery, proxy job retirement/refund, standard workshop isolation and command
capacity delegation. Earlier observations below are historical checkpoints.

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

## Native maintenance correction and verified result

The subsequent `maintenance-order-reconcile/consecration-maintenance` run passes
the full four-rank, 24,000-active-tick gate. Every rank repaired all eight damaged
machines and recorded natural operation decay on all eight. Junior/intermediate/
Senior/Magos completed 5/4/8/6 rites respectively; each rank also completed 120
real machine operations. The native log contains `PASS active machine
consecration and repair from real stocked items ranks=4`.

The operation economy needed registration with the canonical tick broker;
its former legacy callback was not receiving service. The dispatcher needed to
reconcile finished orders before admitting the next maintenance job. Repair and
rite movement now use reachable standoff distances outside solid machines while
retaining the physical interaction range. Native wandering commands are detected
and corrected through the existing movement owner and command budget.

## Earlier checks and remaining blockers

Later native factory iterations correct the 2.1 pole supply API, half-tile pipe
grid, bound placement calls, output-only fluidbox neighbour segments, premature
route completion and proposal expiry during physical construction. Pipe adjacency
now checks the exact touching port rather than every fluidbox of a nearby boiler.
The explicitly independent 72,000-tick run builds 19 real pipes, completes the
water and steam routes, and installs the laboratory and three networked poles.
Water is produced by a real offshore pump; no fluid is seeded. Science and
research are still zero at this checkpoint. The next measured blocker is the
valid zero-slot vanilla burnt-result inventory being misclassified as full;
the correction is covered by a residue-capacity regression and is under native
rerun. Do not count physical assembly as science acceptance.

Manual shoreline checks exposed another fixture defect: the old pond only put
a diagonal corner inside the station construction interior. It allowed a dry
pump under ghost-revival checks. The initial pond now has an accessible shoreline
inside that interior; starting terrain is changed, never fluid inventory.
This factory fixture now explicitly enables independent mode through the existing
setter after each original pair appears, rather than depending on discovery to
enable it silently. Default maintenance discovery no longer authorizes expansion.

The arena now records resource expansion reasons and mission state. A pending
raw construction leaf takes priority over speculative ratio materials: forces
blocked on stone now explore for stone instead of iron. Existing physical
missions and ore custody retain their owners when independent mode is disabled.
The four-way factory/science/combat acceptance gate remains failing.

`energy-phase-handoff/midgame-science` subsequently records real electricity
generation at tick 72,000 (`generator_output_last_tick=41.666666666666`). Its
energy receipts prove two coal removed from canonical storage, carried to the
boiler and inserted at tick 28,090. Source/delivery movement now uses the same
physical footprint calculation, and verified pickup and terminal events release
only the energy owner's movement lease. Previously movement debounce returned
the coal immediately to its source. A regression exercises this with the real
movement controller, including pickup outside its smaller arrival radius.

Fuel discovery now uses the same canonical storage sources as stock accounting,
keeps distinct inventory identities and honors reserved ore courier stock.
The factory builder checks modern fluid storage before recipe configuration;
0528 reads native crafter input/output inventory IDs. Boiler coal pickup uses a
counted batch of up to eight to reduce repeated two-item round trips. These fixes
do not yet prove laboratory throughput or research completion; those native gates
remain under iteration.

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
