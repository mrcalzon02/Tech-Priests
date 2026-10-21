-- Standalone Lua 5.2+ regression; run from repo root:
-- lua tests/unit/emergency_facility_feed_accounting.lua
local path=(arg and arg[1]) or "tech-priests_src/scripts/core/emergency_facility_doctrine.lua"
local function inv(initial,cap)
  local v={valid=true,items=initial or {},cap=cap}
  function v.get_item_count(name) return v.items[name] or 0 end
  function v.can_insert(stack)
    local total=0
    for _,n in pairs(v.items) do total=total+n end
    return total+stack.count<=v.cap
  end
  function v.remove(stack)
    local n=math.min(v.get_item_count(stack.name),stack.count)
    v.items[stack.name]=v.get_item_count(stack.name)-n
    return n
  end
  function v.insert(stack)
    if v.block_refund then return 0 end
    local total=0
    for _,n in pairs(v.items) do total=total+n end
    local n=math.max(0,math.min(stack.count,v.cap-total))
    if v.partial then n=math.min(n,v.partial) end
    v.items[stack.name]=v.get_item_count(stack.name)+n
    return n
  end
  return v
end
local function fixture(cap)
  _G.storage={tech_priests={pairs_by_station={}}}
  _G.game={tick=100}
  _G.defines={inventory={chest=1,character_main=2,assembling_machine_input=3,
    assembling_machine_output=4,furnace_source=5,furnace_result=6,fuel=7,burnt_result=8}}
  _G.prototypes={recipe={}}
  _G.tech_priests_inventory_steward_unload=nil
  _G.TECH_PRIESTS_STATION_CATALOG_0327=nil
  _G.TECH_PRIESTS_WORK_VISUALS=nil
  _G.tech_priests_emit_overhead_status_0473=nil
  _G.tech_priests_draw_emergency_operation_status_0184=nil
  local stock=inv({["iron-ore"]=4,["coal"]=2},99)
  local input=inv({},cap)
  local fuel=inv({},0)
  local result=inv({},cap)
  local surface={}
  local furnace={valid=true,name="tech-priests-emergency-smelter",
    type="furnace",unit_number=2,position={x=2,y=0},surface=surface}
  function furnace.get_inventory(id)
    if id==defines.inventory.furnace_source then return input end
    if id==defines.inventory.furnace_result then return result end
    if id==defines.inventory.fuel then return fuel end
  end
  function surface.find_entities_filtered(_) return {furnace} end
  local station={valid=true,unit_number=1,name="tech-priests-cogitator",
    position={x=0,y=0},surface=surface}
  function station.get_inventory(id)
    if id==defines.inventory.chest then return stock end
  end
  local pair={station=station,priest={valid=true},
    emergency_craft={facility_only_0647=true,output_item="iron-plate"}}
  storage.tech_priests.pairs_by_station[1]=pair
  local mod=dofile(path)
  assert(mod.tag_built_entity(pair,furnace,"test"))
  return mod,pair,stock,input,fuel,result
end
do
  local mod,pair,stock,input=fixture(0)
  mod.service_pair(pair,"test")
  assert(stock.get_item_count("iron-ore")==4 and input.get_item_count("iron-ore")==0)
  assert(pair.emergency_facility_feed_custody_0357==nil)
end
do
  local mod,pair,stock,input=fixture(10)
  input.partial=1
  mod.service_pair(pair,"test")
  assert(stock.get_item_count("iron-ore")==3 and input.get_item_count("iron-ore")==1)
  assert(pair.emergency_facility_feed_custody_0357==nil)
end
do
  local mod,pair,stock,input=fixture(10)
  input.partial=1
  stock.block_refund=true
  local ok,why=mod.service_pair(pair,"test")
  assert(ok==false and why=="feed-custody-retained")
  local custody=pair.emergency_facility_feed_custody_0357
  assert(custody and custody.item=="iron-ore" and custody.count==3)
  assert(stock.get_item_count("iron-ore")==0 and input.get_item_count("iron-ore")==1)
  local blocked,reason=mod.service_pair(pair,"test")
  assert(blocked==false and reason=="feed-custody-blocked")
  stock.block_refund=false
  input.cap=1
  mod.service_pair(pair,"test")
  assert(pair.emergency_facility_feed_custody_0357==nil)
  assert(stock.get_item_count("iron-ore")==3 and input.get_item_count("iron-ore")==1)
end
do
  local mod,pair,stock,input=fixture(10)
  input.can_insert=function() error("simulated preflight failure") end
  mod.service_pair(pair,"test")
  assert(stock.get_item_count("iron-ore")==4 and input.get_item_count("iron-ore")==0)
end
do
  local mod,pair,stock,input,fuel=fixture(0)
  fuel.cap=2
  mod.service_pair(pair,"test")
  assert(stock.get_item_count("coal")==0 and fuel.get_item_count("coal")==2)
  assert(stock.get_item_count("iron-ore")==4 and input.get_item_count("iron-ore")==0)
