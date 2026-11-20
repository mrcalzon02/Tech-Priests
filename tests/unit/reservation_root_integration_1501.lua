-- T1-05: live reservation authority uses one-time root initialization.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
storage={tech_priests={}}
game={tick=1}
local R=require('scripts.core.work_reservations')
local categories=R.categories
local normalizations=0
setmetatable(categories,{__index=function(_,key)
  if key==#categories+1 then normalizations=normalizations+1 end
end})
local target={valid=true,unit_number=200,position={x=4,y=5},surface={index=1},force={index=1}}
local a={station={valid=true,unit_number=10}}
local b={station={valid=true,unit_number=11}}
assert(R.claim('repair',target,a,100))
local first=R.root()
assert(normalizations==1)
for i=1,20000 do
  assert(R.is_claimed_key('repair','unit:200',b)==true)
  assert(R.is_claimed_key('repair','unit:200',a)==false)
end
assert(normalizations==1,'stable reservations root repeatedly normalized categories')
assert(R.release_key('repair','unit:200',a))
assert(R.is_claimed_key('repair','unit:200',b)==false)
local old_stats=first.stats
storage.tech_priests[R.storage_key]={version='old',enabled=false,reservations={repair={}},stats={historical=77}}
local upgraded=R.root()
assert(upgraded~=first and upgraded.enabled==false and upgraded.stats.historical==77)
assert(upgraded.version==R.version and upgraded.reservations.pickup and normalizations==2)
assert(upgraded.stats~=old_stats)
-- Custom category registration must survive repeated lookups and save-root reuse.
upgraded.enabled=true
assert(R.claim('custom-rite',target,a,100))
local custom=upgraded.reservations['custom-rite']
assert(type(custom)=='table' and custom['unit:200'])
for i=1,1000 do assert(R.root()==upgraded) end
assert(upgraded.reservations['custom-rite']==custom and custom['unit:200'])
print('[reservation-root-integration-1501] PASS')
