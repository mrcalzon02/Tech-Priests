-- Missing ammo must not rediscover all prototypes/sources on each question.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
storage={tech_priests={}};game={tick=1}
defines={inventory={chest=1,turret_ammo=2}}
local items={['firearm-magazine']={type='ammo'},
 ['piercing-rounds-magazine']={type='ammo'},
 ['uranium-rounds-magazine']={type='ammo'},['modded-round']={type='ammo'}}
for i=1,2000 do items['ordinary-item-'..i]={type='item'}end
local prototype_walks=0
setmetatable(items,{__pairs=function(t)
 prototype_walks=prototype_walks+1;return next,t,nil
end})
prototypes={item=items}
local source_reads,counts=0,{}
local inv={valid=true,get_item_count=function(item)return counts[item]or 0 end}
local proxy_counts,proxy_reads={},0
local proxy_inv={valid=true,get_item_count=function(item)
 proxy_reads=proxy_reads+1;return proxy_counts[item]or 0
end,is_empty=function()return next(proxy_counts)==nil end}
local pair={station={valid=true,unit_number=1,get_inventory=function()return inv end},
 proxy={valid=true,unit_number=2,get_inventory=function()return proxy_inv end}}
_G.tech_priests_inventory_steward_sources_for_pair=function()
 source_reads=source_reads+1;return {{inv=inv,source='known-station-stock'}}
end
local Ammo=require('scripts.core.proxy_ammo_hardener_0649')
for i=1,500 do
 assert(Ammo.station_ammo(pair)==nil)
 assert(not Ammo.proxy_has_ammo(pair))
end
assert(prototype_walks==1,'missing ammo repeatedly traversed every prototype')
assert(source_reads==500,'one ammo question rediscovered inventory sources per ammo type')
assert(proxy_reads==0,'empty native ammo inventory was polled per item type')
counts['modded-round']=7
local item,n,source=Ammo.station_ammo(pair)
assert(item=='modded-round' and n==7 and source.inv==inv,
 'new modded ammo was hidden behind cached quantities')
counts['uranium-rounds-magazine']=2
item,n=Ammo.station_ammo(pair)
assert(item=='uranium-rounds-magazine' and n==2,'preferred ammo priority changed')
counts['uranium-rounds-magazine']=nil;counts['modded-round']=nil
assert(Ammo.station_ammo(pair)==nil,'removed ammo remained available')
proxy_counts['modded-round']=1
assert(Ammo.proxy_has_ammo(pair),'modded proxy ammo was not detected')
proxy_counts['modded-round']=nil
assert(not Ammo.proxy_has_ammo(pair),'consumed proxy ammo remained available')
assert(prototype_walks==1,'live inventory changes rebuilt immutable prototype list')
package.loaded['scripts.core.proxy_ammo_hardener_0649']=nil
Ammo=require('scripts.core.proxy_ammo_hardener_0649')
assert(Ammo.station_ammo(pair)==nil and prototype_walks==2,
 'derived prototype list did not rebuild after a runtime reload')
print('[proxy-ammo-discovery-0649] PASS: 500 missing checks, one prototype walk; live amounts and unchanged preference')
