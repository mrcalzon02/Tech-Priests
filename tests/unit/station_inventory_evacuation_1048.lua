-- 1048 regression, executed from existing station-relocation validation.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local function inventory(items,capacity)
  local inv={valid=true}
  local stacks={}
  for i=1,capacity do
    local source=items[i]
    local s={valid=true,valid_for_read=source~=nil,
      name=source and source.name or nil,
      count=source and source.count or 0,
      quality=source and source.quality or nil}
    s.transfer_stack=function(from,amount)
      assert(not s.valid_for_read)
      assert(from.valid_for_read and from.count==amount)
      s.valid_for_read=true
      s.name,s.count,s.quality=from.name,amount,from.quality
      from.count=0
      from.name,from.quality,from.valid_for_read=nil,nil,false
      return true
    end
    stacks[i]=s
  end
  setmetatable(inv,{__len=function() return capacity end,
    __index=function(_,k) return stacks[k] end})
  inv.get_contents=function()
    local out={}
    for _,s in ipairs(stacks) do
      if s.valid_for_read then
        out[#out+1]={name=s.name,count=s.count,quality=s.quality}
      end
    end
    return out
  end
  inv.get_item_count=function(item)
    local n=0
    for _,s in ipairs(stacks) do
      if s.valid_for_read and (not item or s.name==item) then n=n+s.count end
    end
    return n
  end
  inv.get_insertable_count=function() return capacity end
  return inv
end
local f={name="player"}
local surface={index=1,find_logistic_network_by_position=function() return nil end}
local function pair(id,rank,name,stock)
  local station={valid=true,unit_number=id,name=name,force=f,surface=surface,
    position={x=id==11 and 4 or 0,y=0},minable=true,
    prototype={mineable_properties={products={{name=name,type="item",amount=1}}}}}
  local priest={valid=true,unit_number=id+100,force=f,surface=surface,
    position={x=2,y=0},
    get_main_inventory=function() return inventory({},1) end}
  return {station=station,priest=priest,rank=rank,mode="idle",
    inventory=stock,command_hierarchy_0480={
      superior_unit=id==11 and 10 or nil,direct_subordinate_units={},peer_units={}}}
end
defines={inventory={chest=1},events={script_raised_destroy=11}}
game={tick=1048}
local parent=pair(10,2,"intermediate-cogitator-station",inventory({},4))
local child=pair(11,1,"junior-cogitator-station",inventory({
  {name="iron-ore",count=13,quality="normal"},
  {name="copper-plate",count=7,quality="uncommon"}},3))
storage={tech_priests={pairs_by_station={[10]=parent,[11]=child},
  pairs_by_priest={[110]=parent,[111]=child},
  station_by_priest={[110]=10,[111]=11},
  station_expansion_0256={}}}
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  rank=function(p) return p.rank end,
  is_direct_subordinate=function(p,c)
    return c.command_hierarchy_0480.superior_unit==p.station.unit_number
  end,peers=function() return {} end,rebuild=function() return true end}
_G.tech_priests_0358_station_sources_for_pair=function(p)
  return {{owner=p.station,inv=p.inventory}}
end
package.loaded["scripts.core.station_recycling_0822"]=nil
package.loaded["scripts.core.station_inventory_evacuation_1048"]=nil
local Recovery=require("scripts.core.station_recycling_0822")
local Evac=require("scripts.core.station_inventory_evacuation_1048")
local rec={id=1048,status="active",worker_station_unit=10,
  station_item="junior-cogitator-station"}
local ok,why=Recovery.check_candidate(parent,child,rec.station_item)
assert(not ok and why=="station-inventory-not-empty",
  "ordinary physical mine must still reject occupied station")
ok,why=Evac.service_local(parent,child,rec)
assert(not ok and why=="evacuation-stack-moved")
assert(parent.inventory.get_item_count("iron-ore")==13
  and child.inventory.get_item_count("iron-ore")==0
  and child.inventory.get_item_count("copper-plate")==7)
