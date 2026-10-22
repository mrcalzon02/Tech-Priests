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

-- With one physical coal remaining and both machines requesting fuel,
-- an authorized copper smelt wins before routine miner replenishment.
do
  local mod,pair,stock,input,fuel=fixture(10)
  fuel.cap=10
  stock.items["coal"]=1
  stock.items["copper-ore"]=4
  pair.emergency_craft={infrastructure_first_0640=true,
    facility_only_0647=true,output_item="copper-plate",count=10}
  local minefuel=inv({},10)
  local miner={valid=true,name="tech-priests-emergency-miner",
    type="assembling-machine",unit_number=37,position={x=3,y=2},
    surface=pair.station.surface,force=pair.station.force}
  miner.get_inventory=function(id)
    if id==defines.inventory.fuel then return minefuel end
  end
  miner.get_recipe=function()
    return "tech-priests-emergency-mine-iron-ore"
  end
  assert(mod.tag_built_entity(pair,miner,"real-fuel-priority"))
  local records=storage.tech_priests.emergency_facility_doctrine_0343.facilities
  local furnace
  for _,entry in pairs(records) do
    if entry.role=="smelter" then furnace=entry.entity;break end
  end
  assert(furnace)
  pair.station.surface.find_entities_filtered=function()
    return {furnace,miner}
  end
  local accepted,reason=mod.service_pair(pair,"copper-furnace-fuel-before-miner")
  assert(accepted and reason=="used-owned-facilities"
    and fuel.get_item_count("coal")==1
    and minefuel.get_item_count("coal")==0
    and stock.get_item_count("coal")==0
    and input.get_item_count("copper-ore")==4,
    "miner consumed the only real coal before authorized copper smelting")
  assert(not pair.emergency_facility_feed_custody_0357
    and pair.emergency_craft.output_item=="copper-plate",
    "fuel priority destroyed the active physical production transaction")
end

-- Failure diagnostics must expose the real recipe-selection blocker
-- without force-enabling technology, replacing a recipe or fabricating stock.
do
  local mod,pair,stock,input=fixture(10)
  prototypes.recipe["copper-cable"]={}
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=88,
    position={x=3,y=0},surface=pair.station.surface}
  local attempts=0
  assembler.get_recipe=function()return nil end
  assembler.set_recipe=function(_)
    attempts=attempts+1
    return false
  end
  assembler.get_inventory=function()return nil end
  assert(mod.tag_built_entity(pair,assembler,"recipe-denial-regression"))
  local furnace
  for _,entry in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if entry.role=="smelter" then furnace=entry.entity;break end
  end
  pair.station.surface.find_entities_filtered=function()return {furnace,assembler}end
  pair.emergency_craft={strict_recipe_0647=true,output_item="copper-cable",
    infrastructure_first_0640=true}
  mod.service_pair(pair,"strict-engine-reject")
  local state=pair.emergency_facility_recipe_diagnostic_0357
  assert(attempts>0 and state and state.recipe=="copper-cable"
    and state.phase=="engine-rejected"
    and state.reason=="set_recipe returned false",
    "failed physical recipe selection was not captured with engine reason")
  -- A setter that returns success but retains no recipe is NOT successful
  -- production. The broker must expose the mismatch and keep trying later.
  assembler.set_recipe=function(_)
    attempts=attempts+1
    return true
  end
  mod.service_pair(pair,"engine-silent-recipe-loss")
  state=pair.emergency_facility_recipe_diagnostic_0357
  assert(attempts==2 and state and state.recipe=="copper-cable"
    and state.phase=="engine-unconfirmed"
    and state.reason:find("selected=nil",1,true),
    "accepted set_recipe with nil engine recipe was falsely credited")
  _G.tech_priests_0576_claim_machine_for_recipe=function()return false,"other-owner"end
  mod.service_pair(pair,"recipe-claim-rejected")
  state=pair.emergency_facility_recipe_diagnostic_0357
  assert(state and state.phase=="claim-rejected"
    and state.reason=="other-owner" and attempts==2,
    "failed ownership claim was bypassed or not observed")
  _G.tech_priests_0576_claim_machine_for_recipe=nil
  assert(stock.get_item_count("copper-cable")==0,
    "selector diagnostics fabricated copper cable")
end

-- Only a real smelter may accept copper/iron/brick recipes. An unrelated
-- burner assembler must neither receive that recipe nor consume furnace fuel.
for _,material in ipairs({"copper-plate","iron-plate","stone-brick"}) do
  local mod,pair,stock,input,fuel=fixture(10)
  -- The generic blocked-fuel fixture starts with capacity zero; this
  -- scenario must permit the real furnace to accept its physical coal.
  fuel.cap=8
  prototypes.recipe[material]={category="smelting"}
  local assembler_fuel=inv({},8)
  local attempts=0
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=80,
    position={x=3,y=0},surface=pair.station.surface}
  assembler.get_inventory=function(id)
    if id==defines.inventory.fuel then return assembler_fuel end
  end
  assembler.get_recipe=function()return nil end
  assembler.set_recipe=function(_)attempts=attempts+1;return true end
  assert(mod.tag_built_entity(pair,assembler,"smelting-selector-guard"))
  local furnace
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.role=="smelter" then furnace=rec.entity;break end
  end
  pair.station.surface.find_entities_filtered=function()return {furnace,assembler}end
  stock.items.coal=1
  stock.items["copper-ore"]=4
  pair.emergency_craft={facility_only_0647=true,output_item=material,
    infrastructure_first_0640=true}
  mod.service_pair(pair,"smelting-selector")
  assert(attempts==0 and assembler_fuel.get_item_count("coal")==0,
    "smelting recipe or fuel was wrongly assigned to the assembler")
  if material=="copper-plate" then
    assert(fuel.get_item_count("coal")==1
      and input.get_item_count("copper-ore")==4,
      "real copper furnace was robbed of fuel by invalid assembly work")
  end
end

-- A locally owned workshop must not strand real copper cable when the
-- active production objective has advanced to a different item. Exact
-- physical return works even while a priest carries unrelated mining cargo,
-- without changing any movement state or another Cogitator's inventory.
do
  local mod,pair,stock,input=fixture(10)
  local output=inv({["copper-cable"]=4},20)
  local assembler={valid=true,name="tech-priests-emergency-assembler",
    type="assembling-machine",unit_number=75,position={x=4,y=0},
    surface=pair.station.surface,force=pair.station.force}
  assembler.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_output then return output end
  end
  local furnace
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.role=="smelter" then furnace=rec.entity end
  end
  assert(mod.tag_built_entity(pair,assembler,"electronics-local-output"))
  pair.station.surface.find_entities_filtered=function()return {furnace,assembler}end
  pair.mode="direct-acquisition-returning-with-custody"
  local held={item="coal",count=2}
  pair.direct_acquisition_custody_0513=held
  pair.emergency_craft={infrastructure_first_0640=true,
    facility_only_0647=true,output_item="copper-plate"}
  _G.tech_priests_safe_deposit_item=function(_,item,count)
    local deposited=stock.insert({name=item,count=count})
    return deposited==count,"deposited",deposited
  end
  local acted=mod.service_owned_miners_all("broker-periodic")
  assert(acted>=1 and output.get_item_count("copper-cable")==0
    and stock.get_item_count("copper-cable")==4
    and pair.direct_acquisition_custody_0513==held
    and pair.mode=="direct-acquisition-returning-with-custody",
    "owned workshop failed to settle real cable or stole mining custody")
  assert(not pair.emergency_facility_feed_custody_0357,
    "successful local cable return retained invented transfer custody")
  _G.tech_priests_safe_deposit_item=nil
