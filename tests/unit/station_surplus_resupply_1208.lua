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
  and receiver.station_surplus_last_receipt_1208.donor_unit==200,
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
print("[station-surplus-resupply-1208] PASS physical source/debit/bag/return/deposit; no remote credit, duplicates, theft, or cross-domain pickup")
