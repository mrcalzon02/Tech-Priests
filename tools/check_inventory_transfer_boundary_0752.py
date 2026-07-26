#!/usr/bin/env python3
"""Validate canonical remove-before-credit priest cargo custody."""
from __future__ import annotations
import pathlib,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
STEWARD=ROOT/'tech-priests_src/scripts/core/inventory_steward.lua'
RETIRED=ROOT/'tech-priests_src/scripts/core/inventory_transfer_integrity_0687.lua'
REQUIRED=(
 'version = "0.1.674-dev"',
 'exact_remove_before_credit = true',
 'persistent_restore_custody = true',
 'inventory_transfer_custody_0687',
 'phase = "removed-not-credited"',
 'function Steward.service_custody',
 'function Steward.flush_priest_inventory_to_station',
 'local function transfer_stack',
 'authority.deposit_exact',
 'custody.source_inventory',
 'custody.count = count - restored',
 'name = "inventory_steward_0357"',
 'return {\n    processed = processed',
 'Steward.route_owner = "runtime-tick-broker"',
)
FORBIDDEN=(
 'spill_item_stack', 'script.on_nth_tick', 'TechPriestsRuntimeEventRegistry',
 'commands.add_command', 'wrap_legacy_finish', 'storage_role_authority_0686_install_wrapped',
 'inventory_transfer_integrity_0687_install_wrapped',
)
RETIRED_FORBIDDEN=('function M.install','register_service','script.on_','inventory.remove','inventory.insert','patch_steward')
def main()->int:
 errors=[]
 text=STEWARD.read_text(encoding='utf-8',errors='replace') if STEWARD.is_file() else ''
 retired=RETIRED.read_text(encoding='utf-8',errors='replace') if RETIRED.is_file() else ''
 for fragment in REQUIRED:
  if fragment not in text: errors.append('missing canonical custody contract: '+fragment)
 for fragment in FORBIDDEN:
  if fragment in text: errors.append('forbidden steward regression: '+fragment)
 if 'retired = true' not in retired: errors.append('0687 is not explicitly retired')
 for fragment in RETIRED_FORBIDDEN:
  if fragment in retired: errors.append('retired 0687 contains forbidden authority: '+fragment)
 if errors:
  print('Inventory transfer boundary audit failed:',file=sys.stderr)
  for error in errors: print('  - '+error,file=sys.stderr)
  return 1
 print('Inventory transfer boundary audit passed: canonical steward owns persistent remove-before-credit custody; 0687 is inert.')
 return 0
if __name__=='__main__': raise SystemExit(main())
