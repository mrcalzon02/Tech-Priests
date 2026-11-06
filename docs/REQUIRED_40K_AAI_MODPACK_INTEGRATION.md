# Mandatory Mechanicist + AAI + Warhammer 40K integration contract

> **Historical contract (superseded 2026-11-05 local).** The old statements below requiring `40kvehicles-AAI-fix` and a red gate for its absence are **no longer current**. By explicit user decision, the Factorio 1.1-era patch is retired and nonblocking. The [current native-process integration audit](CROSS_MOD_NATIVE_PROCESS_INTEGRATION_AUDIT.md), [2.1 dependency contract](../tests/modpacks/required_21_1271.json), and [passing unified smoke](UNIFIED_FACTORIO_MODPACK_TEST_STATUS.md) are authoritative. Other native behavior assertions remain unverified unless separately proven.


**Hard requirement (2026-11-05):** The exact named mod IDs are hard dependencies in `tech-priests_src/info.json` and a hard CI/release integration profile in `tests/modpacks/required_40k_1270.json`. This is an engineering acceptance requirement, not a claim that tests passed.

| Mod Portal ID | Required functional integration |
| --- | --- |
| `mechanicist-factorio` | Real prototype names preserved through UI retheme; recipes/technologies resolved by engine |
| `tanks_for_bob_fork` | All additional production/research/tank supplies treated as real inventories |
| `kj_40kbaneblade` | Baneblade vehicle, fuel, guns/ammo, technology and recipes |
| `aai-programmable-vehicles` | Real AAI unit navigation and behavior |
| `kj_40kpredator` | Actual vehicle control through AAI, including stop/resume |
| `kj_40klemanruss` | Actual vehicle control through AAI, including stop/resume |
| `kj_40kdreadnought` | Actual vehicle control through AAI, including stop/resume |
| `kj_servoskull` | Servo-Skull cosmetic adaptation of actual construction/logistic robots; preserve native roboport/robot network authority |
| `40kvehicles-AAI-fix` | **Mandatory behavioral functionality**; a strict dependency cannot load on Factorio 2.0 until a compatible port exists |

All eight named compatible-mod entries are required. All transitive *required* dependencies must also be installed and verified. The words "other 40K mods" remain an expansion obligation; do not claim unnamed mods tested. Explicit additional names become required matrix entries.

## Blocking compatibility limitation

The public [AAI fix](https://mods.factorio.com/mod/40kvehicles-AAI-fix/downloads) has ONLY Factorio 1.1 releases, latest 1.1.2. It modifies Predator, Leman Russ and Dreadnought for the AAI controller and changes technology prerequisites/costs. Do not inject its 1.1 archive into Factorio 2.0.77, invent an equivalent, or add an unresolvable `info.json` hard dependency. A licensed/clean-room port or independently engineered 2.0 equivalent must first pass actual engine movement and recipe checks. Until then **mandatory integration acceptance is RED** even if mod loading and other tests pass.

Servo-Skull's 2.0.4 download is explicitly listed on the [official portal](https://mods.factorio.com/mod/kj_servoskull/downloads). It is a *visual robot replacement*, not a new resource production route. Verify real robot/roboport objects and transfers without substituting fake robot identities.

AAI's last explicitly 2.0 release is 0.8.5: https://mods.factorio.com/mod/aai-programmable-vehicles/downloads. Select newest available 2.0 for every mod, never the newer 2.1-only releases. No third-party protected mod ZIPs or artwork are committed here.

## Remote verification stages

1. **Source test:** `python3 tools/check_required_40k_modpack_1270.py` verifies hard metadata, manifest, fix blocker and Servo-Skull requirement. Source-validation CI runs automatically.
2. **Remote download/install:** Existing `factorio-runtime-tests.yml` uses `FACTORIO_USERNAME` and `FACTORIO_TOKEN` to install transitive required mod dependencies in an isolated Factorio 2.0.77 directory. `--installed <dir>` is an explicit fail-closed proof that all eight archives exist.
3. **Native Factorio load/run:** Existing 123,000-tick baseline science/combat benchmark and separate-process save/reload run against this full modpack. Mod errors, missing packages, credential failures and unproven required runtime behavior are **FAIL**, not converted to skipped tests.
4. **Strict fix gate:** `--portal` obtains current Mod Portal metadata and returns **FAIL** until a 2.0-compatible fix and actual vehicle movement behavior are verified. This is intentionally red; it cannot claim engine behavior based on metadata or a unit stub.
5. **Next work:** Add a native disposable AAI vehicle test world for each of the three vehicle types, authentic waypoint/remote control, collision/obstruction, fuel/ammo and stop/resume. Also test Servo-Skull robots building real ghosts, carrying counted materials, and reloading. Preserve native game power, coverage, inventory, reachability and transport as sole authorities.
6. **Release gate:** Complete the above behavioral evidence, preserve logs and exact commit/run identifiers. Never mark complete on a successful download, Lua parser pass or screenshot.

**Known status as of contract creation:** 2.0-compatible upstream AAI fix is unavailable; full modpack native load, AAI behavior and Servo-Skull robot delivery are not yet proved. Existing tests must be inspected for actual PASS/FAIL before claiming success.
