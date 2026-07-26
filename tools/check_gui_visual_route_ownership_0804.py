#!/usr/bin/env python3
# Fail closed on GUI, catalog, doctrine, and visual ownership regressions introduced in 0804.
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tech-priests_src/scripts/core"
FILES = {
    "0474": SRC / "alt_writ_visual_stability_0474.lua",
    "0476": SRC / "task_retention_visual_lease_0476.lua",
    "network": SRC / "network_visuals.lua",
    "overlay": SRC / "station_network_overlay.lua",
    "catalog": SRC / "station_catalog.lua",
    "work": SRC / "station_work_inventory.lua",
    "doctrine": SRC / "doctrine_argument.lua",
    "recovery": SRC / "workstate_gui_radar_recovery_0465.lua",
    "router": ROOT / "tech-priests_src/scripts/gui/gui_router.lua",
    "gui_bus": SRC / "gui_bus.lua",
    "generated_001": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_001.lua",
    "cleanup": SRC / "runtime_command_cleanup_0720.lua",
}
DIRECT = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")
RAW_GUI = re.compile(r"script\.on_event\s*\(\s*defines\.events\.(?:on_gui_opened|on_gui_closed|on_gui_click)")

errors: list[str] = []
text = {name: path.read_text(encoding="utf-8") for name, path in FILES.items()}

for name in ("0474", "0476", "network", "overlay", "catalog", "work", "doctrine", "recovery", "router", "gui_bus"):
    count = len(DIRECT.findall(text[name]))
    if count:
        errors.append(f"{name} retains {count} direct script route(s)")

raw_gui_paths = []
for path in (ROOT / "tech-priests_src").rglob("*.lua"):
    body = path.read_text(encoding="utf-8", errors="replace")
    if RAW_GUI.search(body):
        raw_gui_paths.append(str(path.relative_to(ROOT)))
if raw_gui_paths:
    errors.append("raw Factorio GUI bindings remain outside the canonical router: " + ", ".join(raw_gui_paths))

def require(name: str, fragments: tuple[str, ...]) -> None:
    for fragment in fragments:
        if fragment not in text[name]:
            errors.append(f"{name} missing contract: {fragment}")

def forbid(name: str, fragments: tuple[str, ...]) -> None:
    for fragment in fragments:
        if fragment in text[name]:
            errors.append(f"{name} retains forbidden fragment: {fragment}")

require("0474", (
    "M.refresh_period = 15", "M.redraw_period = 60", "M.ttl = 120",
    "M.refresh_all_command_cameras", "_G.tech_priests_0328_refresh_network_visuals = M.refresh_all",
    "_G.tech_priests_0355_refresh_station_network_overlay = M.refresh_all",
    'route = "periodic-stable-overlay-refresh"', 'route = "cursor-stack-refresh"',
    'route = "runtime-setting-refresh"', 'route = "selected-entity-refresh"',
))
require("network", ("route-free compatibility API", "return Visuals.refresh_all(...)",))
forbid("network", ("TechPriestsRuntimeEventRegistry", "Visuals.register_commands()", "tp-network-visuals-0333"))
require("overlay", ("route-free compatibility API", "return Overlay.refresh_all(...)",))
forbid("overlay", ("TechPriestsRuntimeEventRegistry", "Overlay.register_commands()", "tp-station-overlay-0355"))
require("0476", ('route = "task-retention-service"', "M.wrap_order_queue()", "M.wrap_magos_planning()", "M.wrap_sound_manager()"))
forbid("0476", ("visual_lease_tick", "patch_visual_authority", "visual_tick_interval", "clear-visuals"))
if len(re.findall(r"registry\.on_nth_tick\s*\(", text["0476"])) != 1:
    errors.append("0476 must own exactly one registry cadence")
require("router", ('route = "gui-opened-dispatch"', 'route = "gui-closed-dispatch"', 'route = "gui-click-dispatch"', "if not (opened and closed and click) then"))
router_start = text["router"].find("function Router.install")
router_accept = text["router"].find("if not (opened and closed and click) then", router_start)
router_publish = text["router"].find("Router.installed = true", router_accept)
if min(router_start, router_accept, router_publish) < 0 or router_publish < router_accept:
    errors.append("GUI router publishes installed state before route acceptance")