local original_priest=child.priest
local foreign={id=1049,status="active",worker_station_unit=10,
  station_item=rec.station_item}
ok,why=Evac.service_local(parent,child,foreign)
assert(not ok and why=="evacuation-existing-writ-or-priest-mismatch")
parent.priest.position={x=99,y=0}
ok,why=Evac.service_local(parent,child,rec)
assert(not ok and why=="evacuation-physical-owner-or-reach-invalid")
parent.priest.position={x=2,y=0}
parent.combat_target={valid=true}
ok,why=Evac.service_local(parent,child,rec)
assert(not ok and why=="evacuation-worker-busy-or-carried-custody"
  and child.inventory.get_item_count("copper-plate")==7)
parent.combat_target=nil
storage.tech_priests.station_cargo_0824={
  [500]={station_unit=10,priest_unit=110}}
ok,why=Evac.service_local(parent,child,rec)
assert(not ok and why=="evacuation-worker-has-engine-cargo"
  and child.inventory.get_item_count("copper-plate")==7)
storage.tech_priests.station_cargo_0824=nil
storage.tech_priests.station_relocation_0823={
  [99]={old_unit=99,worker_unit=10}}
ok,why=Evac.service_local(parent,child,rec)
assert(not ok and why=="evacuation-other-relocation-lease"
  and child.inventory.get_item_count("copper-plate")==7)
storage.tech_priests.station_relocation_0823=nil
package.loaded["scripts.core.station_inventory_evacuation_1048"]=nil
Evac=require("scripts.core.station_inventory_evacuation_1048")
ok,why=Evac.service_local(parent,child,rec)
assert(not ok and why=="evacuation-stack-moved")
assert(parent.inventory.get_item_count("copper-plate")==7
  and child.inventory.get_item_count("copper-plate")==0
  and parent.inventory[2].quality=="uncommon",
  "engine transfer must preserve item quality")
ok,why=Evac.service_local(parent,child,rec)
assert(ok and why=="evacuation-complete")
assert(Recovery.check_candidate(parent,child,rec.station_item,nil,false,rec.id),
  "ordinary mining may begin only after station inventory becomes empty")
assert(not Recovery.check_candidate(parent,child,rec.station_item),
  "foreign mine cannot consume another evacuation writ")
assert(storage.tech_priests.station_inventory_evacuation_1048[11].status
  =="ready-to-mine" and child.priest==original_priest)
assert(Evac.complete_local(rec,11))
assert(not storage.tech_priests.station_inventory_evacuation_1048[11]
  and rec.inventory_evacuation_1048.item_counts["iron-ore"]==13
  and rec.inventory_evacuation_1048.item_counts["copper-plate"]==7
  and rec.inventory_evacuation_1048.stack_transfers==2)
-- A full parent must fail closed without modifying a nonempty subordinate.
local child2=pair(12,1,"junior-cogitator-station",
  inventory({{name="stone",count=4,quality="normal"}},1))
child2.command_hierarchy_0480.superior_unit=10
child2.station.position={x=4,y=0}
storage.tech_priests.pairs_by_station[12]=child2
parent.inventory=inventory({
  {name="iron-ore",count=1},{name="copper-plate",count=1}},2)
ok,why=Evac.service_local(parent,child2,{id=1050,status="active",
  worker_station_unit=10,station_item="junior-cogitator-station"})
assert(not ok and why=="evacuation-parent-inventory-full"
  and child2.inventory.get_item_count("stone")==4
  and child2.station.valid and child2.priest.valid)
assert(not Recovery.check_candidate(parent,child2,"junior-cogitator-station"))
-- Execute the actual 0823 local mining entry point, not just its helper.
-- First tick moves ore; the next tick mines exactly one real station item.
local child3=pair(13,1,"junior-cogitator-station",
  inventory({{name="iron-ore",count=9,quality="normal"}},1))