end

-- A blocked storage return must never erase completed Electronics output.
do
  local mod,pair,stock,input=fixture(10)
  local output=inv({["copper-cable"]=4},20)
  local assembler={valid=true,name="tech-priests-emergency-assembler",
    type="assembling-machine",unit_number=76,position={x=4,y=0},
    surface=pair.station.surface,force=pair.station.force}
  assembler.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_output then return output end
  end
  local furnace
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.role=="smelter" then furnace=rec.entity end
  end
  assert(mod.tag_built_entity(pair,assembler,"blocked-electronics-output"))
  pair.station.surface.find_entities_filtered=function()return {furnace,assembler}end
  _G.tech_priests_safe_deposit_item=function()return false,"blocked",0 end
  mod.service_owned_miners_all("broker-periodic")
  assert(output.get_item_count("copper-cable")==4
    and stock.get_item_count("copper-cable")==0
    and pair.emergency_facility_feed_custody_0357==nil,
    "rejected electronics deposit lost physical cable output")
  _G.tech_priests_safe_deposit_item=nil
end

-- Force prototypes in a plain-Lua fixture must be attached consistently
-- to both the Cogitator and its physical machine. The owned scan rejects
-- differently forced entities, as the real engine correctly does.
local function fixture_electronics_force(pair,researched)
  local force={technologies={electronics={researched=researched}}}
  pair.station.force=force
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.entity and rec.entity.valid then rec.entity.force=force end
  end
end

-- Electronics completion: a running copper furnace must eventually
-- switch to real iron smelting for the first circuit. Both copper inventories
-- are refunded transactionally; the new iron stock is fed, not fabricated.
do
  local mod,pair,stock,input,fuel,result=fixture(10)
  fixture_electronics_force(pair,true)
  pair.infrastructure_recipe_request_0647={
    item="electronic-circuit",missing="iron-plate"}
  pair.emergency_craft={facility_only_0647=true,output_item="iron-plate",
    infrastructure_first_0640=true}
  input.items["copper-ore"]=2
  result.items["copper-plate"]=3
  stock.items["iron-ore"]=4
  _G.tech_priests_safe_deposit_item=function(_,item,count)
    local n=stock.insert({name=item,count=count})
    return n==count,"deposited",n
  end
  local ok,why=mod.service_pair(pair,"copper-furnace-to-iron-circuit")
  assert(ok and why=="used-owned-facilities"
      and input.get_item_count("copper-ore")==0
      and result.get_item_count("copper-plate")==0
      and stock.get_item_count("copper-ore")==2
      and stock.get_item_count("copper-plate")==3
      and input.get_item_count("iron-ore")==4
      and stock.get_item_count("iron-ore")==0
      and stock.get_item_count("iron-plate")==0
      and not pair.emergency_facility_feed_custody_0357,
    "copper-to-iron changeover lost real copper or fabricated iron plates")
  _G.tech_priests_safe_deposit_item=nil
end

-- Never interrupt actual copper smelting to obtain the next iron plate.
do
  local mod,pair,stock,input,fuel,result=fixture(10)
  fixture_electronics_force(pair,true)
  pair.infrastructure_recipe_request_0647={
    item="electronic-circuit",missing="iron-plate"}
  pair.emergency_craft={facility_only_0647=true,output_item="iron-plate"}
  local furnace
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.role=="smelter" then furnace=rec.entity end
  end
  assert(furnace)
  furnace.crafting_progress=0.5
  input.items["copper-ore"]=2
  result.items["copper-plate"]=1
  _G.tech_priests_safe_deposit_item=function(_,item,count)
    local n=stock.insert({name=item,count=count})
    return n==count,"deposited",n
  end
  mod.service_pair(pair,"active-copper-must-complete")
  assert(input.get_item_count("copper-ore")==2
      and input.get_item_count("iron-ore")==0
      and result.get_item_count("copper-plate")==1
      and stock.get_item_count("iron-ore")==4,
    "reciprocal switch interrupted a partially completed copper smelt")
  _G.tech_priests_safe_deposit_item=nil
end

-- A full/blocked station must retain completed copper until exact deposit
-- succeeds. Do not erase copper or insert incompatible iron into the furnace.
do
  local mod,pair,stock,input,fuel,result=fixture(10)
  fixture_electronics_force(pair,true)
  pair.infrastructure_recipe_request_0647={
    item="electronic-circuit",missing="iron-plate"}
  pair.emergency_craft={facility_only_0647=true,output_item="iron-plate"}
  input.items["copper-ore"]=2
  result.items["copper-plate"]=3
  _G.tech_priests_safe_deposit_item=function()return false,"full",0 end
  mod.service_pair(pair,"copper-refund-blocked")
  assert(input.get_item_count("copper-ore")==2
      and input.get_item_count("iron-ore")==0
      and result.get_item_count("copper-plate")==3
      and stock.get_item_count("iron-ore")==4
      and not pair.emergency_facility_feed_custody_0357,
    "failed copper output return erased products or mixed furnace inputs")
  _G.tech_priests_safe_deposit_item=nil
end

-- The unresearched ten-copper-plate trigger must not be disrupted by
-- concurrent iron/gear requests, even if a circuit prerequisite is queued.
do
  local mod,pair,stock,input,fuel,result=fixture(10)
  fixture_electronics_force(pair,false)
  pair.infrastructure_recipe_request_0647={
    item="electronic-circuit",missing="iron-plate"}
  pair.emergency_craft={facility_only_0647=true,output_item="iron-plate"}
  input.items["copper-ore"]=2
  result.items["copper-plate"]=3
  _G.tech_priests_safe_deposit_item=function(_,item,count)
    local n=stock.insert({name=item,count=count})
    return n==count,"deposited",n
  end
  mod.service_pair(pair,"protect-copper-electronics-trigger")
  assert(input.get_item_count("copper-ore")==2
      and result.get_item_count("copper-plate")==3
      and stock.get_item_count("copper-plate")==0
      and stock.get_item_count("copper-ore")==0,
    "unresearched copper trigger was prematurely switched back to iron")
  _G.tech_priests_safe_deposit_item=nil
end

-- The governor may reserve circuit iron directly before it creates a
-- recursive parent request. Its explicit local gate is equally authoritative
-- for safely switching an otherwise copper-filled furnace after Electronics.
do
  local mod,pair,stock,input,fuel,result=fixture(10)
  fixture_electronics_force(pair,true)
  pair.local_infrastructure_gate_0640={
    item="iron-plate",why="first-electronics-physical-iron-smelting"}
  pair.emergency_craft={infrastructure_first_0640=true,
    facility_only_0647=true,output_item="iron-plate"}
  input.items["copper-ore"]=2
  result.items["copper-plate"]=3
  _G.tech_priests_safe_deposit_item=function(_,item,count)
    local n=stock.insert({name=item,count=count})
    return n==count,"deposited",n
  end
  local ok,reason=mod.service_pair(pair,"first-circuit-local-iron-gate")
  assert(ok and reason=="used-owned-facilities"
      and stock.get_item_count("copper-ore")==2
      and stock.get_item_count("copper-plate")==3
      and input.get_item_count("copper-ore")==0
      and result.get_item_count("copper-plate")==0
      and input.get_item_count("iron-ore")==4
      and stock.get_item_count("iron-ore")==0,
    "local post-Electronics iron gate could not evacuate copper furnace")
  _G.tech_priests_safe_deposit_item=nil
end

