# Seeded force-projection endurance arena and autonomous rebuilding

Status: source and mock/parser tests implemented. Native acceptance is separate.

## Deconstruction authority

Maximum frustration AND full autonomous mode are necessary just to CONSIDER
a rebuild. Neither condition authorizes mining or demolition. An active player
order, locked player book, or inherited parent order blocks consideration.
Unknown provenance fails closed. Resetting the parent order's frustration must
invalidate queued abandonment/rebuild proposals using the order generation.

Initial eligible targets: positively identified same-force/surface structures
erected under autonomous authority, now redundant, empty, without a committed
task/material owner, without critical dependants, and with verified replacement
and salvage capacity. Player-built structures, player-blueprint structures,
protected structures, unknown ownership, and live transport/power/defence
dependencies are ineligible. A stopped machine alone is not obsolete.

The pure `autonomous_rebuild_policy.consider` module expresses this fail-closed
proposal contract. It is NOT connected to a demolition executor or a completed
player-order ledger. No new deconstruction capability is enabled by this change.
Existing explicit station recovery/relocation and combat remain separate owners;
this contract does not disable those established physical paths.

Before physical rebuilding is introduced, require dependency checks, replacement
commissioning, an incremental salvage operation, and a final generation/custody
recheck at the actual mining step. A frustration reset must block all remaining
steps immediately while preserving already salvaged items. No automatic mass
rebuild and no demolition solely because doctrine changed.

## Presets

Every priest start is a separate force and one original Planetary Magos station
with its canonically paired priest. Subordinates must be built by the actual AI.
Each bug start is a separate force with three ordinary biter spawners, evolution
fixed to zero for novice opponents, native higher-level AI enabled. No scripted
attack commands or forced encounters.

| Preset | Arrangement and diplomacy | Map |
| --- | --- | --- |
| 2p2b | NW/SW priests hostile to each other; NE/SE bugs hostile to each other and priests | 2048 square |
| 1v4-bugs | One priest against four allied, separately owned bug forces | 3072 square |
| 2v2 | Two allied priest forces on left versus two allied bug forces on right | 2048 square |
| 3v1 | Three allied priest forces versus one bug force | 2048 square |
| 4v4-priests | Eight independently owned priest forces, allied as four left versus four right | 3072 square |

These are explicit first interpretations of the requested ratios; diplomacy is
configuration data so a later four-way/free-for-all variant is straightforward.

Every 256-square macrocell contains randomized blobs of iron, copper, coal,
stone, crude oil and water. Starts have a protected 96-square clear pad. Resource
amounts near starts are 100–400 per ore tile; farther deposits 400–1800. Oil uses
the corresponding larger finite native amounts. Radius and offsets vary by seed.
Fixture-created deposits are labelled as authored test resources, never credited
as mining. The resource layout is predefined and reproducible for a given seed;
unseeded CLI runs choose a fresh entropy-derived seed and record it.

One large real chest per priest start: largest non-hidden container/passive
provider with 48–256 normal-quality slots in the installed modpack. No infinity
containers, hidden helpers or planner tools. Every slot independently selects a
random visible item from the installed game/modpack, across technology tiers,
with a random quantity from one to its native stack limit. Duplicates and missing
essentials are intentional. No curated bootstrap subset, refill, fixture research
unlock, production reward, teleported cargo, or later fixture-built machinery.
This is a randomized-stock stress test; a resource-starved start is diagnostic,
not evidence that the scenario or combat succeeded. Enabled DLC/mods determine
the eligible supply pool and must be held constant when comparing revisions.

## Performance and observation

Terrain setup generates at most one requested native chunk every five ticks.
Resource setup processes at most twelve coordinates per tick. Start placement
is staggered 120 ticks apart. Setup is reported separately from active duration;
the whole map is not generated inside the first station event. Native chunk
generation itself is indivisible and must be profiled on the runner.

During observation, one chunk is censused per tick, capped at 512 returned
entities. Saturation is explicitly recorded and invalidates an exact census
interpretation. Census is a rolling observation, not an instantaneous map scan.
One force is sampled per tick for a full set every simulation minute. Native
build events, live stations/ghosts, maximum observed build distance, native ore
production, research completions, damage, losses, surviving original Magos and
remaining supply stock are recorded. Ore production statistics are not proven
multi-hop delivery receipts. Missing raised build events can undercount builds;
rolling live counts provide a separate observation. Current-task text is a
best-effort diagnostic, not an authority or proof of the planner's blocker.

First cross-force damage records attacker, defender, position and tick. No
contact is reported as no observed combat. Periodic saves every 15 active
minutes and a final save use a private runtime write-data directory. The driver
checks the final save's ZIP CRC before accepting observation completion. A final
save existing is NOT independent reload proof; that remains a separate test.

Native elapsed ticks and wall duration yield aggregate observed UPS including
setup, instrumentation and saving. Script milliseconds, pathfinder cost and
unprofiled gameplay UPS remain unmeasured by this harness. Existing first-station
and service benchmark tests stay separate and unchanged.

## Running

    python3 tools/run_force_projection.py --factorio /path/to/factorio --preset 2p2b --active-ticks 36000

Optional `--seed` repeats the exact stock/layout; `--dependency-mods` accepts an
existing external mod folder. Default active duration is 216000 ticks (one hour).
Use one-minute active smoke tests before ten-minute baselines, then one-hour
endurance and paired-seed comparisons across commits. Output folders refuse
reuse. No normal mod release includes this fixture.

Result JSON distinguishes observation completion, actual combat observation,
and measured progress. It rejects missing manifests, empty/missing deposits,
wrong seed/roster/timing, missing final force samples and explicit fixture FAIL.
Never equate a completed endurance observation with autonomous expansion success.

## Source checks

    texlua tests/unit/autonomous_rebuild_policy.lua
    texlua tests/unit/force_projection_fixture.lua
    python3 -m unittest discover -s tests/unit -p test_force_projection.py -v

Mocks exercise every preset's bounded setup, deposit coverage, force count and
biter AI activation. Parser negatives reject incomplete/duplicate/wrong-seed
evidence. These do not substitute for the Factorio 2.1 native run.
