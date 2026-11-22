# Isolated Factorio 2.0 service and railway scenarios

These are two **independent real-engine acceptance environments**, separate
from the existing all-ground-ranks science/combat/relocation endurance test.
Their fixtures are copied into an isolated mod installation and invoked only
at `control.lua` parse time. They are never packaged in the released mod.
No new GitHub Actions workflow is required.

## Execute locally (Factorio 2.0.77 headless)

Use the actual installed binary and a directory of any required external
Factorio mods (ZIPs or unpacked mod folders). This is a self-contained
launcher, not an invitation to modify normal saves or installed mods:

```sh
python3 tools/run_factorio_isolated_service_scenario.py \
  --scenario consecration-maintenance \
  --factorio /path/to/factorio/bin/x64/factorio \
  --dependency-mods /path/to/required/mods

python3 tools/run_factorio_isolated_service_scenario.py \
  --scenario remote-rail-acquisition \
  --factorio /path/to/factorio/bin/x64/factorio \
  --dependency-mods /path/to/required/mods
```

Output is retained under `test-artifacts/isolated-service/<scenario>/`:
the disposable mod installation, initial save, map settings, and original
create/benchmark logs. Each scenario runs as its own benchmark world on seed
907260, with biter-base generation disabled. Any fatal marker, missing pass
marker, missing dependency, or nonzero headless exit is an honest **failure**.

### All-rank consecration / repair

Four vanilla-rank Cogitator/priest pairs (Junior, Intermediate, Senior,
Planetary Magos). Each has **two rows of four running assemblers**, engine
selected iron-gear recipes, 30 real iron plates per assembler, independent
test-only electric power, and a physically stocked chest (oil, litany,
repair packs, ammunition). Machines begin pre-aged but no rite, repaired
health or production counter is fabricated. The fixture subsequently
inflicts genuine Factorio engine damage on each assembled machine.

The 24,000-tick acceptance requires, **for every rank**, actual gear output,
operation-triggered sanctification decay, a consecration source history
attributed to the priest, and rising engine health from repair packs.
Periodic diagnostics report rank, crafts, actual decay, rites, repairs,
current work order and executor phases.

Passive restocking is the distinct `emergency_supply_reserve_0497` path,
with ammo, repair packs, sacred oil and the other consecration items tracked
as critical. This fixture starts stocked to isolate **active service**;
a separate depletion/restocking run must prove passive manufacturing and
redistribution. Do not treat a stocked item as proof that it was crafted.

### No-local-ore, distant-train acquisition

One living Planetary Magos at (0,0), charted 81-tile iron ore patch near
(512,0), **no local iron ore within 64 tiles**, 700 physical rail items,
locomotives, wagons, fuel, stops, signals, mining drills, chest and inserter
supplies. Railway/automation train research is fixture-unlocked; not
credited as priest research. No track, train, mine or inbound ore is placed
by the fixture. Biters and resource noise are removed from the local
footprint and rail corridor; the remote destination is explicitly charted
as prior map intelligence.

The first acceptance is the new `remote_rail_outpost_0835` observer:
real iron-ore shortage, absent local mineable ore, unlocked railway
technology, physical construction supplies, charted distant ore, then
**one durable Magos expansion objective**. The observer is read-only and
does not spawn rails, inventories or trains.

Later stages must pass IN ORDER from engine evidence:

1. Route selected against real terrain and supplies budgeted.
2. Successive rail pieces constructed with exact item debit, linked into
   a physically usable continuous train route.
3. Locomotive and cargo wagon assembled, fueled and validated as a train.
4. Magos actually boards/rides; no position teleport or false lease proof.
5. Remote mine and transfer infrastructure constructed by engine actions.
6. Real iron ore loaded, train travels back and unloads into central storage,
   yielding **more ore than the measured initial inventory**.
7. Saved/reloaded missions and partial construction retain original identity,
   cargo and expenditure ledgers.

The first-stage starvation survey is implemented. The **0836 physical
track frontier** now requests one straight rail at a time through the existing
0338 construction authority, retaining segment, site and exact item custody
across dispatch pulses/saves. It advances only after a real engine rail entity
is linked to the successful canonical builder's record. Initial routing is a
bounded eastbound straight corridor; unsuitable terrain fails closed instead
of pretending to create a connected route. The separate scenario now checks
**first real track and consumed rail stock at 18,000 ticks**.

A full engine-validated continuous route is **not yet achieved**. Curves and
terrain routing, train assembly, actual boarding, remote mining, physical
freight and reload acceptance remain future implementation. The 90,000-tick
end-to-end test intentionally fails until these physically execute. A relay
of Cogitator stations is not train proof, and moving a scripted ore balance
is never freight proof.

### Mid-game multi-science autonomous factory (new)

The separate `midgame-science` scenario starts with three paired ranks
(Junior, Senior, Planetary Magos), **eight actual steel-chest supply crates**,
and real local iron, copper, coal, stone, uranium, crude oil and water.
The scenario unlocks base-game prerequisites through **military science**
(red/green/military packs available), plus ordinary mid-game industry
technology. **Chemical science remains unresearched** and is the advanced
progression target. Factory machinery, power plants, drills, labs, belts,
pipes and science packs are **not prebuilt or fabricated**. No research order
is set; its selection must come from the actual AI.

