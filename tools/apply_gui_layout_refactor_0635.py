#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

HISTORY = ROOT / "tech-priests_src/scripts/core/consecration/history_gui.lua"
WORKSTATE = ROOT / "tech-priests_src/scripts/core/station_work_inventory.lua"
ROUTE = ROOT / "tech-priests_src/scripts/core/ground_route_authority_0633.lua"
INFO = ROOT / "tech-priests_src/info.json"
DATA_UPDATES = ROOT / "tech-priests_src/data-updates.lua"
STYLE_PROTO = ROOT / "tech-priests_src/prototypes/gui_inner_styles_0635.lua"


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8", errors="replace")
    if old not in text:
        print(f"already patched or missing expected block in {path.relative_to(ROOT)}: {label}")
        return
    path.write_text(text.replace(old, new, 1), encoding="utf-8", newline="\n")
    print(f"patched {label}: {path.relative_to(ROOT)}")


def write_style_proto() -> None:
    # Prototype-stage GUI style specifications are not the same as runtime
    # LuaStyle objects.  Runtime LuaStyle accepts boolean stretchability fields,
    # but Factorio's gui-style prototype tree rejects those booleans here.
    # Keep this prototype to the graphical frame/padding contract; the builders
    # still set stretchability at runtime with element.style where valid.
    STYLE_PROTO.write_text('''-- prototypes/gui_inner_styles_0635.lua
-- Real inner panel style for nested Tech-Priests GUI content.

local default = data.raw["gui-style"].default

default.tech_priests_inner_panel_0635 = {
  type = "frame_style",
  parent = "inside_shallow_frame",
  graphical_set = {
    base = {
      position = {0, 0},
      corner_size = 8,
      filename = "__tech-priests__/graphics/gui/rough-assets/Sliceable/inner.jpg",
      scale = 1
    }
  },
  padding = 8,
  margin = 0
}
''', encoding="utf-8", newline="\n")
    print(f"wrote {STYLE_PROTO.relative_to(ROOT)}")


def patch_data_updates() -> None:
    text = DATA_UPDATES.read_text(encoding="utf-8", errors="replace")
    line = 'require("prototypes.gui_inner_styles_0635")'
    if line not in text:
        DATA_UPDATES.write_text(text.rstrip() + "\n\n" + line + "\n", encoding="utf-8", newline="\n")
        print("wired gui_inner_styles_0635 in data-updates.lua")
    else:
        print("data-updates.lua already wires gui_inner_styles_0635")


def patch_history() -> None:
    old = '''  local screen_body = ledger_parent.add{ type = "frame", name = "tech_priests_machine_spirit_inner_screen_0565", direction = "vertical" }
  set_display_frame_style_0565(screen_body)
  pcall(function() screen_body.style.minimal_width = math.max(680, (shell_content_w or 760) - 22) end)
  pcall(function() screen_body.style.maximal_width = math.max(680, (shell_content_w or 760) - 22) end)
  pcall(function() screen_body.style.minimal_height = math.max(620, (shell_content_h or 720) - 72) end)
  local tabs = screen_body.add{ type = "tabbed-pane", name = "tech_priests_machine_spirit_tabs_0526" }
'''
    new = '''  local tabs = ledger_parent.add{ type = "tabbed-pane", name = "tech_priests_machine_spirit_tabs_0526" }
  pcall(function() tabs.style.minimal_width = math.max(680, (shell_content_w or 760) - 22) end)
  pcall(function() tabs.style.maximal_width = math.max(680, (shell_content_w or 760) - 22) end)
  pcall(function() tabs.style.minimal_height = math.max(620, (shell_content_h or 720) - 72) end)
'''
    replace_once(HISTORY, old, new, "Machine-Spirit remove extra inner_screen frame")


def patch_workstate() -> None:
    old = '''local function add_inner_screen_page_0565(parent, name, scroll_h, scroll_w)
  local screen = parent.add({ type = "frame", name = tostring(name or "tech_priests_inner_screen") .. "_screen_0565", direction = "vertical" })
  apply_display_frame_style_0540(screen)
  pcall(function() screen.style.horizontally_stretchable = true end)
  pcall(function() screen.style.vertically_stretchable = true end)
  pcall(function() screen.style.minimal_height = scroll_h end)
  pcall(function() screen.style.maximal_height = scroll_h end)
  pcall(function() screen.style.minimal_width = math.max(560, scroll_w or 560) end)
  local scroll = screen.add({ type = "scroll-pane", name = name, direction = "vertical" })
  apply_screen_scroll_style_0564(scroll)
  pcall(function() scroll.style.minimal_height = math.max(120, (scroll_h or 400) - 18) end)
  pcall(function() scroll.style.maximal_height = math.max(120, (scroll_h or 400) - 18) end)
  pcall(function() scroll.style.minimal_width = math.max(540, (scroll_w or 560) - 20) end)
  pcall(function() scroll.style.horizontally_stretchable = true end)
  return scroll, screen
end
'''
    new = '''local function add_inner_screen_page_0565(parent, name, scroll_h, scroll_w)
  local scroll = parent.add({ type = "scroll-pane", name = name, direction = "vertical" })
  apply_screen_scroll_style_0564(scroll)
  pcall(function() scroll.style.minimal_height = math.max(120, scroll_h or 400) end)
  pcall(function() scroll.style.maximal_height = math.max(120, scroll_h or 400) end)
  pcall(function() scroll.style.minimal_width = math.max(540, scroll_w or 560) end)
  pcall(function() scroll.style.maximal_width = math.max(540, scroll_w or 560) end)
  pcall(function() scroll.style.horizontally_stretchable = true end)
  pcall(function() scroll.style.vertically_stretchable = true end)
  return scroll, scroll
end
'''
    replace_once(WORKSTATE, old, new, "Work-State remove per-tab nested screen frame")


def remove_clamp_install() -> None:
    old = '''  local ok_gui, Gui0634 = pcall(require, "scripts.core.machine_spirit_ledger_gui_clamp_0634")
  if ok_gui and Gui0634 and type(Gui0634.install)=="function" then pcall(Gui0634.install) end
'''
    text = ROUTE.read_text(encoding="utf-8", errors="replace")
    if old in text:
        ROUTE.write_text(text.replace(old, "", 1), encoding="utf-8", newline="\n")
        print("removed ledger GUI clamp install")
    else:
        print("ledger GUI clamp install block already absent")


def bump_info() -> None:
    info = json.loads(INFO.read_text(encoding="utf-8"))
    info["version"] = "0.1.635"
    info["description"] = "Tech-Priest logistics drones, Cogitator Stations, Machine Spirit Sanctification, Work State tabs, Machine-Spirit ledger traits, movement enforcement, bounded Ground Route Authority, station-area freshness invalidation, and 0.1.635 structural GUI layout repair using a real inner panel style plus direct removal of redundant nested ledger/reliquary frame layers."
    INFO.write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("bumped info.json to 0.1.635")


def main() -> int:
    write_style_proto()
    patch_data_updates()
    patch_history()
    patch_workstate()
    remove_clamp_install()
    bump_info()
    print("done: inspect with git diff, then package tech-priests_0.1.635.zip")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
