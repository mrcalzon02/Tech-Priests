# Tech Priests — first Cogitator cold-start performance regression 1406–1408

**Status: source implemented, Factorio 2.1.24 runtime A/B comparison NOT YET RUN.** This document is an engine benchmark contract, not a claim that the reported freeze is fixed.

## Source-audited cost centers

**Placement event:** Original `control_legacy_part_002.create_pair` performs native priest spawn positioning, LuaSurface.create_entity priest spawn, original station/priest registration, two physical hidden logistics-support entities, original pair-state/armor/equipment refreshes and initial movement. Other registered on-built callbacks run in the same event. No one phase can be blamed without native time attribution.

**First scheduled service burst:** `efficiency_economy_0595` intentionally sleeps the runtime before any station. `runtime_tick_broker_0600` originally registers most services with `next_due_tick=0`; after first wake, many nonessential planners and scans can run on the same 5-tick pulse. This is a source-supported burst risk, not a measured cause. The movement waypoint aggregator may contribute subsequent path costs, but the native pathfinder and graphical overlay must be distinguished from Lua script time.

## Implemented mitigation and profiling

`runtime_tick_broker.stagger_first_station_wake_1407(pair)` runs once after the original first station/priest is registered. Lifecycle, dispatcher, combat, movement, recovery, safety and authority services remain immediately eligible. All **noncritical, enabled, already-due** services are deterministically spread across at most 120 ticks (2s at 60 UPS). No service is disabled, deleted, given new item authority, or permanently postponed. Original operation continues on existing broker cadences after the first pulse. Audit state is under `storage.tech_priests.runtime_tick_broker_0600.first_station_wake_1407`.

Opt-in native first-station profiler command, before placement: `/tp-profile-first-station-1406 on`. When enabled, it times the full native build-event registry, each original create_pair phase, and each broker service's first actual callback during 300 ticks. It uses Factorio 2.1 `helpers.create_profiler(false)` with older API fallback. Every LuaProfiler remains ephemeral module-local, and LocalisedString log records preserve the native timing values; game.storage contains only scalar metadata. Default is OFF.

## Headless A/B: same source SHA, Factorio 2.1.24, CPU and seed

Run from repository root using the self-hosted Factorio executable. Supply `--dependency-mods` consistently for your modpack. Exact command forms:

    python3 tools/run_factorio_isolated_service_scenario.py --scenario first-station-baseline-1408 --factorio "/path/to/factorio" --seed 907260 --ticks 2000
    python3 tools/run_factorio_isolated_service_scenario.py --scenario first-station-placement-unprofiled-1408 --factorio "/path/to/factorio" --seed 907260 --ticks 2000
    python3 tools/run_factorio_isolated_service_scenario.py --scenario first-station-placement-1408 --factorio "/path/to/factorio" --seed 907260 --ticks 2000
    python3 tools/compare_first_station_benchmarks_1408.py --output-dir test-artifacts/isolated-service --source-sha EXACT_40_CHARACTER_TESTED_MAIN_SHA

Each isolated case creates a disposable mod copy and fresh seeded world, rather than reusing an existing scenario with stations at game initialization. All three invoke native `--benchmark-verbose all`. The readback tool requires real fixture PASS markers and parsable per-tick metrics in **nanoseconds**; otherwise it refuses to generate performance deltas.

- Baseline: station-free world, profiler disabled.
- Placement-unprofiled: real `junior-cogitator-station` created at tick 600 via `surface.create_entity{raise_built=true}`, with genuine `script_raised_built` callback, no profiler overhead. This is the unbiased performance comparator.
- Placement: identical native station event plus opt-in profiler. Use to identify expensive callbacks, NOT to claim unbiased placement timing.

The fixture validates a real native original pair/precise priest entity, plus completed one-time broker stagger, without invented station or physics receipts. It records checkpoints at ticks 540, 600, 605, 660, 780, 1200, 1800. Compare native wholeUpdate/scriptUpdate/pathfinder/entity/garbage/terrain times over windows 100–539 (before), 590–629 (placement), 630–779 (cold wake), 780–1199 (after wake), 1200–1899 (settled). Track **max and p95** as well as mean. The 60-UPS update budget is approximately **16.667ms per tick**.

Runner artifact path: `test-artifacts/isolated-service/first-station-*/benchmark.log`; comparison output `test-artifacts/isolated-service/first-station-performance-comparison-1408.json`. Keep original logs, source SHA, Factorio version, runner CPU and dependency mod list. Do not misinterpret create-save success as physical placement acceptance.

## Manual graphical cold-placement check

Headless cannot see graphical overlay performance, or exactly reproduce a player's on_built_entity input. On fresh normal game (no initial Cogitator), press **F4** and enable `show-fps` and `show-time-usage`, optionally `/perf-avg-frames 1000`. Place the FIRST Cogitator manually; record FPS/UPS and native update maximums. Repeat on another identical seed with profiler disabled, and one with `/tp-profile-first-station-1406 on` enabled before placement.

If the problem peaks in the build-event frame, inspect priest collision search and hidden caches. If the spike peaks 5–120 ticks afterward, inspect broker and movement/scan services. If Script update stays low but Entity update, Path finder or rendering spikes, do NOT blame Lua planners prematurely.

## Source unit regressions

    texlua tests/unit/first_station_wake_1407.lua
    texlua tests/unit/first_station_cold_profile_1406.lua

These cover forty noncritical and seven critical mocked services, eventual execution without cancellation, once-per-game original pair ownership, opt-in timer fast paths, and no LuaProfiler storage serialization. Source tests are not proof of Factorio 2.1.24 runtime behavior. Reproduce and measure before declaring the performance hitch repaired.

**Do not disable scheduled tasks or other native engine services.** A reproducible gameplay-freezing first station event can be a serious usability blocker; unrelated visual/style optimizations remain diagnostics per project release rules.