Run Factorio 2.0.77 locally with:

```sh
python3 tools/run_factorio_isolated_service_scenario.py \
  --scenario midgame-science \
  --factorio /path/to/factorio/bin/x64/factorio
```

The test records nine complete, actual engine checkpoints from tick 0 to
216,000, including the exact per-force/per-surface one-minute red, green,
military and chemical science production flows, current research, live
entity positions, selected recipes, and priest pairing. Original eight
crates and fixture-unlocked technologies **never** count as output.

Factorio headless does not render screenshots; requesting
`game.take_screenshot` in a headless benchmark does nothing. The separate
`tools/render_midgame_science_timelapse.py` builds an overhead **engine
telemetry map** for each checkpoint and combines nine maps into a readable
GIF. It labels these derived images **NOT A GAME SCREENSHOT**. If the same
fixture is run in a graphical Factorio client, genuine
`checkpoint-*.png` images can be supplied to the renderer instead.

The fixture also requests individually named autosaves at every milestone.
Only save ZIP files actually found on disk are counted as recoverable
checkpoint saves; a save request is not proof that the benchmark wrote it.
The runner retains native logs, strict JSON checkpoint evidence, the GIF,
and available saves in `test-artifacts/isolated-service/midgame-science/`.

The [mid-game science workflow](../../.github/workflows/midgame-science-validation.yml)
runs separately from the original physical-ore, biter-defense and
123k ground-rank acceptance. A successful **fixture/checkpoint audit** does
not mean the priests achieved three-pack or chemical science production:
the final `MIDGAME_OBJECTIVE` marker and summary.json truthfully report
those independent measured manufacturing goals. Continued development
must address unbuilt machines, missing fuel/power, ingredient feeds,
research selection, layout and fluid-routing failures.

### Machine Spirit Law/Chaos native acceptance (Factorio 2.1)

Run against an **already installed local Factorio binary and cached dependency
mods**, not a hosted runner that repeatedly downloads the same packages:

```sh
python3 tools/run_factorio_isolated_service_scenario.py \
  --scenario machine-spirit-doctrine \
  --factorio /path/to/local/factorio \
  --dependency-mods /path/to/cached/mods
```

This isolated fixture verifies the native prototypes and researched unlocks,
module inventories on four genuine assembling-machine-3 entities (baseline,
Law, Chaos and mixed), actual iron-gear crafting, and real Mechanical Detritus
entering each output inventory. It verifies the Chaos quantity multiplier
survives the 100% chance ceiling. Initial sanctity 5/100 is explicitly seeded
to reproduce low-sanctity behavior; the fixture **does not** manufacture
operations or output items. Captured output is removed only after engine
production and counted as physical custody; absent or duplicated material fails.
The disposable test-only fixture is never packaged. This test has not yet been
run against a native binary after being added.


### Native custom-entity Quality matrix (Factorio 2.1, Quality required)

Use an existing local Factorio installation and cached mod ZIPs. This case
requires an actual enabled Quality feature with all five native grades; it
**fails** rather than silently accepting a Normal-only run.

```sh
python3 tools/run_factorio_isolated_service_scenario.py \
  --scenario quality-entity-matrix \
  --factorio /path/to/installed/factorio \
  --dependency-mods /path/to/locally/cached/mods
```

The native test creates **40 bunker turrets** (eight prototypes × five Quality
grades) plus two grade specimens for 27 other custom structures (Cogitators,
Martian power and comms arrays, faction factories, hydrogen machines, plasma
reactors and emergency machinery). It checks actual placed quality, the native
quality-adjusted `LuaEntity.max_health` against
`LuaEntityPrototype.get_max_health(quality)`, crafting speed on supported
crafting machines, pole supply/wire distances, and preserved quality in the
hidden Martian communications radar. Burner generator output is logged as
engine-observed prototype data rather than assuming automatic power scaling.

The fixture runs only in the disposable isolated mod installation, reports a
pass only from the loaded benchmark process, and does not fabricate production,
turret kills or electrical power. **This is a native *quality-entity-stat* gate,
not a distant-target shot test, power throughput test, or save/reload proof.**
Those remain separate gates.


### Native Legendary Energy Dish firing beyond Normal range

```sh
python3 tools/run_factorio_isolated_service_scenario.py \
  --scenario quality-turret-fire \
  --factorio /path/to/installed/factorio \
  --dependency-mods /path/to/already-cached/mods
```

This **separate 1,200-tick test** creates two powered native
`tech-priests-bunker-energy-dish` turrets at Normal and Legendary Quality,
each facing one real stationary hostile worm 35 tiles away. This distance is
outside the 28-tile Normal attack envelope but inside the 42-tile Legendary
envelope. The fixture measures the minimum actual worm HP observed by the
existing runtime broker service and requires **no Normal target damage** and
**positive Legendary target damage**. It does not directly call
`LuaEntity.damage`, create synthetic projectiles, or modify the released
weapon definitions. Only the disposable fixture's electrical supply and
test targets are created by script. The native game, not a calculation,
must deliver the successful shot. The scenario has passed a local Lua
syntax check but has **not yet completed a native Factorio 2.1 run**.
