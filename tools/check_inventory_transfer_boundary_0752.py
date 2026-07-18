#!/usr/bin/env python3
"""Validate persistent remove-before-credit priest cargo transfers."""
from __future__ import annotations
import pathlib,sys

ROOT=pathlib.Path(__file__).resolve().parents[1]
TRANSFER=ROOT/'tech-priests_src/scripts/core/inventory_transfer_integrity_0687.lua'
REQUIRED=(
'version = "0.1.674-dev"',
'exact_remove_before_credit = true',
'persistent_restore_custody = true',
'inventory_transfer_custody_0687',
'phase = "removed-not-credited"',
'function M.service_custody',
'function M.flush_priest_inventory_to_station',
'local function transfer_stack',
'local function deposit_exact',
'authority.deposit_exact',
'return ok and accepted == true and inserted == count',
'custody.source_inventory',
'custody.count = count - restored',
'previous == true and patched == true',
'return patched == true',
)
FORBIDDEN=(
'spill_item_stack',
'script.on_nth_tick',
'TechPriestsRuntimeEventRegistry',
'register_service',
'result ~= false',
'result~=false',
'return result',
'critical_restore_shortfall',
'no-deposit-authority',
'get_station_inventory',
'defines.inventory.assembling_machine_input',
'defines.inventory.assembling_machine_output',
'defines.inventory.furnace_source',
'defines.inventory.furnace_result',
)

def main()->int:
 errors=[]
 if not TRANSFER.is_file():
  errors.append(f'missing transfer authority: {TRANSFER.relative_to(ROOT)}')
  text=''
 else:
  text=TRANSFER.read_text(encoding='utf-8',errors='replace')
 for fragment in REQUIRED:
  if fragment not in text:errors.append(f'missing transfer custody contract: {fragment}')
 for fragment in FORBIDDEN:
  if fragment in text:errors.append(f'forbidden transfer regression: {fragment}')
 if errors:
  print('Inventory transfer boundary audit failed:',file=sys.stderr)
  for error in errors:print('  - '+error,file=sys.stderr)
  return 1
 print('Inventory transfer boundary audit passed: remove-before-credit with persistent exact custody.')
 return 0
if __name__=='__main__':raise SystemExit(main())
