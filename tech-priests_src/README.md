# Tech Priests

Tech Priests is a Factorio 2.0 mod built around Cogitator Stations, paired
Tech-Priests, emergency Martian industry, station-owned logistics, autonomous
construction planning, defensive perimeters, and Machine-Spirit maintenance.

Current source version: `0.1.646`.

## Active development focus

- Decompose the next science requirement into minimum viable production nodes.
- Build only technology-unlocked infrastructure.
- Keep production construction inside station yards and defense construction on
  station-owned perimeter arcs.
- Migrate construction placement into one queue/reservation/order/dispatcher
  executor path.
- Configure recipes, supply machines, extract products, and route products into
  downstream recipe demand.

## Runtime contracts

- `docs/STANDARDS_AND_PRACTICES.md`: mandatory project and packaging rules.
- `docs/BEHAVIOR_ORDER_OF_OPERATIONS.md`: actual behavior ownership and desired
  construction execution path.
- `docs/AUTHORITY_REFACTOR_CONTINUITY.md`: authority boundaries and migration method.
- `docs/CURRENT_TESTING_GOALS.md`: current live-test target.
- `docs/DEVELOPMENT_HISTORY.md`: consolidated historical record.

Audio manifests and generation prompts remain under `docs/` because they are
stable references for shipped sound assets.

## Packaging

Run `python tools/package_local.py` from the repository root. The packager checks
locale uniqueness and ZIP root/integrity. A release candidate still requires an
in-game Factorio load test.
