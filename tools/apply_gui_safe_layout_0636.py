#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HISTORY = ROOT / "tech-priests_src/scripts/core/consecration/history_gui.lua"
WORKSTATE = ROOT / "tech-priests_src/scripts/core/station_work_inventory.lua"
INFO = ROOT / "tech-priests_src/info.json"


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8", errors="replace")
    if old not in text:
        print(f"already patched or missing block: {label}")
        return
    path.write_text(text.replace(old, new, 1), encoding="utf-8", newline="\n")
    print(f"patched {label}")


def patch_history() -> None:
    old = '''  local shell_body, shell_content_w, shell_content_h = add_machine_spirit_sliced_shell_0567(frame, ledger_panel_w, ledger_panel_h)
  local ledger_parent = shell_body or frame
'''
    new = '''  -- 0.1.636: safe layout fallback. The ornate sliced shell is visually rich but
  -- it still behaves like manually tiled decoration inside a normal Factorio GUI
  -- tree, and in practice it can overlap/bleed over live tab content. Use one
  -- real inner panel as the layout parent and let Factorio size the children.
  local shell_content_w = ledger_panel_w - 56
  local shell_content_h = ledger_panel_h - 92
  local ledger_parent = frame.add{ type = "frame", name = "tech_priests_machine_spirit_safe_body_0636", direction = "vertical" }
  apply_style_0564(ledger_parent, "tech_priests_inner_panel_0635")
  pcall(function() ledger_parent.style.minimal_width = shell_content_w end)
  pcall(function() ledger_parent.style.maximal_width = shell_content_w end)
  pcall(function() ledger_parent.style.minimal_height = shell_content_h end)
  pcall(function() ledger_parent.style.maximal_height = shell_content_h end)
  pcall(function() ledger_parent.style.horizontally_stretchable = false end)
  pcall(function() ledger_parent.style.vertically_stretchable = false end)
'''
    replace_once(HISTORY, old, new, "Machine-Spirit safe body replaces sliced shell")


def patch_workstate() -> None:
    old = '''  local shell = frame.add({ type = "flow", name = "tech_priests_workstate_diegetic_shell_0482", direction = "vertical" })
  shell.style.horizontally_stretchable = true
  shell.style.vertically_stretchable = true
  local body, content_w_0536, content_h_0536 = add_diegetic_workstate_body_0482(shell, panel_w, panel_h)
  local content_w_for_scroll_0536 = tonumber(content_w_0536) or (panel_w - 116)
'''
    new = '''  -- 0.1.636: safe layout fallback. Do not build the tiled reliquary shell here;
  -- it is decoration pretending to be layout and it overlaps real tab/scroll
  -- content on live displays. Use one inner panel and let Factorio own layout.
  local content_w_0536 = panel_w - 48
  local content_h_0536 = panel_h - 92
  local body = frame.add({ type = "frame", name = "tech_priests_workstate_safe_body_0636", direction = "vertical" })
  apply_gui_style_0532(body, "tech_priests_inner_panel_0635")
  pcall(function() body.style.minimal_width = content_w_0536 end)
  pcall(function() body.style.maximal_width = content_w_0536 end)
  pcall(function() body.style.minimal_height = content_h_0536 end)
  pcall(function() body.style.maximal_height = content_h_0536 end)
  pcall(function() body.style.horizontally_stretchable = false end)
  pcall(function() body.style.vertically_stretchable = false end)
  local content_w_for_scroll_0536 = tonumber(content_w_0536) or (panel_w - 116)
'''
    replace_once(WORKSTATE, old, new, "Work-State safe body replaces diegetic shell")


def bump_info() -> None:
    info = json.loads(INFO.read_text(encoding="utf-8"))
    info["version"] = "0.1.636"
    info["description"] = "Tech-Priest logistics drones, Cogitator Stations, Work State tabs, Machine-Spirit ledger traits, bounded Ground Route Authority, station-area freshness invalidation, 0.1.635 structural GUI cleanup, and 0.1.636 safe GUI layout fallback that removes tiled reliquary shell layers from the two broken ledger screens and uses one real inner panel per screen."
    INFO.write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("bumped info.json to 0.1.636")


def main() -> int:
    patch_history()
    patch_workstate()
    bump_info()
    print("done: inspect diff, run GUI checker, package tech-priests_0.1.636.zip")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
