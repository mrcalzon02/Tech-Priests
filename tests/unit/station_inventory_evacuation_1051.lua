-- 1051: physical distant inventory evacuation regression (no remote deposits).
-- Executed from the existing station-relocation source-validation step.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local function inventory(items,capacity)
  local inv={valid=true}
  local slots={}
  for i=1,capacity do
    local item=items[i]
    local s={valid=true,valid_for_read=item~=nil,
      name=item and item.name or nil,count=item and item.count or 0,
      quality=item and item.quality or nil}
    s.transfer_stack=function(from,amount)
      assert(not s.valid_for_read and from.valid_for_read)
      assert(amount>0 and from.count>=amount)
      s.name,s.count,s.quality=from.name,amount,from.quality
      s.valid_for_read=true
      from.count=from.count-amount
      if from.count==0 then
        from.valid_for_read=false
        from.name,from.quality=nil,nil
      end
      return true
    end
    slots[i]=s
  end
  setmetatable(inv,{__len=function()return capacity end,
    __index=function(_,key)return slots[key] end})
  inv.get_contents=function()
    local out={}
    for _,s in ipairs(slots) do
      if s.valid_for_read then
        out[#out+1]={name=s.name,count=s.count,quality=s.quality}
      end
    end
    return out
  end
  inv.destroy=function() inv.valid=false end
  return inv
end
local force={name="player"}
local surface={index=1,find_logistic_network_by_position=function()return nil end}
local function pair(id,rank,name,pos,inv)
  local station={valid=true,unit_number=id,name=name,
    force=force,surface=surface,position={x=pos,y=0},minable=true,
    prototype={mineable_properties={products={{name=name,type="item",amount=1}}}}}
  local priest={valid=true,unit_number=id+100,
    force=force,surface=surface,position={x=20,y=0},
    get_main_inventory=function()return inventory({},1)end}
  return {station=station,priest=priest,rank=rank,mode="idle",
    inventory=inv,command_hierarchy_0480={
      superior_unit=id==11 and 10 or nil,
      direct_subordinate_units={},peer_units={}}}
end
defines={inventory={chest=1},
  command={go_to_location=1},distraction={none=0}}
game={tick=1051,create_inventory=function(n)return inventory({},n)end}
local parent_inv=inventory({},2)
local child_inv=inventory({
  {name="iron-ore",count=13,quality="normal"},
  {name="copper-plate",count=7,quality="uncommon"}},3)
local parent=pair(10,2,"intermediate-cogitator-station",0,parent_inv)
local child=pair(11,1,"junior-cogitator-station",20,child_inv)
local rec={id=1051,status="active",worker_station_unit=10,
  station_item="junior-cogitator-station",
  recycling_candidate_unit_0822=11,ghost_unit=300,
  ghost_position={x=30,y=0}}
storage={tech_priests={pairs_by_station={[10]=parent,[11]=child},
  pairs_by_priest={[110]=parent,[111]=child},
  station_by_priest={[110]=10,[111]=11},
  station_expansion_0256={[1051]=rec}}}
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  rank=function(p)return p.rank end,
  is_direct_subordinate=function(p,c)
    return c.command_hierarchy_0480.superior_unit==p.station.unit_number
  end,peers=function()return {}end,rebuild=function()return true end}
_G.tech_priests_0358_station_sources_for_pair=function(p)
  return {{owner=p.station,inv=p.inventory}}