-- A genuine owned laboratory output is a constructed item prerequisite,
-- not science or a virtual completed laboratory. Return it to the same
-- station's physical storage while respecting independent mining custody.
do
  local mod,pair,stock,input=fixture(10)
  local item="tech-priests-emergency-laboratorium"
  local output=inv({[item]=1},20)
  local assembler={valid=true,name="tech-priests-emergency-assembler",
    type="assembling-machine",unit_number=275,position={x=4,y=0},
    surface=pair.station.surface,force=pair.station.force}
  assembler.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_output then return output end
  end
  local furnace
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.role=="smelter" then furnace=rec.entity end
  end
  assert(mod.tag_built_entity(pair,assembler,"physical-laboratory-output"))
  pair.station.surface.find_entities_filtered=function()return {furnace,assembler}end
  pair.mode="direct-acquisition-returning-with-custody"
  local held={item="coal",count=2}
  pair.direct_acquisition_custody_0513=held
  _G.tech_priests_safe_deposit_item=function(_,name,count)
    local accepted=stock.insert({name=name,count=count})
    return accepted==count,"deposited",accepted
  end
  local acted=mod.service_owned_miners_all("return-owned-real-laboratory")
  local stats=storage.tech_priests.emergency_facility_doctrine_0343.stats
  assert(acted>=1 and output.get_item_count(item)==0
      and stock.get_item_count(item)==1
      and stats["local-laboratorium-output-settled-0357"]==1
      and pair.direct_acquisition_custody_0513==held
      and pair.mode=="direct-acquisition-returning-with-custody"
      and not pair.emergency_facility_feed_custody_0357,
    "physical owned laboratory output was stranded or stole mining custody")
  -- If storage later rejects a second real laboratory, its machine output
  -- must remain untouched. No synthetic item or fake rollback success.
  output.items[item]=1
  _G.tech_priests_safe_deposit_item=function()return false,"storage-full",0 end
  game.tick=game.tick+130
  mod.service_owned_miners_all("blocked-laboratory-return")
  assert(output.get_item_count(item)==1
      and stock.get_item_count(item)==1
      and stats["local-laboratorium-output-settled-0357"]==1
      and not pair.emergency_facility_feed_custody_0357,
    "blocked real laboratory restitution lost an item or fabricated custody")
  _G.tech_priests_safe_deposit_item=nil
end

-- Iron gears and transport belts are themselves engine-manufactured
-- vanilla laboratory prerequisites; collection must conserve both whenever
-- the owned workshop advances to another recipe.
do
  local mod,pair,stock,input=fixture(10)
  local output=inv({["iron-gear-wheel"]=3,["transport-belt"]=4},20)
  local assembler={valid=true,name="tech-priests-emergency-assembler",
    type="assembling-machine",unit_number=373,position={x=4,y=0},
    surface=pair.station.surface,force=pair.station.force}
  assembler.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_output then return output end
  end
  local furnace
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.role=="smelter" then furnace=rec.entity end
  end
  assert(mod.tag_built_entity(pair,assembler,"normal-laboratory-components"))
  pair.station.surface.find_entities_filtered=function()return {furnace,assembler}end
  _G.tech_priests_safe_deposit_item=function(_,item,count)
    local inserted=stock.insert({name=item,count=count})
    return inserted==count,"deposited",inserted
  end
  local acted=mod.service_owned_miners_all("lab-parts-physically-returned")
  local stats=storage.tech_priests.emergency_facility_doctrine_0343.stats
  assert(acted>0 and output.get_item_count("iron-gear-wheel")==0
      and output.get_item_count("transport-belt")==0
      and stock.get_item_count("iron-gear-wheel")==3
      and stock.get_item_count("transport-belt")==4
      and stats["local-lab-parts-output-settled-0357"]==7,
    "real normal laboratory intermediates were lost or left unreachable")
  _G.tech_priests_safe_deposit_item=nil
end

-- Factorio's recipe that unlocks red science produces the literal
-- vanilla "lab" item, not the custom emergency-laboratorium. Once crafted,
-- it must move into physical storage without duplicating the item.
do
  local mod,pair,stock,input=fixture(10)
  local item="lab"
  local output=inv({[item]=1},20)
  local assembler={valid=true,name="tech-priests-emergency-assembler",
    type="assembling-machine",unit_number=374,position={x=4,y=0},
    surface=pair.station.surface,force=pair.station.force}
  assembler.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_output then return output end
  end
  local furnace
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.role=="smelter" then furnace=rec.entity end
  end
  assert(mod.tag_built_entity(pair,assembler,"engine-built-normal-lab"))
  pair.station.surface.find_entities_filtered=function()return {furnace,assembler}end
  _G.tech_priests_safe_deposit_item=function(_,name,count)
    local deposited=stock.insert({name=name,count=count})
    return deposited==count,"deposited",deposited
  end
  local acted=mod.service_owned_miners_all("real-vanilla-lab-output")
  assert(acted>0 and output.get_item_count(item)==0
      and stock.get_item_count(item)==1
      and not pair.emergency_facility_feed_custody_0357,
    "normal laboratory crafting output was stranded or fabricated")
  _G.tech_priests_safe_deposit_item=nil
end

-- The existing owned-facility continuity loop moves genuine red
-- science from workshop output into the station and then into a real lab.
-- Neither step may spoof a production statistic or a research flag.
do
  local mod,pair,stock,input=fixture(10)
  defines.inventory.lab_input=9
  local science="automation-science-pack"
  local output=inv({[science]=2},20)
  local lab_input=inv({},10)
  local lab_fuel=inv({},10)
  local assembler={valid=true,name="tech-priests-emergency-assembler",
    type="assembling-machine",unit_number=375,position={x=4,y=0},
    surface=pair.station.surface,force=pair.station.force}
  assembler.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_output then return output end
  end
  local lab={valid=true,name="tech-priests-emergency-laboratorium",
    type="lab",unit_number=376,position={x=5,y=0},
    surface=pair.station.surface,force=pair.station.force}
  lab.get_inventory=function(id)
    if id==defines.inventory.lab_input then return lab_input end
    if id==defines.inventory.fuel then return lab_fuel end
  end
  local furnace
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.role=="smelter" then furnace=rec.entity end
  end
  assert(mod.tag_built_entity(pair,assembler,"physical-red-science-output"))
  assert(mod.tag_built_entity(pair,lab,"real-science-lab"))
  pair.station.surface.find_entities_filtered=function()return {furnace,assembler,lab}end
  _G.tech_priests_safe_deposit_item=function(_,item,count)
    local n=stock.insert({name=item,count=count})
    return n==count,"deposited",n
  end
  local first=mod.service_owned_miners_all("science-completion-and-lab-feed")
  local stats=storage.tech_priests.emergency_facility_doctrine_0343.stats
  assert(first>0 and output.get_item_count(science)==0
      and stock.get_item_count(science)==0
      and lab_input.get_item_count(science)==2
      and stats["local-science-output-settled-0357"]==2
      and stats["physical-science-fed:automation-science-pack"]==2
      and stats["physical-laboratory-fuel-fed"]==2
      and stock.get_item_count("coal")==0
      and lab_fuel.get_item_count("coal")==2
      and not pair.emergency_facility_feed_custody_0357,
    "real science packs were not conserved through local laboratory feed")
  -- A blocked lab insert cannot remove a science pack from storage.
  lab_input.items[science]=0
  lab_input.cap=0
  stock.items[science]=1
  game.tick=game.tick+130
  mod.service_owned_miners_all("blocked-real-science-lab")
  assert(stock.get_item_count(science)==1
      and lab_input.get_item_count(science)==0
      and not pair.emergency_facility_feed_custody_0357,
    "full laboratory consumed science without a physical insert")
  _G.tech_priests_safe_deposit_item=nil
end

