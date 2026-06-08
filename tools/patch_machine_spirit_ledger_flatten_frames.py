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
import re
from pathlib import Path

TARGET = Path("tech-priests_src/scripts/core/consecration/history_gui.lua")


def replace_once(text: str, old: str, new: str, label: str) -> tuple[str, int]:
    if new in text:
        print(f"already patched: {label}")
        return text, 0
    if old not in text:
        raise SystemExit(f"expected block not found for {label}; refusing partial patch")
    return text.replace(old, new, 1), 1


def patch_trait_table(text: str) -> tuple[str, int]:
    # Current 0.1.628 source uses a neutral grey empty-text color here. Earlier
    # draft helper expected the caller color, so it failed closed. Match the
    # recovered baseline exactly.
    old = '''local function add_trait_table(parent, title, list, color, empty_text)
  local section = parent.add{ type = "frame", direction = "vertical", caption = title }
  pcall(function() section.style.minimal_width = TRAIT_TABLE_WIDTH end)
  list = list or {}
  if #list == 0 then
    local empty = section.add{ type = "label", caption = empty_text or "No marks recorded." }
    set_label_style(empty, 760, { r = 0.70, g = 0.70, b = 0.70 })
    return section
  end'''
    new = '''local function add_trait_table(parent, title, list, color, empty_text)
  local section = parent.add{ type = "flow", direction = "vertical" }
  pcall(function() section.style.minimal_width = TRAIT_TABLE_WIDTH end)
  pcall(function() section.style.horizontally_stretchable = true end)
  local heading = section.add{ type = "label", caption = tostring(title or "Machine-Spirit Marks") }
  set_label_style(heading, 820, color or { r = 0.95, g = 0.86, b = 0.32 })
  pcall(function() heading.style.font = "default-bold" end)
  list = list or {}
  if #list == 0 then
    local empty = section.add{ type = "label", caption = empty_text or "No marks recorded." }
    set_label_style(empty, 760, { r = 0.70, g = 0.70, b = 0.70 })
    return section
  end'''
    return replace_once(text, old, new, "trait/flaw/neutral section frame flattening")


def patch_machine_spirit_wrapper(text: str) -> tuple[str, int]:
    old = '''local function add_machine_spirit_ledger(parent, record)
  local spirit = record.machine_spirit_0523 or {}
  local wrapper = parent.add{ type = "frame", direction = "vertical", caption = "Machine-Spirit Character Ledger" }
  pcall(function() wrapper.style.minimal_width = 870 end)
  local name = spirit.display_name or "Machine"'''
    new = '''local function add_machine_spirit_ledger(parent, record)
  local spirit = record.machine_spirit_0523 or {}
  local wrapper = parent.add{ type = "flow", direction = "vertical" }
  pcall(function() wrapper.style.minimal_width = 870 end)
  pcall(function() wrapper.style.horizontally_stretchable = true end)
  local ledger_heading = wrapper.add{ type = "label", caption = "Machine-Spirit Character Ledger" }
  set_label_style(ledger_heading, 820, { r = 0.95, g = 0.86, b = 0.32 })
  pcall(function() ledger_heading.style.font = "default-bold" end)
  local name = spirit.display_name or "Machine"'''
    return replace_once(text, old, new, "Machine-Spirit Character Ledger wrapper flattening")


def patch_history_page(text: str) -> tuple[str, int]:
    old = '''  local history_page = tabs.add{ type = "frame", name = "tech_priests_machine_spirit_history_page_0526", direction = "vertical" }
  set_display_frame_style_0565(history_page)
  tabs.add_tab(history_tab, history_page)
  add_history(history_page, record)'''
    new = '''  local history_page = tabs.add{ type = "flow", name = "tech_priests_machine_spirit_history_page_0526", direction = "vertical" }
  pcall(function() history_page.style.horizontally_stretchable = true end)
  pcall(function() history_page.style.vertically_stretchable = true end)
  tabs.add_tab(history_tab, history_page)
  add_history(history_page, record)'''
    return replace_once(text, old, new, "Rite History tab page frame flattening")


def assert_no_target_frames_remain(text: str) -> None:
    remaining = []
    checks = [
        ("trait section native frame", r'local section = parent\.add\{ type = "frame", direction = "vertical", caption = title \}'),
        ("machine-spirit wrapper native frame", r'local wrapper = parent\.add\{ type = "frame", direction = "vertical", caption = "Machine-Spirit Character Ledger" \}'),
        ("history page native frame", r'local history_page = tabs\.add\{ type = "frame", name = "tech_priests_machine_spirit_history_page_0526"'),
    ]
    for label, pattern in checks:
        if re.search(pattern, text):
            remaining.append(label)
    if remaining:
        raise SystemExit("target native frames still remain after patch: " + ", ".join(remaining))


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

    for patcher in (patch_trait_table, patch_machine_spirit_wrapper, patch_history_page):
        updated, delta = patcher(updated)
        changed += delta

    assert_no_target_frames_remain(updated)

    print(f"{'APPLY' if args.apply else 'DRY-RUN'} Machine-Spirit Ledger frame flattening: {path}")
    print(f"changes={changed}")
    if args.apply and changed:
        path.write_text(updated, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
