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