-- Both vanilla first-tier science packs are real factory products.
-- The collector and owned lab feeder must conserve the red/green mixture.
do
  local mod,pair,stock=fixture(10)
  defines.inventory.lab_input=9
  local red,green="automation-science-pack","logistic-science-pack"
  local output=inv({[red]=1,[green]=1},20)
  local lab_input=inv({},10)
  local assembler={valid=true,name="tech-priests-emergency-assembler",
    type="assembling-machine",unit_number=405,position={x=4,y=0},
    surface=pair.station.surface,force=pair.station.force}
  assembler.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_output then return output end
  end
  local lab={valid=true,name="tech-priests-emergency-laboratorium",
    type="lab",unit_number=406,position={x=5,y=0},
    surface=pair.station.surface,force=pair.station.force}
  lab.get_inventory=function(id)
    if id==defines.inventory.lab_input then return lab_input end
  end
  local furnace
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.role=="smelter" then furnace=rec.entity end
  end
  assert(mod.tag_built_entity(pair,assembler,"actual-red-green-output"))
  assert(mod.tag_built_entity(pair,lab,"real-lab-two-pack-feed"))
  pair.station.surface.find_entities_filtered=function()return {furnace,assembler,lab}end
  _G.tech_priests_safe_deposit_item=function(_,item,count)
    local added=stock.insert({name=item,count=count})
    return added==count,"deposited",added
  end
  local acted=mod.service_owned_miners_all("return-and-feed-two-real-science-packs")
  local stats=storage.tech_priests.emergency_facility_doctrine_0343.stats
  assert(acted>0 and output.get_item_count(red)==0
      and output.get_item_count(green)==0
      and stock.get_item_count(red)==0
      and stock.get_item_count(green)==0
      and lab_input.get_item_count(red)==1
      and lab_input.get_item_count(green)==1
      and stats["local-science-output-settled-0357"]==2
      and stats["physical-science-fed:automation-science-pack"]==1
      and stats["physical-science-fed:logistic-science-pack"]==1
      and not pair.emergency_facility_feed_custody_0357,
    "real red/green packs were not conserved in the owned laboratory")
  _G.tech_priests_safe_deposit_item=nil
end


-- A strict copper-cable task must not stop its separate furnace. The
-- furnace receives physical copper ore and real burner coal while the
-- assembler waits for engine-smelted copper plates; no ingredient or science
-- output is manufactured directly by the maintenance service.
do
  local mod,pair,stock,input,fuel,result=fixture(10)
  fuel.cap=4
  stock.items["copper-ore"]=4
  prototypes.recipe["copper-cable"]={}
  local assembly_input=inv({},10)
  local selected
  local assembler={valid=true,name="tech-priests-emergency-assembler",
    type="assembling-machine",unit_number=451,position={x=4,y=0},
    surface=pair.station.surface,force=pair.station.force}
  assembler.set_recipe=function(item)
    selected=item
    return item=="copper-cable"
  end
  assembler.get_recipe=function()
    return selected and {name=selected,ingredients={
      {name="copper-plate",type="item",amount=1}}} or nil
  end
  assembler.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_input then return assembly_input end
  end
  local furnace
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.role=="smelter" then furnace=rec.entity end
  end
  assert(mod.tag_built_entity(pair,assembler,"physical-cable-smelting-dependency"))
  pair.station.surface.find_entities_filtered=function()return {furnace,assembler}end
  pair.emergency_craft={strict_recipe_0647=true,facility_only_0647=true,
    infrastructure_first_0640=true,output_item="copper-cable"}
  local done,why=mod.service_pair(pair,"run-copper-furnace-with-cable-assembler")
  assert(done and why=="used-owned-facilities" and selected=="copper-cable"
      and input.get_item_count("copper-ore")==4
      and stock.get_item_count("copper-ore")==0
      and fuel.get_item_count("coal")==2
      and stock.get_item_count("coal")==0
      and stock.get_item_count("copper-plate")==0
      and result.get_item_count("copper-plate")==0
      and assembly_input.get_item_count("copper-plate")==0
      and not pair.emergency_facility_feed_custody_0357,
    "cable crafting stalled physical copper smelting or forged an ingredient")
  local observed=pair.emergency_facility_input_diagnostic_0357
  assert(observed and observed.recipe=="copper-cable"
      and observed.output=="copper-cable"
      and observed.requested==1 and observed.moved==0
      and observed.phase=="engine-input-feed",
    "cable input feeder failed to report its genuine missing plate")
end

-- An empty laboratory cannot research or consume science. Preserve its
-- station's scarce coal until an actual red pack reaches the lab input;
-- then use the same transactional fuel and science feed as before.
do
  local mod,pair,stock=fixture(10)
  defines.inventory.lab_input=9
  local lab_input=inv({},10)
  local lab_fuel=inv({},10)
  local lab={valid=true,name="tech-priests-emergency-laboratorium",
    type="lab",unit_number=452,position={x=5,y=0},
    surface=pair.station.surface,force=pair.station.force}
  lab.get_inventory=function(id)
    if id==defines.inventory.lab_input then return lab_input end
    if id==defines.inventory.fuel then return lab_fuel end
  end
  local furnace
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.role=="smelter" then furnace=rec.entity end
  end
  assert(mod.tag_built_entity(pair,lab,"idle-lab-preserve-fuel"))
  pair.station.surface.find_entities_filtered=function()return {furnace,lab}end
  mod.service_owned_miners_all("empty-lab-preserve-coal")
  assert(stock.get_item_count("coal")==2 and lab_fuel.get_item_count("coal")==0,
    "unfed laboratory took scarce physical fuel before science existed")
  stock.items["automation-science-pack"]=1
  game.tick=game.tick+130
  mod.service_owned_miners_all("genuine-science-allows-fuel")
  assert(stock.get_item_count("automation-science-pack")==0
      and lab_input.get_item_count("automation-science-pack")==1
      and stock.get_item_count("coal")==0
      and lab_fuel.get_item_count("coal")==2
      and not pair.emergency_facility_feed_custody_0357,
    "science-ready laboratory failed to accept real pack and burner coal")
end


