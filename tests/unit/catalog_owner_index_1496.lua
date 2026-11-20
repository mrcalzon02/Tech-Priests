-- Regression 1496: station cleanup should scale with that station's claims.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
local Index=require('scripts.core.catalog_owner_index_1496')
local root={owned_resources={},stats={}}
for i=1,10000 do
  root.owned_resources['u:'..i] = i<=100 and 1 or (i<=110 and 2 or 3)
end
-- Simulate loading a pre-index save: rebuild lazily from canonical claims.
local groups=Index.for_root(root)
assert(root.stats.owner_index_rebuilds_1496==1)
local function count(group) local n=0;for _ in pairs(group or {})do n=n+1 end;return n end
assert(count(groups[1])==100 and count(groups[2])==10 and count(groups[3])==9890)
assert(Index.for_root(root)==groups and root.stats.owner_index_rebuilds_1496==1,
  'unchanged ownership rebuilt its reverse index')
local tags={}
for i=101,110 do tags['u:'..i]=true end
local called=0
local released=Index.release_station(root,2,function(key)
  assert(tags[key]);tags[key]=nil;called=called+1
end)
assert(released==10 and called==10 and next(tags)==nil,
  'targeted station cleanup did not release its exact keys and tags')
assert(root.owned_resources['u:1']==1 and root.owned_resources['u:111']==3,
  'cleanup released another station\'s resource')
assert(Index.release_station(root,2)==0,'repeated cleanup did not become a no-op')
assert(Index.assign(root,'u:1',3),'transfer between stations was ignored')
assert(groups[1]['u:1']==nil and groups[3]['u:1'],
  'transfer left obsolete reverse ownership')
assert(Index.release(root,'u:1') and root.owned_resources['u:1']==nil,
  'direct removal left an existing resource claimed')
assert(not Index.release(root,'u:1'),'double removal did not become a no-op')
assert(Index.assign(root,'legacy:rock',1),'legacy string key was rejected')
assert(groups[1]['legacy:rock'],'legacy key was not present in reverse lookup')
local new_root={owned_resources={['old:1']=4,['old:2']=4},stats={}}
local changed=Index.for_root(new_root)
assert(changed~=groups and count(changed[4])==2,
  'replacing ownership storage did not reseed the derived index')
assert(new_root.stats.owner_index_rebuilds_1496==1)
assert(Index.release_station(new_root,4)==2 and next(new_root.owned_resources)==nil,
  'orphan cleanup failed after a save reload')
-- A later cleanup must not iterate the complete ownership table again.
local guarded={owned_resources={x=9,y=9},stats={}}
assert(Index.for_root(guarded)[9].x)
setmetatable(guarded.owned_resources,{__pairs=function()
  error('unexpected full ownership scan after lazy rebuild')
end})
assert(Index.release_station(guarded,9)==2)
-- The source table is the only persisted authority; the derived index is not saved.
assert(root.owner_index_1496==nil and new_root.owner_index_1496==nil)
print('[catalog-owner-index-1496] PASS')
