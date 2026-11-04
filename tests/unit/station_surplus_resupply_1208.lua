-- Original native storage and Factorio unit movement are simulated here;
-- the separate 2.0.77 scenario checks real built/pair outcomes.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local R=require("scripts.core.station_surplus_resupply_1208")
local function inventory(items)
  local i={valid=true,items=items or {},capacity=1000}
  i.get_item_count=function(n)
    if n==nil then
      local count=0
      for _,v in pairs(i.items)do count=count+v end
      return count
    end
    return i.items[n] or 0
  end
  i.get_insertable_count=function(n)
    return math.max(0,i.capacity-i.get_item_count())
  end
  i.insert=function(spec)
    local n=math.min(spec.count,i.get_insertable_count(spec.name))
    i.items[spec.name]=(i.items[spec.name] or 0)+n
    return n
  end
  i.remove=function(spec)
    local n=math.min(spec.count,i.get_item_count(spec.name))
    i.items[spec.name]=(i.items[spec.name] or 0)-n
    return n
  end
  i.destroy=function()i.valid=false end
  return i
end
local stock="junior-cogitator-station"
local force,surface={index=1},{index=1}
local function pair(id,x,items)
  local inv=inventory(items)
  return {
    radius=30,station={valid=true,unit_number=id,
      name=id==100 and "junior-cogitator-station"
        or "intermediate-cogitator-station",
      position={x=x,y=0},force=force,surface=surface,
      get_inventory=function(which)assert(which==1);return inv end},
    priest={valid=true,unit_number=id+1,force=force,surface=surface,
      position={x=x,y=0}},
  },inv
end
local receiver,home=pair(100,0,{})
local donor,source=pair(200,20,{[stock]=3})
local rec={id=23,status="active",worker_station_unit=100,
  station_item=stock,station_entity=stock}
storage={tech_priests={pairs_by_station={[100]=receiver,[200]=donor},
  station_expansion_0256={[23]=rec},
  station_expansion_by_worker_0256={[100]=23}}}
