# Factorio 2.1.24 migration — remote native-engine validation

The user supplied the installed version banner **2.1.24 (build 87808, expansion, win64)** on 2026-11-05. This is the migration **target**, not a claim that the source is already ready for release. A Linux x64 headless engine of the *same version* must drive CI smoke testing. Never use a moving /stable URL.

**Do not silently downgrade Mechanicus Reborn.** The newest officially published Factorio 2.1 release is **0.0.3**, rather than the 2.0-only 0.0.1. It is mandatory for this test profile. AAI Programmable Vehicles live 2.1.24 audit selected 0.9.2 for 2.1; King Jo's Baneblade, Predator, Leman Russ, Dreadnought and Servo-Skull list 2.1.0. The remote audit dynamically selects the latest *2.1* version from each mod's authoritative release metadata.

## First native failure and cross-version source repair

Run https://github.com/mrcalzon02/Tech-Priests/actions/runs/42131282245 proved that Factorio **2.1.24 build 87808** downloads and starts on GitHub Linux. The first core create crashed at `blackstone-fragment`: `ItemPrototype::fuel_category was removed. Please use ItemPrototype::fuel_categories.` This is a genuine 2.1 migration defect, not a Mod Portal problem. The repair adds `prototypes/compatibility/native_fuel_categories_1272.lua` to select Factorio 2.0 singular or Factorio 2.1 plural native field from the observed base version. A separate Lua regression checks both paths. Neither production metadata nor 2.0 requirements are changed.

The first Mechanicus run also exposed that GitHub Actions has no `FACTORIO_USERNAME`/`FACTORIO_TOKEN`; its archive cannot be downloaded there yet. Do not present its source metadata audit as a native Mechanicus runtime pass.

## Honest blocker inventory (2026-11-05)