child3.command_hierarchy_0480.superior_unit=10
child3.station.position={x=4,y=0}
storage.tech_priests.pairs_by_station[13]=child3
storage.tech_priests.pairs_by_priest[113]=child3
storage.tech_priests.station_by_priest[113]=13
parent.inventory=inventory({},4)
local receiver=parent.inventory
local ghost={valid=true,name="entity-ghost",unit_number=1700,
  ghost_name="junior-cogitator-station",force=f,surface=surface,
  position={x=20,y=0}}
local writ={id=1051,status="active",worker_station_unit=10,
  station_item="junior-cogitator-station",
  station_entity="junior-cogitator-station",
  ghost_unit=1700,ghost_position={x=20,y=0}}
package.loaded["scripts.core.station_relocation_0823"]=nil
local Reloc=require("scripts.core.station_relocation_0823")
local mine_count=0
child3.station.mine=function(args)
  mine_count=mine_count+1
  assert(args.inventory==receiver and args.force==true)
  assert(Reloc.intercept_removed(child3.station,
    {name=defines.events.script_raised_destroy}))
  child3.station.valid=false
  local slot=receiver[2]
  assert(not slot.valid_for_read)
  slot.valid_for_read=true
  slot.name,slot.count,slot.quality="junior-cogitator-station",1,"normal"
  return true
end
ok,why=Reloc.try_recover(parent,child3,writ,ghost,receiver)
assert(not ok and why=="evacuation-stack-moved"
  and mine_count==0 and child3.station.valid
  and receiver.get_item_count("iron-ore")==9,
  "first live recovery service must move ore without mining")
ok,why=Reloc.try_recover(parent,child3,writ,ghost,receiver)
assert(ok and why=="physical-station-mined" and mine_count==1
  and not child3.station.valid and child3.priest.valid
  and storage.tech_priests.pairs_by_station[13]==nil
  and storage.tech_priests.pairs_by_priest[113]==child3
  and receiver.get_item_count("iron-ore")==9
  and receiver.get_item_count("junior-cogitator-station")==1
  and writ.inventory_evacuation_1048.item_counts["iron-ore"]==9
  and storage.tech_priests.station_inventory_evacuation_1048[13]==nil,
  "second service must mine one item and preserve counted ore and priest")
ok,why=Reloc.try_recover(parent,child3,writ,ghost,receiver)
assert(ok and why=="existing-relocation-mined" and mine_count==1,
  "reload/retry cannot mint a second station item")
