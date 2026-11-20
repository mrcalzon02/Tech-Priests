-- Claude T2-02 stage 1: world events must not reallocate all priest cache records.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Epoch=require("scripts.core.idle_invalidation_epoch_1491")
local root={pair={}}
local a,invalid=Epoch.cache_record(root,"100")
assert(not invalid and a.world_change_epoch_1491==0)
a.next_dispatch_after=200
a.next_legacy_after=350
local b=Epoch.cache_record(root,"200")
b.next_dispatch_after=600
b.next_legacy_after=700
assert(Epoch.world_changed(root)==1)
assert(root.pair["100"]==a and root.pair["200"]==b,
  "world event replaced persisted pair cache tables")
assert(a.next_dispatch_after==200 and b.next_dispatch_after==600,
  "world event eagerly reset each unrelated priest")
local ra,woke=Epoch.cache_record(root,"100")
assert(woke and ra==a and a.next_dispatch_after==0 and a.next_legacy_after==0,
  "affected priest was not lazily awakened on its next read")
assert(b.next_dispatch_after==600, "other priest was eagerly invalidated")
local rb,woke2=Epoch.cache_record(root,"200")
assert(woke2 and rb==b and b.next_dispatch_after==0 and b.next_legacy_after==0)
assert(Epoch.cache_record(root,"200")==b, "stable epoch changed cache record")
for i=1,10000 do Epoch.world_changed(root) end
assert(root.pair["100"]==a and root.pair["200"]==b,
  "event storm caused persisted table churn")
a.next_dispatch_after=1000000
assert(select(2,Epoch.cache_record(root,"100"))==true and a.next_dispatch_after==0,
  "event storm did not force revalidation before idle suppression")
local old={pair={legacy={next_dispatch_after=999,next_legacy_after=999}},world_change_epoch_1491=6}
local migrated,changed=Epoch.cache_record(old,"legacy")
assert(changed and migrated.next_dispatch_after==0 and migrated.next_legacy_after==0,
  "pre-upgrade sleeping priest was not safely awakened")
print("[idle-invalidation-epoch-1491] PASS")