end
do
  local mod,pair,stock,input,fuel=fixture(0)
  fuel.cap=4
  fuel.partial=1
  stock.block_refund=true
  local ok,why=mod.service_pair(pair,"test")
  assert(ok==false and why=="feed-custody-retained")
  local c=pair.emergency_facility_feed_custody_0357
  assert(c and c.item=="coal" and c.count==1)
  assert(stock.get_item_count("coal")==0 and fuel.get_item_count("coal")==1)
  stock.block_refund=false
  fuel.cap=1
  mod.service_pair(pair,"test")
  assert(pair.emergency_facility_feed_custody_0357==nil)
  assert(stock.get_item_count("coal")==1 and fuel.get_item_count("coal")==1)
end
-- Assembly must receive only the ingredients of its selected physical
-- recipe. Copper cable is required for circuits and was previously omitted
-- entirely by the generic emergency-assembler feed list.
do
  local mod,pair,stock=fixture(10)
  local input=inv({},10)
  stock.items["copper-cable"]=3
  stock.items["iron-plate"]=1
  local recipe={name="electronic-circuit",ingredients={
    {type="item",name="copper-cable",amount=3},
    {type="item",name="iron-plate",amount=1}
  }}
  prototypes.recipe["electronic-circuit"]={}
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=3,
    position={x=3,y=0},surface=pair.station.surface}
  assembler.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_input then return input end
  end
  assembler.set_recipe=function(name)
    assert(name=="electronic-circuit","unrelated assembly recipe selected")
    return true
  end
  assembler.get_recipe=function()return recipe end
  assert(mod.tag_built_entity(pair,assembler,"test"))
  -- The live surface scan, not only the ownership ledger, must contain the
  -- physical assembler. Otherwise this fixture cannot exercise recipe feeding.
  pair.station.surface.find_entities_filtered=function()return {assembler}end
  pair.emergency_craft={strict_recipe_0647=true,output_item="electronic-circuit"}
  pair.direct_acquisition_task_0336={
    kind="direct-mine-0336",item_name="iron-ore",
    current={kind="direct-mine-0336",item_name="iron-ore"}
  }
  local ok,why=mod.service_pair(pair,"test")
  assert(ok==true and why=="used-owned-facilities",
    "actual electronic-circuit assembly input was not serviced")
  assert(input.get_item_count("copper-cable")==3
    and input.get_item_count("iron-plate")==1,
    "copper cable and iron plates were not physically transferred")
  assert(stock.get_item_count("copper-cable")==0
    and stock.get_item_count("iron-plate")==0
    and stock.get_item_count("iron-ore")==4,
    "the assembler feeder removed unrelated items or failed stock accounting")
  assert(pair.emergency_facility_feed_custody_0357==nil,
    "successful exact ingredient transfer left orphaned custody")
end
-- Physical electronics bootstrap must rehome buffered iron before
-- a real furnace can accept copper ore; no ore or plate appears from nowhere.
do
  local mod,pair,stock,input=fixture(10)
  pair.emergency_craft={facility_only_0647=true,output_item="copper-plate"}
  input.items["iron-ore"]=3
  stock.items["copper-ore"]=4
  _G.tech_priests_safe_deposit_item=function(_,item,count)
    local credited=stock.insert({name=item,count=count})
    return credited==count,"deposited",credited
  end
  local ok,why=mod.service_pair(pair,"copper-trigger-physical-switch")
  assert(ok and why=="used-owned-facilities")
  assert(input.get_item_count("iron-ore")==0
    and input.get_item_count("copper-ore")==4
    and stock.get_item_count("iron-ore")==7
    and stock.get_item_count("copper-ore")==0
    and stock.get_item_count("copper-plate")==0,
    "furnace ore switching lost physical material or fabricated copper")
  assert(not pair.emergency_facility_feed_custody_0357)
end
-- Never interrupt a partially completed iron smelt to change products.
do
  local mod,pair,stock,input=fixture(10)
  pair.emergency_craft={facility_only_0647=true,output_item="copper-plate"}
  local furnace=mod and storage.tech_priests.emergency_facility_doctrine_0343
    and next(storage.tech_priests.emergency_facility_doctrine_0343.facilities)
  local rec=furnace and storage.tech_priests.emergency_facility_doctrine_0343.facilities[furnace]
  assert(rec and rec.entity)
  rec.entity.crafting_progress=0.5
  input.items["iron-ore"]=3
  stock.items["copper-ore"]=4
  mod.service_pair(pair,"busy-iron-before-copper")
  assert(input.get_item_count("iron-ore")==3
    and input.get_item_count("copper-ore")==0
    and stock.get_item_count("copper-ore")==4,
    "active smelting was interrupted or mis-fed")