require("work", (
    'Router.register("opened", M.handle_gui_opened, "station-work-inventory-opened")',
    'Router.register("closed", M.handle_gui_closed, "station-work-inventory-closed")',
    'Router.register("click", M.handle_gui_click, "station-work-inventory-click"',
    'route = "workstate-boot-display-service"', "if not (opened and closed and click and boot) then return false end",
))
require("doctrine", (
    'route = "doctrine-argument-pulse"', 'route = "doctrine-alignment-normalize"',
    'route = "doctrine-overlay-cleanup"',
    'bus.register("click", M.handle_gui_click, "doctrine-argument-click")',
    'bus.register("closed", M.handle_gui_closed, "doctrine-argument-closed")',
    "if not (pulse and normalize and cleanup and click and closed) then return false end",
))
if len(re.findall(r"registry\.on_nth_tick\s*\(", text["doctrine"])) != 3:
    errors.append("doctrine argument must own exactly three registry cadences")
require("catalog", ('route = "station-catalog-scan"', 'route = "station-catalog-destroyed-entity"', "Work State owns GUI routing"))
if len(re.findall(r"registry\.on_nth_tick\s*\(", text["catalog"])) != 1 or len(re.findall(r"registry\.on_event\s*\(", text["catalog"])) != 1:
    errors.append("catalog must own exactly one scan cadence and one destruction event route")

def assert_after(name: str, acceptance: str, publications: tuple[str, ...]) -> None:
    function_name = "Catalog.install" if name == "catalog" else "M.install"
    start = text[name].find("function " + function_name)
    accepted = text[name].find(acceptance, start)
    if start < 0 or accepted < 0:
        errors.append(f"{name} missing install acceptance boundary")
        return
    for publication in publications:
        position = text[name].find(publication, accepted)
        if position < accepted:
            errors.append(f"{name} publishes {publication} before route acceptance")

assert_after("0476", "if not retention_route then return false end", ("root()", "M.wrap_order_queue()", "_G.TECH_PRIESTS_TASK_RETENTION_VISUAL_LEASE_0476 = M", "M._installed = true"))
assert_after("work", "if not (opened and closed and click and boot) then return false end", ("_G.TECH_PRIESTS_STATION_WORK_INVENTORY_0358 = M", "M.install_commands()", "M._installed = true"))
assert_after("doctrine", "if not (pulse and normalize and cleanup and click and closed) then return false end", ("ensure_root()", "M.register_commands()", "_G.tech_priests_0370_doctrine_argument = M", "M._installed = true"))
assert_after("catalog", "if not (scan and destroyed) then return false end", ("ensure_root()", "_G.TechPriestsStationCatalog = Catalog", "Catalog.register_commands()", "Catalog._installed = true"))
require("recovery", ("duplicate_handlers_retired = true", "late canonical GUI router bootstrap installed", "Work.install()", "Router.install()"))
forbid("recovery", ("tp-workstate-gui-0465", "Router.dispatch_", "service_workstate_only", "registry.on_event", "registry.on_nth_tick"))
require("gui_bus", ("route_free = true", "return Router.register(name, handler, label, opts)", "late 0465 bootstrap owns router installation"))
forbid("gui_bus", ("Router.install()", "station-catalog-opened-0327", "Router.install_debug_command"))
require("generated_001", ("TECH_PRIESTS_GUI_ROUTER_EARLY_INSTALL_RETIRED_0804 = true",))
forbid("generated_001", ("TechPriestsGuiRouter.install()",))
router_install_callers = []
for path in (ROOT / "tech-priests_src").rglob("*.lua"):
    body = path.read_text(encoding="utf-8", errors="replace")
    if "Router.install()" in body and path not in (FILES["recovery"], FILES["router"]):
        router_install_callers.append(str(path.relative_to(ROOT)))
if router_install_callers:
    errors.append("Router.install() must be called only by late 0465 bootstrap: " + ", ".join(router_install_callers))
info = (ROOT / "tech-priests_src/info.json").read_text(encoding="utf-8")
if '"version": "0.1.672"' not in info:
    errors.append("protected source version changed from 0.1.672")

require("cleanup", (
    '["tp-network-visuals-0333"] = true',
    '["tp-station-overlay-0355"] = true',
    '["tp-workstate-gui-0465"] = true',
))

if errors:
    print("GUI/visual ownership audit failed:", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    raise SystemExit(1)

print("GUI/visual ownership audit passed: canonical router, Work State, doctrine GUI, catalog, 0474 visual authority, and 0476 retention ownership are consolidated.")