-- A recipe may be known yet impossible on the particular engine machine.
-- Force-locks, custom categories and fluid inputs must be checked before
-- machine selection and inventory withdrawal; a capability mismatch is a
-- planning failure, not a successful physical manufacturing transaction.
do
  local mod,pair,stock=fixture(10)
  local input=inv({},20)
  local selected,attempts=nil,0
  local assembler={valid=true,name="tech-priests-emergency-assembler",
    type="assembling-machine",unit_number=601,position={x=4,y=0},
    force={recipes={}},surface=pair.station.surface,
    prototype={crafting_categories={crafting=true,electronics=true}}}
  assembler.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_input then return input end
  end
  assembler.get_recipe=function()
    return selected and {name=selected,ingredients={
      {type="item",name="iron-gear-wheel",amount=1},
      {type="item",name="iron-plate",amount=1}}} or nil
  end
  assembler.set_recipe=function(recipe)
    attempts=attempts+1
    local proto=prototypes.recipe[recipe]
    local categories=proto.categories or {proto.category or "crafting"}
    for _,category in ipairs(categories) do
      if assembler.prototype.crafting_categories[category] then
        selected=recipe
        return true
      end
    end
    return false -- The mock engine rejects an unsupported physical recipe.
  end
  local furnace
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.role=="smelter" then furnace=rec.entity end
  end
  assert(mod.tag_built_entity(pair,assembler,"recipe-category-preflight"))
  pair.station.surface.find_entities_filtered=function()return {furnace,assembler}end
  pair.station.force={recipes={
    ["transport-belt"]={enabled=true},
    ["electronic-circuit"]={enabled=false},
    ["fluid-test"]={enabled=true},
  }}
  assembler.force=pair.station.force
  prototypes.recipe["transport-belt"]={category="pressing",
    ingredients={{type="item",name="iron-gear-wheel",amount=1}}}
  prototypes.recipe["electronic-circuit"]={category="electronics"}
  prototypes.recipe["fluid-test"]={category="crafting",
    ingredients={{type="fluid",name="water",amount=10}}}
  stock.items["iron-gear-wheel"]=2
  stock.items["iron-plate"]=2
  pair.emergency_craft={facility_only_0647=true,strict_recipe_0647=true,
    output_item="transport-belt"}
  local can,why=mod.machine_recipe_fit(pair,assembler,"transport-belt")
  assert(can==false and why=="incompatible-crafting-category:pressing",
    "pressing belt falsely classified as supported by crafting-only workshop")
  mod.service_pair(pair,"incompatible-belt-workshop")
  local reason=pair.emergency_facility_recipe_blocker_0357
  assert(reason and reason.reason=="incompatible-crafting-category:pressing"
      and attempts==1 and input.get_item_count("iron-gear-wheel")==0
      and stock.get_item_count("iron-gear-wheel")==2,
    "incompatible belt recipe selected, consumed stock or hid its blocker")
  local locked,locked_why=mod.machine_recipe_fit(pair,assembler,"electronic-circuit")
  assert(not locked and locked_why=="recipe-not-unlocked-for-force",
    "locked electronics recipe incorrectly marked executable")
  local fluid,fluid_why=mod.machine_recipe_fit(pair,assembler,"fluid-test")
  assert(not fluid and fluid_why=="missing-fluid-boxes",
    "fluid-bearing recipe incorrectly assigned to dry workshop")
  assembler.prototype.crafting_categories.pressing=true
  local valid,detail=mod.machine_recipe_fit(pair,assembler,"transport-belt")
  assert(valid and detail==nil,"physical press still rejected valid belt recipe")
  mod.service_pair(pair,"physical-press-works")
  assert(attempts==2 and selected=="transport-belt"
      and input.get_item_count("iron-gear-wheel")==1
      and stock.get_item_count("iron-gear-wheel")==1
      and not pair.emergency_facility_feed_custody_0357,
    "category-compatible press failed to select and feed real belt ingredients")
  assert(input.get_item_count("transport-belt")==0
      and stock.get_item_count("transport-belt")==0,
    "recipe-aware feed fabricated finished belt rather than waiting for engine")
end

-- A metadata-only category mismatch cannot veto actual Factorio acceptance.
-- The real engine's selected recipe is authoritative; input feeding still
-- requires a physical station withdrawal and must not invent any output.
do
  local mod,pair,stock=fixture(10)
  local input=inv({},12)
  local selected,attempts=nil,0
  local recipe={name="copper-cable",ingredients={
    {type="item",name="copper-plate",amount=1}}}
  prototypes.recipe["copper-cable"]={
    categories={"electronics"},ingredients=recipe.ingredients}
  pair.station.force={recipes={["copper-cable"]={enabled=true}}}
  local assembler={valid=true,type="assembling-machine",
    name="tech-priests-emergency-assembler",unit_number=612,
    force=pair.station.force,position={x=3,y=0},surface=pair.station.surface,
    prototype={crafting_categories={crafting=true}}}
  assembler.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_input then return input end
  end
  assembler.get_recipe=function()return selected and recipe or nil end
  assembler.set_recipe=function(name)
    attempts=attempts+1
    assert(name=="copper-cable")
    selected=name -- Mock of a successful real engine selection.
    return true
  end
  local furnace
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities)do
    if rec.role=="smelter" then furnace=rec.entity end
  end
  assert(mod.tag_built_entity(pair,assembler,"false-negative-engine-selection"))
  pair.station.surface.find_entities_filtered=function()return {furnace,assembler}end
  stock.items["copper-plate"]=3
  pair.emergency_craft={strict_recipe_0647=true,output_item="copper-cable"}
  local fit,reason=mod.machine_recipe_fit(pair,assembler,"copper-cable")
  assert(not fit and reason=="incompatible-crafting-category:electronics",
    "fixture must reproduce the false-negative static category prediction")
  local worked=mod.service_pair(pair,"engine-overrides-stale-category-metadata")
  local diag=pair.emergency_facility_assembler_recipe_diagnostic_0357
  assert(worked and attempts==1 and selected=="copper-cable"
      and diag and diag.phase=="engine-confirmed"
      and diag.reason:find("engine overrode preflight:",1,true)
      and input.get_item_count("copper-plate")==1
      and stock.get_item_count("copper-plate")==2
      and input.get_item_count("copper-cable")==0
      and stock.get_item_count("copper-cable")==0
      and pair.emergency_facility_feed_custody_0357==nil,
    "engine-confirmed recipe was rejected, misfed or produced fabricated cable")
end


-- Maintenance of an engine-authorized strict recipe is independent of the
-- planner-origin flag and priest movement/custody. It does not generate any
-- output: it only selects the real workshop recipe and moves real plates.
do
  local mod,pair,stock=fixture(10)
  local input=inv({},10)
  local selected,attempts=nil,0
  prototypes.recipe["copper-cable"]={
    category="electronics",ingredients={{
      type="item",name="copper-plate",amount=1
    }}
  }
  local force={recipes={["copper-cable"]={enabled=true}}}
  pair.station.force=force
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.entity and rec.entity.valid then rec.entity.force=force end
  end
  local assembler={valid=true,name="tech-priests-emergency-assembler",
    type="assembling-machine",unit_number=731,position={x=4,y=0},
    force=force,surface=pair.station.surface,
    prototype={crafting_categories={electronics=true}}}
  assembler.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_input then return input end
  end
  assembler.get_recipe=function()
    return selected and {name=selected,
      ingredients=prototypes.recipe[selected].ingredients} or nil
  end
  assembler.set_recipe=function(recipe)
    selected=recipe;attempts=attempts+1;return true
  end
  local furnace
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.role=="smelter" then furnace=rec.entity end
  end
  assert(mod.tag_built_entity(pair,assembler,"strict-recipe-continuity"))
  pair.station.surface.find_entities_filtered=function()return {furnace,assembler}end
  stock.items["copper-plate"]=3
  local held={item="iron-ore",count=1}
  pair.direct_acquisition_custody_0513=held
  pair.mode="direct-acquisition-returning-with-custody"
  pair.emergency_craft={strict_recipe_0647=true,output_item="copper-cable"}
  assert(pair.emergency_craft.infrastructure_first_0640==nil)
  local acted=mod.service_owned_miners_all("broker-periodic")
  local observed=pair.emergency_facility_continuity_diagnostic_0357
  assert(acted>0 and observed and observed.authorized
      and not observed.infrastructure and observed.custody_ready
      and observed.serviced and observed.workshop_owned,
    "authorized strict workshop was skipped without an infrastructure-origin flag")
  assert(selected=="copper-cable" and attempts==1
      and input.get_item_count("copper-plate")==1
      and stock.get_item_count("copper-plate")==2
      and stock.get_item_count("copper-cable")==0,
    "autonomous workshop service did not select and physically feed recipe")
  assert(pair.direct_acquisition_custody_0513==held
      and pair.mode=="direct-acquisition-returning-with-custody"
      and not pair.emergency_facility_feed_custody_0357,
    "workshop service stole mining custody or invented physical cargo")
end


