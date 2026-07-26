#!/usr/bin/env python3
"""Reject generic storage access to machine work inventories."""
from __future__ import annotations
import pathlib,sys

ROOT=pathlib.Path(__file__).resolve().parents[1]
STORAGE=ROOT/'tech-priests_src/scripts/core/storage_role_authority_0686.lua'
REQUIRED=(
'version = "0.1.674-dev"',
'generic_container_only = true',
'function M.generic_station_inventories',
'function M.generic_item_count',
'function M.remove_generic_item',
'function M.deposit_exact',
'local function container_inventory',
'local function deposit_plan',
'local function rollback',
'local function safe_create_stash',
'no_spill_cache_recovery = true',
'name = "storage_role_authority_0686_sweep"',
'fn = function() return sweep_role_containers() end',
'tech_priests_generic_station_inventories_0686',
'tech_priests_generic_station_item_count_0686',
'tech_priests_generic_station_remove_0686',
'M.route_owner = "runtime-tick-broker"',
'M.installed = true',
'return true',
)
FORBIDDEN=(
'defines.inventory.assembling_machine_input',
'defines.inventory.assembling_machine_output',
'defines.inventory.furnace_source',
'defines.inventory.furnace_result',
'defines.inventory.lab_input',
'defines.inventory.fuel',
'defines.inventory.burnt_result',
'defines.inventory.rocket_silo_input',
'defines.inventory.rocket_silo_output',
'spill_item_stack',
'script.on_nth_tick',
'TechPriestsRuntimeEventRegistry',
'result ~= false',
'result~=false',
)

def main()->int:
 errors=[]
 if not STORAGE.is_file():errors.append(f'missing storage authority: {STORAGE.relative_to(ROOT)}');text=''
 else:text=STORAGE.read_text(encoding='utf-8',errors='replace')
 for fragment in REQUIRED:
  if fragment not in text:errors.append(f'missing storage boundary contract: {fragment}')
 for fragment in FORBIDDEN:
  if fragment in text:errors.append(f'forbidden generic storage regression: {fragment}')
 if errors:
  print('Generic storage boundary audit failed:',file=sys.stderr)
  for error in errors:print('  - '+error,file=sys.stderr)
  return 1
 print('Generic storage boundary audit passed: container/trunk storage only.')
 return 0
if __name__=='__main__':raise SystemExit(main())
