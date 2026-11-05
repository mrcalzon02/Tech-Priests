# Factorio 2.1.24 migration — remote native-engine validation

The user supplied the installed version banner **2.1.24 (build 87808, expansion, win64)** on 2026-11-05. This is the migration **target**, not a claim that the source is already ready for release. A Linux x64 headless engine of the *same version* must drive CI smoke testing. Never use a moving /stable URL.

**Do not silently downgrade Mechanicus Reborn.** The newest officially published Factorio 2.1 release is **0.0.3**, rather than the 2.0-only 0.0.1. It is mandatory for this test profile. AAI Programmable Vehicles currently lists 0.9.1 for 2.1; King Jo's Baneblade, Predator, Leman Russ, Dreadnought and Servo-Skull list 2.1.0. The remote audit dynamically selects the latest *2.1* version from each mod's authoritative release metadata.

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
