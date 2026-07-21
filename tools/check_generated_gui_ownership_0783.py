#!/usr/bin/env python3
"""Validate canonical 0306 GUI ownership and retired 0310 replacements."""
from __future__ import annotations
import pathlib,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "part20":ROOT/"tech-priests_src/scripts/generated/control_legacy_part_020.lua",
 "part21":ROOT/"tech-priests_src/scripts/generated/control_legacy_part_021.lua",
 "integration":ROOT/"tools/check_development_integration_0732.py",
 "source_workflow":ROOT/".github/workflows/source-validation.yml",
 "workflow":ROOT/".github/workflows/generated-gui-ownership-validation.yml",
}
REQ={
 "part20":(
  'function tech_priests_0306_open_gui(player, pair)',
  'function tech_priests_0306_on_gui_opened(event)',
  'function tech_priests_0306_on_gui_closed(event)',
  'function tech_priests_0306_on_gui_click(event)',
  'if player then tech_priests_0306_clear_gui(player) end',
  'if pair and apply_pair_display_names then',
  'if tech_priests_0310_handle_overview_click then',
  'TechPriestsGuiRouter.register("opened", tech_priests_0306_on_gui_opened)',
  'TechPriestsGuiRouter.register("closed", tech_priests_0306_on_gui_closed)',
  'TechPriestsGuiRouter.register("click", tech_priests_0306_on_gui_click)',
  'TECH_PRIESTS_0306_GRID_DOCTRINE_RETIRED = true'),
 "part21":(
  'TECH_PRIESTS_0310_GRID_SIDE_PANEL_OVERRIDE_RETIRED = true',
  'TECH_PRIESTS_0310_GUI_ROUTER_WRAPPERS_RETIRED = true',
  'function tech_priests_0310_handle_overview_click(event)'),
 "integration":('check_generated_gui_ownership_0783.py',),
 "source_workflow":('Audit canonical generated GUI ownership','check_generated_gui_ownership_0783.py'),
 "workflow":('Audit canonical generated GUI ownership','check_generated_gui_ownership_0783.py'),
}
FORBID={
 "part21":(
  'TECH_PRIESTS_PRE_OPEN_GRID_0306_FOR_0310',
  'function tech_priests_0306_open_gui(player, pair)',
  'function tech_priests_0310_on_gui_opened(event)',
  'function tech_priests_0310_on_gui_closed(event)',
  'function tech_priests_0310_on_gui_click(event)',
  'TechPriestsGuiRouter.register("opened", tech_priests_0310_on_gui_opened)',
  'TechPriestsGuiRouter.register("closed", tech_priests_0310_on_gui_closed)',
  'TechPriestsGuiRouter.register("click", tech_priests_0310_on_gui_click)',
  'Cogitator Sub-Equipment Grid'),
}
def count_contract(text, needle, expected, label, errors):
 actual=text.count(needle)
 if actual != expected: errors.append(f'{label} expected {expected} occurrence(s) of {needle!r}, found {actual}')
def main():
 errors=[]
 texts={name:path.read_text(encoding='utf-8',errors='replace') for name,path in FILES.items()}
 for name,parts in REQ.items():
  for part in parts:
   if part not in texts[name]: errors.append(f'{FILES[name].relative_to(ROOT)} missing contract: {part}')
 for name,parts in FORBID.items():
  for part in parts:
   if part in texts[name]: errors.append(f'{FILES[name].relative_to(ROOT)} contains forbidden regression: {part}')
 count_contract(texts['part20'],'function tech_priests_0306_open_gui(player, pair)',1,'canonical 0306 side-panel policy',errors)
 count_contract(texts['part21'],'function tech_priests_0306_open_gui(player, pair)',0,'retired 0310 side-panel replacement',errors)
 for event in ('opened','closed','click'):
  count_contract(texts['part20'],f'TechPriestsGuiRouter.register("{event}", tech_priests_0306_on_gui_{event})',1,f'canonical 0306 {event} GUI route',errors)
  count_contract(texts['part21'],f'TechPriestsGuiRouter.register("{event}"',0,f'retired later {event} GUI routes',errors)
 if errors:
  print('Canonical generated GUI ownership audit failed:',file=sys.stderr)
  for error in errors: print('  - '+error,file=sys.stderr)
  return 1
 print('Canonical generated GUI ownership audit passed: 0306 owns the sole station-inventory GUI family; 0310 side-panel and router replacements are retired while overview handling remains available.')
 return 0
if __name__=='__main__': raise SystemExit(main())
