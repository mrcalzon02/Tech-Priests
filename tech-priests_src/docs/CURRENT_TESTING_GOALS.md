# Current Testing Goals

## 0.1.674-dev — Integration, migration, and behavioral release gates

**Packaged baseline:** `0.1.672`  
**Development candidate:** `0.1.674-dev` on `main`  
**Current source-integration commit:** `ad9cf5c881ae1bc0503e6b72ab8213e9844c5055`

This candidate is not release-ready. Do not update `info.json`, build a `0.1.674` archive, or describe the milestone as complete until every gate below has objective evidence.

### Gate 1 — Governance checkpoint

- Read `docs/STANDARDS_AND_PRACTICES.md` before any release build.
- Read `docs/AUTHORITY_REFACTOR_CONTINUITY.md` before changing runtime behavior.
- Keep this file as the single active live-test target.
- Append verified work to `docs/DEVELOPMENT_HISTORY.md`; do not create another standalone pass-history or audit document.
- Keep all GitHub development on the single `main` branch.

Current checkpoint: the authoritative standards document exists inside the mod source at `tech-priests_src/docs/STANDARDS_AND_PRACTICES.md`. No duplicate repository-root standards file is required.

### Gate 2 — Source installation and static validation

- Confirm `planning_constraints_0646.lua` installs `energy_item_automation_guard_0722.lua` after `energy_family_logistics_0707.lua`.
- Confirm every required hardener module loads and its `install()` function does not return `false` or raise an error.
- Confirm runtime broker services replace existing registrations by service name rather than accumulating duplicate pulses after configuration changes.
- Audit new persistent storage for functions, cyclic tables, LuaObjects stored inside serializable history records, or other save-breaking values.
- Parse every Lua source file with Lua 5.2.
- Validate `tech-priests_src/info.json` as JSON.
- Compile every Python tool under `tools/`.
- Record a successful GitHub Actions source-validation run and its commit SHA.

Current checkpoint: `0722` is wired by commit `ad9cf5c881ae1bc0503e6b72ab8213e9844c5055`. No GitHub Actions run or combined status has yet been recorded for that commit.

### Gate 3 — Factorio load and migration validation

Run all tests with the required dependencies installed.

1. Load the development source in a new Factorio 2.0 game.
2. Place each Cogitator tier needed to exercise the runtime families and allow installation/configuration handlers to finish.
3. Confirm there are no Lua load errors, Factorio API errors, missing module errors, or failed hardener-install messages.
4. Save, exit, reload, and confirm all Tech-Priest storage remains serializable.
5. Load an existing `0.1.672` save with the development source.
6. Confirm configuration-change installation succeeds without duplicating broker services, diagnostics wrappers, reservations, pair state, or active task ledgers.
7. Save and reload the migrated game again.
8. Capture `factorio-current.log` and the automatic emergency diagnostic pair dumps from both the new-save and migrated-save passes.

Every load-time error, serialization error, duplicated service, or corrupted pair is release-blocking.

### Gate 4 — Energy automation ownership guard

Test both manual and externally automated energy entities.

1. Supply a manual boiler with valid fuel and water. Confirm the priest may deliver fuel physically.
2. Attach an inserter that feeds or removes items from the boiler. Confirm readiness reports mark it `external-item-automation-owned` and no new priest fuel task begins.
3. Begin a manual fuel task, then attach automation before pickup. Confirm the uncarried task aborts, its reservation and requests clear, and the machine is not mutated.
4. Begin a manual fuel task, allow the priest to acquire custody, then attach automation. Confirm the task changes to `return-custody` and the carried item is physically returned rather than deleted or inserted.
5. Test a reactor with fresh fuel and spent-cell evacuation.
6. Fill the burnt-result inventory and confirm no fresh fuel is inserted when the burnt result cannot be retained.
7. Remove the required heat connection or fluid path and confirm readiness blocks delivery honestly.
8. Confirm the automatic pair dump reports external reports, aborted tasks, and custody returns while reporting `automation_mutations=0`.

Regression watch: the guard must not disable observation-only readiness, mutate inserters/loaders, change recipes, alter electrical/heat/fluid networks, or seize an entity already managed by external automation.

### Gate 5 — Behavioral integration matrix

Exercise each family independently and then under overlap, interruption, and save/load pressure:

- machine input delivery, output evacuation, trash evacuation, partial insertion, source destruction, destination destruction, and storage-full return;
- ammunition, modules, fuel, burnt results, and incompatible item rejection;
- manual energy service and external automation exclusion;
- rocket-silo ingredient service, trash evacuation, launch interruption, and strict payload/launch-state non-mutation;
- fixed artillery refill and stationary manual artillery-wagon refill, including movement or automatic-mode interruption;
- roboport repair-pack service without construction-robot or logistic-robot population mutation;
- input-fluid and output-fluid network planning, contamination rejection, blocked routes, compatible-network adoption, pipe shortage, and save/load during construction;
- fluid-turret source selection, exact port identity, final-tile connection, route retry limits, and unusual modded fluidbox layouts;
- overlapping Cogitator ranges, simultaneous route proposals, reservation conflicts, and station stock ownership;
- combat interruption during every custody-bearing task;
- save/load during every active task family;
- agreement between movement target, active leaf task, status text, and visible intent line.

For every scenario, verify that physical source removal precedes custody, custody persists until delivery or return, destination inventories are revalidated immediately before insertion, and leftovers are never deleted or duplicated.

### Gate 6 — Release packaging

Only after Gates 1 through 5 pass:

1. Update `info.json` to `0.1.674`.
2. Update changelog and description with verified behavior only.
3. Append the verified milestone, workflow run, tested Factorio version, and migration evidence to `docs/DEVELOPMENT_HISTORY.md`.
4. Run `python tools/package_local.py --overwrite`.
5. Inspect the archive root, output filename, `info.json`, locale uniqueness, required files, and ZIP integrity.
6. Install the packaged archive rather than the source folder and perform one final clean new-save load plus one final `0.1.672` migration load.

The release gate passes only when the packaged archive reproduces the verified source behavior and no unresolved error is being carried forward as a documentation note.