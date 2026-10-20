# Tech Priests — Authoritative Source

Tech Priests is a Factorio 2.0 mod with Cogitator Stations, paired
Tech-Priests, emergency industry, logistics and autonomous construction.

**Protected packaged baseline:** `0.1.672` (`info.json`).  
**Development lane:** `0.1.674-dev` on `main`.  
**Recovery:** Stages 0–4 source-implemented; Stage 5 engine acceptance open.

## Recovery work order

Ordinary feature expansion is paused. Follow
`../RECOVERY_REPAIR_SEQUENCE.md` and
`../docs/STANDARDS_AND_PRACTICES.md`.
Canonical history: `../docs/DEVELOPMENT_HISTORY.md`.
Live testing matrix: `docs/CURRENT_TESTING_GOALS.md`.

The dispatcher selects one action family, and the movement controller
owns physical movement. The `priest_lifecycle_authority_0499` alone
owns re-imprint transactions. The `pair_lifecycle` facade must fail
closed if 0499 is missing, fails, or returns non-true; generated 0298
helpers are internal presentation adapters, not a fallback authority.

## Verification and packaging

Run `texlua tests/unit/pair_lifecycle_install.lua` from repository root.
A passing unit test does not prove Factorio loading, migration, save/reload,
runtime behavior, or profiler acceptance.

The canonical packager is `tools/package_local.py` at repository root.
Release authorization remains blocked. Published `v0.1.674-rc.3` is
experimental, not a verified release.
