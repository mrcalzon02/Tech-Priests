-- Engine-owned station-item cargo: no remote station debit, no synthetic
-- item, persistent custody bound to one actual priest and expansion writ.
package.path = "tech-priests_src/?.lua;tech-priests_src/?/init.lua;" .. package.path
local force, surface = {name="player"}, {index=1}
local station = {valid=true,unit_number=12,force=force,surface=surface,position={x=0,y=0}}
local priest = {valid=true,unit_number=112,position={x=0,y=0}}
local worker = {station=station,priest=priest}
local rec = {id=42,station_item="junior-cogitator-station",ghost_position={x=30,y=0}}
local item = rec.station_item
local source = {valid=true,stock=2,room=10}
source.get_item_count=function(name)assert(name==item);return source.stock end
source.get_insertable_count=function(name)assert(name==item);return source.room end
source.remove=function(stack)
  assert(stack.name==item)
  local n=math.min(source.stock,stack.count)
  source.stock=source.stock-n
  return n
end
source.insert=function(stack)
  assert(stack.name==item)
  local n=math.min(source.room,stack.count)
  source.stock=source.stock+n
  return n
end
local bags={}
game={tick=300,create_inventory=function(size)
  assert(size==1)
  local bag={valid=true,stock=0}
  bag.get_item_count=function(name)assert(name==item);return bag.stock end
  bag.insert=function(stack)
    assert(stack.name==item)
    local n=math.min(1-bag.stock,stack.count)
    bag.stock=bag.stock+n
    return n
  end
  bag.remove=function(stack)
    assert(stack.name==item)
    local n=math.min(bag.stock,stack.count)
    bag.stock=bag.stock-n
    return n
  end
  bag.destroy=function()
    assert(bag.stock==0,"must never destroy an inventory containing real items")
    bag.valid=false
  end
  bags[#bags+1]=bag
  return bag
end}
storage={tech_priests={}}
local M=require("scripts.core.station_cargo_0824")
priest.position={x=30,y=0}
local ok,why=M.pickup(worker,rec,source)
assert(not ok and why=="priest-not-at-physical-pickup"
  and source.stock==2 and #bags==0,"remote stock cannot be debited")
priest.position={x=0,y=0}
ok,why=M.pickup(worker,rec,source)
assert(ok and why=="physically-picked-up"
  and source.stock==1 and #bags==1 and bags[1].stock==1)
ok,why=M.pickup(worker,rec,source)
assert(ok and why=="already-carried"
  and source.stock==1 and #bags==1 and bags[1].stock==1,
  "duplicate service must never duplicate station items")
local imposter={station=station,priest={valid=true,unit_number=999,position={x=0,y=0}}}
assert(M.get(imposter,rec)==nil,"different priest cannot steal carried stock")
package.loaded["scripts.core.station_cargo_0824"]=nil
M=require("scripts.core.station_cargo_0824")
assert(M.has_record(rec) and M.get(worker,rec),
  "engine LuaInventory custody must survive module reload")
ok,why=M.begin_build(worker,rec)
assert(not ok and why=="carrier-not-at-build-site")
priest.position={x=30,y=0}
ok,why=M.begin_build(worker,rec)
assert(ok and why=="carrier-item-debited" and bags[1].stock==0)
ok,why=M.begin_build(worker,rec)
assert(not ok and why=="carrier-not-at-build-site",
  "a consumed item cannot be consumed twice")
ok,why=M.build_failed(worker,rec)
assert(ok and why=="carrier-refunded" and bags[1].stock==1)
ok,why=M.build_failed(worker,rec)
assert(not ok and why=="not-building")
ok,why=M.return_unused(worker,rec,source)
assert(not ok and why=="priest-not-at-physical-return"
  and source.stock==1 and bags[1].stock==1)
priest.position={x=0,y=0}
source.room=0
ok,why=M.return_unused(worker,rec,source)
assert(not ok and why=="return-inventory-full" and bags[1].stock==1)
source.room=10
ok,why=M.return_unused(worker,rec,source)
assert(ok and why=="physically-returned"
  and source.stock==2 and not bags[1].valid and not M.has_record(rec))
local rec2={id=43,station_item=item,ghost_position={x=30,y=0}}
ok,why=M.pickup(worker,rec2,source)
assert(ok and source.stock==1 and bags[2].stock==1)
priest.position={x=30,y=0}
assert(M.begin_build(worker,rec2))
assert(M.complete(worker,rec2))
assert(not bags[2].valid and not M.has_record(rec2)
  and source.stock==1,"successful build must consume exactly one real item")
-- Callback exceptions after the engine has inserted the item must not
-- produce a second item by refunding the carrier.
local rec3={id=44,station_item=item,ghost_position={x=30,y=0}}
priest.position={x=0,y=0}
assert(M.pickup(worker,rec3,source))
local original_insert=source.insert
source.insert=function(stack)
  original_insert(stack)
  error("post-insert callback exception")
end
ok,why=M.return_unused(worker,rec3,source)
assert(ok and why=="physically-returned"
  and source.stock==1 and not M.has_record(rec3)
  and not bags[3].valid,"post-insert exception must not duplicate the item")
source.insert=original_insert
-- A pre-insert failure must put the one real item back in the carrier.
local rec4={id=45,station_item=item,ghost_position={x=30,y=0}}
assert(M.pickup(worker,rec4,source))
source.insert=function()error("before insert")end
ok,why=M.return_unused(worker,rec4,source)
assert(not ok and why=="return-item-refunded-to-carrier"
  and source.stock==0 and bags[4].stock==1)
source.insert=original_insert
assert(M.return_unused(worker,rec4,source)
  and source.stock==1 and not M.has_record(rec4))
-- A source callback can also throw after actually removing the item.
-- The physical debit must still be accounted for exactly once.
local rec5={id=46,station_item=item,ghost_position={x=30,y=0}}
local original_remove=source.remove
source.remove=function(stack)
  original_remove(stack)
  error("post-debit callback exception")
end
ok,why=M.pickup(worker,rec5,source)
assert(ok and why=="physically-picked-up"
  and source.stock==0 and bags[5].stock==1,
  "post-debit exception must not discard a removed physical item")
source.remove=original_remove
assert(M.return_unused(worker,rec5,source)
  and source.stock==1 and not bags[5].valid)
-- The item stays in its original LuaInventory on carrier death.
local rec6={id=47,station_item=item,ghost_position={x=30,y=0}}
priest.position={x=0,y=0}
assert(M.pickup(worker,rec6,source) and source.stock==0 and bags[6].stock==1)
priest.position={x=12,y=0}
assert(M.observe_carrier(worker,rec6))
local old_pair={station=station,priest=priest,priest_unit=priest.unit_number}
assert(M.note_priest_lost(old_pair,priest)==1)
assert(M.note_priest_lost(old_pair,priest)==0,"death observation must be idempotent")
priest.valid=false
local successor={valid=true,unit_number=113,position={x=0,y=0}}
local successor_worker={station=station,priest=successor}
assert(not M.get(successor_worker,rec6),"no remote cargo inheritance")
local site=M.stranded_for(successor_worker,rec6)
assert(site and site.x==12 and bags[6].stock==1)
local stolen,reason=M.reclaim_stranded(successor_worker,rec6)
assert(not stolen and reason=="replacement-priest-not-at-death-site"
  and bags[6].stock==1 and #bags==6)
successor.position={x=12,y=0}
assert(M.reclaim_stranded(successor_worker,rec6))
assert(M.get(successor_worker,rec6) and bags[6].stock==1)
assert(not M.stranded_for(successor_worker,rec6),"no double salvage")
package.loaded["scripts.core.station_cargo_0824"]=nil
M=require("scripts.core.station_cargo_0824")
assert(M.get(successor_worker,rec6) and bags[6].stock==1,"reload custody")
successor.position={x=30,y=0}
assert(M.begin_build(successor_worker,rec6))
assert(M.build_failed(successor_worker,rec6))
successor.position={x=0,y=0}
assert(M.return_unused(successor_worker,rec6,source)
  and source.stock==1 and not bags[6].valid and not M.has_record(rec6))
-- Death in an empty mining reservation is ambiguous and cannot fabricate stock.
local rec7={id=48,station_item=item,ghost_position={x=30,y=0}}
local reserved,bag=M.reserve_recovery(successor_worker,rec7)
assert(reserved and bag.stock==0)
local successor_pair={station=station,priest=successor,priest_unit=successor.unit_number}
assert(M.note_priest_lost(successor_pair,successor)==1)
assert(not M.stranded_for({station=station,priest={valid=true,unit_number=114,position={x=0,y=0}}},rec7))
assert(bag.valid and bag.stock==0 and M.has_record(rec7),
  "unresolved mining must retain engine custody and fail closed")
-- Engine callbacks can throw AFTER a physical inventory mutation. All three
-- transfer directions must reconcile observed stock instead of treating the
-- callback's Lua return as the authoritative item count.
local rec8={id=49,station_item=item,ghost_position={x=30,y=0}}
successor.position={x=0,y=0}
assert(M.pickup(successor_worker,rec8,source) and source.stock==0)
local bag8=bags[8]
local debit8=bag8.remove
bag8.remove=function(stack)
  debit8(stack)
  error("post-build-debit exception")
end
successor.position={x=30,y=0}
ok,why=M.begin_build(successor_worker,rec8)
assert(ok and why=="carrier-item-debited" and bag8.stock==0
  and M.get(successor_worker,rec8).status=="building",
  "post-debit exception must not strand an empty carrying hold")
bag8.remove=debit8
local insert8=bag8.insert
bag8.insert=function(stack)
  insert8(stack)
  error("post-build-refund exception")
end
ok,why=M.build_failed(successor_worker,rec8)
assert(ok and why=="carrier-refunded" and bag8.stock==1
  and M.get(successor_worker,rec8).status=="carrying",
  "post-refund exception must not quarantine a physically returned item")
bag8.insert=insert8
successor.position={x=0,y=0}
assert(M.return_unused(successor_worker,rec8,source)
  and source.stock==1 and not M.has_record(rec8))

local rec9={id=50,station_item=item,ghost_position={x=30,y=0}}
assert(M.pickup(successor_worker,rec9,source) and source.stock==0)
local bag9=bags[9]
local debit9=bag9.remove
bag9.remove=function()error("pre-build-debit exception")end
successor.position={x=30,y=0}
ok,why=M.begin_build(successor_worker,rec9)
assert(not ok and why=="carrier-build-debit-refused" and bag9.stock==1
  and M.get(successor_worker,rec9).status=="carrying")
bag9.remove=debit9
assert(M.begin_build(successor_worker,rec9))
local insert9=bag9.insert
bag9.insert=function()error("pre-build-refund exception")end
ok,why=M.build_failed(successor_worker,rec9)
assert(not ok and why=="carrier-build-refund-refused" and bag9.stock==0
  and M.get(successor_worker,rec9).status=="building",
  "rejected refund must retain pending debit for later retry")
bag9.insert=insert9
assert(M.build_failed(successor_worker,rec9) and bag9.stock==1)
successor.position={x=0,y=0}
assert(M.return_unused(successor_worker,rec9,source)
  and source.stock==1 and not M.has_record(rec9))

local rec10={id=51,station_item=item,ghost_position={x=30,y=0}}
assert(M.pickup(successor_worker,rec10,source) and source.stock==0)
local bag10=bags[10]
local debit10=bag10.remove
bag10.remove=function(stack)
  debit10(stack)
  error("post-return-debit exception")
end
ok,why=M.return_unused(successor_worker,rec10,source)
assert(ok and why=="physically-returned" and source.stock==1
  and not M.has_record(rec10) and not bag10.valid,
  "post-return-debit exception must not lose an item")
local rec11={id=52,station_item=item,ghost_position={x=30,y=0}}
assert(M.pickup(successor_worker,rec11,source) and source.stock==0)
local bag11=bags[11]
local debit11=bag11.remove
bag11.remove=function()error("pre-return-debit exception")end
ok,why=M.return_unused(successor_worker,rec11,source)
assert(not ok and why=="return-cargo-debit-refused"
  and source.stock==0 and bag11.stock==1)
bag11.remove=debit11
assert(M.return_unused(successor_worker,rec11,source)
  and source.stock==1 and not M.has_record(rec11))

local rec12={id=53,station_item=item,ghost_position={x=30,y=0}}
local create12=game.create_inventory
game.create_inventory=function(size)
  local bag=create12(size)
  bag.insert=function()error("carrier insert rejected")end
  return bag
end
local source_insert12=source.insert
source.insert=function(stack)
  source_insert12(stack)
  error("source refund callback threw after insert")
end
ok,why=M.pickup(successor_worker,rec12,source)
assert(not ok and why=="carrier-debit-refunded"
  and source.stock==1 and not M.has_record(rec12)
  and not bags[12].valid,
  "post-refund source exception must not leave a false custody error")
source.insert=source_insert12
game.create_inventory=create12
print("station cargo 0827: post-mutation callback reconciliation, interrupted refund, and exact item custody PASS")
print("station cargo 0824: physical pickup, custody, identity, reload, refund, return, death-site salvage PASS")
