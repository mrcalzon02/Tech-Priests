#!/usr/bin/env python3
"""Validate canonical 0307 glow ownership and retired generated wrappers."""
from __future__ import annotations
import pathlib,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "part21":ROOT/"tech-priests_src/scripts/generated/control_legacy_part_021.lua",
 "integration":ROOT/"tools/check_development_integration_0732.py",
 "source_workflow":ROOT/".github/workflows/source-validation.yml",
 "workflow":ROOT/".github/workflows/generated-glow-ownership-validation.yml",
}
REQ={
 "part21":(
  'function tech_priests_0307_refresh_pair_glow(pair)',
  'TechPriestsRuntimeEventRegistry.on_nth_tick(TECH_PRIESTS_GLOW_REFRESH_TICKS_0307',
  'TECH_PRIESTS_0310_DAYLIGHT_GLOW_WRAPPER_RETIRED = true',
  'TECH_PRIESTS_0313_GLOW_PREDECESSOR_CAPTURE_RETIRED = true',
  'TECH_PRIESTS_0315_GLOW_OVERRIDE_RETIRED = true',
  'destroy(pair.glow_day_ambient_0310)',
  'destroy(pair.glow_day_mode_0310)',
  'minimum_darkness = 0.45',
  'minimum_darkness = 0.35',
  'TECH_PRIESTS_0315_AMBIENT_GLOW_INTENSITY or 0.07',
  'TECH_PRIESTS_0315_MODE_GLOW_INTENSITY or 0.13'),
 "integration":('check_generated_glow_ownership_0781.py',),
 "source_workflow":('Audit canonical generated glow ownership','check_generated_glow_ownership_0781.py'),
 "workflow":('Audit canonical generated glow ownership','check_generated_glow_ownership_0781.py'),
}
FORBID={
 "part21":(
  'TECH_PRIESTS_PRE_GLOW_REFRESH_0307_FOR_0310',
  'TECH_PRIESTS_PRE_GLOW_REFRESH_0313 =',
  'function tech_priests_0310_draw_glow_sprite',
  'function tech_priests_0310_rendering_method',
  'script.on_nth_tick(TECH_PRIESTS_GLOW_REFRESH_TICKS_0307'),
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
 count_contract(texts['part21'],'function tech_priests_0307_refresh_pair_glow(pair)',1,'canonical 0307 glow function',errors)
 count_contract(texts['part21'],'TechPriestsRuntimeEventRegistry.on_nth_tick(TECH_PRIESTS_GLOW_REFRESH_TICKS_0307',1,'canonical 0307 glow cadence',errors)
 if errors:
  print('Canonical generated glow ownership audit failed:',file=sys.stderr)
  for error in errors: print('  - '+error,file=sys.stderr)
  return 1
 print('Canonical generated glow ownership audit passed: final night-clamped behavior lives in one 0307 function with one registry cadence; 0310/0313/0315 glow wrappers are retired.')
 return 0
if __name__=='__main__': raise SystemExit(main())