end
-- If returning the old ore is rejected, restore to the furnace; if even
-- that fails, retain serializable custody rather than dropping physical ore.
do
  local mod,pair,stock,input=fixture(10)
  pair.emergency_craft={facility_only_0647=true,output_item="copper-plate"}
  input.items["iron-ore"]=3
  stock.items["copper-ore"]=4
  _G.tech_priests_safe_deposit_item=function()return false,"full",0 end
  mod.service_pair(pair,"blocked-return")
  assert(input.get_item_count("iron-ore")==3
    and stock.get_item_count("copper-ore")==4
    and pair.emergency_facility_feed_custody_0357==nil,
    "blocked furnace refund did not restore real iron ore")
  input.block_refund=true
  mod.service_pair(pair,"blocked-return-and-refund")
  assert(pair.emergency_facility_feed_custody_0357
    and pair.emergency_facility_feed_custody_0357.item=="iron-ore"
    and pair.emergency_facility_feed_custody_0357.count==3,
    "double-blocked furnace return silently lost physical iron ore")
  input.block_refund=false
  _G.tech_priests_safe_deposit_item=nil
  mod.service_pair(pair,"return-custody-to-storage")
  assert(pair.emergency_facility_feed_custody_0357==nil
    and stock.get_item_count("iron-ore")==7,
    "furnace iron custody failed physical restitution")
end

-- Broker-owned continuity services an already-authorized furnace even while
-- a separate coal-mining route owns priest movement. The wrapper must not
-- suppress machine input reconfiguration for the electronics trigger.
do
  local mod,pair,stock,input=fixture(10)
  pair.emergency_craft={infrastructure_first_0640=true,
    facility_only_0647=true,output_item="copper-plate",count=10}
  pair.mode="travelling-to-direct-acquisition"
  local route={kind="direct-mine-0336",output_item="coal",
    current={kind="direct-mine-0336",output_item="coal"}}
  pair.direct_acquisition_task_0336=route
  input.items["iron-ore"]=3
  stock.items["copper-ore"]=4
  _G.tech_priests_safe_deposit_item=function(_,item,count)
    local credited=stock.insert({name=item,count=count})
    return credited==count,"deposited",credited
  end
  local acted=mod.service_owned_miners_all("broker-periodic")
  assert(acted>=1
    and input.get_item_count("iron-ore")==0
    and input.get_item_count("copper-ore")==4
    and stock.get_item_count("iron-ore")==7
    and stock.get_item_count("copper-ore")==0,
    "broker suppressed physical copper furnace service behind coal travel")
  assert(pair.mode=="travelling-to-direct-acquisition"
    and pair.direct_acquisition_task_0336==route,
    "periodic machine upkeep stole active priest mining/movement authority")
  _G.tech_priests_safe_deposit_item=nil
end

-- Completed iron in a real furnace result blocks automatic copper recipe
-- selection even when copper ore reaches the source. Clear both inventories
-- transactionally before feeding copper; do not grant any copper output.
do
  local mod,pair,stock,input,fuel,result=fixture(10)
  pair.emergency_craft={facility_only_0647=true,output_item="copper-plate"}
  result.items["iron-plate"]=5
  input.items["iron-ore"]=2
  stock.items["copper-ore"]=4
  _G.tech_priests_safe_deposit_item=function(_,item,count)
    local inserted=stock.insert({name=item,count=count})
    return inserted==count,"deposited",inserted
  end
  local ok,why=mod.service_pair(pair,"switch-occupied-iron-output")
  assert(ok and why=="used-owned-facilities"
    and result.get_item_count("iron-plate")==0
    and stock.get_item_count("iron-plate")==5
    and input.get_item_count("iron-ore")==0
    and stock.get_item_count("iron-ore")==6
    and input.get_item_count("copper-ore")==4
    and stock.get_item_count("copper-plate")==0,
    "mixed furnace output/input prevented conservation-safe copper changeover")
  _G.tech_priests_safe_deposit_item=nil
end
-- If plate return is refused, leave real furnace output untouched and never
-- transfer copper ore; if rollback is also impossible, retain saveable custody.
do
  local mod,pair,stock,input,fuel,result=fixture(10)
  pair.emergency_craft={facility_only_0647=true,output_item="copper-plate"}
  result.items["iron-plate"]=3
  stock.items["copper-ore"]=4
  _G.tech_priests_safe_deposit_item=function()return false,"blocked",0 end
  mod.service_pair(pair,"blocked-plate-return")
  assert(result.get_item_count("iron-plate")==3
    and input.get_item_count("copper-ore")==0
    and stock.get_item_count("copper-ore")==4
    and not pair.emergency_facility_feed_custody_0357,
    "blocked output return lost iron plate or moved copper")
  result.block_refund=true
  mod.service_pair(pair,"blocked-plate-rollback")
  assert(pair.emergency_facility_feed_custody_0357
    and pair.emergency_facility_feed_custody_0357.item=="iron-plate"
    and pair.emergency_facility_feed_custody_0357.count==3,
    "double-blocked output return did not retain exact iron plate custody")
  result.block_refund=false
  _G.tech_priests_safe_deposit_item=nil
  mod.service_pair(pair,"resolve-plate-custody")
  assert(pair.emergency_facility_feed_custody_0357==nil
    and stock.get_item_count("iron-plate")==3,
    "plate return custody failed to restore physical stock")
end

print("PASS emergency facility feed accounting")