-- A durable, still-assigned infrastructure recipe must survive the gap in
-- which a short-lived emergency_craft task is absent during maintenance.
-- This cannot bypass research unlocks or resurrect terminal/cancelled gates.
do
  local mod,pair,stock=fixture(10)
  local inp,fuel=inv({},10),inv({},4)
  local selected,attempts=nil,0
  local recipes={["copper-cable"]={enabled=true}}
  local force={recipes=recipes}
  pair.station.force=force
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.entity and rec.entity.valid then rec.entity.force=force end
  end
  prototypes.recipe["copper-cable"]={category="electronics",ingredients={
    {name="copper-plate",type="item",amount=1}}}
  local assembler={valid=true,name="tech-priests-emergency-assembler",
    type="assembling-machine",unit_number=820,position={x=4,y=0},
    surface=pair.station.surface,force=force,
    prototype={crafting_categories={electronics=true}}}
  assembler.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_input then return inp end
    if id==defines.inventory.fuel then return fuel end
  end
  assembler.get_recipe=function()
    return selected and {name=selected,
      ingredients=prototypes.recipe[selected].ingredients} or nil
  end
  assembler.set_recipe=function(name)
    attempts=attempts+1;selected=name;return true
  end
  local furnace
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.role=="smelter" then furnace=rec.entity end
  end
  assert(mod.tag_built_entity(pair,assembler,"persisted-physical-recipe-gate"))
  pair.station.surface.find_entities_filtered=function()return {furnace,assembler}end
  stock.items["copper-plate"]=3
  local custody={item="iron-ore",count=1}
  pair.direct_acquisition_custody_0513=custody
  pair.mode="direct-acquisition-returning-with-custody"
  pair.emergency_craft=nil
  pair.local_infrastructure_gate_0640={item="copper-cable",
    state="assigned-local-step",why="recipe-prerequisite-for:electronic-circuit",
    tick=game.tick}
  mod.service_owned_miners_all("gate-backed-workshop")
  local diag=pair.emergency_facility_continuity_diagnostic_0357
  assert(diag and diag.task=="copper-cable" and diag.authorized
      and diag.source=="assigned-local-step" and diag.serviced
      and attempts==1 and selected=="copper-cable"
      and inp.get_item_count("copper-plate")==1
      and stock.get_item_count("copper-plate")==2
      and pair.emergency_craft==nil
      and stock.get_item_count("copper-cable")==0
      and pair.direct_acquisition_custody_0513==custody,
    "gate-backed maintenance did not reach the real engine selector safely")
  pair.local_infrastructure_gate_0640.state="terminal-unverified-local-step"
  selected=nil
  game.tick=game.tick+130
  mod.service_owned_miners_all("retired-gate-cannot-craft")
  assert(attempts==1 and inp.get_item_count("copper-plate")==1
      and stock.get_item_count("copper-plate")==2,
    "terminal gate unlawfully restarted recipe crafting")
  pair.local_infrastructure_gate_0640.state="assigned-local-step"
  recipes["copper-cable"].enabled=false
  game.tick=game.tick+130
  mod.service_owned_miners_all("locked-gate-cannot-craft")
  assert(attempts==1 and stock.get_item_count("copper-cable")==0,
    "force-locked gate unlawfully selected a recipe")
end

-- Truly mined output must be returned physically from the owned micro-miner,
-- with no invented product, interference with machine logistics, or lost coal
-- when a cache rejects deposits. This is not a recipe-production shortcut.
do
  local mod,pair,stock=fixture(10)
  local output=inv({coal=3,["copper-ore"]=2},12)
  local force={recipes={}}
  pair.station.force=force
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.entity and rec.entity.valid then rec.entity.force=force end
  end
  local miner={valid=true,name="tech-priests-emergency-miner",
    type="assembling-machine",unit_number=821,position={x=3,y=1},
    surface=pair.station.surface,force=force}
  miner.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_output then return output end
  end
  miner.get_recipe=function()
    return {name="tech-priests-emergency-mine-coal",products={
      {type="item",name="coal",amount=1}}}
  end
  local furnace
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.role=="smelter" then furnace=rec.entity end
  end
  assert(mod.tag_built_entity(pair,miner,"real-miner-output-return"))
  pair.station.surface.find_entities_filtered=function()return {furnace,miner}end
  pair.emergency_craft=nil
  local custody={item="iron-ore",count=1}
  pair.direct_acquisition_custody_0513=custody
  _G.tech_priests_safe_deposit_item=function(_,item,count)
    local deposited=stock.insert({name=item,count=count})
    return deposited==count,"deposited",deposited
  end
  local accepted=mod.service_owned_miners_all("physical-miner-coal-return")
  assert(accepted>0 and output.get_item_count("coal")==0
      and output.get_item_count("copper-ore")==0
      and stock.get_item_count("coal")==5
      and stock.get_item_count("copper-ore")==2
      and pair.direct_acquisition_custody_0513==custody
      and not pair.emergency_facility_feed_custody_0357,
    "real miner output was not conserved when deposited to station")
  output.items.coal=2
  pair.machine_logistics_0528={machine=miner,phase="transfer"}
  game.tick=game.tick+130
  mod.service_owned_miners_all("active-logistics-owns-miner-output")
  assert(output.get_item_count("coal")==2 and stock.get_item_count("coal")==5,
    "miner continuity stole active machine-logistics output")
  pair.machine_logistics_0528=nil
  _G.tech_priests_safe_deposit_item=function()return false,"blocked",0 end
  game.tick=game.tick+130
  mod.service_owned_miners_all("blocked-miner-storage-rollback")
  assert(output.get_item_count("coal")==2 and stock.get_item_count("coal")==5
      and not pair.emergency_facility_feed_custody_0357,
    "failed mined-coal deposit erased or fabricated inventory")
  _G.tech_priests_safe_deposit_item=nil
end


