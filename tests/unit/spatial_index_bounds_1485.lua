-- Regression 1485: giant areas and colliding unitless IDs fail closed.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={}}
game={tick=0}
local I=require('scripts.core.efficiency_economy_0579')
local surface={index=4,name='nauvis'}
local huge={{-2000,-2000},{2000,2000}}
local root=I.root()
assert(I.note_area_scan(surface,huge,{},768,true)==false,
  'a huge area was incorrectly eligible for unrestricted cell indexing')
assert(I.entities_for_area(surface,huge,768,true)==nil,
  'an oversized area returned a cache hit')
assert(root.stats.area_scans_skipped_cell_budget==1
  and root.stats.area_index_miss_cell_budget==1,
  'oversize budgets were not recorded')
local sidx=root.surfaces[tostring(surface.index)]
assert(not sidx or next(sidx.cells)==nil,
  'budgeted refusal created thousands of cached cells')
local area={{0,0},{32,32}}
local force={index=1}
local e1={valid=true,name='stone',type='simple-entity',surface=surface,
  force=force,position={x=4,y=4}}
local e2={valid=true,name='stone',type='simple-entity',surface=surface,
  force=force,position={x=4,y=4}}
assert(e1~=e2)
assert(I.note_area_scan(surface,area,{e1,e2},768,true)==false,
  'two physically distinct entities with the same exact key certified a cell')
assert(I.entities_for_area(surface,area,768,true)==nil,
  'collision produced incomplete cached entity results')
assert(root.stats.ambiguous_area_index_keys==1,
  'collision not exposed in spatial index diagnostics')
local e3={valid=true,unit_number=77,name='assembling-machine-1',
  type='assembling-machine',surface=surface,position={x=5,y=6}}
game.tick=5
assert(I.note_area_scan(surface,area,{e3},768,true))
local result=I.entities_for_area(surface,area,768,true)
assert(result and #result==1 and result[1]==e3,
  'a new complete scan could not recover a previously ambiguous area')
-- Single cell and budget boundary still work; outside must fail closed.
local valid_boundary={{0,0},{512,512}}
game.tick=6
assert(I.note_area_scan(surface,valid_boundary,{},768,true)==true,
  'exactly 256 cells should remain eligible')
local too_large={{0,0},{544,512}}
assert(I.note_area_scan(surface,too_large,{},768,true)==false,
  '257+ cells must refuse full-area cache learning')
print('[spatial-index-bounds-1485] PASS: huge region, identity collision, recovery')
