#!/usr/bin/env python3
"""
Flatten obvious interior native frames in the Machine-Spirit Ledger GUI.

Target:
    tech-priests_src/scripts/core/consecration/history_gui.lua

This patch is deliberately narrow and visual-only. It does not change GUI event
routing, sanctification logic, machine-spirit records, tab state, or refresh
cadence.

It preserves:
- top-level Machine-Spirit State Ledger frame
- decorative sliced shell
- inner bezel shell
- tabbed-pane
- scroll-panes

It flattens:
- Machine-Spirit Character Ledger wrapper frame -> flow + heading label
- trait/flaw/neutral section frames -> flow + heading label
- history tab page frame -> flow

Dry-run is default. Use --apply to write.
"""

from __future__ import annotations

import argparse
from pathlib import Path

TARGET = Path("tech-priests_src/scripts/core/consecration/history_gui.lua")

REPLACEMENTS = [
    (
'''local function add_trait_table(parent, title, list, color, empty_text)
  local section = parent.add{ type = "frame", direction = "vertical", caption = title }
  pcall(function() section.style.minimal_width = TRAIT_TABLE_WIDTH end)
  list = list or {}
  if #list == 0 then
    local empty = section.add{ type = "label", caption = empty_text or "No marks recorded." }
    set_label_style(empty, 760, color)
    return section
  end''',
'''local function add_trait_table(parent, title, list, color, empty_text)
  local section = parent.add{ type = "flow", direction = "vertical" }
  pcall(function() section.style.minimal_width = TRAIT_TABLE_WIDTH end)
  pcall(function() section.style.horizontally_stretchable = true end)
  local heading = section.add{ type = "label", caption = tostring(title or "Machine-Spirit Marks") }
  set_label_style(heading, 820, color or { r = 0.95, g = 0.86, b = 0.32 })
  pcall(function() heading.style.font = "default-bold" end)
  list = list or {}
  if #list == 0 then
    local empty = section.add{ type = "label", caption = empty_text or "No marks recorded." }
    set_label_style(empty, 760, color)
    return section
  end'''
    ),
    (
'''local function add_machine_spirit_ledger(parent, record)
  local spirit = record.machine_spirit_0523 or {}
  local wrapper = parent.add{ type = "frame", direction = "vertical", caption = "Machine-Spirit Character Ledger" }
  pcall(function() wrapper.style.minimal_width = 870 end)
  local name = spirit.display_name or "Machine"''',
'''local function add_machine_spirit_ledger(parent, record)
  local spirit = record.machine_spirit_0523 or {}
  local wrapper = parent.add{ type = "flow", direction = "vertical" }
  pcall(function() wrapper.style.minimal_width = 870 end)
  pcall(function() wrapper.style.horizontally_stretchable = true end)
  local ledger_heading = wrapper.add{ type = "label", caption = "Machine-Spirit Character Ledger" }
  set_label_style(ledger_heading, 820, { r = 0.95, g = 0.86, b = 0.32 })
  pcall(function() ledger_heading.style.font = "default-bold" end)
  local name = spirit.display_name or "Machine"'''
    ),
    (
'''  local history_page = tabs.add{ type = "frame", name = "tech_priests_machine_spirit_history_page_0526", direction = "vertical" }
  set_display_frame_style_0565(history_page)
  tabs.add_tab(history_tab, history_page)
  add_history(history_page, record)''',
'''  local history_page = tabs.add{ type = "flow", name = "tech_priests_machine_spirit_history_page_0526", direction = "vertical" }
  pcall(function() history_page.style.horizontally_stretchable = true end)
  pcall(function() history_page.style.vertically_stretchable = true end)
  tabs.add_tab(history_tab, history_page)
  add_history(history_page, record)'''
    ),
]


def main() -> int:
    parser = argparse.ArgumentParser(description="Flatten Machine-Spirit Ledger interior frames")
    parser.add_argument("--target", default=str(TARGET), help="history_gui.lua path")
    parser.add_argument("--apply", action="store_true", help="Actually write changes; default is dry-run")
    args = parser.parse_args()

    path = Path(args.target)
    if not path.exists():
        raise SystemExit(f"missing target: {path}")

    text = path.read_text(encoding="utf-8")
    updated = text
    changed = 0
    already = 0

    for old, new in REPLACEMENTS:
        if new in updated:
            already += 1
            continue
        if old not in updated:
            raise SystemExit("expected Machine-Spirit Ledger frame block not found; refusing partial patch")
        updated = updated.replace(old, new, 1)
        changed += 1

    print(f"{'APPLY' if args.apply else 'DRY-RUN'} Machine-Spirit Ledger frame flattening: {path}")
    print(f"changes={changed} already={already}")
    if args.apply and changed:
        path.write_text(updated, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
