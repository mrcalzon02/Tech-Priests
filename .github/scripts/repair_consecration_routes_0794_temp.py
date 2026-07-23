#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(".")
HISTORY_GUI = ROOT / "tech-priests_src/scripts/core/consecration/history_gui.lua"
RUNTIME_BRIDGE = ROOT / "tech-priests_src/scripts/core/consecration/runtime_bridge.lua"
MINING_SENSOR = ROOT / "tech-priests_src/scripts/core/consecration/mining_sensor_0495.lua"
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
AUTHORITY_MAP = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
HISTORY = ROOT / "docs/DEVELOPMENT_HISTORY.md"
FILES = (HISTORY_GUI, RUNTIME_BRIDGE, MINING_SENSOR)
DIRECT_RE = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")

before = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in FILES)
if len(DIRECT_RE.findall(before)) != 6:
    raise SystemExit(f"0794 expected six direct consecration routes before repair, found {len(DIRECT_RE.findall(before))}")

history = HISTORY_GUI.read_text(encoding="utf-8")
history_prefix_re = re.compile(
    r"(?ms)^function M\.install\(\)\n.*?^  if commands and commands\.add_command then\n"
)
history_prefix = '''function M.install()
  ensure_root()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  local ok_router, router = pcall(require, "scripts.gui.gui_router")
  if not (registry and registry.on_nth_tick and ok_router and router and router.install and router.register) then
    if log then log("[Tech-Priests 0.1.526] consecration history GUI not installed: canonical router or registry unavailable") end
    return false
  end
  if router.install() ~= true then
    if log then log("[Tech-Priests 0.1.526] consecration history GUI not installed: GUI router rejected installation") end
    return false
  end
  local opened = router.register("opened", M.handle_gui_opened, "consecration-history-opened-0422")
  local closed = router.register("closed", M.handle_gui_closed, "consecration-history-closed-0422")
  local clicked = router.register("click", M.handle_gui_click, "consecration-history-click-0422")
  local refresh = registry.on_nth_tick(121, function() M.refresh_all_open() end, {
    owner = "consecration-history-gui",
    route = "refresh-open-history",
    category = "gui"
  })
  if not (opened and closed and clicked and refresh) then
    if log then log("[Tech-Priests 0.1.526] consecration history GUI not installed: canonical route registration failed") end
    return false
  end

  if commands and commands.add_command then
'''
history, count = history_prefix_re.subn(history_prefix, history, count=1)
if count != 1:
    raise SystemExit(f"0794 history GUI install prefix mismatch: {count}")
HISTORY_GUI.write_text(history, encoding="utf-8")

bridge = RUNTIME_BRIDGE.read_text(encoding="utf-8")
bridge_install_re = re.compile(r"(?ms)^function M\.install\(\)\n.*?^end\n\nreturn M\n$")
bridge_install = '''function M.install()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  if not (registry and registry.on_event and registry.on_nth_tick and defines and defines.events) then
    if log then log("[Tech-Priests 0.1.452 consecration] runtime bridge not installed: runtime event registry unavailable") end
    return false
  end

  local built = registry.on_event({
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
  }, register_entity, nil, {
    owner = "consecration-runtime-bridge",
    route = "register-built-entity",
    category = "consecration",
    priority = "front"
  })

  local removed = registry.on_event({
    defines.events.on_entity_died,
    defines.events.on_pre_player_mined_item,
    defines.events.on_robot_pre_mined,
    defines.events.script_raised_destroy
  }, remove_entity, nil, {
    owner = "consecration-runtime-bridge",
    route = "remove-destroyed-entity",
    category = "consecration",
    priority = "front"
  })

  local scan = registry.on_nth_tick(89, service_scan, {
    owner = "consecration-runtime-bridge",
    route = "periodic-target-scan",
    category = "consecration"
  })
  if not (built and removed and scan) then
    if log then log("[Tech-Priests 0.1.452 consecration] runtime bridge not installed: canonical route registration failed") end
    return false
  end
  return true
end

return M
'''
bridge, count = bridge_install_re.subn(bridge_install, bridge, count=1)
if count != 1:
    raise SystemExit(f"0794 runtime bridge install mismatch: {count}")
RUNTIME_BRIDGE.write_text(bridge, encoding="utf-8")

