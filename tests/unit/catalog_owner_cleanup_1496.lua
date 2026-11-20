-- Regression 1496: catalog cleanup releases only the selected station's claims.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
local root={version='0.1.579',stations={},next_scan={},owned_resources={},render_tags={},stats={}}
storage={tech_priests={pairs_by_station={},station_catalog_0327=root}}
game={tick=60}
for i=1,10000 do
  root.owned_resources['u:'..i] = i<=100 and 1 or (i<=110 and 2 or 3)
end
local function pair(unit,valid)
  return {station_unit=unit,station={valid=valid,unit_number=unit,
    name='junior-cogitator-station'}}
end
for _,i in ipairs({1,2,3})do
  storage.tech_priests.pairs_by_station[i]=pair(i,i~=2)
  root.stations[i]={station_unit=i}
end
local destroyed=0
for i=101,110 do
  root.render_tags['u:'..i]={object={valid=true,destroy=function() destroyed=destroyed+1 end}}
end
local Catalog=require('scripts.core.station_catalog')
Catalog.prune_invalid()
assert(root.stats.owner_index_rebuilds_1496==1,
  'previous-save ownership was not indexed once')
assert(root.stats.owner_index_owner_checks_1496<=3,
  'prune performed work per resource instead of per owner')
assert(root.stats.owner_index_cleanup_keys_1496==10 and destroyed==10,
  'invalid station cleanup did not remove exact owned tags/claims')
assert(root.stations[2]==nil and root.owned_resources['u:101']==nil)
assert(root.owned_resources['u:1']==1 and root.owned_resources['u:111']==3,
  'invalid station cleanup stole other valid claims')
assert(root.owner_index_1496==nil,
  'derived owner index was incorrectly saved alongside resources')
-- If the canonical table is walked after initial rebuild, fail immediately.
setmetatable(root.owned_resources,{__pairs=function()
  error('unexpected full ownership scan after lazy rebuild')
end})
Catalog.prune_invalid()
assert(root.stats.owner_index_rebuilds_1496==1,
  'catalog rebuilt owner index every sweep')
local entity={valid=true,unit_number=111,name='rock-huge',type='simple-entity'}
assert(not Catalog.claim_built_entity(storage.tech_priests.pairs_by_station[1],entity,'mineable'),
  'valid station ownership was stolen')
-- Removing station 3 should release only its own keys, then permit reassignment.
local claimed_1=root.owned_resources['u:1']
Catalog.cleanup_station(3,'fixture-destroyed')
assert(root.owned_resources['u:111']==nil and root.owned_resources['u:1']==claimed_1)
assert(Catalog.claim_built_entity(storage.tech_priests.pairs_by_station[1],entity,'mineable'),
  'previously released resource could not be claimed by a valid station')
assert(root.owned_resources['u:111']==1)
Catalog.handle_destroyed_entity(entity,'fixture-removed')
assert(root.owned_resources['u:111']==nil,'death event did not remove precise key')
print('[catalog-owner-cleanup-1496] PASS')
