# Unified Factorio modpack test status

**Evidence checkpoint:** 2026-11-05 local (2026-11-06 UTC)
**Active CI:** [Factorio combined Mod Portal integration](../.github/workflows/factorio-combined-modpack.yml)
**Current passing run:** https://github.com/mrcalzon02/Tech-Priests/actions/runs/42151378921
**Prior historical red-gate run:** https://github.com/mrcalzon02/Tech-Priests/actions/runs/42149797508

## Current unified native smoke result

**PASS:** [GitHub Actions run #42151378921](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42151378921), commit `c8fe08366e4093d903a6d747f99ad8c97a63914c`, completed 2026-11-06 02:38 UTC. One Factorio 2.1.24 unified job passed authenticated staging, map creation, **123,000-tick native endurance**, and **second-process 1,200-tick reload of the initial save**. The missing legacy `40kvehicles-AAI-fix` no longer blocks the gate.

**Meaning:** Full required *current smoke modpack* installed and loaded with no reported fatal error, and the endurance/reload smoke finished. AAI vehicle route/stop/resume is **assumed compatible by explicit user direction**, not functionally tested. Tanks for Bob 1.8.95 and Tech-Priests still use disposable 2.1 test metadata staging; no unsupported public 2.1 release is claimed. Functional scenario, multi-client and save-state custody coverage remains separate.

## What is actually proven

The single **Factorio 2.1.24** combined CI job successfully:

1. Obtained an official 2.1.24 Linux headless engine.
2. Authenticated to the Factorio Mod Portal using repository secrets without exposing secret values.
3. Resolved, downloaded, SHA-1-verified and staged **13 external mod ZIPs** including required transitive dependencies.
4. Enabled official **base, elevated-rails, quality, recycler, space-age** modules simultaneously.
5. Staged the current Tech-Priests source and required domestic / 40K mods together.
6. Created a real Factorio save without a fatal prototype error.
7. Completed **123,000 benchmark ticks** (native engine log: `Performed 123000 updates in 32524.832 ms`).
8. Loaded the same save in a second, independent headless process and completed **1,200 additional ticks**.
9. Recorded all native logs, installed-version inventory, original Mod Portal ZIP SHA-1 values, verdict and save in a GitHub Actions artifact.

**Historical gate result (run #42149797508):** `native_smoke=true`, `full_required_modpack_pass=false` because the now-retired AAI fix was mandatory at that checkpoint. This does not describe later runs. Native startup and endurance are not proof of every gameplay behavior.

## Exact external mod versions verified in the 2.1 unified run

| Mod Portal ID | Version | Notes |
| --- | --- | --- |
| `mechanicist-factorio` | 0.1.3 | Published Factorio 2.1 release |
| `tanks_for_bob_fork` | 1.8.95 | **2.0 release**; changed **only its temporary runner-copy metadata** for a 2.1 diagnostic smoke; **not** a distributable 2.1 build |
| `mechanicus-reborn` | 0.0.3 | Factorio 2.1 release |
| `aai-programmable-vehicles` | 0.9.2 | Factorio 2.1 release |
| `aai-signals` | 0.8.0 | Transitive dependency |
| `informatron` | 0.5.0 | Transitive dependency |
| `kj_40kbaneblade` | 2.1.0 | Vehicle |
| `kj_40kdreadnought` | 2.1.0 | Vehicle |
| `kj_40klemanruss` | 2.1.0 | Vehicle |
| `kj_40kpredator` | 2.1.0 | Vehicle |
| `kj_fuel` | 2.1.1 | Transitive dependency |
| `kj_servoskull` | 2.1.0 | Robot |
| `kj_vehicles` | 2.2.1 | Shared vehicle framework |

**Tech-Priests 2.1 caveat:** Current mod source metadata still declares Factorio 2.0. A disposable 2.1 runner copy temporarily changes the Factorio version and adjusts >=2.0.0 constraints to >=2.1.0 **without removing hard or optional dependency declarations**. Preserving those edges fixed a load-order bug where Tech-Priests' Thetazine item was created before Space Age had created the vanilla thruster entity to clone.

**Checksum evidence:** Some KJ vehicle mods have zero prototype checksums and no `Loading mod ... (data.lua)` line. The acceptance parser now recognizes Factorio's own `Checksum of mod: 0` entries as proof they are enabled; this is not an excuse to omit required mods.

## Separate 2.0 baseline

The earlier [Factorio 2.0.77 combined run](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42149466493) SHA-1-verified **14 external ZIPs**, including Tanks for Bob 1.8.95 and Mechanicist 0.1.1, created a save, and completed 3,600 benchmark ticks without native load/runtime failures. Its full-modpack gate remained blocked by the unavailable legacy AAI fix. The original [Factorio runtime workflow](../.github/workflows/factorio-runtime-tests.yml) retains dedicated 2.0 regression testing.

## Legacy AAI compatibility decision (2026-11-05 local)

The user explicitly retired `40kvehicles-AAI-fix` as an outdated Factorio 1.1-era compatibility workaround. It is **not required, downloaded, or release-blocking** in the 2.0 or 2.1 unified smoke contracts. The current AAI Programmable Vehicles and KJ vehicle stack remain required and are presumed compatible. This is a **risk acceptance**, not a claim that real movement/stop/resume gameplay tests have passed.

This change applies to the retired patch specifically, not to future fatal engine errors, broken required Mod Portal downloads, or actual unresolved gameplay failures.

## Remaining integration evidence

- **Retired legacy AAI fix:** No longer a blocker, and no replacement port is required. Current AAI/KJ behavior is assumed compatible and remains **unverified**, not a separate release gate.
- **Tanks for Bob 2.1 release:** The current 1.8.95 ZIP is officially targeted at Factorio 2.0. The temporary metadata bridge verifies integration behavior only. Authoritative native 2.1 packaging and standalone publication require separate approval and proof.
- **Nonfatal KJ vehicle diagnostics:** `kj_vehicles/data-final-fixes.lua:775` reports four vehicle-turret lookup warnings; startup and endurance still passed. Confirm these are benign for mounted weapons before granting combat compatibility.
- **Functional scenario evidence still missing:** Full Tech-Priests ranked resource acquisition, science-production and hostile-defense assertions under this exact unified pack; actual AAI vehicle orders/stop-resume; real Servo-Skull roboport/logistic construction operations; machine recipes and research progression; persisted simulation state through a new-save checkpoint and process restart; dedicated-server multiplayer clients.

## Follow-on test sequence

1. Continue the **one unified Factorio 2.1 profile**, not a matrix. Prioritize real Servo-Skull robot delivery and Tech-Priests factory scenarios; vehicle movement checks may be diagnostic but are no longer a mandatory gate solely because the legacy fix is absent.
2. Wire existing Tech-Priests ranked industrial / combat scenario harness into the same combined pack and run it for 123,000 ticks with its assertion tags, not only an empty-map endurance benchmark.
3. Create a runtime save checkpoint after gameplay and reload it in a new process. The current extra 1,200 ticks only reloads the initial created save.
4. Investigate KJ vehicle turret warnings and any actual ammunition / weapon behavior failures.
5. Permit the unified **native startup/endurance** gate to go green without the retired AAI fix when its actual required mods load and simulation completes. Keep broader gameplay/release readiness separate; do not change shipping Factorio-version declarations to manufacture evidence.

## Code and evidence

- [Unified authenticated installer and dependency resolver](../tools/ci_factorio_combined_modpack.py)
- [One-profile combined runtime workflow](../.github/workflows/factorio-combined-modpack.yml)
- [Mandatory 2.1 integration contract](../tests/modpacks/required_21_1271.json)
- [Completed 123,000-tick run and downloadable evidence](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42149797508)
