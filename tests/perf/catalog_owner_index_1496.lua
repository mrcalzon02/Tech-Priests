-- Diagnostic only. Synthetic Lua, not Factorio UPS or save-size evidence.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
local Index=require('scripts.core.catalog_owner_index_1496')
local N=100000
local owners=50
local original={}
for i=1,N do original['u:'..i]=(i%owners)+1 end
local root={owned_resources=original,stats={}}
local tick=os.clock()
local reverse=Index.for_root(root)
local build_ms=(os.clock()-tick)*1000
local rounds=50
local begin=os.clock()
local old_checked=0
for repeat_index=1,rounds do
  for _,owner in pairs(original) do
    if owner ~= nil then old_checked=old_checked+1 end
  end
end
local old_ms=(os.clock()-begin)*1000/rounds
begin=os.clock()
local new_checked=0
for repeat_index=1,rounds do
  for owner in pairs(reverse) do
    new_checked=new_checked+1
  end
end
local new_ms=(os.clock()-begin)*1000/rounds
assert(old_checked==N*rounds)
assert(new_checked==owners*rounds)
local prior=root.owned_resources['u:1']
local t2=os.clock()
local removed=Index.release_station(root,prior)
local cleanup_ms=(os.clock()-t2)*1000
assert(removed==N/owners)
print(string.format('[catalog-owner-index-1496-perf] claims=%d owners=%d initial_rebuild_ms=%.3f',N,owners,build_ms))
print(string.format('[catalog-owner-index-1496-perf] old_full_scan_ms=%.3f new_owner_iteration_ms=%.3f ratio=%.1fx',old_ms,new_ms,old_ms/new_ms))
print(string.format('[catalog-owner-index-1496-perf] targeted_cleanup_ms=%.3f keys_released=%d',cleanup_ms,removed))
