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
print("station cargo 0824: physical pickup, custody, identity, reload, refund, return PASS")