end
package.loaded["scripts.core.station_recycling_0822"]=nil
package.loaded["scripts.core.station_inventory_evacuation_1048"]=nil
local Recovery=require("scripts.core.station_recycling_0822")
local Evac=require("scripts.core.station_inventory_evacuation_1048")
local ok,why=Recovery.check_candidate(parent,child,rec.station_item)
assert(not ok and why=="station-inventory-not-empty")
assert(Recovery.check_evacuable_candidate(parent,child,rec.station_item,rec.id))
local chosen=Recovery.find_candidate(parent,rec.station_item,{x=40,y=0})
assert(not chosen,"ordinary candidate search must not select occupied stock")
chosen=Recovery.find_candidate(parent,rec.station_item,{x=40,y=0},true)
assert(chosen==child,"occupied candidate requires safe evacuation preflight")
local commands={}
local function command(_,spec)
  commands[#commands+1]=spec
  return true
end
-- Pickup must happen at the CHILD; no parent inventory may change remotely.
ok,why=Evac.service_remote(parent,child,rec,command)
assert(not ok and why=="evacuation-counted-source-pickup")
local entry=Evac.remote_record(child)
assert(entry and entry.bag.valid and entry.bag[1].count==13
  and not child_inv[1].valid_for_read
  and not parent_inv[1].valid_for_read)
assert(not Recovery.check_candidate(parent,child,rec.station_item,nil,false,rec.id),
  "an in-flight inventory must reserve the physical station against mining")
ok,why=Evac.service_remote(parent,child,rec,command)
assert(not ok and why=="evacuation-carrying-to-parent"
  and #commands==1 and commands[1].destination.x==0
  and parent.priest.position.x==20 and not parent_inv[1].valid_for_read)
-- An incorrect writ/worker cannot take the existing engine-owned hold.
rec.worker_station_unit=999
ok,why=Evac.service_remote(parent,child,rec,command)
assert(not ok and why=="evacuation-physical-owner-invalid"
  and entry.bag[1].count==13)
rec.worker_station_unit=10
-- A save/reload must retain the SAME LuaInventory and custody receipt.
package.loaded["scripts.core.station_inventory_evacuation_1048"]=nil
Evac=require("scripts.core.station_inventory_evacuation_1048")
assert(Evac.remote_record(child)==entry)
parent.priest.position={x=0,y=0}
game.tick=1052
ok,why=Evac.service_remote(parent,child,rec,command)
assert(not ok and why=="evacuation-counted-parent-deposit"
  and parent_inv[1].name=="iron-ore" and parent_inv[1].count==13
  and entry.bag[1].count==0)
-- Second real stack cannot be collected until walking BACK to the source.
ok,why=Evac.service_remote(parent,child,rec,command)
assert(not ok and why=="evacuation-returning-to-child"
  and child_inv[2].count==7 and entry.bag[1].count==0)
parent.priest.position={x=20,y=0}
game.tick=1053
ok,why=Evac.service_remote(parent,child,rec,command)
assert(not ok and why=="evacuation-counted-source-pickup"
  and not child_inv[2].valid_for_read
  and entry.bag[1].count==7 and entry.bag[1].quality=="uncommon")
-- Destination congestion must not erase or remotely credit carried stock.
parent_inv[2].valid_for_read=true
parent_inv[2].name="stone"
parent_inv[2].count=1
parent_inv[2].quality="normal"
parent.priest.position={x=0,y=0}
game.tick=1054
ok,why=Evac.service_remote(parent,child,rec,command)
assert(not ok and why=="evacuation-parent-inventory-full"
  and entry.bag[1].count==7 and parent_inv[1].count==13)
parent_inv[2].valid_for_read=false
parent_inv[2].name,parent_inv[2].quality=nil,nil
parent_inv[2].count=0
ok,why=Evac.service_remote(parent,child,rec,command)
assert(not ok and why=="evacuation-counted-parent-deposit"
  and parent_inv[2].name=="copper-plate"
  and parent_inv[2].quality=="uncommon"
  and parent_inv[2].count==7)
assert(not Evac.complete_remote(rec,11),
  "a remote evacuation cannot complete until the worker returns to the child")
parent.priest.position={x=20,y=0}
game.tick=1055
ok,why=Evac.service_remote(parent,child,rec,command)
assert(ok and why=="evacuation-complete"
  and entry.status=="ready-to-mine")
assert(Recovery.check_candidate(parent,child,rec.station_item,nil,false,rec.id))
assert(not Recovery.check_candidate(parent,child,rec.station_item),
  "unrelated mining must not consume the reserved station")
assert(Evac.complete_remote(rec,11) and not entry.bag.valid
  and not Evac.remote_record(child))
assert(rec.inventory_evacuation_1048.physical_carrier
  and rec.inventory_evacuation_1048.item_counts["iron-ore"]==13
  and rec.inventory_evacuation_1048.item_counts["copper-plate"]==7
  and rec.inventory_evacuation_1048.stack_transfers==2)
assert(parent_inv[1].count==13 and parent_inv[2].count==7)
print("[station-inventory-evacuation-1051] PASS: real stack pickup, walking custody, parent deposit, reload, full storage, writ denial, mining gate and counted receipt")
