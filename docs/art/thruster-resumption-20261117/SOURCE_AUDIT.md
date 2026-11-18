# Thruster source audit — 17 November 2026

Read-only audit of the linked Tech-Priests worktrees. At audit time the model-production HEAD was `991d558e`; local `origin/main` was `9b17b3c9`. No fetch or publication was performed. The Git history is shallow, so originating art commits cannot reliably be attributed from this checkout. Committed tree presence was verified directly with `git cat-file` and `git ls-tree`.

| Native prototype | Committed and integrated | Remaining work |
| --- | --- | --- |
| `hydrogen-thruster`, 4×4 | Hydrogen V01 Blender/GLB, four runtime PNGs and late graphics module in both refs; seven source poses, native frozen-pose/cap/shadow review | Powered native clock, actual consumption/thrust, expanded machinery parity, final appearance/remnant/icon gates |
| `thetazine-thruster`, 5×5 | V04 source35 Blender/GLB, nine runtime PNGs and late graphics module in both refs; 64 body/light/shadow clocks, cold and ordinary native states | Actual consumption/thrust and regression acceptance; owner appearance feedback and remnant/icon refinement |
| `void-fusion-thruster`, 1×9 | Native prototype, items/recipe/research, corrected placement and script-serviced electric drive; legacy sprite body | Authored narrow body, animation, surface/export/import and powered native acceptance |
| `large-void-fusion-thruster`, 4×4 | Separate native prototype, items/recipe/research, corrected placement and script-serviced electric drive; wide legacy sprite | Independent wide source construction, animation, surface/export/import and powered native acceptance |

The liquid thrusters use native liquid-hydrogen/oxygen and thetazine/water. The fusion family uses a hidden electric-energy-interface (`12MW` continuous sink, `30MJ` buffer) and hidden native fluids serviced by runtime code. No visible pipes should be invented. Performance effectivity scales from the vanilla donor are respectively 0.25, 0.45, 0.10 and 0.35. This describes implemented tuning, not measured thrust acceptance.

Relevant authority files:

- `tech-priests_src/prototypes/compatibility/space-age.lua`: four prototype constructors, recipes/research, electric sink and performance tuning.
- `tech-priests_src/prototypes/compatibility/thruster-mounting-visuals.lua`: fixed north direction, native edge rules and liquid pipe/cap alignment.
- `tech-priests_src/data-final-fixes.lua`: late Hydrogen V01 and Thetazine V04 requires are committed in HEAD and local origin/main.
- `tech-priests_src/scripts/generated/control_legacy_part_002.lua`: electric sink registration, removal and native fluid servicing.
- `tests/unit/native_thruster_fluid_21_1278.lua`: tests native fluid acceptance/refusal and old API fallback; it is not a propulsion test.
- `docs/art/thetazine-thruster-v04/LEAF_COOLING_CANDIDATE.md`: current V04 integration record supersedes historical V01–V03 status.

No uncommitted/untracked changes were found under existing thruster source, art, generated modules, compatibility or evidence paths during this audit. Other dirty files belong to concurrent work and were not changed. Relevant source is text-identical across model-production, hydrogen-production and colony-integration; differences in raw service-code hashes were line endings. These are linked worktrees sharing `local-validation/sources/Tech-Priests/.git`.

Read-only personal-installation observation: `%APPDATA%/Factorio/mods` contains Tech Priests 0.1.681, 0.1.683 and 0.1.684 folders. Each contains the two late graphics imports, modules and sampled runtime PNGs matching model-production. Tech Priests is enabled in `mod-list.json`. The last normal `factorio-current.log` begins 15 November 2026 and records Factorio 2.1.24 Steam loading Tech Priests 0.1.681 and Space Age. This establishes installed presence and a recorded load, not that 0.1.684 is the active session or that a packaged release passed propulsion acceptance. No personal installation was modified.

Continuation is parallel and deliberately scoped: recover current committed editable sources, test all four native propulsion paths in an isolated fixture, and author separate narrow/wide fusion construction candidates. Neither construction candidate is runtime promotion or owner appearance acceptance.
