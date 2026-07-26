#!/usr/bin/env python3
from pathlib import Path
import re,sys
ROOT=Path(__file__).resolve().parents[1]
FILES={
 'steward':ROOT/'tech-priests_src/scripts/core/inventory_steward.lua',
 'retired':ROOT/'tech-priests_src/scripts/core/inventory_transfer_integrity_0687.lua',
 'storage':ROOT/'tech-priests_src/scripts/core/storage_role_authority_0686.lua',
 'cache':ROOT/'tech-priests_src/scripts/core/stone_cache_filter_0534.lua',
 'supply':ROOT/'tech-priests_src/scripts/core/station_supply_satisfaction_0639.lua',
 'reserve':ROOT/'tech-priests_src/scripts/core/emergency_supply_reserve_0497.lua',
 'planning':ROOT/'tech-priests_src/scripts/core/planning_constraints_0646.lua',
}
DIRECT=re.compile(r'\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(')
def main():
 errors=[]
 text={k:p.read_text(encoding='utf-8',errors='replace') for k,p in FILES.items()}
 for name in ('steward','cache','supply','reserve'):
  if DIRECT.search(text[name]): errors.append(name+' retains direct script route')
 for fragment in ('active_hardener_count=26,retired_authority_count=48','{module="scripts.core.inventory_steward",label="inventory_steward_0357"}','["scripts.core.inventory_transfer_integrity_0687"]'):
  if fragment not in text['planning']: errors.append('planning missing '+fragment)
 for fragment in ('function Steward.service_custody','inventory_transfer_custody_0687','name = "inventory_steward_0357"','Steward.installed = true'):
  if fragment not in text['steward']: errors.append('steward missing '+fragment)
 for fragment in ('patch_steward','patch_stone_cache','previous_steward_install','previous_stone_install'):
  if fragment in text['storage']: errors.append('storage retains patch layer '+fragment)
 for fragment in ('spill_item_stack','stack.clear()','commands.add_command'):
  if fragment in text['cache']: errors.append('cache retains unsafe/command path '+fragment)
 for name in ('cache','supply','reserve'):
  if 'M.installed = true' not in text[name]: errors.append(name+' missing installed publication')
  if 'route_owner' not in text[name]: errors.append(name+' missing route owner metadata')
 if 'retired = true' not in text['retired'] or 'function M.install' in text['retired']:
  errors.append('0687 is not inert retired source')
 if errors:
  print('Inventory steward consolidation audit failed:',file=sys.stderr)
  for e in errors: print('  - '+e,file=sys.stderr)
  return 1
 print('Inventory steward consolidation audit passed: canonical custody, owner-first inventory routes, no raw fallback, 26 active / 48 retired.')
 return 0
if __name__=='__main__': raise SystemExit(main())
