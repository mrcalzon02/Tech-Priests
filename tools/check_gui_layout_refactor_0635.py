#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tech-priests_src"
STYLE = SRC / "prototypes/gui_inner_styles_0635.lua"
DATA_UPDATES = SRC / "data-updates.lua"
HISTORY = SRC / "scripts/core/consecration/history_gui.lua"
WORKSTATE = SRC / "scripts/core/station_work_inventory.lua"
ROUTE = SRC / "scripts/core/ground_route_authority_0633.lua"
INFO = SRC / "info.json"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def require_file(path: Path, failures: list[str]) -> str:
    if not path.exists():
        failures.append(f"missing file: {path.relative_to(ROOT)}")
        return ""
    return read(path)


def main() -> int:
    failures: list[str] = []
    print("GUI layout refactor 0635 checker")

    style = require_file(STYLE, failures)
    if style:
        if "filename = \"__tech-priests__/graphics/gui/rough-assets/Sliceable/inner.jpg\"" not in style:
            failures.append("gui_inner_styles_0635.lua does not point at Sliceable/inner.jpg")
        if "horizontally_stretchable" in style or "vertically_stretchable" in style:
            failures.append("gui_inner_styles_0635.lua contains runtime-only stretchability fields that break gui-style loading")
        if "type = \"frame_style\"" not in style:
            failures.append("gui_inner_styles_0635.lua missing frame_style declaration")
        print("checked gui_inner_styles_0635.lua")

    data_updates = require_file(DATA_UPDATES, failures)
    if data_updates and 'require("prototypes.gui_inner_styles_0635")' not in data_updates:
        failures.append("data-updates.lua does not require prototypes.gui_inner_styles_0635")
    print("checked data-updates.lua")

    history = require_file(HISTORY, failures)
    if history:
        if "tech_priests_machine_spirit_inner_screen_0565" in history:
            failures.append("history_gui.lua still creates tech_priests_machine_spirit_inner_screen_0565")
        if "local tabs = ledger_parent.add{ type = \"tabbed-pane\", name = \"tech_priests_machine_spirit_tabs_0526\" }" not in history:
            failures.append("history_gui.lua does not put machine-spirit tabs directly under ledger_parent")
        print("checked history_gui.lua")

    workstate = require_file(WORKSTATE, failures)
    if workstate:
        if ".. \"_screen_0565\"" in workstate:
            failures.append("station_work_inventory.lua still creates per-tab _screen_0565 wrapper frames")
        if "local scroll = parent.add({ type = \"scroll-pane\", name = name, direction = \"vertical\" })" not in workstate:
            failures.append("station_work_inventory.lua add_inner_screen_page_0565 is not direct scroll-pane construction")
        print("checked station_work_inventory.lua")

    route = require_file(ROUTE, failures)
    if route:
        if "machine_spirit_ledger_gui_clamp_0634" in route:
            failures.append("ground_route_authority_0633.lua still installs the failed GUI clamp")
        if "station_area_change_invalidator_0634" not in route:
            failures.append("ground_route_authority_0633.lua lost station_area_change_invalidator_0634 install")
        print("checked ground_route_authority_0633.lua")

    info_src = require_file(INFO, failures)
    if info_src:
        try:
            info = json.loads(info_src)
            if info.get("version") != "0.1.635":
                failures.append(f"info.json version is {info.get('version')!r}, expected '0.1.635'")
        except Exception as exc:
            failures.append(f"info.json failed to parse: {exc}")
        print("checked info.json")

    if failures:
        print("\nFAIL GUI layout refactor 0635:")
        for f in failures:
            print(f"- {f}")
        return 1

    print("\nOK GUI layout refactor 0635 markers passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
