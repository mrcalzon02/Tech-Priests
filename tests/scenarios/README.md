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

The first stage is implemented; **stages 2–7 remain future production code**.
The 90,000-tick end-to-end acceptance intentionally fails until those
physical behaviors exist. A relay of Cogitator stations is not train proof,
and moving a scripted ore balance is never freight proof.