local bag_count=0
game={tick=600,create_inventory=function(n)
  assert(n==1)
  bag_count=bag_count+1
  return inventory()
end}
defines={inventory={chest=1},distraction={none=0}}
local moves={}
tech_priests_request_movement_0418=function(p,pos,why,opts)
  assert(p==receiver and opts.owner=="station-surplus-relay-1208"
    and opts.radius==2 and opts.priority==72)
  moves[#moves+1]={x=pos.x,y=pos.y,reason=why,owner=opts.owner}
  return true
end
refresh_pair_radius=function()return 30 end
local r,why=R.find_donor(receiver,stock)
assert(r==donor and why=="physical-surplus-source",
  "real donor was not identified by same-surface physical stock")
local ok,reason=R.service(receiver,rec)
assert(ok and reason=="surplus-moving-to-physical-source"
  and #moves==1 and moves[1].x==20
  and home.get_item_count(stock)==0
  and source.get_item_count(stock)==3
  and bag_count==1,
  "remote source was magically debited before arrival")
local source_route={owner="station-surplus-relay-1208",
  reason="station-surplus-pickup-1208",x=20,y=0}
assert(R.authorized_movement(receiver,source_route)
  and not R.authorized_movement(receiver,{
     owner="unrelated-task",reason=source_route.reason,x=20,y=0}),
  "physical trip route accepted unrelated movement owner")
receiver.priest.position={x=20,y=0}
game.tick=900
ok,reason=R.service(receiver,rec)
local escrow=receiver.station_surplus_resupply_1208
assert(ok and reason=="physically-carried-one-station-item"
  and source.get_item_count(stock)==2
  and home.get_item_count(stock)==0
  and escrow and escrow.phase=="to-home"
  and escrow.bag.get_item_count(stock)==1,
  "physical donor debit was not retained in engine cargo")
local return_route={owner="station-surplus-relay-1208",
  reason="station-surplus-return-1208",x=0,y=0}
assert(R.authorized_movement(receiver,return_route)
  and not R.authorized_movement(receiver,source_route),
  "wrong leg was authorized while physically carrying cargo")
game.tick=1020
ok,reason=R.service(receiver,rec)
assert(ok and reason=="surplus-returning-with-physical-cargo"
  and moves[#moves].x==0 and home.get_item_count(stock)==0
  and escrow.bag.get_item_count(stock)==1,
  "carried item arrived at station without a real return")
receiver.priest.position={x=0,y=0}
home.capacity=0
game.tick=1200
ok,reason=R.service(receiver,rec)
assert(ok and reason=="receiver-engine-inventory-full"
  and source.get_item_count(stock)==2
  and home.get_item_count(stock)==0
  and escrow.bag.get_item_count(stock)==1,
  "full home inventory lost carried cargo")
home.capacity=1000
ok,reason=R.service(receiver,rec)
assert(ok and reason=="real-neighbor-surplus-physically-delivered"
  and source.get_item_count(stock)==2
  and home.get_item_count(stock)==1
  and escrow.bag.valid==false
  and not receiver.station_surplus_resupply_1208
  and receiver.station_surplus_last_receipt_1208.quantity==1
  and receiver.station_surplus_last_receipt_1208.donor_unit==200
  and receiver.station_surplus_last_receipt_1208.donor_readback_before==3
  and receiver.station_surplus_last_receipt_1208.donor_readback_after==2
  and receiver.station_surplus_last_receipt_1208.picked_tick
      <=receiver.station_surplus_last_receipt_1208.delivered_tick,
  "real source and destination inventory conservation failed")
ok=R.service(receiver,rec)
assert(not ok and bag_count==1 and home.get_item_count(stock)==1,
  "delivered station item could be duplicated on a retry")
home.remove{name=stock,count=1}
source.remove{name=stock,count=1}
assert(R.find_donor(receiver,stock)==nil,
  "sole donor reserve was not protected")
source.insert{name=stock,count=1}
storage.tech_priests.station_expansion_by_worker_0256[200]=99
assert(R.find_donor(receiver,stock)==nil,
  "another active expansion was robbed of its own last station item")
storage.tech_priests.station_expansion_by_worker_0256[200]=nil
donor.station.force={index=2}
assert(R.find_donor(receiver,stock)==nil,
  "cross-force source was treated as a shared stockpile")
donor.station.force=force
donor.station.surface={index=5}
assert(R.find_donor(receiver,stock)==nil,
  "cross-surface inventory was treated as locally accessible")
donor.station.surface=surface
assert(R.find_donor(receiver,stock)==donor,
  "eligible donor did not return after authority was restored")
ok=R.service(receiver,rec)
assert(ok and receiver.station_surplus_resupply_1208,
  "new physical courier was not reserved for an empty recipient")
local unclaimed=receiver.station_surplus_resupply_1208
receiver.priest.unit_number=777
ok,reason=R.service(receiver,rec)
assert(ok and reason=="surplus-custody-quarantined"
  and receiver.station_surplus_resupply_1208==unclaimed
  and not R.authorized_movement(receiver,source_route)
  and home.get_item_count(stock)==0
  and source.get_item_count(stock)==2,
  "wrong priest was allowed to take custody of real supply")
-- A donor can become depleted AFTER the courier has selected it but
-- BEFORE its first pickup. No cargo is owned yet: release the empty hold
-- and retry another physically stocked neighbor, never inventing a kit.
local second,second_home=pair(300,-2,{})
second.station.name=stock
local rec2={id=24,status="active",worker_station_unit=300,
  station_item=stock,station_entity=stock}
storage.tech_priests.pairs_by_station[300]=second
storage.tech_priests.station_expansion_0256[24]=rec2
storage.tech_priests.station_expansion_by_worker_0256[300]=24
local backup,backup_stock=pair(400,15,{[stock]=3})
local second_moves={}
tech_priests_request_movement_0418=function(p,pos,why,opts)
  assert(p==second and opts.owner=="station-surplus-relay-1208")
  second_moves[#second_moves+1]={x=pos.x,reason=why}
  return true
end
game.tick=1800
ok,reason=R.service(second,rec2)
local abandoned=second.station_surplus_resupply_1208
assert(ok and reason=="surplus-moving-to-physical-source"
  and abandoned and abandoned.donor_station_unit==200
  and abandoned.bag.valid and abandoned.bag.get_item_count()==0,
  "initial donor was not physically selected before depletion")
source.remove{name=stock,count=1}
assert(source.get_item_count(stock)==1)
storage.tech_priests.pairs_by_station[400]=backup
game.tick=1860
ok,reason=R.service(second,rec2)
assert(ok and reason=="unfunded-donor-depleted-reselect"
  and not second.station_surplus_resupply_1208
  and abandoned.bag.valid==false
  and source.get_item_count(stock)==1
  and second_home.get_item_count(stock)==0
  and backup_stock.get_item_count(stock)==3,
  "unfunded donor depletion lost stock or stranded an empty hold")
game.tick=1920
ok,reason=R.service(second,rec2)
local switched=second.station_surplus_resupply_1208
assert(ok and reason=="surplus-moving-to-physical-source"
  and switched and switched.donor_station_unit==400
  and switched.bag.valid and switched.bag.get_item_count()==0,
  "surplus relay did not select the eligible alternative donor")
second.priest.position={x=15,y=0}
game.tick=2000
ok,reason=R.service(second,rec2)
assert(ok and reason=="physically-carried-one-station-item"
  and switched.bag.get_item_count(stock)==1
  and backup_stock.get_item_count(stock)==2
  and second_home.get_item_count(stock)==0,
  "alternative donor was remotely credited or lost its physical debit")
second.priest.position={x=-2,y=0}
game.tick=2100
ok,reason=R.service(second,rec2)
assert(ok and reason=="real-neighbor-surplus-physically-delivered"
  and second_home.get_item_count(stock)==1
  and backup_stock.get_item_count(stock)==2
  and source.get_item_count(stock)==1
  and switched.bag.valid==false,
  "alternative donor transfer did not conserve real physical inventories")

-- The opposite boundary is deliberate: after pickup an invalid donor must
-- NOT cause the courier to delete, reassign or re-mint its carried item.
second_home.remove{name=stock,count=1}
local rec3={id=25,status="active",worker_station_unit=300,
  station_item=stock,station_entity=stock}
storage.tech_priests.station_expansion_0256[25]=rec3
storage.tech_priests.station_expansion_by_worker_0256[300]=25
game.tick=2200
ok,reason=R.service(second,rec3)
local held=second.station_surplus_resupply_1208
assert(ok and held and held.donor_station_unit==400)
second.priest.position={x=15,y=0}
game.tick=2280
ok,reason=R.service(second,rec3)
assert(ok and reason=="physically-carried-one-station-item"
  and backup_stock.get_item_count(stock)==1
  and held.bag.get_item_count(stock)==1)
-- A different priest domain cannot quietly take over escrow after pickup.
second.priest.force={index=9}
game.tick=2310
ok,reason=R.service(second,rec3)
assert(not ok and reason=="no-valid-expansion-writ"
  and held.bag.valid and held.bag.get_item_count(stock)==1
  and not R.authorized_movement(second,{
    owner="station-surplus-relay-1208",
    reason="station-surplus-return-1208",x=-2,y=0}),
  "cross-force priest was allowed to carry or destroy another force's kit")
second.priest.force=force
second.priest.surface={index=9}
ok,reason=R.service(second,rec3)
assert(not ok and reason=="no-valid-expansion-writ"
  and held.bag.get_item_count(stock)==1,
  "cross-surface priest inherited physical surplus escrow")
second.priest.surface=surface

-- The *donor* can be physically destroyed after its genuine debit.
-- Its disappearance must not strand the item in escrow forever: the
-- original receiver still walks it home and deposits it from the real bag.
backup.station.valid=false
game.tick=2340
local final_route={owner="station-surplus-relay-1208",
  reason="station-surplus-return-1208",x=-2,y=0}
assert(R.authorized_movement(second,final_route)
  and not R.authorized_movement(second,{
    owner="station-surplus-relay-1208",
    reason="station-surplus-pickup-1208",x=15,y=0}),
  "valid return route was blocked by a lost donor or pickup still authorized")
ok,reason=R.service(second,rec3)
assert(ok and reason=="surplus-returning-with-physical-cargo"
  and second.station_surplus_resupply_1208==held
  and held.bag.valid and held.bag.get_item_count(stock)==1
  and second_home.get_item_count(stock)==0
  and second_moves[#second_moves].x==-2
  and second_moves[#second_moves].reason=="station-surplus-return-1208",
  "lost donor did not permit the original priest's physical cargo return")
second.priest.position={x=-2,y=0}
game.tick=2460
ok,reason=R.service(second,rec3)
local last=second.station_surplus_last_receipt_1208
assert(ok and reason=="real-neighbor-surplus-physically-delivered"
  and second_home.get_item_count(stock)==1
  and source.get_item_count(stock)==1
  and backup_stock.get_item_count(stock)==1
  and held.bag.valid==false
  and not second.station_surplus_resupply_1208
  and last.record_id==25 and last.donor_unit==400
  and last.donor_readback_before==2
  and last.donor_readback_after==1
  and last.destination_readback==1,
  "lost-donor return failed physical inventory/provenance conservation")
-- Module reload in the middle of real item custody must not restart the
-- courier, clear the hold or duplicate its donor debit. Factorio's separate
-- engine process save/reload is a distinct native acceptance obligation.
local reload_donor,reload_stock=pair(500,-14,{[stock]=3})
storage.tech_priests.pairs_by_station[500]=reload_donor
second_home.remove{name=stock,count=1}
local rec4={id=26,status="active",worker_station_unit=300,
  station_item=stock,station_entity=stock}
storage.tech_priests.station_expansion_0256[26]=rec4
storage.tech_priests.station_expansion_by_worker_0256[300]=26
game.tick=2600
ok,reason=R.service(second,rec4)
local reload_bag=second.station_surplus_resupply_1208
assert(ok and reload_bag and reload_bag.donor_station_unit==500
  and reload_stock.get_item_count(stock)==3
  and reload_bag.bag.get_item_count(stock)==0,
  "in-flight reload fixture was not empty before physical pickup")
second.priest.position={x=-14,y=0}
game.tick=2660
ok,reason=R.service(second,rec4)
assert(ok and reason=="physically-carried-one-station-item"
  and reload_stock.get_item_count(stock)==2
  and reload_bag.bag.get_item_count(stock)==1)
local before_reload_bags=bag_count
package.loaded["scripts.core.station_surplus_resupply_1208"]=nil
local AfterReload=require("scripts.core.station_surplus_resupply_1208")
assert(AfterReload.has_record(second,rec4)
  and second.station_surplus_resupply_1208==reload_bag
  and reload_bag.bag.valid
  and reload_bag.bag.get_item_count(stock)==1,
  "module reload lost actual saved physical escrow identity")
game.tick=2740
ok,reason=AfterReload.service(second,rec4)
assert(ok and reason=="surplus-returning-with-physical-cargo"
  and reload_stock.get_item_count(stock)==2
  and reload_bag.bag.get_item_count(stock)==1
  and bag_count==before_reload_bags,
  "module reload fabricated a new hold or re-debited the original donor")
second.priest.position={x=-2,y=0}
game.tick=2800
ok,reason=AfterReload.service(second,rec4)
local receipt4=second.station_surplus_last_receipt_1208
assert(ok and reason=="real-neighbor-surplus-physically-delivered"
  and second_home.get_item_count(stock)==1
  and reload_stock.get_item_count(stock)==2
  and reload_bag.bag.valid==false
  and not second.station_surplus_resupply_1208
  and bag_count==before_reload_bags
  and receipt4.record_id==26 and receipt4.donor_unit==500
  and receipt4.donor_readback_before==3
  and receipt4.donor_readback_after==2,
  "module reload return did not conserve counted inventory and receipt")
print("[station-surplus-resupply-1208] PASS physical pickup, donor reselection, cross-domain quarantine, post-debit donor loss, module-reload carried custody, zero duplication")