sensor = MINING_SENSOR.read_text(encoding="utf-8")
sensor_install_re = re.compile(r"(?ms)^function M\.install\(\)\n.*?^end\n\nreturn M\n$")
sensor_install = '''function M.install()
  if M.installed then return true end
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  if not (registry and registry.on_nth_tick) then
    if log then log("[Tech-Priests 0.1.544] consecration mining sensor not installed: runtime event registry unavailable") end
    return false
  end
  local cadence = registry.on_nth_tick(M.tick_interval, function() M.service_all() end, {
    owner = "consecration_mining_sensor_0495",
    route = "periodic-mining-operation-scan",
    category = "consecration",
    priority = "normal"
  })
  if not cadence then
    if log then log("[Tech-Priests 0.1.544] consecration mining sensor not installed: cadence registration failed") end
    return false
  end
  root()
  _G.TechPriestsConsecrationMiningSensor0495 = M
  M.wrap_pair_dump()
  M.register_commands()
  M.installed = true
  if log then log("[Tech-Priests 0.1.544] consecration mining sensor installed; mining drills use products_finished/output/progress accumulator operation counters") end
  return true
end

return M
'''
sensor, count = sensor_install_re.subn(sensor_install, sensor, count=1)
if count != 1:
    raise SystemExit(f"0794 mining sensor install mismatch: {count}")
MINING_SENSOR.write_text(sensor, encoding="utf-8")

after = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in FILES)
if DIRECT_RE.search(after):
    raise SystemExit("0794 direct consecration route remains after repair")
for required in (
    'router.register("opened", M.handle_gui_opened, "consecration-history-opened-0422")',
    'router.register("closed", M.handle_gui_closed, "consecration-history-closed-0422")',
    'router.register("click", M.handle_gui_click, "consecration-history-click-0422")',
    'registry.on_nth_tick(121, function() M.refresh_all_open() end',
    'route = "refresh-open-history"',
    'route = "register-built-entity"',
    'route = "remove-destroyed-entity"',
    'registry.on_nth_tick(89, service_scan',
    'route = "periodic-target-scan"',
    'route = "periodic-mining-operation-scan"',
):
    if required not in after:
        raise SystemExit(f"0794 required canonical route missing: {required}")
if "gui_bus.register" in history or "TechPriestsRuntimeEventRegistry.on_event" in history:
    raise SystemExit("0794 history GUI retains duplicate GUI route ownership")
if sensor.index("M.installed = true") < sensor.index("local cadence = registry.on_nth_tick"):
    raise SystemExit("0794 mining sensor marks installed before cadence registration")

# Record the first completed direct-route family without rewriting the inventory baseline.
testing = TESTING.read_text(encoding="utf-8")
heading = "### Consecration route ownership — 2026-07-23"
if heading not in testing:
    testing += (
        f"\n\n{heading}\n\n"
        "Milestone 0794 removed six direct consecration event/timer routes. The Machine-Spirit State Ledger now registers opened, closed, and click handlers once through the canonical GUI router and refreshes through one registry-owned 121-tick route. The consecration runtime bridge and mining sensor use registry-owned cadences only and fail closed when the registry is unavailable. The next direct-route tranche must be selected from the remaining non-generated inventory; Factorio runtime evidence remains blocked until direct ownership classification is complete.\n"
    )
    TESTING.write_text(testing, encoding="utf-8")

authority = AUTHORITY_MAP.read_text(encoding="utf-8")
map_heading = "## Consecration Route Ownership — 2026-07-23"
if map_heading not in authority:
    authority += (
        f"\n\n{map_heading}\n\n"
        "The consecration history GUI is a client of scripts.gui.gui_router and no longer binds Factorio GUI events directly or duplicates those routes through the runtime registry. Its periodic refresh, the consecration runtime bridge, and the mining-operation sensor are registry-owned and have no script.on_* fallback. Installers fail closed before publishing installed state when canonical routing is unavailable.\n"
    )
    AUTHORITY_MAP.write_text(authority, encoding="utf-8")

canonical_history = HISTORY.read_text(encoding="utf-8")
history_heading = "## 2026-07-23 — Milestone 0794: Consecration Route Ownership"
if history_heading not in canonical_history:
    canonical_history += (
        f"\n\n{history_heading}\n\n"
        "Removed six direct event/timer routes from the consecration family. history_gui now registers one labeled handler per GUI kind through the canonical GUI router and one 121-tick refresh through runtime_event_registry. runtime_bridge retains its built, removal, and 89-tick scan routes exclusively through the registry. mining_sensor_0495 registers its cadence before setting installed state or publishing globals. All three installers fail closed when canonical route registration is unavailable. Existing consecration commands and behavior helpers remain unchanged. Static validation does not constitute Factorio runtime proof.\n"
    )
    HISTORY.write_text(canonical_history, encoding="utf-8")

print("0794 consecration route consolidation complete: six direct routes removed")
