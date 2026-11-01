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
print("[station-inventory-evacuation-1048] PASS native-stack deltas, quality, reload, ownership, reach, full-storage refusal and empty-before-mine")
