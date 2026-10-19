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
  local surface={}
  local furnace={valid=true,name="tech-priests-emergency-smelter",
    type="furnace",unit_number=2,position={x=2,y=0},surface=surface}
  function furnace.get_inventory(id)
    if id==defines.inventory.furnace_source then return input end
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
  return mod,pair,stock,input,fuel
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
print("PASS emergency facility feed accounting")