-- The shared work allocator must reach an *actual* owned engine workshop,
-- not merely change a planning label. A priest may be away with completely
-- unrelated, already-held mining cargo; neither movement nor inventory
-- custody can be rewritten by autonomous local machine servicing.
do
  local mod,pair,stock=fixture(10)
  local input=inv({},10)
  local selected,attempts=nil,0
  local force={recipes={["copper-cable"]={enabled=true}}}
  pair.station.force=force
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.entity and rec.entity.valid then rec.entity.force=force end
  end
  prototypes.recipe["copper-cable"]={category="electronics",ingredients={
    {name="copper-plate",type="item",amount=1}}}
  local machine={valid=true,name="tech-priests-emergency-assembler",
    type="assembling-machine",unit_number=930,position={x=4,y=0},
    force=force,surface=pair.station.surface,
    prototype={crafting_categories={electronics=true}}}
  machine.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_input then return input end
  end
  machine.get_recipe=function()
    return selected and {name=selected,
      ingredients=prototypes.recipe[selected].ingredients} or nil
  end
  machine.set_recipe=function(recipe)
    selected=recipe;attempts=attempts+1;return true
  end
  local furnace
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.role=="smelter" then furnace=rec.entity end
  end
  assert(mod.tag_built_entity(pair,machine,"cooperative-real-workshop"))
  pair.station.surface.find_entities_filtered=function()return {furnace,machine}end
  pair.emergency_craft=nil
  pair.local_infrastructure_gate_0640=nil
  local held={item="iron-ore",count=1}
  pair.direct_acquisition_custody_0513=held
  pair.mode="travelling-to-direct-acquisition"
  stock.items["copper-plate"]=3
  local original=_G.TechPriestsInfrastructureFirstGovernor0640
  _G.TechPriestsInfrastructureFirstGovernor0640={
    cooperative_labor_for_pair=function()
      return "copper-cable","cooperative"
    end
  }
  local serviced=mod.service_owned_miners_all("team-real-engine-work-order")
  local work=pair.cooperative_labor_work_order_0690
  local diag=pair.emergency_facility_continuity_diagnostic_0357
  assert(serviced>0 and selected=="copper-cable" and attempts==1
      and work and work.item=="copper-cable"
      and diag and diag.task=="copper-cable"
      and diag.source=="cooperative-labor:cooperative" and diag.serviced
      and input.get_item_count("copper-plate")==1
      and stock.get_item_count("copper-plate")==2
      and stock.get_item_count("copper-cable")==0
      and pair.direct_acquisition_custody_0513==held
      and pair.mode=="travelling-to-direct-acquisition",
    "cooperative production failed to feed an engine-selected physical craft")
  -- The accepted engine recipe is a durable lease. A later planner score
  -- must not evict its physical input while the priest is still travelling.
  force.recipes["electronic-circuit"]={enabled=true}
  prototypes.recipe["electronic-circuit"]={category="electronics",ingredients={
    {name="copper-cable",type="item",amount=1}}}
  _G.TechPriestsInfrastructureFirstGovernor0640={
    cooperative_labor_for_pair=function()
      return "electronic-circuit","different-strategic-preference"
    end
  }
  game.tick=game.tick+130
  mod.service_owned_miners_all("preserve-accepted-machine-work")
  local lease_diag=pair.emergency_facility_continuity_diagnostic_0357
  assert(pair.cooperative_labor_work_order_0690==work
      and work.machine_unit==machine.unit_number
      and work.station_unit==pair.station.unit_number
      and work.recipe=="copper-cable"
      and selected=="copper-cable" and attempts==1
      and input.get_item_count("copper-plate")==1
      and stock.get_item_count("copper-plate")==2
      and lease_diag.machine_accepted
      and lease_diag.source=="cooperative-labor:accepted-lease",
    "maintenance preempted a physical cooperative work order")
  -- Locking the force's recipe must prevent any fresh work order or
  -- ingredient withdrawal. It must not clear a valid previous output.
  force.recipes["electronic-circuit"].enabled=false
  pair.cooperative_labor_work_order_0690=nil
  force.recipes["copper-cable"].enabled=false
  selected=nil
  game.tick=game.tick+130
  mod.service_owned_miners_all("locked-team-recipe")
  assert(not pair.cooperative_labor_work_order_0690 and attempts==1
      and input.get_item_count("copper-plate")==1
      and stock.get_item_count("copper-plate")==2,
    "cooperative work bypassed a locked engine recipe")
  -- Once a genuinely finished cable reaches managed stock and the input
  -- buffer clears, the lease releases and a different feasible team job
  -- can take over the same physical machine.
  force.recipes["copper-cable"].enabled=true
  force.recipes["electronic-circuit"].enabled=true
  selected="copper-cable"
  input.items["copper-plate"]=0
  stock.items["copper-cable"]=1
  pair.cooperative_labor_work_order_0690=work
  game.tick=game.tick+130
  mod.service_owned_miners_all("physically-finished-lease-reassignment")
  local next_work=pair.cooperative_labor_work_order_0690
  local next_diag=pair.emergency_facility_continuity_diagnostic_0357
  assert(selected=="electronic-circuit" and attempts==2
      and next_work and next_work.item=="electronic-circuit"
      and next_work.machine_unit==machine.unit_number
      and next_diag.machine_accepted
      and input.get_item_count("copper-cable")==1
      and stock.get_item_count("copper-cable")==0,
    "finished physical output failed to release the cooperative work lease")
  _G.TechPriestsInfrastructureFirstGovernor0640=original
end

-- Even a valid strategic request cannot change a different assembler recipe
-- while the engine still holds that recipe's input. The transition must not
-- erase the physically deposited plate or claim that electronics was selected.
do
  local mod,pair,stock=fixture(10)
  local force={recipes={
    ["copper-cable"]={enabled=true},
    ["electronic-circuit"]={enabled=true},
  }}
  pair.station.force=force
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.entity and rec.entity.valid then rec.entity.force=force end
  end
  prototypes.recipe["copper-cable"]={category="electronics",ingredients={
    {name="copper-plate",type="item",amount=1}}}
  prototypes.recipe["electronic-circuit"]={category="electronics",ingredients={
    {name="copper-cable",type="item",amount=1}}}
  local input=inv({["copper-plate"]=1},10)
  local previous_count=input.get_item_count
  input.get_item_count=function(name)
    if name then return previous_count(name) end
    local total=0
    for _,amount in pairs(input.items) do total=total+amount end
    return total
  end
  local selected="copper-cable"
  local attempts=0
  local workshop={valid=true,name="tech-priests-emergency-assembler",
    type="assembling-machine",unit_number=931,position={x=4,y=0},
    force=force,surface=pair.station.surface,
    prototype={crafting_categories={electronics=true}}}
  workshop.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_input then return input end
  end
  workshop.get_recipe=function()
    return {name=selected,ingredients=prototypes.recipe[selected].ingredients}
  end
  workshop.set_recipe=function(name)
    attempts=attempts+1;selected=name;return true
  end
  assert(mod.tag_built_entity(pair,workshop,"preemption-guard-fixture"))
  pair.station.surface.find_entities_filtered=function()return {workshop}end
  pair.emergency_craft={strict_recipe_0647=true,facility_only_0647=true,
    output_item="electronic-circuit"}
  local old_claim=_G.tech_priests_0576_claim_machine_for_recipe
  local claims=0
  _G.tech_priests_0576_claim_machine_for_recipe=function()
    claims=claims+1
    return true
  end
  local before_plate=stock.get_item_count("copper-plate")
  mod.service_owned_miners_all("prevent-live-recipe-preemption")
  local diag=pair.emergency_facility_assembler_recipe_diagnostic_0357
  local service=pair.emergency_facility_continuity_diagnostic_0357
  assert(attempts==0 and claims==0 and selected=="copper-cable"
      and input.get_item_count("copper-plate")==1
      and stock.get_item_count("copper-plate")==before_plate
      and diag and diag.phase=="live-recipe-protected"
      and service and service.machine_accepted==false
      and service.selected_recipe=="copper-cable",
    "active engine ingredients were preempted by another recipe")
  _G.tech_priests_0576_claim_machine_for_recipe=old_claim
end

-- A selector returning true is not proof of production when the engine
-- reports recipe=nil. No work order or physical ingredient transfer is allowed.
do
  local mod,pair,stock=fixture(10)
  local force={recipes={["copper-cable"]={enabled=true}}}
  pair.station.force=force
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.entity and rec.entity.valid then rec.entity.force=force end
  end
  prototypes.recipe["copper-cable"]={category="electronics",ingredients={
    {name="copper-plate",type="item",amount=1}}}
  local input=inv({},10)
  local attempts=0
  local workshop={valid=true,name="tech-priests-emergency-assembler",
    type="assembling-machine",unit_number=932,position={x=4,y=0},
    force=force,surface=pair.station.surface,
    prototype={crafting_categories={electronics=true}}}
  workshop.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_input then return input end
  end
  workshop.get_recipe=function()return nil end
  workshop.set_recipe=function(_)attempts=attempts+1;return true end
  assert(mod.tag_built_entity(pair,workshop,"unconfirmed-selector-fixture"))
  pair.station.surface.find_entities_filtered=function()return {workshop}end
  pair.emergency_craft=nil
  stock.items["copper-plate"]=2
  local original=_G.TechPriestsInfrastructureFirstGovernor0640
  _G.TechPriestsInfrastructureFirstGovernor0640={
    cooperative_labor_for_pair=function()return "copper-cable","cooperative"end
  }
  mod.service_owned_miners_all("engine-unconfirmed-selection")
  local selector=pair.emergency_facility_assembler_recipe_diagnostic_0357
  local service=pair.emergency_facility_continuity_diagnostic_0357
  assert(attempts==1 and selector and selector.phase=="engine-unconfirmed"
      and not pair.cooperative_labor_work_order_0690
      and service and service.machine_accepted==false
      and input.get_item_count("copper-plate")==0
      and stock.get_item_count("copper-plate")==2,
    "unconfirmed recipe was credited as cooperative production")
  _G.TechPriestsInfrastructureFirstGovernor0640=original
