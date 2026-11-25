# Catalog continuation: native map-cursor reload parity

This fixture tests the multiplayer load boundary without replacing the catalog
owner. A running host retains module locals; a joining client reloads them. Both
must advance the same saved catalog job by the same number of work units and
publish on the same continuation pulse.

Factorio's modified `next()` and `pairs()` iterate in insertion order. The
fixture verifies that order again after an actual native save/load; it does not
model Factorio serialization by arbitrarily rehashing stock Lua tables.

Sources:

- [Factorio's modified Lua functions](https://lua-api.factorio.com/latest/auxiliary/libraries.html)
- [Multiplayer and save lifecycle](https://lua-api.factorio.com/latest/auxiliary/data-lifecycle.html)

## What it checks

The real catalog scans 400 native ore entities, then stops inside ownership
retirement with a nonempty saved map cursor. It records the uninterrupted host's
remaining pulse trace, restores the checkpoint with its native insertion order
and aliases, and saves it. Loading that save must reproduce every remaining
cursor, phase, work count, query count, and publication pulse. Published totals
and all 400 ownership claims must agree. The fixture uses a deliberately small
16-work/1-query limit to expose an extra traversal immediately.

The production fix keeps progress entirely in the saved cursor. Local prototype
and owner-index cache misses also leave saved diagnostic state unchanged. Their
warm/fresh parity is covered by `station_catalog_continuation_1498.lua` and
`catalog_owner_index_1496.lua`.

This is a targeted native reload simulation of the joining-client boundary. It
is not a two-process network session or a performance acceptance benchmark.

## Run on Factorio 2.1.25

From the repository root, select an isolated directory and the exact headless
engine/data paths:

```sh
export TP_FACTORIO=/absolute/path/to/factorio/bin/x64/factorio
export TP_READ_DATA=/absolute/path/to/factorio/data
export TP_PROBE_ROOT=/absolute/path/to/isolated/catalog-map-reload

python3 - "$TP_PROBE_ROOT" "$TP_READ_DATA" <<'PY'
import json
import pathlib
import shutil
import sys

repo = pathlib.Path.cwd()
target = pathlib.Path(sys.argv[1]).resolve()
mod = target / "mods/catalog-map-reload-probe"
core = mod / "scripts/core"
core.mkdir(parents=True, exist_ok=True)
modules = (
    "runtime_event_registry", "efficiency_economy_0587", "station_catalog",
    "catalog_dense_scan_1478", "entity_identity_1481", "catalog_gui_layout_1483",
    "station_catalog_reuse_guard_1484", "catalog_owner_index_1496",
)
for name in modules:
    shutil.copy2(repo / "tech-priests_src/scripts/core" / (name + ".lua"), core)
shutil.copy2(repo / "tests/scenarios/catalog-continuation-map-reload/control.lua",
             mod / "control.lua")
(mod / "info.json").write_text(json.dumps({
    "name": "catalog-map-reload-probe", "version": "0.1.0",
    "title": "Catalog map reload native probe", "author": "Tech-Priests tests",
    "factorio_version": "2.1", "dependencies": ["base >= 2.1.0"],
}))
(target / "mods/mod-list.json").write_text(json.dumps({"mods": [
    {"name": "base", "enabled": True},
    {"name": "catalog-map-reload-probe", "enabled": True},
]}))
(target / "config.ini").write_text(
    "[path]\nread-data=" + str(pathlib.Path(sys.argv[2]).resolve()) +
    "\nwrite-data=" + str(target / "userdata") +
    "\n[other]\ncheck-updates=false\n")
PY

"$TP_FACTORIO" --config "$TP_PROBE_ROOT/config.ini" \
  --mod-directory "$TP_PROBE_ROOT/mods" \
  --create "$TP_PROBE_ROOT/checkpoint.zip" > "$TP_PROBE_ROOT/create.log" 2>&1

"$TP_FACTORIO" --config "$TP_PROBE_ROOT/config.ini" \
  --mod-directory "$TP_PROBE_ROOT/mods" \
  --benchmark "$TP_PROBE_ROOT/checkpoint.zip" \
  --benchmark-ticks 120 --benchmark-runs 1 > "$TP_PROBE_ROOT/reload.log" 2>&1
```

Require `TP-CATALOG-MAP-CREATE`, `TP-CATALOG-MAP-ORDER`, and
`TP-CATALOG-MAP-PASS`, each with `passed: true`. The tested 400-resource fixture
saved 27 processed keys and completed the remaining work in exactly 24 pulses,
matching its uninterrupted host trace. The prior local-cache rewind fails the
first loaded pulse even though the native order check passes.

The separate `tests/scenarios/catalog-continuation/control.lua` fixture retains
the dense four-station, partial-native-result, ownership, collision-box edge,
and depletion coverage. This focused fixture adds the saved map-phase boundary.