-- A separate native-style remote courier can deposit when AT the original
-- parent and be observed after leaving. Its persisted receipt must prove
-- the actual transfer-time position, physical bag debit and stock delta.
-- Reading the priest's much later position is NOT a remote-transfer test.
do
  local remote_parent=pair(30,2,"intermediate-cogitator-station",
    inventory({},4))
  local remote_child=pair(31,1,"junior-cogitator-station",
    inventory({{name="iron-chest",count=1,quality="normal"}},1))
  remote_parent.station.position={x=0,y=0}
  remote_child.station.position={x=24,y=0}
  remote_parent.priest.position={x=24,y=0}
  remote_child.priest.position={x=24,y=0}
  remote_child.command_hierarchy_0480.superior_unit=30
  local new_rec={id=3048,status="active",worker_station_unit=30,
    requester_station_unit=30,
    recycling_candidate_unit_0822=31,
    station_item="junior-cogitator-station",
    station_entity="junior-cogitator-station",
    ghost_unit=3049,ghost_position={x=35,y=0}}
  local tp=storage.tech_priests
  tp.pairs_by_station[30]=remote_parent
  tp.pairs_by_station[31]=remote_child
  tp.station_expansion_0256[new_rec.id]=new_rec
  tp.station_expansion_by_worker_0256=tp.station_expansion_by_worker_0256 or {}
  tp.station_expansion_by_worker_0256[30]=3048
  defines.command={go_to_location=1}
  defines.distraction={none=0}
  game.create_inventory=function(n)
    assert(n==1)
    return inventory({},1)
  end
  local commands={}
  local function physical_movement(priest,command)
    assert(priest==remote_parent.priest and
      command.type==defines.command.go_to_location)
    commands[#commands+1]=command.destination
    return true
  end
  game.tick=3000
  local began,why=Evac.service_remote(remote_parent,remote_child,new_rec,
    physical_movement)
  assert(not began and why=="evacuation-counted-source-pickup"
      and remote_child.inventory.get_item_count("iron-chest")==0
      and remote_parent.inventory.get_item_count("iron-chest")==0,
    "native remote source pickup was not physically debited")
  local hold=Evac.remote_record(remote_child)
  assert(hold and hold.bag and hold.bag.valid
      and hold.bag.get_item_count("iron-chest")==1,
    "engine-owned remote evacuation bag missing real item")
  game.tick=3060
  local arrived,why=Evac.service_remote(remote_parent,remote_child,new_rec,
    function() error("native-command-exception-1048") end)
  assert(not arrived and why=="evacuation-movement-command-exception"
      and hold.movement_rejection_1048=="exception"
      and hold.movement_rejection_detail_1048:find(
        "native-command-exception-1048",1,true)
      and hold.bag.get_item_count("iron-chest")==1
      and remote_parent.inventory.get_item_count("iron-chest")==0,
    "thrown native movement must retain physical custody and diagnosis")
  arrived,why=Evac.service_remote(remote_parent,remote_child,new_rec,
    function() return false end)
  assert(not arrived and why=="evacuation-movement-command-refused"
      and hold.movement_rejection_1048=="denied"
      and hold.movement_rejection_detail_1048==nil
      and hold.bag.get_item_count("iron-chest")==1,
    "explicit command denial must not masquerade as an exception")
  arrived,why=Evac.service_remote(remote_parent,remote_child,new_rec,
    physical_movement)
  assert(hold.movement_rejection_1048==nil
      and hold.movement_rejection_detail_1048==nil,
    "successful native command must clear stale refusal diagnostics")
  assert(not arrived and why=="evacuation-carrying-to-parent"
      and #commands==1
      and remote_parent.inventory.get_item_count("iron-chest")==0
      and hold.parent_deposits_1048==nil,
    "courier created a remote receipt before physically reaching parent")
  remote_parent.priest.position={x=0,y=0}
  game.tick=3200
  arrived,why=Evac.service_remote(remote_parent,remote_child,new_rec,
    physical_movement)
  local proof=hold.parent_deposits_1048
    and hold.parent_deposits_1048["iron-chest"]
  assert(not arrived and why=="evacuation-counted-parent-deposit"
      and proof and proof.item=="iron-chest"
      and proof.quantity==1
      and proof.parent_unit==30 and proof.worker_unit==130
      and proof.tick==3200
      and proof.worker_position.x==0
      and proof.station_position.x==0
      and proof.carried_before==1 and proof.carried_after==0
      and proof.parent_item_before==0 and proof.parent_item_after==1
      and remote_parent.inventory.get_item_count("iron-chest")==1
      and hold.bag.get_item_count("iron-chest")==0
      and hold.moved["iron-chest"]==1,
    "engine transfer failed to stamp an auditable co-located inventory delta")
  remote_parent.priest.position={x=24,y=0}
  game.tick=3420
  assert((remote_parent.priest.position.x-
    remote_parent.station.position.x)^2>25
    and proof.worker_position.x==0
    and remote_parent.inventory.get_item_count("iron-chest")==1,
    "later observer must be able to distinguish true deposit from movement")
  arrived,why=Evac.service_remote(remote_parent,remote_child,new_rec,
    physical_movement)
  assert(arrived and why=="evacuation-complete"
      and hold.status=="ready-to-mine"
      and proof.tick==3200
      and hold.bag.get_item_count("iron-chest")==0,
    "save-persistent remote deposit evidence was lost on return-to-child")
end
print("[station-inventory-evacuation-1048] PASS native-stack deltas, quality, reload, ownership, reach, full-storage refusal, live 0823 mine, and remote parent-deposit receipts")