end

-- Independent local industry must continue while the dispatcher runs
-- an unrelated, physically authorized furnace recipe. The same pulse feeds
-- the real copper smelter AND an engine-accepted cable workshop, without
-- replacing the priest's furnace task or material/movement custody.
do
  local mod,pair,stock,furnace_input=fixture(10)
  local input=inv({},10)
  local selected,attempts=nil,0
  local force={recipes={["copper-cable"]={enabled=true}}}
  pair.station.force=force
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.entity and rec.entity.valid then rec.entity.force=force end
  end
  prototypes.recipe["copper-cable"]={category="electronics",ingredients={
    {name="copper-plate",type="item",amount=1}}}
  local machine={valid=true,name="tech-priests-emergency-assembler",
    type="assembling-machine",unit_number=933,position={x=4,y=0},
    force=force,surface=pair.station.surface,
    prototype={crafting_categories={electronics=true}}}
  machine.get_inventory=function(id)
    if id==defines.inventory.assembling_machine_input then return input end
  end
  machine.get_recipe=function()
    return selected and {name=selected,
      ingredients=prototypes.recipe[selected].ingredients} or nil
  end
  machine.set_recipe=function(name)
    selected=name;attempts=attempts+1;return true
  end
  local furnace
  for _,rec in pairs(storage.tech_priests.emergency_facility_doctrine_0343.facilities) do
    if rec.role=="smelter" then furnace=rec.entity end
  end
  assert(mod.tag_built_entity(pair,machine,"parallel-smelting-and-assembly"))
  pair.station.surface.find_entities_filtered=function()return {furnace,machine}end
  stock.items["copper-ore"]=3
  stock.items["copper-plate"]=3
  local smelt={output_item="copper-plate",item_name="copper-plate",
    facility_only_0647=true,strict_recipe_0647=true}
  pair.emergency_craft=smelt
  pair.mode="travelling-to-direct-acquisition"
  local held={item="iron-ore",count=1}
  pair.direct_acquisition_custody_0513=held
  local original=_G.TechPriestsInfrastructureFirstGovernor0640
  _G.TechPriestsInfrastructureFirstGovernor0640={
    cooperative_labor_for_pair=function()
      return "copper-plate","furnace-priority"
    end,
    cooperative_workshop_for_pair=function()
      return "copper-cable","parallel-smelter-workshop"
    end
  }
  local worked=mod.service_owned_miners_all("simultaneous-furnace-workshop")
  local diag=pair.emergency_facility_continuity_diagnostic_0357
  local lease=pair.cooperative_labor_work_order_0690
  local offer=pair.emergency_facility_workshop_offer_0357
  assert(offer and offer.proposal=="copper-cable"
      and offer.accepted and offer.status=="engine-selection-pending",
    "workshop offer trace did not retain a viable independent recipe")
  assert(worked>0 and attempts==1 and selected=="copper-cable"
      and furnace_input.get_item_count("copper-ore")==3
      and input.get_item_count("copper-plate")==1
      and stock.get_item_count("copper-ore")==0
      and stock.get_item_count("copper-plate")==2
      and diag and diag.task=="copper-plate"
      and diag.workshop_request=="copper-cable"
      and diag.machine_accepted and diag.workshop_free
      and diag.source=="cooperative-labor:parallel-smelter-workshop"
      and lease and lease.item=="copper-cable"
      and pair.emergency_craft==smelt
      and pair.direct_acquisition_custody_0513==held
      and pair.mode=="travelling-to-direct-acquisition",
    "independent workshop was starved by concurrent physical copper smelting")
  local accepted_tick=lease.tick
  game.tick=game.tick+130
  mod.service_owned_miners_all("furnace-task-must-not-reset-cable-lease")
  assert(pair.cooperative_labor_work_order_0690==lease
      and lease.tick==accepted_tick
      and lease.initial_stock==0
      and selected=="copper-cable",
    "furnace request incorrectly reset physical workshop completion baseline")
  -- Non-strict hand-mining assignments are not an assembler owner either.
  -- This is the historical idle Magos case: a copper-ore acquisition task
  -- existed and silently prevented all workshop recipe selection.
  selected=nil
  input.items["copper-plate"]=0
  pair.cooperative_labor_work_order_0690=nil
  pair.emergency_craft={item_name="copper-ore",output_item="copper-ore"}
  game.tick=game.tick+130
  mod.service_owned_miners_all("raw-task-does-not-own-workshop")
  local diag2=pair.emergency_facility_continuity_diagnostic_0357
  assert(attempts==2 and selected=="copper-cable"
      and input.get_item_count("copper-plate")==1
      and stock.get_item_count("copper-plate")==1
      and diag2 and diag2.workshop_free and diag2.machine_accepted
      and diag2.workshop_request=="copper-cable"
      and pair.direct_acquisition_custody_0513==held,
    "unrelated non-strict raw acquisition suppressed physical workshop")
  -- Carrying furnace output protects that cargo, not this separate physical
  -- assembler. A route targeting the workshop itself must still block.
  -- Start another engine-accepted cable order *after* acquiring the
  -- unrelated furnace cargo. Acceptance must create a durable work lease,
  -- not just happen to preserve an older pre-custody lease.
  pair.cooperative_labor_work_order_0690=nil
  selected=nil
  input.items["copper-plate"]=0
  local furnace_cargo={item="copper-plate",count=1}
  pair.machine_logistics_custody_0528=furnace_cargo
  pair.machine_logistics_0528={
    machine=furnace,phase="return-custody-to-station",custody=furnace_cargo}
  game.tick=game.tick+130
  mod.service_owned_miners_all("furnace-custody-with-independent-workshop")
  local allowed=pair.emergency_facility_continuity_diagnostic_0357
  local independent_lease=pair.cooperative_labor_work_order_0690
  assert(allowed and allowed.workshop_free and allowed.machine_accepted
      and allowed.workshop_request=="copper-cable"
      and independent_lease and independent_lease.item=="copper-cable"
      and independent_lease.machine_unit==machine.unit_number
      and attempts==3 and input.get_item_count("copper-plate")==1
      and stock.get_item_count("copper-plate")==0
      and pair.machine_logistics_custody_0528==furnace_cargo
      and pair.machine_logistics_0528.custody==furnace_cargo
      and selected=="copper-cable",
    "unrelated furnace cargo prevented a new engine-confirmed workshop lease")
  pair.machine_logistics_0528.machine=machine
  game.tick=game.tick+130
  mod.service_owned_miners_all("workshop-custody-must-remain-protected")
  local blocked=pair.emergency_facility_continuity_diagnostic_0357
  assert(blocked and not blocked.workshop_free
      and blocked.blocker=="workshop-machine-logistics-custody"
      and pair.machine_logistics_custody_0528==furnace_cargo
      and selected=="copper-cable",
    "active workshop-specific custody was overridden by the labor allocator")
  _G.TechPriestsInfrastructureFirstGovernor0640=original
end

print("PASS emergency facility feed accounting")