- [Mechanicist Factorio](https://mods.factorio.com/mod/mechanicist-factorio/downloads): latest 0.1.1, *2.0 only*. Needs a tested 2.1 migration/release.
- [Tanks! for Bob!! fork](https://mods.factorio.com/mod/tanks_for_bob_fork/downloads): latest 1.8.93, *2.0 only*. Needs a tested 2.1 migration/release.
- [TheKingJo 40K AAI fix](https://mods.factorio.com/mod/40kvehicles-AAI-fix/downloads): latest 1.1.2, *1.1 only*. Required functionality needs port or equivalent plus live AAI behavior proof.
- A 2.1 Factorio modpack engine run, genuine robot delivery, working AAI movement, the original 123k endurance, and save/reload are not yet proven.

The protected Tech Priests `tech-priests_src/info.json` stays at 2.0 until successful migration. Do **not** advertise current production releases as 2.1-compatible on the basis of an isolated test-only metadata adjustment.

## Tests: existing Factorio runtime GitHub Actions workflow

The current `.github/workflows/factorio-runtime-tests.yml` now has a separate 2.1.24 job (no new workflow created):

1. Fetch official `/api/mods/<mod>/full` metadata for nine mandatory mods plus the AAI fix and store `migration-portal-report.json`. Missing/older releases are blockers, never passed via a fallback.
2. Download and verify exactly `2.1.24/headless/linux64`. This matches the user version, and preserves the existing 2.0.77 baseline in a separate job.
3. Run a **real Factorio 2.1.24 native create + 600-tick core smoke**, using a disposable Tech Priests copy with only a temporary `factorio_version=2.1` metadata patch. This tests source migration in isolation, not the required modpack.
4. Acquire **Mechanicus Reborn latest Factorio 2.1** and its hard transitive dependencies using existing `FACTORIO_USERNAME` and `FACTORIO_TOKEN` secrets, then create and benchmark another disposable Factorio save. If missing secrets or broken dependencies, this step fails and retains the report.
5. Apply an **unwaivable full-modpack gate**. The gate fails while Mechanicist, Tanks, the AAI fix, full 123k runtime, authentic vehicles/robots or save/reload are not confirmed. This is intentional, not a reason to disable the test.
6. Upload raw reports, logs, staged metadata and smoke saves, and publish a separate `tech-priests/factorio-2.1-migration` commit status. The old baseline job's status remains separate.

`python3 tools/run_factorio_21_migration_1271.py --static` is a network-free self-test run in Source validation.

**Do not claim:** successful metadata downloads prove that mods loaded, a 600-tick smoke proves late-game factory behavior, or a 2.1 test-only copy is a distributable build.

**Next integration work:** port Mechanicist and Tanks on their own source trees, prepare/verify AAI fix functionality, test a full 2.1 modpack, run existing 123k and save/reload, and then change the production metadata after genuine evidence.

## 2.1.24 second native prototype blocker — hidden logistic chests

The migration job at https://github.com/mrcalzon02/Tech-Priests/actions/runs/42138112208 reached the hidden requester chest but failed:
`LogisticContainerPrototype::animation, landing_location_offset, opened_duration and animation_sound were moved to LogisticContainerPrototype::robot_door.`

The requester and active provider caches are deep copies of native 2.1 chests. The `native_robot_door_1273.lua` helper now puts the hidden 1px docking animation and zero landing offset in the actual 2.1 `robot_door` schema, clearing removed top-level fields. For Factorio 2.0 the old top-level fields are retained. `hidden_logistic_cache_robot_door_21_1273.lua` covers both versions.

Proof requires **engine create + 600 ticks on native 2.1.24**, not merely Lua static tests.

## 2.1.24 third native prototype blocker — recipe product probability

Run https://github.com/mrcalzon02/Tech-Priests/actions/runs/42138471172 got past the hidden robotic door validation. Factorio 2.1 then rejected `speed-module.results[1]` due to removed product `probability`. Tech Priests adds zero-probability Mechanical Detritus to recipe outputs and also has its own stochastic product recipes.

The final-fixes adapter `native_recipe_schema_1274.lua` now migrates legacy `probability` to `independent_probability` without changing values, including zero. It also migrates legacy `category` and `additional_categories` into 2.1 `categories` while preserving 2.0. The adapter is run **after** all Detritus and custom recipe creation, including modification of base recipes. Explicit source tests check original recipe identity, counted outputs, zero chance, recycling category and idempotence. A native 2.1 engine create and benchmark still must pass before accepting the repair.

## Thetazine-thruster resolve failure: isolated harness load order

Run https://github.com/mrcalzon02/Tech-Priests/actions/runs/42138836690 passed the previous recipe-schema barrier but rejected an unresolved `thetazine-thruster` placement prototype. Examination of the isolated migration runner revealed it staged `info.json` with **only** `base >= 2.1.0`. When Space Age is installed, Factorio consequently loads Tech Priests' `data.lua` before Space Age's vanilla `thruster` prototype, so its donor-cloning function correctly declines to fabricate a nonexistent thruster even though the recipe then refers to that name.

The production `tech-priests_src/info.json` already includes `? space-age >= 2.0.0`. The isolated 2.1 runner now **preserves 2.1-versioned optional Space Age, Quality, and Elevated Rails ordering**, and adds its required Mechanicus Reborn release only when running that profile. This repairs the test harness without forging a thruster or weakening the native engine authority rule. Prove the correction with an actual 2.1.24 new-game create and native benchmark.

## 2.1 missing recipe category after DLC load-order correction

Run https://github.com/mrcalzon02/Tech-Priests/actions/runs/42139177932 reached prototype ID binding but rejected `basic-crafting`: a legacy recipe category is absent from Factorio 2.1. The emergency assembler hardcoded `basic-crafting` alongside crafting/electronics/advanced-crafting, while only checking `pressing` dynamically.

`native_crafting_categories_1275.lua` now selects **all** permitted emergency-workshop categories exclusively from `data.raw["recipe-category"]`. It preserves legacy `basic-crafting` in a 2.0 mod set if that category exists, omits it on 2.1, and still permits a real modded `pressing` category. It never invents machine capabilities or permits smelting. Unit tests check both prototype inventories; native 2.1.24 acceptance still requires a real load and simulation.

## Real 2.1.24 123k industrial/combat endurance + save/reload acceptance

After core and Mechanicus Reborn 0.0.3 **both passed 600 native ticks** in run https://github.com/mrcalzon02/Tech-Priests/actions/runs/42139389697, the next acceptance phase mounts the existing `all-ground-ranks` fixture in a **disposable** 2.1 migration copy and runs 123,000 actual Factorio ticks. This is independent of the blocked upstream 2.1 modpack and the protected 2.0 runtime baseline.

The runner checks all six native acceptance markers: living pairs, recovery, duration diagnosis, actual bootstrap-to-science, real Conclave research/force schism, and hostile-damage defense, with no fatal markers. Next it executes the existing separate-process autosave/reload engine script. It records its own result JSON only if **both** benchmark and persistence checks pass.

A distinct GitHub commit status `tech-priests/factorio-2.1-core-endurance` reports this outcome independently; the broader, still-blocked required third-party modpack acceptance remains RED. Core success is not proof that future Mechanicist, Bob, 40K AAI or Servo-Skull releases have been validated.

## 2.1 runtime LuaRecipePrototype and stochastic product readers

Source audit found two latent errors that 600-tick startup does not exercise: `scripts/magos_ratio_planning.lua` attempted the removed 2.1 `recipe.category` API and treated all `independent_probability` recipes as 100% deterministic; `scripts/core/emergency_facility_doctrine.lua` directly indexed the removed `category` field during smelting/refusal and diagnostic work.

Both now probe 2.1 `categories` before 2.0 `category` with guarded reads, preserving real native recipe classifications, and Magos yield computation now accounts for 2.1 `independent_probability * (shared_probability.max - shared_probability.min)`, including true zero chance. `runtime_recipe_schema_21_1276.lua` extracts and tests the actual runtime code against strict API test fixtures. No imaginary recipe or production output is counted.
